-- cw_crafting/api.lua

cw_crafting.processes = {}

function cw_crafting.register_process(def)
    cw_crafting.processes[def.id] = def
end