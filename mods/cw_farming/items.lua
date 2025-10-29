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
  inventory_image = "cw_farming_wheat_item.png",
})

minetest.register_craft({
  output = "cw_farming:bread",
  recipe = {
    {"cw_farming:wheat_item", "cw_farming:wheat_item", "cw_farming:wheat_item"},
  }
})

minetest.register_craftitem("cw_farming:bread", {
  description = S("Bread"),
  inventory_image = "cw_farming_bread.png",
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

-- CARROT
minetest.register_craftitem("cw_farming:seed_carrot", {
  description = S("Carrot (Seed)"),
  inventory_image = "cw_farming_seed_carrot.png",
  groups = {seed=1, cw_seed=1},
})

minetest.register_craftitem("cw_farming:carrot_item", {
  description = S("Carrot"),
  inventory_image = "cw_farming_carrot_item.png",
  on_use = minetest.item_eat(3),
})
