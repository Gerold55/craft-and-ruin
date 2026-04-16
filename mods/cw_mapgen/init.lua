-- ============================================================================
-- Craft & Ruin - Mapgen Init
-- Proper load order for v7 mapgen
-- ============================================================================

local mp = minetest.get_modpath("cw_mapgen")

-- Always load these. Never conditionally.
dofile(mp .. "/climate.lua")
--dofile(mp .. "/biomes.lua")
dofile(mp .. "/decor_postgen.lua")
dofile(mp .. "/caves.lua")
--dofile(mp .. "/water.lua")
dofile(mp .. "/spawn.lua")

-- Load mapgen last
dofile(mp .. "/mapgen_v7.lua")
