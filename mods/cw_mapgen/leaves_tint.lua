--========================================================
-- cw_mapgen : Leaves palette tint at mapgen (biome uniform)
--  - Uses biome-preferred (uniform) leaf index (Plains=10)
--  - Else humidity→palette + biome clamp
--========================================================

local cw_core = rawget(_G, "cw_core") or {}

local function foliage_humidity_to_palette(h)
  if cw_core.foliage_humidity_to_palette then
    return cw_core.foliage_humidity_to_palette(h)
  end
  h = math.max(0, math.min(100, h or 50))
  return math.floor((h / 100) * 15 + 0.5)
end

local preferred_leaf = (cw_core.biome_tint and cw_core.biome_tint.preferred_leaf_index) or function(_) return nil end
local clamp_leaf     = (cw_core.biome_tint and cw_core.biome_tint.clamp_leaf_index)     or function(_,i) return i end

local LEAF_CID = (function()
  local set = {}
  for name, def in pairs(minetest.registered_nodes) do
    if def and def.groups and def.groups.leaves and def.paramtype2 == "color" and def.palette then
      set[minetest.get_content_id(name)] = true
    end
  end
  return set
end)()

local bit = rawget(_G,"bit32") or rawget(_G,"bit")
local rshift = (bit and bit.rshift) or function(x,s) return math.floor(x / 2^s) end
local function make_h_cache()
  local cache = {}
  return function(x, y, z)
    local key = x .. "," .. rshift(y,4) .. "," .. z
    local h = cache[key]
    if h ~= nil then return h end
    local ok, data = pcall(minetest.get_biome_data, {x=x, y=y, z=z})
    h = (ok and data and data.humidity) or 50
    cache[key] = h
    return h
  end
end

minetest.register_on_generated(function(minp, maxp, seed)
  local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
  if not vm then return end
  local area = VoxelArea:new({ MinEdge = emin, MaxEdge = emax })
  local data = vm:get_data()
  local p2   = vm:get_param2_data()
  local get_h = make_h_cache()

  local changed = false

  for z = minp.z, maxp.z do
    for y = minp.y, maxp.y do
      for x = minp.x, maxp.x do
        local vi = area:index(x, y, z)
        local id = data[vi]
        if LEAF_CID[id] then
          local pref = preferred_leaf({x=x,y=y,z=z})
          local idx
          if pref ~= nil then
            idx = pref
          else
            local base = foliage_humidity_to_palette(get_h(x, y, z))
            idx = clamp_leaf({x=x,y=y,z=z}, base)
          end
          if p2[vi] ~= idx then p2[vi] = idx; changed = true end
        end
      end
    end
  end

  if changed then
    vm:set_param2_data(p2)
    vm:write_to_map()
  end
end)
