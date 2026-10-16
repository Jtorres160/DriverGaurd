param(
    [ValidateSet('ReadOnly','PolicyCycle')][string]$Mode='ReadOnly',
    [switch]$ApproveStateChanges
)

Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$driverGuard=Join-Path $PSScriptRoot '..\DriverGuard.ps1'
$unitTests=Join-Path $PSScriptRoot 'DriverGuard.Tests.ps1'
$shell=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$policyPath='SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
$statePaths=@(
    (Join-Path $env:ProgramData 'DriverGuard\original-state.ini'),
    (Join-Path $env:ProgramData 'DriverGuard\gpu-install.json'),
    (Join-Path $env:ProgramData 'DriverGuard\DriverGuard.log'),
    (Join-Path $env:LOCALAPPDATA 'DriverGuard\DriverGuard-user.log')
)

function Get-Snapshot {
    $view=[Microsoft.Win32.RegistryView]::Registry32
    if ([Environment]::Is64BitOperatingSystem) { $view=[Microsoft.Win32.RegistryView]::Registry64 }
    $base=[Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine,$view)
    try {
        $key=$base.OpenSubKey($policyPath,$false)
        $values=@{}
        if ($key) {
            try {
                foreach ($name in $key.GetValueNames()) {
                    $kind=$key.GetValueKind($name).ToString()
                    $data=$key.GetValue($name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                    $values[$name]="$kind : $data"
                }
            } finally { $key.Dispose() }
        }
    } finally { $base.Dispose() }
    $files=@{}
    foreach ($path in $statePaths) {
        if (Test-Path -LiteralPath $path) { $files[$path]=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
        else { $files[$path]='ABSENT' }
    }
    return [pscustomobject]@{ PolicyKeyExists=($null -ne $key); PolicyValues=$values; StateFiles=$files }
}
function Compare-Snapshot($Before,$After) {
    $beforeJson=ConvertTo-Json $Before -Depth 5 -Compress
    $afterJson=ConvertTo-Json $After -Depth 5 -Compress
    return $beforeJson -ceq $afterJson
}
function Invoke-DriverGuard([string]$Action) {
    Write-Host "Running DriverGuard $Action"
    & $shell -NoProfile -ExecutionPolicy RemoteSigned -File $driverGuard -Action $Action | Out-Host
    return $LASTEXITCODE
}

if ($Mode -eq 'PolicyCycle') {
    if (-not $ApproveStateChanges) { throw 'PolicyCycle requires -ApproveStateChanges and an isolated, snapshotted Windows test machine.' }
    $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
    $principal=New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'PolicyCycle must run in an already elevated session.' }
    Write-Host 'STATE-CHANGING POLICY CYCLE. Requires a VM snapshot and an independently recorded baseline.'
    Write-Host 'The baseline must be an absent policy value or DWORD 0. DriverGuard will ask for YES before each change.'
    if ((Read-Host 'Type APPROVE POLICY CYCLE to continue') -cne 'APPROVE POLICY CYCLE') { throw 'Policy cycle cancelled before any change.' }
    $before=Get-Snapshot
    Write-Host ('Before: '+($before | ConvertTo-Json -Depth 5 -Compress))
    $policyName='ExcludeWUDriversInQualityUpdate'
    if ($before.PolicyValues.ContainsKey($policyName) -and $before.PolicyValues[$policyName] -cne 'DWord : 0') {
        throw 'PolicyCycle baseline must have an absent target value or DWORD 0. No change made.'
    }
    $enableCode=Invoke-DriverGuard 'Enable'
    $enabled=Get-Snapshot
    Write-Host ('After Enable: '+($enabled | ConvertTo-Json -Depth 5 -Compress))
    if ($enableCode -ne 0) { throw "Enable exited $enableCode. Inspect recovery state; no automatic restore attempted." }
    if (-not $enabled.PolicyValues.ContainsKey($policyName) -or $enabled.PolicyValues[$policyName] -cne 'DWord : 1' -or $enabled.StateFiles[$statePaths[0]] -eq 'ABSENT') {
        throw 'Enable target value or recovery backup was not independently observed. Inspect state; no automatic restore attempted.'
    }
    if ((Read-Host 'Type RESTORE to run DriverGuard Restore') -cne 'RESTORE') { Write-Host 'Restore deferred. Retain the VM snapshot and recovery backup.'; exit 2 }
    $restoreCode=Invoke-DriverGuard 'Restore'
    $after=Get-Snapshot
    Write-Host ('After Restore: '+($after | ConvertTo-Json -Depth 5 -Compress))
    if ($restoreCode -ne 0) { throw "Restore exited $restoreCode. Inspect recovery state." }
    $policySame=($before.PolicyKeyExists -eq $after.PolicyKeyExists) -and ((ConvertTo-Json $before.PolicyValues -Compress) -ceq (ConvertTo-Json $after.PolicyValues -Compress))
    if ($policySame) { Write-Host 'Policy key and values: exact before/after match. Check reboot persistence separately.'; exit 0 }
    Write-Host 'Policy key or values differ from baseline. Inspect before restoring VM snapshot.'
    exit 1
}

if ($ApproveStateChanges) { throw '-ApproveStateChanges is only valid with -Mode PolicyCycle.' }
Write-Host 'AUTOMATED READ-ONLY HOST VALIDATION (unit tests use disposable local fixtures)'
$before=Get-Snapshot
& $shell -NoProfile -ExecutionPolicy RemoteSigned -File $unitTests
$unitCode=$LASTEXITCODE
$diagnoseCode=Invoke-DriverGuard 'Diagnose'
$after=Get-Snapshot
$unchanged=Compare-Snapshot $before $after
Write-Host "Mocked unit suite exit: $unitCode"
Write-Host "Native Diagnose exit: $diagnoseCode (0 complete, 2 partial, 1 failed)"
Write-Host "Policy values and DriverGuard state-file hashes unchanged: $unchanged"
if (-not $unchanged -or $unitCode -ne 0 -or $diagnoseCode -eq 1) { exit 1 }
if ($diagnoseCode -eq 2) { exit 2 }
exit 0
