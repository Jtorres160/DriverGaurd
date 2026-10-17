$ErrorActionPreference = 'Stop'
$env:DRIVERGUARD_TEST_MODE = '1'
. (Join-Path $PSScriptRoot '..\DriverGuard.ps1')
$script:passed=0
$script:failed=0
function Check([bool]$Condition,[string]$Name) {
    if ($Condition) { $script:passed++; Write-Host "PASS $Name" }
    else { $script:failed++; Write-Host "FAIL $Name" }
}
function Throws([scriptblock]$Block,[string]$Name) {
    try { & $Block; Check $false $Name } catch { Check $true $Name }
}
& {
    # Exercise the real Windows file replacement without requiring admin ACLs on a test fixture.
    function Assert-SecureStatePath([string]$Path) { if (-not (Test-Path -LiteralPath $Path)) { throw 'Test replacement is missing.' } }
    $dir=Join-Path $PSScriptRoot ('atomic-fixture-'+[guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($dir) | Out-Null
    try {
        $dest=Join-Path $dir 'original-state.ini'
        $next=Join-Path $dir 'next.tmp'
        [IO.File]::WriteAllText($dest,'Phase=Prepared')
        [IO.File]::WriteAllText($next,'Phase=Active')
        Replace-ExistingFile $next $dest 'Phase=Active'
        Check (([IO.File]::ReadAllText($dest) -ceq 'Phase=Active') -and -not [IO.File]::Exists($next) -and @(Get-ChildItem -LiteralPath $dir -File).Count -eq 1) 'Real existing-file replacement advances Prepared to Active'
        Throws { Replace-ExistingFile (Join-Path $dir 'missing.tmp') $dest 'Phase=Restored' } 'Failed replacement reports an error'
        Check ([IO.File]::ReadAllText($dest) -ceq 'Phase=Active') 'Failed replacement retains current recovery state'
        [IO.File]::WriteAllText($next,'Phase=Restored')
        Throws { Replace-ExistingFile $next $dest 'unexpected content' } 'Failed readback reports an error'
        $previous=@(Get-ChildItem -LiteralPath $dir -File | Where-Object { $_.FullName -ne $dest })
        Check (([IO.File]::ReadAllText($dest) -ceq 'Phase=Restored') -and $previous.Count -eq 1 -and [IO.File]::ReadAllText($previous[0].FullName) -ceq 'Phase=Active') 'Failed readback retains prior recovery data'
    } finally {
        foreach ($file in @(Get-ChildItem -LiteralPath $dir -File)) { [IO.File]::Delete($file.FullName) }
        [IO.Directory]::Delete($dir)
    }
}
function New-Gpu([string]$Vendor,[string]$Id,[string]$Inf='oem1.inf',[string]$Version='1.0') {
    [pscustomobject]@{ Vendor=$Vendor; InstanceId=$Id; Model="$Vendor Graphics"; HardwareIds=@($Id); Provider=$Vendor; Inf=$Inf; InfSource='Fixture'; Version=$Version; Status='OK'; Date='2026-01-01' }
}
function New-Journal([string]$State='InstallerExited') {
    [pscustomobject]@{ Schema=1; State=$State; InstanceId='PCI\VEN_10DE&DEV_1234\A'; Vendor='NVIDIA'; Model='NVIDIA Graphics'; OldInf='oem1.inf'; OldVersion='1.0'; OldProvider='NVIDIA'; ExpectedVersion='2.0'; NewInf=''; NewVersion=''; VerifiedUtc='' }
}

Check ((Get-GpuVendor 'PCI\VEN_10DE&DEV_1234\A') -eq 'NVIDIA') 'NVIDIA vendor detection'
Check ((Get-GpuVendor 'PCI\VEN_1002&DEV_1234\A') -eq 'AMD') 'AMD vendor detection'
Check ((Get-GpuVendor 'PCI\VEN_8086&DEV_1234\A') -eq 'Intel') 'Intel integrated vendor detection'
Check ((Get-GpuVendor 'ROOT\DISPLAY\1') -eq $null) 'Nonphysical display excluded'

$script:testEntities = @(
    [pscustomobject]@{ PNPClass='Display'; PNPDeviceID='PCI\VEN_8086&DEV_1234\I'; Name='Intel UHD'; Status='OK' },
    [pscustomobject]@{ PNPClass='Display'; PNPDeviceID='PCI\VEN_10DE&DEV_5678\N'; Name='NVIDIA RTX'; Status='OK' },
    [pscustomobject]@{ PNPClass='Display'; PNPDeviceID='ROOT\DISPLAY\V'; Name='Virtual Display'; Status='OK' }
)
$script:testSigned = @(
    [pscustomobject]@{ ClassGuid=$script:DisplayGuid; DeviceID='PCI\VEN_8086&DEV_1234\I'; DriverProviderName='Intel'; DriverVersion='31.0'; DriverDate='2026-01-01'; InfName='oem2.inf' },
    [pscustomobject]@{ ClassGuid=$script:DisplayGuid; DeviceID='PCI\VEN_10DE&DEV_5678\N'; DriverProviderName='NVIDIA'; DriverVersion='32.0'; DriverDate='2026-02-01'; InfName='oem3.inf' }
)
function Get-CimInstance([string]$ClassName) { if ($ClassName -eq 'Win32_PnPEntity') { return $script:testEntities }; if ($ClassName -eq 'Win32_PnPSignedDriver') { return $script:testSigned } }
function Get-PnpDeviceProperty { param([string]$InstanceId,[string]$KeyName) if ($KeyName -eq 'DEVPKEY_Device_DriverInfPath') { return [pscustomobject]@{ Data=$(if ($InstanceId -match '8086') {'oem2.inf'} else {'oem3.inf'}) } }; throw 'Hardware ID property unavailable' }
$hybrid=@(Get-Gpus)
Check ($hybrid.Count -eq 2 -and $hybrid[0].Vendor -eq 'Intel' -and $hybrid[1].Vendor -eq 'NVIDIA') 'Hybrid graphics detection'
Check ($hybrid[0].Inf -eq 'oem2.inf' -and $hybrid[1].Inf -eq 'oem3.inf') 'Per-device active INF mapping'
Check (@($hybrid[0].HardwareIds).Count -eq 0) 'Unverified hardware IDs are not fabricated from instance IDs'
$script:testEntities += $script:testEntities[0]
Check (@(Get-Gpus).Count -eq 2) 'Duplicate entity rows do not duplicate a GPU'
$script:testEntities = @($script:testEntities | Select-Object -First 3)
function Get-PnpDeviceProperty { param([string]$InstanceId,[string]$KeyName) if ($KeyName -eq 'DEVPKEY_Device_DriverInfPath') { [pscustomobject]@{ Data='oem99.inf' } } else { throw 'Unavailable' } }
Check (-not (@(Get-Gpus | Where-Object { $_.Vendor -eq 'NVIDIA' })[0].Inf)) 'Conflicting device INF sources remain unverified'
function Get-PnpDeviceProperty { param([string]$InstanceId,[string]$KeyName) throw 'Unavailable' }
Check (@(Get-Gpus | Where-Object { $_.Vendor -eq 'NVIDIA' })[0].Inf -eq 'oem3.inf') 'Signed-driver binding remains available when PnP property is unavailable'

$gpu=New-Gpu 'NVIDIA' 'PCI\VEN_10DE&DEV_1234\A'
$unknown=Classify-Origin $gpu @() @() @() $null
Check ($unknown.Classification -eq 'UNKNOWN') 'Missing Windows Update history yields unknown'
$providerOnly=Classify-Origin $gpu @([pscustomobject]@{ Title='NVIDIA Display Driver'; Date=(Get-Date) }) @() @() $null
Check ($providerOnly.Classification -eq 'UNKNOWN') 'Provider/title alone cannot establish provenance'
$setup=@([pscustomobject]@{ InstanceId=$gpu.InstanceId; Inf=$gpu.Inf; WindowsUpdateMarker=$false; Header='Device install'; Started=(Get-Date) })
$history=@([pscustomobject]@{ Title='NVIDIA Graphics driver'; Date=(Get-Date) })
Check ((Classify-Origin $gpu $history $setup @() $null).Classification -eq 'UNKNOWN') 'Matching WU title does not establish an unmarked active installation mechanism'
$unmarkedWithTitle=Classify-Origin $gpu $history $setup @() $null
Check (@($unmarkedWithTitle.Evidence | Where-Object { $_ -match 'does not identify the mechanism' }).Count -eq 1) 'Unknown result explains the limit of nearby WU title evidence'
$setup[0].WindowsUpdateMarker=$true
Check ((Classify-Origin $gpu $history $setup @() $null).Classification -eq 'WINDOWS_UPDATE_CONFIRMED') 'Explicit WU SetupAPI evidence'
$setup[0].Started=(Get-Date).AddDays(-10)
Check ((Classify-Origin $gpu $history $setup @() $null).Classification -eq 'PROBABLE_WINDOWS_UPDATE') 'Exact SetupAPI WU marker without nearby history remains probable'
$setup=@([pscustomobject]@{ InstanceId=$gpu.InstanceId; Inf=$gpu.Inf; WindowsUpdateMarker=$true; Header='old install'; Started=(Get-Date).AddDays(-10) },[pscustomobject]@{ InstanceId=$gpu.InstanceId; Inf=$gpu.Inf; WindowsUpdateMarker=$false; Header='new install'; Started=(Get-Date) })
Check ((Classify-Origin $gpu $history $setup @() $null).Classification -eq 'UNKNOWN') 'Newer unmarked active installation supersedes old WU marker despite matching history title'
$setup=@([pscustomobject]@{ InstanceId='PCI\VEN_1002&DEV_1234\B'; Inf='oem8.inf'; WindowsUpdateMarker=$true; Header='other GPU'; Started=(Get-Date) })
Check ((Classify-Origin $gpu $history $setup @() $null).Classification -eq 'UNKNOWN') 'Other GPU SetupAPI evidence cannot establish origin'
Check ((Classify-Origin (New-Gpu 'NVIDIA' $gpu.InstanceId '') $history $setup @() $null).Classification -eq 'UNKNOWN') 'Missing active INF blocks provenance inference'
$setup=@([pscustomobject]@{ InstanceId=$gpu.InstanceId; Inf=$gpu.Inf; WindowsUpdateMarker=$true; Header='matching install'; Started=(Get-Date) })
$conflictJournal=New-Journal 'Verified'; $conflictJournal.NewInf=$gpu.Inf; $conflictJournal.NewVersion=$gpu.Version
Check ((Classify-Origin $gpu $history $setup @() $conflictJournal).Classification -eq 'CONFLICTING_EVIDENCE') 'Conflicting journal and SetupAPI evidence is explicit'
Check ((Classify-Origin $gpu @() @() @() $conflictJournal).Classification -eq 'PROBABLE_MANUFACTURER') 'Verified installer journal remains probable without independent causation'
Check ((Classify-Origin $gpu @() @() @() $conflictJournal).Classification -ne 'MANUFACTURER_INSTALLER_CONFIRMED') 'Claimed manufacturer installer lacks independent confirmation'
foreach ($vendorGpu in @((New-Gpu 'AMD' 'PCI\VEN_1002&DEV_1234\A' 'oem4.inf'),(New-Gpu 'Intel' 'PCI\VEN_8086&DEV_1234\A' 'oem5.inf'))) {
    $vendorHistory=@([pscustomobject]@{ Title="$($vendorGpu.Model) display driver"; Date=(Get-Date) })
    $vendorSetup=@([pscustomobject]@{ InstanceId=$vendorGpu.InstanceId; Inf=$vendorGpu.Inf; WindowsUpdateMarker=$true; Header='device install'; Started=(Get-Date) })
    Check ((Classify-Origin $vendorGpu $vendorHistory $vendorSetup @() $null).Classification -eq 'WINDOWS_UPDATE_CONFIRMED') "$($vendorGpu.Vendor) synthetic Windows Update correlation"
}
$stagedGpu=New-Gpu 'NVIDIA' $gpu.InstanceId 'oem77.inf'
Check ((Classify-Origin $stagedGpu $history $setup @() $null).Classification -eq 'UNKNOWN') 'Matching staged INF cannot establish active-driver provenance'
$wrongVersionJournal=New-Journal 'Verified'; $wrongVersionJournal.NewInf=$gpu.Inf; $wrongVersionJournal.NewVersion='older'
Check ((Classify-Origin $gpu @() @() @() $wrongVersionJournal).Classification -eq 'UNKNOWN') 'Verified journal for another version cannot establish current origin'
$logLines=@(
    ">>>  [Device Install (Install Windows Update driver) - $($gpu.InstanceId)]",
    '>>>  Section start 2026/10/15 18:05:47.534',
    '     dvi: Selected Driver: oem1.inf',
    '<<<  Section end 2026/10/15 18:05:48.000'
)
$parsed=@(ConvertFrom-SetupEvidence $logLines $gpu.InstanceId $gpu.Inf)
Check ($parsed.Count -eq 1 -and $parsed[0].WindowsUpdateMarker -and $parsed[0].Started.Year -eq 2026 -and $parsed[0].Started.Millisecond -eq 534) 'Fractional SetupAPI timestamp and explicit update mechanism parsed'
Check (@(ConvertFrom-SetupEvidence $logLines $gpu.InstanceId 'oem9.inf').Count -eq 0) 'Active INF mismatch rejects SetupAPI section'
Check (@(ConvertFrom-SetupEvidence $logLines 'PCI\VEN_10DE&DEV_1234\B' $gpu.Inf).Count -eq 0) 'Exact device mismatch rejects SetupAPI section'
$stagedLines=@('>>>  [Setup Import Driver Package - C:\Temp\oem1.inf]','>>>  Section start 2026/10/15 18:05:47.534',"     dvi: $($gpu.InstanceId)",'<<<  Section end 2026/10/15 18:05:48.000')
Check (@(ConvertFrom-SetupEvidence $stagedLines $gpu.InstanceId $gpu.Inf).Count -eq 0) 'Staged package import is not device installation evidence'
$incidentalLines=@(">>>  [Device Install (Hardware initiated) - $($gpu.InstanceId)]",'>>>  Section start 2026/10/15 18:05:47.534','     dvi: Selected Driver: oem1.inf','     dvi: Windows Update search skipped','<<<  Section end 2026/10/15 18:05:48.000')
Check (-not @(ConvertFrom-SetupEvidence $incidentalLines $gpu.InstanceId $gpu.Inf)[0].WindowsUpdateMarker) 'Incidental Windows Update text does not establish mechanism'
$manualLines=@(">>>  [Device Install (UpdateDriverForPlugAndPlayDevices) - $($gpu.InstanceId)]",'>>>  Section start 2026/10/15 18:05:47.534','     dvi: Selected Driver: oem1.inf','<<<  Section end 2026/10/15 18:05:48.000')
Check (-not @(ConvertFrom-SetupEvidence $manualLines $gpu.InstanceId $gpu.Inf)[0].WindowsUpdateMarker) 'Manual device update is not marked as Windows Update'
$manualEvidence=@(ConvertFrom-SetupEvidence $manualLines $gpu.InstanceId $gpu.Inf)
Check ((Classify-Origin $gpu @() $manualEvidence @() $null).Classification -eq 'UNKNOWN') 'Manual device installation without source proof remains unknown'
$reinstallEvidence=@([pscustomobject]@{ InstanceId=$gpu.InstanceId; Inf=$gpu.Inf; WindowsUpdateMarker=$true; Header='earlier WU'; Started=(Get-Date).AddDays(-2) },[pscustomobject]@{ InstanceId=$gpu.InstanceId; Inf=$gpu.Inf; WindowsUpdateMarker=$false; Header='same-version reinstall'; Started=(Get-Date) })
Check ((Classify-Origin $gpu @() $reinstallEvidence @() $null).Classification -eq 'UNKNOWN') 'Same-version reinstall supersedes earlier WU mechanism'
$sameTime=@([pscustomobject]@{ InstanceId=$gpu.InstanceId; Inf=$gpu.Inf; WindowsUpdateMarker=$true; Header='WU'; Started=(Get-Date) },[pscustomobject]@{ InstanceId=$gpu.InstanceId; Inf=$gpu.Inf; WindowsUpdateMarker=$false; Header='manual'; Started=(Get-Date) })
$sameTime[1].Started=$sameTime[0].Started
Check ((Classify-Origin $gpu $history $sameTime @() $null).Classification -eq 'CONFLICTING_EVIDENCE') 'Same-time contradictory install sections remain conflicting'

$tmp=Join-Path $PSScriptRoot 'fixture-package'
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
$exe=Join-Path $tmp 'setup.exe'; $inf=Join-Path $tmp 'display.inf'
[IO.File]::WriteAllText($exe,'fixture')
$validInf="[Version]`nClass=Display`nDriverVer=01/01/2026,2.0`n[Manufacturer]`n%NVIDIA%=NvidiaModels,NTamd64`n[NvidiaModels.NTamd64]`n%GPU%=Install,PCI\VEN_10DE&DEV_1234"
[IO.File]::WriteAllText($inf,$validInf)
function Get-AuthenticodeSignature { param([string]$LiteralPath) [pscustomobject]@{ Status='Valid'; SignerCertificate=[pscustomobject]@{ Subject='CN=NVIDIA Corporation' } } }
Throws { Test-InstallerCompatibility $gpu (Join-Path $tmp 'missing.exe') $inf } 'Invalid installer file refused'
Check ((Test-InstallerCompatibility $gpu $exe $inf).Version -eq '2.0') 'Signed matching package accepted'
function Get-AuthenticodeSignature { param([string]$LiteralPath) if ($LiteralPath -match '\.inf$') { return [pscustomobject]@{ Status='Valid'; SignerCertificate=[pscustomobject]@{ Subject='CN=Microsoft Windows Hardware Compatibility Publisher' } } }; [pscustomobject]@{ Status='Valid'; SignerCertificate=[pscustomobject]@{ Subject='CN=NVIDIA Corporation' } } }
Check ((Test-InstallerCompatibility $gpu $exe $inf).Version -eq '2.0') 'Microsoft certified INF with vendor EXE accepted'
$other=New-Gpu 'NVIDIA' 'PCI\VEN_10DE&DEV_9999\A'
Throws { Test-InstallerCompatibility $other $exe $inf } 'Installer and device incompatibility refused'
[IO.File]::WriteAllText($inf,($validInf -replace 'NTamd64','NTarm64'))
Throws { Test-InstallerCompatibility $gpu $exe $inf } 'Wrong architecture model section refused'
[IO.File]::WriteAllText($inf,($validInf -replace 'NTamd64','NTamd64.99.0'))
Throws { Test-InstallerCompatibility $gpu $exe $inf } 'Future OS model section refused'
[IO.File]::WriteAllText($inf,($validInf -replace 'NTamd64','NTamd64.10.0...99999'))
Throws { Test-InstallerCompatibility $gpu $exe $inf } 'Future Windows build model section refused'
[IO.File]::WriteAllText($inf,($validInf.Replace('[NvidiaModels.NTamd64]','[OtherModels.NTamd64]')))
Throws { Test-InstallerCompatibility $gpu $exe $inf } 'Unreferenced hardware model section refused'
[IO.File]::WriteAllText($inf,"[Version]`nClass=Display`nDriverVer=01/01/2026,2.0`n; PCI\VEN_10DE&DEV_1234`n[Manufacturer]`n%NVIDIA%=NvidiaModels,NTamd64`n[NvidiaModels.NTamd64]`n%Other%=Install,PCI\VEN_10DE&DEV_9999")
Throws { Test-InstallerCompatibility $gpu $exe $inf } 'Commented hardware ID refused'
[IO.File]::WriteAllText($inf,$validInf)
function Get-AuthenticodeSignature { param([string]$LiteralPath) [pscustomobject]@{ Status='NotSigned'; SignerCertificate=$null } }
Throws { Test-InstallerCompatibility $gpu $exe $inf } 'Unsigned installer refused'

$j=New-Journal 'Verified'; $j.NewInf='oem9.inf'; $j.NewVersion='2.0'
$new=New-Gpu 'NVIDIA' $j.InstanceId 'oem9.inf' '2.0'
$packages=@([pscustomobject]@{ Inf='oem1.inf'; Class='Display' })
Check ((Test-CleanupEligibility $j $new $packages @()) -eq $null) 'Safe obsolete package eligible'
Check ((Test-CleanupEligibility $j $new @($packages+$packages) @()) -match 'uniquely') 'Multiple matching INF entries refused'
Check ((Test-CleanupEligibility $j (New-Gpu 'NVIDIA' $j.InstanceId 'oem1.inf' '2.0') $packages @()) -ne $null) 'Active package removal refused'
Check ((Test-CleanupEligibility $j $new $packages @([pscustomobject]@{ InfName='oem1.inf' })) -match 'another device') 'Shared package removal refused'
Check ((Test-CleanupEligibility $j $new $packages @([pscustomobject]@{ InfName=''; UsageUnknown=$true })) -match 'uncertain') 'Unknown device usage refused'
Check ((Test-CleanupEligibility (New-Journal 'Failed') $new $packages @()) -match 'not been verified') 'Failed installation blocks cleanup'
$script:testSigned=@([pscustomobject]@{ ClassGuid=$script:DisplayGuid; DeviceID='PCI\VEN_10DE&DEV_5678\H'; InfName='oem1.inf' })
function Get-PnpDevice { return @([pscustomobject]@{ Class='Display'; InstanceId='PCI\VEN_10DE&DEV_5678\H' }) }
function Get-PnpDeviceProperty { param([string]$InstanceId,[string]$KeyName) [pscustomobject]@{ Data='oem1.inf' } }
Check (@(Get-DeviceUsageInventory | Where-Object { $_.InfName -eq 'oem1.inf' }).Count -gt 0) 'Hidden or disconnected device usage detected'
function Get-PnpDeviceProperty { param([string]$InstanceId,[string]$KeyName) throw 'Property unavailable' }
Check (@(Get-DeviceUsageInventory | Where-Object UsageUnknown).Count -gt 0) 'Unreadable device usage becomes uncertain'

function Assert-Windows { [pscustomobject]@{ Name='Windows Test'; Build=22631; Version='10.0' } }
function Request-Elevation { param([string]$RequestedAction) return $false }
function Test-PendingRestart { return $script:pending }
function Read-Journal { return $script:testJournal }
function Write-Journal { param($Journal) $script:testJournal=$Journal }
$script:logEntries=New-Object Collections.Generic.List[string]
function Write-Log { param([string]$Operation,[string]$Result,[string]$Detail) $script:logEntries.Add("$Operation|$Result|$Detail") }
function Get-Gpus { return @($script:currentGpu) }
$script:pending=$false
$script:testJournal=New-Journal 'Started'; $script:currentGpu=$new
Throws { Verify-GpuDriver } 'Interrupted installer cannot verify'
$script:testJournal=New-Journal 'Failed'
Throws { Verify-GpuDriver } 'Failed installer cannot verify'
$script:testJournal=New-Journal 'InstallerExited'; $script:pending=$true
Verify-GpuDriver | Out-Null
Check ($script:testJournal.State -eq 'PendingRestart' -and @($script:logEntries | Where-Object { $_ -match 'PENDING RESTART' }).Count -gt 0) 'Pending restart recorded and logged'
$script:pending=$false
Verify-GpuDriver | Out-Null
Check ($script:testJournal.State -eq 'Verified' -and $script:testJournal.NewInf -eq 'oem9.inf') 'Replacement verified after reboot'
Check (@($script:logEntries | Where-Object { $_ -match 'GPU verify\|SUCCESS.*oem9.inf' }).Count -gt 0) 'Post-reboot active INF logged'
$script:testJournal=New-Journal 'InstallerExited'; $script:currentGpu=New-Gpu 'NVIDIA' $gpu.InstanceId 'oem1.inf' '1.0'
Throws { Verify-GpuDriver } 'Unchanged driver fails verification'

$realBackupPath=$script:BackupPath
$script:BackupPath=Join-Path $PSScriptRoot 'test-backup.ini'
$sample=[pscustomobject]@{ OriginalKeyExists=$true; OriginalValueExists=$true; OriginalType='DWord'; OriginalValue='0'; LastWritten='1'; Phase='Active'; OS='Windows Test'; CreatedUtc='2026-01-01T00:00:00Z' }
[IO.File]::WriteAllText($script:BackupPath,(Format-Backup $sample))
Check ((Read-Backup).OriginalValue -eq '0') 'Recovery backup round trip'
[IO.File]::WriteAllText($script:BackupPath,'Version=1')
Throws { Read-Backup } 'Corrupt recovery backup refused'
Remove-Item -LiteralPath $script:BackupPath -Force
$script:BackupPath=$realBackupPath

& {
    # Exercise real archival on disposable files; ACL writes require elevation and are stubbed.
    function Protect-DataDirectory { }
    function Assert-SecureStatePath([string]$Path) { if (-not (Test-Path -LiteralPath $Path)) { throw 'Archive path missing.' } }
    function Set-Acl { param([string]$LiteralPath,$AclObject) }
    $oldDir=$script:DataDir; $oldPath=$script:BackupPath
    $dir=Join-Path $PSScriptRoot ('archive-fixture-'+[guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($dir) | Out-Null
    try {
        $script:DataDir=$dir; $script:BackupPath=Join-Path $dir 'original-state.ini'
        $restored=[pscustomobject]@{ OriginalKeyExists='False'; OriginalValueExists='False'; OriginalType=''; OriginalValue=''; Phase='Restored'; OS='Windows Test'; CreatedUtc='2026-01-01T00:00:00Z' }
        [IO.File]::WriteAllText($script:BackupPath,(Format-Backup $restored))
        $archive=Archive-RestoredBackup (Read-Backup)
        Check ((Test-Path -LiteralPath $archive) -and (Read-Backup $archive).Phase -eq 'Restored' -and (Read-Backup).Phase -eq 'Restored') 'Real archival preserves valid Restored source and copy'
        $prepared=[pscustomobject]@{ OriginalKeyExists='True'; OriginalValueExists='True'; OriginalType='DWord'; OriginalValue='0'; Phase='Prepared'; OS='Windows Test'; CreatedUtc='2026-01-02T00:00:00Z' }
        Write-Atomic $script:BackupPath (Format-Backup $prepared) (Format-Backup $restored)
        Check ((Read-Backup).Phase -eq 'Prepared' -and (Read-Backup $archive).Phase -eq 'Restored') 'Real atomic rotation keeps archived history and new Prepared record'
        Throws { Write-Atomic $script:BackupPath (Format-Backup $prepared) (Format-Backup $restored) } 'Real rotation refuses to replace Prepared record'
        [IO.File]::WriteAllText($script:BackupPath,'Version=1')
        Throws { Archive-RestoredBackup $restored } 'Real archival refuses damaged source'
        Check (@(Get-ChildItem -LiteralPath $dir -Filter '*.restored.ini').Count -eq 1) 'Damaged source creates no additional archive'
    } finally {
        $script:DataDir=$oldDir; $script:BackupPath=$oldPath
        foreach ($file in @(Get-ChildItem -LiteralPath $dir -File)) { [IO.File]::Delete($file.FullName) }
        [IO.Directory]::Delete($dir)
    }
}

function Read-Policy { return [pscustomobject]@{ KeyExists=$script:policy.KeyExists; ValueExists=$script:policy.ValueExists; Type=$script:policy.Type; Value=$script:policy.Value } }
function Set-PolicyValue { param([int]$Value) if ($script:denyWrite) { throw 'Access denied' }; $script:policyWrites++; $script:policy=[pscustomobject]@{ KeyExists=$true; ValueExists=$true; Type='DWord'; Value=[string]$Value } }
function Remove-PolicyValue { $script:policyWrites++; $script:policy=[pscustomobject]@{ KeyExists=$true; ValueExists=$false; Type=''; Value='' } }
function Read-Backup { if ($script:damageBackup) { throw 'Recovery backup is malformed.' }; return $script:simBackup }
function Protect-DataDirectory { }
$script:changeOnConfirm=$false; $script:changeAfterBackup=$false; $script:failBackupPhase=''; $script:cancelConfirm=$false; $script:damageBackup=$false; $script:failArchive=$false; $script:changeDuringArchive=$false; $script:changeBeforeAtomic=$false; $script:simArchives=@()
function Archive-RestoredBackup { param($backup) if ($script:failArchive) { $script:failArchive=$false; throw 'Archive failed' }; $script:simArchives += (Format-Backup $backup); if ($script:changeDuringArchive) { $script:simBackup.Phase='Active'; $script:changeDuringArchive=$false }; return 'fixture-archive.ini' }
function Write-Atomic { param([string]$Path,[string]$Text,[string]$ExpectedCurrentText) $script:backupWrites++; $data=@{}; foreach ($line in ($Text -split "`n")) { if ($line -match '^([^=]+)=(.*)$') { $data[$matches[1]]=$matches[2] } }; if ($script:changeBeforeAtomic) { $script:simBackup.Phase='Active'; $script:changeBeforeAtomic=$false }; if ($PSBoundParameters.ContainsKey('ExpectedCurrentText') -and ($script:simBackup.Phase -ne 'Restored' -or (Format-Backup $script:simBackup) -cne $ExpectedCurrentText)) { throw 'Recovery record changed before replacement' }; if ($script:failBackupPhase -eq $data.Phase) { $script:failBackupPhase=''; throw 'Mock atomic state-file replacement failed' }; $script:simBackup=[pscustomobject]$data; if ($script:changeAfterBackup -and $script:simBackup.Phase -eq 'Prepared') { $script:policy.Value='7'; $script:changeAfterBackup=$false } }
function Confirm-Yes { param([string]$Prompt) $script:confirmCalls++; if ($script:changeOnConfirm) { $script:policy.Value='7'; $script:changeOnConfirm=$false }; if ($script:cancelConfirm) { $script:cancelConfirm=$false; return $false }; return $true }
$script:confirmCalls=0
$script:policyWrites=0; $script:backupWrites=0
$script:denyWrite=$false
$script:simBackup=$null
$script:policy=[pscustomobject]@{ KeyExists=$false; ValueExists=$false; Type=''; Value='' }
Enable-Protection | Out-Null
Check ($script:policy.Value -eq '1' -and $script:simBackup.OriginalValueExists -eq 'False') 'A03 absent policy backed up and enabled'
Enable-Protection | Out-Null
Check ($script:simBackup.OriginalValueExists -eq 'False') 'A06 repeat enable preserves original backup'
Restore-Protection | Out-Null
Check (-not $script:policy.ValueExists -and $script:simBackup.Phase -eq 'Restored') 'A07 absent value restored'
$script:simBackup=$null
$script:policy=[pscustomobject]@{ KeyExists=$true; ValueExists=$true; Type='DWord'; Value='0' }
Enable-Protection | Out-Null
Check ($script:simBackup.OriginalValue -eq '0' -and $script:policy.Value -eq '1') 'A04 DWORD zero backed up and enabled'
Restore-Protection | Out-Null
Check ($script:policy.Value -eq '0') 'A08 DWORD zero restored'
$script:simBackup=$sample; $script:simBackup.Phase='Active'
foreach ($external in @(
    [pscustomobject]@{ KeyExists=$true; ValueExists=$true; Type='DWord'; Value='0' },
    [pscustomobject]@{ KeyExists=$true; ValueExists=$false; Type=''; Value='' },
    [pscustomobject]@{ KeyExists=$true; ValueExists=$true; Type='String'; Value='1' },
    [pscustomobject]@{ KeyExists=$true; ValueExists=$true; Type='DWord'; Value='7' }
)) {
    $script:policy=$external
    $beforePolicy=Read-Policy; $beforeBackup=Format-Backup $script:simBackup; $beforeConfirms=$script:confirmCalls; $beforePolicyWrites=$script:policyWrites; $beforeBackupWrites=$script:backupWrites
    $refused=$false
    try { Restore-Protection | Out-Null } catch { $refused=$_.Exception.Message -like '*last write*' }
    Check $refused "Active Restore refuses external $($external.Type)/$($external.Value) before confirmation"
    Check ((Test-SamePolicyState $beforePolicy (Read-Policy)) -and (Format-Backup $script:simBackup) -ceq $beforeBackup -and $script:confirmCalls -eq $beforeConfirms -and $script:policyWrites -eq $beforePolicyWrites -and $script:backupWrites -eq $beforeBackupWrites) "Active conflict performs no policy or recovery-file write: $($external.Type)/$($external.Value)"
}
$script:policy=[pscustomobject]@{ KeyExists=$true; ValueExists=$true; Type='DWord'; Value='1' }
Restore-Protection | Out-Null
Check ($script:policy.Value -eq '0' -and $script:simBackup.Phase -eq 'Restored') 'Active DWORD one restores exact DWORD zero'
Enable-Protection | Out-Null
Check ($script:simBackup.OriginalValue -eq '0') 'Reenable after restore preserves first backup'
Restore-Protection | Out-Null
$script:policy=[pscustomobject]@{ KeyExists=$true; ValueExists=$true; Type='DWord'; Value='1' }
Throws { Restore-Protection } 'Restored backup cannot authorize overwrite of external value one'
Check ($script:policy.Value -eq '1' -and $script:simBackup.Phase -eq 'Restored') 'External value and restored backup remain intact'
$script:simBackup=$null; $script:changeOnConfirm=$true
$script:policy=[pscustomobject]@{ KeyExists=$true; ValueExists=$true; Type='DWord'; Value='0' }
Throws { Enable-Protection } 'Enable refuses policy change during confirmation'
Check ($script:policy.Value -eq '7' -and $null -eq $script:simBackup) 'Enable confirmation conflict creates no stale backup'
$script:simBackup=$null; $script:changeAfterBackup=$true
$script:policy=[pscustomobject]@{ KeyExists=$true; ValueExists=$true; Type='DWord'; Value='0' }
Throws { Enable-Protection } 'Enable refuses policy change after backup preparation'
Check ($script:policy.Value -eq '7' -and $script:simBackup.Phase -eq 'Prepared') 'Prepared backup retained without overwriting new policy'
$script:simBackup=$sample; $script:simBackup.Phase='Active'; $script:changeOnConfirm=$true
$script:policy=[pscustomobject]@{ KeyExists=$true; ValueExists=$true; Type='DWord'; Value='1' }
$beforePolicyWrites=$script:policyWrites; $beforeBackupWrites=$script:backupWrites
Throws { Restore-Protection } 'Restore refuses policy change during confirmation'
Check ($script:policy.Value -eq '7' -and $script:simBackup.Phase -eq 'Active' -and $script:policyWrites -eq $beforePolicyWrites -and $script:backupWrites -eq $beforeBackupWrites) 'Restore confirmation conflict leaves external policy and recovery file untouched'
$script:simBackup=$null; $script:failBackupPhase='Prepared'
$script:policy=[pscustomobject]@{ KeyExists=$true; ValueExists=$true; Type='DWord'; Value='0' }
Throws { Enable-Protection } 'Failed initial backup write blocks policy change'
Check ($script:policy.Value -eq '0' -and $null -eq $script:simBackup) 'Initial backup failure leaves baseline intact'
$script:simBackup=$null; $script:failBackupPhase='Active'
$script:policy=[pscustomobject]@{ KeyExists=$true; ValueExists=$true; Type='DWord'; Value='0' }
Throws { Enable-Protection } 'Failed Active backup write reports interrupted enable'
Check ($script:policy.Value -eq '1' -and $script:simBackup.Phase -eq 'Prepared') 'Interrupted enable retains Prepared recovery record'
Restore-Protection | Out-Null
Check ($script:policy.Value -eq '0' -and $script:simBackup.Phase -eq 'Restored') 'Prepared record restores original after Active write failure'
$script:simBackup=$null
$script:policy=[pscustomobject]@{ KeyExists=$true; ValueExists=$true; Type='DWord'; Value='1' }
Enable-Protection | Out-Null
Check ($null -eq $script:simBackup -and $script:policy.Value -eq '1') 'A05 externally enabled policy left untouched'
Throws { Restore-Protection } 'A09 missing backup refuses restoration'
$script:simBackup=$sample; $script:simBackup.Phase='Active'
$script:policy=[pscustomobject]@{ KeyExists=$true; ValueExists=$true; Type='DWord'; Value='7' }
Throws { Restore-Protection } 'A11 external policy conflict refused'
$script:simBackup=$null; $script:denyWrite=$true
$script:policy=[pscustomobject]@{ KeyExists=$true; ValueExists=$true; Type='DWord'; Value='0' }
Throws { Enable-Protection } 'A10 denied registry write reports failure'
Check ($script:policy.Value -eq '0') 'Denied write does not change observed policy'
$script:denyWrite=$false
$script:policy=[pscustomobject]@{ KeyExists=$true; ValueExists=$true; Type='String'; Value='1' }
Throws { Enable-Protection } 'Invalid policy type refused'
$script:simBackup=$sample; $script:simBackup.Phase='Prepared'
$script:policy=[pscustomobject]@{ KeyExists=$true; ValueExists=$true; Type='DWord'; Value='1' }
Throws { Enable-Protection } 'Prepared backup with value one refuses ambiguous enable'
Restore-Protection | Out-Null
Check ($script:policy.Value -eq '0' -and $script:simBackup.Phase -eq 'Restored') 'Prepared backup restores original after interrupted write'
$script:simBackup=$sample; $script:simBackup.Phase='Prepared'
$script:policy=[pscustomobject]@{ KeyExists=$true; ValueExists=$true; Type='DWord'; Value='0' }
Restore-Protection | Out-Null
Check ($script:simBackup.Phase -eq 'Restored') 'Prepared backup reconciles intact original'

function New-RestoredFixture { return [pscustomobject]@{ OriginalKeyExists='False'; OriginalValueExists='False'; OriginalType=''; OriginalValue=''; LastWritten='1'; Phase='Restored'; OS='Windows Test'; CreatedUtc='2026-01-01T00:00:00Z' } }
$script:simBackup=New-RestoredFixture
$script:policy=[pscustomobject]@{ KeyExists=$true; ValueExists=$true; Type='DWord'; Value='0' }
Throws { Enable-Protection } 'Ordinary Enable still refuses different Restored baseline'
$script:cancelConfirm=$true
Enable-Protection -FreshCycle | Out-Null
Check ($script:policy.Value -eq '0' -and $script:simBackup.Phase -eq 'Restored' -and $script:simArchives.Count -eq 0) 'Fresh cycle cancellation changes nothing'
$script:changeOnConfirm=$true
Throws { Enable-Protection -FreshCycle } 'Fresh cycle refuses registry change during confirmation'
Check ($script:simBackup.Phase -eq 'Restored' -and $script:simArchives.Count -eq 0) 'Confirmation conflict retains old recovery record'
$script:policy.Value='0'; $script:failArchive=$true
Throws { Enable-Protection -FreshCycle } 'Archival failure blocks fresh cycle'
Check ($script:simBackup.Phase -eq 'Restored' -and $script:policy.Value -eq '0') 'Archival failure retains old record and policy'
$script:failBackupPhase='Prepared'
Throws { Enable-Protection -FreshCycle } 'Prepared replacement failure blocks fresh cycle'
Check ($script:simBackup.Phase -eq 'Restored' -and $script:policy.Value -eq '0' -and $script:simArchives.Count -eq 1) 'Replacement failure retains old record and archive'
$script:changeDuringArchive=$true
Throws { Enable-Protection -FreshCycle } 'Fresh cycle refuses record change during archival'
Check ($script:simBackup.Phase -eq 'Active' -and $script:policy.Value -eq '0') 'Concurrent Active record is not replaced'
$script:simBackup=New-RestoredFixture
$script:changeBeforeAtomic=$true
Throws { Enable-Protection -FreshCycle } 'Fresh cycle refuses record change before atomic replacement'
Check ($script:simBackup.Phase -eq 'Active' -and $script:policy.Value -eq '0') 'Late Active record is not replaced'
$script:simBackup=New-RestoredFixture
Enable-Protection -FreshCycle | Out-Null
Check ($script:policy.Value -eq '1' -and $script:simBackup.Phase -eq 'Active' -and $script:simBackup.OriginalValueExists -eq 'True' -and $script:simBackup.OriginalValue -eq '0' -and $script:simArchives.Count -eq 4) 'Fresh cycle from DWORD zero captures new baseline and archives prior record'
Restore-Protection | Out-Null
Check ($script:policy.ValueExists -and $script:policy.Value -eq '0' -and $script:simBackup.Phase -eq 'Restored') 'Fresh cycle restores exact DWORD zero'
$script:simBackup=New-RestoredFixture
$script:policy=[pscustomobject]@{ KeyExists=$true; ValueExists=$false; Type=''; Value='' }
Enable-Protection -FreshCycle | Out-Null
Check ($script:simBackup.OriginalValueExists -eq 'False' -and $script:policy.Value -eq '1') 'Fresh cycle from absent captures absence'
Restore-Protection | Out-Null
Check (-not $script:policy.ValueExists -and $script:simBackup.Phase -eq 'Restored') 'Fresh cycle restores exact absence'
foreach ($phase in @('Prepared','Active')) {
    $script:simBackup=New-RestoredFixture; $script:simBackup.Phase=$phase
    $script:policy=[pscustomobject]@{ KeyExists=$true; ValueExists=$true; Type='DWord'; Value='0' }
    $archiveCount=$script:simArchives.Count
    Throws { Enable-Protection -FreshCycle } "Fresh cycle refuses $phase recovery record"
    Check ($script:simBackup.Phase -eq $phase -and $script:simArchives.Count -eq $archiveCount) "$phase record remains untouched"
}
$script:simBackup=New-RestoredFixture; $script:damageBackup=$true
Throws { Enable-Protection -FreshCycle } 'Fresh cycle refuses damaged recovery record'
$script:damageBackup=$false
$script:policy=[pscustomobject]@{ KeyExists=$true; ValueExists=$true; Type='DWord'; Value='1' }
Throws { Enable-Protection -FreshCycle } 'Fresh cycle refuses enabled policy'
$script:simBackup=New-RestoredFixture; $script:simBackup.OriginalKeyExists='True'; $script:simBackup.OriginalValueExists='True'; $script:simBackup.OriginalType='DWord'; $script:simBackup.OriginalValue='0'
$script:policy.Value='0'; $script:changeAfterBackup=$true
Throws { Enable-Protection -FreshCycle } 'Fresh cycle refuses registry change after new Prepared record'
Check ($script:simBackup.Phase -eq 'Prepared' -and $script:policy.Value -eq '7') 'Interrupted fresh cycle retains Prepared record for review'
$script:policy.Value='0'
Restore-Protection | Out-Null
Check ($script:simBackup.Phase -eq 'Restored' -and $script:policy.Value -eq '0') 'Interrupted fresh cycle reconciles intact baseline'

$script:DataDir=$tmp
$script:packagePresent=$true
$script:pnputilCalls=New-Object Collections.Generic.List[string]
function Get-DriverPackages { if ($script:packagePresent) { [pscustomobject]@{ Inf='oem1.inf'; OriginalInf='nv_fixture.inf'; Class='Display'; Provider='NVIDIA' } } }
function Get-DeviceUsageInventory { return @() }
function pnputil.exe {
    $script:pnputilCalls.Add(($args -join ' '))
    if ($args[0] -eq '/export-driver') { [IO.File]::WriteAllText((Join-Path $args[2] 'saved.inf'),'fixture') }
    if ($args[0] -eq '/delete-driver') { $script:packagePresent=$false }
    $global:LASTEXITCODE=0
}
$script:testJournal=$j; $script:currentGpu=$new; $script:pending=$false
Cleanup-GpuDriver | Out-Null
Check (-not $script:packagePresent -and @($script:pnputilCalls | Where-Object { $_ -eq '/delete-driver oem1.inf' }).Count -eq 1) 'Targeted cleanup uses no force or uninstall flags'

$script:packagePresent=$true
$script:currentGpu=$gpu
function Select-Gpu { return $script:currentGpu }
function Read-Host { param([string]$Prompt) if ($Prompt -match 'INF') { return $inf }; return $exe }
function Test-InstallerCompatibility { param($Gpu,[string]$Installer,[string]$InfPath) [pscustomobject]@{ Installer=$exe; InfPath=$inf; Version='2.0'; InstallerHash=(Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash; InfHash=(Get-FileHash -LiteralPath $inf -Algorithm SHA256).Hash; Signer='NVIDIA' } }
function Start-Process { param([string]$FilePath,[switch]$Wait,[switch]$PassThru) [pscustomobject]@{ ExitCode=5 } }
Throws { Install-GpuDriver } 'Failed manufacturer installer exit reported'
Check ($script:testJournal.State -eq 'Failed' -and @($script:logEntries | Where-Object { $_ -match 'GPU install\|FAILED' }).Count -gt 0) 'Failed install journal and log recorded'

function Get-OS { [pscustomobject]@{ Name='Windows Test'; Version='10.0'; Build=22631 } }
function Test-Admin { return $false }
function Get-UpdateHistory { param([switch]$Strict) return @() }
function Get-SetupEvidence { param([string]$InstanceId,[string]$Inf,[switch]$Strict) return @() }
function Get-EventEvidence { param([string]$InstanceId,[switch]$Strict) return @() }
$beforeLogs=$script:logEntries.Count
$report=Show-ReadOnlyDiagnostics 6>&1 | Out-String
Check ($report -match 'Policy:' -and $report -match 'GPU:' -and $report -match 'Driver store association:' -and $report -match 'Provenance:') 'Read-only diagnostics report required sources'
Check ($report -match 'Diagnose result: COMPLETE \(exit 0\)' -and $report -match '(?m)^0\s*$') 'Complete diagnostics return exit code zero'
Check ($script:logEntries.Count -eq $beforeLogs) 'Read-only diagnostics writes no activity log'
$script:currentGpu=New-Gpu 'NVIDIA' 'PCI\VEN_10DE&DEV_1234\A'
$script:currentGpu.Provider=''; $report=Show-ReadOnlyDiagnostics 6>&1 | Out-String
Check ($report -match 'provider=UNKNOWN' -and $report -match 'Active driver provider unavailable' -and $report -match 'Diagnose result: PARTIAL \(exit 2\)') 'Missing active provider is explicit and makes diagnostics partial'
$script:currentGpu=New-Gpu 'NVIDIA' 'PCI\VEN_10DE&DEV_1234\A'
$script:currentGpu.Version=''; $report=Show-ReadOnlyDiagnostics 6>&1 | Out-String
Check ($report -match 'version=UNKNOWN' -and $report -match 'Active driver version unavailable' -and $report -match 'Diagnose result: PARTIAL \(exit 2\)') 'Missing active version is explicit and makes diagnostics partial'
$script:currentGpu=New-Gpu 'NVIDIA' 'PCI\VEN_10DE&DEV_1234\A' ''
$report=Show-ReadOnlyDiagnostics 6>&1 | Out-String
Check ($report -match 'SetupAPI: UNAVAILABLE - active device INF is unverified' -and $report -match 'Diagnose result: PARTIAL \(exit 2\)') 'Unverified active INF does not masquerade as missing SetupAPI record'
$script:currentGpu=$new
function Get-DriverPackages { throw 'Elevated inventory required' }
function pnputil.exe { $global:LASTEXITCODE=0; return 'Published Name: oem1.inf' }
$report=Show-ReadOnlyDiagnostics 6>&1 | Out-String
Check ($report -match 'Diagnose result: PARTIAL \(exit 2\)' -and $report -match 'Structured driver store inventory unavailable') 'Partial diagnostics identify limited source'
function Read-Policy { throw 'Registry read denied' }
$report=Show-ReadOnlyDiagnostics 6>&1 | Out-String
Check ($report -match 'Diagnose result: FAILED \(exit 1\)' -and $report -match 'Policy read unavailable') 'Failed diagnostics identify critical source'

Remove-Item -LiteralPath $tmp -Recurse -Force
Write-Host "RESULT: $script:passed passed; $script:failed failed"
if ($script:failed -gt 0) { exit 1 }
