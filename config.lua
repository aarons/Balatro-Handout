-- Default settings; Steamodded persists user changes automatically.
-- slot_type_N uses stable IDs: 1=None, 3=Consumable, 4=Joker,
-- 5=Booster Pack, 6=Voucher, 7=Random Choice. Retired ID 2 acts as None.
-- slot_uniform_N: uniform = every poolable option has equal odds;
-- weighted = mirror the game's own shop/rarity weights.
return {
    copies = 1, -- Copies of the selected blessing, from 1 to 5.
    -- Empty bounds include every rarity, including Legendary and modded ones.
    joker_min_rarity = '',
    joker_max_rarity = '',
    slot_type_1 = 1, -- None
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
