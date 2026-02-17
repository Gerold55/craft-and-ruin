-- ============================================================================
-- cw_mapgen: decor_postgen.lua
-- Minecraft-style decoration rules
-- ============================================================================

local MODPATH = minetest.get_modpath("cw_core")
local SEALEVEL = 1

-- IMPORTANT:
-- Do NOT clear ALL decorations from the entire game unless you truly intend to.
-- If you want a clean slate, keep this. If not, remove it.
minetest.clear_registered_decorations()

-- ============================================================================
-- 🌳 TREES — Minecraft spacing & rarity
-- ============================================================================

-- PLAINS / MEADOW: Lone Oaks (VERY RARE)
minetest.register_decoration({
    name = "cw_mapgen:meadow_oak_sparse",
    deco_type = "schematic",
    place_on = {"cw_core:grass_block"},
    biomes = {"meadow"},
    sidelen = 96,
    noise_params = {
        offset = -0.02,
        scale = 0.035,
        spread = {x=400, y=400, z=400},
        seed = 101,
    },
    schematic = MODPATH .. "/schematics/tree_oak.mts",
    flags = "place_center_x, place_center_z",
    rotation = "random",
})

-- MEADOW: Rare Large Oaks
minetest.register_decoration({
    name = "cw_mapgen:meadow_oak_large",
    deco_type = "schematic",
    place_on = {"cw_core:grass_block"},
    biomes = {"meadow"},
    sidelen = 112,
    noise_params = {
        offset = -0.025,
        scale = 0.03,
        spread = {x=500, y=500, z=500},
        seed = 202,
    },
    schematic = MODPATH .. "/schematics/tree_oak_large.mts",
    flags = "place_center_x, place_center_z, force_placement",
    place_offset_y = 1,
    rotation = "random",
})

-- FOREST: Dense Oaks
minetest.register_decoration({
    name = "cw_mapgen:forest_oak",
    deco_type = "schematic",
    place_on = {"cw_core:grass_block"},
    biomes = {"forest", "meadow"}, -- FIXED: must be a table, not a string
    sidelen = 48,
    noise_params = {
        offset = -0.01,
        scale = 0.08,
        spread = {x=180, y=180, z=180},
        seed = 303,
    },
    schematic = MODPATH .. "/schematics/tree_oak.mts",
    flags = "place_center_x, place_center_z, force_placement",
    place_offset_y = 1,
    rotation = "random",
})

-- BIRCH FOREST: Birch-dominant
minetest.register_decoration({
    name = "cw_mapgen:birch_forest_birch",
    deco_type = "schematic",
    place_on = {"cw_core:grass_block"},
    biomes = {"birch_forest"},
    sidelen = 48,
    noise_params = {
        offset = -0.015,
        scale = 0.06,
        spread = {x=220, y=220, z=220},
        seed = 404,
    },
    schematic = MODPATH .. "/schematics/tree_birch.mts",
    flags = "place_center_x, place_center_z, force_placement",
    place_offset_y = 1,
    rotation = "random",
})

-- ============================================================================
-- 🌾 GRASS & FLOWERS — Dense but naturally clumped
-- ============================================================================

minetest.register_decoration({
    name = "cw_mapgen:meadow_grass",
    deco_type = "simple",
    place_on = {"cw_core:grass_block"},
    biomes = {"meadow"},
    sidelen = 16,
    noise_params = {
        offset = 0.0,
        scale = 0.15,
        spread = {x=32, y=32, z=32},
        seed = 505,
    },
    decoration = {
        "cw_core:grass_decor",
        "cw_core:grass_tall",
        "cw_core:flower_dandelion",
        "cw_core:flower_bluebell",
        "cw_core:flower_daisy",
    },
})

-- ============================================================================
-- 🌵 DESERT DECOR — Sparse, intentional
-- ============================================================================

minetest.register_decoration({
    name = "cw_mapgen:dry_flora",
    deco_type = "simple",
    place_on = {"cw_core:desert_sand"},
    biomes = {"desert"},
    fill_ratio = 0.02,
    decoration = {"cw_core:cactus", "cw_core:dead_bush"},
})

-- ============================================================================
-- 🌊 REEDS — Minecraft-accurate
-- ============================================================================

-- 1. DEFINE THE SCHEMATICS (1, 2, and 3 tall)
local reed_1 = {
    size = {x=1, y=1, z=1},
    data = {{name="cw_core:reeds_bottom"}},
}

local reed_2 = {
    size = {x=1, y=2, z=1},
    data = {
        {name="cw_core:reeds_bottom"},
        {name="cw_core:reeds_top"},
    },
}

local reed_3 = {
    size = {x=1, y=3, z=1},
    data = {
        {name="cw_core:reeds_bottom"},
        {name="cw_core:reeds_bottom"},
        {name="cw_core:reeds_top"},
    },
}

-- 2. HELPER FUNCTION TO REGISTER REEDS
local function register_reed(name, schematic, ratio)
    minetest.register_decoration({
        name = "cw_mapgen:shore_reeds_" .. name,
        deco_type = "schematic",
        place_on = {"cw_core:beach_sand", "cw_core:desert_sand"},
        sidelen = 16,
        fill_ratio = ratio,
        biomes = {"beach", "desert"},
        y_min = SEALEVEL - 1,
        y_max = SEALEVEL + 1,
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

