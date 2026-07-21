-- Neow Blessings: choose one of 4 blessings at the start of each run.
-- Blessings are resolved from the live card pools when the run starts, so
-- jokers, booster packs, vouchers, and rarities added by other mods are
-- included automatically — no curated lists.

sendDebugMessage("Loaded NeowBlessings~")

-- Live config table: defaults come from config.lua, user changes are made in
-- the Mods > Neow Blessings > Config tab and persisted by Steamodded.
local config = SMODS.current_mod.config

SMODS.current_mod.config_tab = function()
    return {n = G.UIT.ROOT, config = { align = "cm", padding = 0.05, colour = G.C.CLEAR }, nodes = {
        {n = G.UIT.R, config = { align = "cm", padding = 0.05 }, nodes = {
            create_toggle { label = localize('nb_uniform_joker'), ref_table = config, ref_value = 'uniform_joker' },
        }},
        {n = G.UIT.R, config = { align = "cm", padding = 0.05 }, nodes = {
            create_toggle { label = localize('nb_uniform_booster'), ref_table = config, ref_value = 'uniform_booster' },
        }},
        {n = G.UIT.R, config = { align = "cm", padding = 0.05 }, nodes = {
            create_toggle { label = localize('nb_uniform_consumable'), ref_table = config, ref_value = 'uniform_consumable' },
        }},
    }}
end

SMODS.Atlas {
    key = 'jimbo',
    path = 'j_neow.png',
    px = 71,
    py = 95,
}

-- Stand-in center for the Neow character card shown on the blessing screen.
-- Not registered as a real Joker so it can never enter any pool.
local j_neow = {
    -- key must be 'c_base' so SMODS.get_enhancements treats this card as
    -- unenhanced; any other value (including nil) crashes enhancement lookups
    key = 'c_base',
    order = 151, unlocked = true, start_alerted = true, discovered = true,
    blueprint_compat = true, eternal_compat = true, rarity = 1, cost = 2,
    name = "neow", pos = { x = 0, y = 0 }, set = "Default", effect = "Base",
    cost_mult = 1.0, config = {}, atlas = 'neow_jimbo',
}

local function center_name(center)
    local group = G.localization.descriptions[center.set]
    if group and group[center.key] and group[center.key].name then
        return localize { type = 'name_text', set = center.set, key = center.key }
    end
    return center.name or center.key
end

