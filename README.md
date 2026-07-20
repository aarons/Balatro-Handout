# Neow Blessings Fork

The original excellent work and concept is here: https://github.com/kjossul/NeowBlessings

I wanted something with more randomized rewards, but also more consistent categories than the original.

## Blessings

Neow has transformed into a cute little card! This is a mod for balatro that gives you 4 blessings at the start of your run, inspired from Slay the Spire.

At the start of every run, Neow offers 4 blessings. The options are resolved up front, so you see exactly what you're choosing:

- **Get $10**
- **A random Joker** — rolled from the full joker pool with rarity odds respected, e.g. "Burnt Joker"
- **A random Booster pack** — any pack in the game, weighted like the shop, e.g. "Mega Arcana Pack"
- **A random Voucher** — redeemed immediately, e.g. "Clearance Sale Voucher"

The pools are read from the live game registries at run start, so content from other Steamodded mods — jokers (including modded rarities like Epic), booster packs, and vouchers — appears automatically. Legendary jokers are excluded, as they only spawn through the Soul.

## Install guide

Requires [Steamodded](https://github.com/Steamodded/smods) 1.0 or later.

Download the whole repo as a .zip file and un-zip it in your mods folder. More information in the Steamodded link above.


## Future development
- Make a better card for Neow
- Come up with blessings that give a drawback but also a big bonus, like in StS Curse for a Rare Colorless card, etc.
- Balance and playtesting

## Screenshots
![UI](screenshots/UI.png)

## Other mods

- [Original Neow Blessings](https://github.com/kjossul/NeowBlessings) - Kjossul's original
- [Better Stakes](https://github.com/kjossul/BetterStakes) - A mod for balatro that changes orange and gold stakes, making them easier and reducing the need to reset for a good start.

## Changelog
- 2.0.0: Migrated to modern Steamodded (1.0+). Blessings are now fully dynamic: always $10, a random Joker (modded rarities supported), a random Booster pack, and a random Voucher, all drawn from the live pools including other mods' content. Removed the hardcoded joker effects table and curated pack list.
- New feat: Tooltips for blessings options that contain extra information or descriptions
- Neow speech bubble bugfix.
- Initial commit.
