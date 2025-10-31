-- cw_mobs/nodes/beehive.lua
-- Minecraft-like beehive behavior without requiring the "default" mod.

local HIVE_NAME        = "cw_mobs:beehive"
local HIVE_FULL_NAME   = "cw_mobs:beehive_full"

local MAX_BEES         = 3
local MAX_HONEY        = 5
local RESPAWN_SECONDS  = 120 -- bees stay inside hive ~2 min (MC)

local ITEM_HONEY_BOTTLE   = "cw_mobs:bottle_honey"
local ITEM_HONEYCOMB      = "cw_mobs:honeycomb"
local ITEM_GLASS_BOTTLE   = "cw_core:bottle_glass"
local ITEM_SHEARS         = "cw_core:shears"

local HONEYCOMB_MINMAX = {1, 3}

-- Textures you should provide in textures/
local TEX_FRONT      = "cw_beehive_front.png"
local TEX_FRONT_FULL = "cw_beehive_front_full.png"
local TEX_SIDE       = "cw_beehive_side.png"
local TEX_TOP        = "cw_beehive_top.png"

-- Safe wood sounds (no dependency on 'default')
local function wood_sounds()
  -- If your game defines a global sound helper, use it; otherwise nil is fine.
  if minetest.node_sound_wood_defaults then
    return minetest.node_sound_wood_defaults()
  end
  -- Try to copy sounds from an existing wood node if present
  local wood = minetest.registered_nodes["default:wood"]
  if wood and wood.sounds then
    return wood.sounds
  end
  return nil
end

-- Check for campfire under hive (smoke calms bees)
local function has_campfire_below(pos)
  for dy = 1, 3 do
    local p = {x=pos.x, y=pos.y-dy, z=pos.z}
    local n = minetest.get_node(p).name
    if minetest.get_item_group(n, "campfire") > 0 or n == "cw_core:campfire" then
      return true
    end
  end
  return false
end

-------------------------
-- Hive API (used by bees)
-------------------------

-- Get hive front position + facing direction
function cw_mobs.hive_entrance_point(hpos)
  local node = minetest.get_node(hpos)
  if not node then return nil,nil end
  local dir = minetest.facedir_to_dir(node.param2 or 0)
  local gate = {
    x = hpos.x + dir.x*0.55,
    y = hpos.y + 0.25,
    z = hpos.z + dir.z*0.55
  }
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

local function get_meta_counts(pos)
  local m = minetest.get_meta(pos)
  return m:get_int("honey"), m:get_int("residents")
end

local function set_honey(pos, v)
  local m=minetest.get_meta(pos); m:set_int("honey", v)
  local node=minetest.get_node(pos)
  if v >= MAX_HONEY and node.name ~= HIVE_FULL_NAME then
    minetest.swap_node(pos, {name=HIVE_FULL_NAME, param2=node.param2})
  elseif v < MAX_HONEY and node.name ~= HIVE_NAME then
    minetest.swap_node(pos, {name=HIVE_NAME, param2=node.param2})
  end
end

local function inc_honey(pos, amt)
  local h = minetest.get_meta(pos):get_int("honey")
  h = math.min(MAX_HONEY, h + (amt or 1))
  set_honey(pos, h)
end

-- Bee enters hive (removes entity, optionally adds honey, schedules exit)
function cw_mobs.hive_try_enter(hpos, bee_obj)
  local m = minetest.get_meta(hpos)
  local residents = m:get_int("residents")
  if residents >= MAX_BEES then return false end

  local lua = bee_obj:get_luaentity()
  if lua and lua.has_nectar and lua:has_nectar() then
    inc_honey(hpos, 1)
    if lua.clear_nectar then lua:clear_nectar() end
  end

  m:set_int("residents", residents + 1)
  bee_obj:remove()

  minetest.after(RESPAWN_SECONDS, function()
    if not minetest.get_node_or_nil(hpos) then return end
    local mm = minetest.get_meta(hpos)
    local rr = mm:get_int("residents")
    if rr > 0 then
      mm:set_int("residents", rr-1)
      local gate,dir = cw_mobs.hive_entrance_point(hpos)
      if gate then
        local spawn = {
          x = gate.x + dir.x*0.8,
          y = gate.y,
          z = gate.z + dir.z*0.8
        }
        local obj = minetest.add_entity(spawn, "cw_mobs:bee")
        if obj then
          local e = obj:get_luaentity()
          if e and e.set_home then e:set_home(hpos) end
        end
      end
    end
  end)

  return true
