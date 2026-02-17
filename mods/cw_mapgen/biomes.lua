minetest.clear_registered_biomes()

-- ============================================================================
-- OCEAN + BEACH
-- ============================================================================

minetest.register_biome({
    name = "ocean",
    node_top = "cw_core:sand",
    depth_top = 2,
    node_filler = "cw_core:sand",
    depth_filler = 4,
    y_min = -31000,
    y_max = 0,
    heat_point = 50,
    humidity_point = 50,
})

minetest.register_biome({
    name = "beach",
    node_top = "cw_core:sand",
    depth_top = 1,
    node_filler = "cw_core:sand",
    depth_filler = 2,
    y_min = 1,
    y_max = 3,
    heat_point = 60,
    humidity_point = 50,
})

-- ============================================================================
-- PLAINS / FOREST / DESERT (MC‑like blending)
-- ============================================================================

minetest.register_biome({
    name = "plains",
    node_top = "cw_core:grass_block",
    depth_top = 1,
    node_filler = "cw_core:dirt",
    depth_filler = 3,
    y_min = 4,
    y_max = 40,
    heat_point = 50,
    humidity_point = 50,
})

minetest.register_biome({
    name = "forest",
    node_top = "cw_core:grass_block",
    depth_top = 1,
    node_filler = "cw_core:dirt",
    depth_filler = 3,
    y_min = 4,
    y_max = 40,
    heat_point = 45,
    humidity_point = 70,
})

minetest.register_biome({
    name = "desert",
    node_top = "cw_core:sand",
    depth_top = 1,
    node_filler = "cw_core:sand",
    depth_filler = 4,
    y_min = 4,
    y_max = 40,
    heat_point = 90,
    humidity_point = 10,
})

-- ============================================================================
-- MOUNTAINS (small, MC‑style)
-- ============================================================================

minetest.register_biome({
    name = "mountains",
    node_top = "cw_core:stone",
    depth_top = 1,
    node_filler = "cw_core:stone",
    depth_filler = 3,
    y_min = 41,
    y_max = 31000,
    heat_point = 40,
    humidity_point = 40,
})

