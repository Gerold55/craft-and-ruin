-- cw_mapgen/mapgen.lua
-- Turn-key terrain + biome generator with rivers, beaches, seabed patches,
-- reeds-at-shore, and a biome function that decor_postgen.lua can call.

local modpath = minetest.get_modpath(minetest.get_current_modname())
local decor = dofile(minetest.get_modpath("cw_mapgen").."/decor_postgen.lua")
------------------------------------------------------------------------
-- Settings (tweak here; safe defaults)
------------------------------------------------------------------------
local SEA_LEVEL = 8
local DIRT_THICKNESS = 3

-- Relief strengths
local CONTINENT_AMPL = 18
local HILL_AMPL = 10
local MOUNTAIN_AMPL = 42
local DETAIL_SCALE_GAIN = 2.0

-- Scales (bigger => broader features)
local CONTINENT_SCALE = 1400
local HILL_SCALE = 320
local PEAK_SCALE = 520
local DETAIL_SCALE = 96

-- Domain warp
local WARP_SCALE = 200
local WARP_STRENGTH = 14.0

-- Rivers (width & depth)
local RIVER_WIDTH = 0.035
local RIVER_SOFT = 0.022
local RIVER_DEPTH = 7.5

-- Beaches
local BEACH_TOP_ABOVE = 2
local MAX_BEACH_SLOPE = 1.25
local SAND_CAP_LAYERS = 2

-- Seabed
local SEAFLOOR_SAND = 4
local ABYSS_SAND = 1
local CLAY_PATCH_RATE = 0.25
local GRAVEL_PATCH_RATE = 0.30
local CLAY_PATCH_R = 3
local GRAVEL_PATCH_R = 3

-- Deep ocean shelf depression
local SHELF_START_CONT = -0.05
local SHELF_END_CONT = -0.45
local DEEP_OCEAN_MAX = 48

-- Rare biome knobs
local CLAYSPIRE_RARITY = 0.010 -- ~1%
local CLAYSPIRE_HEIGHT_BIAS = 4

-- Biome bands smoothing
local CLIMATE_CELL = 64

------------------------------------------------------------------------
-- Simple math helpers
------------------------------------------------------------------------
local function clamp(x, a, b) if x < a then return a elseif x > b then return b else return x end end
local function lerp(a, b, t) return a + (b - a) * t end
local function smoothstep(a, b, x) x = clamp((x - a) / (b - a), 0, 1); return x * x * (3 - 2*x) end

------------------------------------------------------------------------
-- PRNG helpers (no bit32)
------------------------------------------------------------------------
local function hash32(x, z, salt)
  local h = minetest.hash_node_position({x = x, y = salt or 0, z = z})
  -- Mix a bit to improve distribution
  h = (h * 1103515245 + 12345) % 2147483647
  h = (h * 1664525 + 1013904223) % 2147483647
  if h < 0 then h = -h end
  return h
end

local function hash01(x, z, salt)
  return (hash32(x, z, salt) % 100000) / 100000.0
end

local function jitter2d(x, z, scale, salt)
  local jx = (hash01(x + 31, z - 17, (salt or 0) + 7) - 0.5) * scale
  local jz = (hash01(x - 23, z + 29, (salt or 0) + 11) - 0.5) * scale
  return jx, jz
end

------------------------------------------------------------------------
-- Perlin noises (lazy init)
------------------------------------------------------------------------
local n_temp, n_hum, n_cont1, n_cont2, n_hill, n_peak, n_detail, n_riv, n_warpx, n_warpz

local function P(spread, seed, oct, pers)
  return minetest.get_perlin({offset=0, scale=1, spread=spread, seed=seed, octaves=oct, persist=pers})
end

