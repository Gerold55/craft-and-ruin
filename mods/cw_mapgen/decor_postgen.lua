-- ============================================================================
-- Craft & Ruin / Cube-World - Postgen Decorations
-- * Natural blue-noise grass/flower scatter (no lines)
-- * Trees (plains sparse, forest dense; oak/birch split 50/50)
-- * Reeds only on sand/dirt immediately adjacent to water
-- * Beehives occasionally on oak/birch
-- * Works for both custom mapgen & v7 decorator
--
-- USAGE:
-- local ok, decor = pcall(dofile, MP.."/decor_postgen.lua")
-- (But this file also exposes a global table 'cw_decor_postgen' with run_chunk)
-- ============================================================================

cw_decor_postgen = cw_decor_postgen or {}

-- Content IDs (resolved at runtime to support your node names)
local ids = {}
local resolved = false
local function resolve_ids()
  if resolved then return end
  ids.air = minetest.get_content_id("air")
  ids.water = minetest.get_content_id("cw_core:water_source")
  ids.dirt = minetest.get_content_id("cw_core:dirt")
  ids.sand = minetest.get_content_id("cw_core:sand")
  ids.grass_block = minetest.get_content_id("cw_core:grass_block")
  ids.oak_log = minetest.get_content_id("cw_core:oak_log")
  ids.oak_leaves = minetest.get_content_id("cw_core:oak_leaves")
  ids.birch_log = minetest.get_content_id("cw_core:birch_log") or ids.oak_log
  ids.birch_leaves = minetest.get_content_id("cw_core:birch_leaves") or ids.oak_leaves
  ids.spruce_log = minetest.get_content_id("cw_core:spruce_log") or ids.oak_log
  ids.spruce_leaves = minetest.get_content_id("cw_core:spruce_leaves") or ids.oak_leaves
  ids.grass_decor = minetest.get_content_id("cw_core:grass_decor")
  ids.flower_daisy = minetest.get_content_id("cw_core:flower_daisy")
  ids.flower_bluebell = minetest.get_content_id("cw_core:flower_bluebell") -- corrected name you mentioned
  ids.reeds = minetest.get_content_id("cw_core:reeds")
  ids.beehive = minetest.get_content_id("cw_mobs:beehive")
  resolved = true
end

-- PRNG shortcut (no bit32)
local function rnd01_at(x, z, salt)
  local pr = PcgRandom(minetest.hash_node_position({x=x, y=salt or 0, z=z}) + 9001)
  return pr:next(0, 10000) / 10000.0
end

-- Surface find above solid
local function surface_y(area, data, x, z, y_min, y_max)
  for y = y_max, y_min, -1 do
    local vi = area:index(x,y,z)
    local n = data[vi]
    if n ~= ids.air and n ~= ids.water then return y end
  end
end

-- Blue-noise per-cell scatter: sample a jittered grid + density test, then locally jitter
local function scatter_points(minp, maxp, cell, salt, density_fn, cb)
  for z = minp.z, maxp.z, cell do
    for x = minp.x, maxp.x, cell do
      local jx = math.floor(rnd01_at(x,z,salt) * cell)
      local jz = math.floor(rnd01_at(x,z,salt+1) * cell)
      local px = x + jx
      local pz = z + jz
      if px >= minp.x and px <= maxp.x and pz >= minp.z and pz <= maxp.z then
        local d = density_fn(px, pz)
        if rnd01_at(px,pz,salt+2) < d then
          cb(px, pz)
        end
      end
    end
  end
end

-- Tree builders (simple, tidy)
local function place_oak(area, data, p2, x, y, z)
  -- trunk
  for i=0,4 do data[area:index(x, y+i, z)] = ids.oak_log end
  -- canopy
  local cy = y + 3
  for dy=-2,2 do
    for dz=-2,2 do
      for dx=-2,2 do
        if (dx*dx + dz*dz <= 3 + ((dy==0) and 1 or 0)) then
          local vi = area:index(x+dx, cy+dy, z+dz)
          if data[vi] == ids.air then data[vi] = ids.oak_leaves end
        end
      end
    end
  end
  -- rare beehive (1.5%)
  if rnd01_at(x,z,777) < 0.015 then
    local hv = area:index(x+1, y+1, z)
    if data[hv] == ids.air then data[hv] = ids.beehive end
  end
