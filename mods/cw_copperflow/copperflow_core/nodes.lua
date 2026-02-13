minetest.register_node("copperflow_core:wire_base", {
    description = "Copperflow Wire Base",
    tiles = {"copperflow_wire.png"},
    groups = {cracky=2, copperflow_wire=1},
    on_copperflow_power = function(pos, state)
        copperflow.power.set(pos, state)
    end,
})

