-- Core nodes for the Abyssal Vein dimension

minetest.register_node("abyssal_vein:abyssal_stone", {
    description = "Abyssal Stone",
    tiles = {"abyssal_stone.png"},
    groups = {cracky=3},
})

minetest.register_node("abyssal_vein:shatterstone", {
    description = "Shatterstone",
    tiles = {"shatterstone.png"},
    groups = {cracky=2},
})

minetest.register_node("abyssal_vein:lumen_soil", {
    description = "Lumen Soil",
    tiles = {"lumen_soil.png"},
    groups = {crumbly=2},
    light_source = 6,
})

minetest.register_node("abyssal_vein:lumen_cap", {
    description = "Lumen Mushroom Cap",
    tiles = {"lumen_cap.png"},
    groups = {snappy=3},
    light_source = 12,
})

minetest.register_node("abyssal_vein:lumen_stem", {
    description = "Lumen Mushroom Stem",
    tiles = {"lumen_stem.png"},
    groups = {snappy=3},
})

minetest.register_node("abyssal_vein:veinheart_stone", {
    description = "Veinheart Stone",
    tiles = {"veinheart_stone.png"},
    groups = {cracky=1},
    light_source = 8,
})

minetest.register_node("abyssal_vein:ambient_crystal", {
    description = "Abyssal Ambient Crystal",
    tiles = {"ambient_crystal.png"},
    light_source = 12,
    groups = {cracky=2},
})

-- Portal blocks
minetest.register_node("abyssal_vein:portal_frame", {
    description = "Abyssal Portal Frame",
    tiles = {"portal_frame.png"},
    groups = {cracky=1},
})

minetest.register_node("abyssal_vein:portal_air", {
    description = "Abyssal Portal",
    drawtype = "glasslike",
    tiles = {"portal_air.png"},
    light_source = 12,
    walkable = false,
    pointable = false,
    diggable = false,
})

minetest.register_node("abyssal_vein:glowbug_light", {
    drawtype = "airlike",
    light_source = 10,
    groups = {not_in_creative_inventory=1},
})

-- Portal core item
minetest.register_craftitem("abyssal_vein:portal_core", {
    description = "Portal Core",
    inventory_image = "portal_core.png",
})

-- Crafting
minetest.register_craft({
    output = "abyssal_vein:portal_frame 8",
    recipe = {
        {"cw_core:bedrock", "cw_core:bedrock", "cw_core:bedrock"},
        {"cw_core:bedrock", "default:obsidian", "cw_core:bedrock"},
        {"cw_core:bedrock", "cw_core:bedrock", "cw_core:bedrock"},
    }
})

minetest.register_craft({
    output = "abyssal_vein:portal_core",
    recipe = {
        {"default:diamond", "default:mese_crystal", "default:diamond"},
        {"default:mese_crystal", "default:obsidian", "default:mese_crystal"},
        {"default:diamond", "default:mese_crystal", "default:diamond"},
    }
})
