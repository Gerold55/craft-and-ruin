-- cw_farming/init.lua
-- Craft & Ruin - simple farming (wheat, potatoes, carrots)
-- MIT License

cw_farming = {}

-- Prefer Craft & Ruin core if present, else fallback to Minetest Game defaults
local CORE = minetest.get_modpath("cw_core") and "cw_core" or "default"

-- Resolve common base nodes
cw_farming.NODES = {
  dirt             = CORE..":dirt",
  dirt_with_grass  = CORE..":dirt_with_grass",
  water_source     = CORE..":water_source",
  water_flowing    = CORE..":water_flowing",
  water_group_name = "water", -- use group test as a fallback anyway
}

-- Utility: is a node position near water within R (Manhattan-ish)
function cw_farming.near_water(pos, radius)
  local p1 = vector.subtract(pos, radius)
  local p2 = vector.add(pos, radius)
  for x = p1.x, p2.x do
    for y = p1.y, p2.y do
      for z = p1.z, p2.z do
        local n = minetest.get_node_or_nil({x=x, y=y, z=z})
        if n and minetest.get_item_group(n.name, "water") > 0 then
          return true
        end
      end
    end
  end
  return false
end

-- Shared growth helpers
cw_farming.GROW = {
  -- Light requirement (approx like MC)
  min_light = 9,      -- minimum light for growth tick
  base_time = 120,    -- average seconds between stage bumps per plant (tuned below per crop)
  rand_jit  = 60,     -- random jitter added to stage timers
}

-- Registered by soil.lua and crops.lua
dofile(minetest.get_modpath("cw_farming").."/soil.lua")
dofile(minetest.get_modpath("cw_farming").."/items.lua")
dofile(minetest.get_modpath("cw_farming").."/crops.lua")
