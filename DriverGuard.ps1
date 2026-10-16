param(
    [ValidateSet('Summary','Enable','Restore','Status','Log','Help','Inspect','Install','Verify','Cleanup','Diagnose')]
    [string]$Action = 'Summary'
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$script:ScriptPath = $PSCommandPath
$script:PolicySubkey = 'SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
$script:PolicyName = 'ExcludeWUDriversInQualityUpdate'
$script:DataDir = Join-Path $env:ProgramData 'DriverGuard'
$script:BackupPath = Join-Path $script:DataDir 'original-state.ini'
$script:LogPath = Join-Path $script:DataDir 'DriverGuard.log'
$script:UserLogPath = Join-Path (Join-Path $env:LOCALAPPDATA 'DriverGuard') 'DriverGuard-user.log'
$script:JournalPath = Join-Path $script:DataDir 'gpu-install.json'
$script:DisplayGuid = '{4d36e968-e325-11ce-bfc1-08002be10318}'

function Test-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
function Get-OS {
    $os = Get-CimInstance Win32_OperatingSystem
    [pscustomobject]@{ Name=$os.Caption; Version=$os.Version; Build=[int]$os.BuildNumber }
}
function Assert-Windows {
    $os = Get-OS
    if ([Environment]::OSVersion.Platform -ne 'Win32NT' -or $os.Build -lt 14393) {
        throw 'This utility requires a supported Windows 10/11 build (1607 or later).'
    }
    return $os
}
function Assert-SecureStatePath([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return }
    if ((Get-Item -LiteralPath $Path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "State path is a reparse point: $Path" }
    $acl = Get-Acl -LiteralPath $Path
    $owner = $acl.GetOwner([Security.Principal.SecurityIdentifier]).Value
    if ($owner -notin @('S-1-5-18','S-1-5-32-544')) { throw "State path has an untrusted owner: $Path" }
    $dangerous = [Security.AccessControl.FileSystemRights]'Write, Delete, ChangePermissions, TakeOwnership'
    foreach ($rule in $acl.GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier])) {
        if ($rule.AccessControlType -ne [Security.AccessControl.AccessControlType]::Allow) { continue }
        if ($rule.IdentityReference.Value -notin @('S-1-5-18','S-1-5-32-544') -and ($rule.FileSystemRights -band $dangerous)) {
            throw "State path grants write permissions to a nonadministrator: $Path"
        }
    }
}
function Protect-DataDirectory {
    if (-not (Test-Admin)) { throw 'Administrator access is required for persistent state changes.' }
    $created = -not (Test-Path -LiteralPath $script:DataDir)
    if ($created) { New-Item -ItemType Directory -Path $script:DataDir -Force | Out-Null }
    $item = Get-Item -LiteralPath $script:DataDir -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'The data directory cannot be a junction or symbolic link.' }
    if (-not $created) { Assert-SecureStatePath $script:DataDir }
    $acl = New-Object Security.AccessControl.DirectorySecurity
    $acl.SetAccessRuleProtection($true,$false)
    $sidSystem = New-Object Security.Principal.SecurityIdentifier('S-1-5-18')
    $sidAdmins = New-Object Security.Principal.SecurityIdentifier('S-1-5-32-544')
    $sidUsers = New-Object Security.Principal.SecurityIdentifier('S-1-5-32-545')
    $acl.SetOwner($sidAdmins)
    $inherit = [Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit'
    $propagate = [Security.AccessControl.PropagationFlags]::None
    foreach ($sid in @($sidSystem,$sidAdmins)) {
        $rule = New-Object Security.AccessControl.FileSystemAccessRule($sid,[Security.AccessControl.FileSystemRights]::FullControl,$inherit,$propagate,[Security.AccessControl.AccessControlType]::Allow)
        $acl.AddAccessRule($rule)
    }
    $readRule = New-Object Security.AccessControl.FileSystemAccessRule($sidUsers,[Security.AccessControl.FileSystemRights]::ReadAndExecute,$inherit,$propagate,[Security.AccessControl.AccessControlType]::Allow)
    $acl.AddAccessRule($readRule)
    Set-Acl -LiteralPath $script:DataDir -AclObject $acl
    foreach ($path in @($script:BackupPath,$script:JournalPath,$script:LogPath)) {
        if (Test-Path -LiteralPath $path) {
            $file = Get-Item -LiteralPath $path -Force
            if ($file.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "State file is a reparse point: $path" }
            Assert-SecureStatePath $path
            $fileAcl = Get-Acl -LiteralPath $path
            $fileAcl.SetAccessRuleProtection($false,$true)
            Set-Acl -LiteralPath $path -AclObject $fileAcl
        }
    }
}
function Write-Log([string]$Operation,[string]$Result,[string]$Detail) {
    $osBuild = 'unavailable'
    try { $osBuild = (Get-OS).Version } catch { }
    $line = '{0:u} | {1} | {2} | os={3} | admin={4} | {5}' -f (Get-Date),$Operation,$Result,$osBuild,(Test-Admin),($Detail -replace '[\r\n|]',' ')
    try {
        if (Test-Admin) {
            Protect-DataDirectory
            Add-Content -LiteralPath $script:LogPath -Value $line -Encoding UTF8
            $logAcl = Get-Acl -LiteralPath $script:LogPath
            $logAcl.SetOwner((New-Object Security.Principal.SecurityIdentifier('S-1-5-32-544')))
            Set-Acl -LiteralPath $script:LogPath -AclObject $logAcl
        } else {
            $userDir = Split-Path -Parent $script:UserLogPath
            if (-not (Test-Path -LiteralPath $userDir)) { New-Item -ItemType Directory -Path $userDir -Force | Out-Null }
            Add-Content -LiteralPath $script:UserLogPath -Value $line -Encoding UTF8
        }
    } catch { Write-Warning "Could not write activity log: $($_.Exception.Message)" }
}
function Write-Atomic([string]$Path,[string]$Text) {
    Protect-DataDirectory
    if (Test-Path -LiteralPath $Path) { Assert-SecureStatePath $Path }
    $temp = Join-Path $script:DataDir ([IO.Path]::GetRandomFileName())
    try {
        [IO.File]::WriteAllText($temp,$Text,(New-Object Text.UTF8Encoding($false)))
        $fileAcl = Get-Acl -LiteralPath $temp
        $fileAcl.SetOwner((New-Object Security.Principal.SecurityIdentifier('S-1-5-32-544')))
        Set-Acl -LiteralPath $temp -AclObject $fileAcl
        if (Test-Path -LiteralPath $Path) {
            [IO.File]::Replace($temp,$Path,$null)
        } else { [IO.File]::Move($temp,$Path) }
    } finally { if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force } }
}
function Open-PolicyRegistryBase {
    $view = [Microsoft.Win32.RegistryView]::Registry32
    if ([Environment]::Is64BitOperatingSystem) { $view = [Microsoft.Win32.RegistryView]::Registry64 }
    return [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine,$view)
}
function Read-Policy {
    $base = Open-PolicyRegistryBase
    try {
        $key = $base.OpenSubKey($script:PolicySubkey,$false)
        if ($null -eq $key) { return [pscustomobject]@{ KeyExists=$false; ValueExists=$false; Type=''; Value='' } }
        try {
            if ($key.GetValueNames() -notcontains $script:PolicyName) { return [pscustomobject]@{ KeyExists=$true; ValueExists=$false; Type=''; Value='' } }
            $kind = $key.GetValueKind($script:PolicyName).ToString()
            $value = $key.GetValue($script:PolicyName,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            return [pscustomobject]@{ KeyExists=$true; ValueExists=$true; Type=$kind; Value=[string]$value }
        } finally { $key.Dispose() }
    } finally { $base.Dispose() }
}
function Get-PolicyLabel($state) {
    if (-not $state.ValueExists) { return 'NOT CONFIGURED' }
    if ($state.Type -ne 'DWord') { return 'INVALID CONFIGURATION' }
    if ($state.Value -eq '1') { return 'EXCLUSION CONFIGURED' }
    if ($state.Value -eq '0') { return 'POLICY DISABLED' }
    return 'INVALID CONFIGURATION'
}
function Set-PolicyValue([int]$Value) {
    $base = Open-PolicyRegistryBase
    try {
        $key = $base.CreateSubKey($script:PolicySubkey)
        if ($null -eq $key) { throw 'Could not open Windows Update policy key for writing.' }
        try { $key.SetValue($script:PolicyName,$Value,[Microsoft.Win32.RegistryValueKind]::DWord) } finally { $key.Dispose() }
    } finally { $base.Dispose() }
}
function Remove-PolicyValue {
    $base = Open-PolicyRegistryBase
    try {
        $key = $base.OpenSubKey($script:PolicySubkey,$true)
        if ($null -ne $key) {
            try { $key.DeleteValue($script:PolicyName,$false) } finally { $key.Dispose() }
        }
    } finally { $base.Dispose() }
}
function Format-Backup($b) {
    return "Version=1`nOriginalKeyExists=$($b.OriginalKeyExists)`nOriginalValueExists=$($b.OriginalValueExists)`nOriginalType=$($b.OriginalType)`nOriginalValue=$($b.OriginalValue)`nLastWritten=1`nPhase=$($b.Phase)`nOS=$($b.OS)`nCreatedUtc=$($b.CreatedUtc)`n"
}
function Read-Backup {
    if (-not (Test-Path -LiteralPath $script:BackupPath)) { return $null }
    if ($env:DRIVERGUARD_TEST_MODE -ne '1') { Assert-SecureStatePath $script:DataDir; Assert-SecureStatePath $script:BackupPath }
    $raw = [IO.File]::ReadAllLines($script:BackupPath)
    $map = @{}
    foreach ($line in $raw) {
        if ($line -notmatch '^([A-Za-z]+)=(.*)$' -or $map.ContainsKey($matches[1])) { throw 'Recovery backup is malformed.' }
        $map[$matches[1]] = $matches[2]
    }
    $keys = @('Version','OriginalKeyExists','OriginalValueExists','OriginalType','OriginalValue','LastWritten','Phase','OS','CreatedUtc')
    if ($map.Count -ne $keys.Count -or @($keys | Where-Object { -not $map.ContainsKey($_) }).Count -ne 0) { throw 'Recovery backup is incomplete.' }
    if ($map.Version -ne '1' -or $map.OriginalKeyExists -notin @('True','False') -or $map.OriginalValueExists -notin @('True','False') -or $map.LastWritten -ne '1' -or $map.Phase -notin @('Prepared','Active','Restored')) { throw 'Recovery backup contains invalid values.' }
    if ($map.OriginalValueExists -eq 'True') {
        if ($map.OriginalType -ne 'DWord' -or $map.OriginalValue -notin @('0','1')) { throw 'Recovery backup has an unsupported original value.' }
    } elseif ($map.OriginalType -ne '' -or $map.OriginalValue -ne '') { throw 'Recovery backup has inconsistent absence data.' }
    if ($map.OriginalKeyExists -eq 'False' -and $map.OriginalValueExists -eq 'True') { throw 'Recovery backup has inconsistent key data.' }
    return [pscustomobject]$map
}
function Test-OriginalState($state,$backup) {
    if ([string]$state.ValueExists -ne $backup.OriginalValueExists) { return $false }
    if (-not $state.ValueExists) { return $true }
    return $state.Type -eq $backup.OriginalType -and $state.Value -eq $backup.OriginalValue
}
function Test-SamePolicyState($before,$after) {
    return $before.KeyExists -eq $after.KeyExists -and
        $before.ValueExists -eq $after.ValueExists -and
        $before.Type -ceq $after.Type -and $before.Value -ceq $after.Value
}
function Confirm-Yes([string]$Prompt) { return (Read-Host "$Prompt Type YES to continue") -ceq 'YES' }
function Request-Elevation([string]$RequestedAction) {
    if (Test-Admin) { return $false }
    $scriptPath = $script:ScriptPath.Replace("'","''")
    $code = "& '$scriptPath' -Action '$RequestedAction'"
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($code))
    try {
        $proc = Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy RemoteSigned -EncodedCommand $encoded" -Wait -PassThru
        if ($proc.ExitCode -ne 0) { throw "Elevated operation exited with code $($proc.ExitCode)." }
    } catch { throw "Elevation was cancelled or failed: $($_.Exception.Message)" }
    return $true
}
function Show-Status([switch]$Brief) {
    try { $os = Assert-Windows; $state = Read-Policy; $label = Get-PolicyLabel $state }
    catch { Write-Host "STATUS UNAVAILABLE: $($_.Exception.Message)"; return }
    $backupLabel = 'MISSING'; $conflict = 'No'
    try {
        $backup = Read-Backup
        if ($backup) {
            $backupLabel = "VALID ($($backup.Phase))"
            if ($backup.Phase -eq 'Active' -and ($state.Type -ne 'DWord' -or $state.Value -ne '1')) { $conflict = 'Yes' }
            if ($backup.Phase -eq 'Prepared') { $conflict = 'Operation incomplete; inspect backup and policy' }
        }
    } catch { $backupLabel = 'CORRUPT'; $conflict = 'Unknown' }
    Write-Host "Operating System : $($os.Name)"; Write-Host "Build            : $($os.Build)"
    Write-Host "Privileges       : $(if (Test-Admin) {'Administrator'} else {'Standard user'})"
    Write-Host "Driver Policy    : $label"; Write-Host "Recovery Backup  : $backupLabel"
    if (-not $Brief) {
        Write-Host "Registry value   : $(if ($state.ValueExists) {$state.Value} else {'[absent]'})"
        Write-Host "Registry type    : $(if ($state.ValueExists) {$state.Type} else {'[absent]'})"
        Write-Host "External change  : $conflict"
        Write-Host 'Enforcement      : Not verified by registry inspection.'
        Write-Host 'Restart          : Recommended after a policy change.'
        if ($os.Name -match 'Home') { Write-Warning 'Home edition policy enforcement is not listed in the Microsoft Update CSP edition table; treat effectiveness as unverified.' }
        Write-Host 'Managed devices may have Group Policy, MDM, or WSUS settings that supersede local changes.'
    }
}
function Enable-Protection {
    $os = Assert-Windows
    if (Request-Elevation 'Enable') { return }
    $state = Read-Policy; $label = Get-PolicyLabel $state
    if ($label -eq 'INVALID CONFIGURATION') { throw 'Unsupported policy type or value; no change made.' }
    $backup = Read-Backup
    if ($label -eq 'EXCLUSION CONFIGURED') {
        if ($backup -and $backup.Phase -eq 'Prepared') { throw 'Prepared backup and policy value 1 require recovery review. Use Restore to recover the recorded original state.' }
        if ($backup -and $backup.Phase -eq 'Active') { Write-Host 'Already configured; active recovery backup retained.'; return }
        Write-Host 'Already configured externally. No registry write or backup overwrite.'; Write-Log 'Enable' 'NO CHANGE' 'Already configured'; return
    }
    if ($backup -and $backup.Phase -ne 'Restored') {
        if (-not (Test-OriginalState $state $backup)) { throw 'Policy differs from the saved state; resolve the conflict before enabling.' }
    } elseif ($backup -and $backup.Phase -eq 'Restored') {
        if (-not (Test-OriginalState $state $backup)) { throw 'Policy differs from the recorded original state; resolve the conflict before enabling.' }
    }
    Write-Host "Current policy: $label. DriverGuard will set REG_DWORD 1."
    Write-Host 'Recommend creating a Windows restore point first.'
    if (-not (Confirm-Yes 'Enable driver exclusion?')) { Write-Host 'Cancelled.'; return }
    if (-not (Test-SamePolicyState $state (Read-Policy))) { throw 'Policy changed during confirmation; enabling refused. Inspect the current policy before retrying.' }
    Protect-DataDirectory
    if (-not $backup) {
        $backup = [pscustomobject]@{ OriginalKeyExists=$state.KeyExists; OriginalValueExists=$state.ValueExists; OriginalType=$state.Type; OriginalValue=$state.Value; Phase='Prepared'; OS="$($os.Name) $($os.Version)"; CreatedUtc=(Get-Date).ToUniversalTime().ToString('o') }
        Write-Atomic $script:BackupPath (Format-Backup $backup)
        $null = Read-Backup
        Write-Log 'Enable' 'BACKUP' "Original=$label"
    } elseif ($backup.Phase -eq 'Restored') {
        $backup.Phase = 'Prepared'; Write-Atomic $script:BackupPath (Format-Backup $backup)
    }
    if (-not (Test-SamePolicyState $state (Read-Policy))) { throw 'Policy changed after recovery preparation; enabling refused. Inspect the current policy and backup before retrying.' }
    Set-PolicyValue 1
    $after = Read-Policy
    if ($after.Type -ne 'DWord' -or $after.Value -ne '1') { throw "Policy write could not be verified; observed $(Get-PolicyLabel $after)." }
    $backup.Phase = 'Active'; Write-Atomic $script:BackupPath (Format-Backup $backup)
    Write-Log 'Enable' 'SUCCESS' "Original=$label; resulting=REG_DWORD 1; OS=$($os.Version)"
    Write-Host 'Exclusion policy configured and independently read back. Restart recommended; real Windows Update behavior is not verified.'
}
function Restore-Protection {
    $null = Assert-Windows
    if (Request-Elevation 'Restore') { return }
    $backup = Read-Backup
    if (-not $backup) { throw 'No recovery backup exists. Original configuration cannot be inferred.' }
    $state = Read-Policy
    if ($backup.Phase -eq 'Prepared' -and (Test-OriginalState $state $backup)) {
        $backup.Phase = 'Restored'; Write-Atomic $script:BackupPath (Format-Backup $backup)
        Write-Log 'Restore' 'RECONCILED' 'Prepared operation left original policy intact'
        Write-Host 'Interrupted operation reconciled: original policy was already intact.'; return
    }
    if ($backup.Phase -eq 'Restored' -and (Test-OriginalState $state $backup)) { Write-Host 'Original state is already restored.'; return }
    if ($backup.Phase -eq 'Restored') { throw 'Policy changed after DriverGuard restored the original state; restoration refused.' }
    if (-not ($state.Type -eq 'DWord' -and $state.Value -eq '1') -and -not (Test-OriginalState $state $backup)) { throw 'Current policy differs from DriverGuard s last write; restoration refused.' }
    Write-Host "Recorded original: $(if ($backup.OriginalValueExists -eq 'True') {"$($backup.OriginalType) $($backup.OriginalValue)"} else {'value absent'})."
    if (-not (Confirm-Yes 'Restore this exact value?')) { Write-Host 'Cancelled.'; return }
    if (-not (Test-SamePolicyState $state (Read-Policy))) { throw 'Policy changed during confirmation; restoration refused. Inspect the current policy and backup before retrying.' }
    if ($backup.OriginalValueExists -eq 'True') { Set-PolicyValue ([int]$backup.OriginalValue) } else { Remove-PolicyValue }
    $after = Read-Policy
    if (-not (Test-OriginalState $after $backup)) { throw 'Restoration could not be verified; recovery backup retained.' }
    $backup.Phase = 'Restored'; Write-Atomic $script:BackupPath (Format-Backup $backup)
    Write-Log 'Restore' 'SUCCESS' "OriginalValueExists=$($backup.OriginalValueExists); original=$($backup.OriginalType)/$($backup.OriginalValue); result=$(Get-PolicyLabel $after)"
    Write-Host 'Original policy value restored and independently verified. Recovery record retained. Restart recommended.'
}
function Get-GpuVendor([string]$InstanceId) {
    if ($InstanceId -match '^PCI\\VEN_10DE&') { return 'NVIDIA' }
    if ($InstanceId -match '^PCI\\VEN_1002&') { return 'AMD' }
    if ($InstanceId -match '^PCI\\VEN_8086&') { return 'Intel' }
    return $null
}
function Get-Gpus {
    $signed = @(Get-CimInstance Win32_PnPSignedDriver -ErrorAction Stop | Where-Object { $_.ClassGuid -eq $script:DisplayGuid })
    $entities = @(Get-CimInstance Win32_PnPEntity -ErrorAction Stop | Where-Object { $_.PNPClass -eq 'Display' -and $_.PNPDeviceID -match '^PCI\\VEN_(10DE|1002|8086)&' })
    $seen = @{}
    foreach ($entity in $entities) {
        $id = [string]$entity.PNPDeviceID
        if ($seen.ContainsKey($id)) { continue }
        $seen[$id] = $true
        $matches = @($signed | Where-Object { $_.DeviceID -eq $id })
        $driver = $null
        if ($matches.Count -eq 1) { $driver = $matches[0] }
        $hardwareIds = @()
        try { $hardwareIds = @((Get-PnpDeviceProperty -InstanceId $id -KeyName 'DEVPKEY_Device_HardwareIds' -ErrorAction Stop).Data | Where-Object { $_ -match '^PCI\\VEN_[0-9A-F]{4}&DEV_[0-9A-F]{4}' }) } catch { }
        $inf = if ($driver) { [string]$driver.InfName } else { '' }
        $infSource = if ($inf) { 'Win32_PnPSignedDriver' } else { 'Unavailable or ambiguous' }
        try {
            $pnpInf = [string](Get-PnpDeviceProperty -InstanceId $id -KeyName 'DEVPKEY_Device_DriverInfPath' -ErrorAction Stop).Data
            if ($pnpInf) {
                if ($inf -and $inf -ine $pnpInf) { $inf=''; $infSource='Conflicting device properties' }
                else { $inf=$pnpInf; $infSource=$(if ($driver) {'PnP device property and signed driver'} else {'PnP device property only'}) }
            }
        } catch { }
        [pscustomobject]@{
            InstanceId=$id; Vendor=(Get-GpuVendor $id); Model=[string]$entity.Name
            HardwareIds=$hardwareIds; Provider=$(if ($driver) {[string]$driver.DriverProviderName} else {''})
            Version=$(if ($driver) {[string]$driver.DriverVersion} else {''})
            Date=$(if ($driver) {[string]$driver.DriverDate} else {''})
            Inf=$inf; InfSource=$infSource; Status=[string]$entity.Status
        }
    }
}
function Get-DriverPackages {
    $drivers = @(Get-WindowsDriver -Online -ErrorAction Stop)
    foreach ($d in $drivers) {
        if ($d.ClassName -eq 'Display' -and $d.Driver -match '^oem\d+\.inf$') {
            [pscustomobject]@{ Inf=[string]$d.Driver; OriginalInf=[string]$d.OriginalFileName; Provider=[string]$d.ProviderName; Class=[string]$d.ClassName; Version=[string]$d.Version; Date=[string]$d.Date }
        }
    }
}
function Get-UpdateHistory([switch]$Strict) {
    try {
        $session = New-Object -ComObject Microsoft.Update.Session
        $searcher = $session.CreateUpdateSearcher()
        $count = [Math]::Min($searcher.GetTotalHistoryCount(),1000)
        if ($count -eq 0) { return @() }
        return @($searcher.QueryHistory(0,$count) | Where-Object { $_.ResultCode -eq 2 } | ForEach-Object {
            [pscustomobject]@{ Title=[string]$_.Title; Date=$_.Date; Operation=$_.Operation }
        })
    } catch { if ($Strict) { throw }; Write-Warning "Windows Update history unavailable: $($_.Exception.Message)"; return @() }
}
function ConvertFrom-SetupEvidence($Lines,[string]$InstanceId,[string]$Inf) {
    $hits = New-Object Collections.Generic.List[object]
    $section = New-Object Collections.Generic.List[string]
    $inSection = $false
    foreach ($line in $Lines) {
        if ($line -match '^>>>  \[') { $section.Clear(); $inSection=$true }
        if ($inSection) { $section.Add($line) }
        if ($inSection -and $line -match '^<<<  Section end') {
            $header = $section[0]
            $headerMatch = [regex]::Match($header,'^>>>  \[Device Install \(([^]]+)\) - (.+)\]$',[Text.RegularExpressions.RegexOptions]::IgnoreCase)
            if ($headerMatch.Success -and $headerMatch.Groups[2].Value -ieq $InstanceId) {
                $joined = $section -join "`n"
                if ($joined -match "(?i)(?<![a-z0-9_.])$([regex]::Escape($Inf))(?![a-z0-9_.])") {
                    $wu = $headerMatch.Groups[1].Value -match '(?i)^Install Windows Update driver$'
                    $dateMatch = [regex]::Match($joined,'(?im)^>>>  Section start (\d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2}(?:\.\d{1,7})?)$')
                    $started = [datetime]::MinValue
                    if ($dateMatch.Success) {
                        $format = 'yyyy/MM/dd HH:mm:ss'
                        if ($dateMatch.Groups[1].Value.Contains('.')) { $format += '.' + ('f' * ($dateMatch.Groups[1].Value.Length - $dateMatch.Groups[1].Value.LastIndexOf('.') - 1)) }
                        [datetime]::TryParseExact($dateMatch.Groups[1].Value,$format,[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::None,[ref]$started) | Out-Null
                    }
                    $hits.Add([pscustomobject]@{ InstanceId=$InstanceId; Inf=$Inf; WindowsUpdateMarker=$wu; Header=$header; End=$line; Started=$started })
                }
            }
            $inSection=$false
        }
    }
    return @($hits | Select-Object -Last 5)
}
function Get-SetupEvidence([string]$InstanceId,[string]$Inf,[switch]$Strict) {
    if (-not $InstanceId -or $Inf -notmatch '^oem\d+\.inf$') { return @() }
    $path = Join-Path $env:windir 'INF\setupapi.dev.log'
    if (-not (Test-Path -LiteralPath $path)) { if ($Strict) { throw 'SetupAPI.dev.log is missing.' }; return @() }
    try { return @(ConvertFrom-SetupEvidence ([IO.File]::ReadLines($path)) $InstanceId $Inf) }
    catch { if ($Strict) { throw }; Write-Warning "SetupAPI log unavailable: $($_.Exception.Message)"; return @() }
}
function Get-EventEvidence([string]$InstanceId,[switch]$Strict) {
    try {
        return @(Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-DeviceSetupManager/Admin';StartTime=(Get-Date).AddDays(-180)} -MaxEvents 1000 -ErrorAction Stop |
            Where-Object { $_.Message -and $_.Message.IndexOf($InstanceId,[StringComparison]::OrdinalIgnoreCase) -ge 0 } |
            Select-Object -First 5 TimeCreated,Id,ProviderName,Message)
    } catch { if ($Strict) { throw }; return @() }
}
function Classify-Origin($gpu,$updates,$setup,$events,$journal) {
    $evidence = New-Object Collections.Generic.List[string]
    if (-not $gpu.InstanceId -or $gpu.Inf -notmatch '^oem\d+\.inf$') {
        return [pscustomobject]@{ Classification='UNKNOWN'; Evidence=@('Active device-to-INF identity is unavailable.') }
    }
    $bound = @($setup | Where-Object { $_.InstanceId -ieq $gpu.InstanceId -and $_.Inf -ieq $gpu.Inf -and $_.Started -is [datetime] -and $_.Started -ne [datetime]::MinValue } | Sort-Object Started)
    $latest = if ($bound.Count -gt 0) { $bound[-1] } else { $null }
    if (-not $latest) { $evidence.Add('No dated SetupAPI install section matches this device and active INF.') }
    $matchingTitles = @($updates | Where-Object {
        $_.Title -match '(?i)driver|display|graphics' -and $gpu.Model -and
        $_.Title.IndexOf($gpu.Model,[StringComparison]::OrdinalIgnoreCase) -ge 0 -and $_.Date -is [datetime]
    })
    $wu = @()
    if ($latest) {
        $wu = @($matchingTitles | Where-Object { [Math]::Abs(($latest.Started - $_.Date).TotalHours) -le 48 })
        $evidence.Add("Matching device and active INF in SetupAPI: $($latest.Header) [$($latest.Started)]")
    }
    if ($wu.Count -eq 0) { $evidence.Add('No nearby matching Windows Update history item.') }
    if ($wu.Count -gt 0) { $evidence.Add("Nearby Windows Update history title: $($wu[0].Title) [$($wu[0].Date)]") }
    if (@($events).Count -gt 0) { $evidence.Add("Device Setup event: $($events[0].Id) [$($events[0].TimeCreated)]") }
    $journalMatch = $journal -and $journal.State -eq 'Verified' -and $journal.InstanceId -ieq $gpu.InstanceId -and $journal.NewInf -ieq $gpu.Inf -and $journal.NewVersion -eq $gpu.Version
    if ($journalMatch) { $evidence.Add('DriverGuard journal records a verified manufacturer installer and running driver; installer causation is unverified.') }
    if ($latest) {
        $latestRecords = @($bound | Where-Object { $_.Started -eq $latest.Started })
        if ($latestRecords.Count -gt 1 -and @($latestRecords | Where-Object WindowsUpdateMarker).Count -gt 0 -and @($latestRecords | Where-Object { -not $_.WindowsUpdateMarker }).Count -gt 0) {
            $evidence.Add('Latest matching SetupAPI sections have contradictory mechanisms at the same timestamp.')
            return [pscustomobject]@{ Classification='CONFLICTING_EVIDENCE'; Evidence=$evidence.ToArray() }
        }
    }
    if ($latest -and $latest.WindowsUpdateMarker -and $journalMatch) {
        return [pscustomobject]@{ Classification='CONFLICTING_EVIDENCE'; Evidence=$evidence.ToArray() }
    }
    if ($latest -and $latest.WindowsUpdateMarker -and $wu.Count -gt 0) {
        return [pscustomobject]@{ Classification='WINDOWS_UPDATE_CONFIRMED'; Evidence=$evidence.ToArray() }
    }
    if ($latest -and $latest.WindowsUpdateMarker) {
        return [pscustomobject]@{ Classification='PROBABLE_WINDOWS_UPDATE'; Evidence=$evidence.ToArray() }
    }
    if ($journalMatch) { return [pscustomobject]@{ Classification='PROBABLE_MANUFACTURER'; Evidence=$evidence.ToArray() } }
    if ($wu.Count -gt 0) { return [pscustomobject]@{ Classification='PROBABLE_WINDOWS_UPDATE'; Evidence=$evidence.ToArray() } }
    return [pscustomobject]@{ Classification='UNKNOWN'; Evidence=$evidence.ToArray() }
}
function Read-Journal {
    if (-not (Test-Path -LiteralPath $script:JournalPath)) { return $null }
    if ($env:DRIVERGUARD_TEST_MODE -ne '1') { Assert-SecureStatePath $script:DataDir; Assert-SecureStatePath $script:JournalPath }
    $j = Get-Content -LiteralPath $script:JournalPath -Raw | ConvertFrom-Json
    if ($j.Schema -ne 1 -or $j.State -notin @('Started','InstallerExited','PendingRestart','Verified','Failed') -or $j.InstanceId -notmatch '^PCI\\VEN_(10DE|1002|8086)&' -or $j.OldInf -notmatch '^oem\d+\.inf$') { throw 'GPU installation journal is invalid.' }
    return $j
}
function Write-Journal($journal) { Write-Atomic $script:JournalPath ($journal | ConvertTo-Json -Depth 4) }
function Show-GpuInspection {
    $null = Assert-Windows
    $gpus = @(Get-Gpus)
    if ($gpus.Count -eq 0) { Write-Host 'No supported physical PCI NVIDIA, AMD, or Intel display device was found.'; Write-Log 'GPU inspection' 'NO GPU' 'No supported PCI display device'; return }
    $updates = @(Get-UpdateHistory)
    $packages = @()
    try { $packages = @(Get-DriverPackages) } catch { Write-Warning "Driver store inventory unavailable: $($_.Exception.Message)" }
    $journal = $null; try { $journal = Read-Journal } catch { Write-Warning $_.Exception.Message }
    foreach ($gpu in $gpus) {
        $setup = @(Get-SetupEvidence $gpu.InstanceId $gpu.Inf)
        $events = @(Get-EventEvidence $gpu.InstanceId)
        $origin = Classify-Origin $gpu $updates $setup $events $journal
        Write-Host "`n$($gpu.Vendor) — $($gpu.Model)"
        Write-Host "  Instance ID : $($gpu.InstanceId)"
        Write-Host "  Hardware ID : $(if ($gpu.HardwareIds.Count) {$gpu.HardwareIds -join ', '} else {'UNAVAILABLE'})"
        Write-Host "  Provider    : $(if ($gpu.Provider) {$gpu.Provider} else {'UNKNOWN'})"
        Write-Host "  Version/date: $(if ($gpu.Version) {$gpu.Version} else {'UNKNOWN'}) / $(if ($gpu.Date) {$gpu.Date} else {'UNKNOWN'})"
        Write-Host "  Active INF  : $(if ($gpu.Inf) {$gpu.Inf} else {'UNVERIFIED'}) ($($gpu.InfSource))"
        Write-Host "  Device state: $($gpu.Status)"
        Write-Host "  Origin      : $($origin.Classification)"
        foreach ($item in $origin.Evidence) { Write-Host "    Evidence: $item" }
        Write-Log 'GPU inspection' 'OBSERVED' "Instance=$($gpu.InstanceId); INF=$($gpu.Inf); version=$($gpu.Version); origin=$($origin.Classification)"
    }
    Write-Host "`nStaged third-party Display packages:"
    if ($packages.Count -eq 0) { Write-Host '  No packages returned, or inventory unavailable.' }
    foreach ($package in $packages) { Write-Host "  $($package.Inf) | $($package.Provider) | $($package.Version) | $($package.OriginalInf)" }
    Write-Host 'Multiple staged packages do not establish which one installed a device. Active INF is shown per GPU.'
}
function Show-ReadOnlyDiagnostics {
    $failures=New-Object Collections.Generic.List[string]
    $limitations=New-Object Collections.Generic.List[string]
    Write-Host 'DriverGuard read-only diagnostics (no log or state writes)'
    Write-Host "Captured UTC: $((Get-Date).ToUniversalTime().ToString('o'))"
    try { Write-Host "Privileges: $(if (Test-Admin) {'Administrator'} else {'Standard user'})" } catch { Write-Host "Privileges: UNAVAILABLE - $($_.Exception.Message)"; $limitations.Add('Privilege detection unavailable') }
    try { $os=Get-OS; Write-Host "Windows: $($os.Name) | version $($os.Version) | build $($os.Build)" }
    catch { Write-Host "Windows: UNAVAILABLE - $($_.Exception.Message)"; $failures.Add('Windows identity unavailable') }
    $policy=$null
    try {
        $policy=Read-Policy
        Write-Host "Policy: $(Get-PolicyLabel $policy) | key=$($policy.KeyExists) | value=$($policy.ValueExists) | type=$($policy.Type) | data=$($policy.Value)"
        Write-Host 'Policy enforcement: not established by registry inspection.'
    } catch { Write-Host "Policy: UNAVAILABLE - $($_.Exception.Message)"; $failures.Add('Policy read unavailable') }
    try {
        $backup=Read-Backup
        if ($backup) {
            $relation='Policy unavailable'
            if ($policy) {
                if (Test-OriginalState $policy $backup) { $relation='Original state observed' }
                elseif ($policy.Type -eq 'DWord' -and $policy.Value -eq '1') { $relation='DriverGuard target value observed; authorship unverified' }
                else { $relation='Conflict or unsupported current value' }
            }
            Write-Host "Backup: $($backup.Phase) | original key=$($backup.OriginalKeyExists) value=$($backup.OriginalValueExists) type=$($backup.OriginalType) data=$($backup.OriginalValue) | $relation"
        } else { Write-Host 'Backup: MISSING' }
    } catch { Write-Host "Backup: UNAVAILABLE OR INVALID - $($_.Exception.Message)"; $failures.Add('Recovery backup unreadable or invalid') }
    $journal=$null
    try { $journal=Read-Journal; Write-Host "Install journal: $(if ($journal) {$journal.State} else {'MISSING'})" }
    catch { Write-Host "Install journal: UNAVAILABLE OR INVALID - $($_.Exception.Message)"; $failures.Add('Install journal unreadable or invalid') }
    $gpus=@(); $packages=@(); $updates=@(); $updatesAvailable=$false; $packagesAvailable=$false
    try { $gpus=@(Get-Gpus); Write-Host "GPU inventory: $($gpus.Count) supported PCI Display device(s)" }
    catch { Write-Host "GPU inventory: UNAVAILABLE - $($_.Exception.Message)"; $failures.Add('GPU inventory unavailable') }
    try { $packages=@(Get-DriverPackages); $packagesAvailable=$true; Write-Host "Driver store: $($packages.Count) third-party Display package(s)" }
    catch {
        Write-Host "Driver store structured inventory: UNAVAILABLE - $($_.Exception.Message)"
        $limitations.Add('Structured driver store inventory unavailable')
        try {
            $rawPackages=@(& pnputil.exe /enum-drivers /class Display 2>&1)
            if ($LASTEXITCODE -ne 0) { throw "PnPUtil exited with code $LASTEXITCODE" }
            Write-Host 'Driver store fallback: raw PnPUtil Display inventory (compare Published Name to active INF; association unverified)'
            foreach ($line in ($rawPackages | Select-Object -First 120)) { Write-Host "  $line" }
            if ($rawPackages.Count -gt 120) { Write-Host '  [output truncated at 120 lines]' }
        } catch { Write-Host "Driver store fallback: UNAVAILABLE - $($_.Exception.Message)"; $limitations.Add('Driver store fallback unavailable') }
    }
    try { $updates=@(Get-UpdateHistory -Strict); $updatesAvailable=$true; Write-Host "Windows Update history: $($updates.Count) successful item(s) in latest 1000 records" }
    catch { Write-Host "Windows Update history: UNAVAILABLE - $($_.Exception.Message)"; $limitations.Add('Windows Update history unavailable') }
    foreach ($gpu in $gpus) {
        Write-Host "GPU: $($gpu.Vendor) | $($gpu.Model) | $($gpu.InstanceId) | status=$($gpu.Status)"
        Write-Host "  Active driver: INF=$(if ($gpu.Inf) {$gpu.Inf} else {'UNVERIFIED'}) ($($gpu.InfSource)) provider=$(if ($gpu.Provider) {$gpu.Provider} else {'UNKNOWN'}) version=$(if ($gpu.Version) {$gpu.Version} else {'UNKNOWN'}) date=$(if ($gpu.Date) {$gpu.Date} else {'UNKNOWN'})"
        if ($packagesAvailable) {
            $associated=@($packages | Where-Object { $_.Inf -eq $gpu.Inf })
            Write-Host "  Driver store association: $(if ($associated.Count -eq 1) {"UNIQUE | original=$($associated[0].OriginalInf)"} elseif ($associated.Count -eq 0) {'NO MATCH'} else {'AMBIGUOUS'})"
        }
        $setup=@(); $events=@(); $setupAvailable=$false
        if ($gpu.Inf -notmatch '^oem\d+\.inf$') {
            Write-Host '  SetupAPI: UNAVAILABLE - active device INF is unverified'
            $limitations.Add("Active INF unavailable for $($gpu.InstanceId)")
        } else {
            try { $setup=@(Get-SetupEvidence $gpu.InstanceId $gpu.Inf -Strict); $setupAvailable=$true; Write-Host "  SetupAPI: $(if ($setup.Count) {"$($setup.Count) matching section(s)"} else {'NOT FOUND (0 matching sections in available log)'})" }
            catch { Write-Host "  SetupAPI: UNAVAILABLE - $($_.Exception.Message)"; $limitations.Add("SetupAPI evidence unavailable for $($gpu.InstanceId)") }
        }
        try { $events=@(Get-EventEvidence $gpu.InstanceId -Strict); Write-Host "  Device Setup events: $($events.Count) matching event(s)" }
        catch { Write-Host "  Device Setup events: UNAVAILABLE - $($_.Exception.Message)"; $limitations.Add("Device Setup events unavailable for $($gpu.InstanceId)") }
        $origin=Classify-Origin $gpu $updates $setup $events $journal
        Write-Host "  Provenance: $($origin.Classification)$(if (-not $updatesAvailable -or -not $setupAvailable) {' (PARTIAL SOURCES)'})"
        foreach ($item in $origin.Evidence) { Write-Host "    $item" }
    }
    foreach ($reason in $failures) { Write-Host "Failed source: $reason" }
    foreach ($reason in $limitations) { Write-Host "Partial source: $reason" }
    if ($failures.Count -gt 0) { Write-Host 'Diagnose result: FAILED (exit 1)'; return 1 }
    if ($limitations.Count -gt 0) { Write-Host 'Diagnose result: PARTIAL (exit 2)'; return 2 }
    Write-Host 'Diagnose result: COMPLETE (exit 0)'
    return 0
}
function Test-PendingRestart {
    $paths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    )
    foreach ($path in $paths) { if (Test-Path -LiteralPath $path) { return $true } }
    try {
        $sm = Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction Stop
        if ($sm.PendingFileRenameOperations) { return $true }
    } catch [System.Management.Automation.ItemNotFoundException] { } catch [System.Management.Automation.PSArgumentException] { }
    return $false
}
function Get-ApplicableInfModels([string]$Content) {
    $sections = @{}
    $current = ''
    foreach ($raw in ($Content -split "`r?`n")) {
        $line = ($raw -replace ';.*$','').Trim()
        if ($line -match '^\[([^\]]+)\]$') { $current=$matches[1].Trim(); $sections[$current]=New-Object Collections.Generic.List[string]; continue }
        if ($current -and $line) { $sections[$current].Add($line) }
    }
    $arch = if ([Environment]::Is64BitOperatingSystem) { if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'NTarm64' } else { 'NTamd64' } } else { 'NTx86' }
    $models = New-Object Collections.Generic.List[string]
    if (-not $sections.ContainsKey('Manufacturer')) { throw 'INF has no Manufacturer section.' }
    foreach ($line in $sections['Manufacturer']) {
        if ($line -notmatch '^[^=]+\s*=\s*([^,\s]+)\s*(?:,(.*))?$') { continue }
        $base=$matches[1]; $decorations=@()
        if ($matches[2]) { $decorations=@($matches[2] -split '\s*,\s*') } else { $decorations=@('') }
        foreach ($decoration in $decorations) {
            if ($decoration -and $decoration -notmatch "^(?i:$arch)(?:\.|$)") { continue }
            if ($decoration -match "^(?i:$arch)\.") {
                $suffix=$decoration.Substring($arch.Length + 1)
                if ($suffix -notmatch '^(\d+)\.(\d+)(?:\.\.\.(\d+))?$') { continue }
                $osVersion=[Environment]::OSVersion.Version
                if ([int]$matches[1] -gt $osVersion.Major -or ([int]$matches[1] -eq $osVersion.Major -and [int]$matches[2] -gt $osVersion.Minor)) { continue }
                if ($matches[3] -and [int]$matches[3] -gt $osVersion.Build) { continue }
            }
            $name = if ($decoration) { "$base.$decoration" } else { $base }
            if ($sections.ContainsKey($name)) { foreach ($model in $sections[$name]) { $models.Add($model) } }
        }
    }
    return @($models)
}
function Test-InstallerCompatibility($gpu,[string]$Installer,[string]$InfPath) {
    if (-not $gpu -or $gpu.Vendor -notin @('NVIDIA','AMD','Intel')) { throw 'Select a supported physical GPU.' }
    if (-not (Test-Path -LiteralPath $Installer -PathType Leaf) -or [IO.Path]::GetExtension($Installer) -ne '.exe') { throw 'Installer must be an existing EXE file.' }
    if (-not (Test-Path -LiteralPath $InfPath -PathType Leaf) -or [IO.Path]::GetExtension($InfPath) -ne '.inf') { throw 'A matching extracted INF file is required.' }
    $exe = (Resolve-Path -LiteralPath $Installer).ProviderPath
    $inf = (Resolve-Path -LiteralPath $InfPath).ProviderPath
    foreach ($path in @($exe,$inf)) { if ((Get-Item -LiteralPath $path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Installer package paths cannot be reparse points.' } }
    $root = [IO.Path]::GetDirectoryName($exe).TrimEnd('\') + '\'
    if (-not $inf.StartsWith($root,[StringComparison]::OrdinalIgnoreCase)) { throw 'INF must be inside the installer package directory.' }
    $parent = [IO.Path]::GetDirectoryName($inf)
    while ($parent -and $parent.Length -ge $root.Length) {
        if ((Get-Item -LiteralPath $parent -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Installer package tree cannot contain a junction or symbolic link.' }
        $parent = [IO.Path]::GetDirectoryName($parent)
    }
    $exeSignature = Get-AuthenticodeSignature -LiteralPath $exe
    $infSignature = Get-AuthenticodeSignature -LiteralPath $inf
    if ($exeSignature.Status -ne 'Valid' -or $infSignature.Status -ne 'Valid') { throw 'Installer and INF must both have valid trusted Authenticode/catalog signatures.' }
    $pattern = switch ($gpu.Vendor) {
        'NVIDIA' { 'NVIDIA' }
        'AMD' { 'Advanced Micro Devices|AMD' }
        'Intel' { 'Intel' }
    }
    if ($exeSignature.SignerCertificate.Subject -notmatch $pattern) { throw 'Installer signer does not match the GPU manufacturer.' }
    if ($infSignature.SignerCertificate.Subject -notmatch $pattern -and $infSignature.SignerCertificate.Subject -notmatch 'Microsoft Windows Hardware Compatibility Publisher|Microsoft Windows') { throw 'INF signer is neither the GPU manufacturer nor Microsoft hardware certification.' }
    $content = Get-Content -LiteralPath $inf -Raw -Encoding Default
    if ($content -notmatch '(?im)^\s*Class\s*=\s*Display\s*$') { throw 'INF is not a Display-class driver.' }
    $device = [regex]::Match($gpu.InstanceId,'(?i)^PCI\\VEN_([0-9A-F]{4})&DEV_([0-9A-F]{4})')
    if (-not $device.Success) { throw 'GPU hardware ID cannot be verified.' }
    $needle = 'PCI\VEN_' + $device.Groups[1].Value + '&DEV_' + $device.Groups[2].Value
    $models = @(Get-ApplicableInfModels $content)
    if (@($models | Where-Object { $_ -match '(?i)=\s*[^,]+\s*,\s*' + [regex]::Escape($needle) + '(?:&[^,\s]*)?(?:\s*,|\s*$)' }).Count -eq 0) { throw 'INF has no exact vendor/device match in an applicable architecture model section.' }
    $versions = @([regex]::Matches($content,'(?im)^\s*DriverVer\s*=\s*[^,\r\n]+,\s*([0-9]+(?:\.[0-9]+){1,3})') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
    if ($versions.Count -ne 1) { throw 'INF driver version cannot be established unambiguously.' }
    return [pscustomobject]@{ Installer=$exe; InfPath=$inf; Version=$versions[0]; InstallerHash=(Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash; InfHash=(Get-FileHash -LiteralPath $inf -Algorithm SHA256).Hash; Signer=$exeSignature.SignerCertificate.Subject }
}
function Select-Gpu {
    $gpus = @(Get-Gpus)
    if ($gpus.Count -eq 0) { throw 'No supported physical GPU found.' }
    for ($i=0; $i -lt $gpus.Count; $i++) { Write-Host "[$($i+1)] $($gpus[$i].Vendor) $($gpus[$i].Model) | $($gpus[$i].InstanceId) | $($gpus[$i].Inf)" }
    $answer = Read-Host 'Select GPU number'
    $number = 0
    if (-not [int]::TryParse($answer,[ref]$number) -or $number -lt 1 -or $number -gt $gpus.Count) { throw 'Invalid GPU selection.' }
    return $gpus[$number-1]
}
function Install-GpuDriver {
    $null = Assert-Windows
    if (Request-Elevation 'Install') { return }
    if (Test-PendingRestart) { throw 'A restart is already pending. Restart Windows before starting driver installation.' }
    $gpu = Select-Gpu
    if ($gpu.Inf -notmatch '^oem\d+\.inf$') { throw 'Current installed INF cannot be identified as an exportable third-party package.' }
    $packages = @(Get-DriverPackages | Where-Object { $_.Inf -eq $gpu.Inf })
    if ($packages.Count -ne 1) { throw 'Current Display package cannot be identified uniquely.' }
    $installer = Read-Host 'Full path to the manufacturer installer EXE'
    $inf = Read-Host 'Full path to its extracted matching Display INF'
    $checked = Test-InstallerCompatibility $gpu $installer $inf
    Write-Host "Verified signer: $($checked.Signer)"
    Write-Host "Matching INF version: $($checked.Version)"
    Write-Host "Target GPU: $($gpu.Model) | $($gpu.InstanceId)"
    Write-Host "Current: $($gpu.Version) | $($gpu.Inf)"
    Write-Host 'Recommend creating a restore point first. The manufacturer installer may require a restart.'
    if (-not (Confirm-Yes 'Run this manufacturer installer interactively?')) { Write-Host 'Cancelled.'; return }
    Protect-DataDirectory
    $oldExport = Join-Path $script:DataDir ("preinstall-$($gpu.Inf)-" + (Get-Date -Format 'yyyyMMddHHmmss'))
    New-Item -ItemType Directory -Path $oldExport -ErrorAction Stop | Out-Null
    & pnputil.exe /export-driver $gpu.Inf $oldExport | Out-Host
    if ($LASTEXITCODE -ne 0 -or @(Get-ChildItem -LiteralPath $oldExport -Recurse -File -ErrorAction Stop).Count -eq 0) { throw 'Current package export failed; installation not started.' }
    Write-Log 'GPU install' 'EXPORTED' "INF=$($gpu.Inf); destination=$oldExport"
    $journal = [pscustomobject]@{
        Schema=1; State='Started'; InstanceId=$gpu.InstanceId; Vendor=$gpu.Vendor; Model=$gpu.Model
        OldInf=$gpu.Inf; OldVersion=$gpu.Version; OldProvider=$gpu.Provider; ExpectedVersion=$checked.Version
        Installer=$checked.Installer; InstallerHash=$checked.InstallerHash; InfPath=$checked.InfPath; InfHash=$checked.InfHash; OldExport=$oldExport
        NewInf=''; NewVersion=''; StartedUtc=(Get-Date).ToUniversalTime().ToString('o'); VerifiedUtc=''; ExitCode=$null
    }
    Write-Journal $journal
    Write-Log 'GPU install' 'STARTED' "Instance=$($gpu.InstanceId); old=$($gpu.Inf)/$($gpu.Version); installerHash=$($checked.InstallerHash)"
    if ((Get-FileHash -LiteralPath $checked.Installer -Algorithm SHA256).Hash -ne $checked.InstallerHash -or (Get-FileHash -LiteralPath $checked.InfPath -Algorithm SHA256).Hash -ne $checked.InfHash) {
        $journal.State='Failed'; Write-Journal $journal
        throw 'Installer package changed after validation; launch refused.'
    }
    $process = Start-Process -FilePath $checked.Installer -Wait -PassThru
    $journal.ExitCode = $process.ExitCode
    if ($process.ExitCode -notin @(0,3010)) {
        $journal.State='Failed'; Write-Journal $journal
        Write-Log 'GPU install' 'FAILED' "Installer exit=$($process.ExitCode); instance=$($gpu.InstanceId)"
        throw "Manufacturer installer exited with code $($process.ExitCode). No success claimed."
    }
    $journal.State='InstallerExited'; Write-Journal $journal
    Write-Log 'GPU install' 'INSTALLER EXITED' "Exit=$($process.ExitCode); awaiting device verification"
    Verify-GpuDriver
}
function Verify-GpuDriver {
    $null = Assert-Windows
    if (Request-Elevation 'Verify') { return }
    $journal = Read-Journal
    if (-not $journal) { throw 'No GPU installation journal exists.' }
    if ($journal.State -eq 'Failed') { throw 'Recorded installer failed. Start a new guided installation.' }
    if ($journal.State -eq 'Started') { throw 'Installer execution was interrupted or has not returned; verification cannot claim success.' }
    $gpus = @(Get-Gpus | Where-Object { $_.InstanceId -eq $journal.InstanceId })
    if ($gpus.Count -ne 1) { throw 'Target GPU cannot be uniquely detected; verification deferred.' }
    $gpu=$gpus[0]
    if (Test-PendingRestart) {
        $journal.State='PendingRestart'; Write-Journal $journal
        Write-Log 'GPU verify' 'PENDING RESTART' "Instance=$($gpu.InstanceId); observed=$($gpu.Inf)/$($gpu.Version)"
        Write-Host 'Windows reports a pending restart. Reboot, then choose Verify installation. Cleanup is unavailable.'
        return
    }
    $vendorPattern = switch ($journal.Vendor) { 'NVIDIA' { 'NVIDIA' } 'AMD' { 'Advanced Micro Devices|AMD' } 'Intel' { 'Intel' } }
    if ($gpu.Inf -eq $journal.OldInf -or $gpu.Version -ne $journal.ExpectedVersion -or $gpu.Status -ne 'OK' -or $gpu.Provider -notmatch $vendorPattern) {
        $journal.State='Failed'; Write-Journal $journal
        Write-Log 'GPU verify' 'FAILED' "Expected version=$($journal.ExpectedVersion); observed=$($gpu.Inf)/$($gpu.Version); status=$($gpu.Status)"
        throw 'Replacement driver is not demonstrably running on the target GPU. No cleanup offered.'
    }
    $journal.NewInf=$gpu.Inf; $journal.NewVersion=$gpu.Version; $journal.VerifiedUtc=(Get-Date).ToUniversalTime().ToString('o'); $journal.State='Verified'
    Write-Journal $journal
    Write-Log 'GPU verify' 'SUCCESS' "Instance=$($gpu.InstanceId); active=$($gpu.Inf)/$($gpu.Version); prior=$($journal.OldInf)"
    Write-Host "Verified running replacement: $($gpu.Model), version $($gpu.Version), INF $($gpu.Inf)."
    Write-Host "Old package $($journal.OldInf) may be reviewed separately for optional cleanup."
}
function Test-CleanupEligibility($journal,$gpu,$packages,$allSigned) {
    if ($journal.State -ne 'Verified') { return 'Replacement has not been verified.' }
    if ($gpu.InstanceId -ne $journal.InstanceId -or $gpu.Inf -ne $journal.NewInf -or $gpu.Version -ne $journal.NewVersion -or $gpu.Status -ne 'OK') { return 'Verified replacement is no longer active.' }
    if ($journal.OldInf -eq $gpu.Inf -or $journal.OldInf -notmatch '^oem\d+\.inf$') { return 'Old package is active or invalid.' }
    if ($null -eq $allSigned) { return 'Device usage inventory is unavailable.' }
    if (@($allSigned | Where-Object { $_.InfName -eq $journal.OldInf }).Count -gt 0) { return 'Old package is still used by another device.' }
    if (@($allSigned | Where-Object { $_.UsageUnknown }).Count -gt 0) { return 'Device usage is uncertain.' }
    $matches = @($packages | Where-Object { $_.Inf -eq $journal.OldInf })
    if ($matches.Count -ne 1 -or $matches[0].Class -ne 'Display') { return 'Old Display package is not uniquely identified.' }
    return $null
}
function Get-DeviceUsageInventory {
    $signed = @(Get-CimInstance Win32_PnPSignedDriver -ErrorAction Stop)
    $devices = @(Get-PnpDevice -ErrorAction Stop)
    $inventory = New-Object Collections.Generic.List[object]
    foreach ($driver in $signed) {
        if (-not $driver.DeviceID -or -not $driver.InfName) { if ($driver.ClassGuid -eq $script:DisplayGuid) { $inventory.Add([pscustomobject]@{ InfName=''; UsageUnknown=$true }) }; continue }
        $inventory.Add([pscustomobject]@{ InfName=[string]$driver.InfName; UsageUnknown=$false })
    }
    foreach ($device in $devices) {
        if ($device.Class -ne 'Display' -and $device.ClassGuid -ne $script:DisplayGuid) { continue }
        if (-not $device.InstanceId) { $inventory.Add([pscustomobject]@{ InfName=''; UsageUnknown=$true }); continue }
        try {
            $property = Get-PnpDeviceProperty -InstanceId $device.InstanceId -KeyName 'DEVPKEY_Device_DriverInfPath' -ErrorAction Stop
            $inf = [string]$property.Data
            if (-not $inf) { throw 'INF path unavailable' }
            $inventory.Add([pscustomobject]@{ InfName=$inf; UsageUnknown=$false })
        } catch { $inventory.Add([pscustomobject]@{ InfName=''; UsageUnknown=$true }) }
    }
    return $inventory.ToArray()
}
function Cleanup-GpuDriver {
    $null = Assert-Windows
    if (Request-Elevation 'Cleanup') { return }
    if (Test-PendingRestart) { throw 'Restart is pending; cleanup refused.' }
    $journal = Read-Journal
    if (-not $journal) { throw 'No verified replacement record exists.' }
    $gpu = @(Get-Gpus | Where-Object { $_.InstanceId -eq $journal.InstanceId })
    if ($gpu.Count -ne 1) { throw 'Target GPU cannot be uniquely detected.' }
    $packages = @(Get-DriverPackages)
    $signed = @(Get-DeviceUsageInventory)
    $reason = Test-CleanupEligibility $journal $gpu[0] $packages $signed
    if ($reason) { Write-Log 'GPU cleanup' 'REFUSED' $reason; throw $reason }
    Write-Host "Obsolete package: $($journal.OldInf), previously used by $($journal.Model)."
    Write-Host "Active replacement: $($gpu[0].Inf), version $($gpu[0].Version)."
    Write-Host 'DriverGuard will export this specific old package, then request a non-forced PnPUtil deletion.'
    if (-not (Confirm-Yes "Remove only $($journal.OldInf)?")) { Write-Host 'Cancelled.'; return }
    $reason = Test-CleanupEligibility $journal (@(Get-Gpus | Where-Object { $_.InstanceId -eq $journal.InstanceId }) | Select-Object -First 1) @(Get-DriverPackages) @(Get-DeviceUsageInventory)
    if ($reason -or (Test-PendingRestart)) { throw "Cleanup conditions changed: $reason" }
    $export = Join-Path $script:DataDir ("export-$($journal.OldInf)-" + (Get-Date -Format 'yyyyMMddHHmmss'))
    Protect-DataDirectory
    New-Item -ItemType Directory -Path $export -ErrorAction Stop | Out-Null
    & pnputil.exe /export-driver $journal.OldInf $export | Out-Host
    if ($LASTEXITCODE -ne 0 -or @(Get-ChildItem -LiteralPath $export -Recurse -File -ErrorAction Stop).Count -eq 0) { throw 'Specific package export failed; deletion refused.' }
    Write-Log 'GPU cleanup' 'EXPORTED' "INF=$($journal.OldInf); destination=$export"
    & pnputil.exe /delete-driver $journal.OldInf | Out-Host
    $code=$LASTEXITCODE
    $remaining = @(Get-DriverPackages | Where-Object { $_.Inf -eq $journal.OldInf })
    $running = @(Get-Gpus | Where-Object { $_.InstanceId -eq $journal.InstanceId })
    $replacementHealthy = $running.Count -eq 1 -and $running[0].Inf -eq $journal.NewInf -and $running[0].Version -eq $journal.NewVersion -and $running[0].Status -eq 'OK'
    if ($code -ne 0 -or $remaining.Count -ne 0 -or -not $replacementHealthy) {
        Write-Log 'GPU cleanup' 'FAILED' "INF=$($journal.OldInf); pnputil exit=$code; stillPresent=$($remaining.Count -gt 0); replacementHealthy=$replacementHealthy"
        throw 'PnPUtil deletion did not complete and verify; no success claimed.'
    }
    Write-Log 'GPU cleanup' 'SUCCESS' "Deleted=$($journal.OldInf); active=$($gpu[0].Inf); export=$export"
    Write-Host "Removed $($journal.OldInf). Export retained at $export."
}
function Show-Help {
    Write-Host @'
DriverGuard configures the Windows Update "Do not include drivers with Windows Updates"
policy. It does not turn off Windows Update, Defender, security updates, or manual
manufacturer installations. Windows may still install drivers through feature
updates, critical/security packages, device setup, management tools, or other paths.

Enable saves the first observed policy value in ProgramData\DriverGuard, then sets
only ExcludeWUDriversInQualityUpdate to REG_DWORD 1. Restore uses that saved value,
preserving the difference between absent and DWORD 0. A conflicting external change
blocks automatic restoration. The recovery record and log remain after restoration.

GPU inspection reads device, Windows Update, SetupAPI, event, and driver store data.
Origin may remain unknown. Guided installation requires a trusted signed EXE and a
matching signed Display INF in the same extracted package tree. It opens the vendor
installer interactively and verifies the running driver afterward or after reboot.
Only a verified replacement permits review of a single obsolete Display package.
Cleanup requires confirmation and exports that package before non-forced deletion.

Windows 10 standard support ended October 14, 2025. Driver exclusion does not
replace security updates or extend operating-system support.
'@
    Write-Host "Persistent state: $($script:DataDir)"
}
if ($env:DRIVERGUARD_TEST_MODE -ne '1') {
    try {
        switch ($Action) {
            'Summary' { Show-Status -Brief }
            'Enable' { Enable-Protection }
            'Restore' { Restore-Protection }
            'Status' { Show-Status; Write-Log 'Policy status' 'OBSERVED' (Get-PolicyLabel (Read-Policy)) }
            'Log' {
                $found=$false
                foreach ($path in @($script:LogPath,$script:UserLogPath)) {
                    if (Test-Path -LiteralPath $path) { Write-Host "Log: $path"; Get-Content -LiteralPath $path -Tail 200; $found=$true }
                }
                if (-not $found) { Write-Host 'No activity log exists yet.' }
            }
            'Help' { Show-Help }
            'Inspect' { Show-GpuInspection }
            'Diagnose' { $diagnoseCode=Show-ReadOnlyDiagnostics; exit $diagnoseCode }
            'Install' { Install-GpuDriver }
            'Verify' { Verify-GpuDriver }
            'Cleanup' { Cleanup-GpuDriver }
        }
    } catch {
        Write-Host "DriverGuard error: $($_.Exception.Message)" -ForegroundColor Red
        if ($Action -eq 'Diagnose') { Write-Host 'Diagnose result: FAILED (exit 1)' }
        else { Write-Log $Action 'FAILED' $_.Exception.Message }
        exit 1
    }
}
