# Validation matrix

## Phase 4B unsafe Active backup ACL — October 16, 2026

**PASS for the tested native VMware file-specific unsafe-write ACL refusal.** Read-only inspection of exported evidence at tested HEAD `83f2543232c7da4f0fbe96dd8bf77d7f66565224` confirms Restore exit `1`, refusal naming the primary recovery file, identical five registry exports (DWORD `1`), identical 200-byte recovery captures/hash (Active, original DWORD `0`), restored original file descriptor, and unchanged directory descriptor. The injected Builtin Users write ACE remained through the refused Restore. Result, cleanup, and termination artifacts report success and confirmed child termination without critical manual intervention. Stderr contains only its BOM; stdout also reports activity-log refusal at the unsafe file.

Final evidence agrees with tester-reported `EXCLUSION CONFIGURED`, `VALID (Active)`, DWORD `1`, and the live recovery hash. There are 36 exported files versus reported 35; original/export equality remains tester-reported. Snapshot restorability is not independently guest-verified. Capture time is October 17 UTC / October 16 Pacific. See [detailed evidence verification](../TESTING.md) for hash and comparison details. No completed live test was repeated. Phase 4A/4B remain **PARTIAL** and Windows Update enforcement **UNVERIFIED**; other malformed/ACL variants remain open.

## Phase 4B malformed Active record — October 16, 2026

| Case | Live VMware evidence | Status and limit |
|---|---|---|
| Active/DWORD `1`; primary record replaced with `INVALID_TEST_RECORD` | Restore refused “Recovery backup is malformed.” before confirmation; Status showed `CORRUPT` and external change `Unknown`. Returning the saved Active file restored valid Status, and normal Restore independently verified DWORD `0`/`Restored` | PASS for this invalid-text refusal and recovery workflow on Windows 11 Home build 26300. Other malformed-record variants remain untested live; the later file-specific unsafe-ACL refusal above passed |

Phase 4 remains **PARTIAL** and Windows Update enforcement **UNVERIFIED**. Remaining safety checks are in [WINDOWS11_VALIDATION.md](../WINDOWS11_VALIDATION.md).

## Phase 4B missing recovery file — October 16, 2026

| Case | Live VMware evidence | Status and limit |
|---|---|---|
| Active/DWORD `1` with primary recovery file renamed | `-Action Restore` refused “No recovery backup exists. Original configuration cannot be inferred.” before confirmation; returning the saved file restored valid `Active` Status, then normal Restore independently verified DWORD `0` and ended `VALID (Restored)` | PASS for missing-file refusal and recovery workflow on Windows 11 Home build 26300; later `INVALID_TEST_RECORD` Restore also passed. Other malformed variants remain untested live; the later file-specific unsafe-ACL refusal above passed. No file hashes or exit codes supplied |

Windows Update enforcement remains **UNVERIFIED**. Other Phase 4 safety checks are in [WINDOWS11_VALIDATION.md](../WINDOWS11_VALIDATION.md).

## Phase 4 UAC and post-Restore reboot — October 16, 2026

| Case | Live VMware observation | Status and limit |
|---|---|---|
| Standard-user UAC decline | Status afterward: DWORD `0`, `VALID (Restored)` | PASS for observed no-change state; no independent file hashes, logs, or exit code supplied |
| UAC approval, then `NO` at Enable | Elevated PowerShell launched; Status afterward: DWORD `0`, `VALID (Restored)` | PASS for observed cancellation; no independent file hashes, logs, or exit code supplied |
| Reboot after Restore | Status after restart: DWORD `0`, `VALID (Restored)`, `External change: No` | PASS for observed persistence; no independent post-reboot registry/file hash supplied |

Remaining Phase 4 release-blocking and optional checks are listed in [WINDOWS11_VALIDATION.md](../WINDOWS11_VALIDATION.md). Windows Update enforcement is **UNVERIFIED**.

## Restore policy conflict case — October 16, 2026

| Case | Evidence | Result | Remaining validation |
|---|---|---|---|
| Active record; external DWORD `1` to original DWORD `0` | Real Windows 11 Home build 26300 VMware: Enable wrote `1`, recovery was valid `Active`, Status flagged the manual DWORD `0` change | Old Restore prompted and tester answered `NO`; after commit `b75aa77`, corrected Restore refused before confirmation, leaving DWORD `0` and `Active`. Manual return to `1` allowed normal Restore to DWORD `0`/`Restored` | PASS for this conflict; removed/unsupported values and final read/write race NOT TESTED live. No byte-for-byte recovery-file hash supplied |
| Normal cycles, FreshCycle, reboot, Prepared recovery, and damaged file | User-reported VMware runs with snapshots; separate local 141/141 PowerShell 5.1 regression checks | PASS for absent and DWORD `0` target restoration, enabled-state and post-Restore reboot observations, UAC and Enable cancellation, real after-write `Prepared` recovery, targeted archive checks, and invalid-text backup detection/Enable refusal | PARTIAL for other interruption/fault and damaged-backup variants; registry readback does not verify Windows Update enforcement |

