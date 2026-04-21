local function tree(def)
    minetest.register_decoration(def)
end

-- OAK TREES (PLAINS) ---------------------------------------------------
tree({
    name = "cw_biomes:oak_tree",
    deco_type = "schematic",
    place_on = {"cw_core:grass_block"},
    sidelen = 16,
    fill_ratio = 0.004,
    schematic = minetest.get_modpath("cw_mapgen") .. "/schematics/oak_tree.mts",
    biomes = {"cw_biomes:plains"},
    flags = "place_center_x, place_center_z",
})

-- BIRCH TREES (BIRCH FOREST) ------------------------------------------
tree({
    name = "cw_biomes:birch_tree",
    deco_type = "schematic",
    place_on = {"cw_core:grass_block"},
    sidelen = 16,
    fill_ratio = 0.004,
    schematic = minetest.get_modpath("cw_mapgen") .. "/schematics/birch_tree.mts",
    biomes = {"cw_biomes:birch_forest"},
    flags = "place_center_x, place_center_z",
})

-- CHERRY TREES (CHERRY GROVE) -----------------------------------------
tree({
    name = "cw_biomes:cherry_tree",
    deco_type = "schematic",
    place_on = {"cw_core:grass_block"},
    sidelen = 16,
    fill_ratio = 0.004,
    schematic = minetest.get_modpath("cw_mapgen") .. "/schematics/cherry_tree.mts",
    biomes = {"cw_biomes:cherry_grove"},
    flags = "place_center_x, place_center_z",
})
