local function register_source(name, desc, texture)
    minetest.register_node("copperflow_sources:" .. name, {
        description = desc,
        tiles = {texture},
        groups = {cracky=2},
        on_construct = function(pos)
            copperflow.power.set(pos, true)
        end,
        on_destruct = function(pos)
            copperflow.power.set(pos, false)
        end,
    })
end

register_source("coal_generator", "Coal Generator", "copperflow_coal_generator.png")
register_source("water_turbine", "Water Turbine", "copperflow_water_turbine.png")
register_source("solar_panel", "Solar Panel", "copperflow_solar_panel.png")
