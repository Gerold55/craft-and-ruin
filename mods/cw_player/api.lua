-- cw_player/api.lua
-- Public API: events, stats, effects

local U = cw_player.util

-- ========= Events (lightweight bus) =========
local events = { _map = {} }

function events.on(name, fn)
    if type(fn) ~= "function" then return end
    local list = events._map[name]
    if not list then list = {}; events._map[name] = list end
    list[#list+1] = fn
end

function events.fire(name, ...)
    local list = events._map[name]
    if not list then return end
    for _, fn in ipairs(list) do
        local ok, err = pcall(fn, ...)
        if not ok then
            minetest.log("warning", "[cw_player] event '"..name.."' error: "..tostring(err))
        end
    end
end

-- ========= Stats (stamina, hunger, armor) =========
local stats = {}
local STAT_RANGES = {
    stamina = {0, 100},
    hunger  = {0, 20},
    armor   = {0, 20},
}
local function k(stat) return "cw_player:"..stat end

function stats.get(player, stat)
    if not STAT_RANGES[stat] then return nil end
    return player:get_meta():get_int(k(stat))
end

function stats.set(player, stat, value, silent)
    local rng = STAT_RANGES[stat]; if not rng then return end
    local v = U.clamp(math.floor(value or 0), rng[1], rng[2])
    player:get_meta():set_int(k(stat), v)
    if not silent then
        events.fire("stat_changed", player, stat, v)
        if cw_player.hud_refresh then cw_player.hud_refresh(player, stat) end
    end
end

function stats.add(player, stat, delta)
    stats.set(player, stat, (stats.get(player, stat) or 0) + (delta or 0))
end

-- ========= Effects (buffs/debuffs) =========
local effects = { defs = {} }
-- def: { on_apply(player,ctx), on_tick(player,ctx,dtime), on_expire(player,ctx) }

function effects.register(name, def) effects.defs[name] = def or {} end

function effects.apply(player, name, seconds, power)
    local def = effects.defs[name]
    if not def then
        minetest.log("warning","[cw_player] unknown effect "..tostring(name))
        return
    end
    local list = U.get_meta_tbl(player, "cw_player:effects")
    local ctx = {name=name, time_left=seconds or 5, power=power or 1}
    list[#list+1] = ctx
    U.set_meta_tbl(player, "cw_player:effects", list)
    if def.on_apply then pcall(def.on_apply, player, ctx) end
    events.fire("effect_applied", player, name, seconds, power)
end

local function effects_tick(player, dtime)
    local list = U.get_meta_tbl(player, "cw_player:effects")
    if #list == 0 then return end
    local out = {}
    for _, ctx in ipairs(list) do
        ctx.time_left = (ctx.time_left or 0) - dtime
        local def = effects.defs[ctx.name]
        if def and def.on_tick then pcall(def.on_tick, player, ctx, dtime) end
        if ctx.time_left > 0 then
            out[#out+1] = ctx
        else
            if def and def.on_expire then pcall(def.on_expire, player, ctx) end
            events.fire("effect_expired", player, ctx.name)
        end
    end
    if #out ~= #list then U.set_meta_tbl(player, "cw_player:effects", out) end
end

-- ========= Per-player accumulators (don't attach to userdata!) =========
local HUNGER_ACC = {}  -- [pname] = seconds

minetest.register_on_leaveplayer(function(player)
    local name = player and player:get_player_name()
    if name then HUNGER_ACC[name] = nil end
end)

-- ========= Globalstep: effects + passive hunger + HUD cadence =========
local hud_acc = 0
minetest.register_globalstep(function(dtime)
    local players = minetest.get_connected_players()
    for _, p in ipairs(players) do
        effects_tick(p, dtime)

        if cw_player.cfg.enable_hunger then
            local name = p:get_player_name()
            local acc = (HUNGER_ACC[name] or 0) + dtime
            if acc >= 60 then
                acc = acc - 60
                stats.add(p, "hunger", -1)
            end
            HUNGER_ACC[name] = acc
        end
    end

    hud_acc = hud_acc + dtime
    if hud_acc >= 0.25 and cw_player.hud_refresh then
        for _, p in ipairs(players) do cw_player.hud_refresh(p) end
        hud_acc = 0
    end
end)

-- ========= Damage relay =========
minetest.register_on_player_hpchange(function(player, hp_change, reason)
    events.fire("hp_changed", player, hp_change, reason)
    return hp_change
end, true)

cw_player.events  = events
cw_player.stats   = stats
cw_player.effects = effects
