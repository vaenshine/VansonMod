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

### v2.2 - Function Upgrade & Experience Optimization
- New Signature Code Function: The signature code function is newly launched to help locate and analyze memory data more accurately.
- Significant Upgrade of Pointer Search Performance: The speed and accuracy of pointer search are fully optimized, achieving a qualitative leap compared with the initial version of V2.0.
- Comprehensive Upgrade of Joint Search: Multiple new input methods are added, and the anchor radiation function is introduced at the same time, which can display special numbers first. Combined with the improved search speed, the retrieval efficiency is greatly improved.
- Full Restructuring of Memory Debugging Tab UI: Optimize the interface layout and interaction logic to bring a smoother debugging experience; meanwhile, the range search function of V1.9 is returned to the batch selection module, and a floating toolbar for batch selection is added for more convenient operation.
- Experience Optimization of RVA Debugging Page: Reconstruct the RVA debugging page, optimize the framework selection logic, make the interface layout more loose and reasonable, and the operation space more comfortable.
- Optimization of Menu Function Structure: Remove the pointer debugging option in the original menu and integrate the toolbox function into this position; the toolbox now centrally manages all saved data for unified viewing and calling. Note: The entry for pointer and signature code related functions can only be accessed by jumping from the memory address.
- Enhancement of Search Results and Browsing Functions: Optimize the jump function of search results, add memory browsing and hexadecimal (Hex) browsing record marks, making the browsing track clear at a glance, so there is no need to manually distinguish which ones have been viewed or not.
- Fix the Problem of Random Page Jumping in Memory Browsing: Special repair for the problem of random page jumping during memory browsing, please experience and verify the specific effect by yourself.

<details>
<summary>v2.1 - Core Architecture Fixes & Multi-Module Experience Optimization</summary>
<ul>
  <li><strong>Core & Stability</strong>: Resolved data crossover issue between <strong>Memory Debugging</strong> and <strong>Pointer Search</strong>.</li>
  <li><strong>Modifier (Memory Debugger)</strong>: 
    <ul>
      <li>Enhanced Fuzzy Search: Added "Value has increased by..." and "Value has decreased by..." search options, supporting input of specific changed values.</li>
      <li>Optimized Batch Operations: Added batch lock, batch favorite, and batch delete functions.</li>
      <li>UI Enhancement: Replaced text labels with icons in "Batch Selection" mode to save space (Select All/Inverse, Favorite, Lock, Modify, Delete).</li>
      <li>Improved Reset Experience: Clicking reset only clears search data while retaining search mode (Exact/Fuzzy) and data type selection, improving continuous debugging efficiency.</li>
    </ul>
  </li>
  <li><strong>Patcher (RVA Debugging)</strong>: Fixed the delete function and resolved data duplication caused by pull-to-refresh.</li>
  <li><strong>Verifier (Pointer Validator)</strong>: 
    <ul>
      <li>Data Type Selection Support: Added a data type selector on the main interface (covering types from I8 to F64).</li>
      <li>Silent Save Function: After successful pointer verification, valid pointers are automatically filtered and saved as a new pointer verification file for easy progress tracking.</li>
    </ul>
  </li>
  <li><strong>Pointer Search</strong>: Fixed navigation issues in manual pointer search, resolving unresponsive UI, inability to return from multi-level (Lv2+) pages, and non-clickable buttons.</li>
  <li><strong>General Optimizations</strong>: 
    <ul>
      <li>Landscape Mode Support: Unlocked App rotation restrictions, perfectly adapting to iPad/iPhone landscape operation; Maintains landscape display when switching back to VM in landscape mode.</li>
      <li>Interaction Refinements: Added "Edit Note" function for address locking and memory locking; Added empty selection prompts for batch operation scenarios.</li>
    </ul>
  </li>
</ul>
</details>

