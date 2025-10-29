-- cw_mapgen/init.lua
local mp = minetest.get_modpath(minetest.get_current_modname())
dofile(mp .. "/mapgen.lua")
dofile(mp .. "/grass_tint.lua")
dofile(mp .. "/leaves_tint.lua")
dofile(mp .. "/decor_postgen.lua")
dofile(mp .. "/caves.lua")
dofile(mp .. "/ores.lua")
--dofile(MP.."/biome_mask.lua")                 -- ← defines cw_mapgen.get_biome_at + tint prefs
-- your terrain generator runs here (heightfields, fill dirt/grass/water, etc.)
--dofile(MP.."/swamp_decor_singlenode.lua")     -- ← adds reeds + lilypads + squat oaks in swamp