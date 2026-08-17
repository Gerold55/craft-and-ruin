local modname = minetest.get_current_modname()

local stained_colors = {
    "blue",
    "red",
    "green",
    "yellow",
    "purple",
    "cyan",
    "white",
    "black",
    "orange",
    "pink",
}

for _, color in ipairs(stained_colors) do
    minetest.register_node(modname .. ":" .. color .. "_stained_glass", {
        description = (color:gsub("^%l", string.upper)) .. " Stained Glass",
        drawtype = "glasslike",
        tiles = { color .. "_stained_glass.png" },
        use_texture_alpha = "blend",
        paramtype = "light",
        sunlight_propagates = true,
        is_ground_content = false,
        groups = { cracky = 3, oddly_breakable_by_hand = 3, colored = 1},
        sounds = node_sound_glass,
    })
end
