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

### ✨ Core Features
*   **Pointer Debugging**:
    *   Supports **manual & automatic dual-mode pointer scanning**, paired with a dedicated **pointer verification feature** to accurately validate pointer validity and eliminate invalid results.
    *   Enables one-click **import & export** of pointer addresses, allowing debugging results to be reused across devices and greatly improving debugging efficiency.
    *   New pointer-specific configuration switch for **manual fine-tuning** of automatic scanning rules, perfectly catering to advanced in-depth debugging needs.
    *   Pointer Lock, Memory Lock and Favorites are **integrated into a single Tab page**, providing one-click access to core pointer operations without page switching.
*   **Memory Debugger**:
    *   Multi-mode scanning: Exact, Fuzzy, Combined (high-performance ordered), Hybrid (secondary filtering) with fully optimized retrieval efficiency.
    *   New **Precise Value Filter**: Supports greater than, less than and range filtering modes to accurately locate target memory data for more efficient debugging.
    *   Neighbor Scan: Scans adjacent memory data based on existing results with automatic deduplication for fast correlation of related addresses.
    *   Batch Debugging: Full/range selection modification, fixed/incremental value modification, value locking and infinite scroll memory browsing are fully supported.
    *   Smart Configuration: Customizable Float Tolerance to adapt to parameter requirements of various debugging scenarios.
*   **Process & App Management**:
    *   Smart Filtering: Automatically identifies user & TrollStore apps, hides system processes, and supports quick filtering by name/BundleID/PID.
    *   Multi-language Support: Intelligently displays localized app names and version numbers, compatible with all language devices.
    *   Layout Optimization: **App Management entry moved to the top of Process Management** for centralized core operations without hierarchical navigation.
    *   Interaction Upgrade: Removed refresh icons, unified **pull-to-refresh** for App Management, Process Selection, Pointer Lock and RVA Management modules for smooth operation.
*   **App Archive Management**:
    *   One-click Backup/Restore: Complete backup of Documents/Library directories with multi-archive support; automatically terminates target processes for instant effect after restoration.
    *   Native Integration: Direct connection with the system Files App, supporting import/export of backup files, unified viewing of global backups and cleanup of zombie archives.
*   **🔧 Cross-process RVA Debugging Suite (Jailbreak Required) [Fully Upgraded]**:
    *   Real-time Debugging: Automatically patches running code with Offset and Hex input, handles memory permissions automatically and built-in common instruction presets.
    *   New **RVA Debug Record Management Module**: One-click save, fast import/export of debugging records for efficient retention of core debugging data and batch management support.
*   **Hex Editor**:
    *   Multi-view Switching: Hex/ASCII split-screen sync display, free switch between Hex-only/Text-only views with zero-margin visual alignment for different debugging habits.
    *   Efficient Editing: Line editing, fast address jump and synchronous scrolling, fixed page turning lag issues with maximized operation smoothness.
*   **Personalization & Experience Optimization**:
    *   Icon Customization: New **multiple app icons for free switching** to change styles and add fun to usage.
    *   Theme Adaptation: Supports System/Follow, Light and Dark three theme modes for all display preferences.
    *   iPad Exclusive: **Native iPad split-screen perfectly supported**, with screen auto-rotation and Stage Manager mode stable operation.
    *   Stability Improvement: Fixed known bugs such as memory browsing lag and value modification failure, greatly optimized overall operational stability.

---

## 📸 Screenshots

<p align="center">
  <img src="/Screenshots/APP_SELECT.PNG" width="30%" alt="APP_SELECT"/>
  <img src="/Screenshots/MEM_BROWSER.PNG" width="30%" alt="MEM_BROWSER"/>
  <img src="/Screenshots/MEM_DEBUG.PNG" width="30%" alt="MEM_DEBUG"/>
  <img src="/Screenshots/MEM_HEX_MIX.PNG" width="30%" alt="MEM_HEX_MIX"/>
</p>
<p align="center">
  <img src="/Screenshots/RVA_MANAGER.PNG" width="30%" alt="RVA_MANAGER"/>
  <img src="/Screenshots/POINTER_ANALYSIS.PNG" width="30%" alt="POINTER_ANALYSIS"/>
  <img src="/Screenshots/POINTER_VERIFY.PNG" width="30%" alt="POINTER_VERIFY"/>
  <img src="/Screenshots/POINTER_LOCKER.PNG" width="30%" alt="POINTER_LOCKER"/>
</p>

---

## ✨ What's New in v2.0
- Added Pointer Scanning feature with manual & automatic dual modes, paired with pointer verification, and supports one-click import & export of pointers for greatly improved debugging efficiency;
- Added RVA Management Module with upgraded RVA debugging features, enabling convenient saving, fast import & export of RVA debugging records for efficient retention of core data;
- Added Value Filter feature that supports greater than, less than and range filtering to accurately locate target data for more precise and efficient debugging;
- Added native iPad split-screen experience with perfect adaptation to tablet operation habits;
- Added App Icon Customization with multiple new icons for free style switching to enhance user experience;
- New pointer configuration switch in Settings for manual fine-tuning of automatic pointer scanning rules to meet advanced debugging needs;
- Optimized interface layout: moved App Management entry to the top of Process Management, and integrated Pointer Lock, Memory Lock and Favorites into a single Tab page for centralized core functions and easier access;
- Optimized interaction: removed refresh icons for App Management, Process Selection, Pointer Lock and RVA Management modules, unified with pull-to-refresh for smoother operation;
- Fixed memory browsing page turning lag bug to ensure smooth operation;
- Optimized overall performance and fixed numerous known bugs to significantly improve app stability;