The VMware discovery is a policy workflow observation and does not add a GPU provenance ground-truth case to the matrix below.

## Phase 5/6 GPU provenance

Updated October 15, 2026. The counts below refer to **one physical GPU**, not independent installations: one real device with verified current identity, zero real installations with independently known origin, one real installation observed without an origin label, and 97 passing mocked assertions. The assertions are neither 97 physical devices nor an accuracy sample.

| Evidence class | Windows version/build | GPU vendor/model | Active INF / driver version | Installation source ground truth | Available evidence | DriverGuard result / expected result | Status and limits |
|---|---|---|---|---|---|---|---|
| Real verified current identity | Windows 11 IoT Enterprise LTSC / 26100 | NVIDIA GeForce RTX 4080 SUPER | `oem23.inf` / `32.0.16.1742` | Unknown | PnP device and properties, signed-driver CIM, video-controller CIM, PnPUtil device and staged-package listings | One healthy NVIDIA GPU with active `oem23.inf`; agrees with current device and driver-store metadata | Verified on this host only. The APIs largely expose the same Windows PnP/driver metadata, so agreement is cross-interface consistency, not independent proof of installer or broad hardware compatibility. |
| Real observed, origin unlabeled (same GPU) | Windows 11 IoT Enterprise LTSC / 26100 | NVIDIA GeForce RTX 4080 SUPER | `oem23.inf` / `32.0.16.1742` | **Unavailable**; no independently documented install mechanism/date | Readable SetupAPI device log with no target device/INF/model, five unrelated successful Windows Update history items, two noncausal Device Setup events, no DriverGuard journal | `UNKNOWN` / `UNKNOWN` given available evidence | Observed, not a provenance accuracy validation. Available log starts October 15 at 18:04 local time; why the installation record is absent is not established. |
| Synthetic regression fixtures | Mock Windows/device data; no physical build | NVIDIA, AMD, Intel and edge cases | Mock INF/version values | Fixture-defined only | Mock PnP/CIM properties, SetupAPI sections, update history, journal, driver-store failures | 97/97 assertions pass, including identity, provenance, reporting, and unrelated safety checks | Synthetic behavior validation only; no measured real-world accuracy. See `tests/DriverGuard.Tests.ps1`. |

## Coverage needed before broader claims

| Hardware / installation case | Required test environment and evidence | Current status |
|---|---|---|
| Additional NVIDIA, AMD, and Intel devices | Actual hardware on supported Windows 10/11 builds; compare exact PnP instance, active INF, version, provider, PnPUtil device binding, and driver-store package | Unverified beyond the one RTX 4080 SUPER |
| Multi-GPU or hybrid graphics | Physical system with two active display adapters, ideally different vendors; verify per-instance INF and no cross-device package association | Synthetic only |
| Disabled, disconnected, hidden, and non-present devices | Physical systems with known device state and readable all-device inventory; verify whether each should be displayed or excluded from active inspection and whether cleanup refuses uncertain usage | No physical case on this host; cleanup behavior mocked |
| Known Windows Update installation | Authorized recoverable test environment with install method recorded outside DriverGuard; retain exact device instance, active INF/version, dated SetupAPI Device Install section with explicit WU mechanism, and matching WU history item | Zero labeled real cases |
| Known manufacturer installation | Authorized recoverable test environment with vendor installer execution record outside DriverGuard; retain exact device, pre/post INF/version, installer identity/time, SetupAPI record, and WU history near the event | Zero labeled real cases; current classifier can report probable, not confirmed, manufacturer origin |

For each future labeled installation, capture the independent source record *before* running DriverGuard, then compare the classification with that label. Preserve the installation event context and exact device/INF/version correlation outside Git. Do not commit full device instance IDs, raw logs, or installer artifacts. If logs are absent, rotated, localized, or inaccessible, keep the case unlabeled or mark the source unavailable. Run installation scenarios only after the separate Phase 4 recovery and authorization gates are satisfied.
