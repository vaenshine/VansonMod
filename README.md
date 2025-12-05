# VansonMod

<p align="center">
  <img src="https://repository-images.githubusercontent.com/1109090336/135167c3-e943-48a9-aa0d-67b3c21e844d" alt="VansonMod Social Preview" width="100%"/>
</p>

**An iOS Memory Editor & RVA Patcher for TrollStore**

[![中文说明](https://img.shields.io/badge/Lang-中文-red)](./README_CN.md)
![Platform](https://img.shields.io/badge/Platform-iOS%2014.0%2B-black)
![Support](https://img.shields.io/badge/Support-TrollStore-blue)
![License](https://img.shields.io/badge/License-MIT-green)

> **注意:** ：点击上方的「中文说明」徽章，可查看中文文档。

---

## 📖 Introduction

**VansonMod** is a standalone Root Helper utility developed for the **TrollStore** environment.

It allows you to modify game values (Health, Gold, etc.), manage app data, and patch assembly instructions (RVA) directly on your device. Unlike traditional tweaks that rely on code injection, VansonMod runs externally using Mach Kernel APIs to manipulate other running processes.

### ⚠️ Compatibility Note
*   **Memory Scanner / Data Manager:** Works on **ALL** devices (Jailbroken & Non-Jailbroken TrollStore users).
*   **RVA Patcher:** Requires a **Jailbroken Environment** (e.g., Dopamine, Palera1n).
    *   *Reason:* On stock iOS (TrollStore only), **AMFI** strictly enforces code signatures. Modifying executable code (`__TEXT`) without a jailbreak will cause the target app to crash.

---

## 📸 Screenshots

<p align="center">
  <img src="/Sreenshots/Select.PNG" width="30%" alt="Process Select"/>
  <img src="/Sreenshots/Modifier.PNG" width="30%" alt="Modifier"/>
  <img src="/Sreenshots/HexEditor.PNG" width="30%" alt="HexEditor"/>
</p>
<p align="center">
  <img src="/Sreenshots/RowEditor.PNG" width="30%" alt="RowEditor"/>
  <img src="/Sreenshots/Rva Patcher.PNG" width="30%" alt="RVA Patcher"/>
  <img src="/Sreenshots/Settings.PNG" width="30%" alt="Settings"/>
</p>

---

## ✨ Features

### 1. Memory Scanner
A standard memory scanning tool.
*   **Data Types:** Supports Int8, Int16, Int32, Int64, Float, and Double.
*   **Search Modes:** Exact Value, Bigger, Smaller, Changed, Unchanged.
*   **Locking:** Freeze values to prevent them from changing (Supports background locking).
*   **Memory Browser:** View and edit nearby memory values intuitively.

### 2. Cross-Process RVA Patcher (Jailbreak Required)
Modify assembly instructions of running apps.
*   **Live Offset Patch:** Input the RVA Offset (from IDA/Hopper), and the tool calculates the absolute address based on the module's ASLR slide.
*   **Safety:** Handles memory permissions (`RX` -> `RWX` -> `RX`) to ensure stability.
*   **Presets:** Built-in common ARM64 hex codes.

### 3. App Data Manager (New)
*   **Backup/Restore:** Easily backup app data (Documents/Library) and restore it later.
*   **Export/Import:** Share backups or import external saves via the native iOS Files app.

### 4. Process Manager
*   View running User and System applications with icons.
*   **Filter:** Automatically hides system extensions and widgets for a cleaner view.
*   **Control:** Attach to, Kill, or Launch apps directly.

### 5. Hex Editor
*   View raw memory in Hexadecimal and ASCII.
*   **Row Editor:** Real-time editing with split views.
*   **Navigation:** Infinite scrolling and jump to address.

---

## 📝 Changelog

### v1.4 - Save Manager & Optimizations
*   **New Feature:** Added Backup/Restore functionality for App Data.
*   **New Feature:** Added "Check for Updates" in Settings.
*   **Optimization:** Improved process classification logic.
*   **Fix:** Resolved an issue where process filtering would fail.
*   **Stability:** Enhanced overall stability and fixed various crashes.

### v1.3 - Stability & Feature Expansion
*   **Stability:** Enhanced app stability and resolved crash issues.
*   **Process Filtering:** Added filtering to exclude system processes/widgets.
*   **Modifier:** Optimized the Modifier module and added a refresh function.
*   **New Feature:** Memory Browser (Value) for intuitive viewing.

### v1.2 - Feature Enhancement & UI/UX
*   **Hex Editor:** Added inline editing (Row Editor) with real-time preview.
*   **UI Optimization:** Refined interface design.
*   **Favorites:** Added a dedicated button and management features (Edit Note/Delete).
*   **Fix:** Resolved specific crash issues.

### v1.1 - Safety Update
*   **RVA Safety Check:** Added environment detection. Warns non-jailbroken users before patching to prevent AMFI-caused crashes.
*   **Optimization:** Improved stability during process switching.

### v1.0 - Initial Release
*   First public release for TrollStore.
*   Basic Memory Scanner, RVA Patcher, Process Manager, and Hex Editor.

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
*   **Fair Play:** Please respect game developers. Do not use this tool to disrupt online multiplayer games.
*   **Risk:** The developer is not responsible for any data loss, device issues, or bans resulting from the use of this tool.

---

## ☕ Support & Donation

**VansonMod is free.** If this tool helped you, please consider supporting the development! ❤️

| **Ko-fi (Global)** | **WeChat Pay (China)** |
| :---: | :---: |
| [![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/vaenshine)<br><br>Click to support via Ko-fi | <img src="/Sreenshots/wechat.png" width="200" alt="WeChat Pay"/> |

---

## 📈 Star History

[![Star History Chart](https://api.star-history.com/svg?repos=vaenshine/VansonMod&type=Date)](https://star-history.com/#vaenshine/VansonMod&Date)

---
*Made with ❤️ by Vaenshine © 2025*
