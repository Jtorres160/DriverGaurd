# Changelog

## Phase 4 VMware validation record — 2026-10-16

- Recorded live Windows 11 Home build 26300 VMware passes for absent-value Enable/Restore, repeated Enable, enabled-state reboot persistence, real `Prepared` interruption recovery, FreshCycle to a DWORD `0` baseline and targeted archive checks, Enable cancellation, corrected Active conflict refusal, and invalid-text backup detection with Enable refusal and recovery-file replacement from a saved copy.
- Phase 4A/4B remain partial for UAC, other fault paths, and post-Restore reboot. Windows Update enforcement remains unverified; the final registry read/write interval is not atomic. No application code changed in this documentation update.

## Active Restore conflict correction — 2026-10-16

- Fixed Restore so an `Active` record requires the current policy to match DriverGuard's recorded DWORD `1` before confirmation; an external change to the original DWORD `0` now refuses. The post-confirmation policy read is retained and checked before writing.
- Preserved Prepared reconciliation and exact DWORD `0` or absent baseline restoration. Added mocked conflict and no-change regression cases. The corrected DWORD `0` conflict refusal subsequently passed in VMware; other conflict variants remain untested live.

## Fresh recovery cycle — 2026-10-16

- Added explicit menu A / `-Action FreshCycle` for a valid `Restored` record and a disabled current policy. It archives and verifies the old record before capturing a new baseline; normal Enable conflict refusal remains.
- Added regression coverage for DWORD `0` and absent baselines, exact restoration, refusal and cancellation, archive/replacement failures, and interrupted rotation.

## Phase 4A recovery-file correction — 2026-10-16

- Fixed Windows PowerShell 5.1 atomic replacement of an existing recovery file by providing a real rollback path. The prior `Prepared` state is retained if replacement verification fails.
- Added real-filesystem replacement and failure regression coverage. Later VMware tests recovered the actual `Prepared` interruption and completed normal cycles; Phase 4 remains partial for other paths.

## Phase 5B/6B validation and hardening — 2026-10-15

- Restricted SetupAPI correlation to exact device-install sections and active INF, preserved fractional chronology, and refused incidental Windows Update mentions or staged imports as direct installation evidence.
- Reported contradictory same-time install records and explained missing matching evidence in read-only diagnostics.
- Passed 97 mocked checks; native standard-user validation kept the RTX 4080 SUPER provenance `UNKNOWN` and the structured driver-store inventory partial. No system changes occurred.

## Phase 5/6 read-only development — 2026-10-15

- Preserved unknown GPU hardware IDs and conflicting active INF evidence instead of guessing; deduplicated device identities.
- Restricted provenance correlation to the latest exact device/active-INF SetupAPI section, with explicit confirmed, probable, conflict, and unknown outcomes.
- Passed 86 mocked checks and observed one NVIDIA device through independent read-only Windows sources. Native provenance remained unknown; structured driver-store inventory required elevation. Phase 4 live validation remains pending.

## Phase 4 safety validation follow-up — 2026-10-15

- Refused policy writes when the target changes during confirmation or after backup preparation; added mocked recovery coverage for state-file write failures.
- Improved read-only host evidence and policy-cycle result reporting. The 74-check mocked suite passed; native read-only validation remained partial. Live Phase 4A/4B validation is still pending an isolated recoverable test environment and authorization.

## Phase 4 validation preparation — 2026-10-15

- Reconstructed project state and documented a gated Phase 4A policy-cycle and Phase 4B recovery matrix. No application behavior changed.
- Re-ran the safe mocked suite: 61 passed, 0 failed. The read-only Windows 11 harness returned partial (`2`) because structured driver-store inventory required elevation; monitored policy values and DriverGuard state-file hashes were unchanged.
- Live policy modification, reboot recovery, UAC cancellation, conflict/fault injection, GPU operations, and Windows Update enforcement remain unverified. Isolation, snapshot recovery, and explicit approval were not established on the current host.

## Phase 2 diagnostics — 2026-10-15

- Added a CLI-only, read-only `Diagnose` action for native GPU, active INF, driver-store, provenance, policy, backup, and installation-journal observations. The BAT menu is unchanged.
- Reports unavailable evidence sources explicitly and shows raw PnPUtil Display inventory when structured driver-store access needs elevation.
- Added a Windows 11 validation checklist. The mocked suite reports 58 passes; one standard-user native diagnostic pass was completed without policy or driver changes.

## 1.1.1 — 2026-10-15

- Restricted INF hardware matching to Manufacturer-referenced model sections for the running Windows architecture and version; rejected package path links.
- Required the Windows Update marker and update history to correlate with the same SetupAPI install timeframe before confirming origin.
- Added all-device Display inventory for cleanup, including hidden and disconnected devices; unreadable usage refuses deletion.
- Reconciled interrupted Prepared policy backups and protected existing log/state paths before writes.
- Made UAC cancellation and elevated child failures visible as operation failures.
- Expanded mocked Windows PowerShell 5.1 regression checks to 56 passing cases. Live registry, installation, and deletion tests were not run.

## 1.1.0 — 2026-10-15

- Added physical NVIDIA, AMD, and Intel GPU inventory with per-device driver details and staged Display packages.
- Added cautious provenance classification from Windows Update history, SetupAPI records, Device Setup Manager events, and verified DriverGuard installation journal.
- Added guided signed manufacturer installer validation with a matching extracted Display INF and exact hardware ID check.
- Added post-install and post-restart verification before any cleanup review.
- Added optional, targeted export and non-forced deletion of one verified obsolete Display package, with active/shared package refusal.
- Added 44 nondisruptive mocked checks. Live driver installation, reboot, and deletion tests remain unperformed.

## 1.0.0 — initial implementation in this repository

- Added BAT menu, Windows Update driver-exclusion policy control, original-state backup, exact restoration, conflict detection, status, help, and logs.
- Recovery distinguishes an absent value from DWORD 0 and retains the first original state across repeated Enable operations.
- Policy readback confirms registry configuration; real Windows Update exclusion and Windows Home effectiveness remain unverified.
