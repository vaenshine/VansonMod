# VansonMod

<p align="center">
  <img src="https://repository-images.githubusercontent.com/1109090336/135167c3-e943-48a9-aa0d-67b3c21e844d" alt="VansonMod Social Preview" width="100%"/>
</p>

**Редактор памяти iOS, анализ указателей, RVA-патчер и менеджер процессов для TrollStore (джейлбрейк не обязателен). Поддерживает Hex-редактирование, поиск значений и резервное копирование/восстановление**

[English](../README.md) | [简体中文](./README_CN.md) | [繁體中文](./README_TW.md) | [العربية](./README_AR.md) | [Deutsch](./README_DE.md) | [Español](./README_ES.md) | [Français](./README_FR.md) | [日本語](./README_JA.md) | [한국어](./README_KO.md) | [Português](./README_PT.md) | **Русский** | [ไทย](./README_TH.md) | [Tiếng Việt](./README_VI.md)

![Platform](https://img.shields.io/badge/Platform-iOS%2014.0%2B-black)
![Support](https://img.shields.io/badge/Support-TrollStore-blue)
![License](https://img.shields.io/badge/License-GPL--3.0-green)

> [![Join Telegram](https://img.shields.io/badge/Join-Telegram%20Channel-blue?logo=telegram&logoWidth=20&labelColor=26A5E4&color=white)](https://t.me/VansonMod)

---

## Введение

**VansonMod** — это независимый инструмент отладки iOS, созданный для среды **TrollStore**. Он работает внешним способом и не требует традиционной tweak-инъекции, поэтому многие типичные сценарии доступны даже на устройствах без джейлбрейка: выбор процесса, поиск памяти, просмотр памяти, анализ и проверка указателей, анализ сигнатур, скрипты и управление резервными копиями.

На устройствах с джейлбрейком VansonMod также открывает более глубокие сценарии работы с кодом, включая **RVA Patch** и **аппаратный мониторинг watchpoint**. Текущая версия уже давно вышла за рамки простого memory scanner и превратилась в более полноценную рабочую среду отладки iOS.

## Совместимость

- **Доступно на TrollStore / без джейлбрейка**: выбор процессов, поиск памяти, nearby search, фильтрация результатов, memory browser, Hex editor, анализ и проверка указателей, анализ сигнатур, script tools, управление бэкапами, а также настройки темы/языка/иконок.
- **Функции, зависящие от task port целевого процесса**: некоторые runtime-функции требуют успешного доступа к task port целевого процесса; поведение может зависеть от окружения и состояния приложения.
- **Рекомендуется или ограничено джейлбрейком**: `RVA Patch`, `управление RVA-записями` и `аппаратные watchpoint` лучше использовать в средах типа **Dopamine / palera1n**.
- **Причина**: на устройствах без джейлбрейка **AMFI** строго проверяет подпись кода. Прямое изменение исполняемого сегмента (`__TEXT`) обычно приводит к немедленному вылету целевого приложения.

## Поддерживаемые языки

- Встроенные языки: 简体中文, 繁體中文, English, العربية, Deutsch, Español, Français, 日本語, 한국어, Português, Русский, ไทย, Tiếng Việt.

## Навигация

- **App Selection**: просмотр запущенных процессов, всех установленных приложений или системных процессов; поиск по имени / Bundle ID / PID; быстрый attach, запуск, завершение, бэкап и просмотр изменений кода.
- **Memory Debug**: точный, fuzzy, групповой, диапазонный и nearby поиск, фильтрация результатов, timeline поиска для восстановления прошлых snapshots результатов, отмена последней ручной записи, пакетное редактирование и переход к просмотру значений или Hex.
- **RVA Debug**: применение патчей по модулю и смещению, управление RVA-записями.
- **Toolbox**: управление memory lock, избранным, указателями, RVA, сигнатурами, файлами проверки и скриптами.
- **Settings**: настройка темы, языка, иконок, порядка вкладок, диапазонов поиска, float tolerance, лимита результатов и проверки обновлений; вкладки также можно быстро переставлять долгим нажатием на нижнее меню.

## Основные возможности

- **Управление процессами и приложениями**: представления `Running / All / System`, локализованные названия приложений, отображение версии, избранное, копирование PID / Bundle ID, быстрый запуск приложений и завершение процессов.
- **Поиск памяти и пакетное редактирование**: точный, fuzzy, групповой, диапазонный и nearby поиск, snapshots timeline с восстановлением, отмена ручной записи, фильтры больше/меньше/между, запись фиксированного значения, инкрементальное изменение, массовая блокировка и массовое избранное.
- **Memory browser и Hex editor**: переход по адресу, автообновление, строковый режим, массовое копирование адресов; Hex editor поддерживает режимы `Hex / Split / Text`, построчное редактирование и переходы по offset.
- **Анализ и проверка указателей**: ручные и автоматические цепочки указателей, режимы статический / динамический / все / backtrack, проверка в реальном времени, сравнение snapshot и импорт/экспорт файлов проверки.
- **Сигнатуры и скрипты**: анализ сигнатур с любого адреса, выбор диапазона модуля, глобальный поиск и smart mask; встроенная JavaScript-среда с руководствами и примерами прямо внутри VM.
- **RVA, watchpoint и аудит процесса**: выбор модуля, патчи по смещению, ARM64-пресеты и управление RVA; при наличии джейлбрейка доступны аппаратные watchpoint. Аудит процесса позволяет увидеть, какие позиции кода или значения RVA изменились до и после запуска целевого приложения.
- **Настройки и UX**: переключение темы, языка, иконок, порядка вкладок, диапазона fuzzy-поиска, частоты lock, предотвращение сна и поддержка iPad split view, горизонтального режима и Stage Manager.

## Скриншоты

| <div align="center"><img src="./Screenshots/APP_SELECT.PNG" width="100%" alt="APP_SELECT"/></div> | <div align="center"><img src="./Screenshots/MEM_BROWSER.PNG" width="100%" alt="MEM_BROWSER"/></div> | <div align="center"><img src="./Screenshots/MEM_DEBUG.PNG" width="100%" alt="MEM_DEBUG"/></div> | <div align="center"><img src="./Screenshots/MEM_HEX_MIX.PNG" width="100%" alt="MEM_HEX_MIX"/></div> |
| :------------------------------------------------------------------------------------------------: | :--------------------------------------------------------------------------------------------------: | :------------------------------------------------------------------------------------------------: | :---------------------------------------------------------------------------------------------------: |
| <div align="center"><img src="./Screenshots/RVA_MANAGER.PNG" width="100%" alt="RVA_MANAGER"/></div> | <div align="center"><img src="./Screenshots/POINTER_ANALYSIS.PNG" width="100%" alt="POINTER_ANALYSIS"/></div> | <div align="center"><img src="./Screenshots/POINTER_VERIFY.PNG" width="100%" alt="POINTER_VERIFY"/></div> | <div align="center"><img src="./Screenshots/POINTER_LOCKER.PNG" width="100%" alt="POINTER_LOCKER"/></div> |

---

## Связанный Проект

Для dylib-редакции под внедренные runtime-сценарии смотрите [VansonLoader](https://github.com/vaenshine/vansonloader), companion dylib-производную VansonMod.

---

## Журнал изменений

См. [Releases](https://github.com/vaenshine/VansonMod/releases).

---

## Установка

1. Скачайте последнюю `.tipa` из [Releases](https://github.com/vaenshine/VansonMod/releases).
2. Установите через **TrollStore**.
3. Запустите приложение, выберите целевой процесс и начните отладку.

---

## Сборка Из Исходников

Требования: Theos, Xcode Command Line Tools, Python 3, `ar`, `tar`, `zip` и `unzip`.

```sh
make clean package FINALPACKAGE=1 DEBUG=0
./scripts/release.sh
```

Правила участия см. в [CONTRIBUTING](./CONTRIBUTING.md), приватные отчеты о безопасности см. в [SECURITY](./SECURITY.md).

---

## Благодарности

*   Developer: **Vaenshine**
*   Special Thanks: **Gey1ist**, **Xiczee**, **Zoomin**
*   Community Support: [iOSGods.com](https://iosgods.com/)

---

## Отказ от ответственности

Инструмент предназначен только для **исследований в области безопасности и изучения реверс-инжиниринга**. Его нельзя использовать для незаконных действий, нечестного получения преимуществ или кражи данных. Все вылеты, потеря данных, блокировки аккаунтов, проблемы с устройством и юридическая ответственность полностью лежат на пользователе.

---

## Важное заявление

Проект открыт под лицензией GPL-3.0. Разработка основана на технических исследованиях и обмене в сообществе.

---

## License

GPL-3.0. See [LICENSE](./LICENSE).

---

## Star History

[![Star History Chart](https://api.star-history.com/chart?repos=vaenshine/VansonMod&type=date&legend=bottom-right&sealed_token=7GKlgSNa_RYfyFti6u-PKeTxObIt1P6yp9ExhaBjWXgxI78k9FV3xLprlOPWX_Rx4DkQRZ_ub-lWHoqPsTekAaDxkiZKMUhSqDuSCrqhTDn9cR8jQAE_pQ)](https://www.star-history.com/?repos=vaenshine%2FVansonMod&type=date&legend=bottom-right)
