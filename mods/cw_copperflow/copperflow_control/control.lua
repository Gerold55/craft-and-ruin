minetest.register_node("copperflow_control:switch", {
    description = "Power Switch",
    tiles = {"copperflow_switch.png"},
    groups = {cracky=2},
    on_rightclick = function(pos)
        local state = not copperflow.power.get(pos)
        copperflow.power.set(pos, state)
    end,
})

minetest.register_node("copperflow_control:relay", {
    description = "Relay",
    tiles = {"copperflow_relay.png"},
    groups = {cracky=2},
    on_copperflow_power = function(pos, state)
        copperflow.power.set(pos, state)
    end,
})

minetest.register_node("copperflow_control:transformer", {
    description = "Transformer",
    tiles = {"copperflow_transformer.png"},
    groups = {cracky=2},
    on_copperflow_power = function(pos, state)
        copperflow.power.set(pos, state)
    end,
})

