-- ============================================================================
-- Craft & Ruin — Init
-- ============================================================================

local mp = minetest.get_modpath(minetest.get_current_modname())

-- 1. PRE-REGISTRATION (Visuals & Utility)
dofile(mp .. "/grass_tint.lua")
dofile(mp .. "/leaves_tint.lua")

-- 2. CONTENT REGISTRATION (Tell the engine what exists before we build)
-- These files should contain core.register_biome and core.register_decoration
dofile(mp .. "/ores.lua")
dofile(mp .. "/decor_postgen.lua") 
dofile(mp .. "/biomes.lua")
dofile(mp .. "/trees.lua")

-- 3. THE GENERATORS
-- We check the mapgen setting to decide which generator to load.
-- ============================================================
--  CW MAPGEN — INIT (V6 ONLY)
--  Loads ONLY the v6 mapgen file.
-- ============================================================


local mp = minetest.get_modpath("cw_mapgen")
local mg = minetest.get_mapgen_setting("mg_name") or ""

if mg == "singlenode" then
    minetest.log("action", "[cw_mapgen] singlenode detected, loading custom mapgen")
    dofile(mp .. "/mapgen_singlenode.lua")
    dofile(mp .. "/caves.lua")      -- if you still want your cave pass
    dofile(mp .. "/trees.lua")      
    dofile(mp .. "/decor_postgen.lua") 
--    dofile(mp .. "/cave_biome.lua")      -- if you still want your cave pass
else
    minetest.log("action", "[cw_mapgen] mg_name = " .. mg .. " (cw_mapgen idle)")
end

