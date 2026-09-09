# Windows port — progress log

Newest at top. When the task is finished, add `STATUS: complete` on the first line.

## Session 2026-09-09 — Phase 1 CMake skeleton (complete)
- Design v3 reviewed by Gemini 3.1 Pro + Kimi K3 (both via OpenRouter); each caught real issues, each also
  made one wrong claim that was disproved empirically (HWND interact not needed; MODULE `.ofx` lands in
  LIBRARY dir). Spec updated before code.
- Implemented via subagent-driven development: implementer (opus) → task review → 1 fix round → scoped
  re-review → final whole-branch review (fable). Commits `c779eb6` (OpenCL deps), `e6b2c90` (skeleton),
  `29a3d25` (fix round), + this docs commit.
- **Gate:** configure OK; spdlog, all 8 Support lib + 2 supportext TUs, `OpenCL.lib` build. 4 `src/` TUs
  fail on exactly 3 root causes → Phase 2 list in `task_plan.md`. `.ofx` does not link yet (gate 5 pending).
- **Decision:** generated headers out of the build graph (`regen-headers` target) → spec + CLAUDE.md.
- Review-deferred minors folded into Phases 2–4 of the plan; SDD scratch ledger deleted (git is the record).

### Next action
Phase 2, first seam: `_USE_MATH_DEFINES` on the target (M_PI in `MathUtil.h` + vendored `spline.h`), one
commit; then the next three seams in plan order until the `.ofx` links and `dumpbin /exports` passes.

## Session 2026-09-09 — OpenCL deps (Phase 0 complete)
- Brainstormed the OpenCL dependency (bounded); cross-checked with Kimi K3 via OpenRouter, which agreed.
- **Decision:** `OpenCL-Headers` submodule @ v2026.05.29 + committed `cmake/OpenCL.def` → import lib via
  `CMAKE_AR` at configure time; `CL_TARGET_OPENCL_VERSION=120` on the target. ICD-loader submodule and
  runtime shim rejected; `/DELAYLOAD` deferred. → `specs/01-windows-port.md` updated.
- Verified with a throwaway exe: def → lib.exe → link → runs against System32 OpenCL.dll.

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
