local MOD = "cw_core"

local wood_types = {
    {name = "oak",    desc = "Oak",    tile = "cw_log_oak.png"},
    {name = "cherry", desc = "Cherry", tile = "cw_log_cherry.png"},
    {name = "birch",  desc = "Birch",  tile = "cw_log_birch.png"},
    {name = "spruce", desc = "Spruce", tile = "cw_log_spruce.png"},
}

for _, wood in ipairs(wood_types) do
    core.register_node(MOD .. ":fence_" .. wood.name, {
        description = wood.desc .. " Craft & Ruin Fence",
        drawtype = "nodebox",
        tiles = {wood.tile},
        paramtype = "light",
        is_ground_content = false,
        -- This group allows it to connect to other fences and gates
        groups = {choppy = 2, oddly_breakable_by_hand = 2, flammable = 2, fence = 1},
        connects_to = {"group:fence", "group:gate", "group:wood", "group:stone"},

        node_box = {
            type = "connected",
            -- 1. THE CENTRAL POST (Chunky Hytale Style)
            fixed = {
                {-0.2, -0.5, -0.2, 0.2, 0.5, 0.2}, -- Main Post
                {-0.25, 0.5, -0.25, 0.25, 0.6, 0.25}, -- Post Cap
            },
            -- 2. EXTERIOR RAILS (Connectors)
            -- These are moved to the edge (0.2 to 0.3) so they sit on the FACE of the post
            connect_front = {
                {-0.2,  0.1, -0.5, 0.2,  0.25, -0.2}, -- Top Rail
                {-0.2, -0.3, -0.5, 0.2, -0.15, -0.2}, -- Bottom Rail
            },
            connect_back = {
                {-0.2,  0.1,  0.2, 0.2,  0.25,  0.5},
                {-0.2, -0.3,  0.2, 0.2, -0.15,  0.5},
            },
            connect_left = {
                {-0.5,  0.1, -0.2, -0.2,  0.25, 0.2},
                {-0.5, -0.3, -0.2, -0.2, -0.15, 0.2},
            },
            connect_right = {
                {0.2,  0.1, -0.2,  0.5,  0.25, 0.2},
                {0.2, -0.3, -0.2,  0.5, -0.15, 0.2},
            },
        },
        -- Minecraft-style 1.5 block collision height
        collision_box = {
            type = "fixed",
            fixed = {-0.5, -0.5, -0.5, 0.5, 1.0, 0.5},
        },
    })

    -- THE COMPANION GATE
    core.register_node(MOD .. ":gate_" .. wood.name .. "_closed", {
        description = wood.desc .. " Craft & Ruin Gate",
        drawtype = "nodebox",
        tiles = {wood.tile, wood.tile, wood.tile .. "^[colorize:#000:50"}, -- Darker hinges
        paramtype = "light",
        paramtype2 = "facedir",
        groups = {choppy = 2, gate = 1},
        node_box = {
            type = "fixed",
            fixed = {
                {-0.5, -0.5, -0.1, -0.3, 0.6, 0.1}, -- Hinge Post
                { 0.3, -0.5, -0.1,  0.5, 0.6, 0.1}, -- Latch Post
                {-0.3,  0.1, -0.2,  0.3, 0.25, -0.1}, -- Top Rail (Exterior)
                {-0.3, -0.3, -0.2,  0.3, -0.15, -0.1}, -- Bottom Rail (Exterior)
                {-0.2, -0.1, -0.15, 0.2, 0.1, -0.12}, -- Brace
            },
        },
        on_rightclick = function(pos, node, clicker)
            core.set_node(pos, {name = MOD .. ":gate_" .. wood.name .. "_open", param2 = node.param2})
            core.sound_play("default_gate_open", {pos = pos, gain = 0.5})
        end,
    })

    -- OPEN GATE (Non-walkable)
    core.register_node(MOD .. ":gate_" .. wood.name .. "_open", {
        drawtype = "nodebox",
        tiles = {wood.tile},
        paramtype = "light",
        paramtype2 = "facedir",
        walkable = false,
        groups = {choppy = 2, gate = 1, not_in_creative_inventory = 1},
        drop = MOD .. ":gate_" .. wood.name .. "_closed",
        node_box = {
            type = "fixed",
            fixed = {
                {-0.5, -0.5, -0.1, -0.3, 0.6, 0.1}, -- Post remains
                {-0.5, -0.5, 0.1, -0.4, 0.6, 0.9}, -- Gate panel swings back
            },
        },
        on_rightclick = function(pos, node, clicker)
            core.set_node(pos, {name = MOD .. ":gate_" .. wood.name .. "_closed", param2 = node.param2})
            core.sound_play("default_gate_close", {pos = pos, gain = 0.5})
        end,
    })
end

minetest.register_node("cw_core:fence_straight", {
    description = "Straight Fence",
    drawtype = "nodebox",
    tiles = {
        "cw_core_fence_top.png",
        "cw_core_fence_bottom.png",
        "cw_core_fence_side.png"
    },
    paramtype = "light",
    sunlight_propagates = true,
    walkable = true,
    groups = {choppy = 2, oddly_breakable_by_hand = 2, flammable = 2},

    node_box = {
        type = "fixed",
        fixed = {
            -- Post
            {-0.1875, -0.5,   -0.0625, 0.1875, 0.5,    0.3125},

            -- Upper rail
            {-0.5,     0.0625, -0.1875, 0.5,    0.4375, -0.0625},

            -- Lower rail
            {-0.5,    -0.3125, -0.1875, 0.5,   -0.0625, -0.0625},
        }
    },

    selection_box = {
        type = "fixed",
        fixed = {-0.5, -0.5, -0.1875, 0.5, 0.5, 0.3125},
    },
})

minetest.register_node("cw_core:fence_corner", {
    description = "Corner Fence",
    drawtype = "nodebox",
    tiles = {
        "cw_core_fence_top.png",
        "cw_core_fence_bottom.png",
        "cw_core_fence_side.png"
    },
    paramtype = "light",
    sunlight_propagates = true,
    walkable = true,
    groups = {choppy = 2, oddly_breakable_by_hand = 2, flammable = 2},

    node_box = {
        type = "fixed",
        fixed = {
            -- Post (same as straight fence)
            {-0.1875, -0.5, -0.0625, 0.1875, 0.5, 0.3125},

            -- Rails along X (same as straight fence)
            {-0.5, 0.0625, -0.1875, 0.0, 0.4375, -0.0625},   -- Upper X rail
            {-0.5, -0.3125, -0.1875, 0.0, -0.0625, -0.0625}, -- Lower X rail

            -- Rails along Z (mirrored geometry)
            {-0.1875, 0.0625, -0.5, -0.0625, 0.4375, 0.0},   -- Upper Z rail
            {-0.1875, -0.3125, -0.5, -0.0625, -0.0625, 0.0}, -- Lower Z rail
        },
    },

    selection_box = {
        type = "fixed",
        fixed = {-0.5, -0.5, -0.5, 0.1875, 0.5, 0.3125},
    },
})
