# VansonMod

**巨魔 (TrollStore) 用户的“大聪明”内存工具**

[![English Readme](https://img.shields.io/badge/Lang-English-blue)](./README.md)
![Platform](https://img.shields.io/badge/Platform-iOS%2014.0%2B-black)
![Support](https://img.shields.io/badge/Support-TrollStore-blue)
![Vibe](https://img.shields.io/badge/Vibe-Epic-orange)

> **提示:** 点击上方的 "English Readme" 徽章切换到英文版。

---

## 👊 兄弟们好！

**VansonMod** 来了！

听着，我知道越狱很酷，但有时候我们只有 **TrollStore**，感觉就像缺了点什么对吧？你想看看 App 内存里到底有啥，或者想改个数值，结果被沙盒挡在外面。

所以我坐下来，喝了亿点点咖啡，敲出了这个东西。它是一个 Root Helper，简单说就是它有超能力，能在不越狱的情况下“偷看”和“修改”其他 App 的内存。**是不是很 Epic？**

## 👏 功能介绍 (The Good Stuff)

### 1. RVA Patcher (这玩意儿很酷)
这是我最喜欢的功能，也是最硬核的部分。
*   **Live Offset Patch:** 你在 IDA 或者 Hopper 里找到了偏移量 (Offset)，然后呢？在这里输入偏移量，工具会自动加上模块基址（ASLR）算出真实地址。**简直是黑魔法。**
*   **TrollStore 环境支持:** 在非越狱环境下直接修改运行中 App 的汇编指令。这可能是（也许是？）同类里比较早支持这个功能的？反正挺好用的。
*   **防手残机制:** 我内置了内存权限管理逻辑 (`mach_vm_protect`)，写入时会自动处理权限。所以理论上，你的游戏不会因为你改了个代码就原地爆炸。理论上。
*   **预设指令:** 我放了几个像 `RET True`、`NOP` 这样的快捷按钮，这样你就不用背 Hex 代码了。不用谢。

### 2. 内存修改器 (CE 既视感)
经典的搜索体验，懂的都懂。
*   **搜什么都行:** Int, Float, Double... 随便搜。
*   **搜索模式:** 知道数值就搜“精确值”，不知道就搜“变大了/变小了”。
*   **锁定数值:** 找到血量了？锁住它。瞬间无敌。（仅限单机哦，兄弟们）。

### 3. 进程管理
*   看看你手机后台都在跑啥。
*   **Attach:** 钩住目标进程。
*   **Kill:** 强制关闭进程（如果它卡住的话）。
*   **Launch:** 直接在这里启动 App。

### 4. Hex 编辑器
*   给真正的技术宅准备的。直接查看原始内存数据。
*   像黑客电影里一样跳转到指定地址。

### 5. 多语言支持
*   支持 **中文** 和 **English**。
*   自动识别系统语言，或者去设置里自己切。

## 📥 安装方法

1.  去 [Releases](../../releases) 下载最新的 `.tipa` 文件。
2.  用 **TrollStore** 安装。
3.  完事。GG。

## ⚠️ 严肃时刻 (免责声明)

听我说，这很重要：
*   **这只是为了学习和研究安全技术。** 别做坏事。
*   **别去搞网络游戏。** 在多人游戏里开挂真的很没品 (Small PP energy)。
*   **后果自负。** 这是一个实验性工具，如果你把存档搞坏了或者手机变砖了，别怪我。我只是个在网上写代码的人。

---
*Made with ❤️ by Vaenshine © 2025*
*Brofist 👊*
