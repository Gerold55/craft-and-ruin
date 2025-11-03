-- cw_mobs/mobs/passive_bee.lua (core-only)
local core = core
cw_mobs = rawget(_G, "cw_mobs") or {}

-- ====== Utilities / settings ======
local function numset(k,d) local v=core.settings:get(k); v=(v=="" and nil) or v; return tonumber(v) or d end
local function now() return core.get_gametime() end
local function mix(a,b,t) return a + (b-a)*t end
local function clamp(v,a,b) return math.max(a, math.min(b, v)) end
local function is_day() local t=core.get_timeofday(); return t>=0.2 and t<=0.8 end
local function bad_weather() return cw_mobs.is_bad_weather() end
local function deg2rad(d) return d*math.pi/180 end
local function yaw_from_hdir(hdir) return math.atan2(-hdir.x, hdir.z) end

-- Animation frames (fly 1..20, attack 21..41)
local FPS = numset("cw_mobs.bee_anim_fps", 20)
local FLY_F1,FLY_F2 = 1,20
local ATK_F1,ATK_F2 = 21,41

-- Movement + steering
local SPD_PATROL, SPD_SEEK, SPD_RETURN = 2.2, 2.6, 3.0
local STEER_LERP, BOB_FREQ, BOB_AMP = 0.16, 3.0, 0.22
local MAX_TURN_RATE, ARRIVE_SLOW_DIST, YAW_EPS = 0.28, 1.2, 0.015

-- Leash/altitude near hive
local LEASH_R = numset("cw_mobs.bee_leash_r", 22)
local ALT_RANGE_MIN, ALT_RANGE_MAX, ALT_HOVER = 0.10, 0.15, 0.15

-- Anti-jitter
local AIM_LERP, LOS_BAD_GRACE = 0.24, 0.25
local AVOID_DECAY, AVOID_GAIN = 0.88, 0.42
local SIDE_PROBE_DIST, AHEAD_PROBE_DIST = 0.9, 1.2

-- Separation
local SEP_RADIUS, SEP_PUSH = 0.8, 0.18

-- Foraging/pollen
local FORAGE_R = numset("cw_mobs.bee_forage_r", 18)
local POLLEN_CHARGES, POLLEN_FERTILIZE_CHANCE = 10, 0.01

-- Combat
local STING_RANGE, STING_COOLDOWN = 1.2, 1.6
local STING_DAMAGE = numset("cw_mobs.bee_sting_damage", 2)
local AGGRO_SECONDS = numset("cw_mobs.bee_aggro_seconds", 20)

-- Pathfinder
local PATH_RING_RADII = {1.6,2.4,3.2}
local PATH_ANGLES     = {0,45,90,135,180,225,270,315}
local PATH_REPLAN_COOLD, REACH_WAYPOINT = 0.6, 0.45

-- Visit logic
local SEEK_TIMEOUT_SEC, FLOWER_RESELECT_COOLD = 15.0, 0.6
local FLOWER_GOAL_LOCK_SEC, SEEK_STUCK_REPLAN_SEC, HOVER_GATHER_SECONDS = 5.0, 1.2, 3.0
local VISIT_MIN_FLOWERS, VISIT_MAX_FLOWERS, VISIT_NEAR_HIVE_RADIUS = 1, 3, 14

-- Hover above bloom
local HOVER_OVER_Y_MIN, HOVER_OVER_Y_MAX = 1.10, 2.00
local HOVER_OVER_XZ_TOL, HOVER_SWIRL_RADIUS = 0.45, 0.10

-- Flowers (explicit names supplement group:flower)
local DEFAULT_FLOWERS = { "cw_core:flower_daisy","cw_core:flower_bluebell" }
local EXTRA_FLOWER_SET = {}
do for _,n in ipairs((cw_mobs and cw_mobs.flower_names) or DEFAULT_FLOWERS) do EXTRA_FLOWER_SET[n]=true end end

