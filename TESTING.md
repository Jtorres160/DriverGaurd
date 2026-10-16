# Testing

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
| A01 | Standard-user menu/status | Read-only actions work | Not run on standard-user Windows session | Not tested |
| A02 | Cancel UAC | No change | Not run | Not tested |
| A03 | Enable from absent | Save absence; write 1 | Mock passed | Pass, mocked |
| A04 | Enable from DWORD 0 | Save 0; write 1 | Mock passed | Pass, mocked |
| A05 | Already DWORD 1 | No write or invented backup | Mock passed | Pass, mocked |
| A06 | Repeated Enable | First backup retained | Mock passed | Pass, mocked |
| A07 | Restore absent | Delete value only | Mock passed | Pass, mocked |
| A08 | Restore DWORD 0 | Write 0 | Mock passed | Pass, mocked |
| A09 | Missing/corrupt backup | Refuse restoration | Mock and parser passed | Pass, mocked |
| A10 | Registry write denied | Report failure, no success | Mock passed | Pass, mocked |
| A11 | External change | Refuse overwrite | Mock passed | Pass, mocked |
| A12 | Invalid menu input | Return to menu | BAT inspection only | Not tested |
| A13 | Restart after enabling | Policy persists | No isolated Windows VM available | Not tested |
| A14 | Restart after restoring | Original state persists | No isolated Windows VM available | Not tested |
| A15 | BAT path with spaces | Menu and elevation work | Menu launch/exit worked in path with spaces; UAC continuation not run | Partial |

Additional mocked checks passed for invalid registry type, reenable after verified restore, denied write, backup format round trip, and diagnostics with no activity-log write. Real interrupted operations, failed backup creation, unexpected values, offline use, repeated live launches, and missing ProgramData directory still require isolated Windows tests.

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
