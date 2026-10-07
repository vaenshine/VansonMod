# String editor checks

Run on macOS with Xcode command-line tools:

```sh
bash tests/run_string_memory_tests.sh
```

The tests use a bounded in-memory fixture, independent of a target process.
They cover UTF-8 byte limits, null termination, exact-length range writes,
address parsing, context paging, stale snapshots, partial failures, readback,
and conflict-checked undo.

## Device checks for 3.5

1. Open a known string and confirm that nearby candidate strings show their
   individual addresses. Load earlier/later pages while a draft and caret
   selection are active.
2. Hide/reopen the keyboard. Test portrait, landscape, long strings and a small
   screen. Compact keyboard layouts temporarily collapse the context header.
3. Shorten a null-terminated string, save, and undo. Verify neighboring bytes
   stay unchanged. Unterminated fragments require equal byte counts.
4. Attempt a longer string and confirm saving is disabled. Byte counts use
   UTF-8, including multibyte Chinese characters and emoji.
5. Switch strings with an unsaved draft; exercise cancel, discard, and save.
6. Select an explicit hexadecimal start/end range (end inclusive, max 8192 bytes).
   Range mode displays raw separators/bytes as `\0`, `\n`, `\r`, `\t`,
   `\\`, and `\xNN`. Entering a different byte count must block saving.
   Confirm an equal-length replacement, inspect its preview, save and undo.
7. Change the original bytes externally before saving or undoing; the editor
   should report a conflict. Disconnect/switch the VM target and confirm reads
   and writes fail with an explicit message.

Context is cached in 1 KB pages, capped at 64 KB; selected addresses are kept
independent of row positions. Each editor retains up to 10 original byte
snapshots for undo. Saves compare the source snapshot, write the selected bytes,
and compare the readback. This cannot make live target memory updates atomic
or validate application-specific object invariants.

## Language refresh UI regression

On an Apple Silicon Mac with an already booted test simulator:

```sh
bash tests/run_language_ui_tests.sh SIMULATOR_UDID
```

This builds the actual settings/root controllers, localization implementation and
modal-dismissal helper. The other four pages and target-memory operations are test
doubles. It covers all 13 languages plus Auto, repeated changes, active modal
dismissal, custom tab order, dark appearance, modal cleanup, UI interaction state,
offscreen loading and preservation of the memory context. It does not reproduce
an iOS 17 device hang or validate target-process operations.

Test builds can enable local language-stage logging with `VM_LANGUAGE_TRACE=1`.
Settings then has an Export Report button. Logs contain timestamps and fixed
stage names only, rotate at roughly 64 KB, and are never uploaded automatically.
Regular builds omit the recorder, watchdog and export control. Set
`VM_LANGUAGE_TRACE=0` to exercise that configuration in the harness.

## UI reconstruction review

```sh
bash tests/run_ui_review.sh SIMULATOR_UDID
make -j4 package FINALPACKAGE=1 ADDITIONAL_CFLAGS='-Wno-error=#warnings'
```

The UI review compiles the real controllers, shared styles, models and engines.
A separate simulator bundle uses a fixture application list, suppresses update
checks and captures native UIKit pages in `.theos/ui-review/screenshots`. Memory
screens read a buffer owned by the test process; string writes use a disabled
fixture writer. Screens cover light/dark, 320pt width, larger text, landscape,
forms, cards, editors and empty states. The app exits after recording results.

Assertions cover malformed tab order, selection retention during reorder,
settings validation, pinned-result batch selection, deselection after global
selection, complete editing drafts, cancellation, hidden field preservation,
unsigned/String types and imported metadata protection. Language refresh checks
wait for actual modal/page completion with a bounded timeout.

The command-local warning option addresses the installed Xcode 27 libc++ warning
for the existing iOS 14 deployment target. Build logs are local generated output.
A real device is required to check target-process permissions, live writes,
watchpoints and restore behavior in the user's jailbreak/TrollStore environment.

### Mac 交互预览与第二轮检查

`bash tests/build_mac_ui_preview.sh` 构建并本地签名 `.theos/ui-review/VansonModPreview.app`，双击即可查看原生 UIKit 页面。预览使用独立标识 `com.vanson.local.macpreview`，默认手机宽度和底部五标签；示例进程列表与正式应用数据隔离。

`bash tests/run_ui_review.sh <booted-simulator-udid> --interactive` 将模拟器测试程序保持在交互模式。省略最后参数执行 156 个截图状态与行为断言，包括键盘滚动恢复、批量工具栏边界、脚本清空撤销、Hex 草稿保护和设置 footer 完整文字。截图由应用窗口绘制，键盘状态图中的底部留白对应系统键盘避让区域。


### 3.5 布局与表单回归

本轮新增进程数量、已连接进程图标/名称/PID、模糊初扫重置、设置密度、复杂弹框及内联错误状态。
手动锁定覆盖 Int64/Float32 溢出，指针解析覆盖多行、残余字符及有符号边界。
工具箱进程头包含姓名回退和左右边距断言，RVA 连接卡校验图标与 PID。
完整截图后运行 `python3 tests/build_ui_gallery.py` 更新 `release/ui-preview/index.html`。
所有预览和安装包均为本地生成，测试进程采用独立 bundle ID。

