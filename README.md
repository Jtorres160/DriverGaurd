# DriverGuard v1.1.1

DriverGuard is a small Windows 10/11 BAT menu with a built-in Windows PowerShell helper. It configures the Windows Update policy that excludes driver-classified packages from normal quality updates, records the original registry state for recovery, inspects physical NVIDIA/AMD/Intel GPUs, and offers a cautious route to replace and optionally remove one obsolete graphics package.

## Start

Keep `DriverGuard.bat` and `DriverGuard.ps1` in the same folder. Double-click the BAT file or launch it from Command Prompt. No installation, download, background task, or scheduled task is required. The launcher uses PowerShell `RemoteSigned`; it does not override a stricter organization policy. Review the files before unblocking a downloaded archive. Read-only menu choices can run without administrator privileges. The BAT menu requests normal UAC elevation only for policy, driver installation, verification journal, and cleanup changes. If UAC is cancelled, no change is made.

The script is intended for Windows PowerShell 5.1 on Windows 10 version 1607 or later and Windows 11. Live compatibility has **not** been established across editions and builds. Microsoft's Update CSP edition table lists Pro, Enterprise, Education, and IoT Enterprise; Home effectiveness is uncertain. Managed systems may enforce a conflicting Group Policy, MDM, or WSUS policy.

For a strictly read-only Windows diagnostics pass, run `powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\DriverGuard.ps1 -Action Diagnose` from this directory. This CLI action does not write DriverGuard logs or state. It reports policy and backup state, physical GPU and active INF, driver-store inventory, and provenance evidence. Its exit code is `0` for complete, `2` for partial source availability, or `1` for a critical read or recovery-state failure. Run it again in an administrator session if structured driver-store inventory requires elevation. See [Windows 11 validation](WINDOWS11_VALIDATION.md) for the safe and potentially disruptive test steps.

## Menu

1. **Enable protection**: reads the policy, saves its first observed state, asks for confirmation, sets `REG_DWORD 1`, and reads it back.
2. **Restore original settings**: reads the protected recovery record, checks for external changes, asks for confirmation, restores the exact original value or removes only the value if it was absent, then reads it back.
3. **Check status**: independently displays OS, build, privilege, registry type/value, backup state, conflict, and limitations.
4. **View logs**: shows system and current-user logs when present.
5. **Help**: explains the policy and recovery.
6. **Inspect GPUs**: lists physical PCI NVIDIA, AMD, and Intel display devices, their active INF, hardware IDs, driver details, staged third-party Display packages, and provenance evidence.
7. **Guided installation**: shows the selected GPU vendor's official driver-download page and advises laptop/branded-system owners to check the system manufacturer's recommended package first. It requires an already downloaded manufacturer EXE and a signed Display INF beneath the EXE's package directory. It checks both signatures, the EXE's vendor signer, a vendor or Microsoft hardware-certified INF signer, and the selected GPU's PCI vendor/device ID in a Manufacturer-referenced model section applicable to the running Windows architecture and version. It rejects package path links, determines the INF driver version, then exports and verifies the current package before running the manufacturer's installer interactively. The exported INF must match the installed current INF by SHA-256, identify Display, and reference present, validly signed catalogs; uncertain backup evidence blocks installer launch. A valid signature does not prove download origin; obtain the package directly from an official vendor or system-manufacturer page.
8. **Verify installation**: after a restart, rechecks the selected GPU, expected driver version, changed INF, provider, device status, and pending restart state.
9. **Optional cleanup**: only after verification, checks that the old `oem#.inf` package is a unique Display package and is not in use by enumerated devices, including hidden and disconnected Display devices. Unreadable device usage blocks cleanup. It asks for explicit confirmation and exports that one package. Before deletion, the export must contain one INF with the package's recorded original filename, byte-for-byte matching the installed `Windows\INF\oem#.inf`; its Version section must identify Display and reference catalogs present beside it with valid Authenticode signatures. Empty files, linked paths, or missing evidence block deletion. It then runs `pnputil /delete-driver oem#.inf` **without** `/uninstall` or `/force` and verifies that the package disappeared.
A. **Fresh recovery cycle**: for a valid `Restored` record and a currently disabled policy (`REG_DWORD 0` or absent), explicitly archives the old record, captures the current baseline, and enables protection. The equivalent command is `powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\DriverGuard.ps1 -Action FreshCycle`.

### Policy scope

DriverGuard changes only:

`HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\ExcludeWUDriversInQualityUpdate`

`1` configures exclusion, `0` explicitly disables it, and absence means not configured. DriverGuard does not equate absence with `0`, edit other registry values, stop Windows Update, disable Defender, or prevent manual manufacturer installs. Registry readback proves configuration only. Microsoft notes that drivers included in security or critical updates and drivers installed during feature updates may still be installed. Driver delivery through device setup or management services may also occur.

### Recovery and logs

The first Enable attempt records the original key/value presence, DWORD type/value, OS, timestamp, and operation phase in `%ProgramData%\DriverGuard\original-state.ini` before writing the policy. Repeated Enable keeps that original record. Restore reconciles an interrupted `Prepared` phase: if the original value is intact, it marks the record restored; if the policy reads as `1`, it requires confirmation before restoring the recorded original. Enable refuses an ambiguous `Prepared` record with policy `1`. Unsupported original types or values, missing/corrupt backup, unsafe file permissions, or conflicting external changes stop automatic restoration. DriverGuard never deletes the whole WindowsUpdate key.

