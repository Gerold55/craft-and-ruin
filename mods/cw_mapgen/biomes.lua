-- ============================================================================
-- Craft & Ruin — biomes.lua (Classic Minetest Sea Level = 1)
-- ============================================================================

minetest.clear_registered_biomes()

-- DEEP OCEAN
minetest.register_biome({
    name = "deep_ocean",
    node_top = "cw_core:beach_sand",
    depth_top = 1,
    node_filler = "cw_core:beach_sand",
    depth_filler = 3,
    y_min = -31000,
    y_max = -20,
    heat_point = 50,
    humidity_point = 80,
})

-- OCEAN
minetest.register_biome({
    name = "ocean",
    node_top = "cw_core:beach_sand",
    depth_top = 1,
    node_filler = "cw_core:beach_sand",
    depth_filler = 3,
    y_min = -19,
    y_max = 0,
    heat_point = 50,
    humidity_point = 70,
})

-- RIVER
minetest.register_biome({
    name = "river",
    node_top = "cw_core:gravel",
    depth_top = 1,
    node_filler = "cw_core:gravel",
    depth_filler = 3,
    y_min = -5,
    y_max = 1,
    heat_point = 50,
    humidity_point = 50,
})

-- BEACH
minetest.register_biome({
    name = "beach",
    node_top = "cw_core:beach_sand",
    depth_top = 1,
    node_filler = "cw_core:beach_sand",
    depth_filler = 3,
    y_min = 1,
    y_max = 3,
    heat_point = 50,
    humidity_point = 50,
})

-- MEADOW
minetest.register_biome({
    name = "meadow",
    node_top = "cw_core:grass_block",
    depth_top = 1,
    node_filler = "cw_core:dirt",
    depth_filler = 3,
    y_min = 4,
    y_max = 20,
    heat_point = 40,
    humidity_point = 40,
})

-- FOREST
minetest.register_biome({
    name = "forest",
    node_top = "cw_core:grass_block",
    depth_top = 1,
    node_filler = "cw_core:dirt",
    depth_filler = 3,
    y_min = 4,
    y_max = 40,
    heat_point = 45,
    humidity_point = 55,
})

-- BIRCH FOREST
minetest.register_biome({
    name = "birch_forest",
    node_top = "cw_core:grass_block",
    depth_top = 1,
    node_filler = "cw_core:dirt",
    depth_filler = 3,
    y_min = 4,
    y_max = 40,
    heat_point = 35,
    humidity_point = 60,
})

-- CHERRY GROVE
minetest.register_biome({
    name = "cherry_grove",
    node_top = "cw_core:grass_block",
    depth_top = 1,
    node_filler = "cw_core:dirt",
    depth_filler = 3,
    y_min = 41,
    y_max = 31000,
    heat_point = 30,
    humidity_point = 60,
})

-- DESERT
minetest.register_biome({
    name = "desert",
    node_top = "cw_core:desert_sand",
    depth_top = 1,
    node_filler = "cw_core:desert_sand",
    depth_filler = 3,
    y_min = 4,
    y_max = 31000,
    heat_point = 90,
    humidity_point = 10,
})

