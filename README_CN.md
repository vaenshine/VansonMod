# VansonMod

<!-- 新增 Social Preview 作为 README 顶部横幅 -->
<p align="center">
  <img src="https://repository-images.githubusercontent.com/1109090336/135167c3-e943-48a9-aa0d-67b3c21e844d" alt="VansonMod Social Preview" width="100%"/>
</p>

**专为 TrollStore 打造的 iOS 内存修改器与 RVA Patch 工具**

[![English Readme](https://img.shields.io/badge/Lang-English-blue)](./README.md)
![Platform](https://img.shields.io/badge/Platform-iOS%2014.0%2B-black)
![Support](https://img.shields.io/badge/Support-TrollStore-blue)
![License](https://img.shields.io/badge/License-MIT-green)

> **提示:** 点击上方的 "English Readme" 徽章可查看英文文档。

---

## 🚀 VansonMod 简介

**VansonMod** 是一款专为 **TrollStore (巨魔)** 环境设计的独立 Root Helper 工具。

它打破了传统修改器需要越狱的限制（针对内存搜索），让你在非越狱设备上也能修改数值。它利用巨魔的高级权限运行，实现了跨进程操作”。

### ⚠️ 重要兼容性提示
*   **内存修改器 (搜数值)**：完美支持 **所有** 设备（包括未越狱的巨魔用户）。
*   **RVA Patcher (改指令)**：**仅限越狱用户** 使用（如 Dopamine, Palera1n）。
    *   *原因:* 在未越狱的设备上，系统 **AMFI** 机制会严查代码签名。修改代码段 (`__TEXT`) 会导致目标 App 立即闪退。这是系统限制，非软件 Bug。

---

## 📸 应用截图

<p align="center">
  <img src="/Sreenshots/Select.PNG" width="30%" alt="Process Select"/>
  <img src="/Sreenshots/Modifier.PNG" width="30%" alt="Modifier"/>
  <img src="/Sreenshots/HexEditor.PNG" width="30%" alt="HexEditor"/>
  <img src="/Sreenshots/RowEditor.PNG" width="30%" alt="RowEditor"/>
  <img src="/Sreenshots/Rva Patcher.PNG" width="30%" alt="RVA Patcher"/>
  <img src="/Sreenshots/Settings.PNG" width="30%" alt="Settings"/>
</p>

---

## 🔥 核心功能

### 1. 跨进程 RVA Patcher (需越狱)
*   **Live Offset Patch:** 输入 IDA 偏移量，自动计算基址并修改汇编指令。
*   **安全机制:** 自动处理内存读写权限，确保在越狱环境下的稳定性。
*   **指令预设:** 内置常用 Hex (RET True, NOP 等)。

### 2. 内存修改器 (全员可用)
*   **全类型:** Int, Float, Double 等。
*   **搜索:** 首次搜索、再次搜索、模糊搜索。
*   **锁定:** 锁定数值，防止变动。

### 3. 进程管理
*   查看带有图标和 BundleID 的用户/系统进程列表。
*   **附加 (Attach):** 获取目标进程控制权。
*   **管理:** 支持直接打开应用或强制结束进程。

### 4. Hex 编辑器
*   查看和编辑原始内存数据。
*   支持地址跳转。

---

## ☕ 捐赠与支持

**VansonMod 是完全免费的。**
如果您觉得这个工具好用，请考虑请我喝杯咖啡！这会鼓励我继续完善它。

| **Ko-fi (海外用户)** | **微信赞赏 (国内用户)** |
| :---: | :---: |
| [![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/vaenshine)<br><br>点击上方按钮跳转 Ko-fi | <img src="/Sreenshots/wechat.png" width="200" alt="微信收款码"/> |

---

## 📥 安装方法

1.  在 [Releases](../../releases) 页面下载最新的 `.tipa` 文件。
2.  使用 **TrollStore** 安装。
3.  打开 App 即可使用。

---

## 🤝 致谢名单

*   开发者: **Vaenshine**
*   特别感谢: **Gey1ist**, **Xiczee**, **Zoomin**
*   社区支持: [iOSGods.com](https://iosgods.com/)

---

## ⚠️ 免责声明

本工具仅供 **安全研究与逆向工程学习** 使用。
*   **非盈利:** 严禁将本工具用于任何商业用途或非法行为。
*   **公平竞争:** 请尊重游戏开发者和其他玩家，切勿用于破坏网络游戏的公平性。
*   **风险自负:** 这是一个涉及系统底层权限的工具，不当使用可能导致应用崩溃或系统异常。因使用本工具导致的任何数据丢失、设备损坏或账号封禁，开发者概不负责。

---

## 📈 Star 趋势

[![Star History Chart](https://api.star-history.com/svg?repos=vaenshine/VansonMod&type=Date)](https://star-history.com/#vaenshine/VansonMod&Date)

---
*Made with ❤️ by Vaenshine © 2025*
