-- Abyssal Vein sky + ambient light + rumble

local DIMENSION_Y = -200

-- Force sky every tick so nothing overrides it
minetest.register_globalstep(function()
    for _, player in ipairs(minetest.get_connected_players()) do
        local pos = player:get_pos()

        if pos.y < DIMENSION_Y then
            player:set_sky({
                type = "plain",
                base_color = "#0a0010",
                fog_color = "#1a0020",
            })
            player:set_sun({ visible = false })
            player:set_moon({ visible = false })
            player:set_stars({ visible = false })
            player:set_clouds({ density = 0 })
        else
            player:set_sky({ type = "regular" })
            player:set_sun({ visible = true })
            player:set_moon({ visible = true })
            player:set_stars({ visible = true })
            player:set_clouds({ density = 0.4 })
        end
    end
end)

-- Ambient rumble
minetest.register_globalstep(function()
    if math.random(1, 200) == 1 then
        for _, player in ipairs(minetest.get_connected_players()) do
            if player:get_pos().y < DIMENSION_Y then
                minetest.sound_play("abyssal_rumble", {
                    to_player = player:get_player_name(),
                    gain = 0.4,
                })
            end
        end
    end
end)

-- Minimum ambient light in the Abyss
minetest.register_globalstep(function()
    for _, player in ipairs(minetest.get_connected_players()) do
        local pos = player:get_pos()
        if pos.y < DIMENSION_Y then
            player:override_day_night_ratio(0.35)
        else
            player:override_day_night_ratio(nil)
        end
    end
end)
