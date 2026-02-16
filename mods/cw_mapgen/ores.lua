-- ============================================================================
-- Craft & Ruin — Ores
-- ============================================================================

local function ore(name, wherein, scarcity, size, y_min, y_max)
    minetest.register_ore({
        ore_type       = "scatter",
        ore            = name,
        wherein        = wherein,
        clust_scarcity = scarcity,
        clust_num_ores = size,
        clust_size     = 3,
        y_min          = y_min,
        y_max          = y_max,
    })
end

ore("cw_core:coal_ore",    "cw_core:stone",  8*8*8,  6, -31000, 31000)
ore("cw_core:iron_ore",    "cw_core:stone", 12*12*12, 5, -31000, 64)
ore("cw_core:copper_ore",  "cw_core:stone", 14*14*14, 4, -31000, 32)
ore("cw_core:gold_ore",    "cw_core:stone", 18*18*18, 3, -31000, -64)
ore("cw_core:diamond_ore", "cw_core:stone", 20*20*20, 3, -31000, -128)
