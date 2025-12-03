# VansonMod

**The "Big Brain" Memory Tool for TrollStore Gamers**

[![中文说明](https://img.shields.io/badge/Lang-中文-red)](./README_CN.md)
![Platform](https://img.shields.io/badge/Platform-iOS%2014.0%2B-black)
![Support](https://img.shields.io/badge/Support-TrollStore-blue)
![Vibe](https://img.shields.io/badge/Vibe-Epic-orange)

> **Note:** Click the "中文说明" badge above if you prefer reading this in Chinese. Or don't. It's a free country.

---

## 👊 How’s it going bros?

**VansonMod** is here!

Look, I love Jailbreaking, but sometimes you just have **TrollStore** and you feel left out, right? You want to see what's inside those apps, maybe tweak a value or two, but you can't because... sandbox.

So I sat down, drank some G-Fuel (okay, maybe just coffee), and coded this thing. It runs as a Root Helper, which basically means it has superpowers to look into other apps without needing a full jailbreak. **It’s pretty epic.**

## 👏 Meme Review... I mean, Features

### 1. RVA Patcher (The Cool Stuff)
Okay, this is the part I'm actually proud of.
*   **Live Offset Patching:** You know when you find an offset in IDA/Hopper and you're like "Now what?" With this, you just type in the offset, and VansonMod does the math with the ASLR base address. **It just works.**
*   **TrollStore Support:** We are patching assembly instructions live on a non-jailbroken device. Is it the first one to do it like this? Maybe? I don't know, but it's cool.
*   **No Crashy-Crashy:** I added some logic (`mach_vm_protect`) to handle memory permissions automatically. So hopefully, your game won't explode when you try to write to it. Hopefully.
*   **Presets:** I put some buttons like `RET True` and `NOP` so you don't have to remember hex codes. You're welcome.

### 2. Memory Scanner
Classic cheat engine vibes.
*   **Search for Numbers:** Ints, Floats, Doubles... whatever you need.
*   **Search Modes:** "Exact Value" for when you know what you're doing, "Changed/Unchanged" for when you have no clue.
*   **Lock It:** Found your health? Lock it. Become immortal. (In single-player games, please).

### 3. Process Stuff
*   See what's running on your phone.
*   **Attach:** Hook into an app.
*   **Yeet:** Force kill an app if it's acting sus.
*   **Launch:** Open apps directly from here. Why not.

### 4. Hex Editor
*   For the real nerds out there. Look at the raw memory matrix.
*   Jump to addresses like a hacker in a movie.

### 5. Multi-Language
*   It speaks **English**.
*   It speaks **Chinese**.
*   It switches automatically so you don't have to learn a new language just to use it.

## 📥 How to Install

1.  Grab the `.tipa` from [Releases](../../releases).
2.  Throw it into **TrollStore**.
3.  That's it. GG.

## ⚠️ Serious Talk (Disclaimer)

Listen to me, this is important:
*   **This is for EDUCATIONAL PURPOSES.** Don't be that guy.
*   **Don't ruin online games.** Nobody likes a cheater in multiplayer. Small PP energy.
*   **Use at your own risk.** If you mess up your save file or your phone turns into a potato, don't blame me. I'm just a developer on the internet.

---
*Made with ❤️ and zero sleep by Vaenshine © 2025*
*Brofist 👊*
