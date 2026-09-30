# Handout

A little help for the hand you’re dealt. Handout is a Balatro mod that lets you choose a randomized reward at the start of each run.

Created and maintained by **aarons**. [NeowBlessings](https://github.com/kjossul/NeowBlessings) provided the inspiration and starting point for this mod. Handout has since taken a substantially different direction and now shares little with the original.

[GitHub repository](https://github.com/aarons/Balatro-Handout)

## Starting rewards

At the start of every run, choose one reward from a horizontal row of cards using the game's own art. Hover or focus a card to see its description, then click or confirm with a controller to claim it. There is no opening character card or dialogue. By default, the four choices are:

- **A random Consumable** — a Tarot, Planet, or Spectral card (or any modded consumable type), added to your consumables area
- **A random Joker** — rolled from the full joker pool with rarity odds respected, e.g. "Burnt Joker"
- **A random Booster pack** — any pack in the game, weighted like the shop, e.g. "Mega Arcana Pack"
- **A random Voucher** — redeemed immediately, e.g. "Clearance Sale Voucher"

The pools are read from the live game registries at run start, so content from other Steamodded mods — jokers (including Legendary and modded rarities like Epic), booster packs, vouchers, and consumables — appears automatically.

## Configuration

Configure up to five reward slots in **Mods > Handout > Config**: None, Consumable, Joker, Booster Pack, Voucher, or Random Choice. Each random award can roll **weighted** (using rarity/shop weights) or **uniform** (every poolable option has equal odds). Changes apply from the next run. The former Money slot is now None, including in saved settings; other saved reward types are preserved. Defaults:

- Joker: weighted (rarity odds respected)
- Booster pack: weighted (shop weights)
- Consumable: uniform — note that in weighted mode, Spectral cards match the shop rate, which is 0 outside the Ghost deck

**Copies** sets how many copies of your selected blessing you receive, from **1–5** (default **1**). Each copy uses the same selected card. Jokers and consumables fill only the slots available under your deck's current limits, accounting for starting cards; excess copies are skipped. Booster copies open one at a time, continuing after you finish or skip each pack. Voucher copies redeem the same voucher repeatedly; the resulting benefit depends on the voucher's effect.

The **Minimum Joker rarity** and **Maximum Joker rarity** sliders set one inclusive range for all Joker reward slots, including Random Choice slots that roll a Joker. Both default to the full range; the maximum displays **Unlimited**, including Legendary and modded rarities even when they cannot appear in shops. Set both to the same rarity to offer only that tier. The sliders stop at each other so the minimum cannot exceed the maximum.

Rarities run from highest to lowest base Joker drop weight (Common → Uncommon → Rare → Legendary in vanilla). Modded rarities are included in this ordering, with rarity keys breaking ties; Steamodded does not define a universal quality rank for custom rarities. Saved bounds use rarity keys so adding mods does not shift them to unrelated tiers; the outermost bounds stay open to new rarities.

Weighted rolls preserve relative rarity weights within the selected range. Rarities with zero base shop weight, including Legendary, receive a base starting-reward weight of `0.01`, before rarity hooks and run modifiers. Uniform rolls give every eligible Joker equal odds. Empty tiers are skipped; if the whole range has no eligible Jokers left, that reward slot is omitted. The range applies to Handout’s direct Joker rewards; shops, packs, and Jokers created by consumables keep their normal rules.

## Install guide

Requires [Steamodded](https://github.com/Steamodded/smods) 1.0 or later.

Download the whole repo as a .zip file and un-zip it in your mods folder. More information in the Steamodded link above.

For local playtesting on macOS, run from this checkout:

```sh
./install.sh
./install.sh --uninstall
```

The installer copies runtime files into `~/Library/Application Support/Balatro/Mods/NeowBlessings`. Run it again after editing the mod, then restart Balatro. Steamodded must already be installed and the Mods folder must exist. To use another installation or platform, set the Mods directory explicitly (requires Bash and rsync):

```sh
BALATRO_MODS_DIR="/path/to/Balatro/Mods" ./install.sh
BALATRO_MODS_DIR="/path/to/Balatro/Mods" ./install.sh --uninstall
```

For upgrade compatibility, Handout retains the internal `NeowBlessings` mod ID and installation folder, the `neow` prefix, and existing random seeds. Saved settings continue to work; the in-game name is Handout.

Uninstall removes only the `NeowBlessings` installation folder. Steamodded's saved preferences and your game saves are preserved.

Run the automated checks with `lua tests/test_rarity.lua`, `lua tests/test_overlay.lua`, and `python3 -m unittest discover -s tests`.

## Future development
- Come up with blessings that give a drawback but also a big bonus, like in StS Curse for a Rare Colorless card, etc.
- Balance and playtesting

## Screenshots (previous interface)
![UI](screenshots/UI.png)

## Other mods

- [Original Neow Blessings](https://github.com/kjossul/NeowBlessings) - Kjossul's original
- [Better Stakes](https://github.com/kjossul/BetterStakes) - A mod for balatro that changes orange and gold stakes, making them easier and reducing the need to reset for a good start.

## Changelog
- Renamed to Handout, with updated author attribution and project links. Existing mod identity and random seeds are retained for compatibility.
- 2.0.0: Migrated to modern Steamodded (1.0+). Blessings are now fully dynamic: always $10, a random Joker (modded rarities supported), a random Booster pack, and a random Voucher, all drawn from the live pools including other mods' content. Removed the hardcoded joker effects table and curated pack list.
- New feat: Tooltips for blessings options that contain extra information or descriptions
- Neow speech bubble bugfix.
- Initial commit.
