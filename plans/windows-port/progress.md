# Windows port — progress log

Newest at top. When the task is finished, add `STATUS: complete` on the first line.

## Session 2026-09-09 — OpenCL deps (Phase 0 complete)
- Brainstormed the OpenCL dependency (bounded); cross-checked with Kimi K3 via OpenRouter, which agreed.
- **Decision:** `OpenCL-Headers` submodule @ v2026.05.29 + committed `cmake/OpenCL.def` → import lib via
  `CMAKE_AR` at configure time; `CL_TARGET_OPENCL_VERSION=120` on the target. ICD-loader submodule and
  runtime shim rejected; `/DELAYLOAD` deferred. → `specs/01-windows-port.md` updated.
- Verified with a throwaway exe: def → lib.exe → link → runs against System32 OpenCL.dll.

### Next action
Phase 1: `CMakeLists.txt` skeleton (brainstorm the layout first — it is a design phase).

## Session 2026-09-09 — bootstrap
- Forked yannpom/OverlayReframe360 → hipur/OverlayReframe360; `origin` = fork, `upstream` = yannpom.
- Applied the project workflow scaffold (CLAUDE.md merged with upstream's, `specs/`, `plans/`, `/wrapup`,
  `.remember/`). Validated every workflow section with the user; `/orchestrate-batch` dropped, board steps dropped,
  `/wrapup` auto-commits + pushes after a `/ponytail-review`.
- Created `.venv` with cmake 4.4.3 + ninja 1.13 (project-scoped).
- Started MSVC Build Tools 2022 install via winget (system-level, user-approved exception).
- Wrote `specs/00-overview.md` + `specs/01-windows-port.md` with locked decisions: MSVC, CMake both platforms.
- **Decision:** project-scoped installs everywhere; MSVC is the one approved exception → recorded in CLAUDE.md + spec.

### Errors
| Error | Attempt | Resolution |
|-------|---------|------------|
| `gh repo fork --remote` did not rename existing origin | 1 | renamed manually: origin→upstream, added fork as origin |
