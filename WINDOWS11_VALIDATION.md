# Windows 11 validation checklist

## Phase 4B unsafe Active backup ACL — October 16, 2026

**PASS for the tested native VMware file-specific unsafe-write ACL refusal.** Read-only inspection of exported evidence at tested HEAD `83f2543232c7da4f0fbe96dd8bf77d7f66565224` confirms Restore exit `1`, refusal naming the primary recovery file, identical five registry exports (DWORD `1`), identical 200-byte recovery captures/hash (Active, original DWORD `0`), restored original file descriptor, and unchanged directory descriptor. The injected Builtin Users write ACE remained through the refused Restore. Result, cleanup, and termination artifacts report success and confirmed child termination without critical manual intervention. Stderr contains only its BOM; stdout also reports activity-log refusal at the unsafe file.

Final evidence agrees with tester-reported `EXCLUSION CONFIGURED`, `VALID (Active)`, DWORD `1`, and the live recovery hash. There are 36 exported files versus reported 35; original/export equality remains tester-reported. Snapshot restorability is not independently guest-verified. Capture time is October 17 UTC / October 16 Pacific. See [detailed evidence verification](TESTING.md) for hash and comparison details. No completed live test was repeated. Phase 4A/4B remain **PARTIAL** and Windows Update enforcement **UNVERIFIED**; other malformed/ACL variants remain open.

## Latest Phase 4B malformed-file result — October 16, 2026

**PASS, reported live VMware test:** on Windows 11 Home build 26300 with a safety snapshot available, Enable from DWORD `0` reached DWORD `1`/`VALID (Active)` and no external change. The tester saved the Active file as `original-state.active-malformed-test.bak` and replaced `original-state.ini` with `INVALID_TEST_RECORD`. Restore refused before confirmation with “Recovery backup is malformed.” Status showed DWORD `1`, `EXCLUSION CONFIGURED`, `CORRUPT`, and `External change: Unknown`. Copying back the saved Active record restored valid Active Status; normal Restore then reported independent verification of the original DWORD `0`, and final Status was `POLICY DISABLED`, DWORD `0`, `VALID (Restored)`, with no external change. This establishes refusal and recovery for this specific invalid-text record. Other malformed-file variants remain untested live; the file-specific unsafe-ACL refusal above passed. Phase 4A/4B remain **PARTIAL**; Windows Update enforcement remains **UNVERIFIED**. No development-PC registry operation was run.

## Latest Phase 4B missing-file result — October 16, 2026

**PASS, reported live VMware test:** on Windows 11 Home build 26300 with a recovery snapshot available, Enable from DWORD `0` reached DWORD `1`/`VALID (Active)` and no external change. After `%ProgramData%\DriverGuard\original-state.ini` was renamed to `original-state.missing-test.bak`, `-Action Restore` refused before confirmation: “No recovery backup exists. Original configuration cannot be inferred.” Returning the saved file restored the valid `Active` record while the policy remained DWORD `1`. Normal Restore then independently verified the recorded DWORD `0` baseline; final Status was `POLICY DISABLED`, DWORD `0`, `VALID (Restored)`, `External change: No`. This validates the missing-file refusal and recovery workflow only. The summary does not include raw hashes, sibling-value comparisons, or exit codes. No development-host live registry operation was run.

Phase 4A/4B remain **PARTIAL**. Windows Update enforcement stays **UNVERIFIED**.

## Latest Phase 4 VMware follow-up — October 16, 2026

The tester reports three further live results on Windows 11 VMware. **PASS:** declining UAC from a standard-user launch left Status at DWORD `0` and `VALID (Restored)`; approving UAC launched elevated PowerShell, then entering `NO` at Enable confirmation left the same policy and recovery state; after a post-Restore reboot, Status showed DWORD `0`, `VALID (Restored)`, and `External change: No`. These are observed Status checks, not newly supplied independent file hashes, sibling-value comparisons, log records, or process exit codes. No live operation was repeated for this documentation update. Phase 4A/4B remain **PARTIAL** for the safety cases below. Windows Update enforcement remains **UNVERIFIED**.

### Remaining Phase 4 checklist

**Release-blocking safety checks** (separate VM snapshots; do not repeat passed paths):

