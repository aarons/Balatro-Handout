-- Handout: choose a starting reward at the start of each run.
-- Blessings are resolved from the live card pools when the run starts, so
-- jokers, booster packs, vouchers, and rarities added by other mods are
-- included automatically — no curated lists.

sendDebugMessage("Loaded Handout~")

-- Live config table: defaults come from config.lua, user changes are made in
-- the Mods > Handout > Config tab and persisted by Steamodded.
local config = SMODS.current_mod.config

local function copy_count(value)
    local count = tonumber(value) or 1
    if count ~= count then count = 1 end
    return math.max(1, math.min(5, math.floor(count)))
end

G.FUNCS.nb_copies = function(args)
    config.copies = copy_count(args.to_key)
end

-- The 5 blessing slots each hold one of these types. Indices are what
-- config.slot_type_N stores, so this order must never be reshuffled.
-- Index 2 used to be Money. Keep it as None for existing saved configs.
local TYPE_KEYS = { 'none', 'none', 'consumable', 'joker', 'booster', 'voucher', 'random' }
local TYPE_OPTIONS = { 1, 3, 4, 5, 6, 7 }
-- 'random' resolves to one of these at run start; 'none' is excluded.
local RANDOM_TYPES = { 'consumable', 'joker', 'booster', 'voucher' }

local VANILLA_RARITIES = { Common = 1, Uncommon = 2, Rare = 3, Legendary = 4 }

-- Steamodded has no universal quality rank for custom rarities. Order the
-- range by base Joker drop weight (most common first), with stable key ties.
local function joker_rarities()
    local rarities, seen = {}, {}
    local function add(key, weight)
        if seen[key] then return end
        seen[key] = true
        local definition = SMODS.Rarities[key]
        rarities[#rarities + 1] = {
            key = key,
            weight = weight or (definition and definition.default_weight) or 0,
        }
    end
    for _, rarity in ipairs(SMODS.ObjectTypes.Joker.rarities) do
        add(rarity.key, rarity.weight)
    end
    -- Shop tiers omit Legendary. Include vanilla tiers and all actual Joker
    -- rarity pools, including modded tiers that cannot appear in the shop.
    for key in pairs(VANILLA_RARITIES) do add(key) end
    for id in pairs(G.P_JOKER_RARITY_POOLS or {}) do
        local key = id
        for name, vanilla_id in pairs(VANILLA_RARITIES) do
            if id == vanilla_id then key = name end
        end
        add(key)
    end
    table.sort(rarities, function(a, b)
        if a.weight ~= b.weight then return a.weight > b.weight end
        return a.key < b.key
    end)
    return rarities
end

local function rarity_bounds(rarities)
    local minimum, maximum = 1, #rarities
    for i, rarity in ipairs(rarities) do
        if rarity.key == config.joker_min_rarity then minimum = i end
        if rarity.key == config.joker_max_rarity then maximum = i end
    end
    return math.min(minimum, maximum), math.max(minimum, maximum)
end

