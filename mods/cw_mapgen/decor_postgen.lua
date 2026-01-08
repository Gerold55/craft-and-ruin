-- ============================================================================
-- cw_mapgen: decor_postgen.lua
-- Plains, Taiga, Desert, and Water-side Reeds
-- ============================================================================

local MODPATH = core.get_modpath("cw_core")
local schems = {
    oak    = MODPATH .. "/schematics/tree_oak.mts",
    birch  = MODPATH .. "/schematics/tree_birch.mts",
    spruce = MODPATH .. "/schematics/tree_spruce.mts",
}

minetest.clear_registered_decorations()

-- 1. REEDS (Sugar Cane) - Spawns near water in Plains and Deserts
minetest.register_decoration({
    name = "cw_mapgen:reeds",
    deco_type = "simple",
    place_on = {"cw_core:grass_block", "cw_core:sand"},
    sidelen = 16,
    noise_params = {offset = 0.1, scale = 0.2, spread = {x=20, y=20, z=20}, seed=123},
    decoration = "cw_core:reeds",
    height = 2, height_max = 4,
    spawn_by = "cw_core:water_source",
    num_spawn_by = 1,
})

-- 2. DESERT CACTUS
minetest.register_decoration({
    name = "cw_mapgen:cactus",
    deco_type = "simple",
    place_on = {"cw_core:sand"},
    sidelen = 16,
    noise_params = {offset = -0.01, scale = 0.05, spread = {x=50, y=50, z=50}, seed=888},
    biomes = {"desert"},
    decoration = "cw_core:cactus", -- Assuming you have a cactus node
    height = 2, height_max = 3,
})

-- 3. SPARSE OAK (Plains/Meadow)
minetest.register_decoration({
    name = "cw_mapgen:sparse_oak",
    deco_type = "schematic",
    place_on = {"cw_core:grass_block"},
    sidelen = 80,
    noise_params = {offset = 0.0008, scale = 0.002, spread = {x=250, y=250, z=250}, seed=2},
    schematic = schems.oak,
    flags = "place_center_x, place_center_z",
    rotation = "random",
})

-- 4. TAIGA (Dense Spruce)
minetest.register_decoration({
    name = "cw_mapgen:taiga_spruce",
    deco_type = "schematic",
    place_on = {"cw_core:grass_block"},
    noise_params = {offset = 0.03, scale = 0.05, spread = {x=150, y=150, z=150}, seed=911},
    schematic = schems.spruce,
    flags = "place_center_x, place_center_z",
})

-- 5. FLOWER PATCHES (Dandelions/Bluebells)
minetest.register_decoration({
    name = "cw_mapgen:flower_clumps",
    deco_type = "simple",
    place_on = {"cw_core:grass_block"},
    noise_params = {offset = -0.15, scale = 0.6, spread = {x=40, y=40, z=40}, seed=55},
    decoration = {"cw_core:flower_dandelion", "cw_core:flower_bluebell"},
})

-- 6. NUISANCE GRASS (Dense Plains Grass)
minetest.register_decoration({
    name = "cw_mapgen:plains_grass",
    deco_type = "simple",
    place_on = {"cw_core:grass_block"},
    noise_params = {offset = 0.15, scale = 0.5, spread = {x=50, y=50, z=50}, seed=333},
    decoration = {"cw_core:grass_decor", "cw_core:grass_tall"},
})