end

local function place_birch(area, data, p2, x, y, z)
  for i=0,5 do data[area:index(x, y+i, z)] = ids.birch_log end
  local cy = y + 4
  for dy=-2,2 do for dz=-2,2 do for dx=-2,2 do
    if dx*dx + dz*dz <= 3 then
      local vi = area:index(x+dx, cy+dy, z+dz)
      if data[vi] == ids.air then data[vi] = ids.birch_leaves end
    end
  end end end
  if rnd01_at(x,z,779) < 0.012 then
    local hv = area:index(x+1, y+2, z)
    if data[hv] == ids.air then data[hv] = ids.beehive end
  end
end

local function place_spruce(area, data, p2, x, y, z)
  -- trunk
  for i=0,7 do data[area:index(x, y+i, z)] = ids.spruce_log end
  -- conic leaves
  local h = 7
  for dy=0,h do
    local r = math.max(0, 3 - math.floor(dy/2))
    local yy = y + h - dy
    for dz=-r,r do for dx=-r,r do
      if dx*dx + dz*dz <= r*r then
        local vi = area:index(x+dx, yy, z+dz)
        if data[vi] == ids.air then data[vi] = ids.spruce_leaves end
      end
    end end
  end
end

-- Grass / flower densities by biome
local function density_grass(biome)
  if biome == "plains" then return 0.40 end
  if biome == "meadow" then return 0.55 end
  if biome == "forest" or biome == "birch_forest" then return 0.22 end
  if biome == "taiga" or biome == "snowy_taiga" then return 0.18 end
  if biome == "savannah" then return 0.25 end
  if biome == "jungle" or biome == "bamboo_jungle" then return 0.35 end
  if biome == "swamp" then return 0.20 end
  return 0.12
end

local function density_flower(biome)
  if biome == "meadow" then return 0.12 end
  if biome == "plains" then return 0.06 end
  return 0.02
end

-- Biome picker is passed in for v7; for custom we approximate from height
local SEA_LEVEL = 8

