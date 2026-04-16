-- Teleport commands for testing

minetest.register_chatcommand("gotoabyss", {
    description = "Teleport to the Abyssal Vein dimension",
    privs = {server = true},
    func = function(name)
        local player = minetest.get_player_by_name(name)
        if not player then return false end
        player:set_pos({x=0, y=-19500, z=0})
        return true, "Teleported to the Abyssal Vein."
    end,
})

minetest.register_chatcommand("returnfromabyss", {
    description = "Return to the overworld",
    privs = {server = true},
    func = function(name)
        local player = minetest.get_player_by_name(name)
        if not player then return false end
        player:set_pos({x=0, y=10, z=0})
        return true, "Returned to the overworld."
    end,
})
