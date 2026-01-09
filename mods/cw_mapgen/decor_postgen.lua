-- ============================================================================
-- cw_mapgen: decor_postgen.lua
-- Minecraft-style decoration rules
-- ============================================================================

local MODPATH = core.get_modpath("cw_core")

core.clear_registered_decorations()

-- ============================================================================
-- 🌳 TREES — Minecraft spacing & rarity
-- ============================================================================

-- PLAINS / MEADOW: Lone Oaks (VERY RARE)
core.register_decoration({
    name = "cw_mapgen:meadow_oak_sparse",
    deco_type = "schematic",
    place_on = {"cw_core:grass_block"},
    biomes = {"meadow"},
    sidelen = 96,
    noise_params = {
        offset = -0.02,
        scale = 0.035,
        spread = {x=400, y=400, z=400},
        seed = 101
    },
    schematic = MODPATH .. "/schematics/tree_oak.mts",
    flags = "place_center_x, place_center_z",
    rotation = "random",
})

-- MEADOW: Rare Large Oaks
core.register_decoration({
    name = "cw_mapgen:meadow_oak_large",
    deco_type = "schematic",
    place_on = {"cw_core:grass_block"},
    biomes = {"meadow"},
    sidelen = 112,
    noise_params = {
        offset = -0.025,
        scale = 0.03,
        spread = {x=500, y=500, z=500},
        seed = 202
    },
    schematic = MODPATH .. "/schematics/tree_oak_large.mts",
    flags = "place_center_x, place_center_z, force_placement",
    place_offset_y = 1,
    rotation = "random",
})

-- FOREST: Dense Oaks
core.register_decoration({
    name = "cw_mapgen:forest_oak",
    deco_type = "schematic",
    place_on = {"cw_core:grass_block"},
    biomes = {"forest, meadow"},
    sidelen = 48,
    noise_params = {
        offset = -0.01,
        scale = 0.08,
        spread = {x=180, y=180, z=180},
        seed = 303
    },
    schematic = MODPATH .. "/schematics/tree_oak.mts",
    flags = "place_center_x, place_center_z, force_placement",
    place_offset_y = 1,
    rotation = "random",
})

-- BIRCH FOREST: Birch-dominant
core.register_decoration({
    name = "cw_mapgen:birch_forest_birch",
    deco_type = "schematic",
    place_on = {"cw_core:grass_block"},
    biomes = {"birch_forest"},
    sidelen = 48,
    noise_params = {
        offset = -0.015,
        scale = 0.06,
        spread = {x=220, y=220, z=220},
        seed = 404
    },
    schematic = MODPATH .. "/schematics/tree_birch.mts",
    flags = "place_center_x, place_center_z, force_placement",
    place_offset_y = 1,
    rotation = "random",
})

-- ============================================================================
-- 🌾 GRASS & FLOWERS — Dense but naturally clumped
-- ============================================================================

core.register_decoration({
    name = "cw_mapgen:meadow_grass",
    deco_type = "simple",
    place_on = {"cw_core:grass_block"},
    biomes = {"meadow"},
    sidelen = 16,
    noise_params = {
        offset = 0.0,
        scale = 0.15,
        spread = {x=32, y=32, z=32},
        seed = 505
    },
    decoration = {
        "cw_core:grass_decor",
        "cw_core:grass_tall",
        "cw_core:flower_dandelion",
        "cw_core:flower_bluebell",
        "cw_core:flower_daisy"
    },
})

-- ============================================================================
-- 🌵 DESERT DECOR — Sparse, intentional
-- ============================================================================

core.register_decoration({
    name = "cw_mapgen:dry_flora",
    deco_type = "simple",
    place_on = {"cw_core:sand"},
    biomes = {"desert"}, -- Engine checks the Heat > 70 wall here
    fill_ratio = 0.02,
    decoration = {"cw_core:cactus", "cw_core:dead_bush"},
})

-- ============================================================================
-- 🌊 REEDS — Minecraft-accurate
-- ============================================================================

core.register_decoration({
    name = "cw_mapgen:reeds",
    deco_type = "simple",
    place_on = {"cw_core:grass_block", "cw_core:sand"},
    biomes = {"meadow", "desert"},
    sidelen = 16,
    noise_params = {
        offset = 0.01,
        scale = 0.06,
        spread = {x=24, y=24, z=24},
        seed = 707
    },
    decoration = "cw_core:reeds",
    height = 2,
    height_max = 4,
    spawn_by = "cw_core:water_source",
    num_spawn_by = 1,
})
