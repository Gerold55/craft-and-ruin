-- cw_mapgen/init.lua
local mp = minetest.get_modpath(minetest.get_current_modname())
--dofile(mp .. "/mapgen_singlenode.lua")
dofile(mp .. "/mapgen_carpathian.lua")
--dofile(mp .. "/mapgen_v7.lua")
dofile(mp .. "/grass_tint.lua")
dofile(mp .. "/leaves_tint.lua")
dofile(mp .. "/decor_postgen.lua")
dofile(mp .. "/caves.lua")
dofile(mp .. "/ores.lua")
--dofile(MP.."/biome_mask.lua")                 -- ← defines cw_mapgen.get_biome_at + tint prefs
-- your terrain generator runs here (heightfields, fill dirt/grass/water, etc.)
--dofile(MP.."/swamp_decor_singlenode.lua")     -- ← adds reeds + lilypads + squat oaks in swamp

-- cw_mapgen/init.lua
local mg = minetest.get_mapgen_setting("mg_name") or ""
if mg == "v6" then
  dofile(minetest.get_modpath(minetest.get_current_modname()).."/mapgen_v6.lua")
else
  minetest.log("action", "[cw_mapgen] mg_name="..mg.." (v6 file will only run on mgv6)")
end
