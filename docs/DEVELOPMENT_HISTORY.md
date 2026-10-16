# DriverGuard development history

This is a concise chronology grounded in local Git commits and verified checks. See [CHANGELOG.md](../CHANGELOG.md) for release notes and [TESTING.md](../TESTING.md) for test details. Commit hashes below are historical parents of the context-system commit.

## 2026-10-15

- `2fce5dec940fe0c781e6dd7a8345775d9cbd2274` — initial repository commit containing `LICENSE` only. The implementation arrived in the following commit.
- `4b0cfe613f65dce1b6704694ca0f0eca612a4c2d` — added the BAT menu, PowerShell policy and recovery workflow, GPU inspection, guided installation and cleanup, README, changelog, and mocked tests. The commit and documentation describe v1.0 policy behavior and v1.1 GPU workflows; they do not establish live driver behavior.
- `337e598c450ffd1065515a0d5819b2eaea6b50d1` — tightened recovery, INF matching, provenance, cleanup eligibility, and failure reporting. The changelog records 56 mocked passes and no live registry, installation, or deletion tests.
- `ee92d159adeb8220f522b4264983bfa667c7eb20` — added CLI-only read-only native diagnostics and the Windows 11 checklist. The changelog records 58 mocked passes and a standard-user native diagnostics observation.
- `864d2a60937224f6140b96789852297c358c8dfa` — added Diagnose result codes and `tests/Windows11.Validation.ps1`, including read-only snapshot comparison and a gated PolicyCycle mode. The existing testing documents record 61 mocked passes and a partial read-only native run; PolicyCycle was prepared but not run.
- Context-system setup (this entry, before its commit) — added `AGENTS.md`, a short `CLAUDE.md` pointer, and these two docs. Ran `powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Windows11.Validation.ps1 -Mode ReadOnly` on the local Windows host. The mocked suite passed 61/61; native Diagnose exited `2` (partial: structured driver-store inventory required elevation); monitored policy values and DriverGuard state-file hashes were unchanged. No state-changing native test was run. The context-system commit hash is reported after commit, rather than predicted here.