After Restore, ordinary Enable still uses the recorded original and refuses a different baseline. To begin a new cycle, choose menu **A** or `-Action FreshCycle` and type `YES` at its prompt. This action is available only with a valid `Restored` record and a disabled current policy. It stores the prior record in a unique `original-state-*.restored.ini` file in the protected data directory, checks the archive and source, then atomically writes and verifies a new `Prepared` record before changing the registry. It uses the normal Enable write, readback, and `Active` transition. `Prepared` and `Active` records cannot be rotated. If interrupted before replacement, the previous `Restored` record remains current; if interrupted afterward, use Restore to reconcile the new `Prepared` record. Archived history is retained and is not selected automatically for Restore. Status reports external change only for an `Active` record, so `External change: No` beside `Restored` does not mean the current value matches its former baseline.

System activity is logged to `%ProgramData%\DriverGuard\DriverGuard.log`; standard-user read-only actions log to `%LOCALAPPDATA%\DriverGuard\DriverGuard-user.log`. The installation journal is `%ProgramData%\DriverGuard\gpu-install.json`. DriverGuard restricts the system data directory to Administrators and SYSTEM for writes and checks state file ownership and ACLs before using recovery data. The GPU package export is retained in that directory. If a policy operation is interrupted, inspect status and use Restore to reconcile the backup before retrying.

### GPU provenance

DriverGuard uses the device instance ID to join Display devices to signed-driver CIM records and reads the device's active INF property when available. Conflicting INF values are labeled unverified. Hardware IDs that cannot be read remain unavailable. Staged driver-store packages are listed separately; matching vendor or version does not make one active.

Provenance classifications are `WINDOWS_UPDATE_CONFIRMED`, `PROBABLE_WINDOWS_UPDATE`, `PROBABLE_MANUFACTURER`, `CONFLICTING_EVIDENCE`, and `UNKNOWN`. Confirmation requires a SetupAPI Device Install section whose header names the exact device and explicitly states the Windows Update install mechanism, whose contents name its active INF, plus a matching update-history title within 48 hours. A verified DriverGuard installer journal supports only probable manufacturer origin because the installer's causation cannot be independently proven. The latest matching SetupAPI section takes precedence over older sections; contradictory same-time sections are reported as conflicting. Provider name, a nearby timestamp, and a staged package alone never establish origin. Missing or rotated history, localized titles, missing logs, and ambiguous evidence commonly leave origin unknown.

### Installation limits

Before asking for installer paths, Guided installation displays official download pages for [NVIDIA](https://www.nvidia.com/Download/index.aspx), [AMD](https://www.amd.com/en/support/download/drivers.html), or [Intel](https://www.intel.com/content/www/us/en/download-center/home.html). Select the exact GPU and Windows version. For laptops and branded systems, check the system manufacturer's recommended driver first because its package may include system-specific support.

A signed EXE and signed applicable INF in one package tree are practical evidence of manufacturer and device compatibility; they do not cryptographically prove that the EXE will install that particular INF or predict every action it will take. DriverGuard therefore refuses an opaque EXE without a verifiable matching INF. Some official installers may be rejected because their INF is compressed, hidden, or not verifiable by `Get-AuthenticodeSignature`. Do not work around a rejection by disabling signature checks. Obtain an extracted package from the manufacturer or use its documented installer outside DriverGuard and inspect afterward. A changed INF and expected version must actually be running before cleanup is offered.

Create a Windows restore point before modifications when System Protection is available. Restart when required. DriverGuard does not remove a driver merely because Windows Update installed it. Never use cleanup to remove chipset, audio, network, or unrelated packages.

The pre-install and cleanup export checks are static recovery evidence, not restore tests. They cannot prove every referenced payload is complete, that the catalog covers every file, or that Windows will accept a later `pnputil /add-driver` on the same or another system. Keep the export and a system snapshot; actual installation, removal, and recovery need separate isolated-machine validation.

Windows 10 standard support ended October 14, 2025. Blocking driver updates does not replace security updates or extend OS support.

## Troubleshooting

- **No backup**: DriverGuard cannot infer the previous policy. Review the current registry value and Windows management policy manually.
- **Backup or ACL error**: do not edit the recovery file as batch commands. Check `%ProgramData%\DriverGuard` ownership and permissions with an administrator; preserve the file for recovery.
- **External change**: a different administrator or policy engine may have changed the setting. DriverGuard refuses to overwrite it silently.
- **Unknown GPU origin**: the logs do not establish who installed the driver. Leave it unchanged unless you independently choose a supported replacement.
- **Installer rejected**: confirm that the EXE and extracted INF are from the official vendor package and match the selected device. Rejection is the safe outcome when compatibility cannot be established.
- **Pending restart**: restart, then use menu item 8. No cleanup is offered while restart evidence remains.
- **Deletion failed**: the old package may remain in use or Windows may reject removal. Keep the export and review the log; DriverGuard does not retry with force.

## Microsoft references

- [Windows Update client policy and limits](https://learn.microsoft.com/en-us/windows/deployment/update/waas-configure-wufb#exclude-drivers-from-quality-updates)
- [Update CSP edition applicability](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-update#excludewudriversinqualityupdate)
- [PnPUtil commands](https://learn.microsoft.com/en-us/windows-hardware/drivers/devtest/pnputil-command-syntax)
- [SetupAPI device installation log](https://learn.microsoft.com/en-us/windows-hardware/drivers/install/setupapi-device-installation-log-entries)
- [Get-WindowsDriver](https://learn.microsoft.com/en-us/powershell/module/dism/get-windowsdriver)
- [Authenticode signatures](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.security/get-authenticodesignature)
