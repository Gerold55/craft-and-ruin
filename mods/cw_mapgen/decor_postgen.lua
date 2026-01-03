-- ============================================================================
-- cw_mapgen: decor_postgen.lua
-- Handles trees, reeds, and flowers based on Minecraft-style biome logic
-- ============================================================================

local MODPATH = core.get_modpath("cw_core")

-- 1. Schematic File Paths
local schems = {
    oak = MODPATH .. "/schematics/tree_oak.mts",
    birch = MODPATH .. "/schematics/tree_birch.mts",
    spruce = MODPATH .. "/schematics/tree_spruce.mts",
}

-- 2. Cleanup Legacy Decors
-- This removes any default engine decorations so only yours appear.
minetest.clear_registered_decorations()

------------------------------------------------------------
-- SPRUCE (TAIGA BIOME)
------------------------------------------------------------
-- This uses noise to match the "Cold" areas defined in mapgen.lua
minetest.register_decoration({
    name = "cw_mapgen:spruce_tree",
    deco_type = "schematic",
    place_on = {"cw_core:grass_block", "cw_core:snow_block"},
    sidelen = 16,
    noise_params = {
        offset = 0.03, -- High density for a thick forest
        scale = 0.05,
        spread = {x = 200, y = 200, z = 200},
        seed = 911,
        octaves = 3,
        persist = 0.7
    },
    -- Restrict Spruce to cold noise values (-1.0 to -0.4)
    biomes = {"taiga"}, 
    schematic = schems.spruce,
    flags = "place_center_x, place_center_z",
    rotation = "random",
})

------------------------------------------------------------
-- OAK & BIRCH (FOREST BIOME)
------------------------------------------------------------
minetest.register_decoration({
    name = "cw_mapgen:oak_tree",
    deco_type = "schematic",
    place_on = {"cw_core:grass_block"},
    sidelen = 16,
    noise_params = {
        offset = 0.01,
        scale = 0.02,
        spread = {x = 150, y = 150, z = 150},
        seed = 2,
        octaves = 3,
        persist = 0.6
    },
    biomes = {"forest", "v6_apple_trees"},
    schematic = schems.oak,
    flags = "place_center_x, place_center_z",
    rotation = "random",
})

minetest.register_decoration({
    name = "cw_mapgen:oak_tree",
    deco_type = "schematic",
    place_on = {"cw_core:grass_block"},
    sidelen = 16,
    noise_params = {
        offset = 0.01,
        scale = 0.02,
        spread = {x = 500, y = 500, z = 500},
        seed = 2,
        octaves = 3,
        persist = 0.6
    },
    biomes = {"meadows"},
    schematic = schems.oak,
    flags = "place_center_x, place_center_z",
    rotation = "random",
})

minetest.register_decoration({
    name = "cw_mapgen:birch_tree",
    deco_type = "schematic",
    place_on = {"cw_core:grass_block"},
    sidelen = 8,
    noise_params = {
        offset = 0.005,
        scale = 0.01,
        spread = {x = 100, y = 100, z = 100},
        seed = 422,
        octaves = 3,
        persist = 0.6
    },
    biomes = {"forest"},
    schematic = schems.birch,
    flags = "place_center_x, place_center_z",
    rotation = "random",
})

minetest.register_decoration({
    name = "cw_mapgen:birch_tree",
    deco_type = "schematic",
    place_on = {"cw_core:grass_block"},
    -- Sidelen 16 or 8 is fine; 16 is slightly better for performance in forests
    sidelen = 16,
    noise_params = {
        -- Offset 0.04 + Scale 0.1 gives a dense, varied look
        -- In Minecraft, forests are thick but have small occasional clearings
        offset = 0.04,
        scale = 0.1,
        spread = {x = 100, y = 100, z = 100},
        seed = 422,
        octaves = 3,
        persist = 0.7 -- Higher persistence makes the "clumps" of trees more rugged
    },
    biomes = {"birch_forest"},
    schematic = schems.birch,
    flags = "place_center_x, place_center_z",
    rotation = "random",
})

