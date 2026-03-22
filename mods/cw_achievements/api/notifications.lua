-- api/notifications.lua
local api = cw_achievements
local active = {}

local DISPLAY_TIME = 3
local FADE_TIME = 0.5

function api.notify(player, ach)
    local name = player:get_player_name()

    if active[name] then
        player:hud_remove(active[name].bg)
        player:hud_remove(active[name].text)
        active[name] = nil
    end

    local bg = player:hud_add({
        hud_elem_type = "image",
        position = {x = 1, y = 0},
        offset = {-180, 40},
        text = "cw_toast_bg.png",
        alignment = {x = 1, y = 0},
        z_index = 100,
    })

    local text = player:hud_add({
        hud_elem_type = "text",
        position = {x = 1, y = 0},
        offset = {-180, 40},
        number = 0xFFFFFF,
        text = "Achievement Unlocked:\n" .. ach.title,
        alignment = {x = 1, y = 0},
        z_index = 101,
    })

    if ach.sound then
        minetest.sound_play(ach.sound, {to_player = name})
    end

    active[name] = { bg = bg, text = text, timer = 0 }
end

minetest.register_globalstep(function(dtime)
    for name, data in pairs(active) do
        data.timer = data.timer + dtime

        local player = minetest.get_player_by_name(name)
        if not player then
            active[name] = nil
            return
        end

        if data.timer > DISPLAY_TIME + FADE_TIME then
            player:hud_remove(data.bg)
            player:hud_remove(data.text)
            active[name] = nil
            return
        end
    end
end)

