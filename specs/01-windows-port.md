# 01 — Windows port

**Status: decisions below are locked; open questions are listed at the end.** Milestone M1/M2 in
`00-overview.md`.

## Goal

The plugin builds on Windows from this repo, installs into Resolve's OFX folder, loads, renders via OpenCL
(CPU fallback), and the overlay is fully usable. The macOS build keeps working from the same tree.

## Locked decisions

### Toolchain: MSVC Build Tools 2022 (x64)

- **Why:** Resolve's Windows OFX SDK, its `GainPlugin` sample, and every shipping Windows OFX plugin are
  MSVC-built. The Support library (`ofxsHWNDInteract.cpp` etc.) assumes the Windows SDK. OpenCL/OpenGL import
  libs come from the Windows SDK and the OpenCL SDK used by Blackmagic.
- **Project-scoping rule and its one exception:** the user's standing rule is *every* install is project-scoped.
  MSVC Build Tools is the single, explicitly approved system-level exception (approved 2026-09-09). Everything
  else stays project-local: CMake + Ninja are pip-installed into `.venv/`; any other binary goes into `tools/`
  (gitignored).
- Installed via `winget install Microsoft.VisualStudio.2022.BuildTools` with the `VCTools` workload.

### Build system: CMake, both platforms — layout locked 2026-09-09 (reviewed by Gemini 3.1 Pro + Kimi K3)

- One root `CMakeLists.txt`, `cmake_minimum_required(3.21)`, `CMAKE_CXX_STANDARD 14` for both platforms
  (code stays C++11-compatible). Generator: Ninja from `.venv`. A `FATAL_ERROR` guard if the pointer size
  is not 8 bytes, so a stray 32-bit vcvars fails at configure with a readable message.
- **One target:** `add_library(OverlayReframe360 MODULE ...)`, `PREFIX ""`, `SUFFIX ".ofx"`,
  `CXX_VISIBILITY_PRESET hidden`, `VISIBILITY_INLINES_HIDDEN ON`. No separate static lib for the Support
  sources (single consumer — rejected as unneeded).
- **Sources split by platform on the source list, not by `#ifdef`s:** common = `src/*.cpp` minus
  `utils.cpp`, plus the eight `Support/Library/*.cpp` the Makefile lists (compiled directly from
  `OFX_SDK_DIR`, no copy into `./Library`), plus `ofxsOGLTextRenderer.cpp` + `ofxsOGLFontData.cpp` from
  openfx-supportext. `APPLE` adds `utils.cpp`, `AccessibilityEvent.m`, `MetalKernel.mm`. `WIN32` adds
  `src/utils_win.cpp` (Phase 2). `ofxsHWNDInteract.cpp` is **not** compiled: verified nothing in the
  Support library references it; it only serves the HWND custom-param-UI feature, not overlay interacts.
- `OFX_SDK_DIR` cache variable with the per-platform Resolve default path.
- **Output layout with no post-build copies, same mechanism on both platforms:**
  `LIBRARY_OUTPUT_DIRECTORY` = `<build>/OverlayReframe360.ofx.bundle/Contents/Win64/` (or `MacOS/`);
  `ARCHIVE_OUTPUT_DIRECTORY` redirected out of the bundle (MSVC drops an import `.lib`/`.exp` there);
  a static `cmake/Info.plist` is copied to `Contents/`. Verified with a spike: a MODULE target's `.ofx`
  lands in the LIBRARY dir on MSVC, not RUNTIME. CMake's `BUNDLE` property is not used (it cannot name the
  inner binary `.ofx`, and one mechanism beats two).
- `install(DIRECTORY <bundle> DESTINATION ${OFX_PLUGIN_DIR})`, per-platform default. On Windows
  `cmake --install` needs an elevated shell and simply fails otherwise — documented, not worked around.
- spdlog via `add_subdirectory(spdlog)` static, examples/tests off, linked as `spdlog::spdlog`. glm and
  nlohmann/json as include directories. MSVC runtime stays at the default `/MD` everywhere.
- **Generated headers are out of the build graph.** They stay committed; a `regen-headers` custom target
  (not in `ALL`) runs `metal2string.py`, `HardcodeKernel.py` (venv python) and `xxd --include` on demand.
  Replaces the Makefile's auto-regeneration; CLAUDE.md's "run make to regenerate" becomes "build the
  `regen-headers` target".
- `option(REFRAME_DEBUG_LOG OFF)` → compile definition `DEBUG` (replaces `make DEBUG=1`).
- `CMakePresets.json`: `windows` (Ninja, Release, `CMAKE_MAKE_PROGRAM` from `.venv`, compiler pinned to
  `cl` so a configure without vcvars cannot poison the cache) and `macos` (universal arches). `build.cmd`
  at the root sources `vcvars64.bat` then runs configure + build with the venv CMake.
