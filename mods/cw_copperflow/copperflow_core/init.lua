copperflow = {
    power = {},
    consumers = {},
    sources = {},
    storage = {},
}

local path = minetest.get_modpath("copperflow_core")

dofile(path .. "/power.lua")
dofile(path .. "/nodes.lua")