-- Debug line helper
local function dbg_line(a,b,rgb,step,ttl)
  if not a or not b then return end
  step,ttl = step or 0.5, ttl or 0.35
  local dx,dy,dz = b.x-a.x, b.y-a.y, b.z-a.z
  local len = math.sqrt(dx*dx+dy*dy+dz*dz); if len<1e-3 then return end
  local ux,uy,uz = dx/len, dy/len, dz/len
  local n = math.max(1, math.floor(len/step))
  local color = ("#%02x%02x%02x"):format(rgb.r, rgb.g, rgb.b)
  for i=0,n do
    local p = {x=a.x+ux*i*step,y=a.y+uy*i*step,z=a.z+uz*i*step}
    core.add_particle({pos=p, velocity={x=0,y=0,z=0}, expirationtime=ttl, size=2.0, glow=10, color=color})
  end
  local head={x=b.x-ux*0.2,y=b.y-uy*0.2,z=b.z-uz*0.2}
  core.add_particle({pos=b,    expirationtime=ttl, size=3.0, glow=10, color=color})
  core.add_particle({pos=head, expirationtime=ttl, size=3.0, glow=10, color=color})
end

-- Node helpers
local function is_flower_node_at(p)
  local n = core.get_node_or_nil(p); if not n then return false end
  if core.get_item_group(n.name, "flower") > 0 then return true end
  return EXTRA_FLOWER_SET[n.name] == true
end

