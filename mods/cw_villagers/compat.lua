cw_villagers = cw_villagers or {}
cw_villagers.nodes = cw_villagers.nodes or {}

local N = cw_villagers.nodes

local function exists(name)
    return minetest.registered_nodes[name] ~= nil
end

N.planks =
    exists("cw_core:planks_oak") and "cw_core:planks_oak" or
    exists("default:wood")       and "default:wood"       or
    "air"

N.log =
    exists("cw_core:log_oak") and "cw_core:log_oak" or
    exists("default:tree")    and "default:tree"    or
    N.planks

N.cobble =
    exists("cw_core:cobble") and "cw_core:cobble" or
    exists("default:cobble") and "default:cobble" or
    N.planks

N.plaster =
    exists("cw_core:plaster_white") and "cw_core:plaster_white" or
    exists("default:sandstonebrick") and "default:sandstonebrick" or
    exists("default:clay") and "default:clay" or
    N.planks

N.glass =
    exists("cw_core:glass") and "cw_core:glass" or
    exists("default:glass") and "default:glass" or
    "air"

N.door =
    exists("cw_core:door_wood") and "cw_core:door_wood" or
    exists("doors:door_wood")   and "doors:door_wood"   or
    "air"

N.roof =
    exists("cw_core:roof_shingles") and "cw_core:roof_shingles" or
    exists("stairs:stair_wood")     and "stairs:stair_wood"     or
    N.planks

-- Farming / cw_farming
N.farmland =
    exists("cw_farming:soil_wet") and "cw_farming:soil_wet" or
    exists("cw_farming:soil")     and "cw_farming:soil"     or
    exists("farming:soil_wet")    and "farming:soil_wet"    or
    exists("farming:soil")        and "farming:soil"        or
    exists("default:dirt")        and "default:dirt"        or
    "air"

N.water =
    exists("cw_core:water_source") and "cw_core:water_source" or
    exists("default:water_source") and "default:water_source" or
    "air"

N.crop =
    exists("cw_farming:wheat_3") and "cw_farming:wheat_3" or
    exists("cw_farming:wheat_1") and "cw_farming:wheat_1" or
    exists("farming:wheat_3")    and "farming:wheat_3"    or
    exists("default:grass_3")    and "default:grass_3"    or
    "default:grass_1"
