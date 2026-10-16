# Testing

## Phase 4B malformed Active recovery record — October 16, 2026

The tester reports a live VMware Workstation Pro run on Windows 11 Home build 26300 from an Administrator Command Prompt, with a safety snapshot available. Starting at DWORD `0`/`VALID (Restored)`, Enable with `YES` reached DWORD `1`, `EXCLUSION CONFIGURED`, `VALID (Active)`, and `External change: No`. The Active record was saved as `original-state.active-malformed-test.bak`, and the primary `original-state.ini` was replaced with `INVALID_TEST_RECORD`. Restore refused **before confirmation** with “Recovery backup is malformed.” Status then showed DWORD `1`, `EXCLUSION CONFIGURED`, `CORRUPT`, and `External change: Unknown`. After the saved Active record was copied back, Status returned to DWORD `1`/`VALID (Active)` with no external change. Normal Restore identified the original DWORD `0`, reported independent verification, and final Status showed `POLICY DISABLED`, DWORD `0`, `VALID (Restored)`, and no external change. **PASS for this malformed-file Restore refusal and recovery workflow.** This is user-reported live VM evidence, separate from the local automated suite. Other malformed-record variants and unsafe-permission Restore behavior remain untested live; Windows Update enforcement remains **UNVERIFIED**.

## Phase 4B missing recovery file — October 16, 2026

The tester reports a live VMware Workstation Pro run on Windows 11 Home build 26300 from an Administrator Command Prompt, with a recovery snapshot available. Enable from an original DWORD `0` baseline reached `EXCLUSION CONFIGURED`, DWORD `1`, `VALID (Active)`, and `External change: No`. The tester renamed `%ProgramData%\DriverGuard\original-state.ini` to `original-state.missing-test.bak`. `-Action Restore` refused with “No recovery backup exists. Original configuration cannot be inferred.” before any confirmation prompt. After the saved file was renamed back, Status still showed DWORD `1`, `VALID (Active)`, and no external change. Normal Restore then reported the recorded DWORD `0` baseline and independent verification; final Status showed `POLICY DISABLED`, DWORD `0`, `VALID (Restored)`, and no external change. **PASS for the tested missing-file refusal and recovery workflow.** This is reported live VM evidence, separate from the local mocked suite; no new VM run was performed for this documentation update.

The missing-file result did not establish malformed-record Restore behavior; the later `INVALID_TEST_RECORD` scenario above tested one such case. Unsafe-permission Restore behavior and Windows Update enforcement remain **UNVERIFIED**. See the [current Phase 4 checklist](WINDOWS11_VALIDATION.md) for remaining safety cases.

## Latest Phase 4 VMware results — October 16, 2026

The tester reports three additional live Windows 11 VMware observations. **PASS:** standard-user UAC decline left Status at DWORD `0` and `VALID (Restored)`; UAC approval launched elevated PowerShell, then `NO` at Enable confirmation left the same state; and a reboot after Restore left Status at DWORD `0`, `VALID (Restored)`, with `External change: No`. These are Status observations, not a new automated suite or independent file-hash/log/exit-code evidence. Previously passed VMware scenarios were not repeated for this documentation update. The current [Phase 4 matrix and remaining checklist](WINDOWS11_VALIDATION.md) separate release-blocking safety cases from optional hardening. Windows Update enforcement remains **UNVERIFIED**.

## Phase 4 VMware follow-up — October 16, 2026

The tester reports live Windows 11 Home build 26300 results from VMware Workstation Pro, using an Administrator Command Prompt and multiple recovery snapshots. **PASS:** an absent-value Enable/Restore cycle (independent DWORD `1` readback, valid `Active` record, repeated Enable retaining that record, and restored absence); DWORD `1` and `Active` surviving a reboot, followed by successful Restore; recovery of the earlier real PowerShell 5.1 `Prepared`/DWORD `1` interruption to the original absent value; a FreshCycle from a prior absent baseline to a new DWORD `0` baseline, including archive verification, Active transition, and independent `REG_DWORD 0x0` readback after Restore; and an Enable prompt declined with `NO` that left DWORD `0` and the valid `Restored` record intact. Archive validation checked expected fields, the prior absent baseline, ownership, and write permissions; it was not a complete filesystem security audit.