-- get_current_pool marks banned/duplicate/out-of-pool entries as 'UNAVAILABLE'
local function pool_choices(_type, _rarity)
    local pool = get_current_pool(_type, _rarity)
    local choices = {}
    for _, key in ipairs(pool) do
        if key ~= 'UNAVAILABLE' then choices[#choices + 1] = key end
    end
    return choices
end

-- Weighted: with no rarity argument, Steamodded's get_current_pool polls the
-- rarity itself via SMODS.poll_rarity, respecting modded rarities and their
-- weights. Uniform: every poolable joker has equal odds regardless of rarity
-- (legendaries stay excluded — they only spawn through the Soul).
local function poll_joker()
    if config.uniform_joker then
        local choices = {}
        for _, v in ipairs(G.P_CENTER_POOLS.Joker) do
            if v.unlocked ~= false and not v.demo and not v.hidden and v.rarity ~= 4
                and not G.GAME.banned_keys[v.key] and not G.GAME.used_jokers[v.key] then
                choices[#choices + 1] = v.key
            end
        end
        return pseudorandom_element(choices, pseudoseed('neow_joker'))
    end
    return pseudorandom_element(pool_choices('Joker'), pseudoseed('neow_joker'))
end

local function poll_voucher()
    return pseudorandom_element(pool_choices('Voucher'), pseudoseed('neow_voucher'))
end

-- Rolls over every consumable type (Tarot, Planet, Spectral, plus modded
-- types via SMODS.ConsumableType). Types are sorted so the roll stays
-- deterministic for a given seed. Uniform: one flat pool, equal odds for
-- every card. Weighted: type picked by its shop rate (Spectral is rate 0
-- outside the Ghost deck, matching the shop), then uniform within the type.
local function poll_consumable()
    local types = {}
    for key in pairs(SMODS.ConsumableType.obj_table) do types[#types + 1] = key end
    table.sort(types)
    if config.uniform_consumable then
        local choices = {}
        for _, _type in ipairs(types) do
            for _, key in ipairs(pool_choices(_type)) do choices[#choices + 1] = key end
        end
        return pseudorandom_element(choices, pseudoseed('neow_consumable'))
    end
    local pool, cume = {}, 0
    for _, _type in ipairs(types) do
        local rate = G.GAME[_type:lower() .. '_rate'] or 0
        if rate > 0 then
            local choices = pool_choices(_type)
            if #choices > 0 then
                cume = cume + rate
                pool[#pool + 1] = { choices = choices, cume = cume }
            end
        end
    end
    if cume == 0 then return nil end
    local poll = pseudorandom(pseudoseed('neow_consumable_type')) * cume
    for _, entry in ipairs(pool) do
        if poll <= entry.cume then
            return pseudorandom_element(entry.choices, pseudoseed('neow_consumable'))
        end
    end
end

-- Roll over every registered booster pack, vanilla and modded. Weighted
-- mirrors get_pack() without its guaranteed first-shop Buffoon pack; uniform
-- gives every pack equal odds (zero-weight packs stay excluded — mods use
-- weight 0 to disable a pack).
local function poll_booster()
    local pool, cume = {}, 0
    for _, v in ipairs(G.P_CENTER_POOLS.Booster) do
        if not G.GAME.banned_keys[v.key] then
            local w = (v.get_weight and v:get_weight()) or v.weight or 1
            if w > 0 then
                cume = cume + w
                pool[#pool + 1] = { center = v, cume = cume }
            end
        end
    end
    if config.uniform_booster then
        local entry = pseudorandom_element(pool, pseudoseed('neow_pack'))
        return entry and entry.center
    end
    local poll = pseudorandom(pseudoseed('neow_pack')) * cume
    for _, entry in ipairs(pool) do
        if poll <= entry.cume then return entry.center end
    end
end

local function add_joker(key)
    local card = SMODS.add_card { set = 'Joker', key = key }
    if card then
        card:start_materialize()
        G.GAME.used_jokers[key] = true
    end
end

local function add_consumable(key)
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

-- Roll the four blessings up front so the player sees exactly what each
-- option grants before choosing.
local function resolve_blessings()
    local blessings = {
        {
            label = { localize('nb_ten_dollars') },
            colour = G.C.MONEY,
            f = function() ease_dollars(10) end
        },
    }
    local consumable_key = poll_consumable()
    if consumable_key then
        local center = G.P_CENTERS[consumable_key]
        blessings[#blessings + 1] = {
            label = { center_name(center) },
            colour = G.C.SECONDARY_SET[center.set] or G.C.PURPLE,
            center = center,
            f = function() add_consumable(consumable_key) end
        }
    end
    local joker_key = poll_joker()
    if joker_key then
        blessings[#blessings + 1] = {
            label = { center_name(G.P_CENTERS[joker_key]) },
            colour = G.C.RED,
            center = G.P_CENTERS[joker_key],
            f = function() add_joker(joker_key) end
        }
    end
    local booster = poll_booster()
    if booster then
        blessings[#blessings + 1] = {
            label = { center_name(booster) },
            colour = G.C.BOOSTER,
            center = booster,
            f = function() open_booster(booster) end
        }
    end
    local voucher_key = poll_voucher()
    if voucher_key then
        blessings[#blessings + 1] = {
            label = { center_name(G.P_CENTERS[voucher_key]) .. ' ' .. localize('nb_voucher') },
            colour = G.C.SECONDARY_SET.Voucher,
            center = G.P_CENTERS[voucher_key],
            f = function() redeem_voucher(G.P_CENTERS[voucher_key]) end
        }
    end
    return blessings
end

-- Two elements on the overlay menu: the box containing the blessing options
-- and the Neow card
local function create_neow_box(buttons)
    local t = create_UIBox_generic_options({ contents = buttons, no_back = true })
    t.nodes[1] = {n = G.UIT.R, config = { align = "cm", padding = 0.1 }, nodes = {

        -- First, the blessings box
        {n = G.UIT.C, config = { align = "tm", padding = 0.3 }, nodes = {
            {n = G.UIT.R, config = { align = "cm" }, nodes = {
                {n = G.UIT.O, config = { object = DynaText({ string = { localize('nb_choose') }, colours = { G.C.MONEY }, shadow = true, float = true, scale = 1.5, pop_in = 0.4, maxw = 6.5 }) }}
            }},
            t.nodes[1]
        }},

        -- Second, Neow card
        {n = G.UIT.C, config = { align = "cm", padding = 1 }, nodes = {
            {n = G.UIT.R, config = { align = "cm" }, nodes = {
                {n = G.UIT.O, config = { padding = 0, id = 'jimbo_spot', object = Moveable(0, 0, G.CARD_W * 1.1, G.CARD_H * 1.1) }},
            }},
        }},
    }}
    return t
end

local function create_blessings_overlay()
    local blessings = resolve_blessings()
    local buttons = {}
    for i, blessing in ipairs(blessings) do
        G.FUNCS['neow_blessing_' .. i] = function()
            blessing.f()
            G.FUNCS:exit_overlay_menu()
        end
        local button = UIBox_button { id = 'neow_blessing_' .. i, label = blessing.label, button = 'neow_blessing_' .. i, minw = 8, colour = blessing.colour }
        -- Hovering the button shows the game's own description popup for the
        -- rolled center, exactly like the tooltips on card-description links.
        -- Dry-run the tooltip first: it is generated without a real Card, and
        -- some mods' loc_vars index Card-only fields (e.g. card.config.center
        -- in Pokermon's pocket packs) and would crash the game on hover.
        if blessing.center and pcall(create_UIBox_detailed_tooltip, blessing.center) then
            button.nodes[1].config.detailed_tooltip = blessing.center
        end
        buttons[i] = {n = G.UIT.R, config = { align = "cm", padding = 0.1 }, nodes = { button }}
    end

    G.FUNCS.overlay_menu {
        definition = create_neow_box(buttons),
        config = { no_esc = true }
    }
end

local function replace_jimbo_sprite()
    -- remove old Jimbo
    local jimbo = G.BLESSINGS_JIMBO
    jimbo.children.card:remove()
    jimbo.children.card = Card(jimbo.T.x, jimbo.T.y, G.CARD_W, G.CARD_H, G.P_CARDS.empty, j_neow, { bypass_discovery_center = true })
    jimbo.children.card.states.visible = false
    jimbo.children.card:start_materialize({ G.C.BLUE, G.C.WHITE, G.C.RED })
    jimbo.children.card:set_alignment {
        major = jimbo, type = 'cm', offset = { x = 0, y = 0 }
    }
    jimbo.children.card.jimbo = jimbo
    jimbo.children.card.states.collide.can = true
    jimbo.children.card.states.focus.can = false
    jimbo.children.card.states.hover.can = true
    jimbo.children.card.states.drag.can = false
    jimbo.children.card.hover = Node.hover
end

local function draw_blessings_overlay()
    create_blessings_overlay()

    table.insert(G.I.POPUP, G.BLESSINGS_JIMBO)
    table.insert(G.OVERLAY_MENU.children, G.BLESSINGS_JIMBO)

    G.E_MANAGER:add_event(Event({
        trigger = 'after',
        delay = 0.5,
        func = function()
            G.CONTROLLER.interrupt.focus = true
            G.BLESSINGS_JIMBO = Card_Character({ x = 0, y = 5 })
            replace_jimbo_sprite()
            local spot = G.OVERLAY_MENU:get_UIE_by_ID('jimbo_spot')
            spot.config.object:remove()
            spot.config.object = G.BLESSINGS_JIMBO
            G.BLESSINGS_JIMBO.ui_object_updated = true
            G.BLESSINGS_JIMBO:add_speech_bubble("nb_1", "tm", { quip = true })
            G.BLESSINGS_JIMBO:say_stuff(5)

            return true
        end
    }))
end

local game_start_run_ref = Game.start_run
function Game.start_run(self, args)
    local result = game_start_run_ref(self, args)
    if not (args and args.savetext) then -- it's a new game
        draw_blessings_overlay()
    end
    return result
end
