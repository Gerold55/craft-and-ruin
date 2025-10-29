minetest.register_on_joinplayer(function(player)
    -- Force 9-wide hotbar regardless of inventory mod
    player:hud_set_hotbar_itemcount(9)
end)