<details>
<summary>v2.0 - New Pointer Search & RVA Management, Optimized Tablet Adaptation and Core Experience</summary>
<ul>
  <li><strong>New Pointer Search Feature</strong>: Supports manual and automatic search modes, paired with pointer verification, and supports pointer import/export for greatly improved debugging efficiency.</li>
  <li><strong>New RVA Management Module</strong>: RVA debugging function upgraded synchronously, enabling convenient saving of RVA debugging records, supporting fast import/export of records for efficient retention of core debugging data.</li>
  <li><strong>New Numerical Filtering Function</strong>: Supports greater than, less than, and range filtering to accurately locate target data for more precise debugging.</li>
  <li><strong>Native iPad Split Screen Support</strong>: Perfectly adapts to tablet device operation habits.</li>
  <li><strong>New App Icon Customization</strong>: Launched multiple new icons for free style switching to add fun and fresh experience.</li>
  <li><strong>New Pointer Configuration Switch in Settings</strong>: Allows manual parameter adjustment for automatic pointer search to meet advanced users' precise debugging needs.</li>
  <li><strong>Optimized Interface Layout</strong>: Moved the APP management entry to the top of process management; Integrated pointer locking, memory locking, and favorites into a single tab page for centralized core functions and easier access.</li>
  <li><strong>Optimized Interaction</strong>: Removed refresh icons from four core modules (APP Management, Process Selection, Pointer Locking, RVA Management) and unified with pull-to-refresh for smoother operation.</li>
  <li><strong>Bug Fixes</strong>: Fixed memory browser page turning freeze issue to ensure smooth operation flow.</li>
  <li><strong>Optimized Runtime Experience</strong>: Fixed numerous known bugs and comprehensively improved overall software stability.</li>
</ul>
</details>

<details>
<summary>v1.9 - New Adjacent Search & Multi-Mode Search, Optimized Retrieval Efficiency and Batch Modification</summary>
<ul>
  <li><strong>New Adjacent Search Feature</strong>: Scans nearby memory data based on existing results to accurately locate associated addresses.</li>
  <li><strong>Improved Fuzzy Search Efficiency</strong>: Fuzzy search speed increased significantly, greatly reducing retrieval time for smoother experience.</li>
  <li><strong>Multi-Mode Hybrid Search Support</strong>: No longer restricted to single search mode; Allows free switching between modes for continuous retrieval.</li>
  <li><strong>Enhanced Joint Search Function</strong>: Requires sequential memory search principle; Mismatched condition order in memory may result in no retrieval results.</li>
  <li><strong>Optimized Batch Modification Logic</strong>: Added range selection function to support free modification range setting for easier operation.</li>
  <li><strong>New Settings Configuration</strong>: Includes joint search range, search result display settings, and float tolerance adjustment.</li>
  <li><strong>Stability Improvement</strong>: Fixed several known issues and improved overall application stability.</li>
</ul>
</details>

<details>
<summary>v1.80 - New Theme Switching & iPad Split Screen, Optimized Search Experience and Bug Fixes</summary>
<ul>
  <li><strong>New Theme Switching Mode</strong>: Supports free theme switching with three options: <strong>Follow System | Light | Dark</strong>.</li>
  <li><strong>Fixed Incremental Modification Logic</strong>: Corrected logical errors in the value incremental modification function.</li>
  <li><strong>Native iPad Split Screen Support</strong>: Added native iPad split screen compatibility (compatibility pending verification; Works normally in Stage Manager mode).</li>
  <li><strong>Enter Key Search Trigger</strong>: Added shortcut search trigger via Enter key to improve operation efficiency.</li>
  <li><strong>Search Result Numbering</strong>: Added sequence number labels for search results to facilitate quick content positioning.</li>
  <li><strong>Lock List Optimization & Bug Fixes</strong>: Added independent toggle for lock list and fixed ineffective value modification issue when enabled.</li>
</ul>
</details>

<details>
<summary>v1.72 - Hex Interface Restructuring & Backup Management Enhancement</summary>
<ul>
  <li><strong>Hex Interface Restructuring</strong>: Fully redesigned Hex Editor supporting three view modes: <strong>Hex Only / Split Screen / Text Only</strong>. Deeply optimized layout ratio and line height to achieve zero-margin display and perfect visual alignment.</li>
  <li><strong>Global Backup Management</strong>: Added <strong>Backup Management</strong> entry in App Management for unified viewing of all backup files on the device. Even "zombie archives" from uninstalled apps can be found, exported, or cleaned here.</li>
  <li><strong>Enhanced Process Search</strong>: Added search bar on the process selection page (Tab 1) to support quick filtering of target processes by App name, BundleID, or PID.</li>
  <li><strong>Optimized Restore Process</strong>: After successful archive restoration, the tool automatically terminates the target app process for immediate effect without manual restart.</li>
  <li><strong>Popup Interaction Optimization</strong>: Unified operation logic of pop-up windows triggered by memory address clicks in the Favorite/Lock modules.</li>
</ul>
</details>

