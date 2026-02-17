cw_mapgen = {}

cw_mapgen.biomes = {
    ocean = {
        y_min = -31000, y_max = 60,
        top = "cw_core:sand", filler = "cw_core:sand",
        is_mountain = false
    },
    beach = {
        y_min = 61, y_max = 64,
        top = "cw_core:sand", filler = "cw_core:sand",
        is_mountain = false
    },
    plains = {
        y_min = 65, y_max = 78,
        top = "cw_core:grass_block", filler = "cw_core:dirt",
        has_petals = false, tree_type = "oak", is_mountain = false
    },
    cherry_grove = {
        y_min = 79, y_max = 31000,
        top = "cw_core:grass_block", filler = "cw_core:dirt",
        has_petals = true, petals_rarity = 3, -- 1 in 3 chance
        tree_type = "cherry", is_mountain = true
    }
}