# OpenYAMM Nintendo Switch 版编译指南

本指南对应 `switch/homebrew` 分支，目标产物是在 Switch 自制系统（Atmosphère + homebrew menu）上运行的
`OpenYAMM.nro`。编译在 PC 上交叉完成，不需要 Switch 参与。

- 分支：`switch/homebrew`（`main` 始终与上游 `pjasicek/openyamm` 同步，不含移植代码）
- 工具链：devkitA64 / libnx
- 渲染：bgfx + switch-mesa（EGL + GLES3），着色器走 ESSL 300，与 Android 后端共用
- CMake 最低版本：**3.22**

> 本分支尚未在真机上完整验证过。编译通过只代表交叉工具链和依赖链接正确，运行期问题见
> [SWITCH_HOMEBREW.md](SWITCH_HOMEBREW.md) 的 Known gaps 一节。

## 1. 安装 devkitPro

### Linux / macOS

```bash
wget https://apt.devkitpro.org/install-devkitpro-pacman
chmod +x install-devkitpro-pacman
sudo ./install-devkitpro-pacman
sudo dkp-pacman -Syu
```

### Windows

用官方安装器装到默认路径 `C:\devkitPro`，然后**从开始菜单打开 "devkitPro MSYS2"**。后续命令都在这个
MSYS2 窗口里执行——不要用 Git Bash 或 PowerShell，工具链路径和 `-specs` 参数在那边解析不了。

### 安装依赖包

```bash
sudo dkp-pacman -S switch-dev switch-sdl3 switch-mesa switch-physfs switch-freetype switch-ffmpeg switch-pkg-config
```

各包作用：

| 包名 | 提供 |
| --- | --- |
| `switch-dev` | devkitA64 编译器、libnx、`nacptool`、`elf2nro` |
| `switch-sdl3` | SDL3 的 Switch 后端（上游 SDL 没有 Switch video driver） |
| `switch-mesa` | EGL + GLESv2/v3，bgfx 的 GLES 渲染后端依赖它 |
| `switch-physfs` | PhysicsFS 的 Switch 平台层（上游 3.2.0 没有） |
| `switch-freetype` | 字体渲染 |
| `switch-ffmpeg` | 视频解码（上游 FFmpeg 的 configure 没有 switch target） |
| `switch-pkg-config` | `aarch64-none-elf-pkg-config` 包装脚本 |

devkitPro 的包名会变。任何一条装不上时，先用 `dkp-pacman -Ss <关键词>` 查实际名称：

```bash
dkp-pacman -Ss sdl3
dkp-pacman -Ss mesa
```

## 2. 激活环境并自检

```bash
source /opt/devkitpro/devkita64.sh
```

逐个确认（缺哪个就补哪个包）：

```bash
echo "$DEVKITPRO"                                  # /opt/devkitpro
which aarch64-none-elf-g++                         # devkitA64 编译器
which nacptool elf2nro                             # 打包工具，在 $DEVKITPRO/tools/bin
aarch64-none-elf-pkg-config --exists sdl3 && echo sdl3-ok
aarch64-none-elf-pkg-config --exists physfs && echo physfs-ok
aarch64-none-elf-pkg-config --exists libavformat && echo ffmpeg-ok
cmake --version                                    # 需 >= 3.22
```

## 3. 一键编译（推荐）

```bash
git clone -b switch/homebrew https://github.com/coffee-tm/openyamm.git
cd openyamm
./switch/validate_switch_build.sh
```

需要把游戏资源打包进 NRO 时，把已整理好的资源根目录传进去：

```bash
OPENYAMM_SWITCH_ROMFS_DIR=/absolute/path/to/romfs ./switch/validate_switch_build.sh
```

脚本会依次做五件事，任何一步失败都会带着明确原因退出：

1. 检查 `DEVKITPRO`、编译器、`nacptool`/`elf2nro`、以及五个 pkg-config 模块是否存在
2. 在 `build-switch-host/` 用**本机**编译器构建 `openyamm_shaderc`（交叉编译产物不能在 PC 上跑，着色器编译器必须是原生程序）
3. 在 `build-switch/` 用 devkitA64 配置交叉编译
4. 编译 ESSL 着色器到 `build-switch/runtime/shaders/essl/`，并把它们拷进 ROMFS 暂存目录（如果指定了）
5. 打包出 `build-switch/OpenYAMM.nro`

