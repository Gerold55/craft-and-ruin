--
-- CRAFT & RUIN — MINECRAFT‑STYLE BIOMES FOR V7
-- Terrain shape is handled by v7. Biomes only define surface layers.
--

-----------------------------
-- PLAINS (low elevation)
-----------------------------
minetest.register_biome({
    name = "cw_biomes:plains",
    node_top = "cw_core:grass_block",
    depth_top = 1,
    node_filler = "cw_core:dirt",
    depth_filler = 5,   -- deeper dirt to hide stone

    y_min = 1,
    y_max = 80,

    heat_point = 50,
    humidity_point = 50,
    vertical_blend = 6,
})

-----------------------------
-- BIRCH FOREST
-----------------------------
minetest.register_biome({
    name = "cw_biomes:birch_forest",
    node_top = "cw_core:grass_block",
    depth_top = 1,
    node_filler = "cw_core:dirt",
    depth_filler = 5,

    y_min = 1,
    y_max = 90,

    heat_point = 40,
    humidity_point = 70,
    vertical_blend = 6,
})

-----------------------------
-- CHERRY GROVE
-----------------------------
minetest.register_biome({
    name = "cw_biomes:cherry_grove",
    node_top = "cw_core:grass_block",
    depth_top = 1,
    node_filler = "cw_core:dirt",
    depth_filler = 5,

    y_min = 1,
    y_max = 90,

    heat_point = 30,
    humidity_point = 60,
    vertical_blend = 6,
})

-----------------------------
-- SAVANNA (transition biome)
-----------------------------
minetest.register_biome({
    name = "cw_biomes:savanna",
    node_top = "cw_core:grass_block",
    depth_top = 1,
    node_filler = "cw_core:dirt",
    depth_filler = 4,

    y_min = 1,
    y_max = 80,

    heat_point = 70,
    humidity_point = 30,
    vertical_blend = 6,
})

-----------------------------
-- DESERT (Minecraft‑like)
-----------------------------
minetest.register_biome({
    name = "cw_biomes:desert",
    node_top = "cw_core:sand",
    depth_top = 3,
    node_filler = "cw_core:sand",
    depth_filler = 2,
    node_stone = "cw_core:sandstone",

    y_min = 1,
    y_max = 80,

    heat_point = 90,
    humidity_point = 10,
    vertical_blend = 4,
})

-----------------------------
-- MOUNTAIN MEADOW (foothills)
-- Grass-covered slopes up to y=100
-----------------------------
minetest.register_biome({
    name = "cw_biomes:mountain_meadow",
    node_top = "cw_core:grass_block",
    depth_top = 1,
    node_filler = "cw_core:dirt",
    depth_filler = 4,

    y_min = 70,
    y_max = 100,

    heat_point = 40,
    humidity_point = 60,
    vertical_blend = 8,
})

-----------------------------
-- STONY PEAKS (stone only above y=100)
-----------------------------
minetest.register_biome({
    name = "cw_biomes:stony_peaks",
    node_top = "cw_core:stone",
    depth_top = 1,
    node_filler = "cw_core:stone",
    depth_filler = 4,

    y_min = 100,
    y_max = 150,

    heat_point = 30,
    humidity_point = 20,
    vertical_blend = 8,
})

-----------------------------
-- SNOWY SLOPES (snow above y=90)
-----------------------------
minetest.register_biome({
    name = "cw_biomes:snowy_slopes",
    node_top = "cw_core:snow",
    depth_top = 1,
    node_filler = "cw_core:stone",
    depth_filler = 3,

    y_min = 90,
    y_max = 150,

    heat_point = 10,
    humidity_point = 40,
    vertical_blend = 8,
})
