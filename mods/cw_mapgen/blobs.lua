local function blob(name, wherein, size, y_min, y_max)
    minetest.register_ore({
        ore_type       = "blob",
        ore            = name,
        wherein        = wherein,
        clust_scarcity = 64 * 64 * 64,
        clust_size     = size,
        y_min          = y_min,
        y_max          = y_max,
        noise_threshold = 0.5,
        noise_params = {
            offset = 0,
            scale = 1,
            spread = {x=32, y=32, z=32},
            seed = 12345,
            octaves = 3,
            persistence = 0.6,
        },
    })
end

-- ============================================================================
-- GRAVEL (PATCHY, NOT OCEAN FLOOR)
-- ============================================================================

minetest.register_ore({
    ore_type       = "blob",
    ore            = "cw_core:gravel",
    wherein        = "cw_core:stone",
    clust_scarcity = 180 * 180 * 180,
    clust_size     = 2,
    y_min          = -64,
    y_max          = 0,
    noise_threshold = 0.75,
    noise_params = {
        offset = 0,
        scale = 1,
        spread = {x=48, y=48, z=48},
        seed = 7777,
        octaves = 2,
        persistence = 0.5,
    },
})

-- ============================================================================
-- CLAY (RIVERS / SHALLOWS)
-- ============================================================================

blob("cw_core:clay", "cw_core:sand", 3, -4, 1)
blob("cw_core:clay", "cw_core:stone", 3, -4, 1)

-- ============================================================================
-- SAND (BEACHES / RIVERS)
-- ============================================================================

blob("cw_core:sand", "cw_core:stone", 4, -2, 4)