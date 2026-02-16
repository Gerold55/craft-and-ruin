-- ============================================================================
-- Craft & Ruin — biomes.lua
-- ============================================================================

minetest.clear_registered_biomes()

-- OCEAN
minetest.register_biome({
    name = "ocean",
    node_top = "cw_core:beach_sand",
    depth_top = 1,
    node_filler = "cw_core:beach_sand",
    depth_filler = 3,
    y_min = -31000,
    y_max = 60,
    heat_point = 50,
    humidity_point = 70,
})

-- DEEP OCEAN
minetest.register_biome({
    name = "deep_ocean",
    node_top = "cw_core:beach_sand",
    depth_top = 1,
    node_filler = "cw_core:beach_sand",
    depth_filler = 3,
    y_min = -31000,
    y_max = 30,
    heat_point = 50,
    humidity_point = 80,
})

-- BEACH
minetest.register_biome({
    name = "beach",
    node_top = "cw_core:beach_sand",
    depth_top = 1,
    node_filler = "cw_core:beach_sand",
    depth_filler = 3,
    y_min = 61,
    y_max = 64,
    heat_point = 50,
    humidity_point = 50,
})

-- MEADOW / PLAINS
minetest.register_biome({
    name = "meadow",
    node_top = "cw_core:grass_block",
    depth_top = 1,
    node_filler = "cw_core:dirt",
    depth_filler = 3,
    y_min = 65,
    y_max = 78,
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
    y_min = 65,
    y_max = 90,
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
    y_min = 65,
    y_max = 90,
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
    y_min = 79,
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
    y_min = 65,
    y_max = 31000,
    heat_point = 90,
    humidity_point = 10,
})

-- RIVER
minetest.register_biome({
    name = "river",
    node_top = "cw_core:gravel",
    depth_top = 1,
    node_filler = "cw_core:gravel",
    depth_filler = 3,
    y_min = -10,
    y_max = 5,
    heat_point = 50,
    humidity_point = 50,
})