**PASS after correction:** with an `Active` record and original DWORD `0`, a manual external change from `1` to `0` made Status report `External change: Yes`. The old Restore offered confirmation; the tester answered `NO`. After installing commit `b75aa77673cc0717e12f48c922dad5b27d73e269` in the VM, Restore refused before confirmation, and Status still showed DWORD `0`, valid `Active`, and the external change. The tester manually returned the value to `1`; Status then reported no external change, and normal Restore returned DWORD `0` with a valid `Restored` record. **PASS for the tested corruption case:** after saving a valid record, replacing the primary file with invalid text made Status report `CORRUPT` and `External change: Unknown`; Enable refused with “Recovery backup is malformed.” DWORD `0` remained unchanged, and copying back the saved record restored valid `Restored` status. These are user-reported live VM observations; no new VM test was run during this documentation update.

Phase 4A and 4B remain **PARTIAL**: later UAC and post-Restore reboot observations passed as recorded above, while other interruption and failure-injection paths, unsupported conflict types/removal, and the remaining matrix cases need live evidence. Windows 11 Home registry persistence does not establish Windows Update enforcement (**UNVERIFIED**). The final registry check/write interval is not atomic. The development PowerShell 5.1 suite passed 141/141 after the conflict fix; this is local automated evidence, separate from the VM tests.

## Active Restore external-policy conflict — October 16, 2026

In a real Windows 11 VMware test, the original policy was DWORD `0`; Enable wrote DWORD `1` and left a valid `Active` recovery record. The tester then changed the value outside DriverGuard back to DWORD `0`. Status correctly reported `External change: Yes`, but Restore reached its confirmation prompt because its Active guard also accepted the recorded original baseline. The tester answered `NO`; no unsafe Restore occurred. This was a live discovery of the old guard; the corrected refusal was subsequently confirmed in VMware as described above.

Restore now requires the recorded `LastWritten` DWORD `1` for an Active record before prompting, and rereads the policy after confirmation before writing. The separate Prepared reconciliation path remains available. Mocked tests cover Active success, external DWORD `0`, removal, unsupported type/value, unchanged registry and recovery record after refusal, the confirmation race, Prepared recovery, and exact DWORD `0` and absent restoration. The full Windows PowerShell 5.1 suite passed **141/141**, exit `0`; parser checks found zero errors in the application and both test scripts. No live registry test ran on the development PC. The corrected DWORD `0` conflict refusal subsequently passed in VMware; other mocked conflict variants have not been tested live.

## Fresh recovery cycle — October 16, 2026

In the VMware test, a completed absent-value Enable/Restore cycle left a valid `Restored` record. After the tester manually set the value to DWORD `0`, ordinary Enable refused because that record described an absent original. This was a legitimate discovered recovery-record lifecycle limitation, **not** a failed registry-write test: the refusal occurred before confirmation and policy modification. The new explicit `FreshCycle` action archives the prior Restored record and captures the current disabled baseline. That earlier VMware run did not exercise the new action; a later VM run did, as recorded above.

The local Windows PowerShell 5.1 suite passed 132/132, exit `0`. Mocked tests cover fresh cycles from DWORD `0` and absent, exact restoration, record-state and policy refusal, cancellation, archival and Prepared-write faults, interruption reconciliation, and policy changes during confirmation or after preparation. A disposable-file test exercises real archival and atomic rotation, verifies that the old record remains archived, and refuses replacement of a `Prepared` record; privileged ACL writes are stubbed. PowerShell 5.1 parsing found zero errors in the application and both test scripts. No live registry write, driver installation, or cleanup was performed on the development PC. The later VM run verified the tested FreshCycle and targeted archive ownership/write-permission checks; other rotation failure paths remain mocked.

## Phase 4A atomic replacement fix — October 16, 2026

A user-reported live VMware run on Windows 11 Home build 26300 began with `ExcludeWUDriversInQualityUpdate` absent. Enable wrote `REG_DWORD 1`, then failed while advancing the recovery record from `Prepared` to `Active` with `[IO.File]::Replace` reporting “The path is not of a legal form.” Status subsequently reported a valid `Prepared` backup and an incomplete operation. This was the initial live observation; the later Restore recovered that interrupted state as recorded above.

