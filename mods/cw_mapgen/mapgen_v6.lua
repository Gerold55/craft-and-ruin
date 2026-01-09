-- ============================================================================
-- cw_mapgen: mapgen.lua (Clean v6 Foundation)
-- ============================================================================

-- 1. DISABLE ALL DEFAULT ENGINE FEATURES
minetest.set_mapgen_setting("mgv6_spflags", "notrees, nojungles, nobiomeblend, nomudflow", true)
minetest.set_mapgen_setting("mg_flags", "nocaves, nodungeons", true)

-- 2. MAPGEN ALIASES (Mapping engine names to YOUR custom nodes)
minetest.register_alias("mapgen_stone", "cw_core:stone")
minetest.register_alias("mapgen_water_source", "cw_core:water_source")
minetest.register_alias("mapgen_river_water_source", "cw_core:water_source")

-- Dummy out things we don't want (Ensures no apples or default trees)
minetest.register_alias("mapgen_tree", "cw_core:log_oak")
minetest.register_alias("mapgen_leaves", "cw_core:leaves_oak")
minetest.register_alias("mapgen_apple", "air")
minetest.register_alias("mapgen_jungle_tree", "air")

-- 3. CLEAR AND DEFINE CUSTOM BIOMES
minetest.clear_registered_biomes()
minetest.clear_registered_decorations()

-- BEACH: Clean Sand, No Shrubs, Low elevation
minetest.register_biome({
    name = "beach",
    node_top = "cw_core:sand",
    depth_top = 1,
    node_filler = "cw_core:sand",
    depth_filler = 3,
    y_max = 2,
    y_min = -10,
    heat_point = 50,
    humidity_point = 40,
})

-- PLAINS: Standard Grass for your Custom Trees and Packages
minetest.register_biome({
    name = "plains",
    node_top = "cw_core:grass_block",
    depth_top = 1,
    node_filler = "cw_core:dirt",
    depth_filler = 3,
    y_max = 31000,
    y_min = 3,
    heat_point = 50,
    humidity_point = 50,
})

-- MEADOW: Lush version of Plains
minetest.register_biome({
    name = "meadow",
    node_top = "cw_core:grass_block",
    depth_top = 1,
    node_filler = "cw_core:dirt",
    depth_filler = 3,
    y_max = 31000,
    y_min = 3,
    heat_point = 40,
    humidity_point = 85,
})

-- DESERT: Sand for Dry Shrubs only
minetest.register_biome({
    name = "desert",
    node_top = "cw_core:sand",
    depth_top = 1,
    node_filler = "cw_core:sand",
    depth_filler = 3,
    y_max = 31000,
    y_min = 3,
    heat_point = 90,
    humidity_point = 10,
})