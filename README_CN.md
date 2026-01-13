# VansonMod

<p align="center">
  <img src="https://repository-images.githubusercontent.com/1109090336/135167c3-e943-48a9-aa0d-67b3c21e844d" alt="VansonMod Social Preview" width="100%"/>
</p>

**专为 TrollStore 打造的 iOS 内存调试与 RVA 调试工具**

[![English Readme](https://img.shields.io/badge/Lang-English-blue)](./README.md)
![Platform](https://img.shields.io/badge/Platform-iOS%2014.0%2B-black)
![Support](https://img.shields.io/badge/Support-TrollStore-blue)
![License](https://img.shields.io/badge/License-MIT-green)

> **Note:** Click the "Lang English" badge above to view the English documentation.

> [![Join Telegram](https://img.shields.io/badge/加入-Telegram%20频道-blue?logo=telegram&logoWidth=20&labelColor=26A5E4&color=white)](https://t.me/VansonMod)

---

## 📖 简介

**VansonMod** 是一款专为 **TrollStore (巨魔)** 环境设计的独立 Root Helper 工具。

与传统的越狱插件不同，它无需代码注入，而是利用 Mach 内核 API 在外部运行，因此 **内存调试功能无需越狱环境** 即可使用。核心集成**超强指针调试体系**、高性能内存调试器、应用存档管理、智能进程管理、专业 Hex 编辑器，同时为越狱用户提供完善的跨进程 RVA 调试套件；适配全尺寸 iOS 设备，完美支持原生 iPad 分屏，功能聚合式布局+极致交互优化，调试效率与稳定性双拉满，是 iOS 平台专业的应用调试工具。

### ⚠️ 兼容性提示
*   **内存调试 / 指针全功能 / 存档管理 / iPad分屏 / 图标切换**：✅ 支持 **所有** 设备（包括未越狱的巨魔用户）。
*   **RVA Patcher (汇编调试) / RVA调试记录管理**：⚠️ 需要 **越狱环境** (如 Dopamine, Palera1n) 才能正常工作。
    *   *原因:* 在未越狱的设备上，系统 AMFI 机制会严查代码签名。直接修改可执行代码段 (`__TEXT`) 会导致目标 App 立即闪退。

---

### 核心功能
1.  **指针调试**
    - 支持手动/自动双模式指针搜索，搭配专属指针验证功能，精准校验指针有效性。
    - 支持指针地址一键导入/导出，调试结果可跨设备复用。
    - 支持指针专属配置开关，可对自动搜索规则手动精细调参，适配高阶用户深度调试需求。
    - 指针锁定、内存锁定、收藏夹三合一聚合至同Tab页，核心指针操作一键触达。
    - 指针验证主界面支持数据类型选择器（覆盖 I8 - F64 类型）。
    - 指针验证成功后支持静默保存功能，自动筛选有效指针并保存为新的指针验证文件。

2.  **内存调试器**
    - 覆盖精确、模糊、联合（高性能有序）、混合（二次筛选）多种搜索模式，优化检索效率。
    - 支持数值精准筛选功能，包含大于、小于、区间筛选三种模式，精准定位目标内存数据。
    - 支持临近搜索，基于现有结果扫描附近内存数据并自动去重，快速关联相关地址。
    - 支持批量调试，涵盖全选/范围选择修改、固定值/递增修改、数值锁定、无限滚动内存浏览等功能；支持批量锁定、批量收藏、批量删除功能。
    - 支持自定义浮点误差 (Float Tolerance)，适配各类调试场景参数需求。
    - 增强模糊搜索功能，支持“数值增加了...”“数值减少了...”搜索选项，可输入具体变动数值。

3.  **进程与应用管理**
    - 支持智能过滤，自动识别用户及TrollStore应用、隐藏系统进程，可按名称/BundleID/PID快速筛选。
    - 支持多语言适配，智能显示App本地化名称并展示应用版本号。
    - APP管理入口迁移至进程管理顶部，核心操作集中化。

4.  **应用存档管理**
    - 支持一键备份/还原，完整备份Documents/Library目录，支持多存档，还原后自动结束目标进程即时生效。
    - 支持原生集成系统「文件」App，可直接管理备份文件的导入导出，支持全局备份统一查看与僵尸存档清理。

5.  **跨进程 RVA 调试套件 (需越狱)**
    - 支持实时调试，输入Offset和Hex即可自动Patch运行中代码，自动处理内存权限，内置常用指令预设。
    - 支持RVA调试记录管理模块，可实现调试记录一键保存、快速导入/导出，支持多记录批量管理。
    - 修复删除功能，解决下拉刷新导致数据重复堆叠的问题。

6.  **Hex 编辑器**
    - 支持多视图切换，涵盖Hex/ASCII同步分屏、仅Hex/仅文本视图，零边距视觉对齐，适配不同调试习惯。
    - 支持高效编辑，包含行编辑、地址快速跳转、同步滚动等功能。

7.  **个性化与体验优化**
    - 支持图标自定义功能，提供多款APP图标供用户随心切换。
    - 支持主题适配，涵盖跟随系统/浅色/深色三种主题模式。
    - 原生适配iPad分屏，支持屏幕自动旋转、台前调度模式。
    - 支持横屏操作，解锁App旋转限制，适配iPad/iPhone横屏；横屏状态下切换回VM仍保持横屏显示。

---

## 📸 应用截图

| <div align="center"><img src="/Screenshots/APP_SELECT.PNG" width="100%" alt="APP_SELECT"/></div> | <div align="center"><img src="/Screenshots/MEM_BROWSER.PNG" width="100%" alt="MEM_BROWSER"/></div> | <div align="center"><img src="/Screenshots/MEM_DEBUG.PNG" width="100%" alt="MEM_DEBUG"/></div> | <div align="center"><img src="/Screenshots/MEM_HEX_MIX.PNG" width="100%" alt="MEM_HEX_MIX"/></div> |
| :----------------------------------------------------------------------------------------------: | :------------------------------------------------------------------------------------------------: | :------------------------------------------------------------------------------------------------: | :-------------------------------------------------------------------------------------------------: |
| <div align="center"><img src="/Screenshots/RVA_MANAGER.PNG" width="100%" alt="RVA_MANAGER"/></div> | <div align="center"><img src="/Screenshots/POINTER_ANALYSIS.PNG" width="100%" alt="POINTER_ANALYSIS"/></div> | <div align="center"><img src="/Screenshots/POINTER_VERIFY.PNG" width="100%" alt="POINTER_VERIFY"/></div> | <div align="center"><img src="/Screenshots/POINTER_LOCKER.PNG" width="100%" alt="POINTER_LOCKER"/></div> |
---

## 📝 历史更新日志 (Changelog)

请在 [Releases](../../releases) 查阅。

---

## 📥 安装
1.  在 [Releases](../../releases) 页面下载最新的 `.tipa` 文件。
2.  使用 **TrollStore** 安装。
3.  打开 App 即可使用。

---

## 🤝 致谢
*   开发者: **Vaenshine**
*   特别感谢: **Gey1ist**, **Xiczee**, **Zoomin**
*   社区支持: [iOSGods.com](https://iosgods.com/)

---

## ⚠️ 免责声明
本工具仅用于 **安全研究与逆向工程学习**，使用前请仔细阅读以下条款，一旦使用即视为同意全部内容：
*   本工具为免费闭源项目，仅限安全研究、逆向工程学习及合规技术场景测试使用，使用后请于 24 小时内卸载。
*   本工具为通用技术调试工具，不针对任何应用程序提供定向功能、调试方法及专属适配，无任何预设调试目标与定制化操作方案。
*   严禁将本工具用于商业牟利、破坏应用运营公平性、非法侵入他人系统、窃取数据及其他任何违反国家法律法规与公序良俗的行为。
*   使用本工具所实施的全部操作，均由使用者独立自主作出，操作过程中可能引发的目标应用崩溃、数据损坏丢失、账号限制封禁、设备异常等各类风险，以及由此产生的一切直接、间接损失与法律责任，均由使用者自行承担。

---

## 📢 重要声明
本项目为免费闭源项目，**不接受任何形式的捐赠**，所有开发工作均基于技术研究与交流目的推进；

---

## 📈 Star 趋势
[![Star History Chart](https://api.star-history.com/svg?repos=vaenshine/VansonMod&type=Date)](https://star-history.com/#vaenshine/VansonMod&Date)
