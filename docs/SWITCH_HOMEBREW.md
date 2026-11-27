# Nintendo Switch homebrew port

This branch carries the OpenYAMM Switch homebrew work. It is for research and personal use.
The source now contains the platform skeleton, `.nro` packaging, asset mounting and SDL gamepad
mapping, but no devkitA64 build or console test has been performed in this workspace.

Base commit: `77fa3d8` (upstream `pjasicek/openyamm` main).

## What is included

- `OPENYAMM_SWITCH` CMake option and compile definition.
- Android low-spec settings profile and ESSL 300 shader path on Switch.
- Desktop-only OpenGL/X11/host-icon paths skipped; `EGL`, `GLESv3` and `nx` linked.
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
- If devkitA64 cannot build ENet, finish link-time removal of the remaining network sources; the runtime
  co-op entry points are already disabled.
- Any platform-specific bgfx/GLES3 issues can only be found on the console.

## Prerequisites

Install devkitPro with at least:

- `switch-dev`
- `switch-sdl-3.4`
- `switch-mesa`
- portlibs used by OpenYAMM (FFmpeg, FreeType, and others)
- `nacptool` and `elf2nro` from `switch-tools` / devkitPro tools

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
plus the pack store. User data is always written under:

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

## Console smoke test

1. Copy `OpenYAMM.nro` to `sdmc:/switch/OpenYAMM.nro`.
2. If not embedding ROMFS, copy the asset root to `sdmc:/switch/openyamm/assets`.
3. Launch the NRO from the Switch homebrew menu.
4. Check `sdmc:/switch/openyamm/openyamm.log` for the asset root and any fatal errors.
5. Confirm the left stick moves, the right stick looks, console A confirms, console B goes back,
   Start opens the menu, and saves are written under `sdmc:/switch/openyamm/saves`.
