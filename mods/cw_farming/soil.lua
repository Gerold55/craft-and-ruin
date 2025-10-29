-- cw_farming/soil.lua
-- Tilled soil that hydrates near water and dries if not maintained.

local S = minetest.get_translator and minetest.get_translator("cw_farming") or function(s) return s end

local SOIL_WET_RADIUS = 4  -- match Minecraft's 4-block water hydration
local DRY_TIMEOUT     = 40 -- seconds to check/dry
local WET_TIMEOUT     = 30 -- seconds to re-check when wet

-- Helper: can this node support crops above?
local function crop_can_stay(pos)
  local above = {x=pos.x, y=pos.y+1, z=pos.z}
  local n = minetest.get_node_or_nil(above)
  if not n then return false end
  if n.name == "air" then return true end
  -- plants are fine; anything solid will trample back into dirt
  return minetest.get_item_group(n.name, "plant") > 0
end

-- Trampling: revert to dirt if a solid node is placed on top or no longer suitable
local function maybe_trample(pos, node)
  if crop_can_stay(pos) then return end
  local base = cw_farming.NODES.dirt
  if minetest.registered_nodes[base] then
    minetest.swap_node(pos, {name = cw_farming.NODES.dirt})
  else
    -- Fallback to default dirt name if needed
    minetest.swap_node(pos, {name = "default:dirt"})
  end
end

local function start_soil_timer(pos, wet)
  minetest.get_node_timer(pos):start(wet and WET_TIMEOUT or DRY_TIMEOUT)
end

-- Dry soil
minetest.register_node("cw_farming:soil", {
  description = S("Farmland"),
  tiles = {"cw_farming_soil.png"},
  drawtype = "nodebox",
  paramtype = "light",
  sunlight_propagates = true,
  walkable = true,
  groups = {crumbly=2, soil=1, oddly_breakable_by_hand=1},
  sounds = minetest.registered_nodes[cw_farming.NODES.dirt] and minetest.registered_nodes[cw_farming.NODES.dirt].sounds or nil,
  node_box = {
    type = "fixed",
    -- Slightly shorter than full block like farmland
    fixed = {-0.5,-0.5,-0.5, 0.5, -0.375, 0.5},
  },
  on_construct = function(pos)
    start_soil_timer(pos, false)
  end,
  on_timer = function(pos, elapsed)
    maybe_trample(pos)
    if cw_farming.near_water(pos, SOIL_WET_RADIUS) then
      minetest.swap_node(pos, {name="cw_farming:soil_wet"})
      start_soil_timer(pos, true)
      return false
    end
    start_soil_timer(pos, false)
    return false
  end,
  -- If dug or built upon, behave
  on_neighbor_changed = function(pos)
    maybe_trample(pos)
  end,
})

-- Wet soil
minetest.register_node("cw_farming:soil_wet", {
  description = S("Hydrated Farmland"),
  tiles = {"cw_farming_soil_wet.png"},
  drawtype = "nodebox",
  paramtype = "light",
  sunlight_propagates = true,
  walkable = true,
  groups = {crumbly=2, soil=1, wet=1, oddly_breakable_by_hand=1, not_in_creative_inventory=1},
  drop = "cw_farming:soil", -- drop dry variant
  sounds = minetest.registered_nodes[cw_farming.NODES.dirt] and minetest.registered_nodes[cw_farming.NODES.dirt].sounds or nil,
  node_box = {
    type = "fixed",
    fixed = {-0.5,-0.5,-0.5, 0.5, -0.375, 0.5},
  },
  on_construct = function(pos)
    start_soil_timer(pos, true)
  end,
  on_timer = function(pos, elapsed)
    maybe_trample(pos)
    if not cw_farming.near_water(pos, SOIL_WET_RADIUS) then
      -- Dry out slowly if there is no crop above; stay wet longer if supporting a plant
      local above = minetest.get_node({x=pos.x, y=pos.y+1, z=pos.z})
      local has_crop = minetest.get_item_group(above.name, "cw_crop") > 0
      if not has_crop then
        minetest.swap_node(pos, {name="cw_farming:soil"})
        start_soil_timer(pos, false)
        return false
      end
    end
    start_soil_timer(pos, true)
    return false
  end,
  on_neighbor_changed = function(pos)
    maybe_trample(pos)
  end,
})

-- Hoe tool (simple wooden hoe so players can start)
minetest.register_tool("cw_farming:hoe_wood", {
  description = S("Wooden Hoe"),
  inventory_image = "cw_farming_hoe_wood.png",
  groups = {hoe=1},
  on_use = function(itemstack, user, pointed_thing)
    if pointed_thing.type ~= "node" then return itemstack end
    local pos = pointed_thing.under
    local node = minetest.get_node(pos)
    -- Only till dirt-like blocks
    local nname = node.name
    local ok = (
      nname == cw_farming.NODES.dirt or
      nname == cw_farming.NODES.dirt_with_grass or
      nname == "default:dirt" or
      nname == "default:dirt_with_grass"
    )
    if not ok then return itemstack end

    -- Must have air or plant above
    local above = vector.add(pos, {x=0,y=1,z=0})
    local nn = minetest.get_node(above).name
    if nn ~= "air" and minetest.get_item_group(nn, "plant") == 0 then
      return itemstack
    end

    minetest.sound_play("default_dig_crumbly", {pos=pos, gain=0.6}, false)
    minetest.swap_node(pos, {name="cw_farming:soil"})
    minetest.get_node_timer(pos):start(DRY_TIMEOUT)
    -- wear a bit
    itemstack:add_wear(65535 / 100) -- ~100 uses
    return itemstack
  end
})

-- Simple craft for wooden hoe
minetest.register_craft({
  output = "cw_farming:hoe_wood",
  recipe = {
    {"group:wood", "group:wood", ""},
    {"",           "group:stick", ""},
    {"",           "group:stick", ""},
  }
})

