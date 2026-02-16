-- ============================================================================
-- Craft & Ruin — mapgen_settings.lua
-- ============================================================================

-- Use v7
minetest.set_mapgen_setting("mg_name", "v7", true)

-- Enable rivers, disable floatlands/caverns
minetest.set_mapgen_setting("mgv7_spflags",
    "mountains,ridges,rivers,nofloatlands,nocaverns", true)

-- Sea level
minetest.set_mapgen_setting("water_level", "63", true)

-- Deepen oceans
minetest.set_mapgen_setting_noiseparams("mgv7_np_terrain_alt", {
    offset = -8,
    scale = 1,
    spread = {x=600, y=600, z=600},
    seed = 82341,
    octaves = 5,
    persistence = 0.6,
    lacunarity = 2.0,
}, true)

-- Base terrain
minetest.set_mapgen_setting_noiseparams("mgv7_np_terrain_base", {
    offset = 0,
    scale = 1,
    spread = {x=600, y=600, z=600},
    seed = 82341,
    octaves = 5,
    persistence = 0.6,
    lacunarity = 2.0,
}, true)

-- Rivers
minetest.set_mapgen_setting_noiseparams("mgv7_np_river", {
    offset = 0,
    scale = 1,
    spread = {x=256, y=256, z=256},
    seed = 9001,
    octaves = 1,
    persistence = 1.0,
    lacunarity = 2.0,
}, true)

