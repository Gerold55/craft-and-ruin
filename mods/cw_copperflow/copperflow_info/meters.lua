local function register_meter(name, desc, texture)
    minetest.register_node("copperflow_info:" .. name, {
        description = desc,
        tiles = {texture},
        groups = {cracky=2},
        on_rightclick = function(pos, node, clicker)
            local state = copperflow.power.get(pos)
            minetest.chat_send_player(clicker:get_player_name(),
                desc .. ": " .. (state and "Powered" or "No Power"))
        end,
    })
end

register_meter("power_meter", "Power Meter", "copperflow_power_meter.png")
register_meter("voltage_meter", "Voltage Meter", "copperflow_voltage_meter.png")
