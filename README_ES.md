# VansonMod

<p align="center">
  <img src="https://repository-images.githubusercontent.com/1109090336/135167c3-e943-48a9-aa0d-67b3c21e844d" alt="VansonMod Social Preview" width="100%"/>
</p>

**Editor de memoria para iOS, análisis de punteros, parcheo RVA y gestión de procesos para TrollStore (jailbreak opcional). Compatible con edición Hex, escaneo de valores y copia de seguridad/restauración**

[English](./README.md) | [简体中文](./README_CN.md) | [繁體中文](./README_TW.md) | [العربية](./README_AR.md) | [Deutsch](./README_DE.md) | **Español** | [Français](./README_FR.md) | [日本語](./README_JA.md) | [한국어](./README_KO.md) | [Português](./README_PT.md) | [Русский](./README_RU.md) | [ไทย](./README_TH.md) | [Tiếng Việt](./README_VI.md)

![Platform](https://img.shields.io/badge/Platform-iOS%2014.0%2B-black)
![Support](https://img.shields.io/badge/Support-TrollStore-blue)
![License](https://img.shields.io/badge/License-MIT-green)

> [![Join Telegram](https://img.shields.io/badge/Join-Telegram%20Channel-blue?logo=telegram&logoWidth=20&labelColor=26A5E4&color=white)](https://t.me/VansonMod)

---

## Introducción

**VansonMod** es una herramienta independiente de depuración para iOS creada para el entorno **TrollStore**. Funciona externamente y no depende de la inyección tweak tradicional, por lo que muchos flujos comunes siguen disponibles en dispositivos sin jailbreak: selección de procesos, búsqueda de memoria, navegador de memoria, análisis y verificación de punteros, análisis de firmas, scripts y gestión de copias de seguridad.

En dispositivos con jailbreak, VansonMod también habilita flujos más profundos a nivel de código, como **RVA Patch** y **monitorización de watchpoints por hardware**. La versión actual ya no es solo un buscador de memoria, sino una estación de trabajo de depuración más completa para iPhone y iPad.

## Compatibilidad

- **Disponible en TrollStore / sin jailbreak**: selección de procesos, búsqueda de memoria, búsqueda cercana, filtrado de resultados, navegador de memoria, editor Hex, análisis y verificación de punteros, análisis de firmas, herramientas de scripts, gestión de backups y ajustes de tema/idioma/icono.
- **Funciones que dependen del task port del proceso objetivo**: algunas funciones en tiempo de ejecución requieren acceso correcto al task port del proceso objetivo; el comportamiento puede variar según el entorno y el estado de la app.
- **Recomendado o limitado a entornos con jailbreak**: `RVA Patch`, `gestión de registros RVA` y `watchpoints por hardware` están pensados para **Dopamine / palera1n** u otros entornos similares.
- **Motivo**: en dispositivos sin jailbreak, **AMFI** aplica verificaciones estrictas de firma. Modificar directamente el segmento ejecutable (`__TEXT`) suele hacer que la app objetivo se cierre inmediatamente.

## Idiomas compatibles

- Idiomas integrados: 简体中文, 繁體中文, English, العربية, Deutsch, Español, Français, 日本語, 한국어, Português, Русский, ไทย, Tiếng Việt.

## Navegación

- **App Selection**: ver procesos en ejecución, todas las apps instaladas o procesos del sistema; buscar por nombre / Bundle ID / PID y adjuntar, abrir, cerrar, respaldar o revisar cambios de código.
- **Memory Debug**: búsquedas exactas, difusas, grupales y cercanas, filtrado de resultados, edición por lotes y salto a vistas de valor o Hex.
- **RVA Debug**: aplicar parches por módulo y offset y gestionar registros RVA.
- **Toolbox**: gestionar bloqueos de memoria, favoritos, punteros, RVA, firmas, archivos de verificación y scripts.
- **Settings**: configurar tema, idioma, iconos, orden de pestañas, rangos de búsqueda, tolerancia float, límite de resultados y actualizaciones; también permite reordenar pestañas manteniendo pulsado el menú inferior.

## Funciones destacadas

- **Gestión de procesos y apps**: vistas `Running / All / System`, nombres localizados, versión, marcados con estrella, copia de PID / Bundle ID, apertura rápida de apps y cierre de procesos.
- **Búsqueda de memoria y edición por lotes**: búsqueda exacta, fuzzy, grupal, por rango y cercana; filtros mayor/menor/entre; escritura fija, edición incremental, bloqueo masivo y favoritos masivos.
- **Navegador de memoria y editor Hex**: salto de direcciones, refresco automático, vista de cadenas, copia masiva de direcciones; el editor Hex admite diseños `Hex / Split / Text`, edición por fila y saltos por offset.
- **Análisis y verificación de punteros**: cadenas manuales o automáticas, modos estático / dinámico / todos / backtrack, verificación en tiempo real, comparación por snapshots y archivos de verificación.
- **Firmas y scripts**: análisis de firmas desde cualquier dirección, alcance por módulo, búsqueda global, smart mask; además incluye un entorno JavaScript integrado con guías y ejemplos visibles dentro de VM.
- **RVA, watchpoints y auditoría del proceso**: selección de módulos, parches por offset, presets ARM64 y gestión RVA; con jailbreak también hay watchpoints por hardware. La auditoría de procesos permite ver qué posiciones de código o valores RVA cambiaron antes y después de ejecutar la app objetivo.
- **Experiencia y ajustes**: cambio de tema, idioma, iconos, orden de pestañas, rango fuzzy, frecuencia de bloqueo, evitar suspensión y compatibilidad con iPad split view, horizontal y Stage Manager.

## Capturas

| <div align="center"><img src="./Screenshots/APP_SELECT.PNG" width="100%" alt="APP_SELECT"/></div> | <div align="center"><img src="./Screenshots/MEM_BROWSER.PNG" width="100%" alt="MEM_BROWSER"/></div> | <div align="center"><img src="./Screenshots/MEM_DEBUG.PNG" width="100%" alt="MEM_DEBUG"/></div> | <div align="center"><img src="./Screenshots/MEM_HEX_MIX.PNG" width="100%" alt="MEM_HEX_MIX"/></div> |
| :------------------------------------------------------------------------------------------------: | :--------------------------------------------------------------------------------------------------: | :------------------------------------------------------------------------------------------------: | :---------------------------------------------------------------------------------------------------: |
| <div align="center"><img src="./Screenshots/RVA_MANAGER.PNG" width="100%" alt="RVA_MANAGER"/></div> | <div align="center"><img src="./Screenshots/POINTER_ANALYSIS.PNG" width="100%" alt="POINTER_ANALYSIS"/></div> | <div align="center"><img src="./Screenshots/POINTER_VERIFY.PNG" width="100%" alt="POINTER_VERIFY"/></div> | <div align="center"><img src="./Screenshots/POINTER_LOCKER.PNG" width="100%" alt="POINTER_LOCKER"/></div> |

---

## Changelog

Consulta [Releases](https://github.com/vaenshine/VansonMod/releases).

---

## Instalación

1. Descarga el archivo `.tipa` más reciente desde [Releases](https://github.com/vaenshine/VansonMod/releases).
2. Instálalo con **TrollStore**.
3. Abre la app, selecciona el proceso objetivo y empieza a depurar.

---

## Créditos

*   Developer: **Vaenshine**
*   Special Thanks: **Gey1ist**, **Xiczee**, **Zoomin**
*   Community Support: [iOSGods.com](https://iosgods.com/)

---

## Aviso legal

Esta herramienta es solo para **investigación de seguridad y aprendizaje de ingeniería inversa**. No debe usarse para fines ilegales, obtención de beneficio injusto o robo de datos. Cualquier bloqueo, pérdida de datos, restricción de cuenta, fallo del dispositivo o responsabilidad legal derivada del uso corre por cuenta del usuario.

---

## Declaración importante

Este proyecto es gratuito y de código cerrado. **No aceptamos donaciones de ninguna forma.** El desarrollo se realiza únicamente con fines de investigación técnica e intercambio comunitario.

---

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=vaenshine/VansonMod&type=Date)](https://star-history.com/#vaenshine/VansonMod&Date)
