-------------------------------
-- Glowbug Light Node
-------------------------------

minetest.register_node("abyssal_vein:glowbug_light", {
    description = "Glowbug Light",
    drawtype = "airlike",
    paramtype = "light",
    sunlight_propagates = true,
    walkable = false,
    pointable = false,
    diggable = false,
    buildable_to = true,
    light_source = 10,
    groups = {not_in_creative_inventory=1},
})

---------------------------------------------------
-- Glowbug Swarms (Increased Density)
---------------------------------------------------

minetest.register_abm({
    label = "Abyssal Glowbug Swarms",
    nodenames = {
        "abyssal_vein:ambient_crystal",
        "abyssal_vein:abyssal_glowstone",
        "abyssal_vein:lumen_cap",
        "abyssal_vein:abyssal_tree_trunk",
        "abyssal_vein:abyssal_leaves",
    },

    -- MORE FREQUENT
    interval = 2,   -- was 3

    -- MORE LIKELY
    chance = 2,     -- was 4

    action = function(pos)

        if pos.y > -200 then return end

        -- MORE BUGS PER SWARM
        local count = math.random(6, 12)  -- was 3–6

        for i = 1, count do
            local p = {
                x = pos.x + math.random(-4, 4),
                y = pos.y + math.random(0, 4),
                z = pos.z + math.random(-4, 4)
            }

            -- Temporary light node
            if minetest.get_node(p).name == "air" then
                minetest.set_node(p, {name="abyssal_vein:glowbug_light"})
                minetest.after(2.5, function()
                    if minetest.get_node(p).name == "abyssal_vein:glowbug_light" then
                        minetest.set_node(p, {name="air"})
                    end
                end)
            end

            -- Glowbug particle
            minetest.add_particle({
                pos = p,
                velocity = {
                    x = math.random(-10,10) * 0.01,
                    y = math.random(0,10) * 0.01,
                    z = math.random(-10,10) * 0.01
                },
                expirationtime = math.random(1, 3),
                size = 1.5,
                texture = "glowbug.png",
                glow = 10,
            })
        end
    end,
})

---------------------------------------------------
-- Ambient Glowbug Clouds (Optional Boost)
---------------------------------------------------

minetest.register_globalstep(function(dtime)
    if math.random(1, 25) ~= 1 then return end  -- more frequent

    local players = minetest.get_connected_players()
    if #players == 0 then return end

    local player = players[math.random(1, #players)]
    local pos = player:get_pos()

    if pos.y > -200 then return end

    local p = {
        x = pos.x + math.random(-12, 12),
        y = pos.y + math.random(-6, 6),
        z = pos.z + math.random(-12, 12)
    }

    minetest.add_particlespawner({
        amount = 16,  -- more bugs
        time = 1,
        minpos = p,
        maxpos = p,
        minvel = {x=-0.1, y=0.05, z=-0.1},
        maxvel = {x=0.1, y=0.15, z=0.1},
        glow = 10,
        texture = "glowbug.png",
    })
end)
