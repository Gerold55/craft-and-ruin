-- ============================================================================
-- Craft & Ruin — Init
-- ============================================================================

local mp = minetest.get_modpath(minetest.get_current_modname())

-- 0. MAPGEN SETTINGS (separate file)
dofile(mp .. "/mapgen_settings.lua")

-- 1. PRE-REGISTRATION (Visuals & Utility)
dofile(mp .. "/grass_tint.lua")
dofile(mp .. "/leaves_tint.lua")

-- 2. CONTENT REGISTRATION (Nodes, Biomes, Decorations)
dofile(mp .. "/ores.lua")
dofile(mp .. "/decor_postgen.lua")
dofile(mp .. "/biomes.lua")
dofile(mp .. "/trees.lua")

-- 3. MAPGEN LOADING
local mg = minetest.get_mapgen_setting("mg_name") or ""

if mg == "singlenode" then
    minetest.log("action", "[cw_mapgen] singlenode detected, loading custom mapgen")
    dofile(mp .. "/mapgen_singlenode.lua")
    dofile(mp .. "/caves.lua")
    dofile(mp .. "/trees.lua")
    dofile(mp .. "/decor_postgen.lua")

elseif mg == "v7" then
    minetest.log("action", "[cw_mapgen] v7 detected, loading mapgen_v7.lua")
    dofile(mp .. "/mapgen_v7.lua")
    dofile(mp .. "/caves.lua")
    dofile(mp .. "/trees.lua")
    dofile(mp .. "/decor_postgen.lua")

else
    minetest.log("action", "[cw_mapgen] mg_name = " .. mg .. " (cw_mapgen idle)")
end

