-- cw_farming/items.lua
-- Seeds and food items + simple cooking/crafting

local S = minetest.get_translator and minetest.get_translator("cw_farming") or function(s) return s end

-- WHEAT
minetest.register_craftitem("cw_farming:seed_wheat", {
  description = S("Wheat Seeds"),
  inventory_image = "cw_farming_seed_wheat.png",
  groups = {seed=1, cw_seed=1},
})

minetest.register_craftitem("cw_farming:wheat_item", {
  description = S("Wheat"),
  inventory_image = "farming_wheat.png",
})

minetest.register_craft({
  output = "cw_farming:bread",
  recipe = {
    {"cw_farming:wheat_item", "cw_farming:wheat_item", "cw_farming:wheat_item"},
  }
})

minetest.register_craft({
  output = "cw_farming:melon",
  recipe = {
    {"cw_farming:slice_melon", "cw_farming:slice_melon", "cw_farming:slice_melon"},
    {"cw_farming:slice_melon", "cw_farming:slice_melon", "cw_farming:slice_melon"},
    {"cw_farming:slice_melon", "cw_farming:slice_melon", "cw_farming:slice_melon"},
  }
})

minetest.register_craftitem("cw_farming:bread", {
  description = S("Bread"),
  inventory_image = "food_bread.png",
  on_use = minetest.item_eat(5),
})

minetest.register_craftitem("cw_farming:potato_raw", {
  description = S("Potato"),
  inventory_image = "cw_farming_potato_raw.png",
  on_use = minetest.item_eat(1),
})

minetest.register_craft({
  type = "cooking",
  output = "cw_farming:potato_baked",
  recipe = "cw_farming:potato_raw",
  cooktime = 8,
})

minetest.register_craftitem("cw_farming:potato_baked", {
  description = S("Baked Potato"),
  inventory_image = "cw_farming_potato_baked.png",
  on_use = minetest.item_eat(5),
})

-- CARROT ITEM (used for eating, drops, and planting)
minetest.register_craftitem("cw_farming:carrot_item", {
  description = S("Carrot"),
  inventory_image = "carrot.png",
  on_use = minetest.item_eat(3),
  -- Optional: add a seed group here if your farming mod checks groups for plantable items
  -- groups = { seed = 1, cw_seed = 1 },
})


-- TOMATO
minetest.register_craftitem("cw_farming:seed_tomato", {
  description = S("Tomato Seeds"),
  inventory_image = "farming_tomato_seed.png",
  groups = {seed=1, cw_seed=1},
})

minetest.register_craftitem("cw_farming:tomato", {
  description = S("Tomato"),
  inventory_image = "farming_tomato.png",
})

-- TOMATO
minetest.register_craftitem("cw_farming:seed_melon", {
  description = S("Melon Seeds"),
  inventory_image = "farming_melon_seeds.png",
  groups = {seed=1, cw_seed=1},
})

minetest.register_craftitem("cw_farming:melon", {
  description = S("Melon"),
  inventory_image = "farming_melon.png",
})

minetest.register_craftitem("cw_farming:slice_melon", {
  description = S("Melon Slice"),
  inventory_image = "farming_melon_slice.png",
})