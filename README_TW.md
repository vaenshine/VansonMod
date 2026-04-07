# VansonMod

<p align="center">
  <img src="https://repository-images.githubusercontent.com/1109090336/135167c3-e943-48a9-aa0d-67b3c21e844d" alt="VansonMod Social Preview" width="100%"/>
</p>

**面向 TrollStore 的 iOS 記憶體編輯、指標分析、RVA Patch 與進程管理工具（可選越獄），支援 Hex 編輯、數值掃描與備份/還原**

[English](./README.md) | [简体中文](./README_CN.md) | **繁體中文** | [العربية](./README_AR.md) | [Deutsch](./README_DE.md) | [Español](./README_ES.md) | [Français](./README_FR.md) | [日本語](./README_JA.md) | [한국어](./README_KO.md) | [Português](./README_PT.md) | [Русский](./README_RU.md) | [ไทย](./README_TH.md) | [Tiếng Việt](./README_VI.md)

![Platform](https://img.shields.io/badge/Platform-iOS%2014.0%2B-black)
![Support](https://img.shields.io/badge/Support-TrollStore-blue)
![License](https://img.shields.io/badge/License-MIT-green)

> [![Join Telegram](https://img.shields.io/badge/Join-Telegram%20Channel-blue?logo=telegram&logoWidth=20&labelColor=26A5E4&color=white)](https://t.me/VansonMod)

---

## 簡介

**VansonMod** 是一款面向 **TrollStore** 環境的獨立 iOS 調試工具。它以外部方式運作，不依賴傳統 tweak 注入，因此在非越獄裝置上也可使用許多常見流程，例如進程選擇、記憶體搜尋、記憶體瀏覽、指標分析與驗證、特徵碼分析、腳本工具，以及應用存檔管理。

在越獄環境下，VansonMod 還可進一步開啟更深層的程式碼級工作流，例如 **RVA Patch** 與 **硬體斷點監控**。目前版本已從單純的記憶體搜尋工具擴展為更完整的 iOS 調試工作台。

## 相容性說明

- **TrollStore / 非越獄可用**：進程選擇、記憶體搜尋、臨近搜尋、結果篩選、記憶體瀏覽、Hex 編輯器、指標分析與驗證、特徵碼分析、腳本工具、存檔管理、主題/語言/圖示設定。
- **依賴目標進程 task port 的功能**：部分執行期功能需要成功取得目標進程的 task port，實際效果會受環境與目標 App 狀態影響。
- **建議或限定在越獄環境使用**：`RVA Patch`、`RVA 記錄管理`、`硬體斷點監控` 等功能更適合在 **Dopamine / palera1n** 等越獄環境下使用。
- **原因**：在非越獄裝置上，**AMFI** 會嚴格檢查程式碼簽名，直接修改可執行程式碼段（`__TEXT`）通常會導致目標 App 立即閃退。

## 多語言支援

- 內建語言：簡體中文、繁體中文、English、العربية、Deutsch、Español、Français、日本語、한국어、Português、Русский、ไทย、Tiếng Việt。

## 頁面結構

- **進程選擇**：瀏覽執行中進程、全部應用或系統進程，支援名稱 / Bundle ID / PID 搜尋，並可快速附加、開啟、結束進程、建立備份或查看程式碼變化。
- **記憶體調試**：提供精確、模糊、聯合、臨近搜尋，結果篩選、批次修改，以及數值視圖 / Hex 視圖跳轉。
- **RVA 調試**：依模組與 Offset 套用 Patch，管理 RVA 記錄，並在越獄環境下處理更深層的程式碼調試流程。
- **工具箱**：集中管理記憶體鎖定、收藏、指標、RVA、特徵碼、驗證檔與腳本。
- **設定**：可調整主題、語言、圖示、標籤排序、搜尋範圍、浮點誤差、結果限制、更新檢查，並支援長按底部選單快速調整標籤順序。

## 功能亮點

- **進程與應用管理**：支援 `Running / All / System` 三種視圖、在地化名稱、版本顯示、星標、PID / Bundle ID 複製、快速開啟 App 與結束進程。
- **記憶體搜尋與批次修改**：支援精確、模糊、聯合、範圍、臨近搜尋，以及大於 / 小於 / 區間篩選、固定值寫入、遞增修改、批量鎖定與批量收藏。
- **記憶體瀏覽與 Hex 編輯**：支援地址跳轉、自動刷新、字串視圖、批量複製地址；Hex 編輯器支援 `Hex / 分屏 / 文本` 佈局、行編輯與偏移跳轉。
- **指標分析與驗證**：支援手動與自動指標鏈、靜態 / 動態 / 全部 / 追溯模式、即時驗證、快照對比、驗證檔匯入匯出與鎖定聯動。
- **特徵碼與腳本系統**：可從任意地址進入特徵碼分析，支援模組範圍、全域搜尋、智慧遮罩；內建 JavaScript 腳本執行環境，可直接在 VM 內查看腳本說明與示例。
- **RVA、斷點監控與進程審計**：支援模組選擇、Offset Patch、ARM64 指令預設、RVA 記錄管理；越獄環境下可使用硬體斷點監控。進程審計可用於查看目標 App 執行前後哪些程式碼位置或 RVA 發生變化。
- **體驗與設定**：支援主題切換、語言切換、圖示切換、標籤排序、模糊搜尋範圍、鎖定頻率、防休眠，以及 iPad 分割畫面、橫向模式與 Stage Manager。

## 應用截圖

| <div align="center"><img src="./Screenshots/APP_SELECT.PNG" width="100%" alt="APP_SELECT"/></div> | <div align="center"><img src="./Screenshots/MEM_BROWSER.PNG" width="100%" alt="MEM_BROWSER"/></div> | <div align="center"><img src="./Screenshots/MEM_DEBUG.PNG" width="100%" alt="MEM_DEBUG"/></div> | <div align="center"><img src="./Screenshots/MEM_HEX_MIX.PNG" width="100%" alt="MEM_HEX_MIX"/></div> |
| :------------------------------------------------------------------------------------------------: | :--------------------------------------------------------------------------------------------------: | :------------------------------------------------------------------------------------------------: | :---------------------------------------------------------------------------------------------------: |
| <div align="center"><img src="./Screenshots/RVA_MANAGER.PNG" width="100%" alt="RVA_MANAGER"/></div> | <div align="center"><img src="./Screenshots/POINTER_ANALYSIS.PNG" width="100%" alt="POINTER_ANALYSIS"/></div> | <div align="center"><img src="./Screenshots/POINTER_VERIFY.PNG" width="100%" alt="POINTER_VERIFY"/></div> | <div align="center"><img src="./Screenshots/POINTER_LOCKER.PNG" width="100%" alt="POINTER_LOCKER"/></div> |

---

## 更新日誌

請前往 [Releases](https://github.com/vaenshine/VansonMod/releases) 查看。

---

## 安裝

1. 從 [Releases](https://github.com/vaenshine/VansonMod/releases) 下載最新的 `.tipa`。
2. 使用 **TrollStore** 安裝。
3. 開啟 App，選擇目標進程後即可開始調試。

---

## 致謝

*   開發者：**Vaenshine**
*   特別感謝：**Gey1ist**, **Xiczee**, **Zoomin**
*   社群支援：[iOSGods.com](https://iosgods.com/)

---

## 免責聲明

本工具僅用於**安全研究與逆向工程學習**。請勿將其用於非法用途、不公平競技、資料竊取或其他違法行為。使用本工具造成的閃退、資料遺失、帳號限制、設備異常與相關法律責任，均由使用者自行承擔。

---

## 重要聲明

本專案為免費閉源專案，**不接受任何形式的捐贈**。開發僅基於技術研究與社群交流目的。

---

## Star 趨勢

[![Star History Chart](https://api.star-history.com/svg?repos=vaenshine/VansonMod&type=Date)](https://star-history.com/#vaenshine/VansonMod&Date)
