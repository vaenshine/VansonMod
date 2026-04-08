# VansonMod

<p align="center">
  <img src="https://repository-images.githubusercontent.com/1109090336/135167c3-e943-48a9-aa0d-67b3c21e844d" alt="VansonMod Social Preview" width="100%"/>
</p>

**Trình chỉnh sửa bộ nhớ iOS, phân tích con trỏ, vá RVA và quản lý tiến trình cho TrollStore (jailbreak là tùy chọn). Hỗ trợ chỉnh Hex, quét giá trị và sao lưu/khôi phục**

[English](../README.md) | [简体中文](./README_CN.md) | [繁體中文](./README_TW.md) | [العربية](./README_AR.md) | [Deutsch](./README_DE.md) | [Español](./README_ES.md) | [Français](./README_FR.md) | [日本語](./README_JA.md) | [한국어](./README_KO.md) | [Português](./README_PT.md) | [Русский](./README_RU.md) | [ไทย](./README_TH.md) | **Tiếng Việt**

![Platform](https://img.shields.io/badge/Platform-iOS%2014.0%2B-black)
![Support](https://img.shields.io/badge/Support-TrollStore-blue)
![License](https://img.shields.io/badge/License-MIT-green)

> [![Join Telegram](https://img.shields.io/badge/Join-Telegram%20Channel-blue?logo=telegram&logoWidth=20&labelColor=26A5E4&color=white)](https://t.me/VansonMod)

---

## Giới thiệu

**VansonMod** là công cụ debug iOS độc lập dành cho môi trường **TrollStore**. Nó hoạt động từ bên ngoài thay vì phụ thuộc vào tweak injection truyền thống, vì vậy nhiều quy trình quen thuộc vẫn dùng được trên thiết bị không jailbreak, như chọn tiến trình, tìm kiếm bộ nhớ, duyệt bộ nhớ, phân tích và xác minh con trỏ, phân tích signature, script và quản lý sao lưu ứng dụng.

Trên thiết bị đã jailbreak, VansonMod còn mở rộng sang các quy trình mức mã nguồn sâu hơn như **RVA Patch** và **giám sát hardware watchpoint**. Ở phiên bản hiện tại, VansonMod không còn chỉ là công cụ quét bộ nhớ mà đã trở thành một workspace debug iOS hoàn chỉnh hơn.

## Tương thích

- **Dùng được trên TrollStore / không jailbreak**: chọn tiến trình, tìm kiếm bộ nhớ, nearby search, lọc kết quả, memory browser, Hex editor, phân tích và xác minh con trỏ, phân tích signature, script tools, quản lý backup và cài đặt giao diện/ngôn ngữ/icon.
- **Tính năng phụ thuộc task port của tiến trình mục tiêu**: một số tính năng runtime cần truy cập được task port của tiến trình mục tiêu; hành vi thực tế có thể thay đổi tùy theo môi trường và trạng thái app.
- **Khuyến nghị hoặc giới hạn cho môi trường jailbreak**: `RVA Patch`, `quản lý bản ghi RVA`, và `hardware watchpoint` phù hợp hơn với môi trường như **Dopamine / palera1n**.
- **Lý do**: trên thiết bị không jailbreak, **AMFI** kiểm tra chữ ký mã rất chặt. Việc sửa trực tiếp phân đoạn thực thi (`__TEXT`) thường sẽ khiến app mục tiêu crash ngay lập tức.

## Ngôn ngữ hỗ trợ

- Ngôn ngữ tích hợp: 简体中文, 繁體中文, English, العربية, Deutsch, Español, Français, 日本語, 한국어, Português, Русский, ไทย, Tiếng Việt.

## Điều hướng

- **App Selection**: xem tiến trình đang chạy, tất cả app đã cài hoặc tiến trình hệ thống; tìm theo tên / Bundle ID / PID; nhanh chóng attach, mở app, kill, backup hoặc xem thay đổi mã.
- **Memory Debug**: tìm kiếm exact, fuzzy, group và nearby, lọc kết quả, chỉnh sửa hàng loạt và chuyển sang dạng xem giá trị hoặc Hex.
- **RVA Debug**: áp dụng patch theo module và offset, đồng thời quản lý các bản ghi RVA.
- **Toolbox**: quản lý memory lock, favorites, pointer, RVA, signature, file verifier và script trong cùng một nơi.
- **Settings**: cấu hình giao diện, ngôn ngữ, icon, thứ tự tab, phạm vi tìm kiếm, float tolerance, giới hạn kết quả và kiểm tra cập nhật; cũng có thể sắp xếp lại tab nhanh bằng cách nhấn giữ menu dưới cùng.

## Điểm nổi bật

- **Quản lý tiến trình và ứng dụng**: hỗ trợ chế độ xem `Running / All / System`, tên app bản địa hóa, hiển thị phiên bản, gắn sao, sao chép PID / Bundle ID, mở app nhanh và kết thúc tiến trình.
- **Tìm kiếm bộ nhớ và chỉnh sửa hàng loạt**: exact, fuzzy, group, range, nearby search; bộ lọc lớn hơn / nhỏ hơn / trong khoảng; ghi giá trị cố định, sửa tăng dần, khóa hàng loạt và đánh dấu yêu thích hàng loạt.
- **Memory browser và Hex editor**: nhảy tới địa chỉ, tự động làm mới, xem chuỗi, sao chép hàng loạt địa chỉ; Hex editor hỗ trợ bố cục `Hex / Split / Text`, chỉnh theo dòng và nhảy theo offset.
- **Phân tích và xác minh con trỏ**: chuỗi con trỏ thủ công hoặc tự động, chế độ static / dynamic / all / backtrack, xác minh thời gian thực, so sánh snapshot và nhập/xuất file verifier.
- **Signature và script**: phân tích signature từ bất kỳ địa chỉ nào, chọn phạm vi module, tìm kiếm toàn cục và smart mask; runtime JavaScript tích hợp với hướng dẫn và ví dụ xem trực tiếp trong VM.
- **RVA, watchpoint và process audit**: chọn module, patch theo offset, preset ARM64 và quản lý RVA; trên máy jailbreak còn có hardware watchpoint. Process audit giúp xem vị trí mã hoặc giá trị RVA nào đã thay đổi trước và sau khi app mục tiêu chạy.
- **Trải nghiệm và cài đặt**: chuyển đổi theme, ngôn ngữ, icon, sắp xếp tab, phạm vi fuzzy search, tần suất lock, chống ngủ và hỗ trợ iPad split view, chế độ ngang và Stage Manager.

## Ảnh chụp màn hình

| <div align="center"><img src="../Screenshots/APP_SELECT.PNG" width="100%" alt="APP_SELECT"/></div> | <div align="center"><img src="../Screenshots/MEM_BROWSER.PNG" width="100%" alt="MEM_BROWSER"/></div> | <div align="center"><img src="../Screenshots/MEM_DEBUG.PNG" width="100%" alt="MEM_DEBUG"/></div> | <div align="center"><img src="../Screenshots/MEM_HEX_MIX.PNG" width="100%" alt="MEM_HEX_MIX"/></div> |
| :------------------------------------------------------------------------------------------------: | :--------------------------------------------------------------------------------------------------: | :------------------------------------------------------------------------------------------------: | :---------------------------------------------------------------------------------------------------: |
| <div align="center"><img src="../Screenshots/RVA_MANAGER.PNG" width="100%" alt="RVA_MANAGER"/></div> | <div align="center"><img src="../Screenshots/POINTER_ANALYSIS.PNG" width="100%" alt="POINTER_ANALYSIS"/></div> | <div align="center"><img src="../Screenshots/POINTER_VERIFY.PNG" width="100%" alt="POINTER_VERIFY"/></div> | <div align="center"><img src="../Screenshots/POINTER_LOCKER.PNG" width="100%" alt="POINTER_LOCKER"/></div> |

---

## Changelog

Xem tại [Releases](https://github.com/vaenshine/VansonMod/releases).

---

## Cài đặt

1. Tải tệp `.tipa` mới nhất từ [Releases](https://github.com/vaenshine/VansonMod/releases).
2. Cài bằng **TrollStore**.
3. Mở app, chọn tiến trình mục tiêu và bắt đầu debug.

---

## Ghi nhận

*   Developer: **Vaenshine**
*   Special Thanks: **Gey1ist**, **Xiczee**, **Zoomin**
*   Community Support: [iOSGods.com](https://iosgods.com/)

---

## Miễn trừ trách nhiệm

Công cụ này chỉ dành cho **nghiên cứu bảo mật và học reverse engineering**. Không được dùng cho mục đích bất hợp pháp, giành lợi thế không công bằng hoặc đánh cắp dữ liệu. Mọi crash, mất dữ liệu, giới hạn tài khoản, lỗi thiết bị và trách nhiệm pháp lý phát sinh đều do người dùng tự chịu.

---

## Tuyên bố quan trọng

Đây là dự án miễn phí, mã nguồn đóng. **Chúng tôi không nhận quyên góp dưới bất kỳ hình thức nào.** Việc phát triển chỉ nhằm mục đích nghiên cứu kỹ thuật và chia sẻ với cộng đồng.

---

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=vaenshine/VansonMod&type=Date)](https://star-history.com/#vaenshine/VansonMod&Date)
