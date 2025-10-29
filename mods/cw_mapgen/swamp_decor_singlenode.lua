-- cw_mapgen/swamp_decor_singlenode.lua
-- Swamp-only decorations for singlenode pipelines:
-- - Denser reeds on banks (cw_core:reeds)
-- - Lily pads on water (cw_core:lilypad)
-- - Sparse squat oaks

local SEA = tonumber(minetest.settings:get("water_level")) or 1

local c_air      = minetest.get_content_id("air")
local c_water    = minetest.get_content_id("cw_core:water_source")
local c_dirt     = minetest.get_content_id("cw_core:dirt")
local c_grass    = minetest.get_content_id("cw_core:grass_block")
local c_sand     = minetest.get_content_id("cw_core:sand")
local c_reeds    = minetest.get_content_id("cw_core:reeds")
local c_lilypad  = minetest.get_content_id("cw_core:lilypad")
local c_log      = minetest.get_content_id("cw_core:oak_log")
local c_leaves   = minetest.get_content_id("cw_core:oak_leaves")

local function is_solid(cid)
  return cid ~= c_air and cid ~= c_water
end

-- Find first solid from top in this column; returns y or nil
local function find_surface_y(area, data, x, z, y_top, y_bot)
  for y = y_top, y_bot, -1 do
    local vi = area:index(x, y, z)
    local cid = data[vi]
    if is_solid(cid) then
      -- surface is this solid; return its y
      return y
    end
  end
  return nil
end

-- 4-neighbor water adjacency check around (x,y,z) ground cell
local function has_water_adjacent(area, data, x, y, z)
  local coords = {
    {x+1,y,z}, {x-1,y,z}, {x,y,z+1}, {x,y,z-1}
  }
  for i=1,4 do
    local p = coords[i]
    local vi = area:index(p[1], p[2], p[3])
    if data[vi] == c_water then return true end
  end
  return false
end

-- Small helper to randomly place a squat oak (5x5x6) if space allows
local function maybe_place_squat_oak(area, data, x, y, z, pr)
  if pr:next(0, 9999) > 12 then return end -- ~0.12% per tested column → sparse
  -- Check space for trunk + low canopy (radius 2, height 6)
  for yy = y+1, y+6 do
    for dz = -2, 2 do
      for dx = -2, 2 do
        local vi = area:index(x+dx, yy, z+dz)
        local cid = data[vi]
        if cid ~= c_air and cid ~= c_leaves then
          return -- blocked
        end
      end
    end
  end
  -- Place trunk
  for yy = 0, 4 do
    data[area:index(x, y+1+yy, z)] = c_log
  end
  -- Place low, wide canopy
  local layers = {
    {yy=3, r=2}, {yy=4, r=2}, {yy=5, r=1},
  }
  for _,L in ipairs(layers) do
    for dz = -L.r, L.r do
      for dx = -L.r, L.r do
        if not (dx==0 and dz==0 and L.yy<=4) then
          local vi = area:index(x+dx, y+1+L.yy, z+dz)
          if data[vi] == c_air then data[vi] = c_leaves end
        end
      end
    end
  end
end

minetest.register_on_generated(function(minp, maxp, blockseed)
  local vm, emin, emax = minetest.get_voxel_manip()
  vm:read_from_map(minp, maxp)
  local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
  local data = vm:get_data()

  local pr = PseudoRandom(blockseed + 913)

  -- iterate columns
  for z = minp.z, maxp.z do
    for x = minp.x, maxp.x do
      -- find surface
      local ysurf = find_surface_y(area, data, x, z, maxp.y, minp.y)
      if ysurf then
        -- classify biome
        local biome = cw_mapgen.get_biome_at(x, ysurf, z)  -- from biome_mask.lua
        if biome == "cw_swamp" then
          local vi = area:index(x, ysurf, z)
          local cid = data[vi]

          -- ---- REEDS: on grass/dirt/sand next to water ----
          if cid == c_grass or cid == c_dirt or cid == c_sand then
            if has_water_adjacent(area, data, x, ysurf, z) then
              -- chance to place a reed base (column will grow via ABM / after_place)
              if pr:next(0,99) < 20 then           -- ~20% along banks
                local above = area:index(x, ysurf+1, z)
                if data[above] == c_air then
                  data[above] = c_reeds
                end
              end
              -- maybe try a squat oak a little inland (less likely right on shoreline)
              if pr:next(0,999) < 3 and ysurf >= SEA-1 then
                maybe_place_squat_oak(area, data, x, ysurf, z, pr)
              end
            end
          end

          -- ---- LILY PADS: on still water surface ----
          -- place only if this column’s surface *is* water and air above
          if cid == c_water then
            local above = area:index(x, ysurf+1, z)
            if data[above] == c_air then
              if pr:next(0,99) < 8 then            -- ~8% coverage
                data[above] = c_lilypad
              end
            end
          end
        end
      end
    end
  end

  vm:set_data(data)
  vm:write_to_map()
end)
