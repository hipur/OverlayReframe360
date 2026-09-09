# CLAUDE.md

Guidance for AI agents working in this repo. Keep this file high-signal. **Design decisions live
in `specs/`** — update the relevant spec when a decision changes, in the same commit.

## What this is

An OpenFX (OFX) plugin for DaVinci Resolve that reframes 360°/equirectangular video. It is a rewrite of
Reframe360XL: only the GPU kernels were kept; the parameter/keyframe model and the whole UI were rewritten
around the **OFX overlay interaction API** — the user reframes by dragging directly on the viewer image.

Upstream (yannpom/OverlayReframe360) is macOS only. **This fork's job is to port the plugin to Windows**
without breaking the macOS build.

## Status

Windows port — **planning / bootstrapping**. Upstream builds on macOS via the Makefile. Nothing builds on
Windows yet. Machine has Resolve 20 + its OpenFX SDK; MSVC Build Tools and a project venv (CMake, Ninja)
are the toolchain. See `specs/01-windows-port.md` and `plans/windows-port/`.

## Specs / design docs (read the relevant one before working a feature)

**Specs are the source of truth for design.** Code implements them; when a decision changes, the
spec changes in the same commit.

- `specs/00-overview.md` — what exists today (architecture summary, pointers into this file)
- `specs/01-windows-port.md` — the port: toolchain, build system, platform seams, what is out of scope

## Build, install, run

### macOS (upstream, unchanged until CMake lands)

```bash
git submodule update --init          # glm, json, openfx-supportext, spdlog (required, none vendored)

# spdlog MUST be built universal or the final link fails on the x86_64 slice
cd spdlog && mkdir -p build && cd build
cmake .. -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" -DCMAKE_BUILD_TYPE=Release && make -j8
cd ../..

make                                 # = directories + install
make clean                           # rm -rf build/ only; does not touch generated headers
```

`make` compiles a universal (arm64 + x86_64) bundle and copies it to `/Library/OFX/Plugins/OverlayReframe360.ofx.bundle`.
It also emits `build/OverlayReframe360.ofx.bundle.zip` for release. **Resolve must be restarted** to reload the plugin.
Requirements: DaVinci Resolve (its OpenFX SDK at
`/Library/Application Support/Blackmagic Design/DaVinci Resolve/Developer/OpenFX` is an include path, and
`make directories` copies its `Support/Library` into `./Library/`), Xcode CLT, cmake, `xxd`, and `python`
on PATH (the Makefile calls bare `python`, not `python3`).

### Windows (this fork — in progress)

```bash
git submodule update --init
python -m venv .venv && .venv/Scripts/pip install cmake ninja     # project-scoped, already done on this machine

build.cmd                        # sources vcvars64, configures + builds the `windows` preset into out/windows
build.cmd windows-debug          # RelWithDebInfo + REFRAME_DEBUG_LOG=ON (spdlog sinks, ~/reframe.*.log)
.venv\Scripts\cmake --install out\windows    # from an ELEVATED shell: copies the bundle to Program Files
.venv\Scripts\cmake --build --preset windows --target regen-headers   # regenerate committed headers on demand
```

`build.cmd` is the whole Windows build story; the Makefile is macOS only. Phase 1 status: the skeleton
configures and builds spdlog, the Support library and `OpenCL.lib`; four `src/` files still fail on
platform seams (Phase 2, listed in `plans/windows-port/task_plan.md`).

