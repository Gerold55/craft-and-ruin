-- Cube-World / Craft & Ruin — Mapgen
-- Adds "Clayspire Basin" (inverted mesa, rare) + gentle MC-like terrain:
-- beaches, rivers, reeds-by-water, scattered flowers/grass, natural trees.
-- No bit32. No weird operators. Clean, extendable.

-----------------------
-- Tunables
-----------------------
local SEA_LEVEL = 8
local WORLD_Y_MIN = -256
local WORLD_Y_MAX = 256

local DIRT_THICKNESS = 3
local BEACH_TOP_ABOVE_SEA = 2
local MAX_BEACH_SLOPE = 1.25
local SAND_CAP_LAYERS = 2
local SEAFLOOR_SAND_DEPTH = 4
local ABYSS_SAND_DEPTH = 1

-- Continentalness / relief
local CONTINENT_SCALE = 1400
local CONTINENT_AMPL = 16
local HILL_SCALE = 320
local HILL_AMPL = 10
local PEAK_SCALE = 520
local MOUNTAIN_AMPL = 42
local DETAIL_SCALE = 96
local DETAIL_GAIN = 2.2
local PEAK_BLEND = 0.48

-- Domain warp (to avoid grid-y look)
local WARP_SCALE = 180
local WARP_STRENGTH = 12.0

-- Rivers
local RIVER_WIDTH = 0.036
local RIVER_SOFT = 0.020
local RIVER_DEPTH = 7.0
local RIVER_BANK_HEIGHT = 1
local CREEK_DEPTH = 2
local RIVER_SAND_T = 0.08

-- Climate smoothing (stable color bands)
local CLIMATE_CELL = 64 -- larger = broader color bands
local COLOR_QUANTUM = 6 -- snap indices to avoid 1px flicker (0 to disable)
local LAT_FULL_RANGE = 6000 -- z-axis “pole” distance
local LAT_BLEND = 0.35 -- how much latitude cools

-- Rarity of Clayspire Basin
local CLAYSPIRE_RARITY = 0.015 -- ~1.5% of land columns target

-- Clay/Gravel disks (underwater & along rivers)
local DISK_CELL = 48
local DISK_R_MIN = 3
local DISK_R_MAX = 8
local DISK_CHANCE = 0.35 -- per-cell
local GRAVEL_BIAS = 0.55 -- >0.5 => more gravel than clay

-- Trees / flowers / grass densities (rough)
local PLAINS_TREE_CHANCE = 0.045 -- few trees in plains
local FOREST_TREE_CHANCE = 0.40 -- dense forest
local BIRCH_TREE_CHANCE = 0.30 -- birch forest density
local FLOWER_CHANCE = 0.02 -- independent scatter
local GRASS_CHANCE = 0.08 -- independent scatter

-----------------------
-- Helpers: PRNG & hash
-----------------------
local function hash01(x, z, salt)
  -- Stable 0..1 random from (x,z[,salt])
  local n = minetest.hash_node_position({x=x, y=salt or 0, z=z})
  -- mix with simple arithmetic (no bit ops)
  n = (n * 1103515245 + 12345) % 2147483647
  return (n % 10000) / 10000.0
end

local function jitter(x, z, scale, salt)
  return (hash01(x, z, salt) - 0.5) * 2.0 * (scale or 1)
end

local function clamp01(t) if t<0 then return 0 elseif t>1 then return 1 else return t end end
local function smoothstep(a, b, x) x = clamp01((x - a) / (b - a)); return x*x*(3 - 2*x) end

-----------------------
-- Noises (lazy init)
-----------------------
local n_temp, n_hum, n_cont1, n_cont2, n_erode, n_weird
local n_hill, n_peak, n_detail, n_riv, n_warpx, n_warpz

local function perlin(spread, seed, oct, pers)
  return minetest.get_perlin({offset=0, scale=1, spread=spread, seed=seed, octaves=oct, persist=pers})
end