The failure was reproduced locally with disposable files under **Windows PowerShell 5.1**: `[IO.File]::Replace(source,destination,$null)` threw the same error and left the destination unchanged. Supplying a real rollback path in the same directory succeeded, advanced the destination to `Active`, and retained its prior `Prepared` content in the rollback file. `Write-Atomic` now uses that path, verifies destination content and secure state before deleting the temporary rollback copy, and retains the old copy if post-replacement verification fails. The existing `Prepared` recovery logic is unchanged.

The full suite passed **102/102**, exit `0`. Five new assertions exercise real filesystem replacement of an existing file, a missing-source failure that preserves the destination, and a post-replacement readback failure that retains the prior content. The ACL check is stubbed only for this disposable standard-user fixture; no privileged state path was changed. PowerShell 5.1 parser checks found zero errors in `DriverGuard.ps1` and both test scripts. The read-only host harness passed its snapshot self-check and embedded suite, then returned `2` because structured driver-store inventory still requires elevation; monitored policy values and DriverGuard state-file hashes were unchanged. At the time of this fix, the corrected flow still required VMware retesting. Later VM runs above verified normal and interrupted recovery paths; Phase 4A remains partial for other scenarios.

## Phase 5C/6C independent read-only assessment — October 15, 2026

Fresh runs: `tests/DriverGuard.Tests.ps1` passed 97/97, exit `0`; `tests/Windows11.Validation.ps1 -Mode ReadOnly` passed its snapshot self-check and embedded 97/97 mocked assertions, while native Diagnose and the harness exited `2` (PARTIAL). PowerShell 5.1 parsed `DriverGuard.ps1` and both test scripts with zero errors. The harness reported unchanged monitored policy values and DriverGuard state-file hashes. No elevation or Windows configuration, driver, or reboot action occurred.

Direct standard-user reads again found one started NVIDIA GeForce RTX 4080 SUPER on Windows 11 IoT Enterprise LTSC build 26100. PnP device properties, signed-driver CIM, video-controller CIM, and PnPUtil device enumeration agreed on the device and driver version `32.0.16.1742`; PnP properties, signed-driver CIM, and PnPUtil agreed on active `oem23.inf`. The provider was NVIDIA and four hardware IDs were readable. These interfaces largely read the same Windows PnP/driver state; their agreement checks consistency and binding, but is not independent installation-origin evidence. PnPUtil's separate store listing contained five staged Display packages, including inactive NVIDIA and AMD packages. Package provider/version matching alone was never used as an active binding.

`Get-WindowsDriver -Online` still returned “The requested operation requires elevation” under this standard-user token. PnPUtil's read-only fallback exited `0` and exposed the five packages, but lacks structured association; Diagnose correctly reported that limitation and exit `2`. The available SetupAPI log was readable but had no target vendor/device ID, active INF, original INF, or model; this is **NOT FOUND**, distinct from an inaccessible log. All five successful Windows Update history entries were unrelated to the GPU, and the two Device Setup events did not name the installer. Thus no existing record provides an independently labeled installation; `UNKNOWN` is appropriate and does not itself cause diagnostic failure. The diagnostic audit found no demonstrated code defect requiring a change. See the [validation matrix](docs/VALIDATION_MATRIX.md) for case counts, hardware gaps, and the future ground-truth procedure. Phase 5 and Phase 6 remain **PARTIAL**.

## Phase 5B/6B hardening — October 15, 2026

The PowerShell 5.1 mocked suite passed **97/97**, exit `0`. Eleven new synthetic checks cover fractional SetupAPI timestamps, exact device and INF mismatch, staged package imports, incidental Windows Update text, manual installation, same-version reinstallation, contradictory chronology, unverified active INF, and unsupported manufacturer confirmation. The read-only Windows 11 harness embedded the 97 passing checks and exited `2`; native Diagnose exited `2` because structured `Get-WindowsDriver -Online` inventory requires elevation. All three PowerShell scripts parsed with zero errors. The harness found monitored policy values and DriverGuard state-file hashes unchanged. No policy, device, driver, or Windows Update setting was modified.