---

## 📝 Changelog (Historical Versions)

<details>
<summary>v1.9 - Added Neighbor Scan & Multi-mode Scanning, Optimized Retrieval Efficiency & Batch Modification</summary>
*   Added Neighbor Scan feature to scan adjacent memory data based on existing results for accurate location of related addresses;
*   Fuzzy scan efficiency greatly improved with significantly reduced retrieval time for smoother experience;
*   Supported hybrid multi-mode scanning with free switch between modes for continuous retrieval;
*   Enhanced Combined Scan with strict memory order compliance (incorrect order may lead to no results);
*   Optimized batch modification logic with new range selection for flexible modification scope;
*   New Settings options: Combined scan range, search result display configuration and Float Tolerance adjustment;
*   Stability improvement with fixed known issues and enhanced overall app stability.
</details>

<details>
<summary>v1.80 - Added Theme Switch & iPad Split-Screen, Optimized Search Experience & Bug Fixes</summary>
*   Added theme switch with three modes: Follow System, Light and Dark;
*   Fixed incremental modification logic error for accurate value adjustment;
*   Added preliminary iPad split-screen support (compatibility in testing, stable with Stage Manager);
*   Added Enter key shortcut to trigger search for improved operation efficiency;
*   Added serial number display for search results for quick location;
*   Optimized Lock List with independent switch and fixed value modification failure bug in locked state.
</details>

<details>
<summary>v1.72 - Hex Editor Restructure & Backup Management Enhancement</summary>
*   Fully restructured Hex Editor with three view modes: Hex-only, Split-screen and Text-only, optimized layout ratio and line height for zero-margin perfect alignment;
*   New Global Backup Management entry in App Manager for unified viewing of all backup files, including zombie archives of uninstalled apps (export/cleanup supported);
*   Enhanced Process Search with a new search bar in Process Tab for fast filtering by app name/BundleID/PID;
*   Optimized restore process with automatic target process termination for instant effect without manual restart;
*   Unified pop-up interaction logic for memory address clicks in Favorites/Lock modules.
</details>

### v1.71 - Fixed Fuzzy Scan Matching Deviation, Optimized Core Algorithm for Higher Efficiency & Accuracy
### v1.7 - Added Fuzzy Scan Type Selection

<details>
<summary>v1.6 - Added String Search & iPad Adaptation Optimization</summary>
*   Added String Search feature (mainly for professional debugging scenarios);
*   Supported direct backup folder import from iOS Files App;
*   Upgraded RVA interface with display and one-click copy of main module base address, added smart error tolerance for input boxes;
*   Full iPad landscape & auto-rotation support for perfect tablet adaptation;
*   Overall interaction optimization with new jump menu for fast function access.
</details>

<details>
<summary>v1.5 - Advanced Search & Hex Editor 2.0</summary>
*   Added Advanced Search: Fuzzy Scan (Unknown initial value → Increase/Decrease) and Combined Scan (e.g., `500,1000`);
*   Supported batch modification with fixed/incremental value for all search results;
*   Fully rebuilt Hex Editor 2.0 with split-screen Hex/ASCII sync scrolling and independent line editing;
*   Optimized archive management with folder direct copy for higher stability, fully integrated with iOS Files App;
*   Smart process list with com.apple system process filtering and app version display;
*   UX improvement with refresh buttons in Memory Debugger/Browser and fixed Settings input box bugs.
</details>

<details>
<summary>v1.4 - Added Archive Management & Overall Optimization</summary>
*   New App Archive Backup & Restore feature for full data protection;
*   Added Check for Updates function for timely version upgrade;
*   Optimized process classification logic for clearer app sorting;
*   Fixed process filtering failure bug for accurate user/system app separation;
*   Enhanced stability with crash fixes and smoother operation.
</details>

<details>
<summary>v1.3 - Stability Improvement & Feature Expansion</summary>
*   Significantly improved overall stability with critical crash fixes;
*   Added process filter to exclude system processes and plugins/components;
*   Optimized Memory Debugger with refresh button for real-time value viewing;
*   New Memory Browser feature for intuitive memory data list display.
</details>

<details>
<summary>v1.2 - Feature Enhancement & UI/UX Optimization</summary>
*   Upgraded Hex Editor with inline editing and real-time Hex/ASCII preview;
*   Minor UI adjustments for better visual experience;
*   Fixed specific crash issues for stable operation;
*   Added independent Favorites entry with note/delete management features.
</details>

<details>
<summary>v1.1 - Security Update</summary>
*   Added RVA environment detection with warning pop-up on non-jailbroken devices to prevent crash from incorrect operation;
*   Optimized process switching stability for seamless app debugging.
</details>

<details>
<summary>v1.0 - Initial Release</summary>
*   The first independent memory tool supporting TrollStore without jailbreak;
*   Core features: Memory Scanning, RVA Modification, Process Management, Hex Editing and multi-language support.
</details>

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