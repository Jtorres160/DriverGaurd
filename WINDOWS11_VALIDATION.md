# Windows 11 validation checklist

## Phase 5B/6B read-only follow-up — October 15, 2026

One present NVIDIA GeForce RTX 4080 SUPER was rechecked through PnP, PnP device properties, signed-driver CIM, video-controller CIM, and `pnputil /enum-devices /class Display`. Active `oem23.inf` and version `32.0.16.1742` agreed across independent device sources; four hardware IDs were readable. `pnputil /enum-drivers /class Display` exited `0` and listed five staged packages. Structured driver-store inventory still required elevation. The available SetupAPI.dev.log, created October 15 at 18:04 local time, contained no occurrence of the device's PCI vendor/device ID, active INF, original INF, or GPU model; no companion SetupAPI device log was found. The five successful Windows Update history items were unrelated to this GPU. Two matching Device Setup events did not establish installation source. Provenance remains `UNKNOWN`; neither a particular installer nor the reason for absent historical records was verified. The 97-check synthetic suite passed. Native Diagnose and the read-only harness exited `2`, with monitored policy and DriverGuard state files unchanged. Phase 4 live scenarios below still need isolation, rollback, and explicit authorization.

## Phase 5/6 read-only observation — October 15, 2026

Standard-user host inspection matched one NVIDIA GeForce RTX 4080 SUPER across PnP, signed-driver CIM, video-controller CIM, PnP device properties, and PnPUtil device enumeration. Active INF `oem23.inf` and version `32.0.16.1742` matched independent device-level sources. PnPUtil listed five staged Display packages; these are inventory, not active bindings. Windows Update history and Device Setup events were readable, but no SetupAPI section matched this device and active INF, so provenance remained `UNKNOWN`. No independent ground truth for the installer was available. The 86-check mocked suite passed; read-only harness exited `2` because structured driver-store inventory required elevation. Policy and DriverGuard state-file snapshots were unchanged. AMD, Intel, multi-GPU, disabled, hidden, and non-present live cases remain pending. Phase 4 live policy and recovery cases remain gated by the isolated rollback environment and authorization described below.

## Live Phase 4 readiness — October 15, 2026 follow-up

**Disposition: BLOCKED for live tests; Phase 4A/4B remain PARTIAL.** Read-only inspection found a standard-user session on a Gigabyte X870 GAMING WIFI6 host, `HypervisorPresent=False`, Windows 11 IoT Enterprise LTSC build 26100, and no WindowsUpdate policy key. Computer-scope `gpresult /r` returned access denied (exit `1`), so Group Policy ownership was not established. Enrollment subkeys were present, but an active MDM configuration or conflict was not established. No isolated VM or equivalent recovery boundary, usable snapshot identifier, or tested rollback procedure was provided. The application's own registry backup is insufficient as a machine rollback plan.

Before the state-changing matrix below, provide an isolated Windows test machine or an approved equivalent with a verified snapshot/rollback procedure, its identifier, and a separate baseline of the target value, sibling policy values and types, DriverGuard state files, and management policy ownership. Obtain explicit authorization for each intended live policy, UAC, interruption, and reboot scenario. Run independent restored snapshots for absent-value and DWORD `0` cycles, repeat Enable, UAC cancellation, interrupted writes, external conflict, corrupt/unsafe backup, and reboot persistence. Record commands, exit codes, pre/post snapshots, and any empty key left after restoring an originally absent value. The `PolicyCycle` harness now reports PARTIAL (`2`) when values are restored but key presence differs. It does not prove Windows Update enforcement. Group Policy and MDM conflict behavior, standard-user elevation, and native atomic replacement failures remain NOT TESTED.

Safe follow-up: 74 mocked passes, zero failures; read-only harness exit `2` from structured driver-store elevation requirement, monitored state unchanged. The new mocked fault cases and transaction guard are documented in [TESTING.md](TESTING.md). A final registry change after the last pre-write read remains a possible race because registry writes here are not atomic compare-and-swap operations; live concurrent policy-engine behavior requires isolated testing.

## Phase 4 read-only follow-up — October 15, 2026

Mocked suite: 63 passed, 0 failed, exit `0`. `tests\Windows11.Validation.ps1 -Mode ReadOnly`: snapshot comparison self-check passed, embedded mocked suite 63/63, native Diagnose exit `2` due to `Get-WindowsDriver -Online` requiring elevation, overall exit `2`, monitored policy and DriverGuard state-file hashes unchanged. The host reported one NVIDIA GeForce RTX 4080 SUPER with active `oem23.inf`; PnPUtil listed five staged Display packages, which were not treated as active associations. No policy cycle or reboot was run. The scenario matrix below remains untested on a recoverable isolated machine.

## Phase 4 execution record — October 15, 2026

**Disposition:** Read-only validation completed; live Phase 4A and 4B deferred. Current host: Windows 11 IoT Enterprise LTSC, version `10.0.26100`, build `26100`, standard-user session. `Win32_ComputerSystem` reports `Gigabyte Technology Co., Ltd. X870 GAMING WIFI6` and `HypervisorPresent=False`; an isolated Windows test environment and usable VM snapshot or equivalent recovery mechanism were not confirmed. Explicit approval for a live policy cycle was not given.

