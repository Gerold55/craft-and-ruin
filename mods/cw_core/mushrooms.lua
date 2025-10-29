-- cw_core/mushrooms.lua
-- Simple red & brown mushrooms. Plantlike, clip alpha, buildable_to.
-- They spread very slowly in dark & damp places (near water / under leaves).

local mod = "cw_core"

local function node_sound_leaves()
  return (default and default.node_sound_leaves_defaults and default.node_sound_leaves_defaults())
      or { footstep={name="default_grass_footstep", gain=0.42} }
end

local function base_mushroom_def(tex, desc)
  return {
    description = desc,
    drawtype = "plantlike",
    tiles = { tex },
    inventory_image = tex,
    wield_image = tex,
    use_texture_alpha = "clip",
    paramtype = "light",
    sunlight_propagates = true,
    walkable = false,
    buildable_to = true,
    waving = 0,
    groups = { snappy=3, flammable=2, attached_node=1, mushroom=1 },
    sounds = node_sound_leaves(),
    selection_box = { type="fixed", fixed = {-0.18,-0.5,-0.18, 0.18, -0.25, 0.18} },
  }
end

minetest.register_node(mod..":mushroom_red",   base_mushroom_def("cw_mushroom_red.png",   "Red Mushroom"))
minetest.register_node(mod..":mushroom_brown", base_mushroom_def("cw_mushroom_brown.png", "Brown Mushroom"))

-- ---------- helper checks for spread ----------
local BASES = {
  [mod..":grass_block"] = true,
  [mod..":dirt"]        = true,
  [mod..":sand"]        = false, -- avoid beaches by default
}

local function is_water_name(nm)
  local def = minetest.registered_nodes[nm]
  return def and def.groups and (def.groups.water or 0) > 0
end

local function water_near(pos, r)
  r = r or 2
  for dz=-r, r do
    for dx=-r, r do
      if not (dx==0 and dz==0) then
        local nm = minetest.get_node({x=pos.x+dx, y=pos.y, z=pos.z+dz}).name
        if is_water_name(nm) then return true end
      end
    end
  end
  return false
end

local function leaves_above(pos, h)
  h = h or 3
  for i=1,h do
    local nm = minetest.get_node({x=pos.x, y=pos.y+i, z=pos.z}).name
    local def = minetest.registered_nodes[nm]
    if def and def.groups and (def.groups.leaves or 0) > 0 then
      return true
    end
  end
  return false
end

-- Slow, flavor spread: prefers dark & damp (near water or under leaves), dies in bright open spots
minetest.register_abm({
  label = "cw_core:mushroom_spread",
  nodenames = { mod..":mushroom_red", mod..":mushroom_brown" },
  interval = 31,
  chance   = 12,
  action = function(pos, node)
    local below = {x=pos.x, y=pos.y-1, z=pos.z}
    local base  = minetest.get_node(below).name
    if not BASES[base] then
      minetest.remove_node(pos)
      return
    end

    local open_light = (minetest.get_node_light(pos, 0.5) or 0) >= 13
    local damp_or_shade = water_near(pos, 2) or leaves_above(pos, 3)

    -- too bright and not damp/shaded -> wither sometimes
    if open_light and not damp_or_shade and math.random() < 0.35 then
      minetest.remove_node(pos)
      return
    end

    -- try to spread to one nearby block
    if damp_or_shade and math.random() < 0.25 then
      local dx = math.random(-2,2); local dz = math.random(-2,2)
      local p  = {x=pos.x+dx, y=pos.y, z=pos.z+dz}
      local p_air = minetest.get_node(p).name
      local p_base= minetest.get_node({x=p.x, y=p.y-1, z=p.z}).name
      if p_air == "air" and BASES[p_base] and (water_near(p,2) or leaves_above(p,3)) then
        minetest.set_node(p, { name = node.name })
      end
    end
  end
})

-- ---------- Light gate ----------
local MUSHROOM_MAX_LIGHT = 12  -- spawn/spread only if light <= 12

local function node_light_leq(pos, max_lux)
  -- 0.5 time-of-day gives a “daylight” check; engine returns 0..15
  local l = minetest.get_node_light(pos, 0.5) or 0
  return l <= max_lux
end

minetest.register_abm({
  label = "cw_core:mushroom_spread",
  nodenames = { mod..":mushroom_red", mod..":mushroom_brown" },
  interval = 31,
  chance   = 12,
  action = function(pos, node)
    local below = {x=pos.x, y=pos.y-1, z=pos.z}
    local base  = minetest.get_node(below).name
    if not BASES[base] then
      minetest.remove_node(pos); return
    end

    -- if current light is too high, wither sometimes
    if not node_light_leq(pos, MUSHROOM_MAX_LIGHT) then
      if math.random() < 0.40 then minetest.remove_node(pos) end
      return
    end

    -- prefer damp/shaded to spread
    if (water_near(pos, 2) or leaves_above(pos, 3)) and math.random() < 0.25 then
      local dx = math.random(-2,2); local dz = math.random(-2,2)
      local p  = {x=pos.x+dx, y=pos.y, z=pos.z+dz}
      local p_air = minetest.get_node(p).name
      local p_base= minetest.get_node({x=p.x, y=p.y-1, z=p.z}).name
      if p_air == "air" and BASES[p_base] and node_light_leq(p, MUSHROOM_MAX_LIGHT) then
        minetest.set_node(p, { name = node.name })
      end
    end
  end
})
