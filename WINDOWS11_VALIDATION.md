# Windows 11 validation checklist

Record the edition, build, account privilege, timestamp, GPU model, active INF, policy type/value, backup phase, and DriverGuard commit for each run. Use a Windows 11 VM snapshot before any state-changing test. Save the diagnostic console output outside `%ProgramData%\DriverGuard` if a record is needed.

## Safe read-only tests

- [ ] From the repository root, run `powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\DriverGuard.Tests.ps1`. Record the actual pass/fail count.
- [ ] Run `powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\DriverGuard.ps1 -Action Diagnose` as a standard user. Confirm it reports privilege, OS, policy key/value/type, backup phase or absence, journal phase or absence, GPU instance ID, active INF/version/provider/status, driver-store inventory, and provenance evidence or an explicit unavailable state.
- [ ] Check that the diagnostic run does not create or change `%ProgramData%\DriverGuard` or `%LOCALAPPDATA%\DriverGuard` logs. Compare timestamps or hashes before and after where those files already exist.
- [ ] Compare GPU and INF output against Device Manager, `Get-CimInstance Win32_PnPSignedDriver`, and `pnputil /enum-drivers /class Display`. Compare driver-store `Published Name` with the active INF. Do not infer that a staged package is active solely from provider or version.
- [ ] Compare reported Windows Update history, SetupAPI.dev.log sections, and Device Setup Manager events by device ID, INF, and time. Record missing or rotated evidence as unavailable or unknown; do not classify origin from provider name alone.
- [ ] Repeat `Diagnose` from an already elevated PowerShell session. Confirm structured driver-store association appears if `Get-WindowsDriver -Online` is available. This step reads state only; do not choose BAT menu actions that change policy or drivers.

## Potentially disruptive tests — isolated VM or approved test machine only

Do not run these during a read-only diagnostics pass. Snapshot the machine and record the original registry value, backup file, and driver inventory first. Restore the snapshot between independent scenarios.

- [ ] **UAC:** From a standard account, start Enable and cancel UAC; verify the policy and backup are unchanged. Repeat with elevation and verify the elevated result or failure is reported accurately.
- [ ] **Policy enable:** Test original value absent, DWORD `0`, and externally configured DWORD `1` in separate snapshots. For absent and `0`, confirm the backup records the exact original, Enable writes only `ExcludeWUDriversInQualityUpdate=1`, and a second Enable keeps the first backup. For external `1`, confirm no invented backup or write.
- [ ] **Policy restore:** Restore after each successful Enable and confirm exact original value or absence by independent registry readback. Confirm unrelated WindowsUpdate key values and Windows Update services remain unchanged. Test missing, malformed, or unsafe backup and external policy conflict; each must refuse automatic restoration.
- [ ] **Interrupted operation:** Interrupt after the `Prepared` backup is written, once before policy write and once after. Use Diagnose to inspect both states. Confirm Restore reconciles intact original state or requests confirmation before restoring from value `1`; confirm Enable refuses ambiguous `Prepared` plus value `1`.
- [ ] **Reboot recovery:** Reboot after Enable, after Restore, and after an interrupted `Prepared` state. Confirm the policy value and backup phase remain consistent and that Diagnose does not silently repair state.
- [ ] **Installer and cleanup:** On suitable test hardware only, use a verified manufacturer package and create a restore point. Confirm post-reboot active INF/version before considering cleanup. Test active/shared/hidden/disconnected/uncertain device usage refusals. If optional cleanup is explicitly approved, confirm export and exact `pnputil /delete-driver oem#.inf` invocation; confirm no `/force` or `/uninstall` and no active GPU driver removal. Restore the snapshot afterward.

Record each scenario's actual command, observed result, Windows build, and whether the result was mocked, read-only native, or state-changing native. Do not mark a scenario passed solely because the registry readback says the policy is configured; Windows Update enforcement needs separate observation.
