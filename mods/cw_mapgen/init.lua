-- ============================================================================
-- Craft & Ruin — Init (Correct Load Order)
-- ============================================================================

local mp = minetest.get_modpath(minetest.get_current_modname())

-- 0. MAPGEN SETTINGS (must load BEFORE mapgen)
dofile(mp .. "/mapgen_settings.lua")

-- 1. CONTENT REGISTRATION
dofile(mp .. "/biomes.lua")
dofile(mp .. "/ores.lua")
dofile(mp .. "/blobs.lua")
dofile(mp .. "/decor_postgen.lua")

-- 2. MAPGEN (minimal, engine-driven)
local mg = minetest.get_mapgen_setting("mg_name") or ""
if mg == "v7" then
    dofile(mp .. "/mapgen_v7.lua")
end

