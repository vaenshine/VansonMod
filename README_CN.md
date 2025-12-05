# VansonMod

<p align="center">
  <img src="https://repository-images.githubusercontent.com/1109090336/135167c3-e943-48a9-aa0d-67b3c21e844d" alt="VansonMod Social Preview" width="100%"/>
</p>

**专为 TrollStore 打造的 iOS 内存修改器与 RVA Patch 工具**

[![English Readme](https://img.shields.io/badge/Lang-English-blue)](./README.md)
![Platform](https://img.shields.io/badge/Platform-iOS%2014.0%2B-black)
![Support](https://img.shields.io/badge/Support-TrollStore-blue)
![License](https://img.shields.io/badge/License-MIT-green)

> **Note:** Click the "English Readme" badge above to view the English documentation.

> [![加入Telegram](https://img.shields.io/badge/加入-Telegram%20频道-blue?logo=telegram&logoWidth=20&labelColor=26A5E4&color=white)](https://t.me/VansonMod)

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
  <img src="/Sreenshots/Select.PNG" width="30%" alt="进程选择"/>
  <img src="/Sreenshots/Modifier.PNG" width="30%" alt="修改器"/>
  <img src="/Sreenshots/HexEditor.PNG" width="30%" alt="Hex编辑器"/>
</p>
<p align="center">
  <img src="/Sreenshots/RowEditor.PNG" width="30%" alt="行编辑器"/>
  <img src="/Sreenshots/Rva Patcher.PNG" width="30%" alt="RVA 修改器"/>
  <img src="/Sreenshots/Settings.PNG" width="30%" alt="设置页面"/>
</p>

---

## ✨ 核心功能

### 1. 内存修改器
标准的内存搜索工具。
*   **数据类型:** 支持 Int8, Int16, Int32, Int64, Float, Double。
*   **搜索模式:** 首次搜索、再次搜索 (变大/变小/精确/变动)。
*   **锁定:** 支持数值锁定（支持后台运行）。
*   **内存浏览:** 直观查看附近的数值内存结构。

### 2. 跨进程 RVA Patcher (需越狱)
直接修改运行中 App 的汇编指令。
*   **Live Offset Patch:** 输入 IDA 偏移量，自动计算基址并修改指令。
*   **安全机制:** 自动处理内存读写权限。
*   **预设指令:** 内置常用 Hex (RET True, NOP 等)。

### 3. 应用存档管理 (新)
*   **备份/还原:** 一键备份应用的 Documents 和 Library 数据。
*   **导入/导出:** 手动选择导入存档。

### 4. 进程管理
*   查看带有图标和 BundleID 的进程列表。
*   **过滤:** 自动隐藏系统扩展和小组件，界面更清爽。
*   **控制:** 附加调试、强制结束进程、打开应用。

### 5. Hex 编辑器
*   以十六进制和 ASCII 码查看任意内存区域。
*   **行编辑器:** 支持分屏实时编辑与预览。
*   **导航:** 无限滚动列表与地址跳转。

---

## 📝 更新日志 (Changelog)

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

本工具仅供 **安全研究与逆向工程学习** 使用。
*   **非盈利:** 严禁将本工具用于任何商业用途或非法行为。
*   **公平竞争:** 请尊重游戏开发者和其他玩家，切勿用于破坏网络游戏的公平性。
*   **风险自负:** 开发者不对因使用本工具导致的任何数据丢失、设备损坏或账号封禁承担责任。

---

## ☕ 捐赠与支持

**VansonMod 是免费的。** 如果您觉得这个工具好用，请考虑请我喝杯咖啡！这会鼓励我继续完善它。❤️

| **Ko-fi (海外用户)** | **微信赞赏 (国内用户)** |
| :---: | :---: |
| [![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/vaenshine)<br><br>点击上方按钮跳转 Ko-fi | <img src="/Sreenshots/wechat.png" width="200" alt="微信收款码"/> |

---

## 📈 Star 趋势

[![Star History Chart](https://api.star-history.com/svg?repos=vaenshine/VansonMod&type=Date)](https://star-history.com/#vaenshine/VansonMod&Date)

---
*Made with ❤️ by Vaenshine © 2025*
