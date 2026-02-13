-- init.lua

cw_quests = cw_quests or {}

local modpath = minetest.get_modpath("cw_quests")

dofile(modpath .. "/api.lua")
dofile(modpath .. "/gui.lua")
dofile(modpath .. "/item.lua")
dofile(modpath .. "/quests_example.lua")

minetest.log("action", "[cw_quests] Quest journal loaded.")

