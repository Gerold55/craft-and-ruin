-- Simple depth-based biome selection

abyssal_vein.get_biome = function(y)
    if y > -19500 then
        return "descent"
    elseif y > -20050 then
        return "lumen_grove"
    else
        return "veinheart"
    end
end

-- Abyssal Vein biome definition
minetest.register_biome({
    name = "abyssal_vein",
    node_top = "abyssal_vein:lumen_soil",
    depth_top = 1,
    node_filler = "abyssal_vein:abyssal_stone",
    depth_filler = 3,
    y_min = -30000,
    y_max = -200,
    heat_point = 20,
    humidity_point = 40,
})
