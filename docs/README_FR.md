# VansonMod

<p align="center">
  <img src="https://repository-images.githubusercontent.com/1109090336/135167c3-e943-48a9-aa0d-67b3c21e844d" alt="VansonMod Social Preview" width="100%"/>
</p>

**Éditeur mémoire iOS, analyse de pointeurs, patcher RVA et gestionnaire de processus pour TrollStore (jailbreak optionnel). Compatible avec l’édition Hex, le scan de valeurs et la sauvegarde/restauration**

[English](../README.md) | [简体中文](./README_CN.md) | [繁體中文](./README_TW.md) | [العربية](./README_AR.md) | [Deutsch](./README_DE.md) | [Español](./README_ES.md) | **Français** | [日本語](./README_JA.md) | [한국어](./README_KO.md) | [Português](./README_PT.md) | [Русский](./README_RU.md) | [ไทย](./README_TH.md) | [Tiếng Việt](./README_VI.md)

![Platform](https://img.shields.io/badge/Platform-iOS%2014.0%2B-black)
![Support](https://img.shields.io/badge/Support-TrollStore-blue)
![License](https://img.shields.io/badge/License-MIT-green)

> [![Join Telegram](https://img.shields.io/badge/Join-Telegram%20Channel-blue?logo=telegram&logoWidth=20&labelColor=26A5E4&color=white)](https://t.me/VansonMod)

---

## Introduction

**VansonMod** est un outil indépendant de débogage iOS conçu pour l’environnement **TrollStore**. Il fonctionne en externe, sans dépendre d’une injection tweak classique, ce qui permet de conserver de nombreux flux utiles sur les appareils non jailbreakés : sélection de processus, recherche mémoire, navigation mémoire, analyse et vérification de pointeurs, analyse de signatures, scripts et gestion des sauvegardes.

Sur les appareils jailbreakés, VansonMod ouvre aussi des flux plus profonds au niveau du code, comme **RVA Patch** et la **surveillance par watchpoints matériels**. La version actuelle va bien au-delà d’un simple moteur de recherche mémoire et devient un espace de travail de débogage iOS plus complet.

## Compatibilité

- **Disponible sur TrollStore / sans jailbreak** : sélection de processus, recherche mémoire, recherche de proximité, filtrage des résultats, navigateur mémoire, éditeur Hex, analyse et vérification de pointeurs, analyse de signatures, scripts, gestion des sauvegardes et réglages thème/langue/icône.
- **Fonctions dépendant du task port cible** : certaines fonctions runtime nécessitent l’accès au task port du processus cible ; le comportement réel peut varier selon l’environnement et l’état de l’app.
- **Recommandé ou limité au jailbreak** : `RVA Patch`, `gestion des enregistrements RVA` et `watchpoints matériels` sont plus adaptés à des environnements comme **Dopamine / palera1n**.
- **Pourquoi** : sur un appareil non jailbreaké, **AMFI** applique des vérifications strictes de signature. Modifier directement le segment exécutable (`__TEXT`) provoque généralement un crash immédiat de l’app cible.

## Langues prises en charge

- Langues intégrées : 简体中文, 繁體中文, English, العربية, Deutsch, Español, Français, 日本語, 한국어, Português, Русский, ไทย, Tiếng Việt.

## Navigation

- **App Selection** : afficher les processus en cours, toutes les apps installées ou les processus système ; recherche par nom / Bundle ID / PID ; attacher, ouvrir, tuer, sauvegarder ou inspecter les changements de code.
- **Memory Debug** : recherches exactes, fuzzy, groupées et de proximité, filtrage des résultats, édition en lot, et saut vers les vues valeur ou Hex.
- **RVA Debug** : appliquer des patchs par module et offset, et gérer les enregistrements RVA.
- **Toolbox** : gérer verrous mémoire, favoris, pointeurs, RVA, signatures, fichiers de vérification et scripts.
- **Settings** : configurer thème, langue, icônes, ordre des onglets, plages de recherche, tolérance float, limite de résultats et mises à jour ; l’ordre des onglets peut aussi être modifié rapidement par un appui long sur le menu du bas.

## Points forts

- **Gestion des processus et applications** : vues `Running / All / System`, noms localisés, affichage de version, favoris, copie de PID / Bundle ID, lancement rapide d’app et arrêt de processus.
- **Recherche mémoire et édition en lot** : modes exact, fuzzy, groupé, intervalle et proximité, filtres supérieur / inférieur / entre, écriture fixe, édition incrémentale, verrouillage massif et favoris massifs.
- **Navigateur mémoire et éditeur Hex** : saut d’adresse, rafraîchissement auto, vue chaîne, copie d’adresses en lot ; l’éditeur Hex propose les modes `Hex / Split / Text`, l’édition par ligne et le saut par offset.
- **Analyse et vérification de pointeurs** : chaînes manuelles ou automatiques, modes statique / dynamique / tous / backtrack, vérification temps réel, comparaison par snapshot et import/export de fichiers de vérification.
- **Signatures et scripts** : analyse de signature depuis n’importe quelle adresse, portée par module, recherche globale, smart mask ; environnement JavaScript intégré avec guides et exemples consultables directement dans VM.
- **RVA, watchpoints et audit de processus** : sélection de module, patch par offset, presets ARM64 et gestion RVA ; les watchpoints matériels sont disponibles en jailbreak. L’audit de processus permet de voir quelles positions de code ou valeurs RVA ont changé avant et après l’exécution de l’app cible.
- **Expérience et réglages** : changement de thème, langue, icônes, ordre des onglets, portée fuzzy, fréquence de verrouillage, anti-veille, prise en charge iPad split view, paysage et Stage Manager.

## Captures d’écran

| <div align="center"><img src="../Screenshots/APP_SELECT.PNG" width="100%" alt="APP_SELECT"/></div> | <div align="center"><img src="../Screenshots/MEM_BROWSER.PNG" width="100%" alt="MEM_BROWSER"/></div> | <div align="center"><img src="../Screenshots/MEM_DEBUG.PNG" width="100%" alt="MEM_DEBUG"/></div> | <div align="center"><img src="../Screenshots/MEM_HEX_MIX.PNG" width="100%" alt="MEM_HEX_MIX"/></div> |
| :------------------------------------------------------------------------------------------------: | :--------------------------------------------------------------------------------------------------: | :------------------------------------------------------------------------------------------------: | :---------------------------------------------------------------------------------------------------: |
| <div align="center"><img src="../Screenshots/RVA_MANAGER.PNG" width="100%" alt="RVA_MANAGER"/></div> | <div align="center"><img src="../Screenshots/POINTER_ANALYSIS.PNG" width="100%" alt="POINTER_ANALYSIS"/></div> | <div align="center"><img src="../Screenshots/POINTER_VERIFY.PNG" width="100%" alt="POINTER_VERIFY"/></div> | <div align="center"><img src="../Screenshots/POINTER_LOCKER.PNG" width="100%" alt="POINTER_LOCKER"/></div> |

---

## Changelog

Consultez [Releases](https://github.com/vaenshine/VansonMod/releases).

---

## Installation

1. Téléchargez le dernier fichier `.tipa` depuis [Releases](https://github.com/vaenshine/VansonMod/releases).
2. Installez-le avec **TrollStore**.
3. Lancez l’app, choisissez un processus cible et commencez le débogage.

---

## Crédits

*   Developer: **Vaenshine**
*   Special Thanks: **Gey1ist**, **Xiczee**, **Zoomin**
*   Community Support: [iOSGods.com](https://iosgods.com/)

---

## Avertissement

Cet outil est fourni uniquement pour la **recherche en sécurité et l’apprentissage du reverse engineering**. Il ne doit pas être utilisé à des fins illégales, de triche, de vol de données ou d’abus. Tous les crashs, pertes de données, restrictions de compte, problèmes d’appareil et responsabilités légales restent à la charge de l’utilisateur.

---

## Déclaration importante

Ce projet est gratuit et fermé source. **Nous n’acceptons aucune forme de don.** Le développement est motivé uniquement par la recherche technique et les échanges de la communauté.

---

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=vaenshine/VansonMod&type=Date)](https://star-history.com/#vaenshine/VansonMod&Date)