首次编译要 FetchContent 拉取 bgfx、imgui、yaml-cpp 等依赖，视网络情况需要十几分钟到半小时。

产物：

```text
build-switch/OpenYAMM.nro
```

## 4. 手动分步编译

需要改选项、增量调试或 CI 集成时用手动流程。脚本做的就是以下四步。

### 4.1 先编译本机着色器编译器

```bash
cmake -S . -B build-host \
  -DOPENYAMM_BUILD_DESKTOP_EXECUTABLE=OFF \
  -DOPENYAMM_BUILD_TESTS=OFF
cmake --build build-host --target openyamm_shaderc --parallel
```

产出 `build-host/openyamm_shaderc`。

### 4.2 配置交叉编译

```bash
cmake -S . -B build-switch \
  -DCMAKE_TOOLCHAIN_FILE="$PWD/switch-toolchain/switch.cmake" \
  -DOPENYAMM_HOST_SHADERC="$PWD/build-host/openyamm_shaderc" \
  -DOPENYAMM_BUILD_TESTS=OFF \
  -DOPENYAMM_BUILD_DESKTOP_EXECUTABLE=OFF
```

`switch-toolchain/switch.cmake` 会自己设 `OPENYAMM_SWITCH=ON`，并带上 libnx 需要的 ABI 参数
（`-march=armv8-a+crc+crypto -mtune=cortex-a57 -mtp=soft -fPIE`、`-specs=.../switch.specs -pie`）。
命令行再传一次 `-DOPENYAMM_SWITCH=ON` 也无害，但没必要。

### 4.3 编译着色器

```bash
cmake --build build-switch --target openyamm_runtime_shaders --parallel
```

**这一步不能省。** 着色器由 `openyamm_runtime_shaders` 生成，它虽然挂在默认构建里，但
`cmake --build build-switch --target openyamm_switch_nro` 只构建该目标及其依赖，**不会**带出着色器。
漏掉的后果是 NRO 能启动、菜单黑屏或直接报着色器加载失败。

### 4.4 打包 NRO

```bash
cmake --build build-switch --target openyamm_switch_nro --parallel
```

若使用 ROMFS，务必先把 `build-switch/runtime/shaders/` 的内容拷到暂存目录的
`runtime/shaders/` 下再执行本步——NRO 的资源是在打包那一刻从暂存目录读进去的，之后再补文件不会生效。

## 5. 资源与着色器布局

游戏从两个位置之一取资源：嵌入 NRO 的 ROMFS，或 SD 卡目录。两条路径都要求资源根满足同一结构：

- 松散的分层目录，或 `index.json` + pack 存储
- **必须**包含着色器：`runtime/shaders/essl/*.bin`（数量以构建实际产出为准，脚本会打印）

| 方式 | 配置 | 运行时资源根 |
| --- | --- | --- |
| ROMFS 内嵌 | `OPENYAMM_SWITCH_ROMFS_DIR=<dir>` | `romfs:/` |
| SD 卡 | 不传该变量 | `sdmc:/switch/openyamm/assets` |

菜单渲染器直接读文件系统（不走 PhysFS），按以下顺序查找着色器，取第一个存在的：

1. `<NRO 所在目录>/runtime/shaders`
2. `<NRO 所在目录>/../runtime/shaders`
3. `romfs:/runtime/shaders`
4. `<工作目录>/runtime/shaders`
5. `<工作目录>/assets/runtime/shaders`

工作目录默认是 `sdmc:/switch/openyamm`，所以 ROMFS 版命中第 3 条，SD 版命中第 5 条。

## 6. 部署到 SD 卡

### ROMFS 版（单文件，推荐给最终用户）

```text
sdmc:/switch/OpenYAMM.nro
```

只需这一个文件。存档、设置和日志仍然写到 `sdmc:/switch/openyamm/`。

### SD 资源版（改资源不用重编）

