-- ============================================================================
-- cw_mapgen: decor_postgen.lua
-- Minecraft-style decoration rules (fixed + tuned)
-- ============================================================================

local MODPATH = core.get_modpath("cw_core")

-- Clear all decorations so only ours apply
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
    fill_ratio = 0.0008,
    noise_params = {
        offset = -0.02,
        scale = 0.03,
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
    fill_ratio = 0.0005,
    noise_params = {
        offset = -0.025,
        scale = 0.025,
        spread = {x=500, y=500, z=500},
        seed = 202
    },
    schematic = MODPATH .. "/schematics/tree_oak_large.mts",
    flags = "place_center_x, place_center_z, force_placement",
    place_offset_y = 1,
    rotation = "random",
})

-- FOREST: Light, natural oak forest (FIXED)
core.register_decoration({
    name = "cw_mapgen:forest_oak",
    deco_type = "schematic",
    place_on = {"cw_core:grass_block"},
    biomes = {"forest", "meadow"}, -- FIXED
    sidelen = 48,
    fill_ratio = 0.0015, -- FIXED
    noise_params = {
        offset = -0.03, -- FIXED
        scale = 0.04,   -- FIXED
        spread = {x=350, y=350, z=350}, -- FIXED
        seed = 303
    },
    schematic = MODPATH .. "/schematics/tree_oak.mts",
    flags = "place_center_x, place_center_z, force_placement",
    place_offset_y = 1,
    rotation = "random",
})

-- BIRCH FOREST: Birch-dominant (FIXED)
core.register_decoration({
    name = "cw_mapgen:birch_forest_birch",
    deco_type = "schematic",
    place_on = {"cw_core:grass_block"},
    biomes = {"birch_forest"},
    sidelen = 48,
    fill_ratio = 0.0018,
    noise_params = {
        offset = -0.02,
        scale = 0.045,
        spread = {x=300, y=300, z=300},
        seed = 404
    },
    schematic = MODPATH .. "/schematics/tree_birch.mts",
    flags = "place_center_x, place_center_z, force_placement",
    place_offset_y = 1,
    rotation = "random",
})

-- ============================================================================
-- 🌾 GRASS & FLOWERS — Natural, clumped, not overwhelming
-- ============================================================================

core.register_decoration({
    name = "cw_mapgen:meadow_grass",
    deco_type = "simple",
    place_on = {"cw_core:grass_block"},
    biomes = {"meadow"},
    sidelen = 24,
    fill_ratio = 0.05,
    noise_params = {
        offset = 0.0,
        scale = 0.15,
        spread = {x=32, y=32, z=32},
        seed = 505
    },
    decoration = {
        "cw_core:grass_decor",
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
    place_on = {"cw_core:desert_sand"},
    biomes = {"desert"},
    sidelen = 32,
    fill_ratio = 0.02,
    decoration = {"cw_core:cactus", "cw_core:dead_bush"},
})

-- ============================================================================
-- 🌊 REEDS — Minecraft-accurate
-- ============================================================================

-- 1. DEFINE THE SCHEMATICS (1, 2, and 3 tall)
local reed_1 = { size = {x=1, y=1, z=1}, data = {{name="cw_core:reeds_bottom"}} }
local reed_2 = { size = {x=1, y=2, z=1}, data = {{name="cw_core:reeds_bottom"}, {name="cw_core:reeds_top"}} }
local reed_3 = { size = {x=1, y=3, z=1}, data = {{name="cw_core:reeds_bottom"}, {name="cw_core:reeds_bottom"}, {name="cw_core:reeds_top"}} }

-- 2. HELPER FUNCTION TO REGISTER REEDS
local function register_reed(name, schematic, ratio)
    core.register_decoration({
        name = "cw_mapgen:shore_reeds_" .. name,
        deco_type = "schematic",
        place_on = {"cw_core:beach_sand", "cw_core:desert_sand"},
        sidelen = 16,
        fill_ratio = ratio,
        biomes = {"beach", "desert"},
        y_min = 64,
        y_max = 66,
        schematic = schematic,
        spawn_by = "cw_core:water_source",
        num_spawn_by = 1,
        flags = "force_placement",
    })
end

-- 3. REGISTER THE MIX (Total density ~0.06)
register_reed("short",  reed_1, 0.03)
register_reed("medium", reed_2, 0.02)
register_reed("tall",   reed_3, 0.01)