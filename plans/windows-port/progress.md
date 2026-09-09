# Windows port — progress log

Newest at top. When the task is finished, add `STATUS: complete` on the first line.

## Session 2026-09-09 — bootstrap
- Forked yannpom/OverlayReframe360 → hipur/OverlayReframe360; `origin` = fork, `upstream` = yannpom.
- Applied the project workflow scaffold (CLAUDE.md merged with upstream's, `specs/`, `plans/`, `/wrapup`,
  `.remember/`). Validated every workflow section with the user; `/orchestrate-batch` dropped, board steps dropped,
  `/wrapup` auto-commits + pushes after a `/ponytail-review`.
- Created `.venv` with cmake 4.4.3 + ninja 1.13 (project-scoped).
- Started MSVC Build Tools 2022 install via winget (system-level, user-approved exception).
- Wrote `specs/00-overview.md` + `specs/01-windows-port.md` with locked decisions: MSVC, CMake both platforms.
- **Decision:** project-scoped installs everywhere; MSVC is the one approved exception → recorded in CLAUDE.md + spec.

### Next action
MSVC is installed and verified (cl 19.44, SDK 10.0.26100, opengl32.lib + glu32.lib present, OpenCL.lib NOT in SDK).
Next: resolve the OpenCL headers/ICD question (spec open question 2, project-scoped), then Phase 1 CMake skeleton.

### Errors
| Error | Attempt | Resolution |
|-------|---------|------------|
| `gh repo fork --remote` did not rename existing origin | 1 | renamed manually: origin→upstream, added fork as origin |
