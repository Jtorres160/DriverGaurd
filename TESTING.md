# Testing

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
