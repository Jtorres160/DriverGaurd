# Git Commit & AI Context Preservation Protocol

This file governs coding agents working in the DriverGuard repository. Keep the durable project snapshot in [docs/AI_CONTEXT.md](docs/AI_CONTEXT.md) and the chronological, evidence-backed record in [docs/DEVELOPMENT_HISTORY.md](docs/DEVELOPMENT_HISTORY.md). Use README.md, TESTING.md, WINDOWS11_VALIDATION.md, and CHANGELOG.md for user-facing behavior and detailed test procedures; do not copy them wholesale into the context files.

## Before development

1. Read this file, `docs/AI_CONTEXT.md`, the relevant product and testing documentation, and the source and tests affected by the task.
2. Inspect working-tree status and relevant recent commits (`git status`, `git log`, and `git show` as needed). Distinguish committed behavior from uncommitted work. Do not overwrite unrelated changes.
3. Identify the safety boundaries and validation level for the change before editing. Treat claims in documents and commit messages as historical evidence, not proof of a new test run.

## Preserve safety boundaries

- Keep policy changes limited to `ExcludeWUDriversInQualityUpdate`; preserve the first observed original state, the difference between absent and DWORD `0`, conflict refusal, secure recovery data, confirmation, and readback.
- Keep GPU provenance evidence-based. Unknown or unavailable evidence must remain explicit; provider names alone do not establish origin.
- Keep installer signature, extracted INF, device and OS applicability checks; post-install verification; and restart gates. Cleanup must refuse active, shared, hidden, disconnected, or unreadable device usage, export the exact package, and use targeted `pnputil /delete-driver oem#.inf` without `/force` or `/uninstall`.
- Keep `Diagnose` read-only, including no DriverGuard log or state writes. Do not silently weaken a refusal or introduce new state-changing automation. Any intentional safety change needs explicit rationale, tests, and documentation.

## Validate and record

1. Run tests appropriate to the changed behavior. The baseline nondisruptive suite is `powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\DriverGuard.Tests.ps1`. For relevant read-only host behavior, use `tests\Windows11.Validation.ps1 -Mode ReadOnly` and report its actual exit code and limitations. State-changing `PolicyCycle`, real driver installation, cleanup, and reboot testing require a suitable isolated or approved machine and their documented gates.
2. Separate mocked results, static inspection, read-only native observations, and state-changing native validation in every report. **Never claim Windows-native validation unless it was actually executed**, and never infer policy enforcement or safe driver removal from registry readback or mocked tests.
3. Before committing, update `docs/DEVELOPMENT_HISTORY.md` with the real change, checks performed, results, and remaining limitations. Update `docs/AI_CONTEXT.md` when the current architecture, safety boundaries, workflow, or known limitations change. Keep entries concise, date them, and link to existing detailed documentation. Never invent earlier milestones or test outcomes.
4. Review the diff and stage only intended files. Create a descriptive Git commit explaining the behavior or documentation change and the validation performed. Do not install a hook that commits or edits repository files without review.
5. After committing, verify the actual full commit hash and working-tree status. Report the real hash, checks and their outcomes, and remaining limitations to the user. Do not claim a commit was made if Git failed.
