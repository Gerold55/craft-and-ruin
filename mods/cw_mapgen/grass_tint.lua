--========================================================
-- cw_mapgen : Grass palette tint + snow detection at mapgen
--  - Enforces biome-preferred (uniform) grass (Plains idx=2)
--  - Else humidity→palette + biome clamp
--  - Swaps to snow variant if snow node directly above
--========================================================

local MOD_CORE = "cw_core"
local NAME_GRASS      = MOD_CORE..":grass_block"
local NAME_GRASS_SNOW = MOD_CORE..":grass_block_snow"
local cw_core = rawget(_G, "cw_core") or {}

local function humidity_to_palette(h)
  if cw_core.humidity_to_palette then return cw_core.humidity_to_palette(h) end
  h = math.max(0, math.min(100, h or 50))
  return math.floor((h / 100) * 15 + 0.5)
end

local preferred_grass = (cw_core.biome_tint and cw_core.biome_tint.preferred_grass_index) or function(_) return nil end
local clamp_grass     = (cw_core.biome_tint and cw_core.biome_tint.clamp_grass_index)     or function(_,i) return i end

local b = rawget(_G, "bit32") or rawget(_G, "bit")
local rshift = (b and b.rshift) or function(x, s) return math.floor(x / 2^s) end

local SNOW_CID = (function()
  local t = {}
  for name, def in pairs(minetest.registered_nodes) do
    if def.groups and def.groups.snow and def.groups.snow > 0 then
      t[minetest.get_content_id(name)] = true
    end
  end
  return t
end)()

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

  local cid_grass      = minetest.get_content_id(NAME_GRASS)
  local cid_grass_snow = minetest.get_content_id(NAME_GRASS_SNOW)
  if cid_grass == minetest.CONTENT_IGNORE then return end

  local get_h = make_h_cache()
  local any_id_swapped = false

  for z = minp.z, maxp.z do
    for y = minp.y, maxp.y do
      for x = minp.x, maxp.x do
        local vi = area:index(x, y, z)
        local id = data[vi]
        if id == cid_grass or id == cid_grass_snow then
          local is_snow_above = false
          if y + 1 <= maxp.y then
            local via = area:index(x, y+1, z)
            is_snow_above = not not SNOW_CID[data[via]]
          end

          local want = is_snow_above and cid_grass_snow or cid_grass
          if id ~= want then data[vi] = want; any_id_swapped = true end

          local pref = preferred_grass({x=x,y=y,z=z})
          local idx
          if pref ~= nil then
            idx = pref
          else
            local base = humidity_to_palette(get_h(x, y, z))
            idx = clamp_grass({x=x,y=y,z=z}, base)
          end
          p2[vi] = idx
        end
      end
    end
  end

  vm:set_data(data)
  vm:set_param2_data(p2)
  if any_id_swapped and vm.calc_lighting then vm:calc_lighting(minp, maxp) end
  vm:write_to_map()
end)