local function ensure_noises()
  if not n_temp then n_temp = perlin({x=2048,y=2048,z=2048}, 591, 3, 0.55) end
  if not n_hum then n_hum = perlin({x=2048,y=2048,z=2048}, 7411, 3, 0.55) end
  if not n_cont1 then n_cont1 = perlin({x=CONTINENT_SCALE,y=CONTINENT_SCALE,z=CONTINENT_SCALE}, 8701, 3, 0.50) end
  if not n_cont2 then n_cont2 = perlin({x=CONTINENT_SCALE*0.5,y=CONTINENT_SCALE*0.5,z=CONTINENT_SCALE*0.5}, 9103, 2, 0.60) end
  if not n_erode then n_erode = perlin({x=640,y=640,z=640}, 2609, 4, 0.55) end
  if not n_weird then n_weird = perlin({x=PEAK_SCALE*0.9,y=PEAK_SCALE*0.9,z=PEAK_SCALE*0.9}, 4703, 4, 0.50) end
  if not n_hill then n_hill = perlin({x=HILL_SCALE, y=HILL_SCALE, z=HILL_SCALE}, 11337, 4, 0.52) end
  if not n_peak then n_peak = perlin({x=PEAK_SCALE, y=PEAK_SCALE, z=PEAK_SCALE}, 9941, 5, 0.45) end
  if not n_detail then n_detail = perlin({x=DETAIL_SCALE, y=DETAIL_SCALE, z=DETAIL_SCALE}, 431, 3, 0.60) end
  if not n_riv then n_riv = perlin({x=480, y=480, z=480}, 7227, 5, 0.55) end
  if not n_warpx then n_warpx = perlin({x=WARP_SCALE, y=WARP_SCALE, z=WARP_SCALE}, 3349, 3, 0.60) end
  if not n_warpz then n_warpz = perlin({x=WARP_SCALE, y=WARP_SCALE, z=WARP_SCALE}, 5561, 3, 0.60) end
end

-----------------------
-- Climate sampling
-----------------------
-- climate cache on coarse grid → bilerp for stable tint bands
local climate_cache = {}
local function cache_key(gx, gz) return gx .. "|" .. gz end

local function climate_cell_sample(gx, gz)
  local k = cache_key(gx, gz)
  local c = climate_cache[k]
  if c then return c end

  local x = gx * CLIMATE_CELL
  local z = gz * CLIMATE_CELL
  local sx = x + n_warpx:get_2d({x=x, y=z}) * WARP_STRENGTH
  local sz = z + n_warpz:get_2d({x=x+1337, y=z-733}) * WARP_STRENGTH

  local T = (n_temp:get_2d({x=sx,y=sz}) + 1) * 0.5
  local H = (n_hum :get_2d({x=sx,y=sz}) + 1) * 0.5

  -- latitude cools toward poles (z)
  local lat = 1.0 - clamp01(math.abs(z) / LAT_FULL_RANGE)
  T = T * (1.0 - LAT_BLEND) + lat * LAT_BLEND

  c = {T=T, H=H}
  climate_cache[k] = c
  return c
end

local function climate_TH(x, z)
  local fx, fz = x / CLIMATE_CELL, z / CLIMATE_CELL
  local gx, gz = math.floor(fx), math.floor(fz)
  local ux, uz = fx - gx, fz - gz

  local c00 = climate_cell_sample(gx, gz)
  local c10 = climate_cell_sample(gx+1, gz)
  local c01 = climate_cell_sample(gx, gz+1)
  local c11 = climate_cell_sample(gx+1, gz+1)

  local T0 = c00.T * (1-ux) + c10.T * ux
  local T1 = c01.T * (1-ux) + c11.T * ux
  local H0 = c00.H * (1-ux) + c10.H * ux
  local H1 = c01.H * (1-ux) + c11.H * ux

  return T0 * (1-uz) + T1 * uz, H0 * (1-uz) + H1 * uz
end