local function ensure_noises()
  if not n_temp then n_temp = P({x=2048,y=2048,z=2048}, 591, 3, 0.55) end
  if not n_hum then n_hum = P({x=2048,y=2048,z=2048}, 7411, 3, 0.55) end
  if not n_cont1 then n_cont1 = P({x=CONTINENT_SCALE, y=CONTINENT_SCALE, z=CONTINENT_SCALE}, 8701, 3, 0.50) end
  if not n_cont2 then n_cont2 = P({x=CONTINENT_SCALE*0.5, y=CONTINENT_SCALE*0.5, z=CONTINENT_SCALE*0.5}, 9103, 2, 0.60) end
  if not n_hill then n_hill = P({x=HILL_SCALE, y=HILL_SCALE, z=HILL_SCALE}, 11337, 4, 0.52) end
  if not n_peak then n_peak = P({x=PEAK_SCALE, y=PEAK_SCALE, z=PEAK_SCALE}, 9941, 5, 0.45) end
  if not n_detail then n_detail = P({x=DETAIL_SCALE, y=DETAIL_SCALE, z=DETAIL_SCALE}, 431, 3, 0.60) end
  if not n_riv then n_riv = P({x=480, y=480, z=480}, 7227, 5, 0.55) end
  if not n_warpx then n_warpx = P({x=WARP_SCALE, y=WARP_SCALE, z=WARP_SCALE}, 3349, 3, 0.60) end
  if not n_warpz then n_warpz = P({x=WARP_SCALE, y=WARP_SCALE, z=WARP_SCALE}, 5561, 3, 0.60) end
end

------------------------------------------------------------------------
-- Climate + height sampling
------------------------------------------------------------------------
local function climate_params(x, z)
  local sx = x + n_warpx:get_2d({x=x, y=z}) * WARP_STRENGTH
  local sz = z + n_warpz:get_2d({x=x+1337, y=z-733}) * WARP_STRENGTH

  local T = (n_temp:get_2d({x=sx,y=sz}) + 1) * 0.5
  local H = (n_hum :get_2d({x=sx,y=sz}) + 1) * 0.5

  -- Continentalness (blend two fields)
  local C_raw = n_cont1:get_2d({x=sx,y=sz}) * 0.7 + n_cont2:get_2d({x=sx*0.7,y=sz*0.7}) * 0.3
  local C = (C_raw + 1) * 0.5

  return T, H, C, sx, sz, C_raw
end

local function ground_height(x, z)
  local T, H, C, sx, sz, C_raw = climate_params(x, z)

  -- Shelf/abyss depression for deep oceans
  local ocean_t = 0
  if C_raw < SHELF_START_CONT then
    ocean_t = clamp((SHELF_START_CONT - C_raw) / (SHELF_START_CONT - SHELF_END_CONT), 0, 1)
  end

  local base = C_raw * CONTINENT_AMPL + SEA_LEVEL
  base = base - (smoothstep(0,1,ocean_t)^2) * DEEP_OCEAN_MAX

  -- Hills + mountains
  local hills = n_hill:get_2d({x=sx,y=sz}) * HILL_AMPL
  local p = n_peak:get_2d({x=sx,y=sz})
  p = 1 - math.abs(p)
  p = math.max(0, p * 1.5 - 0.6)
  local peaks = p * MOUNTAIN_AMPL

  local micro = n_detail:get_2d({x=sx,y=sz}) * DETAIL_SCALE_GAIN
  local y_pre = base + hills + peaks + micro

  -- Rivers (carve where abs(r) small)
  local rv = math.abs(n_riv:get_2d({x=sx, y=sz}))
  local rm = smoothstep(0, RIVER_WIDTH + RIVER_SOFT, rv) -- 0 at center, 1 away
  local carve = (1 - rm); carve = carve * carve
  local cut = carve * RIVER_DEPTH
  local y = y_pre - cut

  return y, rm, ocean_t, T, H, C
end

------------------------------------------------------------------------
-- Biome classifier
------------------------------------------------------------------------
local function pick_biome(x, z)
  local y, rm, ocean_t, T, H, C = ground_height(x, z)

  -- Rare clayspire spikes inland and semi-arid
  if y > SEA_LEVEL + 6 and T > 0.55 and H < 0.45 then
    if hash01(x, z, 999) < CLAYSPIRE_RARITY then
      return "clayspire_basin"
    end
  end

  -- Oceans first
  if y <= SEA_LEVEL - 4 then return "deep_ocean" end
  if y <= SEA_LEVEL + 0.5 then return "ocean" end

  -- Beaches
  local slope_x = math.abs((select(1, ground_height(x+1, z))) - y)
  local slope_z = math.abs((select(1, ground_height(x, z+1))) - y)
  local slope = math.max(slope_x, slope_z)
  local near_sea = y <= SEA_LEVEL + BEACH_TOP_ABOVE
  if near_sea and slope <= MAX_BEACH_SLOPE then return "beach" end

  -- Swamp if humid + low-lying + rivers nearby
  if H >= 0.65 and y <= SEA_LEVEL + 3 and rm < 0.60 then
    return "swamp"
  end

  -- Desert if hot + dry
  if T >= 0.70 and H <= 0.30 then
    return "desert"
  end

  -- Meadows a bit higher and temperate humid
  if y >= SEA_LEVEL + 8 and T >= 0.40 and T <= 0.85 and H >= 0.45 then
    return "meadow"
  end

  -- Birch forest slightly cooler or wetter temperate band
  if T >= 0.35 and T <= 0.75 and H >= 0.50 then
    -- 40% chance birch forest vs regular forest, nudged by noise
    if hash01(x, z, 321) < 0.40 then
      return "birch_forest"
    end
    return "forest"
  end

  -- Plains default on temperate
  return "plains"
