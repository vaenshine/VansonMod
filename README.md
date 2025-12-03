# VansonMod

**The Ultimate iOS Memory Editor & RVA Patcher for TrollStore**

[![中文说明](https://img.shields.io/badge/Lang-中文-red)](./README_CN.md)
![Platform](https://img.shields.io/badge/Platform-iOS%2014.0%2B-black)
![Support](https://img.shields.io/badge/Support-TrollStore-blue)
![License](https://img.shields.io/badge/License-MIT-green)

> **Note:** Click the "中文说明" badge above to view the Chinese documentation.

---

## 🚀 What is VansonMod?

**VansonMod** is a standalone Root Helper utility designed specifically for the **TrollStore** environment.

It allows you to modify game values (Health, Gold, etc.) and patch assembly instructions (RVA) directly on your device **without needing a Jailbreak** (for memory scanning). It runs externally to bypass sandbox limitations, giving you control over other running applications.

### ⚠️ Important Compatibility Note
*   **Memory Scanner:** Works on **ALL** devices (Jailbroken & Non-Jailbroken TrollStore users).
*   **RVA Patcher:** Requires a **Jailbroken Environment** (e.g., Dopamine, Palera1n) to function correctly.
    *   *Why?* On stock iOS (TrollStore only), **AMFI** prevents modifying executable code (`__TEXT`). Attempting to patch code without a jailbreak will cause the target app to crash immediately.

---

## 📸 Screenshots

<p align="center">
  <img src="/Sreenshots/Select.PNG" width="30%" alt="Process Select"/>
  <img src="/Sreenshots/Rva Patcher.PNG" width="30%" alt="RVA Patcher"/>
  <img src="/Sreenshots/Settings.PNG" width="30%" alt="Settings"/>
</p>

---

## 🔥 Key Features

### 1. Cross-Process RVA Patcher (Jailbreak Required)
*   **Live Offset Patch:** Input the RVA Offset (from IDA/Hopper), and the tool automatically calculates the absolute address based on the module's ASLR slide.
*   **Safety:** Handles memory permissions (`RX` -> `RWX` -> `RX`) to ensure stability on jailbroken devices.
*   **Presets:** Built-in ARM64 hex codes (RET True, NOP, etc.).

### 2. Memory Scanner (For Everyone)
*   **Data Types:** Int8, Int16, Int32, Int64, Float, Double.
*   **Search Modes:** Exact Value, Bigger, Smaller, Changed, Unchanged.
*   **Locking:** Freeze values to prevent them from changing in-game.

### 3. Process Manager
*   View all running User and System applications with icons and Bundle IDs.
*   **Attach:** Hook into any process using `task_for_pid`.
*   **Management:** Force kill or launch apps directly.

### 4. Hex Editor
*   View raw memory in Hexadecimal and ASCII.
*   Jump to specific memory addresses instantly.

### 5. Multi-Language
*   Supports English and Simplified Chinese (Auto-detects system language).

---

## ☕ Support & Donation

**VansonMod is free.** However, developing it involves a lot of effort and coffee.
If this tool helped you, please consider supporting the development! ❤️

| **Ko-fi (Global)** | **WeChat Pay (China)** |
| :---: | :---: |
| [![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/vaenshine)<br><br>Click to support via Ko-fi | <img src="/Sreenshots/wechat.png" width="200" alt="WeChat Pay"/> |

---

## 📥 Installation

1.  Download the latest `.tipa` file from [Releases](../../releases).
2.  Open and install it using **TrollStore**.
3.  Enjoy!

---

## 🤝 Credits

*   Created by **Vaenshine**
*   Special Thanks to: **Gey1ist**, **Xiczee**, **Zoomin**
*   Supported by: [iOSGods.com](https://iosgods.com/)

---

## ⚠️ Disclaimer

This tool is for **educational purposes and security research only**.
*   **Non-Commercial:** Do not use this tool for commercial gain or illegal activities.
*   **Fair Play:** Please respect game developers and other players. Do not use this tool to disrupt the fairness of online multiplayer games.
*   **Use at Your Own Risk:** The developer is not responsible for any data loss, device issues, or account bans resulting from the use of this tool.

---

## 📈 Star History

[![Star History Chart](https://api.star-history.com/svg?repos=vaenshine/VansonMod&type=Date)](https://star-history.com/#vaenshine/VansonMod&Date)

---
*Made with ❤️ by Vaenshine © 2025*
