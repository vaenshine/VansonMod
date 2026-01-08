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

### v2.2。1
- 修复编辑特征码闪退
- 修复无法导出指针

### v2.2 - 功能升级与体验优化
- 新增特征码功能：全新上线特征码功能，助力更精准的内存数据定位与分析。
- 指针搜索性能大幅升级：全面优化指针搜索的速度与准确性，相较于 V2.0 初始版本，实现质的飞跃。
- 联合搜索全面升级：新增多种输入方式，同时加入锚点辐射功能，可将特殊数字优先展示，搭配提升的搜索速度，大幅提高检索效率。
- 内存调试 Tab 界面全新重构：优化界面布局与交互逻辑，打造更流畅的调试体验；同时将 V1.9 版本的范围搜索功能回归至批量选择模块，并新增批量选择悬浮工具栏，操作更便捷。
- RVA 调试页面体验优化：重构 RVA 调试页面，优化框架选择逻辑，界面布局更宽松合理，操作空间更舒适。
- 菜单功能结构调整优化：移除原菜单中的指针调试选项，将工具箱功能整合至该位置；工具箱现已聚合管理所有保存数据，方便用户统一查看与调用。注意：指针、特征码相关功能入口，需从内存地址跳转进入。
- 搜索结果与浏览功能强化：优化搜索结果跳转功能，新增内存浏览及十六进制（Hex）浏览记录标记，浏览轨迹一目了然，无需再手动区分已查看 / 未查看内容。
- 修复内存浏览翻页异常问题：针对内存浏览时翻页乱跳的问题进行专项修复，具体自己验证。

<details>
<summary>v2.1 - 核心架构修复与多模块体验优化</summary>
<ul>
  <li><strong>核心架构修复 (Core & Stability)</strong>：解决 “内存调试” 与 “指针搜索” 数据互串问题。</li>
  <li><strong>内存调试 (Modifier)</strong>：
    <ul>
      <li>模糊搜索增强：新增 “数值增加了...”“数值减少了...” 搜索选项，支持输入具体变动数值。</li>
      <li>批量操作优化：新增批量锁定、批量收藏、批量删除功能。</li>
      <li>UI 美化升级：“批量选择” 下替换为图标节省空间（全选/反选、收藏、锁定、修改、删除）。</li>
      <li>重置体验优化：点击重置仅清空搜索数据，保留搜索模式（精确 / 模糊）与数据类型选择，提升连续调试效率。</li>
    </ul>
  </li>
  <li><strong>RVA 调试 (Patcher)</strong>：修复删除功能，修复下拉刷新导致数据重复堆叠的问题。</li>
  <li><strong>指针验证器 (Verifier)</strong>：
    <ul>
      <li>类型选择支持：主界面新增数据类型选择器（覆盖 I8 - F64 类型）。</li>
      <li>静默保存功能：指针验证成功后，自动筛选有效指针并保存为新的指针验证文件，方便保存进度。</li>
    </ul>
  </li>
  <li><strong>指针搜索 (Pointer Search)</strong>：手动搜索指针导航修复，修复多层级（Lv2+）页面无法返回、UI 卡死、按钮无法点击的问题。</li>
  <li><strong>通用优化</strong>：
    <ul>
      <li>横屏支持：解锁 App 旋转限制，完美适配 iPad/iPhone 横屏操作；目标实现横屏状态下切换回 VM 仍保持横屏显示。</li>
      <li>交互细节优化：地址锁定、内存锁定新增 “修改备注” 功能；批量操作场景下，增加空选状态提示。</li>
    </ul>
  </li>
</ul>
</details>