local function find_flowers_in_area(minp, maxp)
  local names = {"group:flower"}; for n,_ in pairs(EXTRA_FLOWER_SET) do names[#names+1]=n end
  local list = core.find_nodes_in_area(minp, maxp, names) or {}
  local seen,out={},{}
  for _,p in ipairs(list) do
    local k = core.pos_to_string(p)
    if not seen[k] then seen[k]=true; out[#out+1]=p end
  end
  return out
end

local function ground_y_below(p,scan)
  scan=scan or 16
  local pos={x=math.floor(p.x+0.5),y=math.floor(p.y+0.5),z=math.floor(p.z+0.5)}
  for dy=0,scan do
    local below={x=pos.x,y=pos.y-dy,z=pos.z}
    local def=core.registered_nodes[core.get_node(below).name]
    if def and def.walkable then return below.y end
  end
  return pos.y-scan
end

local function is_liquid_at(p)
  local n=core.get_node_or_nil(p); if not n then return false end
  local def=core.registered_nodes[n.name]; return def and def.liquidtype and def.liquidtype~="none"
end

local function los_clear(a,b)
  local ray=core.raycast(a,b,false,true)
  for hit in ray do
    if hit and hit.type=="node" then
      local nd=core.registered_nodes[core.get_node(hit.under).name]
      if nd and nd.walkable then return false end
    end
  end
  return true
end

local function build_hover_target(flower_pos, home_pos)
  if not flower_pos then return nil end
  local cx,cz=flower_pos.x+0.5, flower_pos.z+0.5
  local base_y = flower_pos.y + (math.random()*(HOVER_OVER_Y_MAX-HOVER_OVER_Y_MIN)+HOVER_OVER_Y_MIN)
  if home_pos then
    base_y = math.max(home_pos.y+ALT_RANGE_MIN, math.min(home_pos.y+ALT_RANGE_MAX, base_y))
  end
  local anchor={x=cx,y=base_y,z=cz}
  local tip={x=cx,y=flower_pos.y+0.6,z=cz}
  local function path_ok(from)
    for hit in core.raycast({x=from.x,y=from.y+0.2,z=from.z}, {x=tip.x,y=tip.y+0.2,z=tip.z}, false, true) do
      if hit.type=="node" then
        local nd=core.registered_nodes[core.get_node(hit.under).name]
        if nd and nd.walkable then return false end
      end
    end
    return true
  end
  if path_ok(anchor) then return anchor end
  local r=0.25
  local ring={{ r,0},{-r,0},{0,r},{0,-r},{ r, r},{ r,-r},{-r, r},{-r,-r}}
  for _,o in ipairs(ring) do
    local cand={x=cx+o[1],y=base_y,z=cz+o[2]}
    if path_ok(cand) then return cand end
  end
  return anchor
end

local function sample_ring(from,to,radius)
  local best,score=nil,-1e9
  for _,deg in ipairs(PATH_ANGLES) do
    local a=deg2rad(deg)
    local p={x=from.x+math.cos(a)*radius,y=from.y,z=from.z+math.sin(a)*radius}
    local dir=vector.direction(from,to)
    local sd=vector.dot({x=math.cos(a),y=0,z=math.sin(a)},{x=dir.x,y=0,z=dir.z})
    if los_clear({x=from.x,y=from.y+0.2,z=from.z},{x=p.x,y=p.y+0.2,z=p.z}) then
      local los2=los_clear({x=p.x,y=p.y+0.2,z=p.z},{x=to.x,y=to.y+0.2,z=to.z})
      local s=sd + (los2 and 0.5 or 0.0) - (vector.distance(p,to)*0.02)
      if s>score then score=s; best=p end
    end
  end
  return best
end

local function compute_path(from,to)
  if los_clear({x=from.x,y=from.y+0.2,z=from.z},{x=to.x,y=to.y+0.2,z=to.z}) then
    return {vector.new(to)}
  end
  for _,r in ipairs(PATH_RING_RADII) do
    local w1=sample_ring(from,to,r)
    if w1 and los_clear({x=w1.x,y=w1.y+0.2,z=w1.z},{x=to.x,y=to.y+0.2,z=to.z}) then
      return {w1, vector.new(to)}
    end
  end
  for _,r1 in ipairs(PATH_RING_RADII) do
    local w1=sample_ring(from,to,r1)
    if w1 then
      for _,r2 in ipairs(PATH_RING_RADII) do
        local w2=sample_ring(w1,to,r2)
        if w2 and los_clear({x=w2.x,y=w2.y+0.2,z=w2.z},{x=to.x,y=to.y+0.2,z=to.z}) then
          return {w1,w2,vector.new(to)}
        end
      end
    end
  end
  return {vector.new(to)}
end

-- Hive APIs (from beehive.lua)
local function hive_entrance_point(pos) return cw_mobs.hive_entrance_point and cw_mobs.hive_entrance_point(pos) or nil, nil end
local function hive_front_gate_ok(hive_pos, bee_pos) return cw_mobs.hive_front_gate_ok and cw_mobs.hive_front_gate_ok(hive_pos, bee_pos) or false end
local function hive_try_enter(hive_pos, bee_obj) return cw_mobs.hive_try_enter and cw_mobs.hive_try_enter(hive_pos, bee_obj) or false end

-- Forward declare
local try_pollinate_under

-- Choose & lock a flower
local function choose_new_flower(self)
  local fl
  if self._home then
    local minp={x=self._home.x-VISIT_NEAR_HIVE_RADIUS,y=self._home.y-1,z=self._home.z-VISIT_NEAR_HIVE_RADIUS}
    local maxp={x=self._home.x+VISIT_NEAR_HIVE_RADIUS,y=self._home.y+2,z=self._home.z+VISIT_NEAR_HIVE_RADIUS}
    local cands=find_flowers_in_area(minp,maxp)
    if #cands>0 then
      local best,bd
      for _,p in ipairs(cands) do
        local d=vector.distance(self._home,{x=p.x+0.5,y=p.y+0.5,z=p.z+0.5})
        if not bd or d<bd then best,bd=p,d end
      end
      fl=best
    end
  end
  if not fl then
    local pos=self.object:get_pos()
    if pos then
      local r=math.max(10,VISIT_NEAR_HIVE_RADIUS*0.7)
      local c=find_flowers_in_area({x=pos.x-r,y=pos.y-1,z=pos.z-r},{x=pos.x+r,y=pos.y+2,z=pos.z+r})
      fl=(#c>0) and c[1] or nil
    end
  end
  if fl then
    self._flower=fl
    self._goal_lock_until=now()+FLOWER_GOAL_LOCK_SEC
    self._seek_deadline=now()+SEEK_TIMEOUT_SEC
    self._seek_started_at=now()
    self._last_pos_for_seek=self.object:get_pos()
    self._path=nil
    self._state="seek_flower"
    return true
  end
  return false
end

core.register_entity("cw_mobs:bee", {
  initial_properties = {
    visual="mesh", mesh="bee.glb", textures={"bee.png"},
    visual_size={x=6,y=6},
    collisionbox={-0.25,-0.20,-0.25,0.25,0.25,0.25},
    physical=false, collide_with_objects=false, pointable=true,
    static_save=true, glow=0, makes_footstep_sound=false, hp_max=3,
    damage_texture_modifier="^[brighten",
  },

  _t=0,_anim="fly",
  _state="patrol",
  _home=nil,_min_alt=nil,_max_alt=nil,
  _flower=nil,_forage_until=0,_seek_deadline=nil,_next_pick_after=nil,
  _has_nectar=false,_pollen_left=0,
  _heading={x=0,z=1},_aim_last=nil,_avoid={x=0,z=0},_los_bad_until=0,
  _dodge_side=0,_target_obj=nil,_aggro_til=0,_sting_cd=0,
  _path=nil,_path_replan_t=0,
  _goal_lock_until=0,_seek_started_at=0,_visit_goal=0,_visit_done=0,_last_pos_for_seek=nil,_finish_hover_pos=nil,

  get_staticdata=function(self)
    return core.serialize({home=self._home, nectar=self._has_nectar, pollen=self._pollen_left, vg=self._visit_goal, vd=self._visit_done})
  end,

  on_activate=function(self, sd)
    if sd and sd~="" then
      local ok,d = pcall(core.deserialize, sd)
      if ok and type(d)=="table" then
        self._home=d.home; self._has_nectar=d.nectar or false; self._pollen_left=d.pollen or 0
        self._visit_goal=d.vg or 0; self._visit_done=d.vd or 0
      end
    end
    if self._visit_goal==0 then
      self._visit_goal=math.random(VISIT_MIN_FLOWERS, VISIT_MAX_FLOWERS)
      self._visit_done=0
    end
    self.object:set_animation({x=FLY_F1,y=FLY_F2}, FPS, 0, true)
  end,

  set_home=function(self, hive_pos)
    self._home=vector.new(hive_pos)
    local gy=ground_y_below({x=hive_pos.x,y=hive_pos.y+2,z=hive_pos.z},8)
    self._min_alt=(gy or hive_pos.y)+ALT_RANGE_MIN
    self._max_alt=hive_pos.y+ALT_RANGE_MAX
  end,

  has_nectar=function(self) return self._has_nectar end,
  clear_nectar=function(self) self._has_nectar=false; self._pollen_left=0 end,

  make_angry=function(self, player, extra)
    if not (player and player.is_player and player:is_player()) then return end
    self._state="angry"; self._target_obj=player; self._aggro_til=now()+(extra or AGGRO_SECONDS)
    self.object:set_animation({x=ATK_F1,y=ATK_F2}, FPS, 0, true); self._anim="attack"
  end,

  on_punch=function(self, hitter)
    if hitter and hitter:is_player() then self:make_angry(hitter, AGGRO_SECONDS) end
    return true
  end,

  set_debug=function(self,on)
    self._dbg = on and true or nil
    self.object:set_properties({nametag_color={a=255,r=255,g=235,b=120}, nametag=self._dbg and "<bee>" or ""})
  end,

  _debug_tick=function(self, dtime)
    if not self._dbg then return end
    local pos=self.object:get_pos(); if not pos then return end
    local txt = ("[%s] N:%s P:%d V%d/%d"):format(self._state or "?", self._has_nectar and "Y" or "n", self._pollen_left or 0, self._visit_done or 0, self._visit_goal or 0)
    self.object:set_properties({nametag=txt})

    local hx,hz=(self._heading.x or 0),(self._heading.z or 1)
    dbg_line(pos, {x=pos.x+hx*2.0,y=pos.y,z=pos.z+hz*2.0}, {r=255,g=255,b=255})
    if self._path and #self._path>0 then
      dbg_line(pos, self._path[1], {r=60,g=220,b=255})
      for i=1,#self._path-1 do dbg_line(self._path[i], self._path[i+1], {r=80,g=160,b=255}) end
    elseif self._aim_last then
      dbg_line(pos, self._aim_last, {r=255,g=240,b=60})
    end
    if self._home then
      local gate,dir = cw_mobs.hive_entrance_point and cw_mobs.hive_entrance_point(self._home) or nil, nil
      local home_pt = gate or {x=self._home.x+0.5,y=self._home.y+0.5,z=self._home.z+0.5}
      dbg_line(pos, home_pt, {r=235,g=90,b=200})
    end
  end,

  _separate=function(self,pos)
    local objs=core.get_objects_inside_radius(pos, SEP_RADIUS)
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

  _follow_path_or_goto=function(self,dtime,target,speed)
    local pos=self.object:get_pos(); if not pos then return end
    local function need_replan() return (not self._path or #self._path==0 or now()>=(self._path_replan_t or 0)) end
    if need_replan() then
      self._path=compute_path({x=pos.x,y=pos.y,z=pos.z}, target)
      self._path_replan_t=now()+PATH_REPLAN_COOLD
    end
    local wp=self._path[1] or target
    local reached=self:_goto(dtime, wp, speed)
    if reached then table.remove(self._path,1); if (not self._path) or #self._path==0 then return true end end
    return false
  end,

  _goto=function(self,dtime,target,speed)
    local obj=self.object; local pos=obj:get_pos(); if not pos then return end
    local vel=obj:get_velocity() or {x=0,y=0,z=0}
    if is_liquid_at(pos) then vel.y=math.max(vel.y,0.5) end
    local gy=ground_y_below(pos,16)
    if pos.y < gy + 0.2 then obj:set_pos({x=pos.x,y=gy+0.25,z=pos.z}); pos=obj:get_pos(); vel.y=math.max(vel.y,0.2) end

    if not self._aim_last then self._aim_last=vector.new(target)
    else
      self._aim_last.x = self._aim_last.x + (target.x - self._aim_last.x)*AIM_LERP
      self._aim_last.y = self._aim_last.y + (target.y - self._aim_last.y)*AIM_LERP
      self._aim_last.z = self._aim_last.z + (target.z - self._aim_last.z)*AIM_LERP
    end
    local aim=self._aim_last

    local bob=math.sin(self._t*BOB_FREQ)*BOB_AMP
    if self._min_alt and pos.y < self._min_alt then vel.y = mix(vel.y, math.max(0.6, speed*0.4), 0.30)
    elseif self._max_alt and pos.y > self._max_alt then vel.y = mix(vel.y, -math.max(0.6, speed*0.4), 0.30)
    else vel.y = mix(vel.y, bob, 0.20) end

    local dir_to=vector.direction(pos,aim)
    local base_hx,base_hz=dir_to.x,dir_to.z
    local len=math.sqrt(base_hx*base_hx+base_hz*base_hz)
    if len<1e-6 then base_hx,base_hz=0,1 else base_hx,base_hz=base_hx/len,base_hz/len end

    local eye={x=pos.x,y=pos.y+0.2,z=pos.z}
    local los_ok=true
    do
      local ray=core.raycast(eye, aim, false, true)
      for hit in ray do
        if hit and hit.type=="node" then
          local nd=core.registered_nodes[core.get_node(hit.under).name]
          if nd and nd.walkable then los_ok=false; break end
        end
      end
    end
    local nowt=now()
    if not los_ok then self._los_bad_until=math.max(self._los_bad_until, nowt+LOS_BAD_GRACE) end
    local los_bad=(self._los_bad_until or 0)>nowt

    local avoid_x,avoid_z=0,0
    if los_bad then
      local side=self._dodge_side
      if side==0 then side=(math.random()<0.5) and -1 or 1; self._dodge_side=side end
      local side_vec={x= base_hz*side, z=-base_hx*side}
      local probe_side={x=eye.x+side_vec.x*SIDE_PROBE_DIST,y=eye.y,z=eye.z+side_vec.z*SIDE_PROBE_DIST}
      local probe_ahead={x=eye.x+base_hx*AHEAD_PROBE_DIST,y=eye.y,z=eye.z+base_hz*AHEAD_PROBE_DIST}
      local function blocked(dst)
        local ray2=core.raycast(eye,dst,false,true)
        for h in ray2 do
          if h and h.type=="node" then
            local nd=core.registered_nodes[core.get_node(h.under).name]
            if nd and nd.walkable then return true end
          end
        end
        return false
      end
      if blocked(probe_side) or blocked(probe_ahead) then
        avoid_x=side_vec.x*AVOID_GAIN + base_hx*0.10
        avoid_z=side_vec.z*AVOID_GAIN + base_hz*0.10
      end
    else
      self._dodge_side=0
    end

    local sep=self:_separate(pos)
    if sep then
      local sh=math.sqrt(sep.x*sep.x+sep.z*sep.z)
      if sh>1e-6 then avoid_x=avoid_x+(sep.x/sh)*0.25; avoid_z=avoid_z+(sep.z/sh)*0.25 end
    end

    self._avoid.x = self._avoid.x*AVOID_DECAY + avoid_x*(1.0-AVOID_DECAY)
    self._avoid.z = self._avoid.z*AVOID_DECAY + avoid_z*(1.0-AVOID_DECAY)

    local steer_x=base_hx + self._avoid.x
    local steer_z=base_hz + self._avoid.z
    local s_len=math.sqrt(steer_x*steer_x+steer_z*steer_z)
    if s_len>=1e-6 then steer_x,steer_z=steer_x/s_len,steer_z/s_len else steer_x,steer_z=base_hx,base_hz end

    local cur=self._heading or {x=0,z=1}
    local blended={ x = cur.x + clamp(steer_x-cur.x,-MAX_TURN_RATE,MAX_TURN_RATE),
                    z = cur.z + clamp(steer_z-cur.z,-MAX_TURN_RATE,MAX_TURN_RATE) }
    local b_len=math.sqrt(blended.x*blended.x+blended.z*blended.z)
    if b_len>1e-6 then blended.x,blended.z=blended.x/b_len,blended.z/b_len end
    self._heading=blended

    local yaw=yaw_from_hdir(self._heading)
    local cur_yaw=obj:get_yaw() or 0
    if math.abs(cur_yaw - yaw) > YAW_EPS then obj:set_yaw(yaw) end

    local dist=vector.distance(pos,aim)
    local slow=(dist<ARRIVE_SLOW_DIST) and (dist/ARRIVE_SLOW_DIST) or 1.0
    local fwd=(speed*slow)
    local want={x=self._heading.x*fwd, y=vel.y, z=self._heading.z*fwd}
    obj:set_velocity({x=mix(vel.x,want.x,STEER_LERP), y=want.y, z=mix(vel.z,want.z,STEER_LERP)})

    return dist <= REACH_WAYPOINT
  end,

  _try_sting=function(self, player)
    if self._sting_cd>0 or not player or not player:is_player() then return end
    local myp=self.object:get_pos(); local pp=player:get_pos(); if not (myp and pp) then return end
    if vector.distance(myp,pp) > STING_RANGE then return end
    local dir=vector.direction(myp,pp)
    player:punch(self.object, 0.5, {full_punch_interval=1.0, damage_groups={fleshy=STING_DAMAGE}}, dir)
    self._sting_cd=STING_COOLDOWN
    self.object:remove() -- die after sting (MC-like)
  end,

  on_step=function(self,dtime)
    self._t=self._t+dtime
    if self._sting_cd>0 then self._sting_cd=self._sting_cd-dtime end
    local pos=self.object:get_pos(); if not pos then return end

    -- Adopt nearest hive if homeless
    if (not self._home) and (now() % 2 == 0) then
      local list=core.find_nodes_in_area({x=pos.x-16,y=pos.y-8,z=pos.z-16},{x=pos.x+16,y=pos.y+8,z=pos.z+16},{"cw_mobs:beehive","cw_mobs:beehive_full"})
      local best,bd
      for _,hp in ipairs(list) do
        local d=vector.distance(pos,hp)
        if not bd or d<bd then best,bd=hp,d end
      end
      if best then self:set_home(best) end
    end

    if not self._home then
      local yaw=math.random()*math.pi*2; local r=2+math.random()*4
      local tgt={x=pos.x+math.cos(yaw)*r,y=pos.y+0.2,z=pos.z+math.sin(yaw)*r}
      self:_follow_path_or_goto(dtime,tgt,SPD_PATROL)
      try_pollinate_under(self); self:_debug_tick(dtime); return
    end

    if vector.distance(pos,self._home) > LEASH_R then
      self._state="return"; self._flower=nil; self._path=nil
    end

    -- Anger state
    if self._state=="angry" then
      if (not self._target_obj) or (not self._target_obj:is_player()) or now()>self._aggro_til then
        self._state="patrol"; self._target_obj=nil
      else
        local ppos=self._target_obj:get_pos()
        if ppos then
          self:_follow_path_or_goto(dtime,{x=ppos.x,y=ppos.y+0.9,z=ppos.z},SPD_RETURN)
          self:_try_sting(self._target_obj)
          try_pollinate_under(self); self:_debug_tick(dtime); return
        end
      end
    end

    local must_go_home=(not is_day()) or bad_weather()
    if must_go_home and self._state~="return" then self._state="return"; self._flower=nil; self._path=nil end

    if self._state=="patrol" then
      local c=self._home
      local yaw=math.random()*math.pi*2; local r=2+math.random()*4
      local gy=ground_y_below(c,8)
      local y=math.max(gy+ALT_HOVER, c.y+0.3)
      local tgt={x=c.x+math.cos(yaw)*r,y=y,z=c.z+math.sin(yaw)*r}
      self:_follow_path_or_goto(dtime,tgt,SPD_PATROL)

      if is_day() and (not bad_weather()) and self._home then
        if (not self._flower) and (not self._path or #self._path==0) and now()>=(self._goal_lock_until or 0) then
          choose_new_flower(self)
        end
      end

    elseif self._state=="seek_flower" then
      if (not self._flower) or (not is_flower_node_at(self._flower)) then
        self._flower=nil; self._state="patrol"; self._path=nil
      else
        if self._seek_deadline and now() > self._seek_deadline then
          self._flower=nil; self._state="patrol"; self._path=nil; self._next_pick_after=now()+FLOWER_RESELECT_COOLD
        else
          local tgt=build_hover_target(self._flower,self._home)
          if not tgt then self._flower=nil; self._state="patrol"; self._path=nil
          else
            local p=self.object:get_pos()
            if p and self._last_pos_for_seek then
              local dv=vector.distance(p,self._last_pos_for_seek)
              if dv<0.15 and (now()-(self._seek_started_at or now()))>SEEK_STUCK_REPLAN_SEC then
                self._path=nil; self._seek_started_at=now()
              end
            end
            self._last_pos_for_seek=p

            if self:_follow_path_or_goto(dtime,tgt,SPD_SEEK) then
              self._state="hover"; self._forage_until=self._t+HOVER_GATHER_SECONDS
              self._hover_seed=math.random()*math.pi*2; self._path=nil
            end
          end
        end
      end

    elseif self._state=="hover" then
      if (not self._flower) or (not is_flower_node_at(self._flower)) or bad_weather() or (not is_day()) then
        self._flower=nil; self._state="return"; self._path=nil
      else
        local base=build_hover_target(self._flower,self._home)
        if not base then self._flower=nil; self._state="return"; self._path=nil
        else
          local t=self._t+(self._hover_seed or 0)
          local aim={ x=base.x+math.sin(t*2.1)*HOVER_SWIRL_RADIUS,
                      y=base.y+math.sin(t*1.6)*(HOVER_SWIRL_RADIUS*0.25),
                      z=base.z+math.cos(t*1.7)*HOVER_SWIRL_RADIUS }
          self:_follow_path_or_goto(dtime,aim,SPD_PATROL*0.6)
          if self._t >= (self._forage_until or 0) then
            self._finish_hover_pos=self.object:get_pos()
            self._state="hover_done"
          end
        end
      end

    elseif self._state=="hover_done" then
      local ok=false
      if self._finish_hover_pos and self._flower and is_flower_node_at(self._flower) then
        local p=self._finish_hover_pos
        local fx,fz=self._flower.x+0.5, self._flower.z+0.5
        local dx,dz=math.abs(p.x-fx), math.abs(p.z-fz)
        local dy=(p.y-(self._flower.y+0.5))
        if dx<=HOVER_OVER_XZ_TOL and dz<=HOVER_OVER_XZ_TOL and dy>=HOVER_OVER_Y_MIN and dy<=HOVER_OVER_Y_MAX then ok=true end
      end
      if ok then
        if not self._has_nectar then self._has_nectar=true; self._pollen_left=POLLEN_CHARGES end
        self._visit_done=(self._visit_done or 0)+1
      end
      self._flower=nil; self._path=nil
      if (self._visit_done or 0) >= (self._visit_goal or 1) then
        self._state="return"
      else
        self._state="patrol"; self._goal_lock_until=0; self._next_pick_after=0
      end

    elseif self._state=="return" then
      if self._no_home_until and now() < self._no_home_until then
        local c=self._home or self.object:get_pos()
        local yaw=math.random()*math.pi*2; local r=1.5+math.random()*2.0
        local tgt={x=c.x+math.cos(yaw)*r,y=c.y+0.6,z=c.z+math.sin(yaw)*r}
        self:_follow_path_or_goto(dtime,tgt,SPD_PATROL)
        if self._anim~="fly" then self.object:set_animation({x=FLY_F1,y=FLY_F2}, FPS, 0, true); self._anim="fly" end
      else
        local entp,dir = cw_mobs.hive_entrance_point and cw_mobs.hive_entrance_point(self._home) or nil, nil
        if entp and dir then
          local aim={x=entp.x+dir.x*0.18,y=entp.y,z=entp.z+dir.z*0.18}
          if self:_follow_path_or_goto(dtime,aim,SPD_RETURN) then
            local p=self.object:get_pos()
            if p and (cw_mobs.hive_front_gate_ok and cw_mobs.hive_front_gate_ok(self._home,p)) then
              if cw_mobs.hive_try_enter and cw_mobs.hive_try_enter(self._home,self.object) then
                self._visit_goal=math.random(VISIT_MIN_FLOWERS,VISIT_MAX_FLOWERS)
                self._visit_done=0; self._has_nectar=false; self._pollen_left=0
                return
              end
            end
          end
        else
          self._state="patrol"; self._path=nil
        end
      end
    end

    try_pollinate_under(self)
    self:_debug_tick(dtime)
  end,
})

-- Pollination API (used by bees)
local CROP_GROUPS = { "cw_crop", "crop", "crop_pollinated" }
function cw_mobs.pollinate_plant(pos, node)
  node = node or core.get_node(pos)
  if not node or not node.name then return false end
  for _,g in ipairs(CROP_GROUPS) do
    if core.get_item_group(node.name, g) > 0 then
      if cw_mobs.grow_crop then return cw_mobs.grow_crop(pos, node) end
      return true
    end
  end
  return false
end

-- Only when directly above a plant (tight X/Z)
try_pollinate_under = function(self)
  if (not self._has_nectar) or (not self._pollen_left) or self._pollen_left<=0 then return end
  if math.random() >= POLLEN_FERTILIZE_CHANCE then return end
  local my=self.object:get_pos(); if not my then return end
  for dy=1,2 do
    local p={x=math.floor(my.x+0.5),y=math.floor(my.y)-dy,z=math.floor(my.z+0.5)}
    local node=core.get_node(p)
    if node and node.name and node.name~="air" then
      local cx,cz=p.x+0.5,p.z+0.5
      local dx,dz=math.abs(my.x-cx),math.abs(my.z-cz)
      if dx<=HOVER_OVER_XZ_TOL and dz<=HOVER_OVER_XZ_TOL then
        if cw_mobs.pollinate_plant(p,node) then
          self._pollen_left=self._pollen_left-1
          break
        end
      end
    end
  end
end