- [ ] Approve UAC from a standard-user launch and complete Enable with `YES`; verify the elevated result, target readback, recovery state, and failure propagation. The passed approval test stopped at Enable confirmation.
- [ ] Test ordinary Enable from a fresh DWORD `0` baseline and an already external DWORD `1` baseline in separate snapshots; independently compare the target, sibling policy values, and recovery file. The passed FreshCycle used a different entry path.
- [ ] Exercise Restore with other malformed-record variants; confirm refusal without a registry write or recovery-file replacement. Missing-file, `INVALID_TEST_RECORD`, and file-specific unsafe-write ACL Restore refusal passed live.
- [ ] With an `Active` record, externally remove the target and separately set an unsupported type/value; confirm Restore refuses before confirmation and leaves the policy and recovery file unchanged. The external DWORD `0` conflict already passed.
- [ ] Inject failures before the policy write and during backup creation/replacement, plus a denied registry write; verify no unbacked policy change, accurate failure result, and recoverable `Prepared` state where applicable. The real after-write `Prepared` recovery already passed.

**Optional hardening and evidence completion:**

- [ ] Capture independent sibling-value and recovery-file hashes, exit codes, and log results for new runs; earlier VMware summaries supplied Status and targeted registry readback without every matrix artifact.
- [ ] Reboot from an interrupted `Prepared` state, exercise the remaining FreshCycle failure paths, and test menu input or BAT paths with spaces on additional supported Windows builds.
- [ ] Check behavior under actual Group Policy or MDM management and separately investigate Windows Update enforcement. Registry persistence on Windows 11 Home does not establish enforcement.

The policy read immediately before a write is not an atomic compare-and-swap; concurrent changes after that read remain a residual risk.

## Current Phase 4 VMware status — October 16, 2026

The tester reports earlier state-changing validation on snapshotted VMware Workstation Pro, Windows 11 Home build 26300, from an Administrator Command Prompt. **Phase 4A: PARTIAL.** An absent-value Enable, independent DWORD `1` readback, valid `Active` record, repeated Enable preserving that record, and Restore to absence passed. A separate FreshCycle from a prior absent baseline captured DWORD `0`, archived the previous `Restored` record, reached `Active`/DWORD `1`, and restored DWORD `0` (`REG_DWORD 0x0` independently queried). Targeted archive checks verified the `original-state-<GUID>.restored.ini` name, expected fields, preserved absent baseline, ownership, and write permissions; this was not a complete filesystem security audit. Declining Enable with `NO` left DWORD `0` and valid `Restored` state unchanged.

**Phase 4B: PARTIAL.** DWORD `1` and valid `Active` survived a VM reboot and Restore afterward returned the original absence. A real PowerShell 5.1 replacement failure had left policy `1` and backup `Prepared`; after the atomic replacement fix, Restore recovered the absent baseline with independent verification. The old Active conflict guard prompted after an external DWORD `1` to `0` edit, but the tester answered `NO`. With commit `b75aa77673cc0717e12f48c922dad5b27d73e269` copied to the VM, Restore refused before confirmation and Status still showed DWORD `0`, valid `Active`, and `External change: Yes`. After a manual return to `1`, Status showed no external change and normal Restore returned DWORD `0` and valid `Restored`. In a separate snapshot, invalid text in the primary recovery file produced `CORRUPT`/`External change: Unknown`; Enable refused, DWORD `0` remained unchanged, and copying back the saved record restored valid `Restored` status. These are the tester's reported live results; this documentation update did not run a VM test.

**Remaining after the later follow-up above:** the release-blocking and optional items in the current checklist. Earlier UAC and post-Restore reboot gaps are now covered by the reported Status observations. Windows 11 Home registry persistence does not verify Windows Update policy enforcement (**UNVERIFIED**). The final policy read and write are not atomic.

## Active Restore conflict discovered in VMware — October 16, 2026

On a real Windows 11 VMware run, the target began as DWORD `0`; DriverGuard Enable wrote DWORD `1` and the recovery record was valid `Active`. After a manual external change to DWORD `0`, Status reported `External change: Yes`. Restore nevertheless offered confirmation because the Active guard accepted the original baseline. The tester entered `NO`, so this observation does not include an unsafe Restore write. The corrected guard subsequently refused this conflict before confirmation in VMware; the post-confirmation race remains covered only by mocks.

The corrected DWORD `0` conflict and subsequent normal Restore passed in the VM. Externally removed and unsupported type/value conflicts still need separate snapshots; the supplied report does not include byte-for-byte recovery-file hashes, commands, or exit codes for the conflict run. Capture these for later cases. The registry can still change after the final read and before the write because this is not an atomic compare-and-swap operation.

## Phase 4A VMware finding — October 16, 2026

The user reported that a Windows 11 Home build 26300 VM with an initially absent target value ran Enable, wrote `REG_DWORD 1`, and then failed to replace the existing `Prepared` recovery file because the `File.Replace` backup path was null. Status showed a valid `Prepared` record and incomplete operation. The code fix was reproduced with disposable Windows PowerShell 5.1 files and passed local regression tests. A later VMware Restore recovered this actual `Prepared`/DWORD `1` state to the absent baseline, and later normal Enable/Restore cycles passed. Phase 4A and 4B remain partial for the open scenarios below.

