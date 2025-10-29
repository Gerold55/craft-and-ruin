-- cw_mapgen/decor_postgen.lua
-- Second-pass decorations: short grass, flowers, reeds, mushrooms, light leaf-fall.
-- Safe in Lua 5.1 (no bit ops); robust lazy init for all Perlin objects.

local MOD = minetest.get_current_modname() or "cw_mapgen"

----------------------------------------------------------------------
-- CONTENT IDS (resolved on first on_generated)
----------------------------------------------------------------------
local ids = nil
local function resolve_ids()
  if ids then return ids end
  ids = {
    air = minetest.get_content_id("air"),
    water = minetest.get_content_id("cw_core:water_source"),
    grass_block = minetest.get_content_id("cw_core:grass_block"),
    sand = minetest.get_content_id("cw_core:sand"),
    dirt = minetest.get_content_id("cw_core:dirt"),
    grass_decor = minetest.get_content_id("cw_core:grass_decor"),
    flower_daisy = minetest.get_content_id("cw_core:flower_daisy"),
    flower_blue = minetest.get_content_id("cw_core:flower_bluebell"),
    reeds = minetest.get_content_id("cw_core:reeds"),
    oak_leaves = minetest.get_content_id("cw_core:oak_leaves"),
    birch_leaves = minetest.get_content_id("cw_core:birch_leaves") or minetest.get_content_id("cw_core:oak_leaves"),
  }
  return ids
end

----------------------------------------------------------------------
-- NOISE / PRNG HELPERS (deterministic per world position)
----------------------------------------------------------------------

-- tiny integer hash -> [0,1)
local function hrand01(x, z, salt)
  local h = minetest.hash_node_position({x = x + (salt or 0), y = 0, z = z - (salt or 0)})
  -- mix a bit to decorrelate (pure math; no bitops)
  h = (h * 1103515245 + 12345) % 2147483647
  return (h % 10000) / 10000.0
end

-- 2D domain warp (prevents straight lines)
local n_warp_a, n_warp_b = nil, nil
local function ensure_warp()
  if n_warp_a and n_warp_b then return end
  n_warp_a = minetest.get_perlin({
    offset = 0, scale = 1,
    spread = {x=64,y=64,z=64},
    seed = 9101, octaves = 2, persist = 0.58,
  })
  n_warp_b = minetest.get_perlin({
    offset = 0, scale = 1,
    spread = {x=64,y=64,z=64},
    seed = 1249, octaves = 2, persist = 0.58,
  })
end

local function warp2(x, z)
  ensure_warp()
  local ax = n_warp_a:get_2d({x=x, y=z}) * 2.75
  local bz = n_warp_b:get_2d({x=x+1337, y=z-733}) * 2.75
  return x + ax, z + bz
end

----------------------------------------------------------------------
-- SURFACE / WATER CHECKS
----------------------------------------------------------------------
local function surface_y_of_column(area, data, minp, maxp, x, z)
  -- scan downward from top of mapchunk until first non-air/non-water
  for y = maxp.y, minp.y, -1 do
    local vi = area:index(x, y, z)
    local cid = data[vi]
    if cid ~= ids.air and cid ~= ids.water then
      return y
    end
  end
  return nil
end

local function is_water_cid(cid)
  if not cid then return false end
  return cid == ids.water
end

local function water_adjacent_cardinal(area, data, x, y, z)
  local function at(dx, dz)
    return data[area:index(x+dx, y, z+dz)]
  end
  return is_water_cid(at( 1, 0)) or is_water_cid(at(-1, 0))
      or is_water_cid(at( 0, 1)) or is_water_cid(at( 0,-1))
end

----------------------------------------------------------------------
-- SCATTER CORE (warped, “natural”)
----------------------------------------------------------------------

-- Place items inside loosely circular, warped disks (Minecraft-ish).
local function scatter_disk(area, data, p2, minp, maxp, opts, place_fn)
  -- opts: radius_min, radius_max, density, chance, salt, only_on_cids={...}
  local rmin, rmax = opts.radius_min, opts.radius_max
  local density = opts.density or 0.6
  local chance = opts.chance or 0.85
  local salt = opts.salt or 0
  local allow = opts.only_on_cids

  -- choose a random center within this mapblock (warped)
  local cx_raw = minp.x + 8
  local cz_raw = minp.z + 8
  local cx, cz = warp2(cx_raw, cz_raw)

  -- decide if we place anything in this block
  if hrand01(math.floor(cx), math.floor(cz), salt) > chance then return end

  -- disk radius
  local r = rmin + math.floor(hrand01(math.floor(cx*3), math.floor(cz*3), salt+1) * (rmax - rmin + 1))
  local r2 = r * r

  for z = minp.z, maxp.z do
    for x = minp.x, maxp.x do
      local wx, wz = warp2(x, z)
      local dx = wx - cx
      local dz = wz - cz
      if (dx*dx + dz*dz) <= r2 then
        if hrand01(x, z, salt+2) < density then
          local sy = surface_y_of_column(area, data, minp, maxp, x, z)
          if sy then
            local svi = area:index(x, sy, z)
            local above = area:index(x, sy+1, z)
            if (not allow) or allow[data[svi]] then
              place_fn(x, z, sy, svi, above)
            end
          end
        end
      end
    end
  end
end

