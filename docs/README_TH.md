# VansonMod

<p align="center">
  <img src="https://repository-images.githubusercontent.com/1109090336/135167c3-e943-48a9-aa0d-67b3c21e844d" alt="VansonMod Social Preview" width="100%"/>
</p>

**เครื่องมือแก้ไขหน่วยความจำ iOS วิเคราะห์พอยน์เตอร์ แพตช์ RVA และจัดการโปรเซสสำหรับ TrollStore (จะ jailbreak หรือไม่ก็ได้) พร้อมรองรับการแก้ไข Hex การสแกนค่า และการสำรอง/กู้คืนข้อมูล**

[English](../README.md) | [简体中文](./README_CN.md) | [繁體中文](./README_TW.md) | [العربية](./README_AR.md) | [Deutsch](./README_DE.md) | [Español](./README_ES.md) | [Français](./README_FR.md) | [日本語](./README_JA.md) | [한국어](./README_KO.md) | [Português](./README_PT.md) | [Русский](./README_RU.md) | **ไทย** | [Tiếng Việt](./README_VI.md)

![Platform](https://img.shields.io/badge/Platform-iOS%2014.0%2B-black)
![Support](https://img.shields.io/badge/Support-TrollStore-blue)
![License](https://img.shields.io/badge/License-MIT-green)

> [![Join Telegram](https://img.shields.io/badge/Join-Telegram%20Channel-blue?logo=telegram&logoWidth=20&labelColor=26A5E4&color=white)](https://t.me/VansonMod)

---

## แนะนำ

**VansonMod** เป็นเครื่องมือดีบัก iOS แบบอิสระที่ออกแบบมาสำหรับสภาพแวดล้อม **TrollStore** โดยทำงานจากภายนอกและไม่พึ่งการฉีด tweak แบบดั้งเดิม จึงยังสามารถใช้เวิร์กโฟลว์ทั่วไปได้จำนวนมากบนอุปกรณ์ที่ไม่ jailbreak เช่น เลือกโปรเซส ค้นหาหน่วยความจำ ดูข้อมูลหน่วยความจำ วิเคราะห์และตรวจสอบพอยน์เตอร์ วิเคราะห์ซิกเนเจอร์ ใช้งานสคริปต์ และจัดการแบ็กอัปของแอป

ในสภาพแวดล้อมที่ jailbreak แล้ว VansonMod ยังรองรับงานเชิงลึกระดับโค้ด เช่น **RVA Patch** และ **การติดตาม hardware watchpoint** ปัจจุบัน VansonMod ไม่ได้เป็นแค่เครื่องมือค้นหาหน่วยความจำธรรมดา แต่กลายเป็นชุดงานดีบัก iOS ที่ครบขึ้นมาก

## ความเข้ากันได้

- **ใช้งานได้บน TrollStore / ไม่ต้อง jailbreak**: เลือกโปรเซส ค้นหาหน่วยความจำ ค้นหาใกล้เคียง กรองผลลัพธ์ ดูหน่วยความจำ แก้ไข Hex วิเคราะห์และตรวจสอบพอยน์เตอร์ วิเคราะห์ซิกเนเจอร์ เครื่องมือสคริปต์ จัดการแบ็กอัป และตั้งค่าธีม/ภาษา/ไอคอน
- **ฟังก์ชันที่ขึ้นอยู่กับ task port ของโปรเซสเป้าหมาย**: ฟังก์ชัน runtime บางส่วนต้องเข้าถึง task port ของโปรเซสเป้าหมายได้สำเร็จ ดังนั้นพฤติกรรมจริงอาจแตกต่างกันตามสภาพแวดล้อมและสถานะแอป
- **แนะนำหรือจำกัดให้ใช้กับเครื่อง jailbreak**: `RVA Patch`, `การจัดการบันทึก RVA`, และ `hardware watchpoint` เหมาะกับสภาพแวดล้อมแบบ **Dopamine / palera1n**
- **เหตุผล**: บนอุปกรณ์ที่ไม่ jailbreak ระบบ **AMFI** จะตรวจลายเซ็นโค้ดอย่างเข้มงวด การแก้ไขส่วนโค้ดที่รันได้ (`__TEXT`) โดยตรงมักทำให้แอปเป้าหมายปิดทันที

## ภาษาที่รองรับ

- ภาษาในตัว: 简体中文, 繁體中文, English, العربية, Deutsch, Español, Français, 日本語, 한국어, Português, Русский, ไทย, Tiếng Việt

## โครงสร้างเมนู

- **App Selection**: ดูโปรเซสที่กำลังทำงาน แอปที่ติดตั้งทั้งหมด หรือโปรเซสระบบ ค้นหาด้วยชื่อ / Bundle ID / PID และสั่ง attach เปิดแอป ปิดโปรเซส สำรองข้อมูล หรือดูการเปลี่ยนแปลงของโค้ดได้อย่างรวดเร็ว
- **Memory Debug**: ค้นหาแบบ exact, fuzzy, group และ nearby พร้อมกรองผล แก้ไขค่าหลายรายการ และกระโดดไปมุมมองค่า / Hex
- **RVA Debug**: แพตช์ตามโมดูลและออฟเซ็ต พร้อมจัดการบันทึก RVA
- **Toolbox**: จัดการ memory lock, รายการโปรด, พอยน์เตอร์, RVA, ซิกเนเจอร์, ไฟล์ตรวจสอบ และสคริปต์จากที่เดียว
- **Settings**: ตั้งค่าธีม ภาษา ไอคอน ลำดับแท็บ ช่วงค้นหา ค่า float tolerance การจำกัดผลลัพธ์ และการตรวจอัปเดต รวมถึงรองรับการกดค้างเมนูล่างเพื่อสลับลำดับแท็บอย่างรวดเร็ว

## จุดเด่น

- **จัดการโปรเซสและแอป**: รองรับมุมมอง `Running / All / System`, ชื่อแอปแบบแปลภาษา, เวอร์ชัน, การปักดาว, การคัดลอก PID / Bundle ID, การเปิดแอปอย่างรวดเร็ว และการปิดโปรเซส
- **ค้นหาหน่วยความจำและแก้ไขหลายรายการ**: รองรับ exact, fuzzy, group, range และ nearby search พร้อมตัวกรองมากกว่า/น้อยกว่า/ช่วง การเขียนค่าแบบคงที่ การแก้ไขแบบเพิ่มค่า การล็อกหลายรายการ และเพิ่มรายการโปรดหลายรายการ
- **ดูหน่วยความจำและแก้ไข Hex**: กระโดดไปยังที่อยู่ รีเฟรชอัตโนมัติ ดูสตริง คัดลอกที่อยู่หลายรายการ พร้อมเลย์เอาต์ `Hex / Split / Text`, การแก้ไขทีละบรรทัด และการกระโดดตาม offset
- **วิเคราะห์และตรวจสอบพอยน์เตอร์**: รองรับพอยน์เตอร์แบบสร้างเองและอัตโนมัติ โหมด static / dynamic / all / backtrack การตรวจสอบแบบเรียลไทม์ การเปรียบเทียบ snapshot และการนำเข้า/ส่งออกไฟล์ตรวจสอบ
- **ซิกเนเจอร์และระบบสคริปต์**: วิเคราะห์ซิกเนเจอร์จากที่อยู่ใดก็ได้ เลือกขอบเขตตามโมดูล ค้นหาแบบ global และใช้ smart mask พร้อม runtime ของ JavaScript ที่มีคู่มือและตัวอย่างดูได้จากใน VM
- **RVA, watchpoint และ process audit**: เลือกโมดูล แพตช์ตาม offset ใช้ preset ARM64 และจัดการ RVA; บนเครื่อง jailbreak ยังใช้ hardware watchpoint ได้ด้วย ส่วน process audit ใช้ดูว่าตำแหน่งโค้ดหรือค่า RVA จุดใดเปลี่ยนไปก่อนและหลังการรันแอปเป้าหมาย
- **การใช้งานและการตั้งค่า**: เปลี่ยนธีม ภาษา ไอคอน ลำดับแท็บ ช่วง fuzzy search ความถี่ lock ป้องกันเครื่องพัก และรองรับ iPad split view แนวนอน และ Stage Manager

## ภาพหน้าจอ

| <div align="center"><img src="../Screenshots/APP_SELECT.PNG" width="100%" alt="APP_SELECT"/></div> | <div align="center"><img src="../Screenshots/MEM_BROWSER.PNG" width="100%" alt="MEM_BROWSER"/></div> | <div align="center"><img src="../Screenshots/MEM_DEBUG.PNG" width="100%" alt="MEM_DEBUG"/></div> | <div align="center"><img src="../Screenshots/MEM_HEX_MIX.PNG" width="100%" alt="MEM_HEX_MIX"/></div> |
| :------------------------------------------------------------------------------------------------: | :--------------------------------------------------------------------------------------------------: | :------------------------------------------------------------------------------------------------: | :---------------------------------------------------------------------------------------------------: |
| <div align="center"><img src="../Screenshots/RVA_MANAGER.PNG" width="100%" alt="RVA_MANAGER"/></div> | <div align="center"><img src="../Screenshots/POINTER_ANALYSIS.PNG" width="100%" alt="POINTER_ANALYSIS"/></div> | <div align="center"><img src="../Screenshots/POINTER_VERIFY.PNG" width="100%" alt="POINTER_VERIFY"/></div> | <div align="center"><img src="../Screenshots/POINTER_LOCKER.PNG" width="100%" alt="POINTER_LOCKER"/></div> |

---

## บันทึกการอัปเดต

ดูที่ [Releases](https://github.com/vaenshine/VansonMod/releases)

---

## การติดตั้ง

1. ดาวน์โหลดไฟล์ `.tipa` เวอร์ชันล่าสุดจาก [Releases](https://github.com/vaenshine/VansonMod/releases)
2. ติดตั้งด้วย **TrollStore**
3. เปิดแอป เลือกโปรเซสเป้าหมาย แล้วเริ่มดีบักได้ทันที

---

## เครดิต

*   Developer: **Vaenshine**
*   Special Thanks: **Gey1ist**, **Xiczee**, **Zoomin**
*   Community Support: [iOSGods.com](https://iosgods.com/)

---

## ข้อจำกัดความรับผิดชอบ

เครื่องมือนี้จัดทำขึ้นเพื่อ **การวิจัยด้านความปลอดภัยและการเรียนรู้ reverse engineering** เท่านั้น ห้ามใช้เพื่อกิจกรรมที่ผิดกฎหมาย การได้เปรียบอย่างไม่เป็นธรรม หรือการขโมยข้อมูล ความเสียหาย การปิดตัวของแอป การสูญหายของข้อมูล การจำกัดบัญชี ปัญหาของอุปกรณ์ และความรับผิดชอบทางกฎหมายทั้งหมดเป็นความรับผิดชอบของผู้ใช้เอง

---

## ประกาศสำคัญ

โปรเจกต์นี้เป็นซอฟต์แวร์ฟรีแบบปิดซอร์ส **เราไม่รับเงินบริจาคในทุกรูปแบบ** การพัฒนามีขึ้นเพื่อการวิจัยทางเทคนิคและการแลกเปลี่ยนความรู้ในชุมชนเท่านั้น

---

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=vaenshine/VansonMod&type=Date)](https://star-history.com/#vaenshine/VansonMod&Date)
