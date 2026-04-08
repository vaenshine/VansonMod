# VansonMod

<p align="center">
  <img src="https://repository-images.githubusercontent.com/1109090336/135167c3-e943-48a9-aa0d-67b3c21e844d" alt="VansonMod Social Preview" width="100%"/>
</p>

**TrollStore용 iOS 메모리 편집기, 포인터 분석, RVA 패처, 프로세스 관리자(탈옥 선택). Hex 편집, 값 스캔, 백업/복원 지원**

[English](../README.md) | [简体中文](./README_CN.md) | [繁體中文](./README_TW.md) | [العربية](./README_AR.md) | [Deutsch](./README_DE.md) | [Español](./README_ES.md) | [Français](./README_FR.md) | [日本語](./README_JA.md) | **한국어** | [Português](./README_PT.md) | [Русский](./README_RU.md) | [ไทย](./README_TH.md) | [Tiếng Việt](./README_VI.md)

![Platform](https://img.shields.io/badge/Platform-iOS%2014.0%2B-black)
![Support](https://img.shields.io/badge/Support-TrollStore-blue)
![License](https://img.shields.io/badge/License-MIT-green)

> [![Join Telegram](https://img.shields.io/badge/Join-Telegram%20Channel-blue?logo=telegram&logoWidth=20&labelColor=26A5E4&color=white)](https://t.me/VansonMod)

---

## 소개

**VansonMod** 는 **TrollStore** 환경을 위해 설계된 독립형 iOS 디버깅 도구입니다. 전통적인 tweak 주입 방식에 의존하지 않고 외부에서 동작하므로, 비탈옥 기기에서도 프로세스 선택, 메모리 검색, 메모리 브라우징, 포인터 분석 및 검증, 시그니처 분석, 스크립트 도구, 앱 아카이브 관리 같은 일반적인 작업을 수행할 수 있습니다.

탈옥 환경에서는 **RVA Patch** 와 **하드웨어 워치포인트 모니터링** 같은 더 깊은 코드 레벨 워크플로도 사용할 수 있습니다. 현재의 VansonMod 는 단순한 메모리 검색 도구를 넘어 보다 종합적인 iOS 디버깅 워크스테이션으로 확장되었습니다.

## 호환성 안내

- **TrollStore / 비탈옥에서 사용 가능**: 프로세스 선택, 메모리 검색, 주변 검색, 결과 필터링, 메모리 브라우저, Hex 편집기, 포인터 분석 및 검증, 시그니처 분석, 스크립트 도구, 백업 관리, 테마/언어/아이콘 설정.
- **target task port 에 의존하는 기능**: 일부 런타임 기능은 대상 프로세스의 task port 접근이 필요하며, 환경과 대상 앱 상태에 따라 동작이 달라질 수 있습니다.
- **탈옥 환경 권장 또는 한정**: `RVA Patch`, `RVA 기록 관리`, `하드웨어 워치포인트 모니터링` 은 **Dopamine / palera1n** 같은 탈옥 환경에서 사용하는 것이 적합합니다.
- **이유**: 비탈옥 기기에서는 **AMFI** 가 코드 서명을 엄격히 검사하므로, 실행 코드 영역(`__TEXT`)을 직접 수정하면 보통 대상 앱이 즉시 종료됩니다.

## 지원 언어

- 내장 언어: 简体中文, 繁體中文, English, العربية, Deutsch, Español, Français, 日本語, 한국어, Português, Русский, ไทย, Tiếng Việt.

## 구성

- **App Selection**: 실행 중 프로세스, 전체 앱, 시스템 프로세스를 보고 이름 / Bundle ID / PID 로 검색할 수 있으며, 빠른 attach, 실행, 종료, 백업, 코드 변화 확인이 가능합니다.
- **Memory Debug**: 정확 검색, 퍼지 검색, 그룹 검색, 주변 검색, 결과 필터링, 일괄 수정, 값 보기 / Hex 보기 이동을 제공합니다.
- **RVA Debug**: 모듈과 오프셋 기준으로 Patch 를 적용하고 RVA 기록을 관리합니다.
- **Toolbox**: 메모리 잠금, 즐겨찾기, 포인터, RVA, 시그니처, 검증 파일, 스크립트를 한곳에서 관리합니다.
- **Settings**: 테마, 언어, 아이콘, 탭 순서, 검색 범위, 부동소수점 허용 오차, 결과 제한, 업데이트 확인을 설정할 수 있으며, 하단 메뉴를 길게 눌러 탭 순서를 빠르게 바꿀 수 있습니다.

## 주요 기능

- **프로세스 및 앱 관리**: `Running / All / System` 보기, 현지화된 앱 이름, 버전 표시, 즐겨찾기, PID / Bundle ID 복사, 앱 실행, 프로세스 종료를 지원합니다.
- **메모리 검색 및 일괄 편집**: 정확, 퍼지, 그룹, 범위, 주변 검색과 함께 크다 / 작다 / 구간 필터, 고정값 쓰기, 증가형 수정, 일괄 잠금, 일괄 즐겨찾기를 지원합니다.
- **메모리 브라우저 및 Hex 편집기**: 주소 이동, 자동 새로고침, 문자열 보기, 주소 일괄 복사, `Hex / Split / Text` 레이아웃, 줄 편집, 오프셋 이동을 지원합니다.
- **포인터 분석 및 검증**: 수동 / 자동 포인터 체인, 정적 / 동적 / 전체 / 역추적 모드, 실시간 검증, 스냅샷 비교, 검증 파일 입출력을 지원합니다.
- **시그니처와 스크립트 시스템**: 임의 주소에서 시그니처 분석으로 바로 이동할 수 있고, 모듈 범위, 전역 검색, 스마트 마스크를 지원합니다. 내장 JavaScript 런타임에서 VM 내부 스크립트 가이드와 예제를 볼 수 있습니다.
- **RVA, 워치포인트, 프로세스 감사**: 모듈 선택, Offset Patch, ARM64 프리셋, RVA 기록 관리를 지원하며, 탈옥 환경에서는 하드웨어 워치포인트도 사용할 수 있습니다. 프로세스 감사는 실행 전후 어떤 코드 위치나 RVA 가 바뀌었는지 확인하는 데 사용됩니다.
- **설정 및 사용성 개선**: 테마 전환, 언어 전환, 아이콘 전환, 탭 재정렬, 퍼지 검색 범위, 잠금 주기, 절전 방지, iPad 분할 화면, 가로 모드, Stage Manager 를 지원합니다.

## 스크린샷

| <div align="center"><img src="../Screenshots/APP_SELECT.PNG" width="100%" alt="APP_SELECT"/></div> | <div align="center"><img src="../Screenshots/MEM_BROWSER.PNG" width="100%" alt="MEM_BROWSER"/></div> | <div align="center"><img src="../Screenshots/MEM_DEBUG.PNG" width="100%" alt="MEM_DEBUG"/></div> | <div align="center"><img src="../Screenshots/MEM_HEX_MIX.PNG" width="100%" alt="MEM_HEX_MIX"/></div> |
| :------------------------------------------------------------------------------------------------: | :--------------------------------------------------------------------------------------------------: | :------------------------------------------------------------------------------------------------: | :---------------------------------------------------------------------------------------------------: |
| <div align="center"><img src="../Screenshots/RVA_MANAGER.PNG" width="100%" alt="RVA_MANAGER"/></div> | <div align="center"><img src="../Screenshots/POINTER_ANALYSIS.PNG" width="100%" alt="POINTER_ANALYSIS"/></div> | <div align="center"><img src="../Screenshots/POINTER_VERIFY.PNG" width="100%" alt="POINTER_VERIFY"/></div> | <div align="center"><img src="../Screenshots/POINTER_LOCKER.PNG" width="100%" alt="POINTER_LOCKER"/></div> |

---

## 변경 로그

[Releases](https://github.com/vaenshine/VansonMod/releases) 를 확인하세요.

---

## 설치

1. [Releases](https://github.com/vaenshine/VansonMod/releases) 에서 최신 `.tipa` 파일을 다운로드합니다.
2. **TrollStore** 로 설치합니다.
3. 앱을 실행하고 대상 프로세스를 선택한 뒤 디버깅을 시작합니다.

---

## 크레딧

*   Developer: **Vaenshine**
*   Special Thanks: **Gey1ist**, **Xiczee**, **Zoomin**
*   Community Support: [iOSGods.com](https://iosgods.com/)

---

## 면책 조항

본 도구는 **보안 연구와 리버스 엔지니어링 학습** 목적으로만 제공됩니다. 불법 사용, 불공정 경쟁, 데이터 탈취 등의 행위에는 사용할 수 없습니다. 사용 중 발생하는 충돌, 데이터 손실, 계정 제한, 기기 이상, 법적 책임은 모두 사용자 본인에게 있습니다.

---

## 중요 안내

이 프로젝트는 무료 비공개 소스 프로젝트이며 **어떠한 형태의 기부도 받지 않습니다**. 개발은 기술 연구와 커뮤니티 교류 목적만을 기반으로 진행됩니다.

---

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=vaenshine/VansonMod&type=Date)](https://star-history.com/#vaenshine/VansonMod&Date)
