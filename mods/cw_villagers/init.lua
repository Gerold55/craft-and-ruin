local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)

cw_villagers = {
    modname = modname,
    modpath = modpath,
}

dofile(modpath .. "/compat.lua")
dofile(modpath .. "/pathfinding.lua")
dofile(modpath .. "/placement.lua")
dofile(modpath .. "/building_engine.lua")
dofile(modpath .. "/building_templates.lua")
dofile(modpath .. "/farmer_templates.lua")
dofile(modpath .. "/builder_ai.lua")
dofile(modpath .. "/farmer_ai.lua")
dofile(modpath .. "/villagers.lua")

minetest.log("action", "[cw_villagers] Loaded.")
