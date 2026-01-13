# VansonMod

<p align="center">
  <img src="https://repository-images.githubusercontent.com/1109090336/135167c3-e943-48a9-aa0d-67b3c21e844d" alt="VansonMod Social Preview" width="100%"/>
</p>

**iOS Memory Debugger & RVA Debugging Tool exclusively for TrollStore**

[![Chinese Readme](https://img.shields.io/badge/语言-简体中文-blue)](./README_CN.md)
![Platform](https://img.shields.io/badge/Platform-iOS%2014.0%2B-black)
![Support](https://img.shields.io/badge/Support-TrollStore-blue)
![License](https://img.shields.io/badge/License-MIT-green)

> **提示:** ：点击上方的「Lang 中文」徽章，可查看中文文档。

> [![Join Telegram](https://img.shields.io/badge/Join-Telegram%20Channel-blue?logo=telegram&logoWidth=20&labelColor=26A5E4&color=white)](https://t.me/VansonMod)

---

## 📖 Introduction

**VansonMod** is an independent Root Helper tool designed exclusively for the **TrollStore** environment.

Unlike traditional jailbreak tweaks, it runs externally using Mach kernel APIs without code injection, enabling **memory debugging features to work without a jailbroken environment**. It integrates a powerful memory debugger, app archive manager, intelligent process manager, professional Hex editor, and a comprehensive cross-process RVA debugging suite for jailbroken users. Fully compatible with all iOS device sizes and natively supporting iPad split-screen, it features a consolidated layout and optimized interaction design, delivering top-tier debugging efficiency and stability as a professional iOS app debugging tool.

### ⚠️ Compatibility Notes
*   **Memory Debugging / Full Pointer Features / Archive Management / iPad Split-Screen / Icon Customization**: ✅ Supported on **all** devices (including non-jailbroken TrollStore users).
*   **RVA Patcher (Assembly Debugging) / RVA Debug Record Management**: ⚠️ Requires a **jailbroken environment** (e.g., Dopamine, Palera1n) to function properly.
    *   *Reason:* On non-jailbroken devices, the system AMFI mechanism strictly enforces code signature verification. Direct modification of the executable text segment (`__TEXT`) will cause the target app to crash immediately.

---

### Core Features
1.  **Pointer Debugging**
    - Supports both manual and automatic pointer search modes, paired with an exclusive pointer verification feature to accurately validate pointer validity.
    - Enables one-click import/export of pointer addresses, allowing debugging results to be reused across devices.
    - Offers exclusive pointer configuration switches, supporting manual fine-tuning of automatic search rules to meet the in-depth debugging needs of advanced users.
    - Combines pointer locking, memory locking, and favorites into a single tab page for one-click access to core pointer operations.
    - The pointer verification main interface features a data type selector (covering types from I8 to F64).
    - After successful pointer verification, silent saving is supported, which automatically filters valid pointers and saves them as a new pointer verification file.

2.  **Memory Debugger**
    - Covers multiple search modes including exact, fuzzy, joint (high-performance ordered), and hybrid (secondary filtering) to optimize retrieval efficiency.
    - Supports precise numerical filtering with three modes: greater than, less than, and range filtering, for accurate positioning of target memory data.
    - Offers adjacent search, which scans nearby memory data based on existing results and automatically removes duplicates to quickly associate relevant addresses.
    - Enables batch debugging with features including select all/range selection modification, fixed value/incremental modification, numerical locking, and infinite scrolling memory browsing; also supports batch locking, batch favoriting, and batch deletion.
    - Allows custom Float Tolerance to adapt to parameter requirements of various debugging scenarios.
    - Enhances fuzzy search with options such as "Value has increased by..." and "Value has decreased by...", where specific changed values can be entered.

3.  **Process and Application Management**
    - Supports intelligent filtering, automatically identifying user and TrollStore applications, hiding system processes, and enabling quick filtering by name/BundleID/PID.
    - Offers multi-language adaptation, intelligently displaying the localized App name and showing the application version number.
    - The APP management entry is migrated to the top of the process management interface for centralized core operations.

4.  **Application Archive Management**
    - Enables one-click backup/restore, fully backing up the Documents/Library directories, supporting multiple archives, and automatically terminating the target process for immediate effect after restoration.
    - Natively integrates with the system "Files" App, allowing direct management of backup file import and export, as well as unified global backup viewing and zombie archive cleanup.

5.  **Cross-Process RVA Debugging Suite (Jailbreak Required)**
    - Supports real-time debugging: entering Offset and Hex automatically patches running code, automatically handles memory permissions, and has built-in presets for commonly used instructions.
    - Includes an RVA debugging record management module, enabling one-click saving, quick import/export of debugging records, and batch management of multiple records.
    - Fixes the deletion function and resolves the issue of data duplicate stacking caused by pull-to-refresh.

6.  **Hex Editor**
    - Supports multi-view switching, including Hex/ASCII synchronous split screen, Hex-only/text-only views, with zero-margin visual alignment to adapt to different debugging habits.
    - Enables efficient editing with features including line editing, quick address jump, and synchronous scrolling.

7.  **Personalization and Experience Optimization**
    - Supports icon customization with a variety of APP icons for users to switch freely.
    - Offers theme adaptation with three theme modes: follow system/light/dark.
    - Natively adapts to iPad split screen, supporting automatic screen rotation and Stage Manager mode.
    - Enables landscape operation, unlocking App rotation restrictions to adapt to iPad/iPhone landscape orientation; switching back to VM in landscape mode maintains landscape display.

---

## 📸 Screenshots

| <div align="center"><img src="/Screenshots/APP_SELECT.PNG" width="100%" alt="APP_SELECT"/></div> | <div align="center"><img src="/Screenshots/MEM_BROWSER.PNG" width="100%" alt="MEM_BROWSER"/></div> | <div align="center"><img src="/Screenshots/MEM_DEBUG.PNG" width="100%" alt="MEM_DEBUG"/></div> | <div align="center"><img src="/Screenshots/MEM_HEX_MIX.PNG" width="100%" alt="MEM_HEX_MIX"/></div> |
| :----------------------------------------------------------------------------------------------: | :------------------------------------------------------------------------------------------------: | :------------------------------------------------------------------------------------------------: | :-------------------------------------------------------------------------------------------------: |
| <div align="center"><img src="/Screenshots/RVA_MANAGER.PNG" width="100%" alt="RVA_MANAGER"/></div> | <div align="center"><img src="/Screenshots/POINTER_ANALYSIS.PNG" width="100%" alt="POINTER_ANALYSIS"/></div> | <div align="center"><img src="/Screenshots/POINTER_VERIFY.PNG" width="100%" alt="POINTER_VERIFY"/></div> | <div align="center"><img src="/Screenshots/POINTER_LOCKER.PNG" width="100%" alt="POINTER_LOCKER"/></div> |

---

## 📝 Historical Changelog

View the [Releases](../../releases) ChangeLog.

---

## 📥 Installation
1. Download the latest `.tipa` file from the [Releases](../../releases) page;
2. Install via **TrollStore**;
3. Launch the app and start debugging.

---

## 🤝 Credits
*   Developer: **Vaenshine**
*   Special Thanks: **Gey1ist**, **Xiczee**, **Zoomin**
*   Community Support: [iOSGods.com](https://iosgods.com/)

---

## ⚠️ Disclaimer
This tool is for **security research and reverse engineering learning only**. Please read the following terms carefully before use, and your use of the tool shall be deemed as acceptance of all terms:
*   This tool is a free closed-source project, intended solely for security research, reverse engineering learning and compliance technical scenario testing, and must be uninstalled within 24 hours after use;
*   This tool is a general technical debugging tool that does not provide targeted functions, debugging methods or exclusive adaptation for any application, with no preset debugging targets or customized operation schemes;
*   It is strictly prohibited to use this tool for commercial profit, undermining the fairness of application operation, illegally intruding into others' systems, stealing data, or any other acts that violate national laws, regulations and public order and good morals;
*   All operations performed using this tool are independently made by the user. All risks such as target application crash, data damage or loss, account restriction or ban, and device abnormality that may arise during the operation, as well as all direct and indirect losses and legal liabilities resulting therefrom, shall be borne solely by the user.

---

## 📢 Important Statement
This is a free closed-source project, **we do not accept donations in any form**. All development work is driven by technical research and communication purposes only.

---

## 📈 Star History
[![Star History Chart](https://api.star-history.com/svg?repos=vaenshine/VansonMod&type=Date)](https://star-history.com/#vaenshine/VansonMod&Date)