minetest.register_decoration({
    name = "cw_mapgen:birch_meadow_lone",
    deco_type = "schematic",
    place_on = {"cw_core:grass_block"},
    sidelen = 16, -- Increased for better performance in wide open areas
    noise_params = {
        -- Very low offset and scale ensures only 1 tree every few hundred blocks
        offset = 0.001, 
        scale = 0.004,
        spread = {x = 500, y = 500, z = 500},
        seed = 422,
        octaves = 3,
        persist = 0.6
    },
    biomes = {"meadow"},
    schematic = schems.birch,
    flags = "place_center_x, place_center_z",
    rotation = "random",
})

------------------------------------------------------------
-- WATER-SIDE DECOR (REEDS)
------------------------------------------------------------
minetest.register_decoration({
    name = "cw_mapgen:reeds",
    deco_type = "simple",
    place_on = {"cw_core:grass_block", "cw_core:sand"},
    sidelen = 16,
    noise_params = {
        offset = -0.01,
        scale = 0.1,
        spread = {x = 50, y = 50, z = 50},
        seed = 123,
        octaves = 3,
        persist = 0.7
    },
    decoration = "cw_core:reeds",
    height = 2,
    height_max = 4,
    spawn_by = "cw_core:water_source", -- Keeps them near the river/sea
    num_spawn_by = 1,
})

------------------------------------------------------------
-- GROUND COVER (GRASS & FLOWERS)
------------------------------------------------------------

-- Standard Grass
minetest.register_decoration({
    name = "cw_mapgen:grass",
    deco_type = "simple",
    place_on = {"cw_core:grass_block"},
    sidelen = 16,
    noise_params = {
        offset = 0,
        scale = 0.4,
        spread = {x = 100, y = 100, z = 100},
        seed = 333,
        octaves = 3,
        persist = 0.6
    },
    decoration = "cw_core:grass_decor",
})

-- Flowers (Daisies and Bluebells)
minetest.register_decoration({
    name = "cw_mapgen:flowers",
    deco_type = "simple",
    place_on = {"cw_core:grass_block"},
    sidelen = 16,
    noise_params = {
        offset = -0.02,
        scale = 0.05,
        spread = {x = 50, y = 50, z = 50},
        seed = 777,
        octaves = 2,
        persist = 0.5
    },
    decoration = {"cw_core:flower_daisy", "cw_core:flower_bluebell"},
})

minetest.register_decoration({
    name = "cw_mapgen:meadow_flowers",
    deco_type = "simple",
    place_on = {"cw_core:grass_block"},
    sidelen = 16,
    noise_params = {
        offset = 0.2,   -- High baseline for flowers
        scale = 0.4,    -- Thick patches
        spread = {x = 50, y = 50, z = 50},
        seed = 99,
        octaves = 3,
        persist = 0.7
    },
    biomes = {"meadow"},
    -- Use a mix of all your flowers
    decoration = {
        "cw_core:flower_daisy", 
        "cw_core:flower_bluebell", 
        "cw_core:flower_dandelion",
        "cw_core:grass_decor"
    },
})

-- Birch Meadow Trees
minetest.register_decoration({
    name = "cw_mapgen:meadow_birch",
    deco_type = "schematic",
    place_on = {"cw_core:grass_block"},
    sidelen = 16,
    noise_params = {
        offset = 0.001, scale = 0.004, spread = {x = 500, y = 500, z = 500},
        seed = 422, octaves = 3, persist = 0.6
    },
    biomes = {"meadow"},
    schematic = schems.birch,
    flags = "place_center_x, place_center_z",
    rotation = "random",
})

-- Beehives (Attached to Birches)
minetest.register_decoration({
    name = "cw_mapgen:wild_beehive",
    deco_type = "simple",
    place_on = {"cw_core:log_birch"},
    sidelen = 16,
    noise_params = {
        offset = -0.01, scale = 0.02, spread = {x = 100, y = 100, z = 100},
        seed = 777, octaves = 3, persist = 0.6
    },
    biomes = {"meadow"},
    decoration = "cw_mobs:beehive",
    spawn_by = "cw_core:log_birch",
    num_spawn_by = 1,
    param2 = 3,
})