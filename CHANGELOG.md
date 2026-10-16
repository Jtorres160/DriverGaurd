# Changelog

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
