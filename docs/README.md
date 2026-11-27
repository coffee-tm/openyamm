# OpenYAMM 文档

本仓库的 `docs/` 目录。**当前分支是 `switch/homebrew`**：内容为上游 OpenYAMM 加上 Nintendo Switch 自制
系统（homebrew）移植，仅供研究与个人使用，不对应任何官方发行版。

`main` 分支保持与上游 [pjasicek/openyamm](https://github.com/pjasicek/openyamm) 同步，不含移植代码。

## 我该看哪一份

| 你的目标 | 看这份 |
| --- | --- |
| 我要把游戏编成 Switch 的 `.nro` | [BUILD_SWITCH.zh-CN.md](BUILD_SWITCH.zh-CN.md) |
| 我想知道移植了什么、还差什么、怎么测 | [SWITCH_HOMEBREW.md](SWITCH_HOMEBREW.md) |
| 我要打 Windows 桌面版发行包 | [windows_distribution_build.md](windows_distribution_build.md) |
| 我只想在 PC 上玩 | 不用看 `docs/`，直接看仓库根目录的 [README](../README.md) |

## 最快上手

前提：已装 devkitPro 与依赖包（装法见 [BUILD_SWITCH.zh-CN.md](BUILD_SWITCH.zh-CN.md) 第 1 节）。

```bash
# 1. 取代码
git clone -b switch/homebrew https://github.com/coffee-tm/openyamm.git
cd openyamm

# 2. 激活工具链（每个新终端都要做一次）
source /opt/devkitpro/devkita64.sh

# 3. 编译
./switch/validate_switch_build.sh
```

成功后得到：

```text
build-switch/OpenYAMM.nro
```

拷到 SD 卡的 `sdmc:/switch/OpenYAMM.nro` 即可在 homebrew menu 里启动。

想把游戏资源直接嵌进 NRO（单文件分发）：

```bash
OPENYAMM_SWITCH_ROMFS_DIR=/absolute/path/to/romfs ./switch/validate_switch_build.sh
```

首次编译要拉 bgfx、imgui 等依赖，十几分钟到半小时属正常。

## 三份文档各自讲什么

### [BUILD_SWITCH.zh-CN.md](BUILD_SWITCH.zh-CN.md) — 编译指南

从零到 `.nro` 的完整流程。含 devkitPro 包表、环境自检命令、一键脚本与手动分步两条路径、资源与着色器
布局、SD 卡部署目录树、CMake 选项表、10 条故障排查。**要编译就看这份。**

### [SWITCH_HOMEBREW.md](SWITCH_HOMEBREW.md) — 移植说明（英文）

移植范围清单：改了哪些平台分支、依赖为什么必须用 devkitPro 的 portlib 而不是源码构建、手柄映射与
`settings.ini` 的 `[gamepad]` 段、已知功能缺口（Known gaps）、真机冒烟测试清单。**要评估移植完成度就看这份。**

### [windows_distribution_build.md](windows_distribution_build.md) — Windows 发行包

上游文档，讲怎么用 MSYS2 UCRT64 在本地打出 Windows 发行 zip。与 Switch 无关。

## 目录速查

| 路径 | 内容 |
| --- | --- |
| `switch/validate_switch_build.sh` | 一键构建 + 环境校验脚本，CI 也可直接调 |
| `switch-toolchain/switch.cmake` | devkitA64 交叉编译工具链文件 |
| `switch/icon.jpg` | homebrew menu 图标（256×256） |
| `game/app/SwitchMain.cpp` | libnx 入口：挂载 romfs、创建并进入用户数据目录、启动引擎 |
| `game/app/GamepadInput.{h,cpp}` | 手柄映射，Switch 下交换 A/B、X/Y 物理位置 |
| `tests/GamepadInputTests.cpp` | 手柄映射单测，只能在本机编译运行 |
| `build-switch/` | 交叉编译产物，含 `OpenYAMM.nro` 与 `runtime/shaders/essl/` |
| `build-switch-host/` | 本机着色器编译器，交叉编译时被调用 |

## 三个最容易踩的坑

1. **Windows 上必须用 devkitPro 自带的 MSYS2 窗口**，不能用 Git Bash 或 PowerShell——工具链路径和
   `-specs=.../switch.specs` 在那边解析不了。
2. **着色器要单独构建**。`openyamm_runtime_shaders` 虽然在默认构建里，但
   `cmake --build --target openyamm_switch_nro` 不会带出它，漏了会得到一个能启动、但菜单黑屏的 NRO。
   脚本已帮你处理，手动编译时记得先构建该目标。
3. **ROMFS 是打包那一刻读的**。要嵌入的资源（含 `runtime/shaders/essl/*.bin`）必须在 `elf2nro` 之前
   就位，事后往暂存目录补文件无效。

## 出问题时

先看 Switch 上的日志：

```text
sdmc:/switch/openyamm/openyamm.log
```

里面会打印实际生效的 asset root（`romfs:/` 还是 `sdmc:/...`）和致命错误。启动时若声明了 `romfs:/` 但
NRO 没有嵌入 ROMFS，程序会直接以退出码 2 结束并在 stderr 说明原因。

渲染类问题可以加 `-DOPENYAMM_BGFX_DEBUG=ON` 重编，打开 bgfx 的逐调用检查（会明显变慢）。

功能层面的缺失（文本输入、震动/陀螺仪、联机菜单、docked 1080p）是已知项，不算 bug，清单见
[SWITCH_HOMEBREW.md](SWITCH_HOMEBREW.md) 的 Known gaps。