end

-- Expose to other files (decor_postgen expects this name)
function cw_mapgen_biome_at(x, z)
  return pick_biome(x, z)
end

------------------------------------------------------------------------
-- Content IDs helper
------------------------------------------------------------------------
local function get_ids()
  return {
    air = minetest.get_content_id("air"),
    stone = minetest.get_content_id("cw_core:stone"),
    dirt = minetest.get_content_id("cw_core:dirt"),
    grass = minetest.get_content_id("cw_core:grass_block"),
    sand = minetest.get_content_id("cw_core:sand"),
    water = minetest.get_content_id("cw_core:water_source"),
    gravel = minetest.get_content_id("cw_core:gravel"),
    clay = minetest.get_content_id("cw_core:clay"),

    -- reeds + decor/flowers (ensure these exist in cw_core)
    reeds = minetest.get_content_id("cw_core:reeds"),
    grass_decor = minetest.get_content_id("cw_core:grass_decor"),
    flower_daisy = minetest.get_content_id("cw_core:flower_daisy"),
    flower_bluebell= minetest.get_content_id("cw_core:flower_bluebell"),

    -- trees (used by decor_postgen)
    oak_log = minetest.get_content_id("cw_core:oak_log"),
    oak_leaves = minetest.get_content_id("cw_core:oak_leaves"),
    birch_log = minetest.get_content_id("cw_core:birch_log"),
    birch_leaves = minetest.get_content_id("cw_core:birch_leaves"),
    spruce_log = minetest.get_content_id("cw_core:spruce_log"),
    spruce_leaves = minetest.get_content_id("cw_core:spruce_leaves"),
  }
end

------------------------------------------------------------------------
-- Terrain write helpers
------------------------------------------------------------------------
local function is_slope_gentle(x, z, y_here)
  local yx = select(1, ground_height(x+1, z))
  local yz = select(1, ground_height(x, z+1))
  local slope = math.max(math.abs(yx - y_here), math.abs(yz - y_here))
  return slope <= MAX_BEACH_SLOPE
end

local function set_disk(area, data, id, cx, cz, r, emin, emax, y)
  local r2 = r * r
  for dz = -r, r do
    local z = cz + dz
    if z >= emin.z and z <= emax.z then
      for dx = -r, r do
        local x = cx + dx
        if x >= emin.x and x <= emax.x then
          if dx*dx + dz*dz <= r2 then
            local vi = area:index(x, y, z)
            data[vi] = id
          end
        end
      end
    end
  end
end

local function seabed_material_for(x, z, deeper)
  -- clay and gravel as small disks; favor sand overall
  local roll = hash01(x, z, deeper and 8003 or 8001)
  if roll < GRAVEL_PATCH_RATE then return "gravel" end
  if roll < GRAVEL_PATCH_RATE + CLAY_PATCH_RATE then return "clay" end
  return "sand"
end

local function place_reeds_if_shore(area, data, ids, x, y, z, emin, emax, biome)
  -- reeds only when the ground (y) is dirt or sand AND any of 4-neighbors at y is water
  if y < emin.y or y > emax.y then return end
  local ground = data[area:index(x, y, z)]
  if not (ground == ids.dirt or ground == ids.sand) then return end
  local above = data[area:index(x, y+1, z)]
  if above ~= ids.air then return end

  local function is_water(nx, nz) return data[area:index(nx, y, nz)] == ids.water end
  if is_water(x+1,z) or is_water(x-1,z) or is_water(x,z+1) or is_water(x,z-1) then
    -- allow in swamp often, plains/meadow rarely
    local chance = (biome == "swamp") and 0.70 or ((biome == "plains" or biome=="meadow") and 0.06 or 0.02)
    if hash01(x, z, 902) < chance then
      data[area:index(x, y+1, z)] = ids.reeds
    end
  end
