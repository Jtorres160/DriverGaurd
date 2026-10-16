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
                    if ($data -is [byte[]]) { $display=[Convert]::ToBase64String($data) }
                    elseif ($data -is [array]) { $display=ConvertTo-Json -InputObject $data -Compress -Depth 5 }
                    else { $display=[string]$data }
                    $values[$name]="$kind : $display"
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
function Compare-Map($Left,$Right) {
    if ($Left.Count -ne $Right.Count) { return $false }
    foreach ($name in $Left.Keys) {
        if (-not $Right.ContainsKey($name) -or $Left[$name] -cne $Right[$name]) { return $false }
    }
    return $true
}
function Compare-Snapshot($Before,$After) {
    return $Before.PolicyKeyExists -eq $After.PolicyKeyExists -and
        (Compare-Map $Before.PolicyValues $After.PolicyValues) -and
        (Compare-Map $Before.StateFiles $After.StateFiles)
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
    $valuesSame=Compare-Map $before.PolicyValues $after.PolicyValues
    if ($valuesSame -and $before.PolicyKeyExists -eq $after.PolicyKeyExists) { Write-Host 'PolicyCycle: PASS - policy key and values match baseline. Check reboot persistence separately.'; exit 0 }
    if ($valuesSame) { Write-Host 'PolicyCycle: PARTIAL - policy values match baseline, but key presence differs. An empty key may remain after restoring an originally absent value.'; exit 2 }
    Write-Host 'PolicyCycle: FAIL - policy values differ from baseline. Inspect before restoring VM snapshot.'
    exit 1
}

if ($ApproveStateChanges) { throw '-ApproveStateChanges is only valid with -Mode PolicyCycle.' }
$comparisonFixture=[pscustomobject]@{ PolicyKeyExists=$true; PolicyValues=@{ A='DWord : 0'; B='Binary : AQI=' }; StateFiles=@{ backup='ABSENT' } }
$reorderedFixture=[pscustomobject]@{ PolicyKeyExists=$true; PolicyValues=@{ B='Binary : AQI='; A='DWord : 0' }; StateFiles=@{ backup='ABSENT' } }
$changedFixture=[pscustomobject]@{ PolicyKeyExists=$true; PolicyValues=@{ B='Binary : AQM='; A='DWord : 0' }; StateFiles=@{ backup='ABSENT' } }
if (-not (Compare-Snapshot $comparisonFixture $reorderedFixture) -or (Compare-Snapshot $comparisonFixture $changedFixture)) {
    throw 'Read-only snapshot comparison self-check failed.'
}
Write-Host 'Snapshot comparison self-check: PASS (order independent; changed binary value detected)'
Write-Host 'AUTOMATED READ-ONLY HOST VALIDATION (unit tests use disposable local fixtures)'
try {
    $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
    $principal=New-Object Security.Principal.WindowsPrincipal($identity)
    $os=Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    $computer=Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
    Write-Host "Host: $($os.Caption) | version=$($os.Version) | build=$($os.BuildNumber) | administrator=$($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))"
    Write-Host "Platform: $($computer.Manufacturer) $($computer.Model) | hypervisorPresent=$($computer.HypervisorPresent)"
} catch { Write-Host "Host identity: UNAVAILABLE - $($_.Exception.Message)" }
Write-Host 'Live policy cycle: NOT TESTED (requires an isolated recoverable machine and explicit authorization).'
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
