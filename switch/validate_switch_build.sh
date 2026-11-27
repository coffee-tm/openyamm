#!/usr/bin/env bash
# Reproducible Switch build check for the switch/homebrew branch.
# Source devkita64.sh first, then run this script from anywhere.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST_BUILD_DIR="${OPENYAMM_HOST_BUILD_DIR:-$ROOT/build-switch-host}"
SWITCH_BUILD_DIR="${OPENYAMM_SWITCH_BUILD_DIR:-$ROOT/build-switch}"
HOST_SHADERC="${OPENYAMM_HOST_SHADERC:-$HOST_BUILD_DIR/openyamm_shaderc}"

need() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Missing required tool: $1" >&2
        echo "Source /opt/devkitpro/devkita64.sh before running this script." >&2
        exit 1
    fi
}

if [[ -z "${DEVKITPRO:-}" ]]; then
    echo "DEVKITPRO is not set. Source /opt/devkitpro/devkita64.sh first." >&2
    exit 1
fi

export PATH="$DEVKITPRO/tools/bin:$DEVKITPRO/devkita64/bin:$DEVKITPRO/portlibs/switch/bin:$PATH"

need cmake
need aarch64-none-elf-g++
need aarch64-none-elf-pkg-config
need nacptool
need elf2nro

for module in sdl3 physfs freetype2 libavformat libavcodec; do
    if ! aarch64-none-elf-pkg-config --exists "$module"; then
        echo "Missing Switch portlib pkg-config module: $module" >&2
        echo "Install the devkitPro portlibs listed in docs/SWITCH_HOMEBREW.md." >&2
        exit 1
    fi
done

if [[ ! -f "$ROOT/switch/icon.jpg" ]]; then
    echo "Missing Switch icon: $ROOT/switch/icon.jpg" >&2
    exit 1
fi

romfs_args=()
if [[ -n "${OPENYAMM_SWITCH_ROMFS_DIR:-}" ]]; then
    if [[ ! -d "$OPENYAMM_SWITCH_ROMFS_DIR" ]]; then
        echo "OPENYAMM_SWITCH_ROMFS_DIR is not a directory: $OPENYAMM_SWITCH_ROMFS_DIR" >&2
        exit 1
    fi
    romfs_args+=("-DOPENYAMM_SWITCH_ROMFS_DIR=$OPENYAMM_SWITCH_ROMFS_DIR")
fi

echo "==> Building host shader compiler"
cmake -S "$ROOT" -B "$HOST_BUILD_DIR" \
    -DOPENYAMM_BUILD_DESKTOP_EXECUTABLE=OFF \
    -DOPENYAMM_BUILD_TESTS=OFF
cmake --build "$HOST_BUILD_DIR" --target openyamm_shaderc --parallel

echo "==> Configuring Switch cross build"
cmake -S "$ROOT" -B "$SWITCH_BUILD_DIR" \
    -DCMAKE_TOOLCHAIN_FILE="$ROOT/switch-toolchain/switch.cmake" \
    -DOPENYAMM_SWITCH=ON \
    -DOPENYAMM_HOST_SHADERC="$HOST_SHADERC" \
    -DOPENYAMM_BUILD_TESTS=OFF \
    -DOPENYAMM_BUILD_DESKTOP_EXECUTABLE=OFF \
    "${romfs_args[@]}"

echo "==> Building OpenYAMM.nro"
cmake --build "$SWITCH_BUILD_DIR" --target openyamm_switch_nro --parallel

nro="$SWITCH_BUILD_DIR/OpenYAMM.nro"
if [[ ! -f "$nro" ]]; then
    echo "Build finished but $nro was not produced." >&2
    exit 1
fi

echo "==> Build OK: $nro"
echo "Copy it to sdmc:/switch/OpenYAMM.nro on the console."
