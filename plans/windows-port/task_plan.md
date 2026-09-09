# Windows port — plan

**Goal:** the plugin builds on Windows with MSVC + CMake, loads in Resolve 20, renders (OpenCL + CPU) and the
overlay is usable. macOS build unaffected. Spec: `specs/01-windows-port.md`.

**Approach:** toolchain first, then a CMake build that compiles the mac-agnostic core, then platform seams one
at a time, then install + verify in Resolve. Never touch the kernels.

## Phases

- [x] **Phase 0 — Toolchain (project-scoped)**
  - [x] `.venv` with cmake + ninja
  - [x] MSVC Build Tools 2022 + VCTools workload installed (approved system-level exception) — cl 19.44, Windows SDK 10.0.26100
  - [x] OpenCL headers + import lib: `OpenCL-Headers` submodule @ v2026.05.29 + `cmake/OpenCL.def` (spec updated)
- [x] **Phase 1 — CMake skeleton** (design v3 locked in spec after Gemini 3.1 Pro + Kimi K3 review)
  - [x] `CMakeLists.txt`: MODULE target, platform-split sources, `OFX_SDK_DIR`, spdlog subdirectory,
        OpenCL import lib, bundle output dirs + `cmake/Info.plist`, install, `regen-headers`, 64-bit guard
  - [x] `CMakePresets.json` (`windows`, `windows-debug`, `macos`) + `build.cmd`
  - [x] gate: configure OK; spdlog + Support sources + `OpenCL.lib` build; `dumpbin /exports` shows the
        two OFX entry points once the `.ofx` links; record `src/` failures as the Phase 2 list
- [ ] **Phase 2 — Platform seams** (one commit each; ordered from the Phase 1 gate output)
  - [ ] `_USE_MATH_DEFINES` on the target (M_PI in `MathUtil.h` + vendored `spline.h`)
  - [ ] `#include <mutex>` in `Parameters.h` (std::recursive_mutex)
  - [ ] `<unistd.h>` in `Reframe360.cpp` and `<OpenGL/gl.h>` in `Reframe360TransformInteract.cpp` → platform-guarded
  - [ ] `src/utils_win.cpp` (`get_microseconds` only); Metal dispatch in `ImageScaler.cpp` guarded
  - [ ] `init_log()` home dir (USERPROFILE fallback)
  - [ ] `WIN32_LEAN_AND_MEAN` redefinition warning (supportext defines it unguarded)
  - [ ] `.gitattributes` `images/*.png.h text eol=lf` (scoped: the two python-written headers are CRLF) + `git add --renormalize images`
  - [ ] whatever the next build surfaces, until the `.ofx` links and `dumpbin /exports` shows both entry points
- [ ] **Phase 3 — Bundle + install**
  - [x] `Contents/Win64/OverlayReframe360.ofx` + `Info.plist` layout (Phase 1)
  - [ ] `/INCREMENTAL:NO` for RelWithDebInfo or exclude `*.ilk` from install()
  - [ ] run `cmake --install` elevated; plugin appears in Resolve
- [ ] **Phase 4 — macOS parity**
  - [ ] CMake produces the universal bundle on mac; Makefile retired
  - [ ] release `.ofx.bundle.zip` target; mac loads with `Info.plist`; venv python on mac; bump cmake_minimum_required to 3.25
- [ ] **Verify:** spec gate 1–5, report which were actually checked.

## Out of scope / deferred

- CUDA render path → not planned (OpenCL covers Windows GPUs in Resolve).
- Porting the overlay to `OfxDrawSuiteV1` → only if Resolve drops V1 interacts.
- XTouchMini MIDI remote → stays disabled on both platforms.
