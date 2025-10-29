-- cw_mapgen/ores.lua
-- Deterministic ore blobs with Minecraft-like vertical distribution.
-- Skips any ore whose node isn't registered.

local M = {}

local IDS
local function ids()
  if IDS then return IDS end
  IDS = {
    stone = minetest.get_content_id("cw_core:stone"),
    ore_coal = minetest.get_content_id("cw_core:ore_coal") or -1,
    ore_iron = minetest.get_content_id("cw_core:ore_iron") or -1,
    ore_copper = minetest.get_content_id("cw_core:ore_copper") or -1,
    ore_gold = minetest.get_content_id("cw_core:ore_gold") or -1,
  }
  return IDS
end

-- Simple block PRNG
local function rng_for_block(minp, salt)
  local s = minetest.hash_node_position({x=minp.x, y=minp.y or 0, z=minp.z}) + (salt or 0)
  return PcgRandom(s)
end

-- Ore model: (name, id field, y_min, y_max, tries_per_block, blob_radius_range)
local ORES = {
  { name="coal", key="ore_coal", y_min= 0, y_max=128, tries=32, rmin=1, rmax=3 },
  { name="iron", key="ore_iron", y_min=-32, y_max= 64, tries=24, rmin=1, rmax=3 },
  { name="copper", key="ore_copper", y_min=-16, y_max= 64, tries=18, rmin=1, rmax=2 },
  { name="gold", key="ore_gold", y_min=-48, y_max= 16, tries=10, rmin=1, rmax=2 },
}

local function place_blob(area, data, x,y,z, r, stone_cid, ore_cid)
  local xmin,xmax = math.floor(x-r), math.ceil(x+r)
  local ymin,ymax = math.floor(y-r), math.ceil(y+r)
  local zmin,zmax = math.floor(z-r), math.ceil(z+r)
  local r2 = r*r
  for zz=zmin,zmax do
    for yy=ymin,ymax do
      for xx=xmin,xmax do
        local dx,dy,dz = xx-x, yy-y, zz-z
        if dx*dx + dy*dy + dz*dz <= r2 then
          local vi = area:index(xx,yy,zz)
          if data[vi] == stone_cid then
            data[vi] = ore_cid
          end
        end
      end
    end
  end
end

function M.populate(area, data, minp, maxp, seed)
  local id = ids()
  local rng = rng_for_block(minp, (seed or 0) + 70001)

  for _,ore in ipairs(ORES) do
    local ore_cid = id[ore.key]
    if ore_cid and ore_cid ~= -1 then
      local tries = ore.tries + rng:next(-5,5)
      if tries < 0 then tries = 0 end
      for _=1, tries do
        local x = rng:next(minp.x, maxp.x)
        local y = rng:next(math.max(minp.y, ore.y_min), math.min(maxp.y, ore.y_max))
        local z = rng:next(minp.z, maxp.z)
        local r = rng:next(ore.rmin*10, ore.rmax*10) / 10.0
        place_blob(area, data, x,y,z, r, id.stone, ore_cid)
      end
    end
  end
end

return M
