local function register_wire(name, desc, texture)
    minetest.register_node("copperflow_transport:" .. name, {
        description = desc,
        tiles = {texture},
        groups = {cracky=2, copperflow_wire=1},
        on_copperflow_power = function(pos, state)
            copperflow.power.set(pos, state)
        end,
    })
end

register_wire("copper_wire", "Copper Wire", "copperflow_wire.png")
register_wire("insulated_cable", "Insulated Cable", "copperflow_cable.png")
register_wire("hv_line", "High-Voltage Line", "copperflow_hv_line.png")
