# VansonMod

<p align="center">
  <img src="https://repository-images.githubusercontent.com/1109090336/135167c3-e943-48a9-aa0d-67b3c21e844d" alt="VansonMod Social Preview" width="100%"/>
</p>

**Editor de memória iOS, análise de ponteiros, patcher RVA e gestor de processos para TrollStore (jailbreak opcional). Suporta edição Hex, varredura de valores e backup/restauro**

[English](../README.md) | [简体中文](./README_CN.md) | [繁體中文](./README_TW.md) | [العربية](./README_AR.md) | [Deutsch](./README_DE.md) | [Español](./README_ES.md) | [Français](./README_FR.md) | [日本語](./README_JA.md) | [한국어](./README_KO.md) | **Português** | [Русский](./README_RU.md) | [ไทย](./README_TH.md) | [Tiếng Việt](./README_VI.md)

![Platform](https://img.shields.io/badge/Platform-iOS%2014.0%2B-black)
![Support](https://img.shields.io/badge/Support-TrollStore-blue)
![License](https://img.shields.io/badge/License-MIT-green)

> [![Join Telegram](https://img.shields.io/badge/Join-Telegram%20Channel-blue?logo=telegram&logoWidth=20&labelColor=26A5E4&color=white)](https://t.me/VansonMod)

---

## Introdução

**VansonMod** é uma ferramenta independente de depuração para iOS criada para o ambiente **TrollStore**. Ela funciona externamente, sem depender de injeção tweak tradicional, portanto muitos fluxos úteis continuam disponíveis em dispositivos sem jailbreak: seleção de processos, busca de memória, navegador de memória, análise e verificação de ponteiros, análise de assinaturas, scripts e gestão de backups.

Em dispositivos com jailbreak, o VansonMod também desbloqueia fluxos mais profundos ao nível do código, como **RVA Patch** e **monitorização de watchpoints por hardware**. A versão atual deixou de ser apenas um scanner de memória e tornou-se uma estação de trabalho de depuração iOS mais completa.

## Compatibilidade

- **Disponível em TrollStore / sem jailbreak**: seleção de processos, pesquisa de memória, pesquisa próxima, filtro de resultados, navegador de memória, editor Hex, análise e verificação de ponteiros, análise de assinaturas, ferramentas de script, gestão de backups e definições de tema/idioma/ícone.
- **Funções que dependem do task port do processo alvo**: algumas funções em runtime exigem acesso bem-sucedido ao task port do processo alvo; o comportamento real pode variar consoante o ambiente e o estado da app.
- **Recomendado ou limitado a ambientes com jailbreak**: `RVA Patch`, `gestão de registos RVA` e `watchpoints por hardware` são mais adequados para ambientes como **Dopamine / palera1n**.
- **Motivo**: em dispositivos sem jailbreak, o **AMFI** aplica verificações rigorosas de assinatura. Alterar diretamente o segmento executável (`__TEXT`) normalmente faz a app alvo fechar imediatamente.

## Idiomas suportados

- Idiomas integrados: 简体中文, 繁體中文, English, العربية, Deutsch, Español, Français, 日本語, 한국어, Português, Русский, ไทย, Tiếng Việt.

## Navegação

- **App Selection**: ver processos em execução, todas as apps instaladas ou processos do sistema; pesquisar por nome / Bundle ID / PID; anexar, abrir, terminar, fazer backup ou verificar mudanças de código.
- **Memory Debug**: pesquisas exatas, fuzzy, em grupo e por proximidade, filtros de resultados, edição em lote e salto para vistas de valor ou Hex.
- **RVA Debug**: aplicar patches por módulo e offset e gerir registos RVA.
- **Toolbox**: gerir bloqueios de memória, favoritos, ponteiros, RVA, assinaturas, ficheiros de verificação e scripts.
- **Settings**: configurar tema, idioma, ícones, ordem dos separadores, intervalos de busca, tolerância float, limite de resultados e atualizações; também é possível reordenar separadores com um toque longo no menu inferior.

## Destaques

- **Gestão de processos e apps**: vistas `Running / All / System`, nomes localizados, versão, favoritos, cópia de PID / Bundle ID, abertura rápida de apps e encerramento de processos.
- **Pesquisa de memória e edição em lote**: pesquisa exata, fuzzy, em grupo, por intervalo e proximidade, além de filtros maior/menor/entre, escrita fixa, edição incremental, bloqueio em massa e favoritos em massa.
- **Navegador de memória e editor Hex**: salto para endereço, atualização automática, vista de strings, cópia em massa de endereços; o editor Hex suporta `Hex / Split / Text`, edição por linha e saltos por offset.
- **Análise e verificação de ponteiros**: cadeias manuais ou automáticas, modos estático / dinâmico / todos / backtrack, verificação em tempo real, comparação por snapshots e importação/exportação de ficheiros de verificação.
- **Assinaturas e scripts**: análise de assinaturas a partir de qualquer endereço, alcance por módulo, pesquisa global e smart mask; ambiente JavaScript integrado com guias e exemplos visíveis diretamente dentro do VM.
- **RVA, watchpoints e auditoria de processo**: seleção de módulo, patch por offset, predefinições ARM64 e gestão RVA; com jailbreak também há watchpoints por hardware. A auditoria de processo permite ver que posições de código ou valores RVA mudaram antes e depois da execução da app alvo.
- **Experiência e definições**: mudança de tema, idioma, ícones, ordem dos separadores, alcance fuzzy, frequência de lock, evitar suspensão e suporte para iPad split view, modo paisagem e Stage Manager.

## Capturas de ecrã

| <div align="center"><img src="../Screenshots/APP_SELECT.PNG" width="100%" alt="APP_SELECT"/></div> | <div align="center"><img src="../Screenshots/MEM_BROWSER.PNG" width="100%" alt="MEM_BROWSER"/></div> | <div align="center"><img src="../Screenshots/MEM_DEBUG.PNG" width="100%" alt="MEM_DEBUG"/></div> | <div align="center"><img src="../Screenshots/MEM_HEX_MIX.PNG" width="100%" alt="MEM_HEX_MIX"/></div> |
| :------------------------------------------------------------------------------------------------: | :--------------------------------------------------------------------------------------------------: | :------------------------------------------------------------------------------------------------: | :---------------------------------------------------------------------------------------------------: |
| <div align="center"><img src="../Screenshots/RVA_MANAGER.PNG" width="100%" alt="RVA_MANAGER"/></div> | <div align="center"><img src="../Screenshots/POINTER_ANALYSIS.PNG" width="100%" alt="POINTER_ANALYSIS"/></div> | <div align="center"><img src="../Screenshots/POINTER_VERIFY.PNG" width="100%" alt="POINTER_VERIFY"/></div> | <div align="center"><img src="../Screenshots/POINTER_LOCKER.PNG" width="100%" alt="POINTER_LOCKER"/></div> |

---

## Changelog

Veja [Releases](https://github.com/vaenshine/VansonMod/releases).

---

## Instalação

1. Transfira o ficheiro `.tipa` mais recente em [Releases](https://github.com/vaenshine/VansonMod/releases).
2. Instale com **TrollStore**.
3. Abra a app, escolha o processo alvo e comece a depuração.

---

## Créditos

*   Developer: **Vaenshine**
*   Special Thanks: **Gey1ist**, **Xiczee**, **Zoomin**
*   Community Support: [iOSGods.com](https://iosgods.com/)

---

## Aviso legal

Esta ferramenta destina-se apenas a **pesquisa de segurança e aprendizagem de engenharia reversa**. Não deve ser usada para fins ilegais, fraude, recolha indevida de dados ou qualquer abuso. Quaisquer crashes, perdas de dados, limitações de conta, problemas no dispositivo ou responsabilidades legais ficam totalmente a cargo do utilizador.

---

## Declaração importante

Este projeto é gratuito e fechado. **Não aceitamos donativos de qualquer tipo.** O desenvolvimento existe apenas para investigação técnica e partilha com a comunidade.

---

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=vaenshine/VansonMod&type=Date)](https://star-history.com/#vaenshine/VansonMod&Date)
