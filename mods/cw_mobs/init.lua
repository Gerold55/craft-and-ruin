local MP = minetest.get_modpath(minetest.get_current_modname())

cw_mobs = rawget(_G, "cw_mobs") or {}

-- Weather hook: other mods can override these to integrate rain/storms.
-- Example from your atmosphere mod: cw_mobs.is_raining = function() return cw_atmosphere.is_raining() end
cw_mobs.is_raining = cw_mobs.is_raining or function() return false end
function cw_mobs.is_bad_weather() return cw_mobs.is_raining() end

-- ========= Pollination registry =========
cw_mobs.pollinate_handlers = cw_mobs.pollinate_handlers or {}
function cw_mobs.register_pollinate_handler(predicate, action)
  table.insert(cw_mobs.pollinate_handlers, {pred = predicate, act = action})
end

local function advance_numeric_suffix(pos, node)
  local base, num = string.match(node.name, "^(.-)_([0-9]+)$")
  if not base or not num then return false end
  local nextname = base .. "_" .. (tonumber(num) + 1)
  if minetest.registered_nodes[nextname] then
    minetest.swap_node(pos, {name = nextname, param2 = node.param2})
    return true
  end
  return false
end

-- Default handler: nodes with _# suffix advance by one if next exists
cw_mobs.register_pollinate_handler(
  function(name) return string.find(name, "_%d+$") ~= nil end,
  function(pos, node) return advance_numeric_suffix(pos, node) end
)

-- Public entrypoint used by bees
function cw_mobs.pollinate_plant(pos, node)
  for _,h in ipairs(cw_mobs.pollinate_handlers) do
    if h.pred(node.name, node, pos) and h.act(pos, node) then return true end
  end
  return false
end

-- Utility: count named entities in radius
cw_mobs.util = cw_mobs.util or {}
function cw_mobs.util.count_named(center, r, name)
  local n = 0
  for _,o in ipairs(minetest.get_objects_inside_radius(center, r)) do
    local e = o:get_luaentity()
    if e and e.name == name then n = n + 1 end
  end
  return n
end

-- Load nodes & entities
dofile(MP.."/nodes/beehive.lua")
dofile(MP.."/mobs/passive_bee.lua")

-- 2) Crop growth helper (advance exactly one stage on pollination)
dofile(MP.."/crop_grow.lua")

-- (Your honey bottle item stays in items/bottle_honey.lua)
local items = MP.."/items/bottle_honey.lua"
local f = io.open(items, "r"); if f then f:close(); dofile(items) end