-- Beehive & Apiary: front-only entrance, honey 0..5, harvest resets to 0,
-- bees return at night/rain, must stay inside >= 120s, occupants persist with data.

local function numset(k,d)
  local v=minetest.settings:get(k); v=(v=="" and nil) or v; return tonumber(v) or d
end

-- Honey
local MAX_HONEY = 5
local HONEY_TICK_MIN = numset("cw_mobs.honey_tick_min", 30)
local HONEY_TICK_VAR = numset("cw_mobs.honey_tick_var", 10)

-- Occupants
local MIN_STAY_SEC = 120 -- 2 minutes
local MAX_OUTSIDE_NEAR = numset("cw_mobs.hive_outside_cap", 10)
local RELEASE_PER_TICK = numset("cw_mobs.hive_release_per_tick", 2)
local OUTSIDE_RADIUS = numset("cw_mobs.hive_outside_cap_radius", 10)

-- Initial counts
local HIVE_INITIAL_OCC = numset("cw_mobs.hive_initial_occupants", 3)
local APIARY_INITIAL_OCC= numset("cw_mobs.apiary_initial_occupants", 3)

-- Textures
local TEX_HIVE_TOP = "cw_beehive_top.png"
local TEX_HIVE_BOTTOM = "cw_beehive_bottom.png"
local TEX_HIVE_SIDE = "cw_beehive_side.png"
local TEX_HIVE_FRONT = "cw_beehive_front.png"
local TEX_HIVE_FRONT_F = "cw_beehive_front_full.png"

local TEX_API_TOP = "cw_apiary_top.png"
local TEX_API_BOTTOM = "cw_apiary_bottom.png"
local TEX_API_SIDE = "cw_apiary_side.png"
local TEX_API_FRONT = "cw_apiary_front.png"
local TEX_API_FRONT_F = "cw_apiary_front_full.png"

-- Helpers
local function now() return minetest.get_gametime() end
local function is_day() local t=minetest.get_timeofday(); return t>=0.2 and t<=0.8 end
local function rand_tick() return HONEY_TICK_MIN + math.random(0, HONEY_TICK_VAR) end
local function is_log(nm) return minetest.get_item_group(nm,"tree")>0 or minetest.get_item_group(nm,"log")>0 end
local function is_leaves(nm) return minetest.get_item_group(nm,"leaves")>0 end

local function hive_entrance_point(pos)
  local n = minetest.get_node(pos)
  local dir = minetest.facedir_to_dir(n.param2 or 0)
  return {x=pos.x+dir.x*0.55,y=pos.y+0.25,z=pos.z+dir.z*0.55}, dir
end

-- LOS to entrance
local function clear_line_to_entrance(bee_pos, entp)
  local ray = minetest.raycast(bee_pos, entp, false, true)
  for hit in ray do
    if hit and hit.type=="node" then
      local nd = minetest.registered_nodes[minetest.get_node(hit.under).name]
      if nd and nd.walkable then return false end
    end
  end
  return true
end

-- Strict front-only check used by bees (global so entity can call)
cw_mobs = rawget(_G, "cw_mobs") or {}
function cw_mobs.hive_front_gate_ok(hive_pos, bee_pos)
  local entp, dir = hive_entrance_point(hive_pos)
  if not entp then return false end
  local face = {x=hive_pos.x+0.5,y=entp.y,z=hive_pos.z+0.5}
  local rel = {x=bee_pos.x-face.x, y=bee_pos.y-entp.y, z=bee_pos.z-face.z}
  local len = math.sqrt(dir.x*dir.x+dir.z*dir.z); if len==0 then return false end
  local fwd = {x=dir.x/len, y=0, z=dir.z/len}
  local dot = rel.x*fwd.x + rel.z*fwd.z
  if dot < 0 then return false end
  local px = rel.x - fwd.x*dot; local pz = rel.z - fwd.z*dot
  local lateral = math.sqrt(px*px+pz*pz)
  if lateral > 0.38 then return false end
  if math.abs(rel.y) > 0.40 then return false end
  if not clear_line_to_entrance(bee_pos, entp) then return false end
  return true
end

-- ======== Occupant queue in meta: persist bee data & stay timing =========
local function load_occ(meta)
  local raw = meta:get_string("bee_store")
  if raw=="" then return {} end
  local ok,t = pcall(minetest.deserialize, raw)
  return (ok and type(t)=="table") and t or {}
