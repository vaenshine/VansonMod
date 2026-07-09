# VansonMod

<p align="center">
  <img src="https://repository-images.githubusercontent.com/1109090336/135167c3-e943-48a9-aa0d-67b3c21e844d" alt="VansonMod Social Preview" width="100%"/>
</p>

**أداة لتحرير الذاكرة في iOS وتحليل المؤشرات وتصحيح RVA وإدارة العمليات على TrollStore مع دعم اختياري للجيلبريك، وتدعم تحرير Hex ومسح القيم والنسخ الاحتياطي والاستعادة**

[English](../README.md) | [简体中文](./README_CN.md) | [繁體中文](./README_TW.md) | **العربية** | [Deutsch](./README_DE.md) | [Español](./README_ES.md) | [Français](./README_FR.md) | [日本語](./README_JA.md) | [한국어](./README_KO.md) | [Português](./README_PT.md) | [Русский](./README_RU.md) | [ไทย](./README_TH.md) | [Tiếng Việt](./README_VI.md)

![Platform](https://img.shields.io/badge/Platform-iOS%2014.0%2B-black)
![Support](https://img.shields.io/badge/Support-TrollStore-blue)
![License](https://img.shields.io/badge/License-GPL--3.0-green)

> [![Join Telegram](https://img.shields.io/badge/Join-Telegram%20Channel-blue?logo=telegram&logoWidth=20&labelColor=26A5E4&color=white)](https://t.me/VansonMod)

---

## مقدمة

**VansonMod** هي أداة مستقلة لتصحيح تطبيقات iOS صُممت لبيئة **TrollStore**. تعمل من الخارج ولا تعتمد على حقن tweak التقليدي، لذلك تبقى الكثير من المهام الأساسية متاحة حتى على الأجهزة غير المكسورة الحماية، مثل اختيار العمليات، البحث في الذاكرة، تصفح الذاكرة، تحليل المؤشرات والتحقق منها، تحليل التواقيع، السكربتات، وإدارة النسخ الاحتياطي للتطبيقات.

على الأجهزة التي تحتوي على جيلبريك، يفتح VansonMod كذلك مسارات أعمق على مستوى الكود مثل **RVA Patch** و**مراقبة hardware watchpoint**. الإصدار الحالي لم يعد مجرد أداة بحث في الذاكرة، بل أصبح مساحة عمل أكثر اكتمالاً لتصحيح iOS.

## التوافق

- **متاح على TrollStore / بدون جيلبريك**: اختيار العمليات، البحث في الذاكرة، البحث القريب، تصفية النتائج، متصفح الذاكرة، محرر Hex، تحليل المؤشرات والتحقق منها، تحليل التواقيع، أدوات السكربت، إدارة النسخ الاحتياطي، وإعدادات الثيم/اللغة/الأيقونة.
- **الميزات التي تعتمد على task port للعملية الهدف**: بعض الميزات وقت التشغيل تحتاج إلى الوصول الناجح إلى task port الخاص بالعملية الهدف، لذلك قد يختلف السلوك بحسب البيئة وحالة التطبيق.
- **موصى به أو مقيّد ببيئات الجيلبريك**: `RVA Patch` و`إدارة سجلات RVA` و`hardware watchpoint` مناسبة أكثر لبيئات مثل **Dopamine / palera1n**.
- **السبب**: على الأجهزة غير المكسورة الحماية، يفرض **AMFI** فحصاً صارماً لتوقيع الكود. التعديل المباشر على الجزء التنفيذي (`__TEXT`) يؤدي غالباً إلى إغلاق التطبيق الهدف فوراً.

## اللغات المدعومة

- اللغات المدمجة: 简体中文، 繁體中文، English، العربية، Deutsch، Español، Français، 日本語، 한국어، Português، Русский، ไทย، Tiếng Việt.

## التنقل

- **App Selection**: عرض العمليات الجارية، كل التطبيقات المثبتة، أو عمليات النظام؛ البحث بالاسم / Bundle ID / PID؛ والقيام بسرعة بعملية attach أو فتح التطبيق أو إيقافه أو إنشاء نسخة احتياطية أو فحص تغييرات الكود.
- **Memory Debug**: تنفيذ البحث الدقيق والضبابي والجماعي وبالمدى والقريب، مع خط زمني لاستعادة لقطات النتائج، وتراجع عن آخر كتابة يدوية، وتصفية النتائج وتعديلها دفعة واحدة والانتقال إلى عرض القيم أو Hex.
- **RVA Debug**: تطبيق التصحيحات حسب الموديول والإزاحة وإدارة سجلات RVA.
- **Toolbox**: إدارة memory locks والمفضلة والمؤشرات وRVA والتواقيع وملفات التحقق والسكربتات من مكان واحد.
- **Settings**: ضبط الثيم واللغة والأيقونات وترتيب التبويبات ونطاقات البحث ودقة float وحدود النتائج وفحص التحديثات، كما يمكن إعادة ترتيب التبويبات سريعاً عبر الضغط المطوّل على القائمة السفلية.

## أبرز الميزات

- **إدارة العمليات والتطبيقات**: أوضاع عرض `Running / All / System`، أسماء التطبيقات المحلية، عرض الإصدار، التمييز بالنجمة، نسخ PID / Bundle ID، التشغيل السريع للتطبيقات، وإنهاء العمليات.
- **البحث في الذاكرة والتعديل الجماعي**: بحث دقيق وضبابي وجماعي وبالمدى وقريب، مع لقطات زمنية للنتائج واستعادتها، وتراجع عن آخر تعديل يدوي، وفلاتر أكبر/أصغر/بين، وكتابة قيمة ثابتة، وتعديل تدريجي، وقفل جماعي، ومفضلة جماعية.
- **متصفح الذاكرة ومحرر Hex**: الانتقال إلى العنوان، التحديث التلقائي، عرض السلاسل النصية، نسخ العناوين دفعة واحدة؛ ويدعم محرر Hex أنماط `Hex / Split / Text` وتحرير الصفوف والتنقل حسب الإزاحة.
- **تحليل المؤشرات والتحقق منها**: سلاسل مؤشرات يدوية أو تلقائية، أوضاع static / dynamic / all / backtrack، تحقق لحظي، مقارنة snapshots، واستيراد/تصدير ملفات التحقق.
- **التواقيع ونظام السكربت**: تحليل التواقيع من أي عنوان، وتحديد النطاق حسب الموديول، والبحث العام، وsmart mask؛ مع بيئة JavaScript مدمجة تعرض الدليل والأمثلة مباشرة داخل VM.
- **RVA وwatchpoint وتدقيق العملية**: اختيار الموديول، التصحيح حسب الإزاحة، إعدادات ARM64 الجاهزة، وإدارة RVA؛ ومع الجيلبريك تتوفر watchpoints عتادية. أما تدقيق العملية فيساعد على معرفة مواضع الكود أو قيم RVA التي تغيّرت قبل وبعد تشغيل التطبيق الهدف.
- **الإعدادات وتجربة الاستخدام**: تبديل الثيم واللغة والأيقونات وترتيب التبويبات ونطاق البحث الضبابي وتردد القفل ومنع السكون، مع دعم iPad split view والوضع الأفقي وStage Manager.

## لقطات الشاشة

| <div align="center"><img src="./Screenshots/APP_SELECT.PNG" width="100%" alt="APP_SELECT"/></div> | <div align="center"><img src="./Screenshots/MEM_BROWSER.PNG" width="100%" alt="MEM_BROWSER"/></div> | <div align="center"><img src="./Screenshots/MEM_DEBUG.PNG" width="100%" alt="MEM_DEBUG"/></div> | <div align="center"><img src="./Screenshots/MEM_HEX_MIX.PNG" width="100%" alt="MEM_HEX_MIX"/></div> |
| :------------------------------------------------------------------------------------------------: | :--------------------------------------------------------------------------------------------------: | :------------------------------------------------------------------------------------------------: | :---------------------------------------------------------------------------------------------------: |
| <div align="center"><img src="./Screenshots/RVA_MANAGER.PNG" width="100%" alt="RVA_MANAGER"/></div> | <div align="center"><img src="./Screenshots/POINTER_ANALYSIS.PNG" width="100%" alt="POINTER_ANALYSIS"/></div> | <div align="center"><img src="./Screenshots/POINTER_VERIFY.PNG" width="100%" alt="POINTER_VERIFY"/></div> | <div align="center"><img src="./Screenshots/POINTER_LOCKER.PNG" width="100%" alt="POINTER_LOCKER"/></div> |

---

## مشروع مرتبط

إذا كنت تحتاج إلى إصدار dylib لتدفقات runtime المحقونة، راجع [VansonLoader](https://github.com/vaenshine/vansonloader)، وهو مشتق dylib مرافق لـ VansonMod.

---

## سجل التحديثات

راجع [Releases](https://github.com/vaenshine/VansonMod/releases).

---

## التثبيت

1. نزّل أحدث ملف `.tipa` من [Releases](https://github.com/vaenshine/VansonMod/releases).
2. ثبّته عبر **TrollStore**.
3. افتح التطبيق، اختر العملية الهدف، وابدأ التصحيح.

---

## البناء من المصدر

المتطلبات: Theos و Xcode Command Line Tools و Python 3 و `ar` و `tar` و `zip` و `unzip`.

```sh
make clean package FINALPACKAGE=1 DEBUG=0
./scripts/release.sh
```

راجع [CONTRIBUTING](./CONTRIBUTING.md) لقواعد المساهمة و [SECURITY](./SECURITY.md) للإبلاغ الخاص عن الثغرات.

---

## الشكر

*   Developer: **Vaenshine**
*   Special Thanks: **Gey1ist**, **Xiczee**, **Zoomin**
*   Community Support: [iOSGods.com](https://iosgods.com/)

---

## إخلاء المسؤولية

هذه الأداة مخصصة فقط لـ **أبحاث الأمن وتعلم الهندسة العكسية**. يُمنع استخدامها في أي نشاط غير قانوني أو غير عادل أو لسرقة البيانات. أي انهيارات أو فقدان بيانات أو قيود على الحساب أو مشاكل بالجهاز أو مسؤوليات قانونية تقع بالكامل على عاتق المستخدم.

---

## بيان مهم

هذا المشروع مفتوح المصدر بموجب GPL-3.0، ويستند التطوير إلى البحث التقني وتبادل المجتمع.

---

## License

GPL-3.0. See [LICENSE](./LICENSE).

---

## Star History

[![Star History Chart](https://api.star-history.com/chart?repos=vaenshine/VansonMod&type=date&legend=bottom-right&sealed_token=7GKlgSNa_RYfyFti6u-PKeTxObIt1P6yp9ExhaBjWXgxI78k9FV3xLprlOPWX_Rx4DkQRZ_ub-lWHoqPsTekAaDxkiZKMUhSqDuSCrqhTDn9cR8jQAE_pQ)](https://www.star-history.com/?repos=vaenshine%2FVansonMod&type=date&legend=bottom-right)
