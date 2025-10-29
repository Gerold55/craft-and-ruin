-- cw_core/items/bottle_glass.lua
-- Simple reusable glass bottle + recipes

-- Item
minetest.register_craftitem("cw_core:bottle_glass", {
  description = "Glass Bottle",
  inventory_image = "cw_bottle_glass.png", -- 16x16 or 32x32
  stack_max = 64,
})

-- Recipes (choose whatever glass you have available)
-- Minecraft-style “V” = 3 bottles
local function add_bottle_recipe(glass_item)
  minetest.register_craft({
    output = "cw_core:bottle_glass 3",
    recipe = {
      {"",           glass_item,           ""},
      {glass_item,   "",                   glass_item},
      {"",           glass_item,           ""},
    }
  })
end

if minetest.registered_items["default:glass"] then
  add_bottle_recipe("default:glass")
end
if minetest.registered_items["cw_core:glass"] then
  add_bottle_recipe("cw_core:glass")  -- optional fallback if you have your own glass
end

-- Optional: shapeless fallback if you use panes or a “group:glass_bottle_parts”
-- minetest.register_craft({ type="shapeless", output="cw_core:bottle_glass",
--   recipe={"cw_core:glass_shard","cw_core:glass_shard","cw_core:glass_shard"} })