----------------------------------------------------------------------
-- DECOR RULES
----------------------------------------------------------------------

-- Short grass (non-grid, sparse & natural)
local function place_short_grass(x, z, sy, svi, above)
  if ids == nil then return end
  if minetest.get_node_light({x=x,y=sy+1,z=z}, 0.5) and minetest.get_node_light({x=x,y=sy+1,z=z}, 0.5) <= 3 then
    -- avoid placing in very dark so mushrooms can take over there
    return
  end
  if minetest.registered_nodes and minetest.registered_nodes[minetest.get_name_from_content_id(ids.grass_block)] then
    -- only if above is air and ground is grass
    if (minetest.get_name_from_content_id(ids.grass_block) and (data and false)) then end -- placeholder to keep linter happy
  end
end

-- we can’t see data here; define concrete functions for scatter:

local function grass_place_fn(area, data)
  return function(x, z, sy, svi, above)
    if data[svi] == ids.grass_block and data[above] == ids.air then
      -- ~70% chance (adds irregularity inside the disk)
      if hrand01(x, z, 401) < 0.7 then
        data[above] = ids.grass_decor
      end
    end
  end
end

local function flower_place_fn(area, data)
  return function(x, z, sy, svi, above)
    if data[svi] == ids.grass_block and data[above] == ids.air then
      local r = hrand01(x, z, 911)
      if r < 0.18 then
        data[above] = (hrand01(x, z, 912) < 0.5) and ids.flower_daisy or ids.flower_blue
      end
    end
  end
end

local BASES_FOR_REEDS = nil
local function ensure_reed_bases()
  if BASES_FOR_REEDS then return end
  BASES_FOR_REEDS = {}
  BASES_FOR_REEDS[ids.sand] = true
  BASES_FOR_REEDS[ids.dirt] = true
  BASES_FOR_REEDS[ids.grass_block] = true
end

local function reeds_place_fn(area, data)
  ensure_reed_bases()
  return function(x, z, sy, svi, above)
    -- must be sand/dirt/grass AND directly touch water horizontally
    local ground = data[svi]
    if BASES_FOR_REEDS[ground] and data[above] == ids.air then
      if water_adjacent_cardinal(area, data, x, sy, z) then
        -- 2–3 tall with small chance
        data[above] = ids.reeds
        local top = {x=x, y=sy+1, z=z}
        if minetest.get_node(top).name == "air" then
          local vi2 = area:index(x, sy+2, z)
          if hrand01(x, z, 222) < 0.55 and (sy+2) <= 31000 and data[vi2] == ids.air then
            data[vi2] = ids.reeds
            local vi3 = area:index(x, sy+3, z)
            if hrand01(x, z, 223) < 0.25 and (sy+3) <= 31000 and data[vi3] == ids.air then
              data[vi3] = ids.reeds
            end
          end
        end
      end
    end
  end
end

local function mushroom_place_fn(area, data)
  return function(x, z, sy, svi, above)
    -- low light only, and only on grass/dirt
    local light = minetest.get_node_light({x=x,y=sy+1,z=z}, 0.5) or 15
    if light <= 8 and data[above] == ids.air then
      if data[svi] == ids.grass_block or data[svi] == ids.dirt then
        -- reuse flowers as placeholders if you don’t have mushroom nodes yet:
        data[above] = (hrand01(x, z, 777) < 0.5) and ids.flower_daisy or ids.flower_blue
      end
    end
  end
end

----------------------------------------------------------------------
-- CONFIG TUNING
----------------------------------------------------------------------

local CONF = {
  grass = {
    radius_min = 7, radius_max = 14, density = 0.45, chance = 0.92, salt = 131,
    only_on_cids = nil, -- we check ground per-voxel anyway
  },
  flowers = {
    radius_min = 8, radius_max = 16, density = 0.25, chance = 0.55, salt = 261,
  },
  reeds = {
    radius_min = 10, radius_max = 18, density = 0.40, chance = 0.65, salt = 411,
  },
  mushrooms = {
    radius_min = 9, radius_max = 15, density = 0.35, chance = 0.40, salt = 551,
  },
}

----------------------------------------------------------------------
-- ENTRY POINT
----------------------------------------------------------------------

minetest.register_on_generated(function(minp, maxp, seed)
  resolve_ids()
  ensure_warp()

  -- limit vertical work band
  if maxp.y < -32 or minp.y > 160 then return end

  local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
  local area = VoxelArea:new{MinEdge=emin, MaxEdge=emax}
  local data = vm:get_data()
  local p2 = vm:get_param2_data()

  -- Short grass
  scatter_disk(area, data, p2, minp, maxp, CONF.grass, grass_place_fn(area, data))
  -- Flowers (natural scatter, not rows)
  scatter_disk(area, data, p2, minp, maxp, CONF.flowers, flower_place_fn(area, data))
  -- Reeds (only where base is dirt/sand/grass and touching water)
  scatter_disk(area, data, p2, minp, maxp, CONF.reeds, reeds_place_fn(area, data))
  -- Mushrooms in low light (under trees / caves entrances)
  scatter_disk(area, data, p2, minp, maxp, CONF.mushrooms, mushroom_place_fn(area, data))

  vm:set_data(data)
  vm:set_param2_data(p2)
  vm:write_to_map()
  -- no lighting changes from decals here; skip calc_lighting
end)
