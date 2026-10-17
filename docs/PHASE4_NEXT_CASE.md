# Phase 4 next-case runbook (prepared October 17, 2026; NOT EXECUTED)

Tested source: `714966a9b1b81de25d7f6910004f56486f7030d9`. Current VM is Windows 11 Home build 26300, VMware20,1, with DWORD `1` and an Active record whose original value is DWORD `0`. Do not use that live state for a fresh-baseline case. No Enable, Restore, FreshCycle, install, cleanup, or reboot was run during this review. Do not install an NVIDIA driver in this VM.

## Practical order of remaining cases

Based on the current remaining checklist in [WINDOWS11_VALIDATION.md](../WINDOWS11_VALIDATION.md), use independent restored snapshots and preserve evidence off-VM before reverting:

1. Standard-user launch, approve UAC, complete ordinary Enable with YES; capture elevated completion and parent exit propagation. Use a fresh DWORD `0`/missing-recovery baseline so this also supplies ordinary DWORD `0` entry-path evidence. Treat these as separately scored assertions.
2. Ordinary Enable with externally configured DWORD `1`, no recovery record: no target write or invented backup; compare siblings and file absence. Log writes are expected for this action.
3. Active Restore conflicts: external target deletion, unsupported registry type (for example REG_SZ `1`), and unsupported DWORD (for example `7`), each independently. Existing Active/DWORD `0` conflict need not be repeated.
4. Other malformed recovery records (schema, missing/duplicate fields, invalid phase/value) and remaining unsafe path/directory ACL variants: refuse before confirmation; preserve registry and recovery bytes. Missing file, invalid text, and file-specific nonadministrator-write ACL cases already passed.
5. Controlled pre-write/backup creation/replacement failures and registry-write denial; verify no unbacked write, failure propagation, and recoverable Prepared state where appropriate. Use a reviewed per-fault plan; do not apply broad registry ACL denial or terminate processes arbitrarily. Actual after-write Prepared recovery already passed.
6. Optional hardening: interrupted Prepared reboot, remaining FreshCycle failures, menu input and full BAT elevation from paths with spaces on additional builds. Collect independent hashes, siblings, logs, and exit codes throughout new tests rather than repeating passed paths only for artifacts.
7. Separately scoped managed Group Policy/MDM cases and Windows Update enforcement investigation. Registry readback/persistence does not prove enforcement, particularly on Home.

## First case: prerequisites and baseline

These are prepared commands only. Obtain explicit authorization for this UAC/Enable case and, separately, any Restore rollback. Record a VMware snapshot name/ID and verify the host-side revert procedure. Restore a dedicated snapshot already containing DWORD `0` and no DriverGuard recovery record; do not reset the current Active VM by deleting files or editing its target. If no such baseline exists, stop and prepare a separately approved fixture. Record management ownership with `gpresult` and `dsregcmd`; unresolved policy ownership stops the live case.

Use an elevated **64-bit Windows PowerShell 5.1 observer** for baseline/post evidence. Start a screen recording of the standard-user console, UAC, and elevated child; parent redirection cannot capture the separate elevated window. Choose the actual launcher account and record its LOCALAPPDATA in its own console first (`$env:LOCALAPPDATA`). Set `$launcherLocal` below to that exact path; the example assumes Jose is the launcher. Preserve the account/profile used at UAC too, since alternate administrator credentials can select a different user log.

