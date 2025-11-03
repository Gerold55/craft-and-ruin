-- cw_mobs/nodes/beehive.lua
-- Beehive with autonomous release + always-exit-from-front.

local core = core
cw_mobs = rawget(_G, "cw_mobs") or {}

local HIVE_NAME        = "cw_mobs:beehive"
local HIVE_FULL_NAME   = "cw_mobs:beehive_full"

local MAX_BEES         = 3
local MAX_HONEY        = 5
local RESPAWN_SECONDS  = tonumber(core.settings:get("cw_mobs.hive_respawn_seconds")) or 120
local TICK_SECONDS     = 2.0  -- node timer tick
local CROWD_RADIUS     = 2.5  -- don't emit into a swarm cloud

local ITEM_HONEY_BOTTLE   = "cw_mobs:bottle_honey"
local ITEM_HONEYCOMB      = "cw_mobs:honeycomb"
local ITEM_GLASS_BOTTLE   = "cw_core:bottle_glass"
local ITEM_SHEARS         = "cw_core:shears"

local HONEYCOMB_MINMAX = {1, 3}

-- Textures
local TEX_FRONT      = "cw_beehive_front.png"
local TEX_FRONT_FULL = "cw_beehive_front_full.png"
local TEX_SIDE       = "cw_beehive_side.png"
local TEX_TOP        = "cw_beehive_top.png"

-- Optional weather hook
local function bad_weather()
  return cw_mobs and cw_mobs.is_bad_weather and cw_mobs.is_bad_weather() or false
end
local function is_day()
  local t=core.get_timeofday(); return t>=0.2 and t<=0.8
end

-- Sounds without default dep
local function wood_sounds()
  if core.node_sound_wood_defaults then return core.node_sound_wood_defaults() end
  local wood = core.registered_nodes["default:wood"]
  return wood and wood.sounds or nil
end

local function has_campfire_below(pos)
  for dy = 1, 3 do
    local p = {x=pos.x, y=pos.y-dy, z=pos.z}
    local n = core.get_node(p).name
    if core.get_item_group(n, "campfire") > 0 or n == "cw_core:campfire" then
      return true
    end
  end
  return false
end

-- ===== API used by bees =====

function cw_mobs.hive_entrance_point(hpos)
  local node = core.get_node(hpos)
  local param2 = node and node.param2 or 0
  local dir = core.facedir_to_dir(param2 or 0); dir = dir or {x=0,y=0,z=1}
  local gate = { x = hpos.x + dir.x*0.55, y = hpos.y + 0.25, z = hpos.z + dir.z*0.55 }
  return gate, dir
end

function cw_mobs.hive_front_gate_ok(hpos, bee_pos)
  local gate, dir = cw_mobs.hive_entrance_point(hpos)
  if not gate or not bee_pos then return false end
  local dx, dz = bee_pos.x - gate.x, bee_pos.z - gate.z
  local lateral = math.abs(-dir.z*dx + dir.x*dz)
  local forward = ( dir.x*dx + dir.z*dz)
  local vy = math.abs((bee_pos.y - gate.y))
  return (lateral <= 0.55 and vy <= 0.60 and forward >= -0.25)
end

local function set_honey(pos, v)
  local m=core.get_meta(pos); m:set_int("honey", v)
  local node=core.get_node(pos)
  if v >= MAX_HONEY and node.name ~= HIVE_FULL_NAME then
    core.swap_node(pos, {name=HIVE_FULL_NAME, param2=node.param2})
  elseif v < MAX_HONEY and node.name ~= HIVE_NAME then
    core.swap_node(pos, {name=HIVE_NAME, param2=node.param2})
  end
end

local function inc_honey(pos, amt)
  local m = core.get_meta(pos)
  local h = m:get_int("honey")
  h = math.min(MAX_HONEY, h + (amt or 1))
  set_honey(pos, h)
end

