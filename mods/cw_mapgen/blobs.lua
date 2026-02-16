-- ============================================================================
-- Craft & Ruin — River & Ocean Blobs
-- ============================================================================

local function blob(name, wherein, size, y_min, y_max)
    minetest.register_ore({
        ore_type       = "blob",
        ore            = name,
        wherein        = wherein,
        clust_scarcity = 20*20*20,
        clust_size     = size,
        y_min          = y_min,
        y_max          = y_max,
        noise_threshold = 0.0,
        noise_params = {
            offset = 0,
            scale = 1,
            spread = {x=64, y=64, z=64},
            seed = 12345,
            octaves = 3,
            persistence = 0.6,
        },
    })
end

blob("cw_core:clay",        "cw_core:sand", 4, -10, 5)
blob("cw_core:clay",        "cw_core:stone",      4, -10, 5)
blob("cw_core:gravel",      "cw_core:stone",      5, -31000, 20)
blob("cw_core:beach_sand",  "cw_core:stone",      5, -31000, 10)