-----------------------
-- Height sampling
-----------------------
local function sample_all(x, z)
  -- domain warp
  local sx = x + n_warpx:get_2d({x=x, y=z}) * WARP_STRENGTH
  local sz = z + n_warpz:get_2d({x=x+1337, y=z-733}) * WARP_STRENGTH

  local cont = n_cont1:get_2d({x=sx,y=sz}) * 0.7 + n_cont2:get_2d({x=sx,y=sz}) * 0.3
  local base = cont * CONTINENT_AMPL + SEA_LEVEL

  local E = (n_erode:get_2d({x=sx,y=sz}) + 1) * 0.5
  local erode_h = 1.0 - E

  local hills = n_hill:get_2d({x=sx,y=sz}) * HILL_AMPL * (0.65 + 0.35*erode_h)
  local p = n_peak:get_2d({x=sx,y=sz}); p = 1 - math.abs(p); p = math.max(0, p * 1.5 - 0.6)
  local weird = (n_weird:get_2d({x=sx,y=sz}) + 1) * 0.5
  local peaks = p * (PEAK_BLEND * (0.5 + 0.8*weird)) * MOUNTAIN_AMPL * (0.6 + 0.4*erode_h)

  local micro = n_detail:get_2d({x=sx,y=sz}) * DETAIL_GAIN

  -- deep ocean shelves
  local ocean_t = 0
  if cont < -0.05 then
    ocean_t = clamp01((-0.05 - cont) / (-0.05 + 0.45))
  end
  base = base - (smoothstep(0,1,ocean_t)^2) * 48

  local raw_y = base + hills + peaks + micro

  -- river carve
  local rm = math.abs(n_riv:get_2d({x=sx, y=sz}))
  rm = smoothstep(0, RIVER_WIDTH + RIVER_SOFT, rm) -- 0 center
  local carve= (1 - rm); carve = carve * carve
  local highland_fade = clamp01((4 - (raw_y - SEA_LEVEL)) / 12)
  local coast_boost = clamp01(0.35 + 0.65 * ocean_t)
  local river_cut = carve * RIVER_DEPTH * highland_fade * coast_boost

  local y = raw_y - river_cut
  return y, rm, ocean_t
end

-----------------------
-- Content IDs (late)
-----------------------
local function ids()
  return {
    air = minetest.get_content_id("air"),
    water = minetest.get_content_id("cw_core:water_source"),
    stone = minetest.get_content_id("cw_core:stone"),
    dirt = minetest.get_content_id("cw_core:dirt"),
    grass = minetest.get_content_id("cw_core:grass_block"),
    sand = minetest.get_content_id("cw_core:sand"),
    gravel = minetest.get_content_id("cw_core:gravel"),
    clay = minetest.get_content_id("cw_core:clay"),

    oak_log = minetest.get_content_id("cw_core:oak_log"),
    oak_leaves = minetest.get_content_id("cw_core:oak_leaves"),

    birch_log = minetest.get_content_id("cw_core:birch_log") or -1,
    birch_leaves = minetest.get_content_id("cw_core:birch_leaves") or -1,

    -- terracotta colors (fallback safe)
    t_orange = minetest.get_content_id("cw_core:terracotta_orange") or minetest.get_content_id("cw_core:terracotta") or -1,
    t_red = minetest.get_content_id("cw_core:terracotta_red") or minetest.get_content_id("cw_core:terracotta") or -1,
    t_brown = minetest.get_content_id("cw_core:terracotta_brown") or minetest.get_content_id("cw_core:terracotta") or -1,
    t_yellow = minetest.get_content_id("cw_core:terracotta_yellow") or minetest.get_content_id("cw_core:terracotta") or -1,

    flower_daisy = minetest.get_content_id("cw_core:flower_daisy"),
    flower_bluebell = minetest.get_content_id("cw_core:flower_bluebell") or minetest.get_content_id("cw_core:flower_bluebell") or -1,
    grass_decor = minetest.get_content_id("cw_core:grass_decor"),
    reeds = minetest.get_content_id("cw_core:reeds"),
  }
end

-----------------------
-- Utility queries
-----------------------
local function slope_at(x,z, h)
  local h1 = select(1, sample_all(x+1, z))
  local h2 = select(1, sample_all(x, z+1))
  return math.max(math.abs(h1 - h), math.abs(h2 - h))
end

local function is_shorelike(x, z, surf_y)
  if surf_y < SEA_LEVEL - 1 then return false end
  local h1 = select(1, sample_all(x+1, z))
  local h2 = select(1, sample_all(x-1, z))
  local h3 = select(1, sample_all(x, z+1))
  local h4 = select(1, sample_all(x, z-1))
  return (h1 <= SEA_LEVEL + 0.1) or (h2 <= SEA_LEVEL + 0.1)
      or (h3 <= SEA_LEVEL + 0.1) or (h4 <= SEA_LEVEL + 0.1)
end