Native standard-user checks used `Get-PnpDevice`, `Get-PnpDeviceProperty`, `Get-CimInstance Win32_PnPSignedDriver`, `Get-CimInstance Win32_VideoController`, `pnputil /enum-devices /class Display`, and `pnputil /enum-drivers /class Display`. They found one present, healthy NVIDIA GeForce RTX 4080 SUPER. Device-level sources agreed on active `oem23.inf` and version `32.0.16.1742`; the signed-driver provider was NVIDIA. Four hardware IDs were readable. Both PnPUtil commands exited `0`; the driver-store listing contained five staged Display packages. This host provides no real AMD, Intel, hybrid, disabled, or non-present Display case.

The available `C:\Windows\INF\setupapi.dev.log` was created October 15 at 18:04 local time and contained **zero** occurrences of the GPU's PCI vendor/device ID, active `oem23.inf`, original `nv_dispi.inf`, or GPU model. No `setupapi.dev*` companion log was present in the inspected INF directory. The five successful items in the latest Windows Update history were Windows Security, audio, Realtek software-component, and Windows App Runtime updates; none was a GPU driver. Two Device Setup Manager events matched the device, but they do not identify the installer. The available log therefore lacks this installation record. Log reset/retention or installation before this log began is plausible, not established. The actual installation mechanism remains `UNKNOWN` with no independently verified ground truth.

The SetupAPI parser now accepts only `Device Install (...) - <exact instance ID>` section headers that contain the active INF, preserves fractional timestamp precision, and regards only a header explicitly stating `Install Windows Update driver` as a direct Windows Update marker. This prevents staged-package and incidental-text false positives. Other SetupAPI section formats or localized mechanism labels may be missed, so an absent match remains `NOT FOUND` within the available log rather than proof that installation never occurred. Manufacturer confirmation is not implemented: a verified DriverGuard journal remains `PROBABLE_MANUFACTURER` because it does not independently prove installer causation. A real `WINDOWS_UPDATE_CONFIRMED` result would require a matching exact device/active-INF SetupAPI install section with an explicit Windows Update mechanism, a corresponding update-history item, and consistent chronology; the synthetic fixture does not establish a real installation. Phase 4 live validation gates below remain unchanged.

## Phase 5 and 6 read-only development — October 15, 2026

The Windows PowerShell 5.1 mocked suite passed **86/86**, exit `0`. New synthetic checks cover unavailable hardware IDs, duplicate Display rows, conflicting active INF sources, exact device/INF provenance identity, older Windows Update markers, unavailable active INF, and conflicting journal evidence. Parser inspection of the three PowerShell scripts found zero errors. The read-only Windows 11 harness embedded the 86 passing checks; native Diagnose returned `2` and the harness returned `2` because `Get-WindowsDriver -Online` requires elevation in this standard-user session. Its before/after policy values and DriverGuard state-file hashes were unchanged.

Native read-only observations on Windows 11 IoT Enterprise LTSC build 26100 found one present NVIDIA GeForce RTX 4080 SUPER. `Get-PnpDevice`, `Win32_PnPSignedDriver`, `Win32_VideoController`, PnP device properties, and `pnputil /enum-devices /class Display` agreed on the device identity. The signed-driver CIM record, PnP active INF property, and PnPUtil device record agreed on active `oem23.inf`, provider NVIDIA, and version `32.0.16.1742`. Four hardware ID variants were available. The separate PnPUtil driver-store inventory showed five staged Display packages, including inactive NVIDIA and AMD packages; structured inventory remained unavailable. Only this NVIDIA hardware was physically inspected. AMD, Intel, hybrid, disabled, hidden, and non-present cases remain synthetic or untested on this host.

For provenance, the native diagnostic inspected the latest 1000 Windows Update history records, SetupAPI.dev.log, and Device Setup Manager events. It found five successful update-history items, zero SetupAPI sections matching the device and active INF, and two device events. Classification was `UNKNOWN`; the actual installation mechanism has no independently established ground truth. The synthetic `WINDOWS_UPDATE_CONFIRMED` case is not a native confirmation. The current SetupAPI parser requires an exact device ID in the section header and active INF in the section body; log rotation, differing section formats, or missing records can produce unknown. A title match can still be ambiguous on same-model devices, so confirmation should be reviewed against the underlying records. No system-modifying operation was run. Phase 4A and 4B live gates below remain open; Phase 5 and 6 are **PARTIAL** pending broader hardware and independently verified provenance cases.

