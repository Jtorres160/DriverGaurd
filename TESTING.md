# Testing

Run the nondisruptive suite from the project directory:

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\DriverGuard.Tests.ps1
```

The suite dot-sources `DriverGuard.ps1` in test mode and mocks Windows registry, CIM, PnPUtil, signing, installer, journal, and restart calls. It never invokes a real driver installer, `pnputil /delete-driver`, or live policy write. On October 15, 2026, it reported **44 passed, 0 failed**. PowerShell parser validation reported no errors. The BAT menu launched and exited through option 0 both in the project folder and in a temporary folder containing spaces. A live Summary call reported `STATUS UNAVAILABLE: Access to a CIM resource was not available to the client` in this restricted execution environment. That is an environment limitation, not a Windows compatibility pass.

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

Additional mocked checks passed for invalid registry type, reenable after verified restore, denied write, and backup format round trip. An interrupted policy operation, failed backup creation, unexpected values, offline use, repeated live launches, and missing ProgramData directory still require isolated Windows tests.

## GPU v1.1 cases

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
| Unsigned installer | Refused | Mock passed | Pass, mocked |
| Failed driver installation | No cleanup | Mocked nonzero installer exit, failed journal, and log passed | Pass, mocked |
| Interrupted installation | No success claim | Mock passed | Pass, mocked |
| Pending restart | Defer verification and cleanup | Mock passed | Pass, mocked |
| Manufacturer replacement | New INF/version running | Post-restart verification mock passed | Pass, mocked |
| Safe obsolete cleanup | Eligible only when unique and unused | Eligibility and targeted non-forced command mock passed | Pass, mocked |
| Active/shared driver refusal | Refused | Mock passed | Pass, mocked |
| Detection and logging after reboot | Correct active INF logged | Mock passed | Pass, mocked |

No disruptive real-GPU or real-registry test was run. The suite does not establish actual Windows Update provenance accuracy, vendor installer behavior, package catalog behavior, or live PnPUtil deletion. These require snapshots and explicit approval in an isolated Windows 10/11 VM with suitable GPUs or pass-through devices.

## Suggested isolated validation

1. Snapshot a Windows 11 Pro VM and record the OS build, registry value/type, Display devices, active INFs, Windows Update history, and driver store inventory.
2. Run A01–A15 with separate snapshots for absent, DWORD 0, DWORD 1, malformed backup, denied registry access, cancelled UAC, external policy change, and reboot cases. Confirm security and cumulative update settings remain unchanged.
3. On suitable physical or pass-through NVIDIA, AMD, and Intel hardware, compare inspection output with Device Manager, `Win32_PnPSignedDriver`, SetupAPI.dev.log, and Windows Update history. Include hybrid systems and missing history.
4. Use only a vendor package whose EXE and extracted INF pass signature and hardware checks. Create a restore point, run the interactive installer, restart if required, and confirm DriverGuard's observed INF/version and device status.
5. For cleanup, verify every device using the old INF is absent before confirming. Check the export and deletion result. Separately test active/shared package refusal. Restore the VM snapshot after each disruptive scenario.
6. Record actual results by Windows edition/build. Do not infer Home policy enforcement from a registry readback.
