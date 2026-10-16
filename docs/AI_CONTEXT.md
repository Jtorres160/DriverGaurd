# DriverGuard AI context

Last reviewed: 2026-10-15. This is a current-state handoff, not a substitute for source inspection. Follow the workflow in [AGENTS.md](../AGENTS.md) and check recent commits before work.

## Project and source map

DriverGuard is a Windows 10/11 BAT menu and Windows PowerShell 5.1 helper. `DriverGuard.bat` launches the menu; `DriverGuard.ps1` owns policy, recovery, GPU inspection, guided installation, verification, cleanup, and the CLI-only read-only `Diagnose` action. `tests/DriverGuard.Tests.ps1` is a mocked, nondisruptive regression suite. `tests/Windows11.Validation.ps1` has a read-only host mode and a separately gated state-changing `PolicyCycle` mode. See [README.md](../README.md) for behavior, [TESTING.md](../TESTING.md) for coverage and limits, and [WINDOWS11_VALIDATION.md](../WINDOWS11_VALIDATION.md) for native validation steps.

## Current safety model

- Policy operations target only `HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\ExcludeWUDriversInQualityUpdate`. A protected first-observed backup supports exact value restoration and conflict detection. Registry readback establishes configuration, not Windows Update enforcement.
- GPU origin is classified from correlated evidence; absent or ambiguous evidence remains Unknown. Guided installation requires signed vendor EXE and matching signed, applicable Display INF. Cleanup follows verified replacement, checks all-device usage, exports the package, and attempts only targeted, non-forced deletion.
- `Diagnose` is read-only and reports complete (`0`), partial (`2`), or failed (`1`). The BAT menu does not expose it. Do not turn missing evidence into a success claim.

## Verified baseline and open limits

The 2026-10-15 history through `864d2a60937224f6140b96789852297c358c8dfa` contains the implementation and validation harness. During this context setup, the Windows PowerShell read-only harness ran on a Windows 11 host: its mocked suite exited `0` with 61 passes, native Diagnose exited `2` because structured driver-store inventory required elevation, and the harness reported unchanged monitored policy values and DriverGuard state-file hashes. This is a read-only native observation plus mocked regression testing. No state-changing Windows policy cycle, real installer, driver deletion, reboot recovery, or Windows Update enforcement validation was performed during this setup. Earlier claimed results and further untested scenarios are documented in [TESTING.md](../TESTING.md) and [WINDOWS11_VALIDATION.md](../WINDOWS11_VALIDATION.md).

Future agents should update this file only when the durable project state changes. Add dated, evidence-backed entries to [DEVELOPMENT_HISTORY.md](DEVELOPMENT_HISTORY.md) before commits.
