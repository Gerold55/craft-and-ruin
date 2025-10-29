-- ============================================================================
-- cw_mapgen/caves.lua — simple caves + occasional ravines
-- No minp/maxp usage. We read the block we’re inside via voxelmanip’s emin/emax.
-- Assumes terrain was already placed by mapgen.lua for the same on_generated turn.
-- ============================================================================

local CAVES = {}

-- Respect terrain or fall back safely
SEA_LEVEL = SEA_LEVEL or 64

-- Tunables (Minecraft-ish feel, but cheaper)
local Y_MIN = -512 -- don’t carve below this
local Y_MAX = SEA_LEVEL - 4 -- carve mostly below sea
local CAVE_SCALE = {x=96,y=64,z=96} -- main 3D noise
local CAVE_OCT = 3
local CAVE_PERS = 0.55
local CAVE_THRESH = 0.66 -- higher = fewer caves

-- Ravines: two elongated fields multiplied together
local RAV_A_SCALE = {x=180,y=40,z=60}
local RAV_B_SCALE = {x=60,y=40,z=180}
local RAV_OCT = 2
local RAV_PERS = 0.5
local RAV_STRENGTH= 0.72 -- 0..1, higher = fewer ravines

-- Lazy noise
local n_cave, n_rav_a, n_rav_b
local function perlin3(spread, seed, oct, pers)
  return minetest.get_perlin({
    offset=0, scale=1, spread=spread,
    seed=seed, octaves=oct, persist=pers
  })
end

local function ensure_noises(seed)
  if not n_cave then n_cave = perlin3(CAVE_SCALE, 0x0C0A5E + seed, CAVE_OCT, CAVE_PERS) end
  if not n_rav_a then n_rav_a = perlin3(RAV_A_SCALE, 0x04A1BA + seed, RAV_OCT, RAV_PERS) end
  if not n_rav_b then n_rav_b = perlin3(RAV_B_SCALE, 0x04A1BB + seed, RAV_OCT, RAV_PERS) end
end

-- Small helper: safe content ids
local function ids()
  return {
    air = minetest.get_content_id("air"),
    stone = minetest.get_content_id("cw_core:stone"),
    water = minetest.get_content_id("cw_core:water_source"),
  }
end

-- Carve function that acts on the current block; does NOT need minp/maxp
local function carve_current_block(seed)
  ensure_noises(seed or 0)

  local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
  if not vm or not emin or not emax then return end

  local area = VoxelArea:new{MinEdge=emin, MaxEdge=emax}
  local data = vm:get_data()
  local p2 = vm:get_param2_data()
  local id = ids()

  -- Clamp vertical work band
  local y0 = math.max(emin.y, Y_MIN)
  local y1 = math.min(emax.y, Y_MAX)

  -- Nothing to do if this block sits entirely above the carve band
  if y0 > y1 then return end

  -- Iterate once; keep formulas simple (no minp/maxp references)
  for z = emin.z, emax.z do
    for y = y0, y1 do
      for x = emin.x, emax.x do
        local vi = area:index(x,y,z)
        if data[vi] == id.stone then
          -- Main cave field
          local c = n_cave:get_3d({x=x, y=y, z=z}) -- [-1..1]
          local cave_ok = (c > CAVE_THRESH)

          -- Ravine field — elongated seams
          local ra = n_rav_a:get_3d({x=x, y=y, z=z}) -- [-1..1]
          local rb = n_rav_b:get_3d({x=x, y=y, z=z})
          local rav = math.abs(ra) * math.abs(rb) -- [0..1]
          local rav_ok = (rav > RAV_STRENGTH)

          if cave_ok or rav_ok then
            data[vi] = id.air

            -- Optional: shallow water seep for low elevations below SEA_LEVEL
            -- (keeps some flooded caves; skip if you dislike)
            if y <= SEA_LEVEL - 6 then
              -- Check just above; if it’s also air, don’t place water here.
              local via = area:index(x, y+1, z)
              if data[via] ~= id.air then
                -- very small probability to place a water pocket
                -- (cheap hash from coordinates)
                local h = minetest.hash_node_position({x=x,y=y,z=z})
                if (h % 97) == 0 then
                  data[vi] = id.water
                  if p2 then p2[vi] = 0 end
                end
              end
            end

          end
        end
      end
    end
  end

  vm:set_data(data)
  if p2 then vm:set_param2_data(p2) end
  -- Lighting remains owned by terrain pass; let that stage call calc_lighting/write
end

-- Public API (so decor_postgen can call it explicitly)
CAVES.carve_current_block = carve_current_block
cw_caves = CAVES

-- Optional: run caves in our own on_generated if you want automatic carving.
-- If you prefer to control order, comment this out and call carve_current_block()
-- from your decor_postgen on_generated BEFORE calc_lighting.
minetest.register_on_generated(function(_, _, seed)
  carve_current_block(seed or 0)
end)