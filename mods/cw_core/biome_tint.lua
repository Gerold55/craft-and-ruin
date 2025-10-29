--========================================================
-- cw_core : Biome-driven tint policy (shared by grass & leaves)
--  - Plains: grass uniform index=2, leaves uniform index=10
--  - Helpers: clamp_* and preferred_* used by nodes + mapgen
--========================================================
local M = {}
local function clamp(x, lo, hi) if x < lo then return lo elseif x > hi then return hi else return x end end

M.SPECS = {
  plains = {
    temperature = 0.8,
    humidity    = 0.4,
    precip      = true,
    windows = {
      grass  = { min = 2,  max = 2 },   -- uniform grass
      leaves = { min = 9,  max = 11 },  -- uniform leaves preferred=10
    },
    preferred = {
      grass  = 2,
      leaves = 10,
    },
  },
  -- Reserve for later:
  -- swamp = { windows={grass={min=3,max=3}, leaves={min=3,max=3}}, preferred={grass=3, leaves=3} },
}

function M.spec_for_pos(pos)
  local ok, bd = pcall(minetest.get_biome_data, pos)
  if not ok or not bd then return "", nil end
  local name = (minetest.get_biome_name and minetest.get_biome_name(bd.biome)) or ""
  local lname = name:lower()
  for key, spec in pairs(M.SPECS) do
    if lname:find(key, 1, true) then return lname, spec end
  end
  return lname, nil
end

function M.clamp_index(kind, pos, idx)
  local _, spec = M.spec_for_pos(pos)
  if not spec then return idx end
  local win = spec.windows and spec.windows[kind]
  if not win then return idx end
  return clamp(idx, win.min or 0, win.max or 15)
end

function M.clamp_grass_index(pos, idx) return M.clamp_index("grass",  pos, idx) end
function M.clamp_leaf_index (pos, idx) return M.clamp_index("leaves", pos, idx) end

function M.preferred_index(kind, pos)
  local _, spec = M.spec_for_pos(pos)
  if not spec then return nil end
  local pref = spec.preferred and spec.preferred[kind]
  if pref ~= nil then return pref end
  local w = spec.windows and spec.windows[kind]
  if not w then return nil end
  local lo, hi = (w.min or 0), (w.max or 15)
  return math.floor((lo + hi) / 2 + 0.5)
end

function M.preferred_leaf_index (pos) return M.preferred_index("leaves", pos) end
function M.preferred_grass_index(pos) return M.preferred_index("grass",  pos) end

cw_core = rawget(_G, "cw_core") or {}
cw_core.biome_tint = M
return { biome_tint = M }