-- quantize a 0..255 index to bands
local function qidx(i)
  if COLOR_QUANTUM <= 0 then return i end
  return math.floor((i + COLOR_QUANTUM * 0.5) / COLOR_QUANTUM) * COLOR_QUANTUM
end

-----------------------
-- Biome picker
-----------------------
-- Returns a simple tag and controls we need for surface materials.
local function pick_biome(x, z, h, ocean_t)
  local T, H = climate_TH(x, z)

  -- Rare Clayspire gate: warm & semi-arid, mid-inland, not too steep
  -- Also prefers local basins (slightly below surroundings).
  local rare_gate = (T > 0.70 and H < 0.45 and ocean_t < 0.25 and h > SEA_LEVEL + 2)
                    and (hash01(x, z, 90210) < CLAYSPIRE_RARITY)

  if rare_gate then
    return "clayspire", {warm=true, arid=true}
  end

  -- Simple palette of common biomes to keep personality broad
  if ocean_t > 0.65 then return "deep_ocean", {} end
  if ocean_t > 0.30 then return "ocean", {} end

  if H < 0.25 and T > 0.65 then return "desert", {hot=true} end

  if T > 0.55 and H > 0.45 then
    -- warmer & wetter – forest vs plains by noise roll
    if hash01(x, z, 7) < 0.55 then return "forest", {} else return "plains", {} end
  end

  -- Default land fallback
  return "plains", {}
end

-----------------------
-- Seabed material disks
-----------------------
local function disk_center_for(x, z)
  -- align per DISK_CELL, then jitter inside
  local gx = math.floor(x / DISK_CELL)
  local gz = math.floor(z / DISK_CELL)
  local cx = gx * DISK_CELL + math.floor(hash01(gx, gz, 11) * DISK_CELL)
  local cz = gz * DISK_CELL + math.floor(hash01(gx, gz, 13) * DISK_CELL)
  local r = DISK_R_MIN + math.floor(hash01(gx, gz, 17) * (DISK_R_MAX - DISK_R_MIN + 1))
  return cx, cz, r
end

local function seabed_material_id(id, x, z)
  -- consistent choice per cell
  local gx = math.floor(x / DISK_CELL)
  local gz = math.floor(z / DISK_CELL)
  local roll = hash01(gx, gz, 23)
  return (roll < GRAVEL_BIAS) and id.gravel or id.clay
end

-----------------------
-- Tree placement
-----------------------
local function can_place_tree(area, data, c_air, x, y, z, radius, height)
  local r = radius or 3
  local top = y + (height or 6)
  for yy = y, top do
    for zz = z-r, z+r do
      for xx = x-r, x+r do
        if data[area:index(xx, yy, zz)] ~= c_air then
          return false
        end
      end
    end
  end
  return true
end

local function place_oak(area, data, p2, id, x, y, z)
  local trunk_h = 4 + math.floor(hash01(x,z,31)*3) -- 4..6
  if not can_place_tree(area, data, id.air, x, y+1, z, 3, trunk_h+3) then return end
  -- trunk
  for yy=0,trunk_h-1 do data[area:index(x, y+yy, z)] = id.oak_log end
  -- canopy
  local cy = y + trunk_h - 1
  local r = 2 + math.floor(hash01(x,z,33)*2)
  for dy=-2,2 do
    local ry = r - math.floor(math.abs(dy)/2)
    for dz=-ry, ry do
      for dx=-ry, ry do
        if dx*dx + dz*dz <= ry*ry + (hash01(x+dx, z+dz, 35) < 0.3 and 1 or 0) then
          local vi = area:index(x+dx, cy+dy, z+dz)
          if data[vi] == id.air then data[vi] = id.oak_leaves end
        end
      end
    end
  end
end

local function place_birch(area, data, p2, id, x, y, z)
  if id.birch_log == -1 or id.birch_leaves == -1 then return end
  local trunk_h = 5 + math.floor(hash01(x,z,41)*3) -- 5..7
  if not can_place_tree(area, data, id.air, x, y+1, z, 3, trunk_h+3) then return end
  for yy=0,trunk_h-1 do data[area:index(x, y+yy, z)] = id.birch_log end
  local cy = y + trunk_h - 1
  local r = 2
  for dy=-2,2 do
    local ry = r - math.floor(math.abs(dy)/2)
    for dz=-ry, ry do
      for dx=-ry, ry do
        if dx*dx + dz*dz <= ry*ry then
          local vi = area:index(x+dx, cy+dy, z+dz)
          if data[vi] == id.air then data[vi] = id.birch_leaves end
        end
      end
    end
  end