-- The base game only calls slider callbacks for mouse dragging, not controller
-- input. A local UI update function handles both and keeps the bounds ordered.
G.FUNCS.nb_rarity_slider = function(e)
    G.FUNCS.slider(e)
    local bar = e.children[1]
    local args = bar.config.ref_table
    local state = args.ref_table
    -- Retain fractional controller movement: rounding the backing value every
    -- frame would discard the game's 1%-of-range directional steps.
    local position = state[args.ref_value]
    if args.ref_value == 'minimum' then
        position = math.max(1, math.min(position, math.floor(state.maximum + 0.5)))
    else
        position = math.min(#state.rarities, math.max(position, math.floor(state.minimum + 0.5)))
    end
    state[args.ref_value] = position
    local value = math.floor(position + 0.5)
    local is_endpoint = (args.ref_value == 'minimum' and value == 1)
        or (args.ref_value == 'maximum' and value == #state.rarities)
    config[args.config_key] = is_endpoint and '' or state.rarities[value].key
    args.text = localize(args.ref_value == 'maximum' and is_endpoint
        and 'nb_unlimited' or ('k_' .. state.rarities[value].key:lower()))
    bar.T.w = (value - args.min) / (args.max - args.min) * args.w
    bar.config.w = bar.T.w
end

local function rarity_slider(state, bound, config_key, label)
    local slider = create_slider {
        label = localize(label), label_scale = 0.35,
        ref_table = state, ref_value = bound, config_key = config_key,
        min = 1, max = math.max(2, #state.rarities), decimal_places = 0,
        w = 2.2, h = 0.3, text_scale = 0.28,
    }
    local function prepare(node)
        if node.config.func == 'slider' then node.config.func = 'nb_rarity_slider' end
        if node.config.minw == 0.8 then node.config.minw = 1.8 end
        for _, child in ipairs(node.nodes or {}) do prepare(child) end
    end
    prepare(slider)
    return slider
end

G.FUNCS.nb_slot_type = function(args)
    config['slot_type_' .. args.cycle_config.nb_slot] = TYPE_OPTIONS[args.to_key]
end

SMODS.current_mod.config_tab = function()
    local type_names = {}
    for i, id in ipairs(TYPE_OPTIONS) do type_names[i] = localize('nb_type_' .. TYPE_KEYS[id]) end
    local rows = {}
    rows[#rows + 1] = {n = G.UIT.R, config = { align = 'cm', padding = 0.03 }, nodes = {
        create_option_cycle {
            label = localize('nb_copies'), options = { '1', '2', '3', '4', '5' },
            current_option = copy_count(config.copies), opt_callback = 'nb_copies',
            w = 3.2, scale = 0.7, colour = G.C.RED,
        },
    }}
    rows[#rows + 1] = {n = G.UIT.R, config = { align = 'cm', padding = 0.03 }, nodes = {
        {n = G.UIT.T, config = { text = localize('nb_copies_info'), scale = 0.3, colour = G.C.UI.TEXT_LIGHT }},
    }}
    for i = 1, 5 do
        local current_option = 1
        for option, id in ipairs(TYPE_OPTIONS) do
            if config['slot_type_' .. i] == id then current_option = option end
        end
        rows[#rows + 1] = {n = G.UIT.R, config = { align = "cm", padding = 0.03 }, nodes = {
            {n = G.UIT.C, config = { align = "cm", minw = 4.5 }, nodes = {
                create_option_cycle {
                    label = localize('nb_blessing') .. ' ' .. i,
                    options = type_names,
                    current_option = current_option,
                    opt_callback = 'nb_slot_type',
                    nb_slot = i,
                    w = 3.2, scale = 0.7, colour = G.C.RED,
                },
            }},
            {n = G.UIT.C, config = { align = "cm", minw = 3 }, nodes = {
                create_toggle { label = localize('nb_uniform'), ref_table = config, ref_value = 'slot_uniform_' .. i },
            }},
        }}
    end
    rows[#rows + 1] = {n = G.UIT.R, config = { align = "cm", padding = 0.05 }, nodes = {
        {n = G.UIT.T, config = { text = localize('nb_uniform_info'), scale = 0.3, colour = G.C.UI.TEXT_LIGHT }},
    }}
    local rarities = joker_rarities()
    if #rarities > 0 then
        local minimum, maximum = rarity_bounds(rarities)
        local state = { minimum = minimum, maximum = maximum, rarities = rarities }
        rows[#rows + 1] = {n = G.UIT.R, config = { align = 'cm', padding = 0.03 }, nodes = {
            {n = G.UIT.C, config = { align = 'cm' }, nodes = {
                rarity_slider(state, 'minimum', 'joker_min_rarity', 'nb_min_rarity'),
            }},
            {n = G.UIT.C, config = { align = 'cm' }, nodes = {
                rarity_slider(state, 'maximum', 'joker_max_rarity', 'nb_max_rarity'),
            }},
        }}
        rows[#rows + 1] = {n = G.UIT.R, config = { align = 'cm', padding = 0.03 }, nodes = {
            {n = G.UIT.T, config = { text = localize('nb_rarity_info'), scale = 0.3, colour = G.C.UI.TEXT_LIGHT }},
        }}
    end
    return {n = G.UIT.ROOT, config = { align = "cm", padding = 0.05, colour = G.C.CLEAR }, nodes = rows}
end

-- Every poller takes a seed (unique per slot, so two slots of the same type
-- roll independently) and an exclude set of center keys already rolled by
-- earlier slots this run, so duplicate slots never offer the same card.

