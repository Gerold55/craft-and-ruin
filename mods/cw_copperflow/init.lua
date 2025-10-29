local MOD = minetest.get_current_modname()
local MP  = minetest.get_modpath(MOD)

cw_copperflow = {
  modname = MOD,
  power_max = 15,
  groups = {
    conductive = "cf_conductive",
    emitter    = "cf_emitter",
    consumer   = "cf_consumer",
    wire       = "cf_wire",
  },
}

dofile(MP.."/util.lua")
dofile(MP.."/power.lua")
dofile(MP.."/wire.lua")
dofile(MP.."/lever.lua")
dofile(MP.."/actuator.lua")

minetest.log("action", "[cw_copperflow:min] loaded")