```powershell
Set-Location 'C:\Users\Jose\Desktop\DriveGaurd'
$repo = (Get-Location).Path
$e = Join-Path $env:USERPROFILE ('Desktop\DG-Phase4-UAC-' + (Get-Date -Format yyyyMMdd-HHmmss))
New-Item -ItemType Directory -Path $e -ErrorAction Stop | Out-Null
$snapshotId = Read-Host 'Verified VMware snapshot name/ID'
if ([string]::IsNullOrWhiteSpace($snapshotId)) { throw 'Snapshot required' }
$snapshotId | Set-Content (Join-Path $e 'snapshot.txt')
$launcherLocal = 'C:\Users\Jose\AppData\Local' # replace if launcher reports another path
git rev-parse HEAD | Set-Content (Join-Path $e 'head.txt')
git status --porcelain=v1 | Set-Content (Join-Path $e 'git-status.txt')
$PSVersionTable | Out-String | Set-Content (Join-Path $e 'powershell.txt')
Get-CimInstance Win32_OperatingSystem | Format-List * | Out-File (Join-Path $e 'os.txt')
gpresult.exe /r /scope computer 2>&1 | Out-File (Join-Path $e 'gpresult.txt')
"exit=$LASTEXITCODE" | Add-Content (Join-Path $e 'gpresult.txt')
dsregcmd.exe /status | Out-File (Join-Path $e 'dsregcmd.txt')

function Capture-DG([string]$Tag) {
    $out = Join-Path $e $Tag
    New-Item -ItemType Directory -Path $out -ErrorAction Stop | Out-Null
    $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey('LocalMachine','Registry64')
    $key = $base.OpenSubKey('SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate')
    try {
        $values = @()
        if ($key) {
            $values = @(foreach ($name in ($key.GetValueNames() | Sort-Object)) {
                [pscustomobject]@{Name=$name; Type=$key.GetValueKind($name).ToString();
                    Data=$key.GetValue($name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)}
            })
        }
        [pscustomobject]@{KeyExists=($null -ne $key); Values=$values} |
            Export-Clixml (Join-Path $out 'policy.xml')
    } finally { if ($key) { $key.Dispose() }; $base.Dispose() }
    reg.exe query 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' /s 2>&1 |
        Out-File (Join-Path $out 'policy-query.txt')
    "exit=$LASTEXITCODE" | Add-Content (Join-Path $out 'policy-query.txt')
    if (Test-Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate') {
        reg.exe export 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' (Join-Path $out 'policy.reg') /y | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Baseline export failed' }
    }
    $paths = @((Join-Path $env:ProgramData 'DriverGuard'),
        (Join-Path $launcherLocal 'DriverGuard'), (Join-Path $env:LOCALAPPDATA 'DriverGuard')) | Select-Object -Unique
    $index = 0
    $manifest = @(foreach ($path in $paths) {
        if (-not (Test-Path -LiteralPath $path)) { [pscustomobject]@{Path=$path; Hash='ABSENT'; Sddl=''}; continue }
        $entries = @(Get-Item -LiteralPath $path -Force) + @(Get-ChildItem -LiteralPath $path -Recurse -Force -ErrorAction Stop)
        foreach ($item in $entries) {
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Linked evidence path; stop' }
            $hash = 'DIRECTORY'
            if (-not $item.PSIsContainer) {
                $hash = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
                Copy-Item -LiteralPath $item.FullName -Destination (Join-Path $out ("state-$index.bin")) -ErrorAction Stop
            }
            [pscustomobject]@{Index=$index; Path=$item.FullName; Hash=$hash; Sddl=(Get-Acl -LiteralPath $item.FullName).Sddl}
            $index++
        }
    })
    $manifest | Export-Clixml (Join-Path $out 'state.xml')
    powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File "$repo\DriverGuard.ps1" -Action Diagnose |
        Out-File (Join-Path $out 'diagnose.txt')
    "exit=$LASTEXITCODE" | Add-Content (Join-Path $out 'diagnose.txt')
}
Capture-DG before
$before = Import-Clixml (Join-Path $e 'before\policy.xml')
$target = @($before.Values | Where-Object Name -eq 'ExcludeWUDriversInQualityUpdate')
if ($target.Count -ne 1 -or $target[0].Type -ne 'DWord' -or $target[0].Data -ne 0) { throw 'Need fresh DWORD 0 baseline' }
if (Test-Path (Join-Path $env:ProgramData 'DriverGuard\original-state.ini')) { throw 'Need missing recovery record; do not delete it' }
```

Review the captured policy/management results and snapshot readiness before proceeding. Baseline capture must fail closed on unreadable state. Store evidence securely; it contains registry and recovery data.

## First case: future authorized action

In the **unelevated launcher console**, run this exact sequence. The administrator-role assertion must print `False`; do not start in the currently elevated observer. If using a true standard account, approve with the designated administrator credentials. Verify repository access before starting. Record the identity/profile from both sessions.

