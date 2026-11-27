# devkitA64 toolchain for OpenYAMM Switch homebrew builds.
# Usage:
#   source /opt/devkitpro/devkita64.sh   # sets DEVKITPRO / DEVKITA64
#   cmake -S . -B build-switch \
#     -DCMAKE_TOOLCHAIN_FILE=switch-port/toolchain/switch.cmake \
#     -DOPENYAMM_HOST_SHADERC=/path/to/host/shaderc \
#     -DOPENYAMM_BUILD_TESTS=OFF -DOPENYAMM_BUILD_DESKTOP_EXECUTABLE=OFF
#   cmake --build build-switch

set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR aarch64)
set(CMAKE_SYSTEM_VERSION 1)

if(NOT DEFINED DEVKITPRO)
    set(DEVKITPRO "$ENV{DEVKITPRO}")
endif()
if(NOT DEFINED DEVKITA64)
    set(DEVKITA64 "${DEVKITPRO}/devkitA64")
endif()
if(NOT DEVKITPRO OR NOT EXISTS "${DEVKITPRO}")
    message(FATAL_ERROR "DEVKITPRO is not set. Source /opt/devkitpro/devkita64.sh first.")
endif()

set(TOOLCHAIN_PREFIX "${DEVKITA64}/bin/aarch64-none-elf-")
set(CMAKE_C_COMPILER   "${TOOLCHAIN_PREFIX}gcc")
set(CMAKE_CXX_COMPILER "${TOOLCHAIN_PREFIX}g++")
set(CMAKE_ASM_COMPILER "${TOOLCHAIN_PREFIX}gcc")
set(CMAKE_AR           "${TOOLCHAIN_PREFIX}gcc-ar")
set(CMAKE_RANLIB       "${TOOLCHAIN_PREFIX}gcc-ranlib")
set(CMAKE_OBJCOPY      "${TOOLCHAIN_PREFIX}objcopy")

# libnx lives in the portlibs tree; devkitPro packages install here.
set(DEVKITPRO_PORTLIBS "${DEVKITPRO}/portlibs/switch")

# Only look for headers/libs in the target sysroot, never the host.
set(CMAKE_FIND_ROOT_PATH
    "${DEVKITA64}"
    "${DEVKITPRO_PORTLIBS}"
    "${DEVKITPRO}/libnx")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# Switch has no mmap in libnx; globals/static init must avoid host assumptions.
add_compile_definitions(OPENYAMM_SWITCH=1 __SWITCH__=1)
add_compile_options(-ffunction-sections -fdata-sections)
add_link_options(-Wl,--gc-sections -specs=${DEVKITPRO}/libnx/switch.specs)

set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)
