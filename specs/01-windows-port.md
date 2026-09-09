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

### Build system: CMake, both platforms

- One `CMakeLists.txt` at the root replaces the Makefile's logic. Generator: Ninja (from `.venv`).
- Platform split by `if(APPLE)` / `if(WIN32)` on **source lists and link libs**, not on `#ifdef`s sprinkled
  through code. Apple-only files (`*.m`, `*.mm`, Metal) are simply not in the Windows target.
- The Makefile stays until CMake produces a working macOS bundle, then it is deleted (or reduced to
  `cmake --build`). Tracked in `plans/windows-port/`.
- Generated headers (`src/*Kernel.h`, `images/*.png.h`) remain **committed**. CMake gets custom commands to
  regenerate them when sources change, using `.venv` python and `xxd` from Git for Windows. The build must
  not fail if `xxd` is missing — the committed header is the fallback.
- spdlog: build as part of the CMake tree via `add_subdirectory(spdlog)` (static), so the
  "build spdlog universal by hand" step disappears on both platforms.

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
- `/std:c++14` minimum (nlohmann/json requires ≥ C++11 but MSVC's C++11 mode does not exist; glm and spdlog
  are happier at 14+). Keep the code C++11-compatible for the mac side.
- Warnings: `/W3` baseline; do not turn on `/WX` until the port compiles clean.
- Link: `OpenCL.lib`, `opengl32.lib`, `glu32.lib`. No CUDA.
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
- OpenCL headers: use the ones shipped alongside Resolve's SDK if any, else vendor the Khronos headers as a
  submodule (`KhronosGroup/OpenCL-Headers`) and the ICD loader import lib — project-scoped.
- Font rendering: `ofxsOGLTextRenderer` from openfx-supportext is used for text; confirm it compiles on MSVC.
