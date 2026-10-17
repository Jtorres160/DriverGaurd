# HEAD 714966a read-only native evidence - 2026-10-17

Initial sandbox harness exit: 1; embedded mocked suite: 172 passed, 0 failed, exit 0.
Native output and final comparison:
```text
Running DriverGuard Diagnose
DriverGuard read-only diagnostics (no log or state writes)
Captured UTC: 2026-10-17T22:55:39.3768545Z
Privileges: Standard user
Windows: UNAVAILABLE - Access denied
Policy: EXCLUSION CONFIGURED | key=True | value=True | type=DWord | data=1
Policy enforcement: not established by registry inspection.
Backup: Active | original key=True value=True type=DWord data=0 | DriverGuard target value observed; authorship unverified
Install journal: MISSING
GPU inventory: UNAVAILABLE - Access denied
Driver store structured inventory: UNAVAILABLE - The requested operation requires elevation.

Driver store fallback: raw PnPUtil Display inventory (compare Published Name to active INF; association unverified)
  Microsoft PnP Utility

  Published Name:     oem8.inf
  Original Name:      vm3d.inf
  Provider Name:      Broadcom Inc.
  Class Name:         Display
  Class GUID:         {4d36e968-e325-11ce-bfc1-08002be10318}
  Driver Version:     01/16/2026 9.17.11.3
  Signer Name:        Microsoft Windows Hardware Compatibility Publisher
  Attributes:         Declarative
  WHCP Version:       Unknown

Windows Update history: 21 successful item(s) in latest 1000 records
Failed source: Windows identity unavailable
Failed source: GPU inventory unavailable
Partial source: Structured driver store inventory unavailable
Diagnose result: FAILED (exit 1)
Mocked unit suite exit: 0
Native Diagnose exit: 1 (0 complete, 2 partial, 1 failed)
Policy values and DriverGuard state-file hashes unchanged: True
```

Approved outside-sandbox affected harness rerun exit: 0; embedded mocked suite: 172 passed, 0 failed, exit 0.
The harness intrinsically reruns the mocked suite. No separate extra suite was invoked.
```text
Snapshot comparison self-check: PASS (order independent; changed binary value detected)
AUTOMATED READ-ONLY HOST VALIDATION (unit tests use disposable local fixtures)
Host: Microsoft Windows 11 Home | version=10.0.26300 | build=26300 | administrator=True
Platform: VMware, Inc. VMware20,1 | hypervisorPresent=True
Live policy cycle: NOT TESTED (requires an isolated recoverable machine and explicit authorization).
Running DriverGuard Diagnose
DriverGuard read-only diagnostics (no log or state writes)
Captured UTC: 2026-10-17T22:55:53.0116879Z
Privileges: Administrator
Windows: Microsoft Windows 11 Home | version 10.0.26300 | build 26300
Policy: EXCLUSION CONFIGURED | key=True | value=True | type=DWord | data=1
Policy enforcement: not established by registry inspection.
Backup: Active | original key=True value=True type=DWord data=0 | DriverGuard target value observed; authorship unverified
Install journal: MISSING
GPU inventory: 0 supported PCI Display device(s)
Driver store: 1 third-party Display package(s)
Windows Update history: 21 successful item(s) in latest 1000 records
Diagnose result: COMPLETE (exit 0)
Mocked unit suite exit: 0
Native Diagnose exit: 0 (0 complete, 2 partial, 1 failed)
Policy values and DriverGuard state-file hashes unchanged: True
```

Parser invocation initially failed from nested-shell quote loss, exit 1; repository parsing did not start.
Corrected EncodedCommand invocation: Windows PowerShell 5.1.26100.9711, zero parser errors in DriverGuard.ps1, tests/DriverGuard.Tests.ps1, tests/Windows11.Validation.ps1; exit 0.
No application changes or state-changing native actions. Comparison covers policy key presence/values and four named state files, not every host file or registry setting.
