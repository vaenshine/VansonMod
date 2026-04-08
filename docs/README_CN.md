# VansonMod

<p align="center">
  <img src="https://repository-images.githubusercontent.com/1109090336/135167c3-e943-48a9-aa0d-67b3c21e844d" alt="VansonMod Social Preview" width="100%"/>
</p>

**面向 TrollStore 的 iOS 内存编辑、指针分析、RVA Patch 与进程管理工具（可选越狱），支持 Hex 编辑、数值扫描与备份/还原**

[English](../README.md) | **简体中文** | [繁體中文](./README_TW.md) | [العربية](./README_AR.md) | [Deutsch](./README_DE.md) | [Español](./README_ES.md) | [Français](./README_FR.md) | [日本語](./README_JA.md) | [한국어](./README_KO.md) | [Português](./README_PT.md) | [Русский](./README_RU.md) | [ไทย](./README_TH.md) | [Tiếng Việt](./README_VI.md)

![Platform](https://img.shields.io/badge/Platform-iOS%2014.0%2B-black)
![Support](https://img.shields.io/badge/Support-TrollStore-blue)
![License](https://img.shields.io/badge/License-MIT-green)

> [![Join Telegram](https://img.shields.io/badge/加入-Telegram%20频道-blue?logo=telegram&logoWidth=20&labelColor=26A5E4&color=white)](https://t.me/VansonMod)

---

## 简介

**VansonMod** 是一款面向 **TrollStore** 环境设计的独立 iOS 调试工具。它以外部方式工作，不依赖传统 tweak 注入，可在非越狱设备上完成进程选择、内存搜索、内存浏览、指针分析与验证、特征码分析、脚本自动化、应用存档等常用调试流程。

在越狱环境下，VansonMod 还会进一步开放面向代码层的调试能力，包括 **RVA Patch**、**硬件断点监控** 与更完整的运行时代码观察工作流。当前版本已经从单一的内存搜索工具扩展为一套更完整的 iOS 调试工作台，适合 iPhone 与 iPad 使用，并支持分屏、横屏与 Stage Manager。

## 兼容性说明

- **TrollStore / 非越狱可用**：进程选择、内存搜索、临近搜索、结果筛选、内存浏览、Hex 编辑、指针分析与验证、特征码分析、脚本工具、应用存档管理、主题/语言/图标等功能。
- **依赖目标进程 Task Port 的功能**：部分运行时能力需要成功获取目标进程的 task port，实际效果会受到当前环境与目标进程状态影响。
- **仅越狱环境建议或限定使用**：`RVA Patch`、`RVA 调试记录管理`、`硬件断点监控` 等涉及执行代码修改或调试寄存器的能力，更适合在 **Dopamine / palera1n** 等越狱环境下使用。
- **原因说明**：在未越狱设备上，系统 **AMFI** 会严格校验代码签名。直接修改可执行代码段（`__TEXT`）通常会导致目标 App 立即闪退。

## 多语言支持

- 当前内置语言：简体中文、繁體中文、English、العربية、Deutsch、Español、Français、日本語、한국어、Português、Русский、ไทย、Tiếng Việt。

## 页面结构

- **进程选择**：查看运行中进程、全部应用或系统进程，支持搜索名称 / Bundle ID / PID，并可直接执行附加、打开、结束进程、创建备份、查看代码变化等操作。
- **内存调试**：完成精确搜索、模糊搜索、联合搜索、临近搜索、结果筛选、批量修改，以及数值视图 / Hex 视图跳转。
- **RVA 调试**：按模块与偏移写入 Patch，管理 RVA 记录，并在越狱环境下完成更完整的代码级调试工作流。
- **工具箱**：集中管理内存锁定、收藏、指针、RVA、特征码、验证文件与脚本。
- **设置**：统一调整主题、语言、图标、标签排序、搜索范围、浮点误差、结果显示限制、更新检查等配置，并支持长按底部菜单快速调整标签顺序。

## 功能亮点

- **进程与应用管理**：支持 `Running / All / System` 三种视图，自动显示本地化应用名称与版本号，并提供星标、复制 PID / Bundle ID、直接打开应用、结束进程等快捷操作。
- **内存搜索与批量调试**：支持精确、模糊、联合、范围、临近等多种搜索方式；支持大于 / 小于 / 区间筛选，以及固定值修改、递增修改、批量锁定、批量收藏、批量删除等高频操作。
- **内存浏览与 Hex 编辑**：支持地址跳转、自动刷新、字符串视图、批量复制地址；Hex 编辑器支持 `Hex / 分屏 / 文本` 三种视图、行编辑、偏移跳转与快速写入。
- **指针分析与验证**：支持手动添加与自动搜索指针链，涵盖静态 / 动态 / 全部 / 追溯等模式；支持实时验证、增量快照、变化区域对比、验证文件保存、导入导出与锁定联动。
- **特征码分析工具**：可从任意地址快速进入特征码分析流程，支持模块范围选择、全局搜索、智能掩码、结果验证，并可将特征码直接保存到工具箱继续管理。
- **脚本系统**：内置 JavaScript 脚本执行环境，提供示例、快捷指令、控制台输出与隐私模式；可直接在 VM 内查看脚本说明文档和示例内容，方便上手与编写。
- **RVA 调试与断点监控**：支持模块选择、Offset Patch、常用 ARM64 指令预设、RVA 记录管理；在越狱环境下还可使用硬件断点监控、命中记录、代码检查器，并将命中位置快速发送到 RVA 调试器。
- **应用存档与进程审计**：支持 `Documents / Library` 一键备份与还原、多备份管理、系统“文件”导入导出；进程审计可用来查看目标 App 运行前后哪些代码位置或 RVA 发生了变化，并支持导出差异结果与恢复原始字节。
- **设置与体验优化**：支持主题切换、语言切换、应用图标切换、标签排序、长按底部菜单调整标签顺序、模糊搜索范围切换、锁定频率、防休眠、结果显示限制、检查更新，并原生适配 iPad 分屏、横屏与 Stage Manager。

## 应用截图

| <div align="center"><img src="../Screenshots/APP_SELECT.PNG" width="100%" alt="APP_SELECT"/></div> | <div align="center"><img src="../Screenshots/MEM_BROWSER.PNG" width="100%" alt="MEM_BROWSER"/></div> | <div align="center"><img src="../Screenshots/MEM_DEBUG.PNG" width="100%" alt="MEM_DEBUG"/></div> | <div align="center"><img src="../Screenshots/MEM_HEX_MIX.PNG" width="100%" alt="MEM_HEX_MIX"/></div> |
| :------------------------------------------------------------------------------------------------: | :--------------------------------------------------------------------------------------------------: | :------------------------------------------------------------------------------------------------: | :---------------------------------------------------------------------------------------------------: |
| <div align="center"><img src="../Screenshots/RVA_MANAGER.PNG" width="100%" alt="RVA_MANAGER"/></div> | <div align="center"><img src="../Screenshots/POINTER_ANALYSIS.PNG" width="100%" alt="POINTER_ANALYSIS"/></div> | <div align="center"><img src="../Screenshots/POINTER_VERIFY.PNG" width="100%" alt="POINTER_VERIFY"/></div> | <div align="center"><img src="../Screenshots/POINTER_LOCKER.PNG" width="100%" alt="POINTER_LOCKER"/></div> |

---

## 更新日志

请前往 [Releases](https://github.com/vaenshine/VansonMod/releases) 查看。

---

## 安装

1. 在 [Releases](https://github.com/vaenshine/VansonMod/releases) 页面下载最新的 `.tipa` 文件。
2. 使用 **TrollStore** 安装。
3. 打开 App 后选择目标进程，即可开始调试。

---

## 致谢

*   开发者: **Vaenshine**
*   特别感谢: **Gey1ist**, **Xiczee**, **Zoomin**
*   社区支持: [iOSGods.com](https://iosgods.com/)

---

## 免责声明

本工具仅用于 **安全研究与逆向工程学习**，使用前请仔细阅读以下条款，一旦使用即视为同意全部内容：

*   本工具为免费闭源项目，仅限安全研究、逆向工程学习及合规技术场景测试使用，使用后请于 24 小时内卸载。
*   本工具为通用技术调试工具，不针对任何应用程序提供定向功能、调试方法及专属适配，无任何预设调试目标与定制化操作方案。
*   严禁将本工具用于商业牟利、破坏应用运营公平性、非法侵入他人系统、窃取数据及其他任何违反国家法律法规与公序良俗的行为。
*   使用本工具所实施的全部操作，均由使用者独立自主作出，操作过程中可能引发的目标应用崩溃、数据损坏丢失、账号限制封禁、设备异常等各类风险，以及由此产生的一切直接、间接损失与法律责任，均由使用者自行承担。

---

## 重要声明

本项目为免费闭源项目，**不接受任何形式的捐赠**，所有开发工作均基于技术研究与交流目的推进。

---

## Star 趋势

[![Star History Chart](https://api.star-history.com/svg?repos=vaenshine/VansonMod&type=Date)](https://star-history.com/#vaenshine/VansonMod&Date)
