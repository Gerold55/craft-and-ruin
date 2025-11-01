-- cw_mobs/mobs/passive_bee.lua
-- Minecraft-like bee with lightweight pathfinding and robust flower seeking.
-- Anim ranges: fly 1..20, attack 21..41.
-- Flowers are any nodes in group:flower (no registry). Fallback list supported.
-- Crops to pollinate are matched by groups in cw_mobs.pollinate_plant (see bottom).

--------------------------- Settings / Utils ----------------------------------
cw_mobs = rawget(_G, "cw_mobs") or {}

local function numset(k,d) local v=minetest.settings:get(k); v=(v=="" and nil) or v; return tonumber(v) or d end
local function now() return minetest.get_gametime() end
local function mix(a,b,t) return a + (b-a)*t end
local function clamp(v,a,b) return math.max(a, math.min(b, v)) end
local function is_day() local t=minetest.get_timeofday(); return t>=0.2 and t<=0.8 end
local function bad_weather() return cw_mobs and cw_mobs.is_bad_weather and cw_mobs.is_bad_weather() or false end

-- Animation
local FPS            = numset("cw_mobs.bee_anim_fps", 20)
local FLY_F1,FLY_F2  = 1, 20
local ATK_F1,ATK_F2  = 21, 41

-- Movement
local SPD_PATROL   = 2.2
local SPD_SEEK     = 2.6
local SPD_RETURN   = 3.0
local STEER_LERP   = 0.16
local BOB_FREQ     = 3.0
local BOB_AMP      = 0.22
local MAX_TURN_RATE    = 0.28
local ARRIVE_SLOW_DIST = 1.2
local YAW_EPS      = 0.015

-- Altitude + leash
local LEASH_R       = numset("cw_mobs.bee_leash_r", 22)
local ALT_RANGE_MIN = 0.9
local ALT_RANGE_MAX = 2.1
local ALT_HOVER     = 1.3

-- Anti-jitter nav
local AIM_LERP         = 0.24
local LOS_BAD_GRACE    = 0.25
local AVOID_DECAY      = 0.88
local AVOID_GAIN       = 0.42
local SIDE_PROBE_DIST  = 0.9
local AHEAD_PROBE_DIST = 1.2

-- Separation
local SEP_RADIUS = 0.8
local SEP_PUSH   = 0.18

-- Foraging & pollen (MC-like)
local FORAGE_R                 = numset("cw_mobs.bee_forage_r", 14)
local FORAGE_DWELL_MIN         = 2.0
local FORAGE_DWELL_MAX         = 5.0
local POLLEN_CHARGES           = 10
local POLLEN_FERTILIZE_CHANCE  = 0.01

-- Combat / anger (MC: dies after one sting)
local STING_RANGE     = 1.2
local STING_COOLDOWN  = 1.6
local STING_DAMAGE    = numset("cw_mobs.bee_sting_damage", 2)
local AGGRO_SECONDS   = numset("cw_mobs.bee_aggro_seconds", 20)
local STINGS_TO_DIE   = 1

-- Pathfinding (lightweight)
local PATH_RING_RADII    = {1.6, 2.4, 3.2}
local PATH_ANGLES        = {0,45,90,135,180,225,270,315}
local PATH_REPLAN_COOLD  = 0.6
local REACH_WAYPOINT     = 0.6

-- Flower targeting / reselection
local SEEK_TIMEOUT_SEC       = 6.0    -- give up and re-pick if we can't reach in this time
local FLOWER_RESELECT_COOLD  = 1.0    -- small cool-down before picking again
local SEARCH_BEE_FIRST       = true   -- look near the bee, then near the hive
local FLOWER_NAMES_FALLBACK  = { "cw_core:daisy", "cw_core:bluebell" } -- add more if needed

------------------------ Shared helpers / APIs --------------------------------
local function hive_entrance_point(pos)
  return cw_mobs.hive_entrance_point and cw_mobs.hive_entrance_point(pos) or nil, nil
end
local function hive_front_gate_ok(hive_pos, bee_pos)
  return cw_mobs.hive_front_gate_ok and cw_mobs.hive_front_gate_ok(hive_pos, bee_pos) or false
end
local function hive_try_enter(hive_pos, bee_obj)
  return cw_mobs.hive_try_enter and cw_mobs.hive_try_enter(hive_pos, bee_obj) or false
end

-- Flowers = any node with group:flower, OR fallback explicit names if group missing.
local function is_flower_node_at(p)
  local n = minetest.get_node_or_nil(p); if not n then return false end
  if minetest.get_item_group(n.name, "flower") > 0 then return true end
  for _,name in ipairs(FLOWER_NAMES_FALLBACK) do
    if n.name == name then return true end
  end
  return false
end