<details>
<summary>v2.0 - 新增指针搜索与RVA管理 优化平板适配及核心体验</summary>
<ul>
  <li><strong>新增指针搜索功能</strong>：支持手动、自动双搜索模式，配套指针验证功能，同时支持指针导入导出，大幅提升调试效率。</li>
  <li><strong>新增 RVA 管理模块</strong>：RVA 调试功能同步升级，可便捷保存 RVA 调试记录，支持调试记录快速导入与导出，核心调试记录高效留存。</li>
  <li><strong>新增数值筛选功能</strong>：支持大于、小于及区间筛选，精准定位目标数据，调试查找更精准高效。</li>
  <li><strong>增加原生 iPad 分屏体验</strong>：完美适配平板设备操作习惯。</li>
  <li><strong>新增 APP 图标选择功能</strong>：上线多款全新图标，随心切换风格，增添使用趣味性，换种新鲜体验。</li>
  <li><strong>设置项新增指针配置开关</strong>：可对指针自动搜索进行手动调参，满足高阶用户精细调试需求。</li>
  <li><strong>优化界面布局</strong>：将 APP 管理入口迁移至进程管理上方，同时整合指针锁定、内存锁定、收藏夹至同一 Tab 页，核心功能集中聚合，操作查找更便捷。</li>
  <li><strong>优化交互操作</strong>：针对 APP 管理、进程选择、指针锁定、RVA 管理四大模块，移除原有刷新图标，统一改为下拉刷新，操作更流畅顺滑。</li>
  <li><strong>Bug 修复</strong>：修复内存浏览翻页时候卡住的 bug，保障操作流程顺畅不卡顿。</li>
  <li><strong>优化运行体验</strong>：修复诸多已知 bug，全面提升软件整体运行稳定性。</li>
</ul>
</details>

<details>
<summary>v1.9 - 新增临近搜索与多模式搜索 优化检索效率及批量修改</summary>
<ul>
  <li><strong>新增临近搜索功能</strong>：可基于已有结果扫描附近内存数据，精准定位关联地址。</li>
  <li><strong>模糊搜索效率提升</strong>：模糊搜索再度提速，大幅缩短检索耗时，体验更流畅。</li>
  <li><strong>支持多模式混合搜索</strong>：不再限制单一搜索模式，可自由切换模式继续检索。</li>
  <li><strong>联合搜索功能增强</strong>：需遵循内存顺序先后搜索原则，内存中条件顺序不符可能导致检索无结果。</li>
  <li><strong>优化批量修改逻辑</strong>：新增区间选择功能，支持自由选定修改范围，操作更便捷。</li>
  <li><strong>设置项新增配置</strong>：包含联合搜索范围、搜索结果显示设置、浮点误差调节。</li>
  <li><strong>稳定性提升</strong>：修复若干已知问题，提升应用整体稳定性。</li>
</ul>
</details>

<details>
<summary>v1.80 - 新增主题切换与iPad分屏 优化搜索体验及问题修复</summary>
<ul>
  <li><strong>新增主题切换模式</strong>：支持自由切换主题模式，包含<strong>跟随系统｜浅色｜深色</strong>三种选择。</li>
  <li><strong>修复递增修改逻辑</strong>：修正了数值递增修改功能的逻辑异常问题。</li>
  <li><strong>适配iPad原生分屏</strong>：新增iPad原生分屏支持（兼容性待验证，台前调度模式下可正常运行）。</li>
  <li><strong>回车键触发搜索</strong>：新增回车键快捷触发搜索功能，提升操作效率。</li>
  <li><strong>搜索结果序号显示</strong>：为搜索结果添加序号标识，方便快速定位内容。</li>
  <li><strong>锁定列表功能优化及Bug修复</strong>：为锁定列表新增独立开关，并修复开启状态下修改数值不生效的问题。</li>
</ul>
</details>

<details>
<summary>v1.72 - Hex 界面重构与备份管理增强</summary>
<ul>
  <li><strong>Hex 界面重构</strong>：全新设计的 Hex 编辑器，支持「仅 Hex / 分屏 / 仅文本」三种视图模式切换。深度优化了布局比例与行高，实现了零边距显示与完美的视觉对齐。</li>
  <li><strong>全局备份管理</strong>：在应用管理中新增「备份管理」入口，支持统一查看设备内的所有备份文件。即使是已卸载应用的「僵尸存档」也能在此处找到并进行导出或清理。</li>
  <li><strong>进程搜索增强</strong>：进程选择页面（Tab 1）新增搜索栏，支持通过应用名称、BundleID 或 PID 快速筛选目标进程。</li>
  <li><strong>还原流程优化</strong>：存档还原成功后，工具将自动结束目标应用的进程，无需用户手动重启即可生效。</li>
  <li><strong>弹窗交互优化</strong>：收藏 / 锁定模块中，统一了内存地址点击弹窗的操作逻辑。</li>
</ul>
</details>

