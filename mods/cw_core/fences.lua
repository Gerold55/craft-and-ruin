local MOD = "cw_core"

local wood_types = {
    {name = "oak",    desc = "Oak",    tile = "cw_oak_log.png"},
    {name = "cherry", desc = "Cherry", tile = "cherry_log.png"},
    {name = "birch",  desc = "Birch",  tile = "cw_birch_log.png"},
    {name = "spruce", desc = "Spruce", tile = "cw_spruce_log.png"},
    {name = "jungle", desc = "Jungle", tile = "log_jungle.png"},
}

-- FENCE GEOMETRY (rails raised by 1 pixel = +0.0625)
local function mc_fence_boxes(connect)
    local boxes = {}

    -- Center post
    if connect.north or connect.south or connect.east or connect.west or connect.alone then
        table.insert(boxes, {
            -0.125, -0.5,   -0.125,
             0.125,  0.5,    0.125
        })
    end

    -- Rails (raised by 1px)
    if connect.north then
        table.insert(boxes, {-0.0625, -0.125, -0.5, 0.0625, 0.0625, -0.125})
        table.insert(boxes, {-0.0625,  0.1875, -0.5, 0.0625, 0.375,  -0.125})
    end
    if connect.south then
        table.insert(boxes, {-0.0625, -0.125, 0.125, 0.0625, 0.0625, 0.5})
        table.insert(boxes, {-0.0625,  0.1875, 0.125, 0.0625, 0.375,  0.5})
    end
    if connect.east then
        table.insert(boxes, {0.125, -0.125, -0.0625, 0.5, 0.0625, 0.0625})
        table.insert(boxes, {0.125,  0.1875, -0.0625, 0.5, 0.375,  0.0625})
    end
    if connect.west then
        table.insert(boxes, {-0.5, -0.125, -0.0625, -0.125, 0.0625, 0.0625})
        table.insert(boxes, {-0.5,  0.1875, -0.0625, -0.125, 0.375,  0.0625})
    end

    return boxes
end

------------------------------------------------------------
-- 1. WOOD FENCES
------------------------------------------------------------

for _, wood in ipairs(wood_types) do
    minetest.register_node(MOD .. ":fence_" .. wood.name, {
        description = wood.desc .. " Fence",
        drawtype = "nodebox",
        tiles = {wood.tile},

        inventory_image = "cw_fence_" .. wood.name .. "_item.png",
        wield_image     = "cw_fence_" .. wood.name .. "_item.png",

        paramtype = "light",
        groups = {choppy = 2, flammable = 2, fence = 1},
        connects_to = {"group:fence", "group:gate", "group:solid"},

        node_box = {
            type = "connected",
            fixed = mc_fence_boxes({alone = true}),
            connect_front = mc_fence_boxes({north = true}),
            connect_back  = mc_fence_boxes({south = true}),
            connect_left  = mc_fence_boxes({west = true}),
            connect_right = mc_fence_boxes({east = true}),
        },

        collision_box = {
            type = "fixed",
            fixed = {
                -0.5, -0.5, -0.5,
                 0.5,  1.5,  0.5
            }
        },
    })
end

------------------------------------------------------------
-- 2. GATES (Minecraft Bedrock geometry)
------------------------------------------------------------

local gate_closed_box = {
    type = "fixed",
    fixed = {
        {-0.5, -0.1875, -0.0625, -0.375, 0.5,    0.0625},
        {0.375, -0.1875, -0.0625, 0.5,    0.5,    0.0625},
        {-0.375, 0.25,   -0.0625, 0.375,  0.4375, 0.0625},
        {-0.125, 0.0625, -0.0625, 0.125,  0.25,   0.0625},
        {-0.375, -0.125, -0.0625, 0.375,  0.0625, 0.0625},
    }
}

local gate_open_box = {
    type = "fixed",
    fixed = {
        {-0.5,   -0.1875, -0.0625, -0.375, 0.5,    0.0625},
        {0.375,  -0.1875, -0.0625, 0.5,    0.5,    0.0625},

        {-0.5,   0.25,   -0.4375, -0.375, 0.4375, -0.0625},
        {-0.5,   0.0625, -0.4375, -0.375, 0.25,   -0.3125},
        {-0.5,  -0.125,  -0.4375, -0.375, 0.0625, -0.0625},

        {0.375, -0.125,  -0.4375, 0.5,    0.0625, -0.0625},
        {0.375,  0.0625, -0.4375, 0.5,    0.25,   -0.3125},
        {0.375,  0.25,   -0.4375, 0.5,    0.4375, -0.0625},
    }
}