## Phase 4 safe validation follow-up — October 15, 2026

Commands from the repository root: `powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\DriverGuard.Tests.ps1` passed **74/74** mocked checks, exit `0`; `powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Windows11.Validation.ps1 -Mode ReadOnly` passed its snapshot self-check and embedded 74 checks, but native Diagnose and the harness exited `2` (PARTIAL) because structured driver-store inventory required elevation. The harness reported that monitored WindowsUpdate policy values and DriverGuard state-file hashes were unchanged. PowerShell 5.1 parsed the three changed scripts with zero syntax errors.

New mocked cases cover policy changes during Enable and Restore confirmation, a change after the Prepared backup was written, failure of the initial backup write, failure of the Active-phase replacement after the policy write, and recovery from that Prepared record. The registry mock now returns a fresh value object on each read, as the real registry reader does. These results validate refusal and transaction ordering only in mocks.

Read-only host checks reported Windows 11 IoT Enterprise LTSC build 26100, a standard-user token, Gigabyte X870 GAMING WIFI6, `HypervisorPresent=False`, and an absent WindowsUpdate policy key. Computer-scope `gpresult /r` returned access denied (exit `1`). Enrollment registry subkeys exist, but that alone does not identify an active MDM policy owner. A verified isolated test machine, rollback snapshot, and management-policy baseline have not been established. No live policy writes, elevation, UAC prompt, reboot, driver installation, or package deletion were run. Phase 4A/4B remain **PARTIAL**; see the [live readiness checklist](WINDOWS11_VALIDATION.md).

## Phase 4 safe follow-up — October 15, 2026

From `E:\Cursor\DriveGaurd`, the mocked suite passed **63/63**, exit `0`, after adding regression coverage for a completed Restore followed by an external DWORD `1` policy change. Restore now refuses to use a `Restored` recovery record to overwrite that later external value. The read-only Windows 11 harness passed its snapshot comparison self-check, ran the same 63 mocked checks, and exited `2`: native Diagnose remained partial because structured driver-store enumeration required elevation. The harness reported unchanged WindowsUpdate policy values and DriverGuard state-file hashes. PowerShell 5.1 parsed the three changed scripts with zero syntax errors. No live policy write, elevation, reboot, GPU installation, or package deletion was performed. Phase 4A and 4B live scenarios remain pending the gates in [WINDOWS11_VALIDATION.md](WINDOWS11_VALIDATION.md).

## Phase 4 preparation and read-only result — October 15, 2026

On the current Windows 11 IoT Enterprise LTSC build 26100 host, these commands were run from the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\DriverGuard.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Windows11.Validation.ps1 -Mode ReadOnly
```

The mocked suite exited `0`: **61 passed, 0 failed**. The native read-only harness exited `2` (confirmed from PowerShell's `$LASTEXITCODE`): its embedded mocked suite passed 61/61, and native `Diagnose` exited `2` because structured `Get-WindowsDriver -Online` inventory required elevation. Raw read-only PnPUtil Display inventory was available. The harness reported that all monitored WindowsUpdate policy values and SHA-256 hashes of the backup, journal, system log, and user log were unchanged. An independent read found the WindowsUpdate policy key absent and each of those DriverGuard state files absent. These results are read-only host observations and mocked tests, not a live policy cycle or evidence of Windows Update enforcement.

The host reports `Gigabyte Technology Co., Ltd. X870 GAMING WIFI6` and `HypervisorPresent=False`. An isolated test environment and a usable snapshot or equivalent recovery mechanism were **not confirmed**, and no approval for a live policy cycle was given. Phase 4A live elevation, backup, Enable, repeated Enable, Restore, unrelated-setting preservation, and UAC cancellation remain **not performed**. Phase 4B reboot persistence, interrupted Prepared recovery, external conflict, damaged recovery file, and live logging/exit-code cases also remain **not performed**. No reboot, registry write, GPU installation, or driver deletion was run.

The Phase 4 execution matrix and approval gates are in [WINDOWS11_VALIDATION.md](WINDOWS11_VALIDATION.md). The existing `PolicyCycle` harness covers only one interactive Enable/Restore cycle from an absent or DWORD `0` baseline; it does not establish isolation or snapshot availability, repeat Enable, UAC cancellation, reboot behavior, or all recovery failure cases. Its `-ApproveStateChanges` switch and typed prompt are local guards, not substitutes for the required external approval and recovery checks.

Run the nondisruptive suite from the `DriveGaurd` repository root (the directory containing `DriverGuard.ps1`):

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\DriverGuard.Tests.ps1
```

