-- ============================================================================
-- CRAFT & RUIN — SIMPLE, CORRECT DECORATIONS
-- Grass, Reeds, Cattails, Flowers
-- ============================================================================

local function deco(def)
    minetest.register_decoration(def)
end

-- Surfaces we allow decor on
local grass_surfaces = {
    "cw_core:grass_block",
    "cw_core:grass_block_snow",
}

-- ============================================================================
-- GRASS DECOR (your main ground cover)
-- ============================================================================

deco({
    name = "cw_mapgen:grass_decor",
    deco_type = "simple",
    place_on = grass_surfaces,
    sidelen = 16,
    fill_ratio = 0.06,
    decoration = "cw_core:grass_decor",
    y_min = 1,
    y_max = 140,
})

-- ============================================================================
-- FLOWERS (Bluebell + Daisy)
-- ============================================================================

local flowers = {
    "cw_core:flower_bluebell",
    "cw_core:flower_daisy",
}

for _, flower in ipairs(flowers) do
    deco({
        name = "cw_mapgen:" .. flower:gsub(":", "_"),
        deco_type = "simple",
        place_on = grass_surfaces,
        sidelen = 16,
        fill_ratio = 0.01,
        decoration = flower,
        y_min = 1,
        y_max = 140,
    })
end

-- ============================================================================
-- REEDS (spawn near water)
-- ============================================================================

deco({
    name = "cw_mapgen:reeds",
    deco_type = "simple",
    place_on = {"cw_core:grass_block", "cw_core:sand"},
    sidelen = 16,
    fill_ratio = 0.02,
    decoration = "cw_core:reeds",
    spawn_by = "cw_core:water_source",
    num_spawn_by = 1,
    y_min = -1,
    y_max = 140,
})
