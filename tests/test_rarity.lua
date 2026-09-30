-- Standalone behavioral tests for the mod's real polling and slider functions.
local config = dofile('config.lua')
local random_value = 0
local rarity_ids = { Common = 1, Uncommon = 2, Rare = 3, Legendary = 4 }
G = {
    FUNCS = {}, UIT = { R = 'row', C = 'column', T = 'text', ROOT = 'root' },
    C = { RED = {}, CLEAR = {}, UI = { TEXT_LIGHT = {} } },
    GAME = { banned_keys = {}, used_jokers = {} }, P_CENTERS = {},
    P_JOKER_RARITY_POOLS = { [1] = {}, [2] = {}, [3] = {}, [4] = {} },
    localization = { descriptions = {} },
}
SMODS = {
    current_mod = { config = config }, Atlas = function() end, Rarities = {},
    ObjectTypes = { Joker = { rarities = {
        { key = 'Common', weight = 0.7 }, { key = 'Uncommon', weight = 0.25 },
        { key = 'Rare', weight = 0.05 },
    } } },
}
Game = { start_run = function() end }
sendDebugMessage = function() end
localize = function(key) return key end
pseudoseed = function(seed) return seed end
pseudorandom = function() return random_value end
pseudorandom_element = function(pool, seed)
    assert(#pool > 0, 'must never roll an empty Joker pool')
    if seed:match('^neow_slot_') then return 'joker' end
    return pool[math.floor(random_value * #pool) + 1]
end

local function add_center(key, rarity, fields)
    local center = fields or {}
    center.key, center.rarity, center.set = key, rarity, 'Joker'
    G.P_CENTERS[key] = center
end
add_center('j_joker', 1)
add_center('j_uncommon', 2)
add_center('j_rare', 3)
add_center('j_legendary', 4, { unlocked = false })

-- Model the relevant Steamodded contract, including its Common fallback.
get_current_pool = function(kind, rarity, legendary, seed)
    assert(kind == 'Joker' and type(rarity) == 'string')
    assert(seed:match('^neow_') or seed == 'test')
    local result = {}
    for key, center in pairs(G.P_CENTERS) do
        if center.rarity == (rarity_ids[rarity] or rarity) and not center.out_of_pool then
            result[#result + 1] = key
        end
    end
    table.sort(result)
    return #result > 0 and result or { 'j_joker' }
end

create_option_cycle = function(args) return { config = args } end
create_toggle = create_option_cycle
create_slider = function(args)
    return { config = {}, nodes = {
        { config = { func = 'slider' }, nodes = {
            { config = { ref_table = args } },
        } },
        { config = { minw = 0.8 } },
    } }
end
G.FUNCS.slider = function(e)
    local args = e.children[1].config.ref_table
    if e.mouse_value then args.ref_table[args.ref_value] = e.mouse_value end
end
dofile('neow_blessings.lua')

local function upvalue(fn, name)
    for i = 1, 100 do
        local key, value = debug.getupvalue(fn, i)
        if key == name then return value end
        if not key then break end
    end
    error('Missing upvalue: ' .. name)
end
local draw = upvalue(Game.start_run, 'draw_blessings_overlay')
local resolve = upvalue(draw, 'resolve_blessings')
local poll = upvalue(resolve, 'poll_joker')
local function range(minimum, maximum)
    config.joker_min_rarity, config.joker_max_rarity = minimum, maximum
end
local function equal(actual, expected)
    assert(actual == expected, tostring(actual) .. ' ~= ' .. tostring(expected))
end

-- Every tier, including locked/undiscovered vanilla Legendaries, works alone.
for name, id in pairs(rarity_ids) do
    range(name, name)
    for _, uniform in ipairs({ false, true }) do
        equal(G.P_CENTERS[poll(uniform, 'test', {})].rarity, id)
    end
end

-- Filtering precedes rarity selection; remaining weights are normalized.
range('Uncommon', 'Rare')
local counts = { [2] = 0, [3] = 0 }
for i = 0, 599 do
    random_value = (i + 0.5) / 600
    local rarity = G.P_CENTERS[poll(false, 'test', {})].rarity
    counts[rarity] = counts[rarity] + 1
end
equal(counts[2], 500)
equal(counts[3], 100)
range('', '')
random_value = 0.999
equal(poll(false, 'test', {}), 'j_legendary')

-- Uniform gives cards equal odds, regardless of rarity weights.
counts = {}
for i = 0, 399 do
    random_value = (i + 0.5) / 400
    local key = poll(true, 'test', {})
    counts[key] = (counts[key] or 0) + 1
end
for _, count in pairs(counts) do equal(count, 100) end

-- Banned, used, hidden, demo, locked and out-of-pool Jokers stay excluded.
range('Rare', 'Rare')
for _, field in ipairs({ 'hidden', 'demo', 'out_of_pool', 'unlocked' }) do
    G.P_CENTERS.j_rare[field] = field ~= 'unlocked'
    for _, uniform in ipairs({ false, true }) do equal(poll(uniform, 'test', {}), nil) end
    G.P_CENTERS.j_rare[field] = nil
end
for _, exclusions in ipairs({ G.GAME.banned_keys, G.GAME.used_jokers }) do
    exclusions.j_rare = true
    equal(poll(false, 'test', {}), nil)
    equal(poll(true, 'test', {}), nil)
    exclusions.j_rare = nil
end
equal(poll(false, 'test', { j_rare = true }), nil)
equal(poll(true, 'test', { j_rare = true }), nil)
range('Uncommon', 'Rare')
G.P_CENTERS.j_uncommon.out_of_pool = true
equal(poll(false, 'test', {}), 'j_rare')
G.P_CENTERS.j_uncommon.out_of_pool = nil

-- Modded rarities, custom weights, modifiers and zero-weight tiers.
local rarities = SMODS.ObjectTypes.Joker.rarities
rarities[#rarities + 1] = { key = 'mod_epic', weight = 0.02 }
add_center('j_epic', 'mod_epic')
range('Rare', 'mod_epic')
random_value = 0.99
equal(poll(false, 'test', {}), 'j_epic')
range('mod_epic', 'mod_epic')
SMODS.Rarities.mod_epic = { get_weight = function() return 0 end }
equal(poll(false, 'test', {}), nil)
equal(poll(true, 'test', {}), 'j_epic')
SMODS.Rarities.mod_epic = nil
G.GAME.mod_epic_mod = 0
equal(poll(false, 'test', {}), nil)
G.GAME.mod_epic_mod = nil
-- A modded tier may exist only in Joker pools, outside the shop tier list.
G.P_JOKER_RARITY_POOLS.mod_special = {}
SMODS.Rarities.mod_special = { default_weight = 0 }
add_center('j_special', 'mod_special')
range('mod_special', 'mod_special')
equal(poll(false, 'test', {}), 'j_special')

-- Old settings and removed-mod bounds fall back to open endpoints.
range(nil, nil)
random_value = 0
equal(poll(false, 'test', {}), 'j_joker')
range('removed_mod', 'removed_mod')
equal(poll(false, 'test', {}), 'j_joker')

-- Every configured Joker/Random Choice slot shares the range and exclusions.
range('Rare', 'Rare')
for i = 1, 5 do
    config['slot_type_' .. i] = i % 2 == 0 and 7 or 4
    config['slot_uniform_' .. i] = i % 2 == 0
end
add_center('j_rare_2', 3)
add_center('j_rare_3', 3)
local blessings = resolve()
equal(#blessings, 3)
local seen = {}
for _, blessing in ipairs(blessings) do
    equal(blessing.center.rarity, 3)
    assert(not seen[blessing.center.key])
    seen[blessing.center.key] = true
end

-- Exercise actual UI wiring, mouse rounding, controller updates, persistence,
-- bound clamping, and reopening the config tab.
range('', '')
local function sliders()
    local result = {}
    local function walk(node)
        if node.config.func == 'nb_rarity_slider' then
            local args = node.nodes[1].config.ref_table
            result[args.ref_value] = { children = { { config = { ref_table = args }, T = {} } } }
        end
        for _, child in ipairs(node.nodes or {}) do walk(child) end
    end
    walk(SMODS.current_mod.config_tab())
    return result
end
local controls = sliders()
local minimum, maximum = controls.minimum, controls.maximum
G.FUNCS.nb_rarity_slider(maximum)
equal(config.joker_max_rarity, '')
equal(maximum.children[1].config.ref_table.text, 'nb_unlimited')
random_value = 0.999
for _, uniform in ipairs({ false, true }) do
    equal(poll(uniform, 'test', {}), 'j_special')
end
minimum.mouse_value = 2.7
G.FUNCS.nb_rarity_slider(minimum)
equal(config.joker_min_rarity, 'Rare')
equal(minimum.children[1].config.ref_table.text, 'k_rare')
minimum.mouse_value = nil
local args = maximum.children[1].config.ref_table
args.ref_table.maximum = 2 -- Controller changes value without a mouse callback.
G.FUNCS.nb_rarity_slider(maximum)
equal(args.ref_table.maximum, 3)
equal(config.joker_max_rarity, 'Rare')
minimum.mouse_value = 6
G.FUNCS.nb_rarity_slider(minimum)
equal(config.joker_min_rarity, 'Rare')
controls = sliders()
equal(controls.minimum.children[1].config.ref_table.ref_table.minimum, 3)
equal(controls.maximum.children[1].config.ref_table.ref_table.maximum, 3)
-- Small controller steps must accumulate instead of being rounded away.
range('', '')
controls = sliders()
minimum = controls.minimum
args = minimum.children[1].config.ref_table
for _ = 1, 20 do
    args.ref_table.minimum = args.ref_table.minimum + 0.01 * (args.max - args.min)
    G.FUNCS.nb_rarity_slider(minimum)
end
equal(config.joker_min_rarity, 'Uncommon')
print('Rarity tests passed: bounds, weighting, all rarities, exclusions, slots, and sliders')
