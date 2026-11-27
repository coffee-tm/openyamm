# devkitA64 toolchain for OpenYAMM Switch homebrew builds.
# Usage:
#   source /opt/devkitpro/devkita64.sh   # sets DEVKITPRO / DEVKITA64
#   cmake -S . -B build-switch \
#     -DCMAKE_TOOLCHAIN_FILE=switch-toolchain/switch.cmake \
#     -DOPENYAMM_HOST_SHADERC=/path/to/host/shaderc
#   cmake --build build-switch --target openyamm_switch_nro
#
# The toolchain turns OPENYAMM_SWITCH on, so the platform configuration in the top-level CMakeLists.txt applies even
# when it is not passed on the command line.

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
if(NOT EXISTS "${DEVKITA64}")
    message(FATAL_ERROR "DEVKITA64 does not exist: ${DEVKITA64}")
endif()

set(OPENYAMM_SWITCH ON CACHE BOOL "Build the Nintendo Switch homebrew target." FORCE)

set(TOOLCHAIN_PREFIX "${DEVKITA64}/bin/aarch64-none-elf-")
set(CMAKE_C_COMPILER   "${TOOLCHAIN_PREFIX}gcc")
set(CMAKE_CXX_COMPILER "${TOOLCHAIN_PREFIX}g++")
set(CMAKE_ASM_COMPILER "${TOOLCHAIN_PREFIX}gcc")
set(CMAKE_AR           "${TOOLCHAIN_PREFIX}gcc-ar")
set(CMAKE_RANLIB       "${TOOLCHAIN_PREFIX}gcc-ranlib")
set(CMAKE_OBJCOPY      "${TOOLCHAIN_PREFIX}objcopy")
set(CMAKE_STRIP        "${TOOLCHAIN_PREFIX}strip")

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

# The ABI flags libnx's own makefiles use. -mtp=soft selects the thread pointer model newlib and libnx expect;
# -fPIE/-pie produce the position-independent NRO the loader maps.
set(OPENYAMM_SWITCH_ARCH_FLAGS "-march=armv8-a+crc+crypto -mtune=cortex-a57 -mtp=soft -fPIE")
set(CMAKE_C_FLAGS_INIT "${OPENYAMM_SWITCH_ARCH_FLAGS}")
set(CMAKE_CXX_FLAGS_INIT "${OPENYAMM_SWITCH_ARCH_FLAGS}")
set(CMAKE_ASM_FLAGS_INIT "${OPENYAMM_SWITCH_ARCH_FLAGS}")

set(OPENYAMM_SWITCH_LINK_FLAGS
    "-specs=${DEVKITPRO}/libnx/switch.specs -pie -Wl,--gc-sections")
set(CMAKE_EXE_LINKER_FLAGS_INIT "${OPENYAMM_SWITCH_LINK_FLAGS}")

add_compile_definitions(OPENYAMM_SWITCH=1 __SWITCH__=1)
add_compile_options(-ffunction-sections -fdata-sections)

# Switch has no host mmap assumptions; probes compile only, they never link a target executable.
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)
