# 00 — Overview

**Status: locked (inherited from upstream).** This spec records what the plugin *is* so the port spec can
talk about seams. The detailed architecture write-up lives in `CLAUDE.md` → "Architecture"; this file does
not duplicate it, it points at it.

## Product

OverlayReframe360 is a DaVinci Resolve OpenFX plugin that reframes 360°/equirectangular footage. All
interaction happens in an OpenGL overlay drawn on the viewer (`Reframe360TransformInteract`). Animation
state is one JSON custom param owned by `Params`. Rendering is a projection kernel with three
implementations: Metal (macOS), OpenCL (both), CPU fallback (both).

## Milestones

| # | Milestone | State |
|---|---|---|
| M0 | macOS build via Makefile (upstream) | done |
| M1 | **Windows build that loads in Resolve 20 and renders (OpenCL + CPU)** | planned — `01-windows-port.md` |
| M2 | Overlay fully working on Windows (draw, hit-test, keyframes, curves) | planned |
| M3 | Release packaging for both platforms from one CMake build | planned |

## Platform seams (where macOS-only code lives today)

| Area | Files | Windows plan |
|---|---|---|
| Metal render path | `src/MetalKernel.{mm,metal,h}` | excluded from target |
| AX / CGEvent pokes (unused) | `src/AccessibilityEvent.{h,m}`, `src/utils.cpp:sendShiftKey` | excluded / guarded |
| MIDI remote (disabled) | `src/XTouchMini.*_`, CoreMIDI link flags | dropped from link |
| Build | `Makefile` (clang, `-bundle`, frameworks) | CMake, both platforms |
| Log path | `init_log()` uses `~` | Windows-safe home dir |
| OpenGL headers | `<OpenGL/gl.h>` | `<GL/gl.h>` + `windows.h`; Support lib handles most |

## Non-goals (for the port)

- No changes to projection maths or keyframe model.
- No CUDA path. OpenCL is Resolve's cross-vendor GPU path on Windows and the kernel already exists.
- No move off the V1 (OpenGL) overlay interact.