<details>
<summary>v1.71 - 修复模糊搜索匹配偏差问题 优化核心算法</summary>
<ul>
  <li>修复模糊搜索匹配偏差问题，优化核心算法，大幅提升搜索效率与准确性。</li>
</ul>
</details>

<details>
<summary>v1.7 - 增加模糊搜索自行选择类型</summary>
<ul>
  <li>增加模糊搜索自行选择类型，提升搜索灵活性。</li>
</ul>
</details>

<details>
<summary>v1.6 - 字符串搜索与 iPad 适配优化</summary>
<ul>
  <li><strong>字符串搜索</strong>：新增字符串搜索功能（该功能主要适用于调试场景）。</li>
  <li><strong>存档导入</strong>：支持从 iOS “文件” App 直接导入备份文件夹。</li>
  <li><strong>RVA 界面升级</strong>：展示主程序基址（支持点击复制），输入框新增<strong>智能容错机制</strong>。</li>
  <li><strong>iPad 适配</strong>：全面适配 iPad 横屏显示模式及屏幕自动旋转功能。</li>
  <li><strong>交互体验</strong>：交互全面优化，新增跳转菜单功能。</li>
</ul>
</details>

<details>
<summary>v1.5 - 高级搜索与 Hex 编辑器 2.0</summary>
<ul>
  <li><strong>高级搜索</strong>：新增 <strong>模糊搜索</strong> (未知初始值 -> 变大/变小) 和 <strong>联合搜索</strong> (如 `500,1000`)。</li>
  <li><strong>批量修改</strong>：支持将搜索结果修改为 <strong>固定值</strong> 或 <strong>递增数值</strong>。</li>
  <li><strong>Hex 编辑器 2.0</strong>：全新重构，支持上下分屏 (Hex/ASCII) 同步滚动与独立行编辑。</li>
  <li><strong>存档管理</strong>：改用文件夹直拷方案，更稳定，并支持在系统“文件”App 中直接管理备份。</li>
  <li><strong>进程列表</strong>：智能过滤系统进程 (com.apple)，并新增应用版本号显示。</li>
  <li><strong>体验优化</strong>：修改器和内存浏览器增加刷新按钮；修复设置页输入框 Bug。</li>
</ul>
</details>

<details>
<summary>v1.4 - 存档管理与优化</summary>
<ul>
  <li><strong>新增</strong>：应用存档备份与还原功能。</li>
  <li><strong>新增</strong>：检查更新功能。</li>
  <li><strong>优化</strong>：进程分类逻辑。</li>
  <li><strong>修复</strong>：过滤进程失效的问题。</li>
  <li><strong>稳定</strong>：增强稳定性，修复闪退。</li>
</ul>
</details>

<details>
<summary>v1.3 - 稳定性与功能扩展</summary>
<ul>
  <li><strong>稳定性</strong>：提升整体稳定性，修复崩溃问题。</li>
  <li><strong>进程过滤</strong>：增加过滤功能，排除系统进程及插件/组件。</li>
  <li><strong>修改器</strong>：优化修改器模块，增加刷新功能以实时查看数值。</li>
  <li><strong>新功能</strong>：内存浏览器 (Memory Browser)，直观查看数值列表。</li>
</ul>
</details>

<details>
<summary>v1.2 - 功能增强与 UI/UX 优化</summary>
<ul>
  <li><strong>Hex 编辑器</strong>：增加行内编辑功能，支持 Hex/ASCII 实时预览。</li>
  <li><strong>UI 优化</strong>：界面微调，提升用户体验。</li>
  <li><strong>修复</strong>：修复特定崩溃问题。</li>
  <li><strong>收藏夹</strong>：增加独立的收藏夹入口与管理功能（备注/删除）。</li>
</ul>
</details>

<details>
<summary>v1.1 - 安全性更新</summary>
<ul>
  <li><strong>RVA 安全检测</strong>：增加环境检测。在未越狱设备上使用 Patch 功能前弹出警告，防止误操作导致闪退。</li>
  <li><strong>优化</strong>：提升进程切换时的稳定性。</li>
</ul>
</details>

<details>
<summary>v1.0 - 初始版本</summary>
<ul>
  <li>首个支持 TrollStore 的独立内存工具。</li>
  <li>包含内存搜索、RVA 修改、进程管理、Hex 编辑及多语言支持。</li>
</ul>
</details>

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