-- Enter hive: record resident, add honey if carrying, schedule next exit time
function cw_mobs.hive_try_enter(hpos, bee_obj)
  local m = core.get_meta(hpos)
  local residents = m:get_int("residents")
  if residents >= MAX_BEES then return false end

  local lua = bee_obj and bee_obj:get_luaentity() or nil
  if lua and lua.has_nectar and lua:has_nectar() then
    inc_honey(hpos, 1)
    if lua.clear_nectar then lua:clear_nectar() end
  end

  m:set_int("residents", residents + 1)
  -- schedule autonomous exit using a timestamp, handled by on_timer
  local next_exit = m:get_int("next_exit")
  local now      = core.get_gametime()
  if next_exit == 0 or next_exit < now then
    m:set_int("next_exit", now + RESPAWN_SECONDS)
  else
    -- stagger exits: +RES/3 sec each resident
    m:set_int("next_exit", next_exit + math.floor(RESPAWN_SECONDS / math.max(1, MAX_BEES)))
  end

  if bee_obj then bee_obj:remove() end
  -- ensure timer is running
  core.get_node_timer(hpos):start(TICK_SECONDS)
  return true
end

-- Debug helper used by /hive_debug
function cw_mobs.debug_hive(pos, playername)
  local m = core.get_meta(pos)
  local honey = m:get_int("honey")
  local res   = m:get_int("residents")
  local next_exit = m:get_int("next_exit")
  local msg = ("Hive %s | Honey=%d/5 | Bees Inside=%d/3 | next_exit=%d")
    :format(core.pos_to_string(pos), honey, res, next_exit)
  if playername then core.chat_send_player(playername, msg) end
  return honey, res
end

-- ===== Node registration =====