The suite dot-sources `DriverGuard.ps1` in test mode and mocks Windows registry, CIM, PnPUtil, signing, installer, journal, and restart calls. It never invokes a real driver installer, `pnputil /delete-driver`, or live policy write. The Phase 3 run on October 15, 2026 reported **61 passed, 0 failed** under Windows PowerShell 5.1, including complete, partial, and failed Diagnose outcomes. This is a mocked result, not a live Windows policy or GPU compatibility pass.

Run the Windows-native read-only harness with `powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Windows11.Validation.ps1 -Mode ReadOnly`. It runs the mocked suite and native Diagnose, then compares the policy key values and SHA-256 hashes of DriverGuard backup, journal, and logs. Its exit codes are `0` complete, `2` partial diagnostics, and `1` test failure or changed monitored state. The October 15 run returned **2**: mocked tests passed, native Diagnose was partial because structured `Get-WindowsDriver -Online` inventory required elevation, and monitored policy values and state-file hashes were unchanged. The raw PnPUtil fallback displayed staged Display packages without claiming an active package association.

`Diagnose` alone now exits `0` when all applicable sources were read, `2` when supporting sources were unavailable, and `1` when Windows identity, policy, GPU inventory, or an existing recovery file could not be read or validated. It prints each reason. An unknown driver origin is a valid observation, not a test failure. No live policy change, driver installation, package removal, or reboot was performed.

The read-only native diagnostic action was also run on a Windows 11 IoT Enterprise LTSC host, build 26100, as a standard user. It found one NVIDIA GPU with active `oem23.inf`, five successful Windows Update history items, zero matching SetupAPI sections, two Device Setup events, no DriverGuard policy value or backup, and **Unknown origin**. `Get-WindowsDriver -Online` required elevation; the report displayed raw read-only PnPUtil Display inventory and did not claim a verified structured package association. Before/after SHA-256 checks found the DriverGuard log files unchanged. This observation is specific to this host.

| ID | Case | Expected | Actual | Status |
|---|---|---|---|---|
| A01 | Standard-user menu/status | Read-only actions work | Status observed after standard-user UAC decline; full menu path not reported | PARTIAL |
| A02 | Cancel UAC | No change | UAC declined; Status remained DWORD `0`/`VALID (Restored)` | PASS for observed state; logs/hashes not supplied |
| A03 | Enable from absent | Save absence; write 1 | Mock and VMware readback passed | PASS, live and mocked |
| A04 | Enable from DWORD 0 | Save 0; write 1 | FreshCycle captured 0 and enabled 1 in VMware | PASS, tested FreshCycle path; ordinary Enable from 0 remains mocked |
| A05 | Already DWORD 1 | No write or invented backup | Mock passed | Pass, mocked |
| A06 | Repeated Enable | First backup retained | Mock and VMware passed | PASS, live and mocked |
| A07 | Restore absent | Delete value only | Mock and VMware readback passed | PASS, live and mocked |
| A08 | Restore DWORD 0 | Write 0 | Mock and VMware independent `REG_DWORD 0x0` readback passed | PASS, live and mocked |
| A09 | Missing/corrupt backup | Refuse restoration | Mock passed; VMware missing-file Restore and `INVALID_TEST_RECORD` Restore refused before confirmation, then normal Restore succeeded after saved-file return | PARTIAL overall: tested missing and one malformed Restore case PASS; other malformed and unsafe-permission variants open |
| A10 | Registry write denied | Report failure, no success | Mock passed | Pass, mocked |
| A11 | External change | Refuse overwrite | Mock passed; corrected Active/DWORD `0` refusal confirmed in VMware | PASS for tested conflict; other variants mocked |
| A12 | Invalid menu input | Return to menu | BAT inspection only | Not tested |
| A13 | Restart after enabling | Policy persists | VMware reboot retained DWORD `1` and valid `Active` | PASS, live |
| A14 | Restart after restoring | Original state persists | VMware reboot Status: DWORD `0`, `VALID (Restored)`, `External change: No` | PASS for observed state; independent hashes not supplied |
| A15 | BAT path with spaces | Menu and elevation work | Menu launch/exit worked in path with spaces; UAC continuation not run | Partial |

