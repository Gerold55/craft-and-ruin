-- ============================================================================
-- Craft & Ruin – Biomes (Clean Rewrite)
-- Minecraft-style climate + height, C2 cold family, swamp, inland mesa
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

-- Frozen ocean (C2)
biome({
    name = "frozen_ocean",
    node_top = "cw_core:snow_block",
    depth_top = 1,
    node_filler = "cw_core:stone",
    depth_filler = 3,
    node_stone = "cw_core:stone",
    y_min = -32,
    y_max = 0,
    heat_point = 5,
    humidity_point = 60,
})

-- ============================================================================
-- BEACHES (NO MESA BEACH)
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
    heat_point = 10,
    humidity_point = 50,
})

-- ============================================================================
-- PLAINS FAMILY
-- ============================================================================

biome({
    name = "plains",
    node_top = "cw_core:grass_block",
    depth_top = 1,
    node_filler = "cw_core:dirt",
    depth_filler = 5,
    node_stone = "cw_core:stone",
    y_min = 4,
    y_max = 80,
    heat_point = 45,
    humidity_point = 45,
})

-- Snowy plains (C2)
biome({
    name = "snowy_plains",
    node_top = "cw_core:grass_block_snow",
    depth_top = 1,
    node_filler = "cw_core:dirt",
    depth_filler = 5,
    node_stone = "cw_core:stone",
    y_min = 4,
    y_max = 80,
    heat_point = 5,
    humidity_point = 40,
})

-- Rolling hills as higher plains variant
biome({
    name = "rolling_hills",
    node_top = "cw_core:grass_block",
    depth_top = 1,
    node_filler = "cw_core:dirt",
    depth_filler = 5,
    node_stone = "cw_core:stone",
    y_min = 40,
    y_max = 120,
    heat_point = 45,
    humidity_point = 45,
})

-- ============================================================================
-- FORESTS (TEMPERATE / WARM)
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
    heat_point = 55,
    humidity_point = 60,
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

-- Swamp
biome({
    name = "swamp",
    node_top = "cw_core:grass_block",
    depth_top = 1,
    node_filler = "cw_core:dirt",
    depth_filler = 3,
    node_stone = "cw_core:stone",

    -- Swamps sit at low elevation
    y_min = 0,
    y_max = 20,

    -- Warm + very humid
    heat_point = 60,
    humidity_point = 90,
})

-- ============================================================================
-- WARM / DRY (SAVANNA / DESERT / MESA INLAND)
-- ============================================================================

biome({
    name = "savanna",
    node_top = "cw_core:grass_block",
    depth_top = 1,
    node_filler = "cw_core:dirt",
    depth_filler = 3,
    node_stone = "cw_core:stone",
    y_min = 4,
    y_max = 80,
    heat_point = 70,
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
    y_max = 80,
    heat_point = 90,
    humidity_point = 10,
})

-- Mesa / Badlands – inland only (no beach)
biome({
    name = "clayspire_basin",
    node_top = "cw_core:terracotta_yellow",
    depth_top = 1,
    node_filler = "cw_core:terracotta_orange",
    depth_filler = 3,
    node_stone = "cw_core:stone",
    y_min = 70,
    y_max = 160,
    heat_point = 95,
    humidity_point = 25,
})

-- ============================================================================
-- COOL / COLD FORESTS (C2 FAMILY)
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

-- Taiga (non-snowy)
biome({
    name = "taiga",
    node_top = "cw_core:grass_block",
    depth_top = 1,
    node_filler = "cw_core:dirt",
    depth_filler = 3,
    node_stone = "cw_core:stone",
    y_min = 4,
    y_max = 90,
    heat_point = 20,
    humidity_point = 60,
})

-- Snowy taiga (your taiga_forest)
biome({
    name = "taiga_forest",
    node_top = "cw_core:grass_block_snow",
    depth_top = 1,
    node_filler = "cw_core:dirt",
    depth_filler = 3,
    node_stone = "cw_core:stone",
    y_min = 0,
    y_max = 90,
    heat_point = 10,
    humidity_point = 60,
})

-- Ice biome (snow everywhere)
biome({
    name = "ice_biome",
    node_top = "cw_core:snow_block",
    depth_top = 1,
    node_filler = "cw_core:dirt",
    depth_filler = 3,
    node_stone = "cw_core:stone",
    y_min = 0,
    y_max = 31000,
    heat_point = 0,
    humidity_point = 40,
})

-- Frozen river (C2)
biome({
    name = "frozen_river",
    node_top = "cw_core:snow_block",
    depth_top = 1,
    node_filler = "cw_core:dirt",
    depth_filler = 3,
    node_stone = "cw_core:stone",
    y_min = -4,
    y_max = 2,
    heat_point = 0,
    humidity_point = 60,
})

-- ============================================================================
-- MOUNTAINS / SLOPES / PEAKS (STONE + SNOW, NO DIRT)
-- ============================================================================

-- Base mountains – stone
biome({
    name = "mountains",
    node_top = "cw_core:stone",
    depth_top = 1,
    node_filler = "cw_core:stone",
    depth_filler = 3,
    node_stone = "cw_core:stone",
    y_min = 90,
    y_max = 160,
    heat_point = 20,
    humidity_point = 30,
})

-- Snowy slopes (C2)
biome({
    name = "snowy_slopes",
    node_top = "cw_core:stone",
    depth_top = 1,
    node_filler = "cw_core:stone",
    depth_filler = 3,
    node_stone = "cw_core:stone",
    y_min = 120,
    y_max = 200,
    heat_point = 10,
    humidity_point = 40,
})

-- Frozen peaks (C2)
biome({
    name = "frozen_peaks",
    node_top = "cw_core:snow_block",
    depth_top = 1,
    node_filler = "cw_core:stone",
    depth_filler = 3,
    node_stone = "cw_core:stone",
    y_min = 180,
    y_max = 31000,
    heat_point = 0,
    humidity_point = 30,
})

