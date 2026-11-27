# Nintendo Switch homebrew port

This branch carries the OpenYAMM Switch homebrew work. It is for research and personal use.
The source now contains the platform skeleton, `.nro` packaging, asset mounting and SDL gamepad
mapping, but no devkitA64 build or console test has been performed in this workspace.

Base commit: `77fa3d8` (upstream `pjasicek/openyamm` main).

## What is included

- `OPENYAMM_SWITCH` CMake option and compile definition.
- Android low-spec settings profile and ESSL 300 shader path on Switch.
- Desktop-only OpenGL/X11/host-icon paths skipped; `EGL`, `GLESv2` (switch-mesa) and `nx` linked.
- Switch dependencies come from devkitPro portlibs (SDL3, PhysicsFS, FreeType, FFmpeg) instead of host source
  builds; ENet is not built because network co-op is disabled.
- SDL initialized with `SDL_INIT_GAMEPAD`, with a graceful fallback if gamepad init fails.
- SDL gamepad input adapted from upstream PR #5 against the current source:
  - `game/app/GamepadInput.h/.cpp`
  - actions, Escape, cursor control and look motion folded into `GameInputSystem`
  - `[gamepad]` settings persisted in `settings.ini`
  - host unit tests in `tests/GamepadInputTests.cpp`
  - Switch face buttons mapped from SDL's positional diamond to the console's A/B and X/Y layout.
- libnx entry point (`game/app/SwitchMain.cpp`).
- SD-card user data directory, default `sdmc:/switch/openyamm`, used for `settings.ini`, saves and logs.
- Assets from either embedded ROMFS (`romfs:/`) or `sdmc:/switch/openyamm/assets`.
- `.nro` packaging with NACP metadata and a 256x256 homebrew icon (`switch/icon.jpg`).
- Desktop-only calls fenced for Switch:
  - `SDL_OpenURL` goes through `Engine::openExternalUrl()` and is a no-op on Switch.
  - video capture through `popen` is unavailable.
  - the Apple-only `execv` launcher path is a no-op in Switch builds.
  - the self-updater and headless updater are unavailable.
  - network co-op entry points return an error instead of opening ENet sockets.
- `switch/validate_switch_build.sh` for a reproducible devkitA64 build check.

## What still needs a real Switch environment

- devkitA64 cross build and `.nro` generation.
- Console smoke test, including ROMFS/SD asset loading and save writing.
- Any platform-specific bgfx/GLES3 issues can only be found on the console.
- Audio output, suspend/resume and docked/handheld resolution switching.

## Prerequisites

Install devkitPro with at least:

- `switch-dev` (devkitA64, libnx, `nacptool`, `elf2nro`)
- `switch-sdl3` (the SDL3 port; package names change, confirm with `(dkp-)pacman -Ss sdl3`)
- `switch-mesa` (EGL + GLES2/3 for the homebrew GLES3 path)
- `switch-physfs`, `switch-freetype`, `switch-ffmpeg`
- `switch-pkg-config` (the `aarch64-none-elf-pkg-config` wrapper)

PhysicsFS matters: upstream 3.2.0 has no Switch platform layer, so the build takes the devkitPro package. The same
applies to SDL3 (upstream has no Switch video backend) and FFmpeg (the bundled `configure` has no Switch target).

Initialize the environment, for example:

```bash
source /opt/devkitpro/devkita64.sh
```

## Build via script

```bash
cd /path/to/openyamm
./switch/validate_switch_build.sh
```

To embed game content in the NRO, stage the exact asset root in a directory and pass it as:

```bash
OPENYAMM_SWITCH_ROMFS_DIR=/absolute/path/to/romfs ./switch/validate_switch_build.sh
```

The script writes to `build-switch-host/` and `build-switch/`, and checks that
`build-switch/OpenYAMM.nro` exists.

## Build manually

First build the host shader compiler. Cross-compiled binaries cannot run on the host:

```bash
cmake -S . -B build-host -DOPENYAMM_BUILD_DESKTOP_EXECUTABLE=OFF
cmake --build build-host --target openyamm_shaderc
```

Then configure the Switch cross build:

```bash
cmake -S . -B build-switch \
  -DCMAKE_TOOLCHAIN_FILE=switch-toolchain/switch.cmake \
  -DOPENYAMM_SWITCH=ON \
  -DOPENYAMM_HOST_SHADERC=$PWD/build-host/openyamm_shaderc \
  -DOPENYAMM_BUILD_TESTS=OFF \
  -DOPENYAMM_BUILD_DESKTOP_EXECUTABLE=OFF
cmake --build build-switch --target openyamm_switch_nro
```

The packaged homebrew executable is:

```text
build-switch/OpenYAMM.nro
```

## Asset layout

Without ROMFS, the entry point uses:

```text
sdmc:/switch/openyamm/assets
```

With `OPENYAMM_SWITCH_ROMFS_DIR` set, the NRO embeds that directory and the entry point uses:

```text
romfs:/
```

Either root must be a usable OpenYAMM asset root: either loose tier directories or `index.json`
plus the pack store. It must also carry the compiled shaders under:

```text
runtime/shaders/essl/
```

The menu renderer reads shader binaries from the filesystem, not through PhysFS, and looks in this order:
`<NRO folder>/runtime/shaders`, `romfs:/runtime/shaders`, `<working directory>/runtime/shaders`, then
`<working directory>/assets/runtime/shaders`. With the default layout the working directory is
`sdmc:/switch/openyamm`, so a ROMFS build finds them at `romfs:/runtime/shaders` and an SD build at
`sdmc:/switch/openyamm/assets/runtime/shaders`.

User data is always written under:

```text
sdmc:/switch/openyamm/
```

## Gamepad configuration

The `[gamepad]` section of `settings.ini` supports:

```ini
[gamepad]
enabled=true
deadzone=0.25
look_sensitivity=1.0
invert_look_y=false
a=trigger
b=combat
x=use
y=cast
rt=attack
lt=jump
start=menu
back=quest
```

The `back=quest` key is kept for compatibility with the current settings schema; it opens the
inventory. `none` unbinds a button.

## Known gaps

- Nothing in this branch has been compiled with devkitA64 or run on a console yet.
- Text entry (save names, character names) depends on SDL's Switch backend opening the system keyboard; untested.
- No rumble or gyro support, and no on-screen button prompts for the pad.
- The co-op menu is still reachable and reports that network play is unavailable instead of hiding its entries.
- Output is a 1280x720 surface; docked 1080p output is not selected.

## Console smoke test

1. Copy `OpenYAMM.nro` to `sdmc:/switch/OpenYAMM.nro`.
2. If not embedding ROMFS, copy the asset root to `sdmc:/switch/openyamm/assets`.
3. Launch the NRO from the Switch homebrew menu.
4. Check `sdmc:/switch/openyamm/openyamm.log` for the asset root and any fatal errors.
5. Confirm the left stick moves, the right stick looks, console A confirms, console B goes back,
   Start opens the menu, and saves are written under `sdmc:/switch/openyamm/saves`.
