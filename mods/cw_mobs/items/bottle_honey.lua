-- cw_mobs/items/bottle_honey.lua
-- Honey Bottle (consumable) – returns an empty glass bottle

local HONEY_ITEM = "cw_mobs:bottle_honey"

minetest.register_craftitem(HONEY_ITEM, {
  description = "Honey Bottle",
  inventory_image = "cw_honey_bottle.png",
  stack_max = 99,
  groups = {food=1},
  on_use = function(itemstack, user, pointed_thing)
    -- Optional tiny heal (no hunger API needed). Adjust or remove.
    if user and user:is_player() then
      local hp = user:get_hp() or 0
      local maxhp = 20
      user:set_hp(math.min(maxhp, hp + 4))
    end

    -- consume the honey, give back empty bottle (unless in creative)
    if user and not minetest.is_creative_enabled(user:get_player_name()) then
      itemstack:take_item(1)
      local inv = user:get_inventory()
      local leftover = inv:add_item("main", ItemStack("cw_core:bottle_glass"))
      if not leftover:is_empty() then
        local p = user:get_pos(); if p then p.y = p.y + 1 end
        minetest.add_item(p, leftover)
      end
    end
    return itemstack
  end,
})