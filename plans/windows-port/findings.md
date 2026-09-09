# Windows port — findings

## Code locations

- `Makefile` — mac-only build; source lists + Support lib file list worth copying into CMake.
- `C:\ProgramData\Blackmagic Design\DaVinci Resolve\Support\Developer\OpenFX` — Resolve 20 SDK on Windows.
  `Support/Library/` has 9 `.cpp` incl. Windows-only `ofxsHWNDInteract.cpp`; `GainPlugin/GainPlugin.vcxproj`
  is the reference MSVC project (defines `WIN32;_WINDOWS;_USRDLL`, links `OpenCL.lib`, bundle at
  `$(OutDir)GainPlugin.ofx.bundle\Contents\Win64\GainPlugin.ofx`).
- `C:\Program Files\Common Files\OFX\Plugins` — install dir; already holds 10 third-party bundles (good
  reference for layout: e.g. `Gyroflow.ofx.bundle`).
- `src/Reframe360Factory.cpp:init_log()` — log path uses `~`.

## Decisions

- MSVC Build Tools (system install, approved) + CMake/Ninja in `.venv` — `specs/01-windows-port.md`.
- CMake for both platforms; Makefile retired once mac parity is proven.

## Dead-ends / gotchas

- Machine had no C++ compiler, no cmake, no VS at all on 2026-09-09; `python` on PATH is 3.10/3.12.
- `gh repo fork --remote --remote-name origin` refuses to rename an existing `origin`.
- Windows SDK 10.0.26100 ships `OpenGL32.Lib` + `GlU32.Lib` but **no `OpenCL.lib`** — needs Khronos `OpenCL-Headers` + `OpenCL-ICD-Loader` (or the SDK) vendored project-scoped.
- `cl.exe` needs `vcvars64.bat`; CMake should be run from a shell that sourced it, or use `-G Ninja` with `CMAKE_C_COMPILER`/`CXX` pointing at the full path.