local function find_flowers_in_area(minp, maxp)
  local list = {}
  -- Primary: group:flower
  local g = minetest.find_nodes_in_area(minp, maxp, {"group:flower"})
  for _,p in ipairs(g or {}) do list[#list+1] = p end
  -- Fallback: explicit names (handles missing groups)
  for _,name in ipairs(FLOWER_NAMES_FALLBACK) do
    local f = minetest.find_nodes_in_area(minp, maxp, {name})
    for _,p in ipairs(f or {}) do list[#list+1] = p end
  end
  return list
end

local function pick_flower_near(center, r)
  local minp = {x=center.x-r, y=center.y-2, z=center.z-r}
  local maxp = {x=center.x+r, y=center.y+2, z=center.z+r}
  local candidates = find_flowers_in_area(minp, maxp)
  if #candidates == 0 then return nil end

  -- Prefer line-of-sight and closer targets
  local eye = {x=center.x, y=center.y+0.8, z=center.z}
  local best, best_score = nil, -1e18
  for _,p in ipairs(candidates) do
    local aim = {x=p.x+0.5, y=p.y+0.5, z=p.z+0.5}
    local los_ok = true
    for hit in minetest.raycast(eye, aim, false, true) do
      if hit.type=="node" then
        local def = minetest.registered_nodes[minetest.get_node(hit.under).name]
        if def and def.walkable then los_ok=false; break end
      end
    end
    local d = vector.distance(center, aim)
    local score = (los_ok and 1000 or 0) - d  -- LOS wins; nearer is better
    if score > best_score then best_score = score; best = p end
  end
  return best
end

----------------------------- World helpers -----------------------------------
local function ground_y_below(p, scan)
  scan = scan or 16
  local pos = {x=math.floor(p.x+0.5), y=math.floor(p.y+0.5), z=math.floor(p.z+0.5)}
  for dy=0,scan do
    local below = {x=pos.x, y=pos.y - dy, z=pos.z}
    local def = minetest.registered_nodes[minetest.get_node(below).name]
    if def and def.walkable then return below.y end
  end
  return pos.y - scan
end

local function is_liquid_at(p)
  local n = minetest.get_node_or_nil(p); if not n then return false end
  local def = minetest.registered_nodes[n.name]; return def and def.liquidtype and def.liquidtype ~= "none"
end

local function build_hover_target(flower_pos, home_pos)
  if not flower_pos then return nil end
  local gy = ground_y_below(flower_pos, 6) or (flower_pos.y - 1)
  local min_y = gy + ALT_HOVER
  local max_y = (home_pos and (home_pos.y + ALT_RANGE_MAX)) or (flower_pos.y + 2.0)
  local y = math.max(min_y, math.min(flower_pos.y + 0.7, max_y))
  return { x = flower_pos.x + 0.5, y = y, z = flower_pos.z + 0.5 }
end

local function yaw_from_hdir(hdir) return math.atan2(-hdir.x, hdir.z) end
local function deg2rad(d) return d * math.pi / 180 end

--------------------------- Lightweight pathfinder ----------------------------
local function los_clear(a, b)
  local ray = minetest.raycast(a, b, false, true)
  for hit in ray do
    if hit and hit.type=="node" then
      local nd = minetest.registered_nodes[minetest.get_node(hit.under).name]
      if nd and nd.walkable then return false end
    end
  end
  return true
end

local function sample_ring(from, to, radius)
  local best, best_score = nil, -1e9
  for _,deg in ipairs(PATH_ANGLES) do
    local a = deg2rad(deg)
    local p = { x = from.x + math.cos(a)*radius, y = from.y, z = from.z + math.sin(a)*radius }
    local dir = vector.direction(from, to)
    local score_dir = vector.dot({x=math.cos(a), y=0, z=math.sin(a)}, {x=dir.x, y=0, z=dir.z})
    if los_clear({x=from.x,y=from.y+0.2,z=from.z}, {x=p.x,y=p.y+0.2,z=p.z}) then
      local los2 = los_clear({x=p.x,y=p.y+0.2,z=p.z}, {x=to.x,y=to.y+0.2,z=to.z})
      local score = score_dir + (los2 and 0.5 or 0.0) - (vector.distance(p, to) * 0.02)
      if score > best_score then best_score = score; best = p end
    end
  end
  return best
end

local function compute_path(from, to)
  if los_clear({x=from.x,y=from.y+0.2,z=from.z}, {x=to.x,y=to.y+0.2,z=to.z}) then
    return {vector.new(to)}
  end
  for _,r in ipairs(PATH_RING_RADII) do
    local w1 = sample_ring(from, to, r)
    if w1 and los_clear({x=w1.x,y=w1.y+0.2,z=w1.z}, {x=to.x,y=to.y+0.2,z=to.z}) then
      return {w1, vector.new(to)}
    end
  end
  for _,r1 in ipairs(PATH_RING_RADII) do
    local w1 = sample_ring(from, to, r1)
    if w1 then
      for _,r2 in ipairs(PATH_RING_RADII) do
        local w2 = sample_ring(w1, to, r2)
        if w2 and los_clear({x=w2.x,y=w2.y+0.2,z=w2.z}, {x=to.x,y=to.y+0.2,z=to.z}) then
          return {w1, w2, vector.new(to)}
        end
      end
    end
  end
  return {vector.new(to)}
end

------------------------------ Entity -----------------------------------------
local function try_pollinate_under(self) end

minetest.register_entity("cw_mobs:bee", {
  initial_properties = {
    visual="mesh", mesh="bee.glb", textures={"bee.png"},
    visual_size={x=6,y=6},
    collisionbox={-0.25,-0.20,-0.25, 0.25,0.25,0.25},
    physical=false, collide_with_objects=false, pointable=true,
    static_save=true, glow=0, nametag="",
    makes_footstep_sound=false, damage_texture_modifier="^[brighten",
    hp_max=3,
  },

  _t=0, _anim="fly",
  _state="patrol",            -- patrol | seek_flower | hover | return | angry
  _home=nil, _min_alt=nil, _max_alt=nil,
  _flower=nil, _forage_until=0, _seek_deadline=nil, _next_pick_after=nil,
  _has_nectar=false, _pollen_left=0,
  _heading={x=0,z=1}, _aim_last=nil, _avoid={x=0,z=0}, _los_bad_until=0,
  _dodge_side=0,
  _target_obj=nil, _aggro_til=0, _sting_cd=0, _stings_done=0,

  _path=nil, _path_replan_t=0,

  get_staticdata = function(self)
    return minetest.serialize({home=self._home, nectar=self._has_nectar, pollen=self._pollen_left})
  end,

  on_activate = function(self, staticdata)
    if staticdata and staticdata~="" then
      local ok,d = pcall(minetest.deserialize, staticdata)
      if ok and type(d)=="table" then
        self._home = d.home; self._has_nectar = d.nectar or false; self._pollen_left = d.pollen or 0
      end
    end
    self.object:set_animation({x=FLY_F1,y=FLY_F2}, FPS, 0, true)
  end,

  set_home = function(self, hive_pos)
    self._home = vector.new(hive_pos)
    local gy = ground_y_below({x=hive_pos.x,y=hive_pos.y+2,z=hive_pos.z}, 8)
    self._min_alt = (gy or hive_pos.y) + ALT_RANGE_MIN
    self._max_alt = hive_pos.y + ALT_RANGE_MAX
  end,

  has_nectar   = function(self) return self._has_nectar end,
  clear_nectar = function(self) self._has_nectar=false; self._pollen_left=0 end,

  make_angry = function(self, target_player, extra_secs)
    if not (target_player and target_player.is_player and target_player:is_player()) then return end
    self._state="angry"
    self._target_obj = target_player
    self._aggro_til = now() + (extra_secs or AGGRO_SECONDS)
    self.object:set_animation({x=ATK_F1,y=ATK_F2}, FPS, 0, true); self._anim="attack"
  end,

  on_punch = function(self, hitter)
    if hitter and hitter:is_player() then self:make_angry(hitter, AGGRO_SECONDS) end
    return true
  end,

  _separate = function(self, pos)
    local objs = minetest.get_objects_inside_radius(pos, SEP_RADIUS)
    local push={x=0,y=0,z=0}; local n=0
    for _,o in ipairs(objs) do
      if o~=self.object then
        local e=o:get_luaentity()
        if e and e.name=="cw_mobs:bee" then
          local p2=o:get_pos(); if p2 then push=vector.add(push, vector.direction(p2,pos)); n=n+1 end
        end
      end
    end
    if n>0 then return vector.multiply(vector.normalize(push), SEP_PUSH) end
    return nil
  end,

  _follow_path_or_goto = function(self, dtime, target, speed)
    local obj=self.object; local pos=obj:get_pos(); if not pos then return end
    local function need_replan()
      return (not self._path or #self._path==0 or now() >= (self._path_replan_t or 0))
    end
    if need_replan() then
      self._path = compute_path({x=pos.x,y=pos.y,z=pos.z}, target)
      self._path_replan_t = now() + PATH_REPLAN_COOLD
    end
    local wp = self._path[1] or target
    local reached = self:_goto(dtime, wp, speed)
    if reached then
      table.remove(self._path, 1)
      if (not self._path) or #self._path==0 then return true end
    end
    return false
  end,

  _goto = function(self, dtime, target, speed)
    local obj=self.object; local pos=obj:get_pos(); if not pos then return end
    local vel=obj:get_velocity() or {x=0,y=0,z=0}
    if is_liquid_at(pos) then vel.y = math.max(vel.y, 0.5) end
    local gy_now = ground_y_below(pos, 16)
    if pos.y < gy_now + 0.2 then
      obj:set_pos({x=pos.x, y=gy_now + 0.25, z=pos.z})
      pos=obj:get_pos(); vel.y=math.max(vel.y,0.2)
    end

    if not self._aim_last then
      self._aim_last = vector.new(target)
    else
      self._aim_last.x = self._aim_last.x + (target.x - self._aim_last.x) * AIM_LERP
      self._aim_last.y = self._aim_last.y + (target.y - self._aim_last.y) * AIM_LERP
      self._aim_last.z = self._aim_last.z + (target.z - self._aim_last.z) * AIM_LERP
    end
    local aim = self._aim_last

    local bob = math.sin(self._t*BOB_FREQ)*BOB_AMP
    if self._min_alt and pos.y < self._min_alt then
      vel.y = mix(vel.y, math.max(0.6, speed*0.4), 0.30)
    elseif self._max_alt and pos.y > self._max_alt then
      vel.y = mix(vel.y, -math.max(0.6, speed*0.4), 0.30)
    else
      vel.y = mix(vel.y, bob, 0.20)
    end

    local dir_to = vector.direction(pos, aim)
    local base_hx, base_hz = dir_to.x, dir_to.z
    local len = math.sqrt(base_hx*base_hx + base_hz*base_hz)
    if len < 1e-6 then
      base_hx, base_hz = 0, 1
    else
      base_hx, base_hz = base_hx/len, base_hz/len  -- ✅ fixed normalization
    end

    local eye = {x=pos.x, y=pos.y+0.2, z=pos.z}
    local los_ok = true
    do
      local ray = minetest.raycast(eye, aim, false, true)
      for hit in ray do
        if hit and hit.type=="node" then
          local nd = minetest.registered_nodes[minetest.get_node(hit.under).name]
          if nd and nd.walkable then los_ok = false; break end
        end
      end
    end
    local nowt = now()
    if not los_ok then self._los_bad_until = math.max(self._los_bad_until, nowt + LOS_BAD_GRACE) end
    local los_bad = (self._los_bad_until or 0) > nowt

    local avoid_x, avoid_z = 0, 0
    if los_bad then
      local side = self._dodge_side
      if side == 0 then side = (math.random()<0.5) and -1 or 1; self._dodge_side = side end
      local side_vec = { x =  base_hz * side, z = -base_hx * side }
      local probe_side = { x = eye.x + side_vec.x * SIDE_PROBE_DIST, y = eye.y, z = eye.z + side_vec.z * SIDE_PROBE_DIST }
      local probe_ahead= { x = eye.x + base_hx * AHEAD_PROBE_DIST, y = eye.y, z = eye.z + base_hz * AHEAD_PROBE_DIST }
      local function blocked(dst)
        local ray = minetest.raycast(eye, dst, false, true)
        for h in ray do
          if h and h.type=="node" then
            local nd = minetest.registered_nodes[minetest.get_node(h.under).name]
            if nd and nd.walkable then return true end
          end
        end; return false
      end
      if blocked(probe_side) or blocked(probe_ahead) then
        avoid_x = side_vec.x * AVOID_GAIN + base_hx * 0.10
        avoid_z = side_vec.z * AVOID_GAIN + base_hz * 0.10
      end
    else
      self._dodge_side = 0
    end

    local sep = self:_separate(pos)
    if sep then
      local sh = math.sqrt(sep.x*sep.x + sep.z*sep.z)
      if sh>1e-6 then
        avoid_x = avoid_x + (sep.x/sh)*0.25
        avoid_z = avoid_z + (sep.z/sh)*0.25
      end
    end

    self._avoid.x = self._avoid.x * AVOID_DECAY + avoid_x * (1.0 - AVOID_DECAY)
    self._avoid.z = self._avoid.z * AVOID_DECAY + avoid_z * (1.0 - AVOID_DECAY)

    local steer_x = base_hx + self._avoid.x
    local steer_z = base_hz + self._avoid.z
    local s_len = math.sqrt(steer_x*steer_x + steer_z*steer_z)
    if s_len >= 1e-6 then
      steer_x, steer_z = steer_x/s_len, steer_z/s_len
    else
      steer_x, steer_z = base_hx, base_hz
    end

    local cur = self._heading or {x=0,z=1}
    local blended = {
      x = cur.x + clamp(steer_x - cur.x, -MAX_TURN_RATE, MAX_TURN_RATE),
      z = cur.z + clamp(steer_z - cur.z, -MAX_TURN_RATE, MAX_TURN_RATE),
    }
    local b_len = math.sqrt(blended.x*blended.x + blended.z*blended.z)
    if b_len > 1e-6 then blended.x, blended.z = blended.x/b_len, blended.z/b_len end
    self._heading = blended

    local yaw = yaw_from_hdir(self._heading)
    local cur_yaw = obj:get_yaw() or 0
    if math.abs(cur_yaw - yaw) > YAW_EPS then obj:set_yaw(yaw) end

    local dist = vector.distance(pos, aim)
    local slow = (dist < ARRIVE_SLOW_DIST) and (dist / ARRIVE_SLOW_DIST) or 1.0
    local fwd  = (speed * slow)
    local want = { x = self._heading.x * fwd, y = vel.y, z = self._heading.z * fwd }
    obj:set_velocity({ x = mix(vel.x, want.x, STEER_LERP), y = want.y, z = mix(vel.z, want.z, STEER_LERP) })

    return dist <= REACH_WAYPOINT
  end,

  _try_sting = function(self, player)
    if self._sting_cd>0 or not player or not player:is_player() then return end
    local myp=self.object:get_pos(); local pp=player:get_pos()
    if not (myp and pp) then return end
    if vector.distance(myp,pp) > STING_RANGE then return end
    local dir = vector.direction(myp,pp)
    player:punch(self.object, 0.5, {full_punch_interval=1.0, damage_groups={fleshy=STING_DAMAGE}}, dir)
    self._stings_done = (self._stings_done or 0) + 1
    self._sting_cd = STING_COOLDOWN
    self.object:set_velocity({x=-dir.x*0.5,y=0.1,z=-dir.z*0.5})
    if self._stings_done >= STINGS_TO_DIE then self.object:remove() end
  end,

  on_step = function(self, dtime)
    self._t = self._t + dtime
    if self._sting_cd>0 then self._sting_cd = self._sting_cd - dtime end

    local obj=self.object; local pos=obj:get_pos(); if not pos then return end

    if not self._home then
      local yaw=math.random()*math.pi*2; local r=2+math.random()*4
      local tgt = {x=pos.x+math.cos(yaw)*r, y=pos.y+0.2, z=pos.z+math.sin(yaw)*r}
      self:_follow_path_or_goto(dtime, tgt, SPD_PATROL); return
    end

    if vector.distance(pos, self._home) > LEASH_R then
      self._state="return"; self._flower=nil; self._path=nil
    end

    if self._state=="angry" then
      if (not self._target_obj) or (not self._target_obj:is_player()) or now()>self._aggro_til then
        self._state="patrol"; self._target_obj=nil
      else
        local ppos = self._target_obj:get_pos()
        if ppos then
          self:_follow_path_or_goto(dtime, {x=ppos.x,y=ppos.y+0.9,z=ppos.z}, SPD_RETURN)
          self:_try_sting(self._target_obj)
          return
        end
      end
    end

    local must_go_home = (not is_day()) or bad_weather()
    if must_go_home and self._state~="return" then self._state="return"; self._flower=nil; self._path=nil end

    if self._state=="patrol" then
      -- Respect short cooldown after a failed seek
      if self._next_pick_after and now() < self._next_pick_after then
        -- keep patrolling
      end

      local c=self._home
      local yaw=math.random()*math.pi*2; local r=2+math.random()*4
      local gy = ground_y_below(c, 8)
      local y  = math.max(gy + ALT_HOVER, c.y + 0.3)
      local tgt = {x=c.x+math.cos(yaw)*r, y=y, z=c.z+math.sin(yaw)*r}
      self:_follow_path_or_goto(dtime, tgt, SPD_PATROL)

      if is_day() and not bad_weather() then
        local fl = nil
        if SEARCH_BEE_FIRST then
          local pos_now = self.object:get_pos()
          if pos_now then fl = pick_flower_near(pos_now, FORAGE_R) end
        end
        if (not fl) and self._home then
          fl = pick_flower_near(self._home, FORAGE_R)
        end
        if fl then
          self._flower = fl
          self._state  = "seek_flower"
          self._path   = nil
          self._seek_deadline = now() + SEEK_TIMEOUT_SEC
        end
      end

    elseif self._state=="seek_flower" then
      if (not self._flower) or (not is_flower_node_at(self._flower)) then
        self._flower=nil; self._state="patrol"; self._path=nil
      else
        if (self._seek_deadline and now() > self._seek_deadline) then
          self._flower = nil
          self._state  = "patrol"
          self._path   = nil
          self._next_pick_after = now() + FLOWER_RESELECT_COOLD
          return
        end

        local tgt = build_hover_target(self._flower, self._home)
        if not tgt then
          self._flower=nil; self._state="patrol"; self._path=nil
        else
          if self:_follow_path_or_goto(dtime, tgt, SPD_SEEK) then
            self._state        = "hover"
            self._forage_until = self._t + math.random()*(FORAGE_DWELL_MAX-FORAGE_DWELL_MIN) + FORAGE_DWELL_MIN
            self._hover_seed   = math.random()*math.pi*2
            self._path=nil
          end
        end
      end

    elseif self._state=="hover" then
      if (not self._flower) or (not is_flower_node_at(self._flower)) or bad_weather() or (not is_day()) then
        self._flower=nil; self._state="return"; self._path=nil
      else
        local base = build_hover_target(self._flower, self._home)
        if not base then
          self._flower=nil; self._state="return"; self._path=nil
        else
          local t  = self._t + (self._hover_seed or 0)
          local hover = { x = base.x + math.sin(t * 2.1) * 0.12,
                          y = base.y + math.sin(t * 2.0) * 0.06,
                          z = base.z + math.cos(t * 1.7) * 0.12 }
          self:_follow_path_or_goto(dtime, hover, SPD_PATROL*0.7)
          if self._t >= (self._forage_until or 0) then
            self._has_nectar  = true
            self._pollen_left = POLLEN_CHARGES
            self._state       = "return"
            self._flower      = nil
            self._path        = nil
          end
        end
      end

    elseif self._state=="return" then
      -- Prevent instant re-entry after forced exit
      if self._no_home_until and minetest.get_gametime() < self._no_home_until then
        local c = self._home or self.object:get_pos()
        local yaw=math.random()*math.pi*2; local r=1.5+math.random()*2.0
        local tgt = {x=c.x+math.cos(yaw)*r, y=c.y+0.6, z=c.z+math.sin(yaw)*r}
        self:_follow_path_or_goto(dtime, tgt, SPD_PATROL)
        if self._anim ~= "fly" then
          self.object:set_animation({x=FLY_F1,y=FLY_F2}, FPS, 0, true); self._anim = "fly"
        end
        return
      end

      local entp, dir = hive_entrance_point(self._home)
      if entp and dir then
        local aim = { x = entp.x + dir.x * 0.18, y = entp.y, z = entp.z + dir.z * 0.18 }
        if self:_follow_path_or_goto(dtime, aim, SPD_RETURN) then
          local p=self.object:get_pos()
          if p and hive_front_gate_ok(self._home, p) then
            if hive_try_enter(self._home, self.object) then return end
          end
        end
      else
        self._state="patrol"; self._path=nil
      end
    end

    try_pollinate_under(self)
  end,
})

------------------------- Pollination hook ------------------------------------
-- Crops are matched by groups; growth handled in crop_grow.lua (cw_mobs.grow_crop).
-- Pick one group name and tag your crop nodes (e.g., groups = { plant=1, cw_crop=1 }).
local CROP_GROUPS = { "cw_crop", "crop", "crop_pollinated" }

function cw_mobs.pollinate_plant(pos, node)
  node = node or minetest.get_node(pos)
  if not node or not node.name then return false end
  for _,g in ipairs(CROP_GROUPS) do
    if minetest.get_item_group(node.name, g) > 0 then
      if cw_mobs.grow_crop then return cw_mobs.grow_crop(pos, node) end
      return true
    end
  end
  return false
end

-- Called during flight with nectar; 1–2 nodes below, ~1% chance/tick, up to 10 charges
local function try_pollinate_under(self)
  if not self._has_nectar or not self._pollen_left or self._pollen_left<=0 then return end
  if math.random() >= POLLEN_FERTILIZE_CHANCE then return end
  local my = self.object:get_pos(); if not my then return end
  for dy=1,2 do
    local p = { x = math.floor(my.x + 0.5), y = math.floor(my.y) - dy, z = math.floor(my.z + 0.5) }
    local node = minetest.get_node(p)
    if node and node.name and node.name~="air" then
      if cw_mobs.pollinate_plant(p, node) then
        self._pollen_left = self._pollen_left - 1
        break
      end
    end
  end
end

-- Raycast: which node is the player looking at (server-safe)
local function cw_get_look_node_pos(player, range)
  range = range or 10
  local p = player:get_pos(); if not p then return end
  local eye_h = (player:get_properties() and player:get_properties().eye_height) or 1.5
  local eye = {x=p.x, y=p.y + eye_h, z=p.z}
  local dir = player:get_look_dir() or {x=0,y=0,z=1}
  local dst = {x=eye.x+dir.x*range, y=eye.y+dir.y*range, z=eye.z+dir.z*range}
  for hit in minetest.raycast(eye, dst, false, true) do
    if hit.type == "node" then return hit.under end
  end
end

-- Is there air (and headroom) here?
local function cw_is_free_air(pos)
  local n1 = minetest.get_node_or_nil(pos)
  local n2 = minetest.get_node_or_nil({x=pos.x, y=pos.y+1, z=pos.z})
  if not (n1 and n2) then return false end
  local d1 = minetest.registered_nodes[n1.name]
  local d2 = minetest.registered_nodes[n2.name]
  local function open(def) return def and not def.walkable and (not def.liquidtype or def.liquidtype=="none") end
  return open(d1) and open(d2)
end

-- Find a clean spawn point a little in front of the hive’s entrance
local function cw_find_evac_spot(hpos, player_fwd)
  local gate, dir = (cw_mobs and cw_mobs.hive_entrance_point) and cw_mobs.hive_entrance_point(hpos) or nil, nil
  local base = gate or {x=hpos.x+0.5, y=hpos.y+0.5, z=hpos.z+0.5}

  local fwd = dir or player_fwd or {x=0,y=0,z=1}
  local len = math.sqrt((fwd.x or 0)^2 + (fwd.z or 0)^2)
  if len < 1e-6 then fwd = {x=0,y=0,z=1} else fwd = {x=fwd.x/len, y=0, z=fwd.z/len} end

  local offsets = {
    {0.9, 0.0,  0.0}, {1.1, 0.0,  0.2}, {1.1, 0.0, -0.2},
    {0.9, 0.3,  0.0}, {1.2, 0.3,  0.2}, {1.2, 0.3, -0.2},
    {1.4, 0.6,  0.0}, {1.4, 0.6,  0.3}, {1.4, 0.6, -0.3},
  }
  for _,o in ipairs(offsets) do
    local p = {
      x = base.x + fwd.x*o[1] + fwd.z*o[3],
      y = base.y + o[2],
      z = base.z + fwd.z*o[1] - fwd.x*o[3]
    }
    p = {x = math.floor(p.x) + 0.5, y = math.floor(p.y) + 0.0, z = math.floor(p.z) + 0.5}
    if cw_is_free_air(p) then return p, fwd end
  end
  return nil, fwd
end

-- ============== /hive_debug ==============
minetest.register_chatcommand("hive_debug", {
  description = "Show honey and resident bee count for the beehive you're looking at",
  privs = {interact = true},
  func = function(name)
    local player = minetest.get_player_by_name(name)
    if not player then return false, "Player not found." end

    local pos = cw_get_look_node_pos(player, 10)
    if not pos then return false, "Look at a beehive within ~10 nodes." end

    local n = minetest.get_node(pos).name
    if n ~= "cw_mobs:beehive" and n ~= "cw_mobs:beehive_full" then
      return false, ("That is %s, not a beehive."):format(n)
    end

    if not (cw_mobs and cw_mobs.debug_hive) then
      return false, "cw_mobs.debug_hive() is missing — ensure it's defined in nodes/beehive.lua."
    end

    local honey, residents = cw_mobs.debug_hive(pos, name)
    return true, ("Hive %s | Honey=%d/5 | Bees Inside=%d/3")
      :format(minetest.pos_to_string(pos), honey or 0, residents or 0)
  end
})

-- ============== /hive_seed ==============
minetest.register_chatcommand("hive_seed", {
  description = "Force-seed up to 3 bees into the beehive you're looking at",
  privs = {interact = true},
  func = function(name)
    local player = minetest.get_player_by_name(name)
    if not player then return false, "Player not found." end

    local pos = cw_get_look_node_pos(player, 10)
    if not pos then return false, "Look at a beehive within ~10 nodes." end

    local n = minetest.get_node(pos).name
    if n ~= "cw_mobs:beehive" and n ~= "cw_mobs:beehive_full" then
      return false, "Not a beehive."
    end

    local before = minetest.get_meta(pos):get_int("residents")

    local function seed_one()
      local e = minetest.add_entity({x=pos.x+0.5,y=pos.y+0.5,z=pos.z+0.5}, "cw_mobs:bee")
      if e and cw_mobs and cw_mobs.hive_try_enter then
        cw_mobs.hive_try_enter(pos, e)
      end
    end

    seed_one(); seed_one(); seed_one()
    local after = minetest.get_meta(pos):get_int("residents")
    return true, ("Seeded hive: residents %d → %d"):format(before, after)
  end
})

-- ============== /hive_force_exit (diagnostic + robust) ==============
minetest.register_chatcommand("hive_force_exit", {
  description = "Eject resident bees from the pointed beehive (shows pos & count, robust spawn).",
  privs = {interact = true},
  func = function(name)
    local player = minetest.get_player_by_name(name)
    if not player then return false, "Player not found." end

    -- helpers from earlier (keep your cw_get_look_node_pos, cw_find_evac_spot)
    local function say(msg) minetest.chat_send_player(name, msg) end

    local hive_pos = cw_get_look_node_pos(player, 10)
    if not hive_pos then return false, "Look at a beehive within ~10 nodes." end
    local nn = minetest.get_node(hive_pos).name
    if nn ~= "cw_mobs:beehive" and nn ~= "cw_mobs:beehive_full" then
      return false, ("That is %s, not a beehive."):format(nn)
    end

    -- Read via the same path as /hive_debug so numbers match
    local honey,residents = 0,0
    if cw_mobs and cw_mobs.debug_hive then
      honey, residents = cw_mobs.debug_hive(hive_pos)  -- also prints a line
    else
      local m = minetest.get_meta(hive_pos)
      honey     = m:get_int("honey")
      residents = m:get_int("residents")
    end

    say(("Hive %s | Honey=%d/5 | Bees Inside=%d/3"):format(minetest.pos_to_string(hive_pos), honey, residents))

    if residents <= 0 then
      -- Optional: spawn 1 test bee so you can visually confirm evac works
      local spawn_base, fwd = cw_find_evac_spot(hive_pos, player:get_look_dir())
      if spawn_base then
        local o = minetest.add_entity(spawn_base, "cw_mobs:bee")
        if o then
          local L = o:get_luaentity()
          if L and L.set_home then L:set_home(hive_pos) end
          o:set_velocity({x=(fwd.x or 0)*1.5, y=0.4, z=(fwd.z or 0)*1.5})
          if L then L._no_home_until = minetest.get_gametime() + 8; L._state="patrol"; L._path=nil end
          return true, "No residents recorded, spawned 1 test bee in front of the hive."
        end
      end
      return true, "No residents inside."
    end

    -- Zero out before spawning so hive doesn't grab them back immediately
    local m = minetest.get_meta(hive_pos)
    m:set_int("residents", 0)

    local spawn_base, fwd = cw_find_evac_spot(hive_pos, player:get_look_dir())
    if not spawn_base then
      spawn_base = {x=hive_pos.x+0.5, y=hive_pos.y+1.2, z=hive_pos.z+0.5}
      fwd = fwd or {x=0,y=0,z=1}
    end

    local released, failed = 0, 0
    for i=1,residents do
      local off = 0.20 * (i-1)
      local p = {x=spawn_base.x + (fwd.x or 0)*off, y=spawn_base.y, z=spawn_base.z + (fwd.z or 0)*off}
      local o = minetest.add_entity(p, "cw_mobs:bee")
      if o then
        local L = o:get_luaentity()
        if L and L.set_home then L:set_home(hive_pos) end
        o:set_velocity({x=(fwd.x or 0)*1.5, y=0.4, z=(fwd.z or 0)*1.5})
        if L then L._no_home_until = minetest.get_gametime() + 8; L._state="patrol"; L._path=nil end
        released = released + 1
      else
        failed = failed + 1
        minetest.log("warning", "[cw_mobs] hive_force_exit: add_entity failed @"..minetest.pos_to_string(p))
      end
    end

    local msg = ("Evacuated hive %s → released %d bee(s)%s.")
      :format(minetest.pos_to_string(hive_pos), released, failed>0 and (" (failed: "..failed..")") or "")
    minetest.log("action", "[cw_mobs] "..msg)
    return true, msg
  end
})

-- ============== /spawn_bee ==============
minetest.register_chatcommand("spawn_bee", {
  description = "Spawn a bee where you look and bind it to the nearest beehive (<=16m)",
  privs = {interact = true},
  func = function(name)
    local player = minetest.get_player_by_name(name)
    if not player then return false, "Player not found." end

    local p = player:get_pos(); if not p then return false, "No position." end
    local eye_h = (player:get_properties() and player:get_properties().eye_height) or 1.5
    local eye = {x=p.x, y=p.y + eye_h, z=p.z}
    local dir = player:get_look_dir() or {x=0,y=0,z=1}
    local dst = {x = eye.x + dir.x*8, y = eye.y + dir.y*8, z = eye.z + dir.z*8}

    local spawn_at = {x = eye.x + dir.x*2, y = eye.y, z = eye.z + dir.z*2}
    for hit in minetest.raycast(eye, dst, false, true) do
      if hit.type == "node" then
        spawn_at = {
          x = hit.intersection_point.x - dir.x*0.3,
          y = hit.intersection_point.y - dir.y*0.3,
          z = hit.intersection_point.z - dir.z*0.3
        }
        break
      end
    end

    local o = minetest.add_entity(spawn_at, "cw_mobs:bee")
    if not o then return false, "Failed to spawn bee (check model/texture paths)." end

    local nearest, ndist
    local minp = {x=spawn_at.x-16,y=spawn_at.y-16,z=spawn_at.z-16}
    local maxp = {x=spawn_at.x+16,y=spawn_at.y+16,z=spawn_at.z+16}
    for _,pos2 in ipairs(minetest.find_nodes_in_area(minp, maxp, {"cw_mobs:beehive","cw_mobs:beehive_full"})) do
      local d = vector.distance(spawn_at, pos2)
      if not ndist or d < ndist then ndist, nearest = d, pos2 end
    end
    local L = o:get_luaentity()
    if nearest and L and L.set_home then L:set_home(nearest) end

    return true, ("Spawned bee at %s%s")
      :format(minetest.pos_to_string(spawn_at), nearest and (" (home "..minetest.pos_to_string(nearest)..")") or "")
  end
})