for _, wood in ipairs(wood_types) do
    local closed = MOD .. ":gate_" .. wood.name .. "_closed"
    local open   = MOD .. ":gate_" .. wood.name .. "_open"

    -- CLOSED GATE
    minetest.register_node(closed, {
        description = wood.desc .. " Fence Gate",
        drawtype = "nodebox",
        tiles = {wood.tile},

        inventory_image = "cw_gate_" .. wood.name .. "_item.png",
        wield_image     = "cw_gate_" .. wood.name .. "_item.png",

        paramtype = "light",
        paramtype2 = "facedir",

        groups = {choppy = 2, gate = 1},
        connects_to = {"group:fence", "group:solid"},

        node_box = gate_closed_box,

        collision_box = {
            type = "fixed",
            fixed = {
                -0.5, -0.5, -0.5,
                 0.5,  1.5,  0.5
            }
        },

        on_rightclick = function(pos, node)
            minetest.set_node(pos, {name = open, param2 = node.param2})
        end,
    })

    -- OPEN GATE
    minetest.register_node(open, {
        drawtype = "nodebox",
        tiles = {wood.tile},

        inventory_image = "cw_gate_" .. wood.name .. "_item.png",
        wield_image     = "cw_gate_" .. wood.name .. "_item.png",

        paramtype = "light",
        paramtype2 = "facedir",
        walkable = false,
        drop = closed,

        groups = {choppy = 2, gate = 1, not_in_creative_inventory = 1},
        connects_to = {"group:fence", "group:solid"},

        node_box = gate_open_box,

        collision_box = {
            type = "fixed",
            fixed = {}
        },

        on_rightclick = function(pos, node)
            minetest.set_node(pos, {name = closed, param2 = node.param2})
        end,
    })
end

------------------------------------------------------------
-- 3. STRAIGHT FENCE (hidden)
------------------------------------------------------------

minetest.register_node("cw_core:fence_straight", {
    description = "Straight Fence",
    drawtype = "nodebox",
    tiles = {"cw_core_fence_side.png"},

    inventory_image = "cw_fence_post_item.png",
    wield_image     = "cw_fence_post_item.png",

    paramtype = "light",

    groups = {choppy = 2, flammable = 2, fence = 1, not_in_creative_inventory = 1},
    connects_to = {"group:fence", "group:gate", "group:solid"},

    node_box = {
        type = "fixed",
        fixed = {
            {-0.125, -0.5, -0.125, 0.125, 0.5, 0.125},

            {-0.0625, -0.125, -0.5, 0.0625, 0.0625, 0.5},
            {-0.0625,  0.1875, -0.5, 0.0625, 0.375,  0.5},
        }
    },

    collision_box = {
        type = "fixed",
        fixed = {
            -0.5, -0.5, -0.5,
             0.5,  1.5,  0.5
        }
    },
})

------------------------------------------------------------
-- 4. CORNER FENCE (hidden)
------------------------------------------------------------

minetest.register_node("cw_core:fence_corner", {
    description = "Corner Fence",
    drawtype = "nodebox",
    tiles = {"cw_core_fence_side.png"},

    inventory_image = "cw_fence_post_item.png",
    wield_image     = "cw_fence_post_item.png",

    paramtype = "light",

    groups = {choppy = 2, flammable = 2, fence = 1, not_in_creative_inventory = 1},
    connects_to = {"group:fence", "group:gate", "group:solid"},

    node_box = {
        type = "fixed",
        fixed = {
            {-0.125, -0.5, -0.125, 0.125, 0.5, 0.125},

            {-0.0625, -0.125, -0.5,    0.0625, 0.0625, -0.125},
            {-0.0625,  0.1875, -0.5,    0.0625, 0.375,  -0.125},

            {-0.5,    -0.125, -0.0625, -0.125, 0.0625,  0.0625},
            {-0.5,     0.1875, -0.0625, -0.125, 0.375,   0.0625},
        }
    },

    collision_box = {
        type = "fixed",
        fixed = {
            -0.5, -0.5, -0.5,
             0.5,  1.5,  0.5
        }
    },
})

------------------------------------------------------------
-- 5. SIDE CONNECTION FENCE (hidden)
------------------------------------------------------------

minetest.register_node("cw_core:fence_side", {
    description = "Side Fence",
    drawtype = "nodebox",
    tiles = {"cw_core_fence_side.png"},

    inventory_image = "cw_fence_post_item.png",
    wield_image     = "cw_fence_post_item.png",

    paramtype = "light",

    groups = {choppy = 2, flammable = 2, fence = 1, not_in_creative_inventory = 1},
    connects_to = {"group:fence", "group:gate", "group:solid"},

    node_box = {
        type = "fixed",
        fixed = {
            {-0.125, -0.5, -0.125, 0.125, 0.5, 0.125},

            -- East rails (raised 1px)
            {0.125, 0.3125, -0.0625, 0.5, 0.5,    0.0625},
            {0.125, -0.0625, -0.0625, 0.5, 0.125, 0.0625},

            -- South rails (raised 1px)
            {-0.0625, -0.0625, 0.125, 0.0625, 0.125, 0.5},
            {-0.0625, 0.3125,  0.125, 0.0625, 0.5,   0.5},
        }
    },

    collision_box = {
        type = "fixed",
        fixed = {
            -0.5, -0.5, -0.5,
             0.5,  1.5,  0.5
        }
    },
})
