-- cw_mobs/nodes/beehive.lua
local core = core
cw_mobs = rawget(_G, "cw_mobs") or {}

-------------------------
-- Config
-------------------------
local MAX_BEES = 3 -- max stored bees
local HONEY_MAX = 5
local TICK_SEC = 2 -- node timer interval
local EXIT_COOLDOWN = 5 -- seconds between releasing bees
local ANGER_RADIUS = 22

-- textures (rename if needed)
local TEX_TOP = "cw_mobs_beehive_top.png"
local TEX_BOTTOM = "cw_mobs_beehive_bottom.png"
local TEX_SIDE = "cw_mobs_beehive_side.png"
local TEX_FRONT = "cw_mobs_beehive_front.png"
local TEX_FRONT_FULL = "cw_mobs_beehive_front_full.png"

-------------------------
-- Helpers
-------------------------
local function now()
  return core.get_gametime()
end

local function is_day()
  local t = core.get_timeofday()
  return t >= 0.2 and t <= 0.8
end

local function has_campfire_below(pos)
  -- Look a few nodes down for a campfire-like node
  for dy = 1, 5 do
    local p = {x = pos.x, y = pos.y - dy, z = pos.z}
    local n = core.get_node(p)
    if n and n.name ~= "air" then
      local def = core.registered_nodes[n.name]
      if def and def.groups and def.groups.campfire and def.groups.campfire > 0 then
        return true
      end
    end
  end
  return false
end

local function facedir_front_vec(param2)
  local d = core.facedir_to_dir(param2 or 0)
  return {x = d.x, y = 0, z = d.z}
end

local function gate_pos_from(param2, pos)
  local dir = facedir_front_vec(param2)
  local gate = {
    x = pos.x + 0.5 + dir.x * 0.51,
    y = pos.y + 0.5,
    z = pos.z + 0.5 + dir.z * 0.51
  }
  return gate, dir
end

local function read_meta(pos)
  local m = core.get_meta(pos)
  return {
    bees = m:get_int("bees") or 0,
    honey = m:get_int("honey") or 0,
    last_exit = m:get_float("last_exit") or 0,
  }, m
end

local function write_meta(pos, data, m)
  m = m or core.get_meta(pos)
  if data.bees ~= nil then m:set_int("bees", data.bees) end
  if data.honey ~= nil then m:set_int("honey", data.honey) end
  if data.last_exit ~= nil then m:set_float("last_exit", data.last_exit) end
  m:mark_as_private({"bees","honey","last_exit"})
end

local function set_hive_node_by_honey(pos, honey)
  local node = core.get_node(pos)
  local want = (honey >= HONEY_MAX) and "cw_mobs:beehive_full" or "cw_mobs:beehive"
  if node.name ~= want then
    node.name = want
    core.swap_node(pos, node)
  end
end

-------------------------
-- Public API (for bees)
-------------------------

function cw_mobs.hive_capacity(_pos)
  return MAX_BEES
end

function cw_mobs.hive_space(pos)
  local m = core.get_meta(pos)
  local inside = m:get_int("bees") or 0
  return math.max(0, MAX_BEES - inside)
end

function cw_mobs.hive_entrance_point(pos)
  local node = core.get_node(pos)
  return gate_pos_from(node.param2 or 0, pos) -- returns gate, dir
end

function cw_mobs.hive_front_gate_ok(pos, obj_pos)
  local node = core.get_node(pos)
  local gate, dir = gate_pos_from(node.param2 or 0, pos)

  if not obj_pos then return false end

  local dx = math.abs(obj_pos.x - gate.x)
  local dz = math.abs(obj_pos.z - gate.z)
  local dy = math.abs(obj_pos.y - gate.y)
  if dy > 0.40 or dx > 0.35 or dz > 0.35 then
    return false
  end

  local relx = (obj_pos.x - (pos.x + 0.5)) * dir.x
  local relz = (obj_pos.z - (pos.z + 0.5)) * dir.z
  local forward = relx + relz
  return forward > 0.05
end

-- Bee calls this when it is at the gate and wants to enter.
function cw_mobs.hive_try_enter(pos, bee_obj)
  local data, m = read_meta(pos)

  if data.bees >= MAX_BEES then
    return false
  end
  if not bee_obj then
    return false
  end

  local obj_pos = bee_obj:get_pos()
  if not obj_pos then
    return false -- treat as already gone
  end

  if not cw_mobs.hive_front_gate_ok(pos, obj_pos) then
    return false
  end

  local ent = bee_obj:get_luaentity()
  if not ent or ent.name ~= "cw_mobs:bee" then
    return false
  end

  -- Snapshot whether it had nectar BEFORE removing
  local had_nectar = ent._has_nectar and true or false

  -- Remove the bee entity (it "moves into" the hive)
  bee_obj:remove()

  -- Count resident
  data.bees = math.min(MAX_BEES, data.bees + 1)

  -- Nectar contributes honey
  if had_nectar then
    data.honey = math.min(HONEY_MAX, data.honey + 1)
  end

  write_meta(pos, data, m)
  set_hive_node_by_honey(pos, data.honey)

  return true
end

-- Called when hive should make nearby bees angry at a player
function cw_mobs.anger_bees_from_hive(pos, player)
  local objs = core.get_objects_inside_radius(pos, ANGER_RADIUS)
  for _,obj in ipairs(objs) do
    local ent = obj:get_luaentity()
    if ent and ent.name == "cw_mobs:bee" and ent.make_angry then
      ent:make_angry(player)
    end
  end
end

-------------------------
-- Node behaviour
-------------------------
local function hive_tiles(full)
  local front = full and TEX_FRONT_FULL or TEX_FRONT
  -- top, bottom, right, left, back, front
  return {TEX_TOP, TEX_BOTTOM, TEX_SIDE, TEX_SIDE, TEX_SIDE, front}