Additional mocked checks passed for invalid registry type, reenable after verified restore, denied write, backup format round trip, and diagnostics with no activity-log write. One real `Prepared`/DWORD `1` interruption was recovered in VMware. Other interruption and failure-injection cases, failed backup creation, unexpected values, offline use, and a missing ProgramData directory still require isolated Windows tests.

## GPU v1.1.1 cases

| Case | Expected | Actual | Status |
|---|---|---|---|
| NVIDIA detection | Physical NVIDIA PCI device identified | Vendor test passed | Pass, mocked |
| AMD detection | Physical AMD PCI device identified | Vendor test passed | Pass, mocked |
| Intel integrated graphics | Physical Intel PCI device identified | Vendor test passed | Pass, mocked |
| Hybrid graphics | Both GPUs and their own INFs shown | Mock passed | Pass, mocked |
| Missing Windows Update history | Unknown origin | Mock passed | Pass, mocked |
| Multiple matching INF entries | Cleanup refused | Mock passed | Pass, mocked |
| Unknown provenance | Provider/title alone insufficient | Mock passed | Pass, mocked |
| Invalid installer file | Refused | Mock passed | Pass, mocked |
| Installer/device mismatch | Refused | Mock passed | Pass, mocked |
| Wrong architecture or future OS INF model | Refused | Mock passed | Pass, mocked |
| Commented or unreferenced hardware ID | Refused | Mock passed | Pass, mocked |
| Unsigned installer | Refused | Mock passed | Pass, mocked |
| Failed driver installation | No cleanup | Mocked nonzero installer exit, failed journal, and log passed | Pass, mocked |
| Interrupted installation | No success claim | Mock passed | Pass, mocked |
| Pending restart | Defer verification and cleanup | Mock passed | Pass, mocked |
| Manufacturer replacement | New INF/version running | Post-restart verification mock passed | Pass, mocked |
| Safe obsolete cleanup | Eligible only when unique and unused | Eligibility and targeted non-forced command mock passed | Pass, mocked |
| Active/shared driver refusal | Refused | Mock passed | Pass, mocked |
| Hidden/disconnected device usage | Refused | Mock passed | Pass, mocked |
| Unreadable device usage | Refused | Mock passed | Pass, mocked |
| Detection and logging after reboot | Correct active INF logged | Mock passed | Pass, mocked |

No disruptive real-GPU or real-registry test was run. The suite does not establish actual Windows Update provenance accuracy, vendor installer behavior, package catalog behavior, or live PnPUtil deletion. These require snapshots and explicit approval in an isolated Windows 10/11 VM with suitable GPUs or pass-through devices.

## Suggested isolated validation

Use the detailed [Windows 11 validation checklist](WINDOWS11_VALIDATION.md) to record read-only observations first and keep potentially disruptive tests in a snapshotted environment.

1. Snapshot a Windows 11 Pro VM and record the OS build, registry value/type, Display devices, active INFs, Windows Update history, and driver store inventory.
2. Run A01–A15 with separate snapshots for absent, DWORD 0, DWORD 1, malformed backup, denied registry access, cancelled UAC, external policy change, and reboot cases. Confirm security and cumulative update settings remain unchanged.
3. On suitable physical or pass-through NVIDIA, AMD, and Intel hardware, compare inspection output with Device Manager, `Win32_PnPSignedDriver`, SetupAPI.dev.log, and Windows Update history. Include hybrid systems and missing history.
4. Use only a vendor package whose EXE and extracted INF pass signature and hardware checks. Create a restore point, run the interactive installer, restart if required, and confirm DriverGuard's observed INF/version and device status.
5. For cleanup, verify every device using the old INF is absent before confirming. Check the export and deletion result. Separately test active/shared package refusal. Restore the VM snapshot after each disruptive scenario.
6. Record actual results by Windows edition/build. Do not infer Home policy enforcement from a registry readback.