end
local function save_occ(meta, t)
  meta:set_string("bee_store", minetest.serialize(t or {}))
  meta:set_int("occ", #(t or {})) -- legacy UI field
end
local function enqueue_bee(meta, rec)
  local q = load_occ(meta); q[#q+1] = rec; save_occ(meta, q)
end
local function dequeue_releasable(meta, nmax)
  local q = load_occ(meta)
  local out, keep = {}, {}
  local cutoff = now() - MIN_STAY_SEC
  for _,rec in ipairs(q) do
    if #out < nmax and (rec.enter_time or 0) <= cutoff then
      out[#out+1] = rec
    else
      keep[#keep+1] = rec
    end
  end
  save_occ(meta, keep)
  return out
end

-- Public API for bees to enter (adds honey + stores bee)
function cw_mobs.hive_try_enter(hive_pos, bee_obj)
  if not hive_pos or not bee_obj then return false end
  local nm = minetest.get_node(hive_pos).name
  if nm ~= "cw_mobs:beehive" and nm ~= "cw_mobs:beehive_full"
     and nm ~= "cw_mobs:apiary" and nm ~= "cw_mobs:apiary_full" then
    return false
  end
  local meta = minetest.get_meta(hive_pos)
  local ent = bee_obj:get_luaentity()

  -- +1 honey if the bee has nectar/pollen (cap 5) and clear bee flag
  if ent and ent.has_nectar and ent:has_nectar() then
    local h = meta:get_int("honey"); if h < MAX_HONEY then h = h + 1 end
    meta:set_int("honey", h)
    if ent.clear_nectar then ent:clear_nectar() end
    if h >= MAX_HONEY then
      local n = minetest.get_node(hive_pos)
      local full = nm:find("apiary") and "cw_mobs:apiary_full" or "cw_mobs:beehive_full"
      minetest.swap_node(hive_pos, {name=full, param2=n.param2})
    end
  end

  -- Store bee data; remove entity
  local hp = 3; pcall(function() hp = bee_obj:get_hp() end)
  local nametag = ""; pcall(function()
    local a = bee_obj:get_nametag_attributes(); nametag = (a and a.text) or ""
  end)
  local flags = {}
  if ent then
    flags._stings_done = ent._stings_done or 0
    flags._pollen_left = ent._pollen_left or 0
  end
  enqueue_bee(meta, {enter_time=now(), hp=hp, nametag=nametag, flags=flags})
  bee_obj:remove()
  return true
end

-- Spawn helper (front)
local function spawn_from_front(pos, rec)
  local entp, dir = hive_entrance_point(pos)
  local spawn = {x=entp.x+dir.x*0.18, y=entp.y, z=entp.z+dir.z*0.18}
  local ok,obj = pcall(minetest.add_entity, spawn, "cw_mobs:bee")
  if ok and obj then
    local ent = obj:get_luaentity()
    if ent and ent.set_home then ent:set_home({x=pos.x,y=pos.y,z=pos.z}) end
    if rec then
      if rec.nametag and rec.nametag~="" then
        pcall(obj.set_nametag_attributes, obj, {text=rec.nametag})
      end
      if rec.hp then pcall(obj.set_hp, obj, rec.hp) end
      if rec.flags and ent then for k,v in pairs(rec.flags) do ent[k]=v end end
    end
    obj:set_velocity({x=dir.x*1.2, y=0.05, z=dir.z*1.2})
    obj:set_yaw(math.atan2(-dir.x, dir.z))
  end
end

-- Release logic used by both empty/full nodes
local function hive_on_timer(pos, node, initial_occ_if_new)
  local meta = minetest.get_meta(pos)

  -- First-time construct might seed queue
  if meta:get_string("seeded") ~= "1" then
    save_occ(meta, {})
    for i=1,(initial_occ_if_new or 0) do
      enqueue_bee(meta, {enter_time=now(), hp=3, nametag="", flags={}})
    end
    meta:set_string("seeded","1")
  end

  -- Daytime + not bad weather → release some, respecting outside cap and min-stay
  if is_day() and not cw_mobs.is_bad_weather() then
    local outside = cw_mobs.util.count_named(pos, OUTSIDE_RADIUS, "cw_mobs:bee")
    local room = math.max(0, MAX_OUTSIDE_NEAR - outside)
    local want = math.min(RELEASE_PER_TICK, room)
    if want > 0 then
      for _,rec in ipairs(dequeue_releasable(meta, want)) do
        spawn_from_front(pos, rec)
      end
    end
  end

  minetest.get_node_timer(pos):start(rand_tick())
  return true
end

-- Bottle helpers (uses your cw_core:bottle_glass and outputs cw_mobs:bottle_honey)
local function player_has_bottle(player)
  local inv = player:get_inventory()
  if inv:contains_item("main","cw_core:bottle_glass") then return "cw_core:bottle_glass" end
  return nil
end
local function take_one_bottle(player, name)
  if not name then return false end
  local inv = player:get_inventory()
  return not inv:remove_item("main", ItemStack(name)):is_empty()
end
local function give_honey_bottle(player)
  local inv = player:get_inventory()
  local leftover = inv:add_item("main", "cw_mobs:bottle_honey")
  if not leftover:is_empty() then
    local p = player:get_pos(); if p then p.y = p.y + 1 end
    minetest.add_item(p, leftover)
  end
end

-- Register pair helper
local function register_hive_pair(base, desc, tex_top, tex_bottom, tex_side, tex_front_empty, tex_front_full, initial_occ)
  -- empty
  minetest.register_node(base, {
    description = desc,
    tiles = {tex_top, tex_bottom, tex_side, tex_side, tex_side, tex_front_empty},
    paramtype2="facedir",
    groups={choppy=2, oddly_breakable_by_hand=2},
    sounds = default and default.node_sound_wood_defaults() or nil,

    on_construct = function(pos)
      local meta = minetest.get_meta(pos)
      meta:set_int("honey", meta:get_int("honey") or 0)
      meta:set_string("seeded","")
      minetest.get_node_timer(pos):start(rand_tick())
    end,

    on_rightclick = function(pos, node, clicker, itemstack)
      local meta = minetest.get_meta(pos)
      if meta:get_int("honey") < MAX_HONEY then return itemstack end
      local bottle = player_has_bottle(clicker)
      if not bottle then
        minetest.chat_send_player(clicker:get_player_name(), "You need a glass bottle.")
        return itemstack
      end
      if take_one_bottle(clicker, bottle) then
        give_honey_bottle(clicker)
        meta:set_int("honey", 0)
        -- already empty texture; keep node as is
      end
      return itemstack
    end,

    on_timer = function(pos, elapsed) return hive_on_timer(pos, minetest.get_node(pos), initial_occ) end,

    after_dig_node = function(pos, oldnode, oldmeta, digger)
      -- Release & anger bees on breaking a natural hive/apiary
      local occ = 0
      if oldmeta and oldmeta.fields and oldmeta.fields.bee_store then
        local ok, q = pcall(minetest.deserialize, oldmeta.fields.bee_store)
        if ok and type(q)=="table" then
          for _,rec in ipairs(q) do
            spawn_from_front(pos, rec)
          end
        end
      end
      -- Nearby bees aggro breaker
      if digger and digger:is_player() then
        for _,o in ipairs(minetest.get_objects_inside_radius(pos, 16)) do
          local e = o:get_luaentity()
          if e and e.name=="cw_mobs:bee" and e.make_angry then e:make_angry(digger, 25) end
        end
      end
    end,
  })

  -- full
  minetest.register_node(base.."_full", {
    description = desc.." (Full)",
    tiles = {tex_top, tex_bottom, tex_side, tex_side, tex_side, tex_front_full},
    paramtype2="facedir",
    groups={choppy=2, oddly_breakable_by_hand=2, not_in_creative_inventory=1},
    drop = base,
    sounds = default and default.node_sound_wood_defaults() or nil,

    on_construct = function(pos)
      local meta = minetest.get_meta(pos)
      if meta:get_int("honey") < MAX_HONEY then meta:set_int("honey", MAX_HONEY) end
      meta:set_string("seeded","")
      minetest.get_node_timer(pos):start(rand_tick())
    end,

    on_rightclick = function(pos, node, clicker, itemstack)
      local meta = minetest.get_meta(pos)
      if meta:get_int("honey") < MAX_HONEY then return itemstack end
      local bottle = player_has_bottle(clicker)
      if not bottle then
        minetest.chat_send_player(clicker:get_player_name(), "You need a glass bottle.")
        return itemstack
      end
      if take_one_bottle(clicker, bottle) then
        give_honey_bottle(clicker)
        meta:set_int("honey", 0)
        minetest.swap_node(pos, {name=base, param2=node.param2})
      end
      return itemstack
    end,

    on_timer = function(pos, elapsed) return hive_on_timer(pos, minetest.get_node(pos), initial_occ) end,

    after_dig_node = function(pos, oldnode, oldmeta, digger)
      -- Same anger behavior as empty
      if oldmeta and oldmeta.fields and oldmeta.fields.bee_store then
        local ok, q = pcall(minetest.deserialize, oldmeta.fields.bee_store)
        if ok and type(q)=="table" then
          for _,rec in ipairs(q) do spawn_from_front(pos, rec) end
        end
      end
      if digger and digger:is_player() then
        for _,o in ipairs(minetest.get_objects_inside_radius(pos, 16)) do
          local e = o:get_luaentity()
          if e and e.name=="cw_mobs:bee" and e.make_angry then e:make_angry(digger, 25) end
        end
      end
    end,
  })
end

register_hive_pair("cw_mobs:beehive","Beehive",
  TEX_HIVE_TOP, TEX_HIVE_BOTTOM, TEX_HIVE_SIDE, TEX_HIVE_FRONT, TEX_HIVE_FRONT_F, HIVE_INITIAL_OCC)

register_hive_pair("cw_mobs:apiary","Apiary",
  TEX_API_TOP, TEX_API_BOTTOM, TEX_API_SIDE, TEX_API_FRONT, TEX_API_FRONT_F, APIARY_INITIAL_OCC)