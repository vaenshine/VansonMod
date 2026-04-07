# VansonMod

<p align="center">
  <img src="https://repository-images.githubusercontent.com/1109090336/135167c3-e943-48a9-aa0d-67b3c21e844d" alt="VansonMod Social Preview" width="100%"/>
</p>

**iOS memory editor, iOS pointer analysis, RVA patcher, and process manager for TrollStore (jailbreak optional). Supports hex editing, value scanning, and backup/restore.**

**English** | [简体中文](./README_CN.md) | [繁體中文](./README_TW.md) | [العربية](./README_AR.md) | [Deutsch](./README_DE.md) | [Español](./README_ES.md) | [Français](./README_FR.md) | [日本語](./README_JA.md) | [한국어](./README_KO.md) | [Português](./README_PT.md) | [Русский](./README_RU.md) | [ไทย](./README_TH.md) | [Tiếng Việt](./README_VI.md)

![Platform](https://img.shields.io/badge/Platform-iOS%2014.0%2B-black)
![Support](https://img.shields.io/badge/Support-TrollStore-blue)
![License](https://img.shields.io/badge/License-MIT-green)

> [![Join Telegram](https://img.shields.io/badge/Join-Telegram%20Channel-blue?logo=telegram&logoWidth=20&labelColor=26A5E4&color=white)](https://t.me/VansonMod)

---

## Introduction

**VansonMod** is an independent iOS debugging tool built for the **TrollStore** environment. It works externally instead of relying on traditional tweak injection, so many common workflows remain available on non-jailbroken devices, including process selection, memory search, memory browsing, pointer analysis and verification, signature analysis, scripting, and app archive management.

On jailbroken devices, VansonMod unlocks deeper code-level workflows such as **RVA patching** and **hardware watchpoint monitoring**. The current version has grown from a pure memory search utility into a broader iOS debugging workstation for both iPhone and iPad, with support for split view, landscape, and Stage Manager.

## Compatibility Notes

- **Available on TrollStore / non-jailbroken devices**: process selection, memory search, nearby search, result filtering, memory browsing, Hex editor, pointer analysis and verification, signature analysis, script tools, app archive management, and theme/language/icon settings.
- **Features that depend on the target task port**: some runtime features require successful access to the target process task port, so actual behavior can vary depending on the environment and target app state.
- **Recommended or limited to jailbroken environments**: `RVA Patch`, `RVA record management`, and `hardware watchpoint monitoring` are best used in **Dopamine / palera1n** style jailbreak environments.
- **Why**: on non-jailbroken devices, **AMFI** strictly enforces code-signing checks. Directly modifying the executable text segment (`__TEXT`) will usually crash the target app immediately.

## Language Support

- Built-in languages: 简体中文, 繁體中文, English, العربية, Deutsch, Español, Français, 日本語, 한국어, Português, Русский, ไทย, Tiếng Việt.

## Navigation

- **App Selection**: browse running processes, all installed apps, or system processes; search by name / Bundle ID / PID; quickly attach, open, kill, back up, or inspect code changes for a target app.
- **Memory Debug**: perform exact, fuzzy, group, and nearby searches, filter results, batch edit values, and jump into value or Hex views.
- **RVA Debug**: patch by module and offset, manage saved RVA records, and handle deeper code-level workflows in jailbreak environments.
- **Toolbox**: manage memory locks, favorites, pointers, RVA records, signatures, verifier files, and scripts in one place.
- **Settings**: configure theme, language, icons, tab order, search ranges, float tolerance, result limits, update checks, and more, with quick tab reordering by long-pressing the bottom menu.

## Highlights

- **Process and App Management**: supports `Running / All / System` views, localized app names, version display, starring, PID / Bundle ID copying, quick app launch, and process termination.
- **Memory Search and Batch Editing**: supports exact, fuzzy, group, range, and nearby search modes, plus greater-than / less-than / between filters, fixed value writes, incremental edits, batch lock, batch favorite, and batch delete.
- **Memory Browser and Hex Editor**: supports address jumping, auto refresh, string view, and batch address copying; the Hex editor supports `Hex / Split / Text` layouts, row editing, offset jumps, and fast writes.
- **Pointer Analysis and Verification**: supports manual and automatic pointer chains, static / dynamic / all / backtrack modes, real-time verification, incremental snapshots, changed-region comparison, verifier file save/import/export, and lock integration.
- **Signature Analysis**: jump into signature analysis from any address, choose module scope, run global searches, apply smart masking, verify matches, and save signatures directly into the toolbox.
- **Script System**: includes a built-in JavaScript runtime with examples, shortcuts, console output, and privacy mode; script guides and examples can be viewed directly inside VM to help users get started faster.
- **RVA Debugging and Watchpoint Monitor**: supports module selection, offset patching, ARM64 instruction presets, and RVA record management; in jailbreak environments it also provides hardware watchpoint monitoring, hit records, a code inspector, and quick sending of hit locations into the RVA debugger.
- **App Archives and Process Audit**: supports one-tap backup and restore for `Documents / Library`, multiple archives, and Files app import/export; process audit helps you see which code locations or RVA values changed before and after the target app runs, with diff export and original-byte restore.
- **Settings and UX Improvements**: supports theme switching, language switching, app icon switching, tab reordering, quick tab reordering by long-pressing the bottom menu, fuzzy search range control, lock interval, prevent sleep, result limits, update checks, and native iPad split view, landscape, and Stage Manager support.

## Screenshots

| <div align="center"><img src="./Screenshots/APP_SELECT.PNG" width="100%" alt="APP_SELECT"/></div> | <div align="center"><img src="./Screenshots/MEM_BROWSER.PNG" width="100%" alt="MEM_BROWSER"/></div> | <div align="center"><img src="./Screenshots/MEM_DEBUG.PNG" width="100%" alt="MEM_DEBUG"/></div> | <div align="center"><img src="./Screenshots/MEM_HEX_MIX.PNG" width="100%" alt="MEM_HEX_MIX"/></div> |
| :------------------------------------------------------------------------------------------------: | :--------------------------------------------------------------------------------------------------: | :------------------------------------------------------------------------------------------------: | :---------------------------------------------------------------------------------------------------: |
| <div align="center"><img src="./Screenshots/RVA_MANAGER.PNG" width="100%" alt="RVA_MANAGER"/></div> | <div align="center"><img src="./Screenshots/POINTER_ANALYSIS.PNG" width="100%" alt="POINTER_ANALYSIS"/></div> | <div align="center"><img src="./Screenshots/POINTER_VERIFY.PNG" width="100%" alt="POINTER_VERIFY"/></div> | <div align="center"><img src="./Screenshots/POINTER_LOCKER.PNG" width="100%" alt="POINTER_LOCKER"/></div> |

---

## Changelog

See [Releases](https://github.com/vaenshine/VansonMod/releases).

---

## Installation

1. Download the latest `.tipa` from [Releases](https://github.com/vaenshine/VansonMod/releases).
2. Install it with **TrollStore**.
3. Launch the app, choose a target process, and start debugging.

---

## Credits

*   Developer: **Vaenshine**
*   Special Thanks: **Gey1ist**, **Xiczee**, **Zoomin**
*   Community Support: [iOSGods.com](https://iosgods.com/)

---

## Disclaimer

This tool is for **security research and reverse engineering learning only**. Please read the following terms carefully before use. By using this tool, you are deemed to have accepted all terms below:

*   This tool is a free closed-source project intended only for security research, reverse engineering learning, and compliant technical testing scenarios, and should be removed within 24 hours after use.
*   This tool is a general technical debugging utility. It does not provide targeted features, dedicated methods, or exclusive adaptations for any specific app, and it does not ship with preset targets or custom operation schemes.
*   It is strictly prohibited to use this tool for commercial profit, to undermine application fairness, to illegally access other systems, to steal data, or for any activity that violates applicable laws, regulations, or public order.
*   All operations performed with this tool are made independently by the user. Any risks including target app crashes, data loss or corruption, account restrictions or bans, device instability, and all resulting direct or indirect losses and legal responsibilities must be borne by the user alone.

---

## Important Statement

This is a free closed-source project. **We do not accept donations in any form.** Development is driven purely by technical research and community exchange.

---

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=vaenshine/VansonMod&type=Date)](https://star-history.com/#vaenshine/VansonMod&Date)
