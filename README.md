# VansonMod

<p align="center">
  <img src="https://repository-images.githubusercontent.com/1109090336/135167c3-e943-48a9-aa0d-67b3c21e844d" alt="VansonMod Social Preview" width="100%"/>
</p>

**An iOS Memory Editor & RVA Patcher for TrollStore**

[![中文说明](https://img.shields.io/badge/Lang-中文-red)](./README_CN.md)
![Platform](https://img.shields.io/badge/Platform-iOS%2014.0%2B-black)
![Support](https://img.shields.io/badge/Support-TrollStore-blue)
![License](https://img.shields.io/badge/License-MIT-green)

> **提示:** ：点击上方的「Lang 中文」徽章，可查看中文文档。

> [![Join Telegram](https://img.shields.io/badge/Join-Telegram%20Channel-blue?logo=telegram&logoWidth=20&labelColor=26A5E4&color=white)](https://t.me/VansonMod)

---

## 📖 Introduction

**VansonMod** is a standalone Root Helper tool designed specifically for the **TrollStore** environment.

Running externally via Mach Kernel APIs without code injection, it enables **memory modification without a jailbreak**. It features a powerful **Memory Modifier** (Exact/Fuzzy/Group/Nearby search, batch modification, float tolerance), **App Backup Manager** (one-click backup/restore of Documents/Library), **Smart Process Manager** (auto-detects TrollStore apps with localization support), and a professional **Hex Editor**. Additionally, for jailbroken users, it includes a **Cross-Process RVA Patcher** for live assembly instruction modification.

### ⚠️ Compatibility
*   **Memory Mod / Backup**: ✅ Supports **All Devices** (including non-jailbroken TrollStore users).
*   **RVA Patcher**: ⚠️ Requires **Jailbreak** (e.g., Dopamine, Palera1n) to function correctly.
    *   *Reason:* On non-jailbroken devices, AMFI strict code signing enforcement will cause the target app to crash immediately upon modifying the executable code segment (`__TEXT`).

---

### ✨ Core Features

*   **Memory Modifier**:
    *   **Multi-Mode Search**: Exact, Fuzzy, Group (Ordered), Mixed Mode (Refine).
    *   **Nearby Search**: Search relative to existing results with auto-deduplication.
    *   **Batch Modify**: Global/Range select, Fixed or Increment modification.
    *   **Smart Config**: Customizable Float Tolerance.
    *   **Extras**: Value freezing, infinite memory browsing.
*   **Process Manager**:
    *   **Smart Filter**: Auto-detects User/TrollStore apps, hides system daemons.
    *   **Localization**: Smartly displays localized App Names.
    *   **Control**: Attach, Kill, Launch apps.
*   **App Backup Manager**:
    *   **Backup & Restore**: One-click Documents/Library backup, multiple slots.
    *   **Native Integration**: Manage/Export/Import via iOS Files app.
*   **Cross-Process RVA Patcher (JB Only)**:
    *   **Live Patch**: Input Offset/Hex to patch running code.
    *   **Safety**: Auto-handles memory permissions, built-in presets.
*   **Hex Editor**:
    *   **Split View**: Sync Hex/ASCII display.
    *   **Edit**: Row editing and address jumping.

---

## 📸 Screenshots

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

## 📝 Changelog

### v1.9 - Added Nearby Search & Multi-mode Search Optimized Retrieval Efficiency and Batch Modification
*   **Added Nearby Search**：Scan adjacent memory of existing results to precisely locate related addresses.
*   **Fuzzy Search Speed Boost**：Fuzzy search speed boosted again, cutting retrieval time for a smoother experience.
*   **Multi-mode Hybrid Search Supported**：No longer restricted to a single search mode; freely switch modes for continued retrieval.
*   **Enhanced Combined Search**：Follows the memory sequence priority principle—mismatched condition order in memory may result in retrieval failures.
*   **Optimized Batch Modification**：Added range selection feature to freely specify modification scopes for more intuitive operations.
*   **New Settings Added**：Combined Search Range, Search Result Display Settings (for those who need to display 10 billion results, you're in luck!) & Floating-Point Error Adjustment.
*   **Improved Stability**：Fixed several known issues and improved overall app stability.

<details>
<summary>v1.80 - Theme Switch & iPad Split Screen, Search Experience Optimization</summary>

*   **Theme Mode Addition:** Added a customizable theme mode that supports switching between **Follow System | Light | Dark** modes as needed.
*   **Increment Modification Logic Fix:** Fixed the logic issue related to incremental value modification.
*   **iPad Native Split Screen Support:** Added support for iPad native split screen (compatibility unconfirmed, works properly under Stage Manager).
*   **Enter Key Trigger Search:** Implemented the function of triggering search with the Enter key for quicker operation.
*   **Search Results Serial Number Display:** Added serial number display for search results to improve readability and navigation.
*   **Lock List Enhancement & Bug Fix:** Added an independent switch for the lock list, and fixed the bug where value modification failed when the lock list was enabled.
</details>

<details>
<summary>v1.72 - Hex Editor Overhaul & Backup Management</summary>

*   **Hex Editor Overhaul:** Completely reconstructed the Hex Editor interface with a new **Split View** system (Hex Only / Split / Text Only), optimized screen real estate usage (zero margins), and improved visual alignment for better readability.
*   **Global Backup Manager:** Introduced a centralized "Backup Manager" in the App Manager tab. This allows users to view and manage all backups, including **"zombie data"** from previously uninstalled apps, facilitating easy export or deletion.
*   **Process Search:** Added a search bar to the Process Selection tab (Tab 1), enabling quick filtering of processes by Name, BundleID, or PID.
*   **Restore Workflow Optimization:** Upon a successful backup restore, the target application process is now automatically killed to ensure data consistency, removing the need for manual restarts.
*   **Popup Interaction Optimization:** Unified the operation logic of the click pop-up for memory addresses in the favorite/lock module.
</details>

### v1.71 - Fix the matching deviation of fuzzy search, optimize the algorithm, and greatly enhance both search accuracy and efficiency.

### v1.7 - Support fuzzy search and custom selection of search types

<details>
<summary>v1.6 - String Search & iPad Adaptation Optimization</summary>

*   **String Search:** Added string search function (mainly applicable to debugging scenarios).
*   **Archive Import:** Supports direct import of backup folders from the iOS "Files" App.
*   **RVA Interface Upgrade:** Displays the main program base address (supports click-to-copy), and the input box features **intelligent fault tolerance**.
*   **iPad Adaptation:** Fully adapted to iPad landscape mode and screen auto-rotation.
*   **Interaction Optimization:** Overall interaction improved with the addition of a jump menu function.
</details>

<details>
<summary>v1.5 - Advanced Search & Hex Editor 2.0</summary>

*   **Advanced Search:** Added **Fuzzy Search** (Unknown Initial Value -> Increased/Decreased) and **Group Search** (e.g., `500,1000`).
*   **Batch Modify:** Support modifying all results with a **Fixed Value** or **Increment Value**.
*   **Hex Editor 2.0:** Completely redesigned with Split View (Hex/ASCII), synchronized scrolling, and a new Row Editor.
*   **App Data Manager:** Switched to folder-based backups for better stability and native Files app integration.
*   **Process List:** Smart filtering (auto-hides system processes) and added App Version display.
*   **UX:** Added Refresh buttons in Modifier and Memory Browser; Fixed Settings input bugs.
</details>

<details>
<summary>v1.4 - Save Manager & Optimizations</summary>

*   **New Feature:** Added Backup/Restore functionality for App Data.
*   **New Feature:** Added "Check for Updates" in Settings.
*   **Optimization:** Improved process classification logic.
*   **Fix:** Resolved an issue where process filtering would fail.
*   **Stability:** Enhanced overall stability and fixed various crashes.
</details>

<details>
<summary>v1.3 - Stability & Feature Expansion</summary>

*   **Stability:** Enhanced app stability and resolved crash issues.
*   **Process Filtering:** Added filtering to exclude system processes/widgets.
*   **Modifier:** Optimized the Modifier module and added a refresh function.
*   **New Feature:** Memory Browser (Value) for intuitive viewing.
</details>

<details>
<summary>v1.2 - Feature Enhancement & UI/UX</summary>

*   **Hex Editor:** Added inline editing (Row Editor) with real-time preview.
*   **UI Optimization:** Refined interface design.
*   **Favorites:** Added a dedicated button and management features (Edit Note/Delete).
*   **Fix:** Resolved specific crash issues.
</details>

<details>
<summary>v1.1 - Safety Update</summary>
*   **RVA Safety Check:** Added environment detection. Warns non-jailbroken users before patching to prevent AMFI-caused crashes.
*   **Optimization:** Improved stability during process switching.
</details>

<details>
<summary>v1.0 - Initial Release</summary>
*   First public release for TrollStore.
*   Basic Memory Scanner, RVA Patcher, Process Manager, and Hex Editor.
</details>

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

This tool is intended **solely for security research and reverse engineering learning purposes**. Please read the following terms carefully before use; use of this tool shall be deemed as acceptance of all the terms below:

*   **Non-profit and Compliance:** It is strictly prohibited to use this tool for commercial profit, illegal intrusion, data theft, or any other acts that violate laws, regulations, or platform rules. Use is limited to legitimate learning and research scenarios only.
*   **Fairness and Respect Principle:** Please respect the intellectual property rights of application/game developers and the legitimate rights and interests of other users. Do not use this tool for malicious purposes such as disrupting the normal operation of applications, tampering with data, or undermining the fairness of use.
*   **Risk Assumption:** Users shall independently assess the relevant risks of using this tool. The developer shall not be liable for any direct or indirect liabilities arising from data loss, device damage, account suspension, or legal liabilities caused by unauthorized use, improper operation, or other reasons.

---

## ☕ Support & Donation

**VansonMod is free.** However, developing it involves a lot of effort and coffee.
If this tool helped you, please consider supporting the development! ❤️

| **Ko-fi (Global)** | **WeChat Pay (China)** |
| :---: | :---: |
| [![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/vaenshine)<br><br>Click to support via Ko-fi | <img src="/Screenshots/wechat.png" width="200" alt="WeChat Pay"/> |

---

## 📈 Star History

[![Star History Chart](https://api.star-history.com/svg?repos=vaenshine/VansonMod&type=Date)](https://star-history.com/#vaenshine/VansonMod&Date)

---
