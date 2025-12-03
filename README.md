# VansonMod

**The Ultimate iOS Memory Editor & RVA Patcher for TrollStore**

[![中文说明](https://img.shields.io/badge/Lang-中文-red)](./README_CN.md)
![Platform](https://img.shields.io/badge/Platform-iOS%2014.0%2B-black)
![Support](https://img.shields.io/badge/Support-TrollStore-blue)
![License](https://img.shields.io/badge/License-MIT-green)

> **Note:** Click the "中文说明" badge above to view the Chinese documentation.

---

## 🚀 What is VansonMod?

**VansonMod** is a standalone, powerful memory manipulation tool designed specifically for the **TrollStore** ecosystem.

It allows you to modify game values (Health, Gold, etc.) and patch assembly instructions (RVA) directly on your device **without needing a Jailbreak**. It runs as a Root Helper to bypass sandbox limitations, giving you "God Mode" control over other running applications.

### 📱 Compatibility
*   **System:** **iOS 14.0 - 17.0**
*   **Requirement:** **TrollStore** must be installed.
*   **Architecture:** Works on all arm64 / arm64e devices.

---

## 📖 A Note from the Developer

**Developing VansonMod was quite a journey.**

Bringing a full-featured Memory Editor and Live RVA Patcher to a non-jailbroken environment (TrollStore) was no easy task. Unlike traditional jailbreak tweaks, I couldn't rely on code injection frameworks like Cydia Substrate. I had to build everything from scratch using low-level Mach Kernel APIs to handle memory permissions, ASLR calculations, and process attachment safely.

There were countless sleepless nights, crashes, and "why isn't this working" moments. But I kept going because I wanted to create something powerful for the community.

**VansonMod is, and always will be, 100% FREE.**
No ads, no paywalls, no hidden features. I built this for the love of technology and reverse engineering.

If you enjoy using it, your support means the world to me! ❤️

---

## 📸 Screenshots

Here is a glimpse of what VansonMod looks like:

<p align="center">
  <img src="/Sreenshots/Select.PNG" width="30%" alt="Process Select"/>
  <img src="/Sreenshots/Rva Patcher.PNG" width="30%" alt="RVA Patcher"/>
  <img src="/Sreenshots/Settings.PNG" width="30%" alt="Settings"/>
</p>

---

## 🔥 Key Features

*   **🧠 Cross-Process RVA Patcher:** Live assembly patching with auto ASLR calculation and safety checks.
*   **🔍 Memory Scanner:** Search, modify, and lock values (Int/Float/Double) just like Cheat Engine.
*   **📱 Process Manager:** Attach to, kill, or launch any app on your device.
*   **💾 Hex Editor:** View and edit raw memory.
*   **🌍 Multi-Language:** English & Chinese support.

---

## ☕ Support & Donation

This project is powered by passion. If VansonMod has helped you, please consider buying me a coffee! It helps keep the updates coming.

| **Ko-fi (Global)** | **WeChat Pay (China)** |
| :---: | :---: |
| [![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/vaenshine)<br><br>Click the button above to support via Ko-fi! | <img src="/Sreenshots/wechat.png" width="200" alt="WeChat Pay"/> |

---

## ⚠️ Disclaimer

**VansonMod is developed strictly for educational purposes and security research.**

*   **Non-Commercial:** Do not use this tool for commercial gain or illegal activities.
*   **Fair Play:** Please respect game developers and other players. Do not use this tool to disrupt the fairness of online multiplayer games.
*   **Use at Your Own Risk:** As a root-level tool, improper use may cause app crashes or system instability. The developer is not responsible for any data loss, device issues, or account bans resulting from the use of this tool.

---

## 🤝 Credits

*   Created by **Vaenshine**
*   Special Thanks to: **Gey1ist**, **Xiczee**, **Zoomin**
*   Supported by: [iOSGods.com](https://iosgods.com/)

---

## 📈 Star History

[![Star History Chart](https://api.star-history.com/svg?repos=vaenshine/VansonMod&type=Date)](https://star-history.com/#vaenshine/VansonMod&Date)

---
*Made with ❤️ by Vaenshine © 2025*
