local MP = minetest.get_modpath(minetest.get_current_modname())

cw_mobs = rawget(_G, "cw_mobs") or {}

-- Weather hook: other mods can override these to integrate rain/storms.
-- Example from your atmosphere mod: cw_mobs.is_raining = function() return cw_atmosphere.is_raining() end
cw_mobs.is_raining = cw_mobs.is_raining or function() return false end
function cw_mobs.is_bad_weather() return cw_mobs.is_raining() end

----------------------------------------------------------------------
-- Bee debugging commands (toggle per-bee, all bees, or dump state)
----------------------------------------------------------------------

local function cw_nearest_bee(player, range)
  range = range or 25
  local p = player:get_pos(); if not p then return end
  local best_obj, best_e, best_d2
  for _,obj in ipairs(minetest.get_objects_inside_radius(p, range)) do
    local e = obj:get_luaentity()
    if e and e.name == "cw_mobs:bee" then
      local op = obj:get_pos()
      if op then
        local dx,dy,dz = op.x - p.x, op.y - p.y, op.z - p.z
        local d2 = dx*dx + dy*dy + dz*dz
        if not best_d2 or d2 < best_d2 then
          best_obj, best_e, best_d2 = obj, e, d2
        end
      end
    end
  end
  return best_obj, best_e
end

-- If you kept the ray-based command, make it gracefully fallback to nearest:
local function cw_ray_bee(player, range)
  range = range or 20
  local p = player:get_pos(); if not p then return end
  local props = player:get_properties() or {}
  local eye = {x=p.x, y=p.y + (props.eye_height or 1.5), z=p.z}
  local dir = player:get_look_dir() or {x=0,y=0,z=1}
  local dst = {x=eye.x+dir.x*range, y=eye.y+dir.y*range, z=eye.z+dir.z*range}
  for hit in minetest.raycast(eye, dst, true, true) do
    if hit.type == "object" and hit.ref then
      local e = hit.ref:get_luaentity()
      if e and e.name == "cw_mobs:bee" then
        return hit.ref, e
      end
    end
  end
  -- Fallback: nearest bee
  return cw_nearest_bee(player, 25)
end

minetest.register_chatcommand("bee_dbg_near", {
  description = "Toggle debug on the nearest bee (within ~25m)",
  privs = {interact = true},
  func = function(name)
    local pl = minetest.get_player_by_name(name)
    if not pl then return false, "Player not found." end
    local obj, e = cw_nearest_bee(pl, 25)
    if not obj then return false, "No bees nearby (within ~25m)." end
    if e.set_debug then
      e:set_debug(not e._dbg)
      return true, e._dbg and "Nearest bee debug: ON" or "Nearest bee debug: OFF"
    end
    return false, "This bee lacks set_debug() (make sure new passive_bee.lua is loaded)."
  end
})

minetest.register_chatcommand("bee_dbg_near_state", {
  description = "Print detailed state of the nearest bee (within ~25m)",
  privs = {interact = true},
  func = function(name)
    local pl = minetest.get_player_by_name(name)
    if not pl then return false, "Player not found." end
    local obj, e = cw_nearest_bee(pl, 25)
    if not obj then return false, "No bees nearby (within ~25m)." end
    local pos = obj:get_pos()
    local s = {
      "=== cw_mobs:bee (nearest) ===",
      "pos="..(pos and minetest.pos_to_string(pos) or "?"),
      "state="..tostring(e._state),
      "home="..(e._home and minetest.pos_to_string(e._home) or "nil"),
      "flower="..(e._flower and minetest.pos_to_string(e._flower) or "nil"),
      ("nectar=%s pollen_left=%d"):format(tostring(e._has_nectar), tonumber(e._pollen_left or 0)),
      ("stings_done=%d sting_cd=%.2f"):format(tonumber(e._stings_done or 0), tonumber(e._sting_cd or 0)),
      ("path_pts=%d"):format((e._path and #e._path or 0)),
      ("aim_last=%s"):format(e._aim_last and minetest.pos_to_string(e._aim_last) or "nil"),
      ("avoid=(%.3f,%.3f)"):format(e._avoid and e._avoid.x or 0, e._avoid and e._avoid.z or 0),
      ("heading=(%.3f,%.3f)"):format(e._heading and e._heading.x or 0, e._heading and e._heading.z or 0),
    }
    for _,line in ipairs(s) do minetest.chat_send_player(name, line) end
    return true, "Dumped nearest bee state."
  end
})

-- (Optional convenience) Rebind /bee_dbg_pick to silently fallback to nearest if ray misses:
minetest.register_chatcommand("bee_dbg_pick", {
  description = "Toggle debug on the bee you're looking at (falls back to nearest within ~25m)",
  privs = {interact = true},
  func = function(name)
    local pl = minetest.get_player_by_name(name)
    if not pl then return false, "Player not found." end
    local obj, e = cw_ray_bee(pl, 20) -- will fallback to nearest
    if not obj then return false, "No bee found (aim at one or stand near one)." end
    if e.set_debug then
      e:set_debug(not e._dbg)
      return true, e._dbg and "Bee debug: ON" or "Bee debug: OFF"
    end
    return false, "This bee lacks set_debug()."
  end
})

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