-- get_current_pool marks banned/duplicate/out-of-pool entries as 'UNAVAILABLE'
local function pool_choices(_type, exclude)
    local pool = get_current_pool(_type)
    local choices = {}
    for _, key in ipairs(pool) do
        if key ~= 'UNAVAILABLE' and not exclude[key] then choices[#choices + 1] = key end
    end
    return choices
end

-- Filter before rolling rarity, so empty/excluded tiers cannot consume a slot.
-- Explicit rarity names avoid get_current_pool's numeric rarity-roll API.
local function poll_joker(uniform, seed, exclude)
    local rarities = joker_rarities()
    local minimum, maximum = rarity_bounds(rarities)
    local all_choices, weighted, total = {}, {}, 0
    for i = minimum, maximum do
        local rarity = rarities[i]
        local rarity_id = VANILLA_RARITIES[rarity.key] or rarity.key
        local choices, seen = {}, {}
        local pool = get_current_pool('Joker', rarity.key, nil, seed)
        for _, key in ipairs(pool) do
            local center = G.P_CENTERS[key]
            -- The game's empty-pool fallback may be a Common Joker. Never
            -- let that bypass the selected range or duplicate exclusions.
            if center and center.rarity == rarity_id and not seen[key]
                and (center.unlocked ~= false or rarity_id == 4)
                and not center.demo and not center.hidden
                and not G.GAME.banned_keys[key] and not G.GAME.used_jokers[key]
                and not exclude[key] then
                choices[#choices + 1] = key
                all_choices[#all_choices + 1] = key
                seen[key] = true
            end
        end
        if not uniform and #choices > 0 then
            -- Soul-only rarities have no shop weight, but can be blessings.
            local weight = rarity.weight > 0 and rarity.weight or 0.01
            local definition = SMODS.Rarities[rarity.key]
            if definition and definition.get_weight then
                weight = definition:get_weight(weight, SMODS.ObjectTypes.Joker)
            end
            weight = weight * (G.GAME[rarity.key:lower() .. '_mod'] or 1)
            if weight > 0 then
                total = total + weight
                weighted[#weighted + 1] = { choices = choices, cume = total }
            end
        end
    end
    if uniform then
        if #all_choices == 0 then return nil end
        return pseudorandom_element(all_choices, pseudoseed(seed))
    end
    if total == 0 then return nil end
    local roll = pseudorandom(pseudoseed(seed .. '_rarity')) * total
    for _, entry in ipairs(weighted) do
        if roll < entry.cume then
            return pseudorandom_element(entry.choices, pseudoseed(seed))
        end
    end
end

-- The shop pool (get_current_pool) at run start contains only base-tier
-- vouchers — upgraded tiers are unavailable until their prerequisite is
-- redeemed — and it's the same pool the ante-1 shop draws from. Roll over
-- the full voucher registry instead, and exclude whatever the first shop
-- has already queued so the blessing never duplicates it.
local function poll_voucher(seed, exclude)
    local queued = {}
    local shop = G.GAME.current_round and G.GAME.current_round.voucher
    if type(shop) == 'string' then
        queued[shop] = true
    elseif type(shop) == 'table' then
        for _, key in ipairs(shop) do queued[key] = true end
    end
    local choices = {}
    for _, v in ipairs(G.P_CENTER_POOLS.Voucher) do
        if v.unlocked ~= false and not G.GAME.banned_keys[v.key]
            and not G.GAME.used_vouchers[v.key] and not queued[v.key]
            and not exclude[v.key] then
            choices[#choices + 1] = v.key
        end
    end
    return pseudorandom_element(choices, pseudoseed(seed))
end

-- Rolls over every consumable type (Tarot, Planet, Spectral, plus modded
-- types via SMODS.ConsumableType). Types are sorted so the roll stays
-- deterministic for a given seed. Uniform: one flat pool, equal odds for
-- every card. Weighted: type picked by its shop rate (Spectral is rate 0
-- outside the Ghost deck, matching the shop), then uniform within the type.
local function poll_consumable(uniform, seed, exclude)
    local types = {}
    for key in pairs(SMODS.ConsumableType.obj_table) do types[#types + 1] = key end
    table.sort(types)
    if uniform then
        local choices = {}
        for _, _type in ipairs(types) do
            for _, key in ipairs(pool_choices(_type, exclude)) do choices[#choices + 1] = key end
        end
        return pseudorandom_element(choices, pseudoseed(seed))
    end
    local pool, cume = {}, 0
    for _, _type in ipairs(types) do
        local rate = G.GAME[_type:lower() .. '_rate'] or 0
        if rate > 0 then
            local choices = pool_choices(_type, exclude)
            if #choices > 0 then
                cume = cume + rate
                pool[#pool + 1] = { choices = choices, cume = cume }
            end
        end
    end
    if cume == 0 then return nil end
    local poll = pseudorandom(pseudoseed(seed .. '_type')) * cume
    for _, entry in ipairs(pool) do
        if poll <= entry.cume then
            return pseudorandom_element(entry.choices, pseudoseed(seed))
        end
    end
end

-- Roll over every registered booster pack, vanilla and modded. Weighted
-- mirrors get_pack() without its guaranteed first-shop Buffoon pack; uniform
-- gives every pack equal odds (zero-weight packs stay excluded — mods use
-- weight 0 to disable a pack).
local function poll_booster(uniform, seed, exclude)
    local pool, cume = {}, 0
    for _, v in ipairs(G.P_CENTER_POOLS.Booster) do
        if not G.GAME.banned_keys[v.key] and not exclude[v.key] then
            local w = (v.get_weight and v:get_weight()) or v.weight or 1
            if w > 0 then
                cume = cume + w
                pool[#pool + 1] = { center = v, cume = cume }
            end
        end
    end
    if uniform then
        local entry = pseudorandom_element(pool, pseudoseed(seed))
        return entry and entry.center
    end
    local poll = pseudorandom(pseudoseed(seed)) * cume
    for _, entry in ipairs(pool) do
        if poll <= entry.cume then return entry.center end
    end
end

local function has_room(area, buffer)
    -- Refresh modded slot usage as well as deck limits before every copy.
    if area.handle_card_limit then area:handle_card_limit() end
    -- Steamodded's card_limit already subtracts extra slots used by cards.
    return #area.cards + (buffer or 0) < area.config.card_limit
end

local function add_joker(key)
    if not has_room(G.jokers, G.GAME.joker_buffer) then return end
    local card = SMODS.add_card { set = 'Joker', key = key }
    if card then
        card:start_materialize()
        G.GAME.used_jokers[key] = true
    end
end

local function add_consumable(key)
    if not has_room(G.consumeables, G.GAME.consumeable_buffer) then return end
    local center = G.P_CENTERS[key]
    local card = SMODS.add_card { set = center.set, key = key }
    if card then
        card:start_materialize()
        G.GAME.used_jokers[key] = true
    end
end

local function open_booster(center)
    local card = Card(G.play.T.x + G.play.T.w / 2 - G.CARD_W * 1.27 / 2,
        G.play.T.y + G.play.T.h / 2 - G.CARD_H * 1.27 / 2, G.CARD_W * 1.27, G.CARD_H * 1.27,
        G.P_CARDS.empty, center, { bypass_discovery_center = true, bypass_discovery_ui = true })
    card.cost = 0
    G.FUNCS.use_card({ config = { ref_table = card } })
    card:start_materialize()
end

-- A pack must finish (including Skip) before the next copy can open.
local pending_boosters
local end_consumeable_ref = G.FUNCS.end_consumeable
G.FUNCS.end_consumeable = function(e, delayfac)
    local result = end_consumeable_ref(e, delayfac)
    local pending = pending_boosters
    if pending and not pending.waiting then
        pending.waiting = true
        G.E_MANAGER:add_event(Event({
            trigger = 'after', delay = 1.1 * (delayfac or 1),
            blocking = false, blockable = false,
            func = function()
                if pending_boosters ~= pending then return true end
                if G.GAME.PACK_INTERRUPT or G.booster_pack then return false end
                pending.remaining = pending.remaining - 1
                pending.waiting = false
                if pending.remaining == 0 then pending_boosters = nil end
                open_booster(pending.center)
                return true
            end,
        }))
    end
    return result
end

local function open_boosters(center, copies)
    if copies > 1 then pending_boosters = { center = center, remaining = copies - 1 } end
    open_booster(center)
end

local function redeem_voucher(center)
    local card = Card(G.play.T.x + G.play.T.w / 2 - G.CARD_W / 2,
        G.play.T.y + G.play.T.h / 2 - G.CARD_H / 2, G.CARD_W, G.CARD_H,
        G.P_CARDS.empty, center, { bypass_discovery_center = true, bypass_discovery_ui = true })
    card.cost = 0
    card:start_materialize()
    G.E_MANAGER:add_event(Event({
        trigger = 'after',
        delay = 0.7,
        func = function()
            card:redeem()
            card:start_dissolve()
            return true
        end
    }))
end

-- Roll every configured slot up front so the player sees exactly what each
-- option grants before choosing. 'rolled' collects every center key already
-- offered this run so duplicate slots never present the same card twice.
local function resolve_blessings()
    local blessings = {}
    local copies = copy_count(config.copies)
    local rolled = {}
    for slot = 1, 5 do
        local _type = TYPE_KEYS[config['slot_type_' .. slot] or 1] or 'none'
        local uniform = config['slot_uniform_' .. slot]
        if _type == 'random' then
            _type = pseudorandom_element(RANDOM_TYPES, pseudoseed('neow_slot_' .. slot))
        end
        local seed = 'neow_' .. _type .. '_' .. slot
        if _type == 'consumable' then
            local key = poll_consumable(uniform, seed, rolled)
            if key then
                rolled[key] = true
                local center = G.P_CENTERS[key]
                blessings[#blessings + 1] = {
                    center = center,
                    f = function() for _ = 1, copies do add_consumable(key) end end
                }
            end
        elseif _type == 'joker' then
            local key = poll_joker(uniform, seed, rolled)
            if key then
                rolled[key] = true
                blessings[#blessings + 1] = {
                    center = G.P_CENTERS[key],
                    f = function() for _ = 1, copies do add_joker(key) end end
                }
            end
        elseif _type == 'booster' then
            local center = poll_booster(uniform, seed, rolled)
            if center then
                rolled[center.key] = true
                blessings[#blessings + 1] = {
                    center = center,
                    f = function() open_boosters(center, copies) end
                }
            end
        elseif _type == 'voucher' then
            local key = poll_voucher(seed, rolled)
            if key then
                rolled[key] = true
                blessings[#blessings + 1] = {
                    center = G.P_CENTERS[key],
                    f = function() for _ = 1, copies do redeem_voucher(G.P_CENTERS[key]) end end
                }
            end
        end
    end
    return blessings
end

-- Use real Cards so vanilla and modded art, animations, and descriptions
-- behave just like the collection. These previews never enter the deck.
local function create_blessings_overlay(blessings)
    G.SETTINGS.paused = true
    local area = CardArea(G.ROOM.T.x, G.ROOM.T.y,
        ((#blessings - 1) * 1.4 + 1.27) * G.CARD_W, G.CARD_H * 1.5,
        { card_limit = #blessings, type = 'title', highlight_limit = 0,
            card_w = G.CARD_W * 1.27 })
    local chosen = false
    local overlay
    for _, blessing in ipairs(blessings) do
        local scale = blessing.center.set == 'Booster' and 1.27 or 1
        local card = Card(area.T.x, area.T.y, G.CARD_W * scale, G.CARD_H * scale,
            G.P_CARDS.empty, blessing.center, {
                bypass_discovery_center = true, bypass_discovery_ui = true, bypass_lock = true,
            })
        card.states.drag.can = false
        -- Mouse clicks and controller confirmation both use Card:click.
        -- Keep this override local to the preview, leaving normal cards alone.
        card.click = function()
            if chosen or not overlay or G.OVERLAY_MENU ~= overlay then return end
            chosen = true
            -- Remove every preview and unpause before applying the reward,
            -- especially when a booster opens its own selection screen.
            G.FUNCS.exit_overlay_menu()
            blessing.f()
        end
        area:emplace(card)
    end

    G.FUNCS.overlay_menu {
        definition = create_UIBox_generic_options {
            no_back = true,
            contents = {
                {n = G.UIT.O, config = { object = area }},
            },
        },
        config = { no_esc = true }
    }
    overlay = G.OVERLAY_MENU
    G.CONTROLLER:snap_to { node = area.cards[1] }
end

local function draw_blessings_overlay()
    -- Every slot set to None (or all pools empty): start the run normally.
    local blessings = resolve_blessings()
    if #blessings == 0 then return end
    create_blessings_overlay(blessings)
end

local game_start_run_ref = Game.start_run
function Game.start_run(self, args)
    pending_boosters = nil
    local result = game_start_run_ref(self, args)
    if not (args and args.savetext) then -- it's a new game
        draw_blessings_overlay()
    end
    return result
end