```text
sdmc:/switch/OpenYAMM.nro
sdmc:/switch/openyamm/assets/
    index.json            或分层资源目录
    runtime/shaders/essl/*.bin
```

### 用户数据（两种方式一致）

```text
sdmc:/switch/openyamm/
    settings.ini
    openyamm.log
    saves/
```

## 7. 常用 CMake 选项

| 选项 | 默认 | 说明 |
| --- | --- | --- |
| `OPENYAMM_SWITCH` | 由工具链置 ON | 启用 Switch 平台分支 |
| `OPENYAMM_SWITCH_ROMFS_DIR` | 空 | 指定后把该目录嵌为 ROMFS |
| `OPENYAMM_SWITCH_ASSET_ROOT` | 空 | 覆盖运行时资源根；空则 ROMFS 用 `romfs:/`、否则用 `<用户数据>/assets` |
| `OPENYAMM_SWITCH_USER_DATA_DIR` | `sdmc:/switch/openyamm` | 设置、存档、日志目录 |
| `OPENYAMM_HOST_SHADERC` | 空 | 交叉编译时必填，指向本机 `openyamm_shaderc` |
| `OPENYAMM_BGFX_DEBUG` | `OFF` | 打开 bgfx 每个 GL 调用的检查，排渲染问题用，慢很多 |
| `OPENYAMM_BUILD_TESTS` | Switch 下强制 `OFF` | 单测只能在本机构建 |
| `OPENYAMM_BUILD_DESKTOP_EXECUTABLE` | Switch 下强制 `OFF` | 桌面可执行文件 |

窗口尺寸固定为 1280×720（Switch 手持模式表面），`OPENYAMM_WINDOW_WIDTH/HEIGHT` 在 Switch 下不生效。

## 8. 常见问题

| 现象 | 原因 | 处理 |
| --- | --- | --- |
| `DEVKITPRO is not set. Source /opt/devkitpro/devkita64.sh first.` | 环境变量没激活 | `source /opt/devkitpro/devkita64.sh` |
| `Missing Switch portlib pkg-config module: sdl3` | 缺少对应 portlib | `sudo dkp-pacman -S switch-sdl3`（照报错里的模块名补） |
| `Missing required tool: elf2nro` | `switch-dev` 未装或 PATH 不全 | `sudo dkp-pacman -S switch-dev`，确认 `$DEVKITPRO/tools/bin` 在 PATH 里 |
| `Set OPENYAMM_HOST_SHADERC to a host bgfx shaderc executable for cross builds.` | 交叉编译时没给本机 shaderc | 先做 4.1，再传 `-DOPENYAMM_HOST_SHADERC=...` |
| `OPENYAMM_HOST_SHADERC does not exist: ...` | 路径写错，或 4.1 没构建成功 | 确认 `build-host/openyamm_shaderc` 真实存在 |
| `DEVKITA64 does not exist: ...` | devkitA64 装在非标准位置 | 显式传 `-DDEVKITPRO=<路径>` |
| NRO 能启动但菜单黑屏 / 提示着色器加载失败 | 没编译或没部署 ESSL 着色器 | 执行 4.3；SD 版把 `runtime/shaders` 拷到资源根 |
| 启动即退出，日志提示资源根不可用 | 资源根缺失或结构不对 | 看 `sdmc:/switch/openyamm/openyamm.log` 里的 asset root 行 |
| 声明了 `romfs:/` 但 NRO 没嵌 ROMFS | 打包时没传 `--romfsdir` | 重新用 `OPENYAMM_SWITCH_ROMFS_DIR=...` 编译 |
| 链接报 `undefined reference to PHYSFS_*` / SDL 符号 | 用了源码构建的依赖而非 portlib | 清理 build 目录重新 configure |

排查运行期问题先看 `sdmc:/switch/openyamm/openyamm.log`。排渲染问题可以加
`-DOPENYAMM_BGFX_DEBUG=ON` 重编。

## 9. 已知限制

功能层面的缺口（文本输入、震动/陀螺仪、联机菜单、docked 1080p）以及真机冒烟测试清单，见
[SWITCH_HOMEBREW.md](SWITCH_HOMEBREW.md)。