- The Makefile stays until CMake produces a working macOS bundle (Phase 4), then it is deleted.
- **Phase 1 done =** configure succeeds on Windows; spdlog, the Support sources and `OpenCL.lib` build;
  `dumpbin /exports` on the linked `.ofx` (once it links) shows `OfxGetNumberOfPlugins` + `OfxGetPlugin`
  (the SDK's `OfxExport` is `__declspec(dllexport)` under `WIN32`). `src/` compile failures are expected
  and become the ordered Phase 2 seam list.

### OpenCL dependency (Windows) — locked 2026-09-09

Resolve's SDK ships no OpenCL headers or import library, and the Windows SDK has none either. The plugin
needs exactly two things: `<CL/cl.h>` at compile time and an import library at link time. The DLL itself
is `C:\Windows\System32\OpenCL.dll` (the Khronos ICD loader installed by GPU drivers), which Resolve's
process already has loaded.

- **Headers:** `OpenCL-Headers/` submodule (KhronosGroup/OpenCL-Headers), pinned to release tag
  `v2026.05.29`. Header-only. Bump by checking out a newer tag, never `main`.
- **Import lib:** `cmake/OpenCL.def` lists the 11 entry points `src/OpenCLKernel.cpp` calls. CMake runs
  `${CMAKE_AR} /def:cmake/OpenCL.def /machine:x64 /out:<build>/OpenCL.lib` as a custom command at
  configure time (`CMAKE_AR` is lib.exe under MSVC, absolute path, so it works without vcvars on PATH).
  x64 exports are undecorated, so bare names suffice. Verified: lib.exe accepts the def, a test program
  links and runs against the system DLL.
- **Version pin:** `target_compile_definitions(... PRIVATE CL_TARGET_OPENCL_VERSION=120)`. Without it
  the headers default to 3.0 and hide 1.2-era prototypes. No source edit needed.
- **Rejected:** building the Khronos ICD loader as a submodule (compiles a loader we never run, only to
  get the same import lib); a runtime `LoadLibrary`/`GetProcAddress` shim (dispatch code to save a
  12-line def file).
- **Deferred upgrade path:** `/DELAYLOAD:OpenCL.dll` would make a missing DLL degrade to the CPU path
  instead of a load failure. Not needed — Resolve itself requires OpenCL or CUDA — one linker flag if
  it ever is.

### Bundle layout and install (Windows)

```
OverlayReframe360.ofx.bundle/
  Contents/
    Info.plist            # same as macOS
    Win64/
      OverlayReframe360.ofx     # the DLL, renamed
```

Install target copies the bundle to `C:\Program Files\Common Files\OFX\Plugins\`. That folder is normally
admin-only; the install step should detect a permission failure and say so rather than silently doing
nothing. Resolve must be restarted to pick the plugin up.

### Compiler settings (Windows)

- Defines from Blackmagic's sample: `WIN32;_WINDOWS;_USRDLL;NOMINMAX;WIN32_LEAN_AND_MEAN`.
- C++14 via `CMAKE_CXX_STANDARD` on both platforms (MSVC has no C++11 mode). Keep the code
  C++11-compatible.
- Warnings: `/W3` baseline; do not turn on `/WX` until the port compiles clean.
- Link: generated `OpenCL.lib` (see above), `opengl32.lib`, `glu32.lib`. No CUDA.
- Exports: the OFX entry points `OfxGetNumberOfPlugins` / `OfxGetPlugin` are exported by the Support library
  with `__declspec(dllexport)` under `WINDOWS` — verify the define name the shipped Support lib uses.

### Code seams (what changes, what does not)

| File | Change |
|---|---|
| `src/Reframe360Factory.cpp` `init_log()` | home dir via `getenv("USERPROFILE")` fallback on Windows |
| `src/utils.{h,cpp}` | `sendShiftKey` under `#ifdef __APPLE__` (unused anyway) |
| `src/Reframe360TransformInteract.cpp` | GL header include; any `<OpenGL/...>` → platform include |
| `src/ImageScaler.cpp` | Metal dispatch under `#ifdef __APPLE__`; OpenCL path unchanged |
| `src/OpenCLKernel.cpp` | `<OpenCL/opencl.h>` → `<CL/cl.h>` on Windows; check for `cl_khr` GL-sharing use |
| `src/global.h`, `define_utils.h` | anything `__attribute__`-flavoured gets an MSVC equivalent |
| kernels, `Parameters.*`, `MathUtil.h`, `spline.h`, `lodepng.*` | **untouched** |

### Verification gate

1. `cmake --build` clean on Windows, zero errors.
2. Bundle appears in Resolve 20 Effects library (Open FX → Filter).
3. Applied to a 360 clip: image reframes (OpenCL), and with GPU processing disabled (CPU path).
4. Overlay draws, mouse hit-testing works at 100% and at a HiDPI scale, keyframes persist through project
   save/reload.
5. `reframe.debug.log` (DEBUG build) shows no `GL_INVALID_FRAMEBUFFER_OPERATION` spam.

## Open questions

- Does Resolve 20 on Windows honour the same V1 overlay override, or does the Windows Support library differ?
  (Diff `Support/Library/ofxsImageEffect.cpp` mac vs Windows once both are on disk.)
- Font rendering: `ofxsOGLTextRenderer` from openfx-supportext is used for text; confirm it compiles on MSVC.