设置分类回归覆盖三个固定标签、切组保存与非法输入保组、公共声明入口，以及小屏/深色/大字号下的布局。语言回归同时检查分组保留和 320pt 法语下所选标签的可见性。

### 深色主题回归

156 个截图状态包含 67 个深色状态，覆盖原实例浅色切深色、长 Bundle ID、导入卡片边框、确认按钮、复杂表单、键盘避让、批量操作与脚本示例。主按钮白字对比度在两种主题下均检查达到 4.5:1。深色截图等待系统转场结束，避免取到导航栏的动画中间态。

模拟器 WebKit 的中文 glyph 资源存在缺失；DOM 中文与编码保持完整，Mac 原生 WebView 实测文字正常。该限制已在截图浏览页的脚本示例卡注明。

进程信息回归检查内存、RVA、工具箱的完整 Bundle ID，含320pt长标识换行及RVA重复进入刷新。品牌回归检查原生安全区、触摸穿透及批量工具栏避让。设置公共信息回归检查版本首行、声明与说明同组，以及每行文字在小屏/大字号中的完整性。


公共版本行覆盖五种更新状态、检查期间禁用、VoiceOver 状态同步、统一信息字号及版权居中。独立离线更新测试使用假网络检查 HTTP/JSON 错误、版本比较、重试、主线程通知与自动/手动请求合流：

```sh
bash tests/run_update_manager_tests.sh <booted-simulator-udid>
```


搜索零结果专项：`bash tests/run_ui_review.sh <booted-simulator-udid> --search-zero-only`。20 个深浅色小屏状态覆盖单次/连续/定值模糊、精确/联合、结果筛选和初始化空/失败。模拟真实 engine 回调，检查 header 立即收缩、attach 间距、模式解锁及重新搜索；旧代码首个场景可复现 371pt 与约 307pt 的高度差。


应用内更新的离线测试同时覆盖官方 TIPA/IPA 资产选择、安装渠道、恶意 URL 拒绝、弹框快照与安装/发布页打开失败回退。更新专项用假 URL opener 验证移交，不会安装软件或打开外部应用。

更新弹框专项：`bash tests/run_ui_review.sh <booted-simulator-udid> --update-ui-only`。10 个深浅色小屏状态从设置版本行进入真实 UIKit 弹框，覆盖 TrollStore、缺少安装包、DEB 渠道、安装器未就绪与跳转失败。检查安装动作、关闭动画期间失败提示衔接，以及返回设置后再次打开的可用性。本轮 611 项离线更新检查与 10 个 UI 状态均通过；设备覆盖安装需在 TrollStore 环境验证。

表单提示专项：`bash tests/run_ui_review.sh <booted-simulator-udid> --form-hints-only`。15 个场景覆盖新增脚本、编辑信息及指针/锁定/RVA 弹框，检查作者标签和默认值分离、输入提示完整性，以及多行提示在输入、删除、程序赋值时的显示切换。截图保留脚本新增初始态和说明清空态。

### README 展示截图

```sh
bash tests/run_release_screenshots.sh <booted-simulator-udid>
```

使用 Apple Silicon iPhone 模拟器生成 `Screenshots/` 中的 12 张英文展示图，界面与演示文本统一使用英文，覆盖进程、内存、指针、RVA、脚本表单及深浅色设置。页面由正式 UIKit 控制器绘制；应用、Bundle ID、PID、内存和列表结果均为固定演示数据。截图程序使用独立标识 `com.vanson.local.releasescreenshots`，每次重建自己的沙盒，并在全部截图成功后替换公开图片。

`ReleaseScreenshotHarness.mm` 和两个截图 fixture 头文件仅用于此独立程序；正式应用的构建入口保持独立。构建日志与抓图日志位于 `.theos/release-screenshots/`。生成后逐张检查图片，并核对根目录和 `docs/` 中各 README 的相对路径。

## Integer search regression

```sh
bash tests/run_integer_scan_tests.sh
```

On Apple Silicon macOS, this compiles the production `MemoryCore.cpp` with
AddressSanitizer and UndefinedBehaviorSanitizer. A bounded Mach-memory fixture
covers U64/I64 exact and range initial scans at every byte alignment, 1 MiB
block boundaries, the last complete value, selected start/end boundaries,
successful short reads, overlapping matches, and exact rescans across 4 KiB
pages. It also checks full-width high-bit U64 comparisons, existing smaller
integer/float strides, and ordered, anchored and layout groups across blocks.
Group-range/skip overflow cases use bounded fixture reads. The fixture performs
no target-process attachment or writes; all result files use a temporary folder.

The scan fix applies to exact/range candidates and groups starting with I64/U64.
Fuzzy snapshots and pointer-address scans retain their existing alignment rules.
