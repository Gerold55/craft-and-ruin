local power_map = {}

function copperflow.power.set(pos, state)
    local key = minetest.pos_to_string(pos)
    if power_map[key] == state then return end
    power_map[key] = state

    for _, dir in ipairs({
        {x=1,y=0,z=0}, {x=-1,y=0,z=0},
        {x=0,y=1,z=0}, {x=0,y=-1,z=0},
        {x=0,y=0,z=1}, {x=0,y=0,z=-1},
    }) do
        local np = vector.add(pos, dir)
        local node = minetest.get_node(np)
        local def = minetest.registered_nodes[node.name]
        if def and def.on_copperflow_power then
            def.on_copperflow_power(np, state)
        end
    end
end

function copperflow.power.get(pos)
    return power_map[minetest.pos_to_string(pos)] or false
end