Resolve's OpenFX SDK lives at `C:\ProgramData\Blackmagic Design\DaVinci Resolve\Support\Developer\OpenFX`
(headers in `OpenFX-1.4/include`, C++ wrapper in `Support/include` + `Support/Library`, MSVC sample in
`GainPlugin/`). Plugins install to `C:\Program Files\Common Files\OFX\Plugins\<name>.ofx.bundle\Contents\Win64\`.

There is no test suite and no linter. **Verification means loading the plugin in Resolve** and exercising
the overlay; on Windows, also check the plugin actually appears in the Effects library (a load failure is
silent) and tail the debug log.

### Logging

Build with `-DDEBUG` (`make DEBUG=1` on macOS, the `windows-debug` preset on Windows) to get spdlog sinks: `Reframe360Factory.cpp:init_log()` writes to
`~/reframe.info.log` and `~/reframe.debug.log` (truncated at each load) plus stdout. Without `-DDEBUG`,
logging is compiled out (`spdlog::level::off`). Tailing `~/reframe.debug.log` is the main way to debug a
running plugin. On Windows `~` resolves via `getenv("HOME")`, which is usually unset — see the port spec.

## Generated files

Three sets of headers are generated *and* committed to git. If you edit a source of one, regenerate
(`make` on macOS, the `regen-headers` CMake target on Windows) — do not hand-edit the `.h`. They are
deliberately outside the CMake build graph:

| Generated | From | By |
|---|---|---|
| `src/MetalKernel.h` | `src/MetalKernel.metal` | `metal2string.py` (kernel as a C string, compiled at runtime by `newLibraryWithSource:`) |
| `src/OpenCLKernel.h` | `src/OpenCLKernel.cl` | `HardcodeKernel.py` (same idea, `clCreateProgramWithSource`) |
| `images/*.png.h` | `images/*.png` | `xxd --include` (icons embedded, decoded with lodepng, uploaded as GL textures) |

Neither kernel is precompiled: both are shipped as text and compiled by the driver at first render, so the
`.ofx` bundle has no `.metallib` alongside it.

## Architecture (locked — inherited from upstream)

### State lives in one JSON param, not in OFX params

The single most important design decision. `describeInContext` (`Reframe360Factory.cpp`) declares only two
host-visible params: a `CustomParam` named `json` and a disabled `help` string. There are **no** OFX
double/animated params for pitch/yaw/roll/fov/etc., and no OFX keyframes.

Instead `Params` (`Parameters.h`/`.cpp`) owns the entire animation model and serialises it to that one custom
param via nlohmann/json:

- `ParamsInJson` = `std::map<int /*frame*/, Keyframe> keyframes[6]` + a motion-blur setting.
- The 6 params are fixed and index-addressed everywhere by `ParameterEnum` (pitch, yaw, roll, fov, rectilinear,
  tiny_planet). `PackOfSix<T>` is the union giving both `.all[i]` and `.pitch`-style access; `param_defs[6]`
  in `Parameters.cpp` holds each one's name, colour, ranges and display format. Adding a 7th parameter means
  touching all of these plus the kernels and the overlay layout.
- Each keyframe carries its own `BlendingFunction`, per parameter — that is why interpolation can be linear on
  yaw and quadratic on pitch at the same frame.
- Any mutation calls `computeCache()`, which expands every keyframe track into a dense per-frame
  `ValuesCache` (values + derivatives, frame `t1` to last keyframe, clamped outside), then `save()` →
  `Reframe360::refresh()` → `_json_param->setValue(...)`. Rendering only ever reads the dense cache, never
  interpolates.

Consequences to keep in mind: undo/redo is the host's undo on that one string; `Reframe360::changedParam`
detects a host-side revert (Ctrl+Z) by comparing the host's json against `params.getJson()` and sets `_dirty`
(shown as `DIRTY`/`SYNC` in the overlay's top-right corner). `setSingleInstance(true)` is set, and
`globalMotionBlurRendering` is a process-wide global.

### The overlay is the UI

`Reframe360TransformInteract` (`Reframe360TransformInteract.cpp`, ~1100 lines — the bulk of the UI) is an
`OFX::OverlayInteract` drawing immediate-mode OpenGL over the viewer: sliders for the 6 params, a timeline
strip with keyframe markers, per-keyframe buttons (move / duplicate / cycle blending function / delete),
toggle buttons for curves, motion blur and render mode, and a curve editor.

Flow: `refreshVariables()` recomputes mouse position (through the GL modelview matrix), current time,
`_closest_keyframe_time` (within `CLOSEST_KEYFRAME_DISTANCE_FRAMES`), and resolves the hovered zone into an
`Action`. `penDown` dispatches that `Action` to a `Params` mutation; `penMotion` while dragging maps mouse
deltas onto `Params::changeValueAtTime` for the `EditedParam`. Every `Action` has a hint string in the
`messages[ACTION_MAX]` table — keep that table in sync with the enum, it is indexed positionally.

`WIDTH`/`HEIGHT` are derived from the GL projection matrix rather than the project size, to survive Retina
scaling; `_hidpi` picks the font.

### The overlay must stay registered as a V1 (OpenGL) interact

`Reframe360Factory::describe` overrides the overlay registration by hand, and that
override is load-bearing -- do not "simplify" it away:

```cpp
p_Desc.getPropertySet().propSetPointer(kOfxImageEffectPluginPropOverlayInteractV1, ...);
p_Desc.getPropertySet().propSetPointer(kOfxImageEffectPluginPropOverlayInteractV2, (void*)0, 0);
```

Resolve 20 ships a support library that -- despite the SDK's 2018 README -- has been
updated to OpenFX 1.5 and *unconditionally* registers the overlay as
`kOfxImageEffectPluginPropOverlayInteractV2` (`Library/ofxsImageEffect.cpp`, in
`setOverlayInteractDescriptor`). Under 1.5 a V2 overlay is expected to draw through
`OfxDrawSuiteV1`, so the host hands the interact an OpenGL context with **no drawable**:
`glCheckFramebufferStatus` returns `GL_FRAMEBUFFER_UNDEFINED` (0x8219), the viewport is
0x0, and every draw call fails with `GL_INVALID_FRAMEBUFFER_OPERATION`. The overlay
computes correctly and paints into nothing -- invisible, while pen and key events still
arrive. Hit-testing breaks too, since `WIDTH`/`HEIGHT` and the mouse position come from
`GL_PROJECTION_MATRIX`/`GL_MODELVIEW_MATRIX`, which are identity on a dead context.

Merely rebuilding against a newer Resolve SDK is enough to trigger this with no source
change at all. Forcing V1 back on restores a real FBO and viewport.

Symptom to recognise: `GL error: GL_INVALID_FRAMEBUFFER_OPERATION` on every draw in
`~/reframe.debug.log`. If Blackmagic ever drops V1, the alternative is to port the whole
interact to `OfxDrawSuiteV1` -- which offers lines, polygons, rectangles, ellipses and
text, but no textures, so `images/*.png.h` would have no equivalent.

### Render path

`Reframe360::setupAndProcess` builds, for each motion-blur sample, a 3×3 rotation matrix (`yaw · pitch · roll`,
angles negated except yaw) plus fov/tinyplanet/rectilinear, and hands the flat arrays to `ImageScaler`
(an `OFX::ImageProcessor`). fov is exponential: `0.01 * 10^fov`.

`ImageScaler` has three interchangeable implementations of the same projection maths:
`processImagesMetal()` → `RunMetalKernel` (`MetalKernel.mm`), `processImagesOpenCL()` → `RunOpenCLKernel`
(`OpenCLKernel.cpp`), and `multiThreadProcessImages()` as the CPU fallback using the glm-style helpers in
`MathUtil.h`. **A change to the projection maths must be made in all three**
(`MetalKernel.metal`, `OpenCLKernel.cl`, `ImageScaler.cpp`). On Windows only OpenCL and CPU apply (Metal
is Apple only); a CUDA path is out of scope unless the spec says otherwise.

Motion blur: `mb_samples` is 50 when enabled, and samples are accumulated by averaging in the kernel. The
`bilinear`/samples decision depends on `globalMotionBlurRendering` (auto = enabled above
`MOTION_BLUR_AUTO_PIXELS`). Note the CPU path needs yaw inverted relative to the GPU paths (`invertYaw`).

### Odd corners

- `Parameters.cpp` opens with `#define private public` around the `Parameters.h` include.
- `src/XTouchMini.cpp_` / `.h_` (trailing underscore) are a disabled MIDI-controller remote; the hooks are the
  commented-out `_xtouchmini` / `processMidiQueue` members and `RemoteControlProtocol.hpp` (now an empty
  interface). The Makefile still links CoreMIDI/CoreAudio and adds an rtmidi include path for it.
- `utils.cpp:sendShiftKey()` and `AccessibilityEvent.m:press_button()` poke Resolve from the outside (CGEvent
  and the Accessibility API, walking Resolve's AX tree for a button described "Yann Button") to force a
  re-render. Currently unused — the overlay uses `redrawOverlays()` and param writes instead. These are
  Apple-only and must be excluded (not stubbed) from the Windows build.
- `src/lodepng.*` and `src/spline.h` are vendored third-party single-file libraries; don't reformat them.

## Critical invariants (easy to get wrong)

- **The macOS build must keep working.** Every Windows change is either platform-guarded or in a
  platform-specific file. Never delete Apple-only code to make MSVC happy — exclude it from the target.
- **Do not touch the projection maths** while porting. The kernels are correct; a port is not the moment to
  "clean them up". If a kernel edit is unavoidable, change all three implementations together.
- **The V1 overlay override stays.** See above. Expect the same OpenFX 1.5 support library on Windows.
- **Generated headers are committed.** If a build step regenerates one, the diff must be empty unless the
  source changed.
- **Resolve loads plugins silently.** A DLL that fails to load (missing dependency, wrong arch, bad bundle
  layout) just doesn't appear. Verify the bundle layout and check with a dependency walker before blaming code.

## Conventions

- **Language/stack:** C++11 (upstream; MSVC needs at least `/std:c++14` — see spec), OpenFX 1.4 headers +
  Blackmagic's `Support` C++ wrapper, OpenCL + OpenGL (Windows), Metal (macOS), glm, nlohmann/json, spdlog.
- **Never install or run anything globally.** Every dependency and tool is project-scoped: Python tools in
  `.venv/` (CMake, Ninja live there), portable binaries in `tools/`, C++ deps as submodules. `.venv/` and
  `tools/` are gitignored. The single approved exception is **MSVC Build Tools**, which the user explicitly
  approved as a one-time system install because Resolve's Windows OFX ecosystem is MSVC-based. If anything
  else seems to need a global install, stop and ask.
- **Log generously, redact secrets.** spdlog via the existing `init_log()`; never log tokens or auth headers.
- **Build / test / run:**
  - install: `git submodule update --init` + `.venv` (see Windows section)
  - test: none — verification is loading the plugin in Resolve (restart Resolve to reload)
  - gate: a clean configure + build on the current platform with no new warnings
  - "dev server": Resolve itself; tail `reframe.debug.log` for a `-DDEBUG` build
- **Verifying the plugin.** A green build proves nothing; *see it run*: plugin appears in Resolve's Effects
  library, applies to a 360 clip, the overlay draws, drag reframes, keyframes persist through save/reload.
  Report which of those you actually checked.
- **Commits:** conventional prefixes (`feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`, `build:`).
  Push to `origin` (hipur fork); `upstream` is yannpom's repo — never push there.

## Lazy-dev discipline — ponytail (always on)

The `ponytail` plugin (`ponytail@ponytail`, enabled in `.claude/settings.json`) puts a lazy senior dev
inside every agent working here: **the best code is the code never written.** Its rules are loaded by a
SessionStart hook and re-injected into every subagent, so they apply to implementer dispatches too.

Before writing any code, stop at the first rung that holds:

1. Does this need to be built at all? (YAGNI)
2. Does it already exist in this codebase? Reuse it.
3. Does the standard library do it? Use it.
4. Does a native platform feature cover it? Use it.
5. Does an already-installed dependency solve it? Use it.
6. Can it be one line? Make it one line.
7. Only then: the minimum code that works.

The ladder runs *after* understanding the problem, never instead of it — read the code the change
touches and trace the real flow first. Bug fix = root cause, not symptom (grep every caller, fix the
shared function once). No unrequested abstractions, no new dependency if avoidable, deletion over
addition, fewest files. Mark a deliberate corner-cut with a `ponytail:` comment naming the ceiling and
the upgrade path. **Not lazy about:** understanding the problem, trust-boundary validation, error
handling that prevents data loss, security, and anything explicitly requested. Non-trivial logic leaves
**one runnable check** behind (an assert-based self-check or one small test file; no frameworks).

For this port that means: no "while I'm here" refactors of upstream code, platform seams via `if(WIN32)`
source lists rather than clever abstraction layers, and the Makefile is deleted rather than kept "just in
case" once CMake proves parity.

Commands: `/ponytail [lite|full|ultra|off]` (intensity; default **full**), `/ponytail-review` (delete-list
for the current diff — run it before `/wrapup`), `/ponytail-audit` (whole repo), `/ponytail-debt`
(harvest deferred `ponytail:` shortcuts into a ledger), `/ponytail-help`.

## Working memory & continuity (read this)

Several tools here can hold "memory/plan" state. Give each **one job** — never write the same
thing in two places:

| Layer | Where | Job | Git |
|---|---|---|---|
| **Truth** | `CLAUDE.md` + `specs/` | what we build + how we work; locked decisions | committed |
| **Active work** | `plans/<task>/` (`task_plan.md`, `findings.md`, `progress.md`) | current major step + live progress | committed |
| **Continuity** | `.remember/remember.md` | where we left off, next action, gotchas | gitignored (local) |
| **Durable facts** | user-level memory (`MEMORY.md`) | user prefs, cross-project facts | — |

**Principle:** decisions → `specs/`; progress → `plans/`; quick handoff → `.remember/`. The `remember`
plugin also keeps its own rolling history files in `.remember/` (`now.md`, `today-*.md`, …); those are
its business — `remember.md` is the hand-written handoff.

## Session start routine

1. Read `CLAUDE.md` + the latest `.remember/remember.md` handoff (a SessionStart hook usually
   surfaces these).
2. If a task is active, open its `plans/<task>/progress.md` + `task_plan.md`.
3. **Reconcile with reality:** `git status`, `git log --oneline -5`, current branch — trust the
   repo over the notes.
4. State the next action in one line and confirm before diving in.

## Session end routine — run `/wrapup`

1. Update the active `plans/<task>/progress.md` (done / decisions / blockers) and check off
   `task_plan.md`.
2. If a design decision changed, update the relevant `specs/*.md` in the same change.
3. **`/ponytail-review`** the session diff and act on its delete-list before anything is committed.
4. Write the `.remember/remember.md` handoff (state, single next action, open questions, gotchas)
   — use the `remember` skill.
5. **Tidy git, then publish — no confirmation needed:** gitignore anything that shouldn't be tracked
   (build output, deps, secrets/`.env`, local/editor files); commit the *meaningful* changes with a
   conventional message **and push to `origin`** (skip only if nothing worth recording). Then **rename the
   session to the feature that was implemented** — a short noun-phrase from what actually shipped, not the
   first prompt.

## Workflow agreements

- **Specs are the source of truth.** If a design decision changes, update the spec in the same change.
- **Discuss → spec → implement, per plan phase.** Any phase that involves a design choice (OpenCL
  dependency strategy, CMake layout, install mechanics, a new platform seam) gets a
  `superpowers:brainstorming` pass and a spec update *before* code. Mechanical phases (guard an include,
  rename a path) go straight to plan steps.
- For any multi-step work, use the **planning-with-files** skill and keep its files in `plans/<task>/`.
- **Default execution: subagent-driven development (`superpowers:subagent-driven-development`).**
  Drive implementation by dispatching a fresh implementer subagent per task + a task reviewer on its
  diff — don't hand-code multi-task work inline. Propagate the ponytail rules verbatim into every
  implementer dispatch; keep reviewers un-pre-judged. Mechanical single-file tasks → cheaper model;
  design/integration → a more capable model. Skip the ceremony only for trivial edits.
- **Branch:** work on `master` of the fork (upstream is dormant). No feature branches unless a change is
  experimental enough that you'd want to throw it away.
- **Done means verified in Resolve.** A green build is a prerequisite, not the finish line — run the
  5-point gate in `specs/01-windows-port.md` and report which points were actually checked.
- `.remember/` is session working-memory and is gitignored — don't commit it.
