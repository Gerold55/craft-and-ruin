-- cw_player/hud_bridge.lua
-- Bridge cw_player stats/events to cw_hudbar or hudbars (hb)

local stats = cw_player.stats

local has_hb        = minetest.global_exists("hb") or minetest.get_modpath("hudbars")
local has_cw_hudbar = minetest.global_exists("cw_hudbar") or minetest.get_modpath("cw_hudbar")

local HUD = {}

if has_hb and hb then
    function HUD.register(name, def)
        hb.register_hudbar(name, def.label or name, def.label or name, def.icon, def.bgicon, def.max or 20, def.max or 20, false, false, def.format)
    end
    function HUD.init(player, name, cur, max)
        hb.init_hudbar(player, name, cur, max)
    end
    function HUD.set(player, name, val, max)
        if max then hb.change_hudbar(player, name, val, max) else hb.change_hudbar(player, name, val) end
    end

elseif has_cw_hudbar and cw_hudbar then
    local api = cw_hudbar
    function HUD.register(name, def) if api.register then api.register(name, def) end end
    function HUD.init(player, name, cur, max) if api.init then api.init(player, name, cur, max) elseif api.set then api.set(player, name, cur, max) end end
    function HUD.set(player, name, val, max) if api.set then api.set(player, name, val, max) end end
else
    minetest.log("warning", "[cw_player] hud_bridge loaded but no HUD mod detected; doing nothing.")
    return
end

-- Register bars
HUD.register("hp",      { label="HP",      max=20,  side="left",  order=1 })
HUD.register("armor",   { label="Armor",   max=20,  side="left",  order=2 })
HUD.register("stamina", { label="Stamina", max=100, side="right", order=1 })
HUD.register("hunger",  { label="Hunger",  max=20,  side="right", order=2 })

cw_player.hud_attach = function(player, _force)
    local hp      = player:get_hp() or 20
    local hunger  = stats.get(player, "hunger")  or 20
    local stamina = stats.get(player, "stamina") or 100
    local armor   = stats.get(player, "armor")   or 0

    HUD.init(player, "hp",      hp,      20)
    HUD.init(player, "armor",   armor,   20)
    HUD.init(player, "stamina", stamina, 100)
    HUD.init(player, "hunger",  hunger,  20)
end

cw_player.hud_refresh = function(player, which)
    if not player or not player:is_player() then return end
    local hp      = player:get_hp() or 20
    local hunger  = stats.get(player, "hunger")  or 20
    local stamina = stats.get(player, "stamina") or 100
    local armor   = stats.get(player, "armor")   or 0

    if not which or which == "hp"      then HUD.set(player, "hp",      hp,      20)  end
    if not which or which == "hunger"  then HUD.set(player, "hunger",  hunger,  20)  end
    if not which or which == "stamina" then HUD.set(player, "stamina", stamina, 100) end
    if not which or which == "armor"   then HUD.set(player, "armor",   armor,   20)  end
end

cw_player.hud_detach = function(_player) end

cw_player.events.on("stat_changed", function(player, stat, value)
    if stat == "hunger"   then HUD.set(player, "hunger",  value, 20)
    elseif stat == "stamina" then HUD.set(player, "stamina", value, 100)
    elseif stat == "armor"   then HUD.set(player, "armor",   value, 20)
    end
end)

minetest.register_on_player_hpchange(function(player, hp_change, reason)
    minetest.after(0, function()
        if player and player:is_player() then
            HUD.set(player, "hp", player:get_hp(), 20)
        end
    end)
    return hp_change
end, true)