<details>
<summary>v1.71 - Fixed Fuzzy Search Matching Deviation, Optimized Core Algorithm</summary>
<ul>
  <li>Fixed fuzzy search matching deviation issue and optimized core algorithm to significantly improve search efficiency and accuracy.</li>
</ul>
</details>

<details>
<summary>v1.7 - Added Fuzzy Search Type Selection</summary>
<ul>
  <li>Added custom type selection for fuzzy search to improve search flexibility.</li>
</ul>
</details>

<details>
<summary>v1.6 - String Search & iPad Adaptation Optimization</summary>
<ul>
  <li><strong>String Search</strong>: Added string search function (mainly applicable to debugging scenarios).</li>
  <li><strong>Archive Import</strong>: Supports direct import of backup folders from iOS "Files" App.</li>
  <li><strong>RVA Interface Upgrade</strong>: Displays main program base address (supports one-click copy); Added <strong>intelligent error tolerance mechanism</strong> to input fields.</li>
  <li><strong>iPad Adaptation</strong>: Fully adapted to iPad landscape display mode and automatic screen rotation.</li>
  <li><strong>Interaction Experience</strong>: Comprehensive interaction optimization with new jump menu function added.</li>
</ul>
</details>

<details>
<summary>v1.5 - Advanced Search & Hex Editor 2.0</summary>
<ul>
  <li><strong>Advanced Search</strong>: Added <strong>Fuzzy Search</strong> (unknown initial value -> increased/decreased) and <strong>Joint Search</strong> (e.g., `500,1000`).</li>
  <li><strong>Batch Modification</strong>: Supports modifying search results to <strong>fixed values</strong> or <strong>incremental values</strong>.</li>
  <li><strong>Hex Editor 2.0</strong>: Fully restructured with support for split-screen (Hex/ASCII) synchronous scrolling and independent line editing.</li>
  <li><strong>Archive Management</strong>: Adopted folder direct copy scheme for higher stability; Supports direct backup management in system "Files" App.</li>
  <li><strong>Process List</strong>: Intelligently filters system processes (com.apple) and added app version number display.</li>
  <li><strong>Experience Optimization</strong>: Added refresh buttons to modifier and memory browser; Fixed input field bugs in settings page.</li>
</ul>
</details>

<details>
<summary>v1.4 - Archive Management & Optimization</summary>
<ul>
  <li><strong>New Feature</strong>: App archive backup and restore function.</li>
  <li><strong>New Feature</strong>: Check for updates function.</li>
  <li><strong>Optimization</strong>: Process classification logic.</li>
  <li><strong>Bug Fix</strong>: Fixed process filtering failure issue.</li>
  <li><strong>Stability</strong>: Enhanced stability and fixed crashes.</li>
</ul>
</details>

<details>
<summary>v1.3 - Stability & Function Expansion</summary>
<ul>
  <li><strong>Stability</strong>: Improved overall stability and fixed crash issues.</li>
  <li><strong>Process Filtering</strong>: Added filtering function to exclude system processes and plugins/components.</li>
  <li><strong>Modifier Enhancement</strong>: Optimized modifier module and added refresh function to view values in real time.</li>
  <li><strong>New Feature</strong>: Memory Browser for intuitive viewing of value lists.</li>
</ul>
</details>

<details>
<summary>v1.2 - Feature Enhancement & UI/UX Optimization</summary>
<ul>
  <li><strong>Hex Editor Enhancement</strong>: Added inline editing function with real-time Hex/ASCII preview support.</li>
  <li><strong>UI Optimization</strong>: Interface fine-tuning to improve user experience.</li>
  <li><strong>Bug Fix</strong>: Fixed specific crash issues.</li>
  <li><strong>Favorites Management</strong>: Added independent favorites entry and management functions (notes/delete).</li>
</ul>
</details>

<details>
<summary>v1.1 - Security Update</summary>
<ul>
  <li><strong>RVA Security Detection</strong>: Added environment detection. Pops up a warning before using Patch function on non-jailbroken devices to prevent crashes caused by misoperation.</li>
  <li><strong>Optimization</strong>: Improved stability during process switching.</li>
</ul>
</details>

<details>
<summary>v1.0 - Initial Release</summary>
<ul>
  <li>The first standalone memory tool supporting TrollStore.</li>
  <li>Includes memory search, RVA modification, process management, Hex editing, and multi-language support.</li>
</ul>
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
