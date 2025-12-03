# VansonMod

**专为 TrollStore 打造的 iOS 内存修改器与 RVA Patch 工具**

[![English Readme](https://img.shields.io/badge/Lang-English-blue)](./README.md)
![Platform](https://img.shields.io/badge/Platform-iOS%2014.0%2B-black)
![Support](https://img.shields.io/badge/Support-TrollStore-blue)
![License](https://img.shields.io/badge/License-MIT-green)

> **提示:** 点击上方的 "English Readme" 徽章可查看英文文档。

---

## 📖 开发者的心声

**开发 VansonMod 这条路，其实并不容易。**

在 TrollStore（非越狱）环境下实现一个功能完整的内存修改器和 RVA Patcher 充满了挑战。与传统的越狱插件不同，我无法依赖 Substrate 等注入框架。为了实现跨进程的读写、搜索和指令修改，我必须深入研究 Mach 内核 API，手动处理内存权限、ASLR 偏移计算以及进程依附逻辑。

这期间经历了无数个不眠之夜，解决了数不清的闪退和权限拒绝问题。但我坚持下来了，因为我想为巨魔社区带来一款真正好用的工具。

**VansonMod 承诺永久免费。**
没有广告，没有付费墙，没有隐藏功能。这完全是用爱发电的产物，只为了对逆向工程的热爱。

如果您觉得这个工具好用，您的支持就是我更新最大的动力！❤️

---

## 📸 应用截图

应用界面概览：

<p align="center">
  <img src="/Sreenshots/Select.PNG" width="30%" alt="进程选择"/>
  <img src="/Sreenshots/Rva Patcher.PNG" width="30%" alt="RVA 修改器"/>
  <img src="/Sreenshots/Settings.PNG" width="30%" alt="设置页面"/>
</p>

---

## 🔥 核心功能

*   **🧠 跨进程 RVA Patcher:** 直接修改运行中 App 的汇编指令，自动计算基址，内置防闪退保护。
*   **🔍 内存修改器:** 类似 CE 的搜索体验，支持全数据类型搜索、修改、锁定。
*   **📱 进程管理:** 查看、附加、结束进程，支持直接打开应用。
*   **💾 Hex 编辑器:** 查看和编辑原始内存数据。
*   **🌍 多语言支持:** 完美支持简体中文。

---

## ☕ 捐赠与支持

如果您喜欢 VansonMod，请考虑请我喝杯咖啡！这会鼓励我继续完善它。

| **Ko-fi (海外用户)** | **微信赞赏 (国内用户)** |
| :---: | :---: |
| [![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/vaenshine)<br><br>点击上方按钮跳转 Ko-fi | <img src="/Sreenshots/wechat.png" width="200" alt="微信收款码"/> |

---

## ⚠️ 免责声明

**VansonMod 仅供安全研究与逆向工程学习使用。**

*   **非盈利:** 严禁将本工具用于任何商业用途或非法行为。
*   **公平竞争:** 请尊重游戏开发者和其他玩家，切勿用于破坏网络游戏的公平性。
*   **风险自负:** 这是一个涉及系统底层权限的工具，不当使用可能导致应用崩溃或系统异常。因使用本工具导致的任何数据丢失、设备损坏或账号封禁，开发者概不负责。
---

## 🤝 致谢名单

*   开发者: **Vaenshine**
*   特别感谢: **Gey1ist**, **Xiczee**, **Zoomin**
*   社区支持: [iOSGods.com](https://iosgods.com/)

---

## 📈 Star 趋势

[![Star History Chart](https://api.star-history.com/svg?repos=vaenshine/VansonMod&type=Date)](https://star-history.com/#vaenshine/VansonMod&Date)

---
*Made with ❤️ by Vaenshine © 2025*