-- Public entrypoint from mapgen files:
-- cw_decor_postgen.run_chunk(minp, maxp, biome_fn)
function cw_decor_postgen.run_chunk(minp, maxp, biome_fn)
  resolve_ids()
  local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
  local area = VoxelArea:new{MinEdge=emin, MaxEdge=emax}
  local data = vm:get_data()
  local p2 = vm:get_param2_data()

  local function biome_at(x, z, sy)
    if biome_fn then return biome_fn(x, z, sy) end
    -- fallback heuristic if none provided
    if sy <= SEA_LEVEL - 2 then return "ocean" end
    if sy <= SEA_LEVEL + 1 then return "beach" end
    return "plains"
  end

  -- ======== GRASS DECOR (blue-noise scatter) =========
  scatter_points(minp, maxp, 6, 101, function(x,z)
    -- density by biome
    local sy = surface_y(area, data, x, z, minp.y, maxp.y)
    if not sy then return 0 end
    local b = biome_at(x,z,sy)
    return density_grass(b)
  end, function(x,z)
    local sy = surface_y(area, data, x, z, minp.y, maxp.y)
    if not sy then return end
    local below = area:index(x, sy, z)
    local above = area:index(x, sy+1, z)
    if data[below] == ids.grass_block and data[above] == ids.air then
      data[above] = ids.grass_decor
    end
  end)

  -- ======== FLOWERS (sparse, independent Bernoulli per accepted point) ======
  scatter_points(minp, maxp, 8, 202, function(x,z)
    local sy = surface_y(area, data, x, z, minp.y, maxp.y)
    if not sy then return 0 end
    local b = biome_at(x,z,sy)
    return density_flower(b)
  end, function(x,z)
    local sy = surface_y(area, data, x, z, minp.y, maxp.y)
    if not sy then return end
    local below = area:index(x, sy, z)
    local above = area:index(x, sy+1, z)
    if data[below] == ids.grass_block and data[above] == ids.air then
      data[above] = (rnd01_at(x,z,5) < 0.5) and ids.flower_daisy or ids.flower_bluebell
    end
  end)

  -- ======== REEDS (only if on sand/dirt right next to water) ================
  scatter_points(minp, maxp, 6, 303, function(x,z)
    return 0.12 -- modest
  end, function(x,z)
    local sy = surface_y(area, data, x, z, minp.y, maxp.y)
    if not sy then return end
    local base = area:index(x, sy, z)
    local above= area:index(x, sy+1, z)
    local base_id = data[base]
    if (base_id ~= ids.sand and base_id ~= ids.dirt and base_id ~= ids.grass_block) then return end
    if data[above] ~= ids.air then return end
    -- must be immediately adjacent to water (N/E/S/W)
    local function is_water(xx,zz) return data[area:index(xx, sy, zz)] == ids.water end
    if is_water(x+1,z) or is_water(x-1,z) or is_water(x,z+1) or is_water(x,z-1) then
      data[above] = ids.reeds
    end
  end)

  -- ======== TREES (blue-noise, slope & spacing checks) ======================
  local function can_place_tree(x,z,sy)
    -- ensure air space
    for yy=sy+1, sy+8 do
      local vi = area:index(x,yy,z)
      if data[vi] ~= ids.air then return false end
    end
    return true
  end

  -- deterministic neighbor avoidance (simple radius with hashed grid)
  local seen = {}
  local function mark_used(x,z,r)
    local key = math.floor(x/r)..":"..math.floor(z/r)
    seen[key] = true
  end
  local function used_near(x,z,r)
    local kx = math.floor(x/r); local kz = math.floor(z/r)
    for dz=-1,1 do for dx=-1,1 do
      if seen[(kx+dx)..":"..(kz+dz)] then return true end
    end end
    return false
  end

  scatter_points(minp, maxp, 12, 404, function(x,z)
    local sy = surface_y(area, data, x, z, minp.y, maxp.y)
    if not sy then return 0 end
    local b = biome_at(x,z,sy)
    if b == "plains" then return 0.03 end
    if b == "meadow" then return 0.02 end
    if b == "forest" then return 0.25 end
    if b == "birch_forest" then return 0.35 end
    if b == "taiga" or b == "snowy_taiga" then return 0.22 end
    if b == "jungle" then return 0.40 end
    return 0
  end, function(x,z)
    local sy = surface_y(area, data, x, z, minp.y, maxp.y)
    if not sy then return end
    if used_near(x,z,10) then return end
    local below = area:index(x, sy, z)
    if data[below] ~= ids.grass_block then return end
    if not can_place_tree(x,z,sy) then return end

    local b = (function()
      -- approximate again (we don't store the earlier value)
      if sy <= SEA_LEVEL - 2 then return "ocean" end
      if sy <= SEA_LEVEL + 1 then return "beach" end
      return "plains"
    end)()

    -- Prefer actual biome decision if v7 passed it through earlier
    if minetest.global_exists("__cw_override_biome_at") then
      b = __cw_override_biome_at(x,z,sy) or b
    end

    if b == "forest" then
      if rnd01_at(x,z,11) < 0.5 then place_oak(area,data,p2,x,sy+1,z)
      else place_birch(area,data,p2,x,sy+1,z) end
      mark_used(x,z,10)
    elseif b == "birch_forest" then
      place_birch(area,data,p2,x,sy+1,z); mark_used(x,z,10)
    elseif b == "plains" or b == "meadow" then
      if rnd01_at(x,z,12) < 0.10 then place_oak(area,data,p2,x,sy+1,z); mark_used(x,z,10) end
    elseif b == "taiga" or b == "snowy_taiga" then
      place_spruce(area,data,p2,x,sy+1,z); mark_used(x,z,10)
    elseif b == "jungle" then
      -- for now just oak proxy; replace with jungle tree later
      place_oak(area,data,p2,x,sy+1,z); mark_used(x,z,10)
    end
  end)

  vm:set_data(data)
  vm:set_param2_data(p2)
  vm:calc_lighting(nil, nil)
  vm:write_to_map()
end

return cw_decor_postgen