end

local function on_construct(pos)
  local data, m = read_meta(pos)
  data.bees = math.random(1, MAX_BEES)
  data.honey = 0
  data.last_exit = 0
  write_meta(pos, data, m)
  core.get_node_timer(pos):start(TICK_SEC)
end

local function after_place_node(pos, placer)
  if not placer then return end
  local look = placer:get_look_dir()
  local facedir = core.dir_to_facedir({x=-look.x, y=0, z=-look.z})
  local node = core.get_node(pos)
  node.param2 = facedir
  core.swap_node(pos, node)
end

local function spawn_bee_from_hive(pos, data, m)
  if data.bees <= 0 then return end

  local gate, dir = cw_mobs.hive_entrance_point(pos)
  if not gate or not dir then return end

  local spawn = {
    x = gate.x + dir.x * 0.3,
    y = gate.y,
    z = gate.z + dir.z * 0.3
  }

  local obj = core.add_entity(spawn, "cw_mobs:bee")
  if not obj then return end

  local ent = obj:get_luaentity()
  if ent and ent.set_home then
    ent:set_home(pos)
  end
  if ent and ent._reset_forage then
    ent:_reset_forage()
  end
  if ent then
    ent._has_nectar = false
    ent._pollen_uses = 0
    ent._state = "leaving_hive"
  end

  data.bees = data.bees - 1
  data.last_exit = now()
  write_meta(pos, data, m)
end

local function on_timer(pos, elapsed)
  local data, m = read_meta(pos)
  local t = now()

  local bad =
    (cw_mobs.is_bad_weather and cw_mobs.is_bad_weather()) or false

  if data.bees > 0 and data.honey < HONEY_MAX and is_day() and not bad then
    if (t - data.last_exit) >= EXIT_COOLDOWN then
      spawn_bee_from_hive(pos, data, m)
    end
  end

  return true
end

local function on_destruct(pos, oldnode, oldmeta, digger)
  if digger and digger:is_player() then
    cw_mobs.anger_bees_from_hive(pos, digger)
  end
end

local function handle_harvest(pos, clicker, itemstack)
  if not (clicker and itemstack) then return false end

  local toolname = itemstack:get_name()
  if toolname ~= "cw_core:bottle_glass" and toolname ~= "cw_core:shears" then
    return false
  end

  local data, m = read_meta(pos)
  if data.honey < HONEY_MAX then
    return false
  end

  local camp = has_campfire_below(pos)

  if toolname == "cw_core:bottle_glass" then
    -- bottle honey
    if not core.is_creative_enabled(clicker:get_player_name()) then
      itemstack:take_item(1)
      clicker:set_wielded_item(itemstack)
    end
    local inv = clicker:get_inventory()
    local leftover = inv:add_item("main", "cw_mobs:bottle_honey")
    if not leftover:is_empty() then
      core.add_item(pos, leftover)
    end
  elseif toolname == "cw_core:shears" then
    -- honeycomb drop
    core.add_item(pos, "cw_mobs:honeycomb 3")
  end

  data.honey = 0
  write_meta(pos, data, m)
  set_hive_node_by_honey(pos, data.honey)

  if not camp then
    cw_mobs.anger_bees_from_hive(pos, clicker)
  end

  return true
end

local function on_rightclick(pos, node, clicker, itemstack)
  if handle_harvest(pos, clicker, itemstack) then
    return itemstack
  end
  return itemstack
end

-------------------------
-- Registration
-------------------------
core.register_node("cw_mobs:beehive", {
  description = "Beehive",
  tiles = hive_tiles(false),
  paramtype2 = "facedir",
  groups = {choppy=2, oddly_breakable_by_hand=2},
  sounds = default and default.node_sound_wood_defaults() or nil,
  on_construct = on_construct,
  after_place_node = after_place_node,
  on_timer = on_timer,
  on_destruct = on_destruct,
  on_rightclick = on_rightclick,
})

core.register_node("cw_mobs:beehive_full", {
  description = "Beehive (Full)",
  tiles = hive_tiles(true),
  paramtype2 = "facedir",
  groups = {choppy=2, oddly_breakable_by_hand=2, not_in_creative_inventory=1},
  drop = "cw_mobs:beehive",
  sounds = default and default.node_sound_wood_defaults() or nil,
  on_construct = on_construct,
  after_place_node = after_place_node,
  on_timer = on_timer,
  on_destruct = on_destruct,
  on_rightclick = on_rightclick,
})

core.register_lbm({
  name = "cw_mobs:beehive_resume",
  nodenames = {"cw_mobs:beehive", "cw_mobs:beehive_full"},
  action = function(pos, node)
    core.get_node_timer(pos):start(TICK_SEC)
  end
})

-- FIX: Mapgen doesn't trigger on_construct. This LBM fixes "dead" wild hives.
minetest.register_lbm({
    name = "cw_mobs:activate_wild_hives",
    nodenames = {"cw_mobs:beehive", "cw_mobs:beehive_full"},
    run_at_every_load = false, -- Only run once per hive
    action = function(pos, node)
        local meta = minetest.get_meta(pos)
        
        -- Check if bees are actually inside; if not, populate it.
        if meta:get_int("bees") == 0 and meta:get_string("initialized") ~= "true" then
            meta:set_int("bees", math.random(1, 3))
            meta:set_int("honey", 0)
            meta:set_string("initialized", "true") -- Mark so we don't overwrite player-placed hives
            
            -- Start the node timer so bees can leave
            minetest.get_node_timer(pos):start(2)
            
            minetest.log("action", "[cw_mobs] Activated wild hive at " .. minetest.pos_to_string(pos))
        end
    end,
})