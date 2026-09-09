# Windows port — plan

**Goal:** the plugin builds on Windows with MSVC + CMake, loads in Resolve 20, renders (OpenCL + CPU) and the
overlay is usable. macOS build unaffected. Spec: `specs/01-windows-port.md`.

**Approach:** toolchain first, then a CMake build that compiles the mac-agnostic core, then platform seams one
at a time, then install + verify in Resolve. Never touch the kernels.

## Phases

- [ ] **Phase 0 — Toolchain (project-scoped)**
  - [x] `.venv` with cmake + ninja
  - [x] MSVC Build Tools 2022 + VCTools workload installed (approved system-level exception) — cl 19.44, Windows SDK 10.0.26100
  - [ ] OpenCL headers + import lib located or vendored (project-scoped)
- [ ] **Phase 1 — CMake skeleton**
  - [ ] `CMakeLists.txt` building the Support library + openfx-supportext + `src/*.cpp` on Windows
  - [ ] spdlog via `add_subdirectory`
  - [ ] custom commands for generated headers (no-op when up to date)
- [ ] **Phase 2 — Platform seams** (one commit each, see spec table)
  - [ ] GL / CL includes
  - [ ] `init_log()` home dir
  - [ ] guard Apple-only code (`utils.cpp`, `ImageScaler.cpp` Metal dispatch)
  - [ ] MSVC-isms (`__attribute__`, `#define private public`, etc.)
- [ ] **Phase 3 — Bundle + install**
  - [ ] `Contents/Win64/OverlayReframe360.ofx` + `Info.plist`
  - [ ] install target to `C:\Program Files\Common Files\OFX\Plugins`
- [ ] **Phase 4 — macOS parity**
  - [ ] CMake produces the universal bundle on mac; Makefile retired
- [ ] **Verify:** spec gate 1–5, report which were actually checked.

## Out of scope / deferred

- CUDA render path → not planned (OpenCL covers Windows GPUs in Resolve).
- Porting the overlay to `OfxDrawSuiteV1` → only if Resolve drops V1 interacts.
- XTouchMini MIDI remote → stays disabled on both platforms.
