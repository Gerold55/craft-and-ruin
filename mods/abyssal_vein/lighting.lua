minetest.register_globalstep(function()
    for _, player in ipairs(minetest.get_connected_players()) do
        local pos = player:get_pos()
        if pos.y < -200 then
            player:override_day_night_ratio(0.25)
        else
            player:override_day_night_ratio(nil)
        end
    end
end)
