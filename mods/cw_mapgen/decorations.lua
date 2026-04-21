-- Simple helper not strictly needed, but keeps things tidy
local function deco(def)
    minetest.register_decoration(def)
end

-- PLAINS GRASS ---------------------------------------------------------
deco({
    name = "cw_biomes:grass_plains",
    deco_type = "simple",
    place_on = {"cw_core:grass_block"},
    sidelen = 16,
    fill_ratio = 0.10,
    decoration = "cw_core:grass_decor",
    biomes = {"cw_biomes:plains"},
})

-- PLAINS FLOWERS -------------------------------------------------------
deco({
    name = "cw_biomes:flowers_plains",
    deco_type = "simple",
    place_on = {"cw_core:grass_block"},
    sidelen = 16,
    fill_ratio = 0.02,
    decoration = {"cw_core:flower_daisy"},
    biomes = {"cw_biomes:plains"},
})

-- BIRCH FOREST FLOWERS -------------------------------------------------
deco({
    name = "cw_biomes:flowers_birch",
    deco_type = "simple",
    place_on = {"cw_core:grass_block"},
    sidelen = 16,
    fill_ratio = 0.02,
    decoration = {"cw_core:flower_bluebell"},
    biomes = {"cw_biomes:birch_forest"},
})

-- CHERRY GROVE GRASS ---------------------------------------------------
deco({
    name = "cw_biomes:grass_cherry",
    deco_type = "simple",
    place_on = {"cw_core:grass_block"},
    sidelen = 16,
    fill_ratio = 0.06,
    decoration = "cw_core:grass_decor",
    biomes = {"cw_biomes:cherry_grove"},
})

-- DESERT CACTUS --------------------------------------------------------
deco({
    name = "cw_biomes:cactus",
    deco_type = "simple",
    place_on = {"cw_core:sand"},
    sidelen = 16,
    fill_ratio = 0.01,
    decoration = "cw_core:cactus",
    biomes = {"cw_biomes:desert"},
})

-- DESERT DEAD BUSH -----------------------------------------------------
deco({
    name = "cw_biomes:dead_bush",
    deco_type = "simple",
    place_on = {"cw_core:sand"},
    sidelen = 16,
    fill_ratio = 0.02,
    decoration = "cw_core:dead_bush",
    biomes = {"cw_biomes:desert"},
})

-- MOUNTAIN MEADOW FLOWERS ----------------------------------------------
deco({
    name = "cw_biomes:flowers_meadow",
    deco_type = "simple",
    place_on = {"cw_core:grass_block"},
    sidelen = 16,
    fill_ratio = 0.03,
    decoration = {"cw_core:flower_daisy", "cw_core:flower_bluebell"},
    biomes = {"cw_biomes:mountain_meadow"},
})
