# VansonMod

<p align="center">
  <img src="https://repository-images.githubusercontent.com/1109090336/135167c3-e943-48a9-aa0d-67b3c21e844d" alt="VansonMod Social Preview" width="100%"/>
</p>

**专为 TrollStore 打造的 iOS 内存修改器与 RVA Patch 工具**

[![English Readme](https://img.shields.io/badge/Lang-English-blue)](./README.md)
![Platform](https://img.shields.io/badge/Platform-iOS%2014.0%2B-black)
![Support](https://img.shields.io/badge/Support-TrollStore-blue)
![License](https://img.shields.io/badge/License-MIT-green)

> **Note:** Click the "Lang English" badge above to view the English documentation.

> [![Join Telegram](https://img.shields.io/badge/加入-Telegram%20频道-blue?logo=telegram&logoWidth=20&labelColor=26A5E4&color=white)](https://t.me/VansonMod)

---

## 📖 简介

**VansonMod** 是一款专为 **TrollStore (巨魔)** 环境设计的独立 Root Helper 工具。

与传统的越狱插件不同，它无需代码注入，而是利用 Mach 内核 API 在外部运行，因此 **内存修改功能无需越狱环境** 即可使用。它集成了强大的**内存修改器**（支持精确/模糊/联合搜索、临近搜索、批量修改及浮点误差配置）、**应用存档管理**（一键备份还原 Documents/Library）、**智能进程管理**（自动识别 TrollStore 应用并支持多语言显示）以及专业的 **Hex 编辑器**。此外，对于越狱用户，它还提供了 **跨进程 RVA Patcher**，可直接修改运行中的汇编指令。

### ⚠️ 兼容性提示
*   **内存修改 / 存档管理**：✅ 支持 **所有** 设备（包括未越狱的巨魔用户）。
*   **RVA Patcher (汇编修改)**：⚠️ 需要 **越狱环境** (如 Dopamine, Palera1n) 才能正常工作。
    *   *原因:* 在未越狱的设备上，系统 AMFI 机制会严查代码签名。直接修改可执行代码段 (`__TEXT`) 会导致目标 App 立即闪退。

---

### ✨ 核心功能

*   **内存修改器**:
    *   **多模式搜索**: 精确、模糊、联合（高性能有序）、混合模式（二次筛选）。
    *   **临近搜索**: 基于现有结果搜索附近数值（自动去重）。
    *   **批量修改**: 支持全选/范围选择，固定值或递增修改。
    *   **智能配置**: 支持自定义浮点误差 (Float Tolerance)。
    *   **其他**: 数值锁定、无限滚动内存浏览。
*   **进程管理**:
    *   **智能过滤**: 自动识别用户及 TrollStore 应用，隐藏系统进程。
    *   **多语言**: 智能显示 App 本地化名称。
    *   **控制**: 附加、结束进程、打开应用。
*   **应用存档管理**:
    *   **一键备份/还原**: 完整备份 Documents/Library，支持多存档。
    *   **原生集成**: 可在“文件”应用中管理、导出导入。
*   **跨进程 RVA Patcher (需越狱)**:
    *   **实时修改**: 输入 Offset 和 Hex 自动 Patch 运行中代码。
    *   **安全**: 自动处理内存权限，内置常用指令预设。
*   **Hex 编辑器**:
    *   **分屏视图**: Hex/ASCII 同步显示。
    *   **编辑**: 支持行编辑与地址跳转。

---

## 📸 应用截图

<p align="center">
  <img src="/Screenshots/Apps.PNG" width="30%" alt="Apps"/>
  <img src="/Screenshots/Modifier.PNG" width="30%" alt="Modifier"/>
  <img src="/Screenshots/HexSplitView.PNG" width="30%" alt="HexSplitView"/>
</p>
<p align="center">
  <img src="/Screenshots/RvaPatcher.PNG" width="30%" alt="RvaPatcher"/>
  <img src="/Screenshots/AppManager.PNG" width="30%" alt="AppManager"/>
  <img src="/Screenshots/Settings.PNG" width="30%" alt="Settings"/>
</p>

---

## 📝 更新日志 (Changelog)

### v1.9 - 新增临近搜索与多模式搜索 优化检索效率及批量修改
*   **新增临近搜索功能**：可基于已有结果扫描附近内存数据，精准定位关联地址。
*   **模糊搜索效率提升**：模糊搜索再度提速，大幅缩短检索耗时，体验更流畅。
*   **支持多模式混合搜索**：不再限制单一搜索模式，可自由切换模式继续检索。
*   **联合搜索功能增强**：需遵循内存顺序先后搜索原则，内存中条件顺序不符可能导致检索无结果。
*   **优化批量修改逻辑**：新增区间选择功能，支持自由选定修改范围，操作更便捷。
*   **设置项新增配置**：包含联合搜索范围、搜索结果显示设置（需要显示 100 亿结果的朋友，你们有福啦）、浮点误差调节。
*   **稳定性提升**：修复若干已知问题，提升应用整体稳定性。

<details>
<summary>v1.80 - 新增主题切换与iPad分屏 优化搜索体验及问题修复</summary>

*   **新增主题切换模式**：支持自由切换主题模式，包含**跟随系统｜浅色｜深色**三种选择。
*   **修复递增修改逻辑**：修正了数值递增修改功能的逻辑异常问题。
*   **适配iPad原生分屏**：新增iPad原生分屏支持（兼容性待验证，台前调度模式下可正常运行）。
*   **回车键触发搜索**：新增回车键快捷触发搜索功能，提升操作效率。
*   **搜索结果序号显示**：为搜索结果添加序号标识，方便快速定位内容。
*   **锁定列表功能优化及Bug修复**：为锁定列表新增独立开关，并修复开启状态下修改数值不生效的问题。
</details>

<details>
<summary>v1.72 - Hex 界面重构与备份管理增强</summary>

*   **Hex 界面重构：** 全新设计的 Hex 编辑器，支持「仅 Hex / 分屏 / 仅文本」三种视图模式切换。深度优化了布局比例与行高，实现了零边距显示与完美的视觉对齐。
*   **全局备份管理：** 在应用管理中新增「备份管理」入口，支持统一查看设备内的所有备份文件。即使是已卸载应用的「僵尸存档」也能在此处找到并进行导出或清理。
*   **进程搜索增强：** 进程选择页面（Tab 1）新增搜索栏，支持通过应用名称、BundleID 或 PID 快速筛选目标进程。
*   **还原流程优化：** 存档还原成功后，工具将自动结束目标应用的进程，无需用户手动重启游戏即可生效。
*   **弹窗交互优化：** 收藏 / 锁定模块中，统一了内存地址点击弹窗的操作逻辑。
</details>

### v1.71 - 修复模糊搜索匹配偏差问题，优化核心算法，大幅提升搜索效率与准确性

### v1.7 - 增加模糊搜索自行选择类型

<details>
<summary>v1.6 - 字符串搜索与 iPad 适配优化</summary>

*   **字符串搜索:** 新增字符串搜索功能（该功能主要适用于调试场景）。
*   **存档导入:** 支持从 iOS “文件” App 直接导入备份文件夹。
*   **RVA 界面升级:** 展示主程序基址（支持点击复制），输入框新增**智能容错机制**。
*   **iPad 适配:** 全面适配 iPad 横屏显示模式及屏幕自动旋转功能。
*   **交互体验:** 交互全面优化，新增跳转菜单功能。
</details>

<details>
<summary>v1.5 - 高级搜索与 Hex 编辑器 2.0</summary>

*   **高级搜索:** 新增 **模糊搜索** (未知初始值 -> 变大/变小) 和 **联合搜索** (如 `500,1000`)。
*   **批量修改:** 支持将搜索结果修改为 **固定值** 或 **递增数值**。
*   **Hex 编辑器 2.0:** 全新重构，支持上下分屏 (Hex/ASCII) 同步滚动与独立行编辑。
*   **存档管理:** 改用文件夹直拷方案，更稳定，并支持在系统“文件”App 中直接管理备份。
*   **进程列表:** 智能过滤系统进程 (com.apple)，并新增应用版本号显示。
*   **体验:** 修改器和内存浏览器增加刷新按钮；修复设置页输入框 Bug。
</details>

<details>
<summary>v1.4 - 存档管理与优化</summary>

*   **新增:** 应用存档备份与还原功能。
*   **新增:** 检查更新功能。
*   **优化:** 进程分类逻辑。
*   **修复:** 过滤进程失效的问题。
*   **稳定:** 增强稳定性，修复闪退。
</details>

<details>
<summary>v1.3 - 稳定性与功能扩展</summary>

*   **稳定性:** 提升整体稳定性，修复崩溃问题。
*   **进程过滤:** 增加过滤功能，排除系统进程及插件/组件。
*   **修改器:** 优化修改器模块，增加刷新功能以实时查看数值。
*   **新功能:** 内存浏览器 (Memory Browser)，直观查看数值列表。
</details>

<details>
<summary>v1.2 - 功能增强与 UI/UX</summary>

*   **Hex 编辑器:** 增加行内编辑功能，支持 Hex/ASCII 实时预览。
*   **UI 优化:** 界面微调，提升用户体验。
*   **修复:** 修复特定崩溃问题。
*   **收藏夹:** 增加独立的收藏夹入口与管理功能（备注/删除）。
</details>

<details>
<summary>v1.1 - 安全性更新</summary>
*   **RVA 安全检测:** 增加环境检测。在未越狱设备上使用 Patch 功能前弹出警告，防止误操作导致闪退。
*   **优化:** 提升进程切换时的稳定性。
</details>

<details>
<summary>v1.0 - 初始版本</summary>
*   首个支持 TrollStore 的独立内存工具。
*   包含内存搜索、RVA 修改、进程管理、Hex 编辑及多语言支持。
</details>

---

## 📥 安装

1.  在 [Releases](../../releases) 页面下载最新的 `.tipa` 文件。
2.  使用 **TrollStore** 安装。
3.  打开 App 即可使用。

---

## 🤝 致谢

*   开发者: **Vaenshine**
*   特别感谢: **Gey1ist**, **Xiczee**, **Zoomin**
*   社区支持: [iOSGods.com](https://iosgods.com/)

---

## ⚠️ 免责声明

本工具仅用于 **安全研究与逆向工程学习**，使用前请仔细阅读以下条款，一旦使用即视为同意全部内容：

*   **非盈利与合规性：** 严禁将本工具用于商业盈利、非法入侵、数据窃取等违反法律法规或平台规则的行为，仅限合法的学习与研究场景。
*   **公平与尊重原则：** 请尊重应用/游戏开发者的知识产权及其他用户的合法权益，不得用于破坏应用正常运行、篡改数据、影响使用公平性等恶意场景。
*   **风险自行承担：** 使用者应自行评估使用本工具的相关风险，因违规使用、操作不当等导致的数据丢失、设备损坏、账号封禁或法律责任，均由使用者本人承担，开发者不承担任何直接或间接责任。

---

## ☕ 捐赠与支持

**VansonMod 是免费的。** 如果您觉得这个工具好用，请考虑请我喝杯咖啡！这会鼓励我继续完善它。❤️

| **Ko-fi (海外用户)** | **微信赞赏 (国内用户)** |
| :---: | :---: |
| [![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/vaenshine)<br><br>点击上方按钮跳转 Ko-fi | <img src="/Screenshots/wechat.png" width="200" alt="微信收款码"/> |

---

## 📈 Star 趋势

[![Star History Chart](https://api.star-history.com/svg?repos=vaenshine/VansonMod&type=Date)](https://star-history.com/#vaenshine/VansonMod&Date)

---
