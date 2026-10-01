# LootBeacon 🎲📣

Compact loot roll bars and one-line roll results for **World of Warcraft: Forever**.
LootBeacon brings back two classic Tekkub addons — **teksLoot** and **GreedBeacon** — rebuilt for the Forever client and styled to match Blizzard's own loot windows.

## 🧠 What It Does

- Replaces Blizzard's loot roll windows with **one compact panel** of rolls you can move anywhere — it keeps its edge in place when you resize it
- Each Need / Greed / Pass button shows **how many players picked it** — point at a button to see who
- **Shift-click** a roll button to skip the "are you sure?" box on Bind on Pickup items
- **Bind on Pickup** items are marked with a small **BoP** in the corner of their icon
- Hides the flood of per-player roll messages in chat and prints **one line per item** with the winner
- Click that line to see **everyone's rolls**; Shift-click it to open Blizzard's Loot Rolls window

## ⚙️ Options

Open `ESC > Options > AddOns > LootBeacon`, or type `/lb` (or `/lootbeacon`).

- `/lb move` — unlock the panel (with sample rolls) so you can drag it into place; right-click it to lock it again
- `/lb test` — show or hide sample bars
- `/lb test 2` — show that many sample bars (up to 20)

You can change the bar size, which way the bars stack, which chat window the results go to, and switch either half of the addon off.

## 🌍 Localization

English, German, French, Spanish, Russian, Portuguese (Brazilian, also used for Portugal), Italian, Korean, Simplified Chinese and Traditional Chinese.
Translations live in `locale.lua` — fixes are welcome as a pull request or an issue.

## 📦 Installation

1. Download or clone this repo into your WoW AddOns folder: `Interface/AddOns/LootBeacon`
   - Using GitHub's **Download ZIP**? Rename the folder from `LootBeacon-main` to exactly `LootBeacon` or the game won't load it.
2. Restart your game, or `/reload` if you're just updating.

## 📋 Requirements

- Supports **World of Warcraft: Forever**
- Using Blizzard's gamepad interface? LootBeacon leaves rolling to Blizzard's gamepad window and still prints the chat results.

## 🙏 Credits

Built on the ideas of **teksLoot** and **GreedBeacon** by Tekkub Stoutwrithe.

## 🛡 License

[MIT License](LICENSE)
