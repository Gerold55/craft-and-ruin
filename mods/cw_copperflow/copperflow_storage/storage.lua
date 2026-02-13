local function register_storage(name, desc, texture)
    minetest.register_node("copperflow_storage:" .. name, {
        description = desc,
        tiles = {texture},
        groups = {cracky=2},
        on_copperflow_power = function(pos, state)
            copperflow.power.set(pos, state)
        end,
    })
end

register_storage("battery", "Battery", "copperflow_battery.png")
register_storage("capacitor", "Capacitor", "copperflow_capacitor.png")