local function register_hive(name, is_full)
  -- Tile order: {top, bottom, right, left, back, front}
  local tiles = { TEX_TOP, TEX_TOP, TEX_SIDE, TEX_SIDE, TEX_SIDE, is_full and TEX_FRONT_FULL or TEX_FRONT }

  core.register_node(name, {
    description = is_full and "Beehive (Full)" or "Beehive",
    tiles = tiles,
    paramtype2 = "facedir",
    is_ground_content = false,
    groups = { choppy=2, oddly_breakable_by_hand=2, not_in_creative_inventory = is_full and 1 or 0 },
    sounds = wood_sounds(),
    drop = HIVE_NAME,
    stack_max = 99,

    on_construct = function(pos)
      local m = core.get_meta(pos)
      if m:get_string("init") == "" then
        m:set_string("init", "1")
        m:set_int("honey", is_full and MAX_HONEY or 0)
        m:set_int("residents", 0)
        m:set_int("next_exit", 0)
      end
      core.get_node_timer(pos):start(TICK_SECONDS)

      -- Seed residents once (spawn inside then enter)
      core.after(0.25, function()
        if not core.get_node_or_nil(pos) then return end
        for i=1,MAX_BEES do
          local e = core.add_entity({x=pos.x+0.5,y=pos.y+0.5,z=pos.z+0.5}, "cw_mobs:bee")
          if e then
            if not cw_mobs.hive_try_enter(pos, e) then
              e:remove()
            end
          end
        end
      end)
    end,

    -- Node timer: autonomous release from the FRONT
    on_timer = function(pos, elapsed)
      local m = core.get_meta(pos)
      local res = m:get_int("residents")
      local next_exit = m:get_int("next_exit")
      local now = core.get_gametime()

      -- keep ticking
      local keep = true

      -- release conditions
      if res > 0 and next_exit > 0 and now >= next_exit and is_day() and not bad_weather() then
        -- small anti-crowd check to avoid stacking
        local crowd = 0
        for _,o in ipairs(core.get_objects_inside_radius(pos, CROWD_RADIUS)) do
          local e=o:get_luaentity()
          if e and e.name=="cw_mobs:bee" then crowd = crowd + 1 end
        end
        if crowd <= 6 then
          -- spawn at front gate
          local gate, dir = cw_mobs.hive_entrance_point(pos)
          local spawn = gate and { x=gate.x + dir.x*0.85, y=gate.y, z=gate.z + dir.z*0.85 }
                                or { x=pos.x+0.5, y=pos.y+0.5, z=pos.z+0.5 }
          local o = core.add_entity(spawn, "cw_mobs:bee")
          if o then
            local L = o:get_luaentity()
            if L and L.set_home then L:set_home(pos) end
            o:set_velocity({x=(dir and dir.x or 0)*1.2, y=0.25, z=(dir and dir.z or 0)*1.2})
            if L then L._no_home_until = now + 6; L._state="patrol"; L._path=nil end
            m:set_int("residents", res - 1)
          end
          -- schedule next exit
          m:set_int("next_exit", now + RESPAWN_SECONDS)
        else
          -- try again soon if crowded
          m:set_int("next_exit", now + 5)
        end
      end

      return keep
    end,

    on_rightclick = function(pos, node, clicker, itemstack)
      if not clicker or not clicker:is_player() then return itemstack end
      local name = itemstack:get_name()
      local m = core.get_meta(pos)
      local honey = m:get_int("honey")
      local calm = has_campfire_below(pos)

      -- Bottle honey (only when full)
      if name == ITEM_GLASS_BOTTLE and honey >= MAX_HONEY then
        itemstack:take_item(1)
        local inv = clicker:get_inventory()
        local hb  = ItemStack(ITEM_HONEY_BOTTLE)
        if inv and inv:room_for_item("main", hb) then inv:add_item("main", hb)
        else core.add_item(clicker:get_pos(), hb) end
        set_honey(pos, 0)
        if not calm then
          for _,obj in ipairs(core.get_objects_inside_radius(pos, 6)) do
            local e=obj:get_luaentity()
            if e and e.name=="cw_mobs:bee" and e.make_angry then e:make_angry(clicker, 30) end
          end
        end
        return itemstack
      end

      -- Shears → honeycomb (only when full)
      if name == ITEM_SHEARS and honey >= MAX_HONEY then
        local cnt = math.random(HONEYCOMB_MINMAX[1], HONEYCOMB_MINMAX[2])
        local comb = ItemStack(ITEM_HONEYCOMB.." "..cnt)
        local inv  = clicker:get_inventory()
        if inv and inv:room_for_item("main", comb) then inv:add_item("main", comb)
        else core.add_item(clicker:get_pos(), comb) end
        set_honey(pos, 0)
        if not calm then
          for _,obj in ipairs(core.get_objects_inside_radius(pos, 6)) do
            local e=obj:get_luaentity()
            if e and e.name=="cw_mobs:bee" and e.make_angry then e:make_angry(clicker, 30) end
          end
        end
        return itemstack
      end

      return itemstack
    end,

    after_dig_node = function(pos, oldnode, oldmeta, digger)
      if has_campfire_below(pos) then return end
      for _,obj in ipairs(core.get_objects_inside_radius(pos, 12)) do
        local e=obj:get_luaentity()
        if e and e.name=="cw_mobs:bee" and e.make_angry and digger then
          e:make_angry(digger, 20)
        end
      end
    end,
  })
end

-- Register nodes
register_hive(HIVE_NAME, false)
register_hive(HIVE_FULL_NAME, true)

-- LBM: ensure existing hives get residents + a running timer
core.register_lbm({
  name = "cw_mobs:beehive_self_heal",
  nodenames = {HIVE_NAME, HIVE_FULL_NAME},
  run_at_every_load = true,
  action = function(pos, node)
    local m = core.get_meta(pos)
    if m:get_string("init") == "" then
      m:set_string("init","1")
      m:set_int("honey", (node.name==HIVE_FULL_NAME) and MAX_HONEY or 0)
      m:set_int("residents", 0)
      m:set_int("next_exit", 0)
    end
    core.get_node_timer(pos):start(TICK_SECONDS)
    if m:get_int("residents") <= 0 then
      local e = core.add_entity({x=pos.x+0.5,y=pos.y+0.5,z=pos.z+0.5}, "cw_mobs:bee")
      if e and cw_mobs.hive_try_enter(pos, e) then
        core.log("action", "[cw_mobs] LBM seeded a bee into hive @ "..core.pos_to_string(pos))
      end
    end
  end
})