end

-----------------------------------
-- Node definition helper
-----------------------------------
local function register_hive(name, is_full)
  -- Tile order for facedir nodes: {top, bottom, right, left, back, front}
  local tiles = {
    TEX_TOP,               -- top
    TEX_TOP,               -- bottom
    TEX_SIDE,              -- right
    TEX_SIDE,              -- left
    TEX_SIDE,              -- back
    is_full and TEX_FRONT_FULL or TEX_FRONT, -- front
  }

  minetest.register_node(name, {
    description = is_full and "Beehive (Full)" or "Beehive",
    tiles = tiles,
    paramtype2 = "facedir",
    is_ground_content = false,
    groups = {
      choppy=2, oddly_breakable_by_hand=2,
      not_in_creative_inventory = is_full and 1 or 0
    },
    sounds = wood_sounds(),
    drop = HIVE_NAME,
    stack_max = 99,

    on_construct = function(pos)
      local m = minetest.get_meta(pos)
      if m:get_string("init") == "" then
        m:set_string("init", "1")
        m:set_int("honey", is_full and MAX_HONEY or 0)
        m:set_int("residents", 0)
      end

      -- Seed starting bees (they’ll enter immediately, then exit after RESPAWN_SECONDS)
      minetest.after(0.5, function()
        if not minetest.get_node_or_nil(pos) then return end
        local function seed_once(delay)
          minetest.after(delay, function()
            if not minetest.get_node_or_nil(pos) then return end
            local fake = minetest.add_entity({x=pos.x+0.5,y=pos.y+0.5,z=pos.z+0.5}, "cw_mobs:bee")
            if fake then cw_mobs.hive_try_enter(pos, fake) end
          end)
        end
        seed_once(0.0)
        seed_once(1.0)
        seed_once(2.0)
      end)
    end,

    on_rightclick = function(pos, node, clicker, itemstack)
      if not clicker or not clicker:is_player() then return itemstack end
      local name = itemstack:get_name()
      local m = minetest.get_meta(pos)
      local honey = m:get_int("honey")
      local calm = has_campfire_below(pos)

      -- Bottle honey (requires full hive)
      if name == ITEM_GLASS_BOTTLE and honey >= MAX_HONEY then
        itemstack:take_item(1)
        local inv = clicker:get_inventory()
        local hb  = ItemStack(ITEM_HONEY_BOTTLE)
        if inv and inv:room_for_item("main", hb) then inv:add_item("main", hb)
        else minetest.add_item(clicker:get_pos(), hb) end
        set_honey(pos, 0)
        if not calm then
          for _,obj in ipairs(minetest.get_objects_inside_radius(pos, 6)) do
            local e=obj:get_luaentity()
            if e and e.name=="cw_mobs:bee" and e.make_angry then e:make_angry(clicker, 30) end
          end
        end
        return itemstack
      end

      -- Shears for honeycomb (requires full hive)
      if name == ITEM_SHEARS and honey >= MAX_HONEY then
        local cnt = math.random(HONEYCOMB_MINMAX[1], HONEYCOMB_MINMAX[2])
        local comb = ItemStack(ITEM_HONEYCOMB.." "..cnt)
        local inv  = clicker:get_inventory()
        if inv and inv:room_for_item("main", comb) then inv:add_item("main", comb)
        else minetest.add_item(clicker:get_pos(), comb) end
        set_honey(pos, 0)
        if not calm then
          for _,obj in ipairs(minetest.get_objects_inside_radius(pos, 6)) do
            local e=obj:get_luaentity()
            if e and e.name=="cw_mobs:bee" and e.make_angry then e:make_angry(clicker, 30) end
          end
        end
        return itemstack
      end

      return itemstack
    end,

    after_dig_node = function(pos, oldnode, oldmeta, digger)
      -- Anger nearby bees if no campfire smoke
      if has_campfire_below(pos) then return end
      for _,obj in ipairs(minetest.get_objects_inside_radius(pos, 12)) do
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
