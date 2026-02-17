-- ============================================================================
-- TERRAIN (FINAL — Low, Smooth, No Stone Peaks)
-- ============================================================================

minetest.set_mapgen_setting("mg_name", "v7", true)

-- Water
minetest.set_mapgen_setting("water_source", "cw_core:water_source", true)
minetest.set_mapgen_setting("river_water_source", "cw_core:water_source", true)
minetest.set_mapgen_setting("water_level", "1", true)

-- Disable extreme features
minetest.set_mapgen_setting("mgv7_spflags",
    "mountains,rivers,noridges,nofloatlands,nocaverns", true)

-- ============================================================================
-- BASE TERRAIN (controls continents)
-- ============================================================================
minetest.set_mapgen_setting_noiseparams("mgv7_np_terrain_base", {
    offset = -10,                -- lowers everything
    scale  = 4,                  -- gentle hills
    spread = {x=1600, y=1600, z=1600},
    seed = 82341,
    octaves = 3,
    persistence = 0.45,
    lacunarity = 2.0,
}, true)

-- ============================================================================
-- ALT TERRAIN (controls mountains)
-- ============================================================================
minetest.set_mapgen_setting_noiseparams("mgv7_np_terrain_alt", {
    offset = -14,                -- suppress mountains heavily
    scale  = 3,                  -- small mountains only
    spread = {x=1200, y=1200, z=1200},
    seed = 5934,
    octaves = 2,
    persistence = 0.45,
    lacunarity = 2.0,
}, true)

-- ============================================================================
-- EROSION (smooth transitions)
-- ============================================================================
minetest.set_mapgen_setting_noiseparams("mgv7_np_terrain_persist", {
    offset = 0.5,
    scale  = 0.4,                -- smoother slopes
    spread = {x=1400, y=1400, z=1400},
    seed = 539,
    octaves = 3,
    persistence = 0.55,
    lacunarity = 2.0,
}, true)

-- ============================================================================
-- RIVERS
-- ============================================================================
minetest.set_mapgen_setting_noiseparams("mgv7_np_river", {
    offset = 0,
    scale = 1,
    spread = {x=512, y=512, z=512},
    seed = 9001,
    octaves = 1,
    persistence = 1.0,
    lacunarity = 2.0,
}, true)