```powershell
Set-Location 'C:\Users\Jose\Desktop\DriveGaurd'
$id = [Security.Principal.WindowsIdentity]::GetCurrent()
$isAdmin = (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
"Identity=$($id.Name); administrator=$isAdmin; LOCALAPPDATA=$env:LOCALAPPDATA"
if ($isAdmin) { throw 'Use an unelevated launcher' }
Start-Transcript -Path (Join-Path $env:TEMP 'DG-Phase4-UAC-launcher.txt') -NoClobber
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\DriverGuard.ps1 -Action Enable
$enableExit = $LASTEXITCODE
"Enable parent exit=$enableExit"
Stop-Transcript
```

Approve UAC and type `YES` at the elevated Enable prompt. Expected screen evidence: the exact disabled-baseline prompt followed by independent readback success. The launcher's actual exit must be `0`. Retain screen evidence of the child, the launcher transcript, and the activity log; do not infer a captured child exit from the parent alone. Static source inspection shows Request-Elevation waits on the child and converts a nonzero child exit to a parent failure; **nonzero propagation remains a separately scored fault-case test**, not proven by a successful launch. The BAT menu returns to its menu and is not a reliable action-exit capture, so use the direct CLI above.

Back in the elevated observer:

```powershell
Capture-DG enabled
$after = Import-Clixml (Join-Path $e 'enabled\policy.xml')
$expected = @($after.Values | Where-Object Name -eq 'ExcludeWUDriversInQualityUpdate')
if ($expected.Count -ne 1 -or $expected[0].Type -ne 'DWord' -or $expected[0].Data -ne 1) { throw 'Enable readback failed; preserve evidence' }
$beforeSiblings = @($before.Values | Where-Object Name -ne 'ExcludeWUDriversInQualityUpdate')
$afterSiblings = @($after.Values | Where-Object Name -ne 'ExcludeWUDriversInQualityUpdate')
Compare-Object (ConvertTo-Json -InputObject $beforeSiblings -Depth 10 -Compress) (ConvertTo-Json -InputObject $afterSiblings -Depth 10 -Compress)
Get-Content (Join-Path $env:ProgramData 'DriverGuard\original-state.ini')
Get-Acl (Join-Path $env:ProgramData 'DriverGuard\original-state.ini') | Format-List Owner,Sddl
```

Expected evidence: no sibling comparison differences; independently read DWORD `1`; valid Active record with original key/value present, original DWord `0`, and LastWritten `1`; trusted administrator/SYSTEM ownership and no nonadministrator write permissions on state file/directory; Enable BACKUP/SUCCESS activity records; unchanged/missing install journal; no driver operation. Retain baseline/post bytes, hashes, ACLs, all process exits and native Diagnose outputs. A complete Diagnose with zero supported PCI GPUs is VM policy-test evidence only, not NVIDIA hardware validation.

## Rollback (prepared, not authorized or run)

1. On any unexpected result, capture the current evidence and stop. Do not overwrite a Prepared/Active record, force Restore, import a whole policy key, or delete state files. Copy evidence off the VM before snapshot revert.
2. Preferred machine rollback: in VMware Workstation select this VM, **VM > Snapshot > Snapshot Manager**, select the exact recorded pre-case snapshot ID/name, and choose **Go To**. Follow the verified host-side procedure; any power/reboot action requires its separately approved scope. After revert, rerun baseline capture in a new evidence directory and compare typed policy values, key presence, recovery bytes/hashes and ACLs with the saved baseline. Host snapshot availability/restorability has not been independently verified by this review.
3. Only with separate Restore approval, and only if target is still DWORD `1` with the valid matching Active record, the observer may run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\DriverGuard.ps1 -Action Restore
$restoreExit = $LASTEXITCODE # type YES only at the intended matching-record prompt
"Restore exit=$restoreExit"
Capture-DG restored
```

Expected: exit `0`, exact DWORD `0`, unchanged siblings, valid Restored record, Restore SUCCESS log. Restore intentionally retains recovery/log files, so this is policy rollback, not a byte-identical fresh fixture. Snapshot revert is required to return to the missing-backup baseline. If Restore refuses or fails, preserve evidence and use the verified snapshot procedure; do not bypass the refusal.
