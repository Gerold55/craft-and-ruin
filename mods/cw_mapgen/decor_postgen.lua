-- ============================================================================
-- cw_mapgen: decor_postgen.lua
-- Biomes: Meadow (Plains), Desert
-- Focus: Sparse trees, dense "nuisance" grass, and desert flora.
-- ============================================================================

local MODPATH = core.get_modpath("cw_core")

-- Clear existing decorations to prevent double-spawning
minetest.clear_registered_decorations()

-- 1. SPARSE OAK (The Lone Oak look)
-- We use a deep negative offset to make these extremely rare.
minetest.register_decoration({
    name = "cw_mapgen:sparse_oak",
    deco_type = "schematic",
    place_on = {"cw_core:grass_block"},
    biomes = {"meadow"},
    sidelen = 80, -- Larger area calculation prevents clustering
    noise_params = {
        offset = -0.015,  -- Lower this (e.g., -0.02) if you want fewer trees
        scale = 0.04, 
        spread = {x=300, y=300, z=300}, 
        seed = 2
    },
    schematic = MODPATH .. "/schematics/tree_oak.mts",
    flags = "place_center_x, place_center_z",
    rotation = "random",
})

-- 2. RARE BIRCH (Isolated patches)
minetest.register_decoration({
    name = "cw_mapgen:rare_birch",
    deco_type = "schematic",
    place_on = {"cw_core:grass_block"},
    biomes = {"meadow"},
    sidelen = 80,
    noise_params = {
        offset = -0.05, 
        scale = 0.1, 
        spread = {x=150, y=150, z=150}, 
        seed = 44
    },
    schematic = MODPATH .. "/schematics/tree_birch.mts",
    flags = "place_center_x, place_center_z",
})

-- 3. THE "NUISANCE" (Tall Grass & Flowers)
-- This is kept dense to give the plains texture without needing trees.
minetest.register_decoration({
    name = "cw_mapgen:plains_flora",
    deco_type = "simple",
    place_on = {"cw_core:grass_block"},
    biomes = {"meadow"},
    fill_ratio = 0.06, -- Roughly 6% of grass blocks will have decor
    decoration = {
        "cw_core:grass_decor", 
        "cw_core:grass_tall", 
        "cw_core:flower_dandelion", 
        "cw_core:flower_bluebell", 
        "cw_core:flower_daisy"
    },
})

-- 4. DESERT DEAD BUSHES
minetest.register_decoration({
    name = "cw_mapgen:dead_bushes",
    deco_type = "simple",
    place_on = {"cw_core:sand"},
    biomes = {"desert"}, -- REMOVE "meadow" or any other biome here
    fill_ratio = 0.01,
    decoration = "cw_core:dead_bush",
})

-- 5. REEDS (Sugar Cane - Near water only)
minetest.register_decoration({
    name = "cw_mapgen:reeds",
    deco_type = "simple",
    place_on = {"cw_core:grass_block", "cw_core:sand"},
    biomes = {"meadow", "desert"},
    sidelen = 16,
    noise_params = {
        offset = 0.02, 
        scale = 0.1, 
        spread = {x=20, y=20, z=20}, 
        seed = 123
    },
    decoration = "cw_core:reeds",
    height = 2, 
    height_max = 4,
    spawn_by = "cw_core:water_source",
    num_spawn_by = 1, -- Must be touching water
})