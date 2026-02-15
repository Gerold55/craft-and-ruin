-- cw_crafting/recipes.lua

cw_crafting.register_process({
    id = "iron_plate",
    name = "Iron Plate",
    blueprint = "basic_metals",
    station = "assembler",
    inputs = {
        {item="cw_core:iron_ingot", count=2}
    },
    output = {
        item="cw_core:iron_plate",
        count=1
    },
    time = 2
})

cw_crafting.register_process({
    id = "copper_wire",
    name = "Copper Wire",
    blueprint = "basic_metals",
    station = "assembler",
    inputs = {
        {item="cw_core:copper_ingot", count=1}
    },
    output = {
        item="cw_core:copper_wire",
        count=3
    },
    time = 1
})