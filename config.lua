-- Default settings; Steamodded persists user changes automatically.
-- slot_type_N indexes the blessing-type list (None, Money, Consumable,
-- Joker, Booster Pack, Voucher, Random Choice) for each of the 5 slots.
-- slot_uniform_N: uniform = every poolable option has equal odds;
-- weighted = mirror the game's own shop/rarity weights.
return {
    slot_type_1 = 2, -- Money
    slot_type_2 = 3, -- Consumable
    slot_type_3 = 4, -- Joker
    slot_type_4 = 5, -- Booster Pack
    slot_type_5 = 6, -- Voucher
    slot_uniform_1 = false,
    slot_uniform_2 = true,
    slot_uniform_3 = false,
    slot_uniform_4 = false,
    slot_uniform_5 = false,
}
