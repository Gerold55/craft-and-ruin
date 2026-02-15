-- ============================================================
--  CW MAPGEN — CLEAN V6 MAPGEN (NO MTG DEPENDENCIES)
-- ============================================================

local mg_name = minetest.get_mapgen_setting("mg_name")
if mg_name ~= "v6" then
    return
end

local modpath = minetest.get_modpath("cw_mapgen")
local schem_path = modpath .. "/schematics/"

-- ============================================================
--  ALIASES (replace MTG nodes with cw_core equivalents)
-- ============================================================

minetest.register_alias("default:stone",              "cw_core:stone")
minetest.register_alias("default:dirt",               "cw_core:dirt")
minetest.register_alias("default:dirt_with_grass",    "cw_core:grass_block")
minetest.register_alias("default:sand",               "cw_core:sand")
minetest.register_alias("default:gravel",             "cw_core:gravel")
minetest.register_alias("default:clay",               "cw_core:clay")

minetest.register_alias("default:water_source",       "cw_core:water_source")
minetest.register_alias("default:water_flowing",      "cw_core:water_flowing")
minetest.register_alias("default:lava_source",        "cw_core:lava_source")
minetest.register_alias("default:lava_flowing",       "cw_core:lava_flowing")

minetest.register_alias("default:tree",               "cw_core:log_oak")
minetest.register_alias("default:leaves",             "cw_core:leaves_oak")
minetest.register_alias("default:jungletree",         "cw_core:log_jungle")
minetest.register_alias("default:jungleleaves",       "cw_core:leaves_jungle")
minetest.register_alias("default:pine_tree",          "cw_core:log_spruce")
minetest.register_alias("default:pine_needles",       "cw_core:leaves_spruce")

minetest.register_alias("default:snow",               "cw_core:snow")
minetest.register_alias("default:snowblock",          "cw_core:snow_block")

-- v6 mapgen tree aliases
minetest.register_alias("mapgen_tree",          "cw_core:log_oak")
minetest.register_alias("mapgen_leaves",        "cw_core:leaves_oak")
minetest.register_alias("mapgen_apple",         "air")
minetest.register_alias("mapgen_pine_tree",     "cw_core:log_spruce")
minetest.register_alias("mapgen_pine_needles",  "cw_core:leaves_spruce")
minetest.register_alias("mapgen_jungletree",    "cw_core:log_jungle")
minetest.register_alias("mapgen_jungleleaves",  "cw_core:leaves_jungle")

-- ============================================================
--  CLEAR EXISTING BIOMES / DECORATIONS / ORES
-- ============================================================

minetest.clear_registered_biomes()
minetest.clear_registered_decorations()
minetest.clear_registered_ores()

-- ============================================================
--  BIOMES
-- ============================================================

local function register_mgv6_biomes()
    minetest.register_biome({
        name = "cw_plains",
        node_top = "cw_core:grass_block",
        depth_top = 1,
        node_filler = "cw_core:dirt",
        depth_filler = 3,
        y_min = 1,
        y_max = 80,
        heat_point = 50,
        humidity_point = 50,
    })

    minetest.register_biome({
        name = "cw_forest",
        node_top = "cw_core:grass_block",
        depth_top = 1,
        node_filler = "cw_core:dirt",
        depth_filler = 3,
        y_min = 1,
        y_max = 90,
        heat_point = 45,
        humidity_point = 65,
    })

    minetest.register_biome({
        name = "cw_cherry_grove",
        node_top = "cw_core:grass_block",
        depth_top = 1,
        node_filler = "cw_core:dirt",
        depth_filler = 3,
        y_min = 60,
        y_max = 100,
        heat_point = 55,
        humidity_point = 55,
    })

    minetest.register_biome({
        name = "cw_taiga",
        node_top = "cw_core:grass_block",
        depth_top = 1,
        node_filler = "cw_core:dirt",
        depth_filler = 3,
        y_min = 1,
        y_max = 90,
        heat_point = 20,
        humidity_point = 60,
    })

    minetest.register_biome({
        name = "cw_beach",
        node_top = "cw_core:sand",
        depth_top = 2,
        node_filler = "cw_core:sand",
        depth_filler = 3,
        y_min = 0,
        y_max = 4,
        heat_point = 60,
        humidity_point = 40,
    })

    minetest.register_biome({
        name = "cw_ocean",
        node_top = "cw_core:sand",
        depth_top = 1,
        node_filler = "cw_core:sand",
        depth_filler = 3,
        y_min = -32,
        y_max = 0,
        heat_point = 50,
        humidity_point = 50,
    })
end

-- ============================================================
--  ORES
-- ============================================================

local function register_mgv6_ores()
    minetest.register_ore({
        ore_type       = "scatter",
        ore            = "cw_core:coal_ore",
        wherein        = "cw_core:stone",
        clust_scarcity = 8 * 8 * 8,
        clust_num_ores = 8,
        clust_size     = 3,
        y_min          = -64,
        y_max          = 64,
    })

    minetest.register_ore({
        ore_type       = "scatter",
        ore            = "cw_core:iron_ore",
        wherein        = "cw_core:stone",
        clust_scarcity = 9 * 9 * 9,
        clust_num_ores = 6,
        clust_size     = 3,
        y_min          = -64,
        y_max          = 32,
    })
end

-- ============================================================
--  DECORATIONS (TREES)
-- ============================================================

local function register_mgv6_decorations()
    minetest.register_decoration({
        deco_type = "schematic",
        place_on = {"cw_core:grass_block"},
        sidelen = 16,
        fill_ratio = 0.01,
        biomes = {"cw_forest", "cw_plains"},
        y_min = 1,
        y_max = 90,
        schematic = schem_path .. "oak_tree.mts",
        flags = "place_center_x, place_center_z",
    })

    minetest.register_decoration({
        deco_type = "schematic",
        place_on = {"cw_core:grass_block"},
        sidelen = 16,
        fill_ratio = 0.01,
        biomes = {"cw_cherry_grove"},
        y_min = 60,
        y_max = 100,
        schematic = schem_path .. "cherry_tree.mts",
        flags = "place_center_x, place_center_z",
    })

    minetest.register_decoration({
        deco_type = "schematic",
        place_on = {"cw_core:grass_block"},
        sidelen = 16,
        fill_ratio = 0.01,
        biomes = {"cw_taiga"},
        y_min = 1,
        y_max = 90,
        schematic = schem_path .. "spruce_tree.mts",
        flags = "place_center_x, place_center_z",
    })
end

-- ============================================================
--  FINAL V6 LOADER (REPLACES MTG LOGIC)
-- ============================================================

register_mgv6_biomes()
register_mgv6_ores()
register_mgv6_decorations()