end

------------------------------------------------------------------------
-- Main on_generated
------------------------------------------------------------------------
minetest.register_on_generated(function(minp, maxp, seed)
  ensure_noises()

  local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
  local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
  local data = vm:get_data()
  local p2 = vm:get_param2_data()
  local ids = get_ids()

  -- Fill columns
  for z = emin.z, emax.z do
    for x = emin.x, emax.x do
      local y, rm, ocean_t = ground_height(x, z)
      -- jitter to avoid chessboardy terraces
      local jx, jz = jitter2d(x, z, 0.5, 17)
      local y_int = math.floor(y + jx*0.1 + jz*0.1 + 0.5)

      -- Bulk fill
      for yy = emin.y, emax.y do
        local vi = area:index(x, yy, z)
        if yy <= y_int then
          data[vi] = ids.stone
        else
          if yy <= SEA_LEVEL then
            data[vi] = ids.water
          else
            data[vi] = ids.air
          end
        end
      end

      -- Surface finalize
      if y_int >= emin.y and y_int <= emax.y then
        local bio = pick_biome(x, z)

        if y_int <= SEA_LEVEL then
          -- Seafloor sand
          local depth = SEA_LEVEL - y_int
          local layers = math.min((ocean_t >= 0.8) and ABYSS_SAND or SEAFLOOR_SAND, depth + 1)
          for i = 0, layers - 1 do
            local yi = y_int - i
            if yi >= emin.y then data[area:index(x, yi, z)] = ids.sand end
          end

          -- Small clay/gravel disks with low chance (gentle)
          if layers > 0 then
            local under = y_int - layers
            if under >= emin.y then
              if hash01(x, z, 6001) < 0.08 then
                local which = seabed_material_for(x, z, ocean_t > 0.5)
                local id = (which == "gravel") and ids.gravel or ids.clay
                set_disk(area, data, id, x, z, (which == "gravel") and GRAVEL_PATCH_R or CLAY_PATCH_R, emin, emax, under)
              end
            end
          end

        else
          -- Land: dirt cap then grass or beach
          for i = 0, (DIRT_THICKNESS - 2) do
            local yi = y_int - i
            if yi >= emin.y then data[area:index(x, yi, z)] = ids.dirt end
          end

          local svi = area:index(x, y_int, z)

          local near_sea = (y_int <= SEA_LEVEL + BEACH_TOP_ABOVE)
          if near_sea and is_slope_gentle(x, z, y_int) and bio ~= "swamp" then
            -- beach
            data[svi] = ids.sand
            for i = 1, SAND_CAP_LAYERS - 1 do
              local yi = y_int - i
              if yi < emin.y then break end
              data[area:index(x, yi, z)] = ids.sand
            end
          else
            -- grass
            data[svi] = ids.grass
          end

          -- Reeds on shore (after surface placed)
          if y_int >= emin.y and y_int <= emax.y then
            place_reeds_if_shore(area, data, ids, x, y_int, z, emin, emax, bio)
          end

          -- A little flower sprinkle directly in mapgen for sanity checks
          -- (most natural grass/flower is handled in decor_postgen)
          if bio == "plains" or bio == "meadow" then
            if hash01(x, z, 444) < 0.01 then
              local top = y_int + 1
              if top <= emax.y and data[area:index(x, top, z)] == ids.air then
                data[area:index(x, top, z)] =
                  (hash01(x, z, 445) < 0.5) and ids.flower_daisy or ids.flower_bluebell
              end
            end
          end
        end
      end
    end
  end

  -- Postgen decorations (natural trees + MC-like short grass)
  local ok, decor = pcall(dofile, modpath.."/decor_postgen.lua")
  if ok and decor and decor.run_chunk then
    local biome_fn = function(x, z) return pick_biome(x, z) end
    decor.run_chunk(area, data, p2, ids, emin, emax, biome_fn)
  else
    minetest.log("warning", "[cw_mapgen] decor_postgen.lua missing or failed; skipping trees/grass decor")
  end

  vm:set_data(data)
  vm:set_param2_data(p2)
  vm:calc_lighting(nil, nil)
  vm:write_to_map()
end)