## Phase 5C/6C readiness — October 15, 2026

The fresh standard-user pass confirmed one present RTX 4080 SUPER and active `oem23.inf`/`32.0.16.1742` across current Windows device interfaces. These interfaces share underlying PnP/driver metadata; they provide cross-interface consistency, not independent installer history. The five staged Display packages do not establish any additional active GPU. Structured `Get-WindowsDriver -Online` requires elevation; raw PnPUtil inventory is readable but incomplete for structured association. Native Diagnose and the harness appropriately returned PARTIAL (`2`) for that source limit. The readable SetupAPI log has no matching target record, Windows Update history has no GPU item, and two Device Setup events do not establish causation. Provenance remains `UNKNOWN`; there are **zero** real installations with independently known source. See [the validation matrix](docs/VALIDATION_MATRIX.md) for physical coverage and a reproducible labeled-case plan. The Phase 4 live readiness checklist below remains in force; Phase 7 has not begun.

## Phase 5B/6B read-only follow-up — October 15, 2026

One present NVIDIA GeForce RTX 4080 SUPER was rechecked through PnP, PnP device properties, signed-driver CIM, video-controller CIM, and `pnputil /enum-devices /class Display`. Active `oem23.inf` and version `32.0.16.1742` agreed across those device interfaces; four hardware IDs were readable. `pnputil /enum-drivers /class Display` exited `0` and listed five staged packages. Structured driver-store inventory still required elevation. The available SetupAPI.dev.log, created October 15 at 18:04 local time, contained no occurrence of the device's PCI vendor/device ID, active INF, original INF, or GPU model; no companion SetupAPI device log was found. The five successful Windows Update history items were unrelated to this GPU. Two matching Device Setup events did not establish installation source. Provenance remains `UNKNOWN`; neither a particular installer nor the reason for absent historical records was verified. The 97-check synthetic suite passed. Native Diagnose and the read-only harness exited `2`, with monitored policy and DriverGuard state files unchanged. Phase 4 live scenarios below still need isolation, rollback, and explicit authorization.

## Phase 5/6 read-only observation — October 15, 2026

Standard-user host inspection matched one NVIDIA GeForce RTX 4080 SUPER across PnP, signed-driver CIM, video-controller CIM, PnP device properties, and PnPUtil device enumeration. Active INF `oem23.inf` and version `32.0.16.1742` matched independent device-level sources. PnPUtil listed five staged Display packages; these are inventory, not active bindings. Windows Update history and Device Setup events were readable, but no SetupAPI section matched this device and active INF, so provenance remained `UNKNOWN`. No independent ground truth for the installer was available. The 86-check mocked suite passed; read-only harness exited `2` because structured driver-store inventory required elevation. Policy and DriverGuard state-file snapshots were unchanged. AMD, Intel, multi-GPU, disabled, hidden, and non-present live cases remain pending. Phase 4 live policy and recovery cases remain gated by the isolated rollback environment and authorization described below.

## Historical development-host readiness — October 15, 2026

**Disposition at that time: BLOCKED for live tests on the development host; Phase 4A/4B PARTIAL.** Read-only inspection found a standard-user session on a Gigabyte X870 GAMING WIFI6 host, `HypervisorPresent=False`, Windows 11 IoT Enterprise LTSC build 26100, and no WindowsUpdate policy key. Computer-scope `gpresult /r` returned access denied (exit `1`), so Group Policy ownership was not established. Enrollment subkeys were present, but an active MDM configuration or conflict was not established. No isolated VM or equivalent recovery boundary, usable snapshot identifier, or tested rollback procedure was provided for that host. The application's own registry backup is insufficient as a machine rollback plan. Later VMware results are recorded above; this development-host gate remains in force.

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

### Phase 4 scenario matrix (current VMware evidence)

