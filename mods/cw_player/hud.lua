-- cw_player/hud.lua
-- Minimal text HUD (hearts bottom-left; armor above; hunger bottom-right)

local HUD_IDS = {} -- pname -> {hearts=..., hunger=..., armor=...}

local function add_text(player, text, x, y, align)
    return player:hud_add({
        hud_elem_type = "text",
        position      = {x = align == "left" and 0 or 1, y = 1},
        offset        = {x = x, y = y},
        name          = "cw_player_text",
        text          = text,
        number        = 0xFFFFFF,
        alignment     = {x = align == "left" and 1 or -1, y = -1},
        scale         = {x=100, y=20},
        z_index       = 100,
    })
end

local function heart_str(hp)
    local full = math.floor((hp or 0) / 2)
    local half = (hp or 0) % 2
    local s = ""
    for i=1,full do s = s .. "♥" end
    if half == 1 then s = s .. "♡" end
    return s
end

local function bar_str(label, val, max, glyph)
    local s = label .. " "
    for i=1,max do s = s .. (i <= val and glyph or "·") end
    return s
end

local function ids(player) return HUD_IDS[player:get_player_name()] end

local function build(player)
    local hearts = add_text(player, "",  12, -36, "left")
    local armor  = add_text(player, "",  12, -64, "left")
    local hunger = add_text(player, "", -12, -36, "right")
    HUD_IDS[player:get_player_name()] = {hearts=hearts, armor=armor, hunger=hunger}
end

cw_player.hud_attach = function(player, force)
    if force or not ids(player) then
        if ids(player) then
            for _, id in pairs(ids(player)) do player:hud_remove(id) end
            HUD_IDS[player:get_player_name()] = nil
        end
        build(player)
    end
end

cw_player.hud_refresh = function(player, which)
    local idset = ids(player); if not idset then return end
    local hp      = player:get_hp() or 20
    local hunger  = cw_player.stats.get(player, "hunger")  or 20
    local armor   = cw_player.stats.get(player, "armor")   or 0

    if not which or which == "hp"     then player:hud_change(idset.hearts, "text", heart_str(hp)) end
    if not which or which == "armor"  then player:hud_change(idset.armor,  "text", bar_str("Armor",  armor,  20, "▮")) end
    if not which or which == "hunger" then player:hud_change(idset.hunger, "text", bar_str("Hunger", hunger, 20, "▮")) end
end

cw_player.hud_detach = function(player)
    local idset = ids(player); if not idset then return end
    for _, id in pairs(idset) do player:hud_remove(id) end
    HUD_IDS[player:get_player_name()] = nil
end