end

-----------------------
-- Node writer helper
-----------------------
local function set_column(area, data, x, surf_y, id_stone, id_top)
  data[area:index(x, surf_y, area.z0)] = id_top
  data[area:index(x, surf_y - 1, area.z0)] = id_stone
  data[area:index(x, surf_y - 2, area.z0)] = id_stone
end

-----------------------
-- on_generated
-----------------------
minetest.register_on_generated(function(minp, maxp, seed)
  if maxp.y < WORLD_Y_MIN or minp.y > WORLD_Y_MAX then return end
  ensure_noises()
  climate_cache = {} -- reset per block

  local id = ids()
  if id.stone == -1 or id.dirt == -1 or id.grass == -1 or id.sand == -1 or id.water == -1 then
    minetest.log("error", "[cw_mapgen] missing core nodes, aborting chunk.")
    return
  end

  local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
  local area = VoxelArea:new{MinEdge=emin, MaxEdge=emax}
  local data = vm:get_data()
  local p2 = vm:get_param2_data()

  -- hack: we’ll temporarily store z in area.z0 during loops to avoid recomputes
  for z = minp.z, maxp.z do
    area.z0 = z
    for x = minp.x, maxp.x do
      local y_real, rm, ocean_t = sample_all(x, z)
      local surf_y = math.floor(y_real + 0.5)
      local biome = pick_biome(x, z, surf_y, ocean_t)

      -- Column fill
      for y = minp.y, maxp.y do
        local vi = area:index(x, y, z)
        if y <= surf_y then
          data[vi] = id.stone
        else
          if y <= SEA_LEVEL then
            data[vi] = id.water
          else
            data[vi] = id.air
          end
        end
      end

      if surf_y >= minp.y and surf_y <= maxp.y then
        local svi = area:index(x, surf_y, z)

        if surf_y <= SEA_LEVEL then
          -- seafloor sand
          local depth = SEA_LEVEL - surf_y
          local target = (ocean_t >= 0.8) and ABYSS_SAND_DEPTH or SEAFLOOR_SAND_DEPTH
          local layers = math.min(target, depth + 1)
          for dy = 0, (layers - 1) do
            local yi = surf_y - dy
            if yi >= minp.y then data[area:index(x, yi, z)] = id.sand end
          end

          -- sparse seabed material disks (gravel/clay) under the sand
          local cx, cz, r = disk_center_for(x, z)
          local dx, dz = x - cx, z - cz
          if dx*dx + dz*dz <= r*r then
            local mat = seabed_material_id(id, x, z)
            if mat ~= -1 then
              local under = surf_y - layers
              if under >= minp.y then
                data[area:index(x, under, z)] = mat
              end
            end
          end

        else
          -- LAND SURFACES
          local h_slope = slope_at(x, z, y_real)
          local near_o = is_shorelike(x, z, surf_y)
          local low = surf_y <= SEA_LEVEL + BEACH_TOP_ABOVE_SEA
          local gentle = (h_slope <= MAX_BEACH_SLOPE)
          local is_river_center = (rm < RIVER_SAND_T) and (surf_y <= SEA_LEVEL + 1)

          if near_o and low and gentle and not is_river_center and biome ~= "clayspire" then
            -- beach
            data[svi] = id.sand
            for i=1,(SAND_CAP_LAYERS-1) do
              local yi = surf_y - i
              if yi < minp.y then break end
              data[area:index(x, yi, z)] = id.sand
            end
          elseif biome == "desert" then
            data[svi] = id.sand
            for i=1,(DIRT_THICKNESS-1) do
              local yi = surf_y - i
              if yi < minp.y then break end
              data[area:index(x, yi, z)] = id.sand
            end

          elseif biome == "clayspire" then
            -- Inverted mesa: basin floors and eroded layered walls
            -- Floor: compact terracotta with patchy sand
            local band = (surf_y / 6) % 4
            local terr = (band == 0 and id.t_orange) or (band == 1 and id.t_red)
                       or (band == 2 and id.t_brown) or id.t_yellow
            if terr ~= -1 then
              data[svi] = terr
              for i=1,(DIRT_THICKNESS-1) do
                local yi = surf_y - i
                if yi < minp.y then break end
                data[area:index(x, yi, z)] = terr
              end
            else
              -- fallback if no terracotta nodes registered
              data[svi] = id.sand
              for i=1,(DIRT_THICKNESS-1) do
                local yi = surf_y - i
                if yi < minp.y then break end
                data[area:index(x, yi, z)] = id.sand
              end
            end

          else
            -- normal vegetated land
            for dy = 0, (DIRT_THICKNESS - 2) do
              local yi = surf_y - dy
              if yi >= minp.y then data[area:index(x, yi, z)] = id.dirt end
            end
            data[svi] = id.grass

            -- Creek fill (shallow)
            if (rm < RIVER_SAND_T) and (surf_y <= SEA_LEVEL + RIVER_BANK_HEIGHT) then
              local top_y = surf_y
              local bottom_y = math.max(minp.y, surf_y - (CREEK_DEPTH - 1))
              for yi = top_y, bottom_y, -1 do
                local viw = area:index(x, yi, z)
                data[viw] = id.water
              end
              local bed_y = bottom_y - 1
              if bed_y >= minp.y then data[area:index(x, bed_y, z)] = id.sand end
            end
          end

          -- river bed sand in channels below sea
          if (rm < RIVER_SAND_T) and surf_y <= SEA_LEVEL then
            data[svi] = id.sand
          end
        end
      end
    end
  end

  ---------------------------
  -- Second pass: decorations
  ---------------------------
  -- Independent scatter = no rows/lines. No need for minp/maxp elsewhere.
  for z = minp.z, maxp.z do
    for x = minp.x, maxp.x do
      local y_real = select(1, sample_all(x, z))
      local surf_y = math.floor(y_real + 0.5)
      if surf_y >= minp.y and surf_y <= maxp.y then
        local svi = area:index(x, surf_y, z)
        local above = area:index(x, surf_y+1, z)
        local node = data[svi]

        -- reeds: exactly by water, on sand or dirt, not 2–4 blocks away
        if (node == id.sand or node == id.dirt) and data[above] == id.air then
          -- check 4-neighbors for water
          local adjw = (data[area:index(x+1, surf_y, z)] == id.water)
                    or (data[area:index(x-1, surf_y, z)] == id.water)
                    or (data[area:index(x, surf_y, z+1)] == id.water)
                    or (data[area:index(x, surf_y, z-1)] == id.water)
          if adjw and hash01(x, z, 201) < 0.20 then
            data[above] = id.reeds
          end
        end

        -- plains vs forest trees:
        local biome = pick_biome(x, z, surf_y, select(3, sample_all(x, z)))
        if node == id.grass and data[above] == id.air then
          -- grass decor (short grass) — lighter than before
          if biome == "plains" and hash01(x, z, 301) < GRASS_CHANCE then
            data[above] = id.grass_decor
          elseif biome == "forest" and hash01(x, z, 303) < GRASS_CHANCE * 0.8 then
            data[above] = id.grass_decor
          end

          -- flowers sparse, unpatched (independent)
          if hash01(x, z, 321) < FLOWER_CHANCE then
            data[above] = (hash01(x, z, 322) < 0.5 and id.flower_daisy or id.flower_bluebell)
          end

          -- trees: probabilistic, no grids
          local slope = slope_at(x, z, y_real)
          if slope <= 1.3 then
            if biome == "plains" and hash01(x, z, 341) < PLAINS_TREE_CHANCE then
              place_oak(area, data, p2, id, x, surf_y+1, z)
            elseif biome == "forest" then
              local r = hash01(x, z, 343)
              if r < FOREST_TREE_CHANCE then
                if r < 0.5 then place_oak(area, data, p2, id, x, surf_y+1, z)
                else place_birch(area, data, p2, id, x, surf_y+1, z) end
              end
            end
          end
        end
      end
    end
  end

  vm:set_data(data)
  vm:set_param2_data(p2)
  vm:calc_lighting(nil, nil)
  vm:write_to_map()
end)