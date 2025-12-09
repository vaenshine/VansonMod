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

它允许你在设备上修改游戏数值（如血量、金币等）、管理应用存档以及修改汇编指令 (RVA)。与依赖代码注入的传统越狱插件不同，VansonMod 在外部运行，利用 Mach 内核 API 对其他进程进行操作，无需完整的越狱环境（内存搜索功能）。

### ⚠️ 兼容性提示
*   **内存修改 / 存档管理**：完美支持 **所有** 设备（包括未越狱的巨魔用户）。
*   **RVA Patcher (汇编修改)**：需要 **越狱环境** (如 Dopamine, Palera1n) 才能正常工作。
    *   *原因:* 在未越狱的设备上，系统 **AMFI** 机制会严查代码签名。直接修改可执行代码段 (`__TEXT`) 会导致目标 App 立即闪退。

---

## 📸 应用截图

<p align="center">
  <img src="/Screenshots/Select.PNG" width="30%" alt="Process Select"/>
  <img src="/Screenshots/Modifier.PNG" width="30%" alt="Modifier"/>
  <img src="/Screenshots/HexEditor.PNG" width="30%" alt="HexEditor"/>
</p>
<p align="center">
  <img src="/Screenshots/RowEditor.PNG" width="30%" alt="RowEditor"/>
  <img src="/Screenshots/Rva Patcher.PNG" width="30%" alt="RVA Patcher"/>
  <img src="/Screenshots/Settings.PNG" width="30%" alt="Settings"/>
</p>

---

## ✨ 核心功能

### 1. 内存修改器
标准的内存搜索工具。
*   **数据类型:** 支持 Int8, Int16, Int32, Int64, Float, Double。
*   **搜索模式:**
    *   **精确搜索:** 查找具体数值。
    *   **模糊搜索:** 搜索未知初始值 (变大 / 变小 / 变动 / 不变)。
    *   **联合搜索:** 搜索相邻的一组数值 (例如 `500,1000`)。
*   **批量修改:** 支持将所有结果修改为 **固定值** 或 **递增数值** (+1, +2...)。
*   **锁定:** 支持数值锁定（支持后台运行）。
*   **内存浏览:** 直观查看附近的数值内存结构，支持无限滚动。

### 2. 跨进程 RVA Patcher (需越狱)
直接修改运行中 App 的汇编指令。
*   **Live Offset Patch:** 输入 IDA 偏移量，自动计算基址并修改指令。
*   **安全机制:** 自动处理内存读写权限。
*   **预设指令:** 内置常用 Hex (RET True, NOP 等)。

### 3. 应用存档管理 (新)
*   **备份/还原:** 一键备份应用的 Documents 和 Library 数据到本地文件夹。
*   **原生集成:** 备份文件可在 iOS “文件” 应用 (我的 iPhone -> VansonMod) 中直接查看、导出或导入。

### 4. 进程管理
*   查看带有图标、版本号和 BundleID 的进程列表。
*   **智能过滤:** 自动隐藏系统扩展和小组件，界面更清爽。
*   **控制:** 附加调试、强制结束进程、打开应用。

### 5. Hex 编辑器 2.0
*   **分屏视图:** 上下分屏同时显示 Hex 和 ASCII，支持同步滚动。
*   **行编辑器:** 支持实时编辑单行数据。
*   **导航:** 无限滚动列表与地址跳转。

---

## 📝 更新日志 (Changelog)
### v1.6 - 字符串搜索与 iPad 适配优化
*   **字符串搜索:** 新增字符串搜索功能（该功能主要适用于调试场景）。
*   **存档导入:** 支持从 iOS “文件” App 直接导入备份文件夹。
*   **RVA 界面升级:** 展示主程序基址（支持点击复制），输入框新增**智能容错机制**。
*   **iPad 适配:** 全面适配 iPad 横屏显示模式及屏幕自动旋转功能。
*   **交互体验:** 交互全面优化，新增跳转菜单功能。

### v1.5 - 高级搜索与 Hex 编辑器 2.0
*   **高级搜索:** 新增 **模糊搜索** (未知初始值 -> 变大/变小) 和 **联合搜索** (如 `500,1000`)。
*   **批量修改:** 支持将搜索结果修改为 **固定值** 或 **递增数值**。
*   **Hex 编辑器 2.0:** 全新重构，支持上下分屏 (Hex/ASCII) 同步滚动与独立行编辑。
*   **存档管理:** 改用文件夹直拷方案，更稳定，并支持在系统“文件”App 中直接管理备份。
*   **进程列表:** 智能过滤系统进程 (com.apple)，并新增应用版本号显示。
*   **体验:** 修改器和内存浏览器增加刷新按钮；修复设置页输入框 Bug。

### v1.4 - 存档管理与优化
*   **新增:** 应用存档备份与还原功能。
*   **新增:** 检查更新功能。
*   **优化:** 进程分类逻辑。
*   **修复:** 过滤进程失效的问题。
*   **稳定:** 增强稳定性，修复闪退。

### v1.3 - 稳定性与功能扩展
*   **稳定性:** 提升整体稳定性，修复崩溃问题。
*   **进程过滤:** 增加过滤功能，排除系统进程及插件/组件。
*   **修改器:** 优化修改器模块，增加刷新功能以实时查看数值。
*   **新功能:** 内存浏览器 (Memory Browser)，直观查看数值列表。

### v1.2 - 功能增强与 UI/UX
*   **Hex 编辑器:** 增加行内编辑功能，支持 Hex/ASCII 实时预览。
*   **UI 优化:** 界面微调，提升用户体验。
*   **修复:** 修复特定崩溃问题。
*   **收藏夹:** 增加独立的收藏夹入口与管理功能（备注/删除）。

### v1.1 - 安全性更新
*   **RVA 安全检测:** 增加环境检测。在未越狱设备上使用 Patch 功能前弹出警告，防止误操作导致闪退。
*   **优化:** 提升进程切换时的稳定性。

### v1.0 - 初始版本
*   首个支持 TrollStore 的独立内存工具。
*   包含内存搜索、RVA 修改、进程管理、Hex 编辑及多语言支持。

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
