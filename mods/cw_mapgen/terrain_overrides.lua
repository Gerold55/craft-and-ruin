-- ============================================================================
-- MINECRAFT-LIKE TERRAIN OVERRIDES (SAFE VALUES)
-- ============================================================================

-- Base terrain (smooth rolling)
minetest.set_mapgen_setting("mgv7_np_terrain_base", minetest.serialize({
    offset = 0,
    scale = 25,
    spread = {x = 500, y = 500, z = 500},
    seed = 12345,
    octaves = 4,
    persist = 0.5,
}), true)

-- Alt terrain (gentle variation)
minetest.set_mapgen_setting("mgv7_np_terrain_alt", minetest.serialize({
    offset = 0,
    scale = 18,
    spread = {x = 600, y = 600, z = 600},
    seed = 54321,
    octaves = 3,
    persist = 0.45,
}), true)

-- Mountain noise (smooth peaks)
minetest.set_mapgen_setting("mgv7_np_mountain", minetest.serialize({
    offset = 0,
    scale = 45,
    spread = {x = 550, y = 550, z = 550},
    seed = 98765,
    octaves = 3,
    persist = 0.5,
}), true)

-- Ridge noise (controls peak sharpness)
minetest.set_mapgen_setting("mgv7_np_ridge", minetest.serialize({
    offset = 0,
    scale = 30,
    spread = {x = 600, y = 600, z = 600},
    seed = 24680,
    octaves = 3,
    persist = 0.45,
}), true)
