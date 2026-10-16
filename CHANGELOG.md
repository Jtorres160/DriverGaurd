# Changelog

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
