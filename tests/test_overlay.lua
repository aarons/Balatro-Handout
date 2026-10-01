-- Exercise the real reward/menu callbacks with lightweight engine doubles.
local config = dofile('config.lua')
local rewards, live_previews, runs = {}, {}, 0
G = {
    FUNCS = {}, UIT = { R = 'row', C = 'column', T = 'text', O = 'object', ROOT = 'root' },
    C = { RED = {}, CLEAR = {}, UI = { TEXT_LIGHT = {} } },
    SETTINGS = { paused = false }, ROOM = { T = { x = 0, y = 0 } },
    CARD_W = 2, CARD_H = 3, P_CARDS = { empty = {} },
    play = { T = { x = 0, y = 0, w = 10, h = 5 } },
    jokers = { cards = {}, config = { card_limit = 5 } },
    consumeables = { cards = {}, config = { card_limit = 2 } },
    GAME = { banned_keys = {}, used_jokers = {}, used_vouchers = {}, current_round = {}, tarot_rate = 1 },
    CONTROLLER = { snap_to = function(self, args) self.target = args.node end },
}
G.P_CENTERS = {
    j_test = { key = 'j_test', set = 'Joker', rarity = 1 },
    c_test = { key = 'c_test', set = 'Tarot' },
    p_test = { key = 'p_test', set = 'Booster' },
    v_test = { key = 'v_test', set = 'Voucher' },
}
G.P_CENTER_POOLS = { Booster = { G.P_CENTERS.p_test }, Voucher = { G.P_CENTERS.v_test } }
local function award(kind)
    assert(not G.SETTINGS.paused and not G.OVERLAY_MENU, 'close overlay before awarding')
    assert(next(live_previews) == nil, 'all previews must be removed first')
    rewards[#rewards + 1] = kind
end
Card = function(x, y, w, h, base, center, params)
    return {
        T = { x = x, y = y, w = w, h = h }, config = { center = center }, params = params,
        created_on_pause = G.SETTINGS.paused,
        states = { drag = { can = true }, click = { can = true }, hover = { can = true } },
        remove = function(self) live_previews[self] = nil; self.removed = true end,
        start_materialize = function() end, start_dissolve = function() end,
        redeem = function() award('Voucher') end,
    }
end
CardArea = function(x, y, w, h, args)
    return {
        T = { x = x, y = y, w = w, h = h }, config = args, cards = {},
        emplace = function(self, card)
            self.cards[#self.cards + 1] = card
            card.area = self
            live_previews[card] = true
        end,
        remove = function(self) for _, card in ipairs(self.cards) do card:remove() end end,
    }
end
SMODS = {
    current_mod = { config = config }, Rarities = {},
    ObjectTypes = { Joker = { rarities = { { key = 'Common', weight = 1 } } } },
    ConsumableType = { obj_table = { Tarot = {} } },
    add_card = function(args)
        award(args.set)
        local card = { key = args.key, start_materialize = function() end }
        local area = args.set == 'Joker' and G.jokers or G.consumeables
        area.cards[#area.cards + 1] = card
        return card
    end,
}
Game = { start_run = function() runs = runs + 1; return 'started' end }
sendDebugMessage = function() end
localize = function(key) return key end
pseudoseed = function(seed) return seed end
pseudorandom = function() return 0 end
pseudorandom_element = function(pool, seed)
    if seed:match('^neow_slot_') then
        assert(#pool == 4)
        for _, kind in ipairs(pool) do assert(kind ~= 'money') end
    end
    return pool[1]
end
get_current_pool = function(kind) return { kind == 'Joker' and 'j_test' or 'c_test' } end
create_UIBox_generic_options = function(args) return args end
G.FUNCS.overlay_menu = function(args)
    if G.OVERLAY_MENU then G.OVERLAY_MENU.area:remove() end
    assert(args.config.no_esc and args.definition.no_back)
    assert(#args.definition.contents == 1 and args.definition.contents[1].n == G.UIT.O)
    G.OVERLAY_MENU = { area = args.definition.contents[1].config.object }
end
G.FUNCS.exit_overlay_menu = function()
    G.OVERLAY_MENU.area:remove()
    G.OVERLAY_MENU = nil
    G.SETTINGS.paused = false
end
G.FUNCS.use_card = function(e) assert(e.config.ref_table.cost == 0); award('Booster') end
G.FUNCS.end_consumeable = function() end
Event = function(args) return args end
G.E_MANAGER = { add_event = function(self, event) assert(event.func()) end }
create_option_cycle = function(args) return { config = args } end
create_toggle = create_option_cycle
-- Keep this test focused on type cycles; rarity dropdowns have their own suite.
SMODS.GUI = { dropdown_select = function() return { config = {} } end }

dofile('neow_blessings.lua')

-- Default four choices use their exact centers, including native pack sizing.
for selected, expected in ipairs({ 'Tarot', 'Joker', 'Booster', 'Voucher' }) do
    G.GAME.used_jokers = {}
    assert(Game:start_run({}) == 'started')
    local area = G.OVERLAY_MENU.area
    assert(#area.cards == 4 and G.CONTROLLER.target == area.cards[1])
    for i, kind in ipairs({ 'Tarot', 'Joker', 'Booster', 'Voucher' }) do
        local card = area.cards[i]
        assert(card.config.center.set == kind and not card.states.drag.can)
        assert(card.created_on_pause and card.states.click.can and card.states.hover.can)
        assert(card.params.bypass_discovery_center and card.params.bypass_discovery_ui and card.params.bypass_lock)
        assert(card.T.w == G.CARD_W * (kind == 'Booster' and 1.27 or 1))
    end
    local before = #rewards
    area.cards[selected]:click()
    assert(#rewards == before + 1 and rewards[#rewards] == expected)
    for _, card in ipairs(area.cards) do card:click() end
    assert(#rewards == before + 1, 'stale/repeated clicks must not award again')
end

-- Replacing a menu makes old callbacks inert and removes their previews.
G.GAME.used_jokers = {}
Game:start_run({})
local old_card = G.OVERLAY_MENU.area.cards[1]
Game:start_run({})
local current = G.OVERLAY_MENU
old_card:click()
assert(old_card.removed and G.OVERLAY_MENU == current)
G.FUNCS.exit_overlay_menu()

-- Loading a saved run does not reroll; disabled/retired slots do not pause.
local before = runs
Game:start_run({ savetext = 'saved run' })
assert(runs == before + 1 and not G.OVERLAY_MENU)
for i = 1, 5 do config['slot_type_' .. i] = 2 end
Game:start_run({})
assert(not G.OVERLAY_MENU and not G.SETTINGS.paused)

-- Display positions map back to stable saved IDs, skipping retired Money.
local ids = { 1, 3, 4, 5, 6, 7 }
local cycles = {}
local function walk(node)
    if node.config.nb_slot then cycles[node.config.nb_slot] = node.config end
    for _, child in ipairs(node.nodes or {}) do walk(child) end
end
walk(SMODS.current_mod.config_tab())
assert(cycles[1].current_option == 1 and #cycles[1].options == #ids)
for option, id in ipairs(ids) do
    G.FUNCS.nb_slot_type { cycle_config = { nb_slot = 1 }, to_key = option }
    assert(config.slot_type_1 == id)
    walk(SMODS.current_mod.config_tab())
    assert(cycles[1].current_option == option)
end
-- Random Choice has only card rewards; one active slot still works.
Game:start_run({})
assert(#G.OVERLAY_MENU.area.cards == 1)
G.OVERLAY_MENU.area.cards[1]:click()

-- The widest configuration (five packs) fits without overlapping neighbors.
for i = 2, 5 do
    G.P_CENTER_POOLS.Booster[i] = { key = 'p_test_' .. i, set = 'Booster' }
end
for i = 1, 5 do config['slot_type_' .. i] = 5 end
Game:start_run({})
local area = G.OVERLAY_MENU.area
assert(#area.cards == 5)
local total_width = 0
for _, card in ipairs(area.cards) do
    total_width = total_width + card.T.w
    assert(area.T.h >= card.T.h)
end
assert(area.T.w >= total_width)
area.cards[5]:click()

-- Copies are bounded, persist through the config callback, and default to one
-- for older saves. Repeated rewards retain the selected center key.
local function claim(kind, copies, limit, occupied, buffer)
    for i = 1, 5 do config['slot_type_' .. i] = 1 end
    config.slot_type_1, config.copies = kind, copies
    G.GAME.used_jokers = {}
    G.GAME.joker_buffer, G.GAME.consumeable_buffer = buffer, buffer
    for _, target in ipairs({ G.jokers, G.consumeables }) do
        target.cards, target.config.card_limit = {}, limit or 10
        for _ = 1, occupied or 0 do target.cards[#target.cards + 1] = {} end
    end
    Game:start_run({})
    local card = G.OVERLAY_MENU.area.cards[1]
    local before = #rewards
    card:click()
    card:click()
    return #rewards - before
end
for count = 1, 5 do
    G.FUNCS.nb_copies { to_key = count }
    assert(config.copies == count)
    local copies_cycle = SMODS.current_mod.config_tab().nodes[1].nodes[1].config
    assert(copies_cycle.opt_callback == 'nb_copies' and copies_cycle.current_option == count)
    assert(#copies_cycle.options == 5)
    assert(claim(4, count) == count)
    for _, card in ipairs(G.jokers.cards) do assert(card.key == 'j_test') end
    assert(claim(3, count) == count)
    for _, card in ipairs(G.consumeables.cards) do assert(card.key == 'c_test') end
    assert(claim(6, count) == count)
end
for _, kind in ipairs({ 3, 4 }) do
    assert(claim(kind, 5, 4, 1) == 3, 'respect reduced capacity and starting cards')
    assert(claim(kind, 5, 2, 1) == 1)
    assert(claim(kind, 5, 2, 2) == 0, 'full area')
    assert(claim(kind, 5, 0, 0) == 0, 'zero slots')
    assert(claim(kind, 5, 1, 2) == 0, 'overfull area')
    assert(claim(kind, 5, 5, 1, 2) == 2, 'reserve pending card slots')
    assert(claim(kind, 99) == 5)
    assert(claim(kind, 0) == 1)
    assert(claim(kind, nil) == 1)
    assert(claim(kind, 'invalid') == 1)
end
assert(claim(7, 5, 2, 1) == 1, 'Random Choice also respects copies and capacity')

-- Steamodded exposes an effective card_limit with extra slot usage deducted.
-- Refresh it between copies, and do not deduct that usage a second time.
G.jokers.handle_card_limit = function(self)
    self.config.card_count = #self.cards + 1
    self.config.card_limit = 3
end
assert(claim(4, 5, 4, 1) == 2, 'fill all effective modded slots')
G.jokers.handle_card_limit = nil
G.jokers.config.card_count = nil

local events = {}
G.E_MANAGER.add_event = function(self, event) events[#events + 1] = event end
assert(claim(5, 5) == 1, 'only open the first pack immediately')
for _ = 2, 5 do
    local before = #rewards
    G.GAME.PACK_INTERRUPT, G.booster_pack = 1, {}
    G.FUNCS.end_consumeable()
    G.FUNCS.end_consumeable()
    assert(#events == 1, 'only queue one next pack')
    local event = table.remove(events, 1)
    assert(not event.blocking and not event.blockable)
    assert(not event.func() and #rewards == before, 'wait for pack cleanup')
    G.GAME.PACK_INTERRUPT, G.booster_pack = nil, nil
    assert(event.func() and #rewards == before + 1)
end
G.FUNCS.end_consumeable()
assert(#events == 0, 'stop after five packs')
assert(claim(5, 3) == 1)
G.FUNCS.end_consumeable()
local stale = table.remove(events, 1)
Game:start_run({ savetext = 'saved run' })
local before = #rewards
assert(stale.func() and #rewards == before, 'new or loaded runs cancel stale pack events')
print('Overlay tests passed: card previews, all rewards, cleanup, saved runs, retired Money, and config IDs')
