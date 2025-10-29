-- ============================================================================
-- cw_core: Oak nodes + sapling growth + leaf decay (palette-tinted leaves)
-- ============================================================================

local S = function(s) return s end

-- Clamp foliage to green window (match mapgen settings)
local FOLIAGE_IDX_MIN = 110
local FOLIAGE_IDX_MAX = 210
local function clamp_foliage_idx(i)
  if i < FOLIAGE_IDX_MIN then i = FOLIAGE_IDX_MIN end
  if i > FOLIAGE_IDX_MAX then i = FOLIAGE_IDX_MAX end
  return i
end

-- Leaf decay (simple)
local function near_log(pos, radius)
  local r = radius or 4
  for dz = -r, r do for dy = -r, r do for dx = -r, r do
    if minetest.get_node({x=pos.x+dx, y=pos.y+dy, z=pos.z+dz}).name == "cw_core:oak_log" then
      return true
    end
  end end end
  return false
end

minetest.register_abm({
  label = "cw_core:leaf_decay",
  nodenames = {"cw_core:oak_leaves"},
  interval = 7, chance = 12,
  action = function(pos)
    if not near_log(pos, 4) then
      if math.random(1, 32) == 1 then minetest.add_item(pos, "cw_core:oak_sapling") end
      minetest.set_node(pos, {name="air"})
    end
  end
})

-- Tint helper via biome hook (fallback mid-green)
-- At top of trees.lua (keep your other content as-is)
-- Use the SAME helper everywhere so palette is picked from location
local function leaf_p2_at(pos)
  -- If you have a biome helper, use it; else, reuse grass tint at this x/z.
  if cw_biome and cw_biome.get_palette_index_at_pos then
    local idx = cw_biome.get_palette_index_at_pos(pos) or 170
    if idx < 0 then idx = 0 elseif idx > 255 then idx = 255 end
    return idx
  end
  -- Fallback: mid-green
  return 170
end

-- Growth (used by saplings)
local function can_place_oak(pos, height)
  local top = pos.y + height + 3
  for y = pos.y, top do
    for z = pos.z-3, pos.z+3 do
      for x = pos.x-3, pos.x+3 do
        local n = minetest.get_node({x=x,y=y,z=z}).name
        if n ~= "air" and n ~= "cw_core:oak_leaves" then return false end
      end
    end
  end
  return true
end

local function place_oak_trunk_and_leaves(pos, pr)
  pr = pr or PcgRandom(os.time() + minetest.hash_node_position(pos))
  local trunk_h = pr:next(4, 6)
  if not can_place_oak(pos, trunk_h) then return false end

  -- trunk
  for y = 0, trunk_h-1 do
    minetest.set_node({x=pos.x, y=pos.y+y, z=pos.z}, {name="cw_core:oak_log"})
  end

  -- canopy
  local cy = pos.y + trunk_h - 1
  local r  = pr:next(2, 3)
  for dy = -2, 2 do
    local ry = r - math.floor(math.abs(dy)/2)
    for dz = -ry, ry do
      for dx = -ry, ry do
        if dx*dx + dz*dz <= ry*ry + pr:next(-1,1) then
          local p = {x=pos.x+dx, y=cy+dy, z=pos.z+dz}
          if minetest.get_node(p).name == "air" then
            minetest.set_node(p, {name="cw_core:oak_leaves", param2 = leaf_p2_at(p)})
          end
        end
      end
    end
  end
  return true
end

cw_core = rawget(_G, "cw_core") or {}
function cw_core.grow_oak(pos, pr) return place_oak_trunk_and_leaves(pos, pr) end
