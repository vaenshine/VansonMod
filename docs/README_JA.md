# VansonMod

<p align="center">
  <img src="https://repository-images.githubusercontent.com/1109090336/135167c3-e943-48a9-aa0d-67b3c21e844d" alt="VansonMod Social Preview" width="100%"/>
</p>

**TrollStore 向けの iOS メモリエディタ、ポインタ解析、RVA Patch、プロセスマネージャー（脱獄は任意）。Hex 編集、値スキャン、バックアップ/復元に対応**

[English](../README.md) | [简体中文](./README_CN.md) | [繁體中文](./README_TW.md) | [العربية](./README_AR.md) | [Deutsch](./README_DE.md) | [Español](./README_ES.md) | [Français](./README_FR.md) | **日本語** | [한국어](./README_KO.md) | [Português](./README_PT.md) | [Русский](./README_RU.md) | [ไทย](./README_TH.md) | [Tiếng Việt](./README_VI.md)

![Platform](https://img.shields.io/badge/Platform-iOS%2014.0%2B-black)
![Support](https://img.shields.io/badge/Support-TrollStore-blue)
![License](https://img.shields.io/badge/License-MIT-green)

> [![Join Telegram](https://img.shields.io/badge/Join-Telegram%20Channel-blue?logo=telegram&logoWidth=20&labelColor=26A5E4&color=white)](https://t.me/VansonMod)

---

## 概要

**VansonMod** は **TrollStore** 環境向けに作られた独立型 iOS デバッグツールです。従来の tweak 注入に依存せず外部から動作するため、非脱獄デバイスでもプロセス選択、メモリ検索、メモリ閲覧、ポインタ解析と検証、シグネチャ解析、スクリプト、アーカイブ管理など多くの操作が行えます。

脱獄環境では **RVA Patch** や **ハードウェアウォッチポイント監視** など、より深いコードレベルのワークフローも利用できます。現在の VansonMod は単なるメモリ検索ツールではなく、より総合的な iOS デバッグワークステーションへと発展しています。

## 互換性

- **TrollStore / 非脱獄で利用可能**：プロセス選択、メモリ検索、近傍検索、結果フィルタ、メモリブラウザ、Hex エディタ、ポインタ解析と検証、シグネチャ解析、スクリプト、アーカイブ管理、テーマ / 言語 / アイコン設定。
- **target task port に依存する機能**：一部の実行時機能は対象プロセスの task port 取得に依存するため、環境や対象 App の状態により挙動が変わる場合があります。
- **脱獄環境推奨または限定**：`RVA Patch`、`RVA 記録管理`、`ハードウェアウォッチポイント監視` は **Dopamine / palera1n** などの脱獄環境での利用が適しています。
- **理由**：非脱獄デバイスでは **AMFI** がコード署名を厳格に検査するため、実行コード領域（`__TEXT`）を直接変更すると通常は対象 App が即座にクラッシュします。

## 対応言語

- 内蔵言語：简体中文、繁體中文、English、العربية、Deutsch、Español、Français、日本語、한국어、Português、Русский、ไทย、Tiếng Việt。

## 画面構成

- **App Selection**：起動中プロセス、全アプリ、システムプロセスを閲覧し、名前 / Bundle ID / PID で検索。アタッチ、起動、終了、バックアップ、コード変化の確認が可能です。
- **Memory Debug**：精確検索、ファジー検索、グループ検索、近傍検索、結果フィルタ、バッチ編集、値ビュー / Hex ビューへのジャンプを行えます。
- **RVA Debug**：モジュールとオフセットで Patch を適用し、RVA 記録を管理できます。
- **Toolbox**：メモリロック、お気に入り、ポインタ、RVA、シグネチャ、検証ファイル、スクリプトを一括管理します。
- **Settings**：テーマ、言語、アイコン、タブ順、検索範囲、浮動小数誤差、結果制限、更新確認を設定でき、下部メニューの長押しでタブ順を素早く変更できます。

## 主な機能

- **プロセス / アプリ管理**：`Running / All / System` ビュー、ローカライズ名、バージョン表示、スター、PID / Bundle ID コピー、アプリ起動、プロセス終了に対応。
- **メモリ検索と一括編集**：精確、ファジー、グループ、範囲、近傍検索に加え、大小比較、範囲フィルタ、固定値書き込み、増分編集、一括ロック、一括お気に入りを利用可能。
- **メモリブラウザと Hex エディタ**：アドレスジャンプ、自動更新、文字列表示、アドレス一括コピー、`Hex / Split / Text` レイアウト、行編集、オフセット移動に対応。
- **ポインタ解析と検証**：手動 / 自動ポインタチェーン、静的 / 動的 / 全体 / 追跡モード、リアルタイム検証、スナップショット比較、検証ファイルの入出力に対応。
- **シグネチャ解析とスクリプト**：任意アドレスからシグネチャ解析へ移動でき、モジュール範囲、グローバル検索、スマートマスクを利用可能。JavaScript スクリプト環境も内蔵し、VM 内でガイドやサンプルを確認できます。
- **RVA / ウォッチポイント / プロセス監査**：モジュール選択、Offset Patch、ARM64 命令プリセット、RVA 記録管理に対応。脱獄環境ではハードウェアウォッチポイントも利用可能です。プロセス監査では、実行前後でどのコード位置や RVA が変化したかを確認できます。
- **設定と体験改善**：テーマ切替、言語切替、アイコン切替、タブ並び替え、ファジー検索範囲、ロック頻度、防スリープ、iPad 分割表示、横向き、Stage Manager に対応。

## スクリーンショット

| <div align="center"><img src="../Screenshots/APP_SELECT.PNG" width="100%" alt="APP_SELECT"/></div> | <div align="center"><img src="../Screenshots/MEM_BROWSER.PNG" width="100%" alt="MEM_BROWSER"/></div> | <div align="center"><img src="../Screenshots/MEM_DEBUG.PNG" width="100%" alt="MEM_DEBUG"/></div> | <div align="center"><img src="../Screenshots/MEM_HEX_MIX.PNG" width="100%" alt="MEM_HEX_MIX"/></div> |
| :------------------------------------------------------------------------------------------------: | :--------------------------------------------------------------------------------------------------: | :------------------------------------------------------------------------------------------------: | :---------------------------------------------------------------------------------------------------: |
| <div align="center"><img src="../Screenshots/RVA_MANAGER.PNG" width="100%" alt="RVA_MANAGER"/></div> | <div align="center"><img src="../Screenshots/POINTER_ANALYSIS.PNG" width="100%" alt="POINTER_ANALYSIS"/></div> | <div align="center"><img src="../Screenshots/POINTER_VERIFY.PNG" width="100%" alt="POINTER_VERIFY"/></div> | <div align="center"><img src="../Screenshots/POINTER_LOCKER.PNG" width="100%" alt="POINTER_LOCKER"/></div> |

---

## 更新履歴

[Releases](https://github.com/vaenshine/VansonMod/releases) を参照してください。

---

## インストール

1. [Releases](https://github.com/vaenshine/VansonMod/releases) から最新の `.tipa` をダウンロードします。
2. **TrollStore** でインストールします。
3. App を起動し、対象プロセスを選択してデバッグを開始します。

---

## クレジット

*   Developer: **Vaenshine**
*   Special Thanks: **Gey1ist**, **Xiczee**, **Zoomin**
*   Community Support: [iOSGods.com](https://iosgods.com/)

---

## 免責事項

本ツールは**セキュリティ研究およびリバースエンジニアリング学習**のみを目的としています。違法行為、不正競争、データ窃取などへの使用は禁止されています。利用により発生したクラッシュ、データ損失、アカウント制限、端末異常、法的責任はすべて利用者自身が負担してください。

---

## 重要事項

本プロジェクトは無料のクローズドソースプロジェクトであり、**いかなる寄付も受け付けていません**。開発は技術研究とコミュニティ交流を目的として行われています。

---

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=vaenshine/VansonMod&type=Date)](https://star-history.com/#vaenshine/VansonMod&Date)