| Scenario | Baseline and action | Evidence required | Current result |
|---|---|---|---|
| 4A-1 elevation and UAC cancellation | Standard-user launch, decline UAC; separately approve UAC and decline Enable | No target or recovery-state change | PASS for both reported cancellations: Status remained DWORD `0`/`VALID (Restored)`; independent hashes, logs, and exit codes not supplied |
| 4A-2 absent value cycle | Snapshot with absent target; Enable and Restore | Original absence saved before write; `DWord 1` readback; restored absence; sibling values unchanged; note any empty key | PASS for target and recovery states; sibling values and key-container comparison not supplied |
| 4A-3 DWORD 0 cycle | Snapshot with target `DWord 0`; Enable and Restore | Original type/value saved; `1` readback; exact `DWord 0` restoration; sibling values unchanged | PASS via FreshCycle workflow; ordinary Enable from fresh DWORD `0` and sibling comparison not supplied |
| 4A-4 repeated Enable | After first Enable, invoke Enable again before Restore | Original backup content retained; no invented baseline; restore returns first original | PASS in absent-baseline cycle |
| 4B-1 reboot persistence | Reboot after Enable and in a separate cycle after Restore | Policy and backup phase persist | PASS for reported Status observations: enabled DWORD `1`/`Active` and restored DWORD `0`/`Restored` survived separate reboots; independent post-Restore registry/file hashes not supplied |
| 4B-2 interrupted Prepared | In disposable snapshots, interrupt once before policy write and once after | Restore reconciles intact original or requires confirmation from `1`; ambiguous Enable refuses | PARTIAL: real after-write `Prepared`/DWORD `1` recovered to absent. Before-write and other faults NOT TESTED |
| 4B-3 external conflict | On a disposable snapshot, alter target externally after Active phase | DriverGuard refuses before confirmation; target and original recovery data retained | PASS for external DWORD `0` with corrected script; old prompt was declined. Other types/removal and byte-for-byte file comparison NOT TESTED |
| Fresh recovery cycle | After complete Restore, use a separate snapshot with DWORD `0`, then select menu A | Prior Restored record archived, new baseline captured, Enable reaches Active, Restore returns exact baseline | PASS for DWORD `0` path and targeted archive checks; other baselines/failure paths NOT TESTED live |
| Cancellation | Decline Enable confirmation with `NO` | No policy or recovery change | PASS: DWORD `0`, valid `Restored`, and no external change after cancellation |
| 4B-4 missing, corrupt, or unsafe backup | Separate disposable snapshots with each fault | State-changing action refuses; policy unchanged; recovery file preserved for review | PARTIAL overall: missing-file and `INVALID_TEST_RECORD` Restore refused before confirmation; each saved-file return allowed normal Restore (PASS for tested branches). File-specific unsafe-write ACL refusal also PASS with exit `1`, identical registry/recovery captures, restored file ACL and unchanged directory ACL; other malformed/ACL variants NOT TESTED live |

For each new run, save the exact command, process exit code, timestamp, Windows edition/build, account privilege, independent registry dump including sibling values and types, recovery-file content and hash, before/after log hashes or lines, snapshot identifier, and any unexpected change. The harness `-Mode PolicyCycle -ApproveStateChanges` requires an already elevated shell and two typed gates; it does not execute the manual scenarios, validate the snapshot, or reboot. Registry readback verifies configuration only; Windows Update enforcement requires separate evidence.

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

- [x] **UAC observation:** Standard-user UAC decline and UAC approval followed by `NO` at Enable both left Status at DWORD `0`/`VALID (Restored)`. Additional log, hash, and exit-code evidence was not supplied.
- [ ] **Policy enable, remaining variants:** Run ordinary Enable from a fresh DWORD `0` snapshot and test externally configured DWORD `1`; compare sibling settings and recovery-file state. Absent-baseline Enable and FreshCycle from DWORD `0` have passed.
- [ ] **Policy restore, remaining variants:** Compare sibling settings and key-container presence, and test Restore refusal for other malformed recovery files and externally removed or unsupported policy values. Missing-file, `INVALID_TEST_RECORD`, and file-specific unsafe-write ACL refusal, normal absent and DWORD `0` restoration, and the corrected external DWORD `0` conflict have passed.
- [ ] **Interrupted operation, remaining variants:** Inject a pre-write interruption and backup/registry failures; inspect the `Prepared` state and refusal behavior. Actual after-write `Prepared` recovery has passed.
- [ ] **Reboot recovery, remaining variant:** Reboot from an interrupted `Prepared` state and confirm Diagnose does not silently repair it. Enabled-state and post-Restore reboot Status observations have passed.
- [ ] **Installer and cleanup:** On suitable test hardware only, use a verified manufacturer package and create a restore point. Confirm post-reboot active INF/version before considering cleanup. Test active/shared/hidden/disconnected/uncertain device usage refusals. If optional cleanup is explicitly approved, confirm export and exact `pnputil /delete-driver oem#.inf` invocation; confirm no `/force` or `/uninstall` and no active GPU driver removal. Restore the snapshot afterward.

Record each scenario's actual command, observed result, Windows build, and whether the result was mocked, read-only native, or state-changing native. Do not mark a scenario passed solely because the registry readback says the policy is configured; Windows Update enforcement needs separate observation.
