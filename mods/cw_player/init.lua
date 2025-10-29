-- cw_player/init.lua
-- Craftopia Player API bootstrap (no player_api dependency)

local MP = minetest.get_modpath(minetest.get_current_modname())

cw_player          = cw_player or {}
cw_player.modname  = minetest.get_current_modname()
cw_player.storage  = minetest.get_mod_storage()
cw_player.version  = "0.2.1"

-- Core
dofile(MP .. "/util.lua")
dofile(MP .. "/api.lua")
dofile(MP .. "/model.lua")

-- Detect external HUD mods
local has_hb        = minetest.global_exists("hb") or minetest.get_modpath("hudbars")
local has_cw_hudbar = minetest.global_exists("cw_hudbar") or minetest.get_modpath("cw_hudbar")
local has_external_hud = (has_hb or has_cw_hudbar)

-- Config (server owners can override in minetest.conf)
local cfg = {
    -- If a HUD mod exists, prefer it; otherwise default to our fallback HUD.
    enable_custom_hud  = (not has_external_hud)
                         and (minetest.settings:get_bool("cw_player_enable_custom_hud", true))
                         or  minetest.settings:get_bool("cw_player_enable_custom_hud", false),

    -- Hide engine bars so either external HUD or our fallback owns the UI
    hide_builtin_hud   = minetest.settings:get_bool("cw_player_hide_builtin_hud", true),

    enable_stamina     = minetest.settings:get_bool("cw_player_enable_stamina", true),
    enable_hunger      = minetest.settings:get_bool("cw_player_enable_hunger", true),
    sprint_multiplier  = tonumber(minetest.settings:get("cw_player_sprint_mult") or 1.25),
    sprint_key_is_aux1 = minetest.settings:get_bool("cw_player_sprint_key_aux1", true),
}
cw_player.cfg = cfg

-- HUD layer: prefer bridge → fallback
if has_external_hud then
    dofile(MP .. "/hud_bridge.lua")  -- uses cw_hudbar or hudbars
elseif cfg.enable_custom_hud then
    dofile(MP .. "/hud.lua")         -- simple text HUD fallback
end

-- Movement (sprint/stamina)
dofile(MP .. "/movement.lua")

-- Initialize per-player meta + visuals + HUD
local function ensure_player_defaults(player)
    local meta = player:get_meta()

    if meta:get_string("cw_player:ver") ~= cw_player.version then
        meta:set_string("cw_player:ver", cw_player.version)
    end
    if meta:get_string("cw_player:init") ~= "1" then
        meta:set_int("cw_player:stamina", 100)                -- 0..100
        meta:set_int("cw_player:hunger",  20)                 -- 0..20
        meta:set_int("cw_player:armor",   0)                  -- 0..20 (display link)
        meta:set_string("cw_player:effects", minetest.serialize({}))
        meta:set_string("cw_player:init", "1")
    end

    if cw_player.cfg.hide_builtin_hud then
        player:hud_set_flags({ healthbar=false, breathbar=false })
    end

    -- Safe visuals (mesh or sprite)
    cw_player.model.init(player)

    -- HUD attach/refresh for whichever layer is active
    if cw_player.hud_attach then
        cw_player.hud_attach(player, true)
        if cw_player.hud_refresh then cw_player.hud_refresh(player) end
    end
end

minetest.register_on_joinplayer(function(player)
    ensure_player_defaults(player)
    cw_player.events.fire("player_join", player)
end)

minetest.register_on_respawnplayer(function(player)
    minetest.after(0, function()
        cw_player.model.init(player)
        if cw_player.hud_attach then cw_player.hud_attach(player, true) end
        if cw_player.hud_refresh then cw_player.hud_refresh(player) end
    end)
    cw_player.events.fire("player_respawn", player)
    return false
end)

minetest.register_on_leaveplayer(function(player)
    cw_player.events.fire("player_leave", player)
end)

minetest.log("action", ("[cw_player] v%s loaded. HUD: %s")
    :format(cw_player.version,
        (has_cw_hudbar and "cw_hudbar")
        or (has_hb and "hudbars")
        or (cfg.enable_custom_hud and "fallback")
        or "none"))