Commands actually run from `E:\Cursor\DriveGaurd`:

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\DriverGuard.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Windows11.Validation.ps1 -Mode ReadOnly
```

The first command exited `0` with 61 mocked passes and 0 failures. The second exited `2` as captured by PowerShell `$LASTEXITCODE`: its embedded mocked suite passed 61/61, while native `Diagnose` was partial because structured driver-store inventory required elevation. Its before/after comparison reported unchanged WindowsUpdate policy values and DriverGuard state-file hashes. An independent read found the entire `HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate` key absent, and `%ProgramData%\DriverGuard\original-state.ini`, `DriverGuard.log`, `gpu-install.json`, and `%LOCALAPPDATA%\DriverGuard\DriverGuard-user.log` absent. No backup was created or verified by a live Enable. Final observed policy state was the same absent key; no unexpected monitored change was observed. No reboot or state-changing native test was performed.

### Approval gate for a later live run

Before any Phase 4A or 4B state-changing test, record the VM identity and isolation boundary, prove a usable snapshot or equivalent recovery mechanism, record a full independent baseline, and obtain explicit approval for the live policy cycle. Record the exact snapshot identifier and restoration procedure outside the guest. Use separate restored snapshots for fault injection and reboot scenarios; do not damage the sole original recovery record. Never install, uninstall, or delete a GPU driver in Phase 4. Do not reboot automatically.

The policy cycle can create `HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate` if absent and set only its `ExcludeWUDriversInQualityUpdate` `REG_DWORD` value to `1`. Restore removes that value when originally absent or writes its original DWORD `0`; an empty key created by Enable may remain. DriverGuard can create or update `%ProgramData%\DriverGuard\original-state.ini` (first original state and transaction phase) and `%ProgramData%\DriverGuard\DriverGuard.log`, and can adjust ACLs within `%ProgramData%\DriverGuard`. A cancelled UAC attempt may use `%LOCALAPPDATA%\DriverGuard\DriverGuard-user.log` for a failure record. The policy cycle does not require `gpu-install.json`, a vendor installer, PnPUtil deletion, or any GPU driver change. The original recovery file must be preserved for review.

### Phase 4 scenario matrix for an approved isolated environment

| Scenario | Baseline and action | Evidence required | Current result |
|---|---|---|---|
| 4A-1 elevation and UAC cancellation | Standard-user launch, cancel UAC before Enable; compare pre/post target, all sibling values, backup, and logs | No policy or backup change; accurate failure exit and user-log message | Not performed |
| 4A-2 absent value cycle | Snapshot with absent target; run `PolicyCycle` interactively | Original absence saved before write; `DWord 1` readback; restored absence; sibling values unchanged; note any empty key | Not performed |
| 4A-3 DWORD 0 cycle | Snapshot with target `DWord 0`; run `PolicyCycle` interactively | Original type/value saved; `1` readback; exact `DWord 0` restoration; sibling values unchanged | Not performed |
| 4A-4 repeated Enable | After first Enable, invoke Enable again before Restore | Original backup content retained; no invented baseline; restore returns first original | Not performed |
| 4B-1 reboot persistence | Reboot manually after Enable and in a separate cycle after Restore | Independent registry and backup readback on both sides of each reboot | Not performed |
| 4B-2 interrupted Prepared | In disposable snapshots, interrupt once before policy write and once after | Diagnose reports state without repairing it; Restore reconciles intact original or requires confirmation from `1`; ambiguous Enable refuses | Not performed |
| 4B-3 external conflict | On a disposable snapshot, alter target externally after Active phase | DriverGuard refuses silent overwrite; original recovery data retained | Not performed |
| 4B-4 missing, corrupt, or unsafe backup | Separate disposable snapshots with each fault | Restore refuses; no policy write; failure output and log/exit code captured | Not performed |

For each run, save the exact command, process exit code, timestamp, Windows edition/build, account privilege, independent registry dump including sibling values and types, recovery-file content and hash, before/after log hashes or lines, snapshot identifier, and any unexpected change. The harness `-Mode PolicyCycle -ApproveStateChanges` requires an already elevated shell and two typed gates; it does not execute the manual scenarios, validate the snapshot, or reboot. Registry readback verifies configuration only; Windows Update enforcement requires separate evidence.

Record the edition, build, account privilege, timestamp, GPU model, active INF, policy type/value, backup phase, and DriverGuard commit for each run. Use a Windows 11 VM snapshot before any state-changing test. Save the diagnostic console output outside `%ProgramData%\DriverGuard` if a record is needed.

## Recorded Phase 3 run — October 15, 2026

On Windows 11 IoT Enterprise LTSC build 26100 as a standard user, `tests\Windows11.Validation.ps1 -Mode ReadOnly` returned **2 (partial)**. Its mocked suite passed **61/61** checks. Native Diagnose read an absent policy value, absent backup and journal, one NVIDIA GeForce RTX 4080 SUPER using `oem23.inf`, five successful Windows Update history items, zero matching SetupAPI sections, and two matching Device Setup events. It reported **Unknown origin**. Structured driver-store inventory required elevation; raw PnPUtil Display inventory was available. The harness found no before/after change to the policy key values or hashes of the backup, journal, and logs. This is an observation of the local host, not an enforcement test. No elevated or state-changing native test has been run.

`Diagnose` result codes: **0 COMPLETE** (all applicable sources read), **2 PARTIAL** (one or more supporting sources unavailable), **1 FAILED** (critical identity, policy, GPU, or recovery-state read/validation failed). The report lists each limitation or failure. Missing backup and journal files and unknown GPU origin are ordinary observations. Diagnose does not write activity logs or repair state.

## Safe read-only tests

- [x] Run `powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Windows11.Validation.ps1 -Mode ReadOnly`. It ran the 61-check mocked suite and native Diagnose; result was partial for the structured driver store.
- [x] Run standard-user Diagnose and confirm privilege, OS, policy key/value/type, backup, journal, GPU, active INF, inventory, and provenance or an explicit unavailable state. Observed as recorded above.
- [x] Compare policy values and SHA-256 hashes of DriverGuard backup, journal, and log files before and after the read-only harness. No change observed.
- [ ] Compare GPU and INF output against Device Manager, `Get-CimInstance Win32_PnPSignedDriver`, and `pnputil /enum-drivers /class Display`. Compare driver-store `Published Name` with the active INF. Do not infer that a staged package is active solely from provider or version.
- [ ] Compare reported Windows Update history, SetupAPI.dev.log sections, and Device Setup Manager events by device ID, INF, and time. Record missing or rotated evidence as unavailable or unknown; do not classify origin from provider name alone.
- [ ] Repeat `Diagnose` from an already elevated PowerShell session. Confirm structured driver-store association appears if `Get-WindowsDriver -Online` is available. This step reads state only; do not choose BAT menu actions that change policy or drivers.

## Potentially disruptive tests — isolated VM or approved test machine only

Do not run these during a read-only diagnostics pass. Snapshot the machine and record the original registry value, backup file, and driver inventory first. Restore the snapshot between independent scenarios.

The optional `tests\Windows11.Validation.ps1 -Mode PolicyCycle -ApproveStateChanges` mode is **not automated read-only testing**. It requires an already elevated session, a VM snapshot, a baseline target value that is absent or DWORD `0`, a typed `APPROVE POLICY CYCLE` gate, DriverGuard's own `YES` prompts for Enable and Restore, and a separate typed `RESTORE` gate. It prints independent policy and state-file snapshots before Enable, after Enable, and after Restore. It does not set up a baseline, reboot, install a driver, or remove a package. It was prepared but **not run**. A cancelled DriverGuard prompt can exit successfully without changing policy; the harness verifies value `1` and a backup before offering Restore. If the key itself was initially absent, DriverGuard removes its value on Restore but may leave the now-empty WindowsUpdate key; record that distinction when assessing exact restoration.

- [ ] **UAC:** From a standard account in a snapshotted VM, record a read-only baseline, start Enable, cancel UAC, and compare policy, backup, and log. Repeat with elevation and verify the elevated result or failure is reported accurately. The PolicyCycle harness intentionally requires an already elevated session, so UAC cancellation is a separate manual case.
- [ ] **Policy enable:** Test original value absent, DWORD `0`, and externally configured DWORD `1` in separate VM snapshots. For absent and `0`, the approved PolicyCycle mode can capture the before/after values. Confirm the backup records the exact original, Enable writes only `ExcludeWUDriversInQualityUpdate=1`, and a second Enable keeps the first backup. For external `1`, confirm no invented backup or write manually; PolicyCycle refuses this baseline.
- [ ] **Policy restore:** Restore after each successful Enable and confirm exact original value or absence by independent registry readback. Compare all other WindowsUpdate key values and Windows Update services. Distinguish target-value restoration from key-container restoration. Test missing, malformed, or unsafe backup and external policy conflict; each must refuse automatic restoration.
- [ ] **Interrupted operation:** Interrupt after the `Prepared` backup is written, once before policy write and once after. Use Diagnose to inspect both states. Confirm Restore reconciles intact original state or requests confirmation before restoring from value `1`; confirm Enable refuses ambiguous `Prepared` plus value `1`.
- [ ] **Reboot recovery:** Reboot after Enable, after Restore, and after an interrupted `Prepared` state. Confirm the policy value and backup phase remain consistent and that Diagnose does not silently repair state.
- [ ] **Installer and cleanup:** On suitable test hardware only, use a verified manufacturer package and create a restore point. Confirm post-reboot active INF/version before considering cleanup. Test active/shared/hidden/disconnected/uncertain device usage refusals. If optional cleanup is explicitly approved, confirm export and exact `pnputil /delete-driver oem#.inf` invocation; confirm no `/force` or `/uninstall` and no active GPU driver removal. Restore the snapshot afterward.

Record each scenario's actual command, observed result, Windows build, and whether the result was mocked, read-only native, or state-changing native. Do not mark a scenario passed solely because the registry readback says the policy is configured; Windows Update enforcement needs separate observation.
