# DriverGuard v1.1

DriverGuard is a small Windows 10/11 BAT menu with a built-in Windows PowerShell helper. It configures the Windows Update policy that excludes driver-classified packages from normal quality updates, records the original registry state for recovery, inspects physical NVIDIA/AMD/Intel GPUs, and offers a cautious route to replace and optionally remove one obsolete graphics package.

## Start

Keep `DriverGuard.bat` and `DriverGuard.ps1` in the same folder. Double-click the BAT file or launch it from Command Prompt. No installation, download, background task, or scheduled task is required. The launcher uses PowerShell `RemoteSigned`; it does not override a stricter organization policy. Review the files before unblocking a downloaded archive. Read-only menu choices can run without administrator privileges. The BAT menu requests normal UAC elevation only for policy, driver installation, verification journal, and cleanup changes. If UAC is cancelled, no change is made.

The script is intended for Windows PowerShell 5.1 on Windows 10 version 1607 or later and Windows 11. Live compatibility has **not** been established across editions and builds. Microsoft's Update CSP edition table lists Pro, Enterprise, Education, and IoT Enterprise; Home effectiveness is uncertain. Managed systems may enforce a conflicting Group Policy, MDM, or WSUS policy.

## Menu

1. **Enable protection**: reads the policy, saves its first observed state, asks for confirmation, sets `REG_DWORD 1`, and reads it back.
2. **Restore original settings**: reads the protected recovery record, checks for external changes, asks for confirmation, restores the exact original value or removes only the value if it was absent, then reads it back.
3. **Check status**: independently displays OS, build, privilege, registry type/value, backup state, conflict, and limitations.
4. **View logs**: shows system and current-user logs when present.
5. **Help**: explains the policy and recovery.
6. **Inspect GPUs**: lists physical PCI NVIDIA, AMD, and Intel display devices, their active INF, hardware IDs, driver details, staged third-party Display packages, and provenance evidence.
7. **Guided installation**: requires an already downloaded manufacturer EXE and a matching signed Display INF in its extracted package tree. It checks both signatures, the EXE's vendor signer, a vendor or Microsoft hardware-certified INF signer, exact PCI vendor/device ID, and INF driver version before running the manufacturer's installer interactively. It exports the current package first and does not pass undocumented silent switches.
8. **Verify installation**: after a restart, rechecks the selected GPU, expected driver version, changed INF, provider, device status, and pending restart state.
9. **Optional cleanup**: only after verification, checks that the old `oem#.inf` package is a unique Display package and is not in use by any enumerated device. It asks for explicit confirmation, exports that one package, and runs `pnputil /delete-driver oem#.inf` **without** `/uninstall` or `/force`. It verifies that the package disappeared.

### Policy scope

DriverGuard changes only:

`HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\ExcludeWUDriversInQualityUpdate`

`1` configures exclusion, `0` explicitly disables it, and absence means not configured. DriverGuard does not equate absence with `0`, edit other registry values, stop Windows Update, disable Defender, or prevent manual manufacturer installs. Registry readback proves configuration only. Microsoft notes that drivers included in security or critical updates and drivers installed during feature updates may still be installed. Driver delivery through device setup or management services may also occur.

### Recovery and logs

The first successful Enable cycle records the original key/value presence, DWORD type/value, OS, timestamp, and operation phase in `%ProgramData%\DriverGuard\original-state.ini`. Repeated Enable keeps that original record. A verified Restore retains the record and marks it restored; later Enable can use the same original state if the current value still matches. Unsupported original types or values, missing/corrupt backup, unsafe file permissions, or conflicting external changes stop automatic restoration. DriverGuard never deletes the whole WindowsUpdate key.

System activity is logged to `%ProgramData%\DriverGuard\DriverGuard.log`; standard-user read-only actions log to `%LOCALAPPDATA%\DriverGuard\DriverGuard-user.log`. The installation journal is `%ProgramData%\DriverGuard\gpu-install.json`. DriverGuard restricts the system data directory to Administrators and SYSTEM for writes and checks state file ownership and ACLs before using recovery data. The GPU package export is retained in that directory. If an operation is interrupted, inspect status and logs before retrying.

### GPU provenance

DriverGuard correlates per-device active INF information with available Windows Update history, SetupAPI.dev.log sections, and Device Setup Manager events. A confirmed Windows Update classification requires a matching update title, a matching device/INF SetupAPI section with an explicit Windows Update marker, and timestamps within 48 hours. Likely requires matching title, device/INF section, and timing without an explicit marker. A DriverGuard-run manufacturer installation is supported by evidence only after post-install verification. Otherwise origin is **Unknown**. Provider name alone never decides provenance. Missing or rotated history, localized titles, missing logs, and ambiguous package matches commonly leave origin unknown.

### Installation limits

A signed EXE and signed matching INF in one package tree are practical evidence of manufacturer and device compatibility; they cannot prove every action the EXE will take. DriverGuard therefore refuses an opaque EXE without a verifiable matching INF. Some official installers may be rejected because their INF is compressed, hidden, or not verifiable by `Get-AuthenticodeSignature`. Do not work around a rejection by disabling signature checks. Obtain an extracted package from the manufacturer or use its documented installer outside DriverGuard and inspect afterward. A changed INF and expected version must actually be running before cleanup is offered.

Create a Windows restore point before modifications when System Protection is available. Restart when required. DriverGuard does not remove a driver merely because Windows Update installed it. Never use cleanup to remove chipset, audio, network, or unrelated packages.

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
