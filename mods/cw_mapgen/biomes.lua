-- ============================================================================
-- Craft & Ruin – Biomes (Final Cold System + Mesa + Plains + Forests)
-- ============================================================================

local function biome(def)
    minetest.register_biome(def)
end

-- ============================================================================
-- OCEANS
-- ============================================================================

biome({
    name = "ocean",
    node_top = "cw_core:sand",
    depth_top = 1,
    node_filler = "cw_core:sand",
    depth_filler = 3,
    node_stone = "cw_core:stone",
    y_min = -32,
    y_max = 0,
    heat_point = 50,
    humidity_point = 50,
})

biome({
    name = "deep_ocean",
    node_top = "cw_core:sand",
    depth_top = 1,
    node_filler = "cw_core:stone",
    depth_filler = 3,
    node_stone = "cw_core:stone",
    y_min = -31000,
    y_max = -33,
    heat_point = 50,
    humidity_point = 50,
})

-- ============================================================================
-- BEACHES
-- ============================================================================

biome({
    name = "beach",
    node_top = "cw_core:beach_sand",
    depth_top = 1,
    node_filler = "cw_core:beach_sand",
    depth_filler = 3,
    node_stone = "cw_core:stone",
    y_min = 0,
    y_max = 4,
    heat_point = 60,
    humidity_point = 40,
})

biome({
    name = "cold_beach",
    node_top = "cw_core:snow_block",
    depth_top = 1,
    node_filler = "cw_core:dirt",
    depth_filler = 3,
    node_stone = "cw_core:stone",
    y_min = 0,
    y_max = 4,
    heat_point = 20,
    humidity_point = 40,
})

biome({
    name = "mesa_beach",
    node_top = "cw_core:red_sand",
    depth_top = 1,
    node_filler = "cw_core:red_sand",
    depth_filler = 3,
    node_stone = "cw_core:stone",
    y_min = 0,
    y_max = 4,
    heat_point = 95,
    humidity_point = 25,
})

-- ============================================================================
-- PLAINS / SAVANNA / DESERT / MESA
-- ============================================================================

biome({
    name = "plains",
    node_top = "cw_core:grass_block",
    depth_top = 1,
    node_filler = "cw_core:dirt",
    depth_filler = 3,
    node_stone = "cw_core:stone",
    y_min = 4,
    y_max = 60,
    heat_point = 40,
    humidity_point = 50,
})

biome({
    name = "savanna",
    node_top = "cw_core:grass_block",
    depth_top = 1,
    node_filler = "cw_core:dirt",
    depth_filler = 3,
    node_stone = "cw_core:stone",
    y_min = 4,
    y_max = 70,
    heat_point = 65,
    humidity_point = 35,
})

biome({
    name = "desert",
    node_top = "cw_core:desert_sand",
    depth_top = 1,
    node_filler = "cw_core:desert_sand",
    depth_filler = 3,
    node_stone = "cw_core:stone",
    y_min = 4,
    y_max = 70,
    heat_point = 90,
    humidity_point = 10,
})

biome({
    name = "clayspire_basin",
    node_top = "cw_core:terracotta_yellow",
    depth_top = 1,
    node_filler = "cw_core:terracotta_orange",
    depth_filler = 3,
    node_stone = "cw_core:stone",
    y_min = 80,
    y_max = 160,
    heat_point = 95,
    humidity_point = 25,
})

-- ============================================================================
-- TEMPERATE / WARM FORESTS
-- ============================================================================

biome({
    name = "forest",
    node_top = "cw_core:grass_block",
    depth_top = 1,
    node_filler = "cw_core:dirt",
    depth_filler = 3,
    node_stone = "cw_core:stone",
    y_min = 4,
    y_max = 90,
    heat_point = 50,
    humidity_point = 70,
})

biome({
    name = "birch_forest",
    node_top = "cw_core:grass_block",
    depth_top = 1,
    node_filler = "cw_core:dirt",
    depth_filler = 3,
    node_stone = "cw_core:stone",
    y_min = 4,
    y_max = 90,
    heat_point = 60,
    humidity_point = 55,
})

biome({
    name = "cherry_grove",
    node_top = "cw_core:grass_block",
    depth_top = 1,
    node_filler = "cw_core:dirt",
    depth_filler = 3,
    node_stone = "cw_core:stone",
    y_min = 20,
    y_max = 100,
    heat_point = 45,
    humidity_point = 80,
})

biome({
    name = "jungle",
    node_top = "cw_core:grass_block",
    depth_top = 1,
    node_filler = "cw_core:dirt",
    depth_filler = 3,
    node_stone = "cw_core:stone",
    y_min = 4,
    y_max = 100,
    heat_point = 90,
    humidity_point = 90,
})

-- ============================================================================
-- COOL / COLD FORESTS + ICE
-- ============================================================================

biome({
    name = "spruce_forest",
    node_top = "cw_core:grass_block",
    depth_top = 1,
    node_filler = "cw_core:dirt",
    depth_filler = 3,
    node_stone = "cw_core:stone",
    y_min = 4,
    y_max = 90,
    heat_point = 30,
    humidity_point = 65,
})

biome({
    name = "taiga_forest",
    node_top = "cw_core:grass_block_snow",
    depth_top = 1,
    node_filler = "cw_core:dirt",
    depth_filler = 3,
    node_stone = "cw_core:stone",
    y_min = 0,
    y_max = 90,
    heat_point = 15,
    humidity_point = 60,
})

biome({
    name = "ice_biome",
    node_top = "cw_core:snow_block",
    depth_top = 1,
    node_filler = "cw_core:dirt",
    depth_filler = 3,
    node_stone = "cw_core:stone",
    y_min = 0,
    y_max = 31000,
    heat_point = 5,
    humidity_point = 40,
})

-- ============================================================================
-- HILLS / MOUNTAINS
-- ============================================================================

biome({
    name = "rolling_hills",
    node_top = "cw_core:grass_block",
    depth_top = 1,
    node_filler = "cw_core:dirt",
    depth_filler = 3,
    node_stone = "cw_core:stone",
    y_min = 40,
    y_max = 140,
    heat_point = 50,
    humidity_point = 50,
})

biome({
    name = "mountains",
    node_top = "cw_core:stone",
    depth_top = 1,
    node_filler = "cw_core:stone",
    depth_filler = 3,
    node_stone = "cw_core:stone",
    y_min = 90,
    y_max = 31000,
    heat_point = 20,
    humidity_point = 30,
})

