-- Bees: hive-anchored; enter/exit FRONT only; fly anim; forage w/ LOS;
-- pollinate under 1–2 blocks (1%/tick, 10 charges per pollen run);
-- return at night OR bad weather; min stay handled by hive; aggression & stings.

local function numset(k,d) local v=minetest.settings:get(k); v=(v=="" and nil) or v; return tonumber(v) or d end
local function now() return minetest.get_gametime() end

-- Animation (frame indices)
local FPS = numset("cw_mobs.bee_anim_fps", 20)
local F1, F2 = 1, 20
local FLY_SPEED = FPS

-- Movement
local SPD_CALM = 2.4
local SPD_DART = 3.0
local STEER_LERP = 0.16
local BOB_FREQ = 3.0
local BOB_AMP = 0.22

-- Leash/altitude
local LEASH_R = numset("cw_mobs.bee_leash_r", 14)
local ALT_RANGE_MIN = 0.8
local ALT_RANGE_MAX = 2.0
local ALT_HOVER = 1.3

-- Separation
local SEP_RADIUS = 0.8
local SEP_PUSH = 0.18

-- Foraging & pollen
local FORAGE_R = numset("cw_mobs.bee_forage_r", 12)
local FORAGE_DWELL = numset("cw_mobs.bee_forage_dwell", 2.5)
local POLLEN_CHARGES = 10
local POLLEN_FERTILIZE_CHANCE = 0.01

-- Combat
local STING_RANGE = 1.2
local STING_COOLDOWN = 1.6
local STING_DAMAGE = numset("cw_mobs.bee_sting_damage", 2)
local AGGRO_SECONDS = numset("cw_mobs.bee_aggro_seconds", 20)
local STINGS_TO_DIE = 3 -- dies after stinging 3 times

local function randf(a,b) return a + math.random()*(b-a) end
local function mix(a,b,t) return a + (b-a)*t end
local function is_day() local t=minetest.get_timeofday(); return t>=0.2 and t<=0.8 end
local function bad_weather() return cw_mobs and cw_mobs.is_bad_weather and cw_mobs.is_bad_weather() or false end

local HIVE_NAMES = { "cw_mobs:beehive","cw_mobs:beehive_full","cw_mobs:apiary","cw_mobs:apiary_full" }

local function ground_y_below(p, scan)
  scan = scan or 6
  local pos = {x=math.floor(p.x+0.5), y=math.floor(p.y+0.5), z=math.floor(p.z+0.5)}
  for dy=0,scan do
    local below = {x=pos.x, y=pos.y - dy, z=pos.z}
    local def = minetest.registered_nodes[minetest.get_node(below).name]
    if def and def.walkable then return below.y end
  end
  return pos.y - scan
end

local function hive_entrance_point(hpos)
  local n = minetest.get_node(hpos)
  local dir = minetest.facedir_to_dir(n.param2 or 0)
  return { x=hpos.x+dir.x*0.55, y=hpos.y+0.25, z=hpos.z+dir.z*0.55 }, dir
end

local function find_nearest_hive(pos, r)
  local minp = {x=pos.x-r, y=pos.y-r, z=pos.z-r}
  local maxp = {x=pos.x+r, y=pos.y+r, z=pos.z+r}
  local nodes = minetest.find_nodes_in_area(minp, maxp, HIVE_NAMES)
  local best, dmin
  for _,hp in ipairs(nodes) do
    local d = vector.distance(pos, hp)
    if not best or d < dmin then best, dmin = hp, d end
  end
  return best
end

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

local function pick_flower_near(hpos, r)
  local minp = {x=hpos.x-r, y=hpos.y-2, z=hpos.z-r}
  local maxp = {x=hpos.x+r, y=hpos.y+2, z=hpos.z+r}
  local nodes = minetest.find_nodes_in_area(minp, maxp, {"group:flower"})
  if #nodes==0 then return nil end
  for _=1,math.min(#nodes, 8) do
    local p = nodes[math.random(#nodes)]
    if los_clear({x=hpos.x,y=hpos.y+0.8,z=hpos.z}, {x=p.x+0.5,y=p.y+0.5,z=p.z+0.5}) then return p end
  end
  return nodes[math.random(#nodes)]
end

local function play_fly(self, force)
  if self._anim~="fly" or force then
    self.object:set_animation({x=F1,y=F2}, FLY_SPEED, 0, true)
    self._anim = "fly"
  end
end

local function node_below_from_pos(pos, dy)
  return { x = math.floor(pos.x + 0.5),
           y = math.floor(pos.y) - dy,
           z = math.floor(pos.z + 0.5) }
end

local function try_pollinate_under(self)
  if not self._has_nectar or not self._pollen_left or self._pollen_left<=0 then return end
  if not self._home then return end
  if math.random() >= POLLEN_FERTILIZE_CHANCE then return end
  local my = self.object:get_pos(); if not my then return end
  for dy=1,2 do
    local p = node_below_from_pos(my, dy)
    local node = minetest.get_node(p)
    if node and node.name and node.name~="air" then
      if cw_mobs and cw_mobs.pollinate_plant and cw_mobs.pollinate_plant(p, node) then
        self._pollen_left = self._pollen_left - 1
        break
      end
    end
  end
end

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

  -- runtime
  _t=0, _anim=nil,
  _state="idle", _target=nil, _flower=nil, _forage_until=0,
  _home=nil, _min_alt=nil, _max_alt=nil,
  _has_nectar=false, _pollen_left=0,

  -- combat
  _angry=false, _aggro_til=0, _target_obj=nil, _sting_cd=0,
  _stings_done=0,

  get_staticdata = function(self)
    return minetest.serialize({home=self._home, nectar=self._has_nectar, pollen=self._pollen_left})
  end,

  on_activate = function(self, staticdata)
    self._t=0; play_fly(self,true)
    if staticdata and staticdata~="" then
      local ok,d = pcall(minetest.deserialize, staticdata)
      if ok and type(d)=="table" then
        self._home = d.home; self._has_nectar = d.nectar or false; self._pollen_left = d.pollen or 0
      end
    end
    if not self._home then
      local p=self.object:get_pos(); local hive = p and find_nearest_hive(p,18)
      if hive then self:set_home(hive) else self._homeless_til = now()+10 end
    end
  end,

  set_home = function(self, hive_pos)
    self._home = vector.new(hive_pos)
    local gy = ground_y_below({x=hive_pos.x,y=hive_pos.y+2,z=hive_pos.z}, 8)
    self._min_alt = (gy or hive_pos.y) + ALT_RANGE_MIN
    self._max_alt = hive_pos.y + ALT_RANGE_MAX
  end,

  has_nectar = function(self) return self._has_nectar end,
  clear_nectar = function(self) self._has_nectar=false; self._pollen_left=0 end,

  -- Public: anger bee at player
  make_angry = function(self, target_player, extra_secs)
    if not (target_player and target_player.is_player and target_player:is_player()) then return end
    self._angry = true; self._target_obj = target_player
    local base = (self._aggro_til and math.max(self._aggro_til, now())) or now()
    self._aggro_til = base + (extra_secs or 20)
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

  _goto = function(self, dtime, target, speed)
    local obj=self.object; local pos=obj:get_pos(); if not pos then return end
    local vel=obj:get_velocity() or {x=0,y=0,z=0}
    local bob = math.sin(self._t*BOB_FREQ)*BOB_AMP
    local sep = self:_separate(pos)

    if self._min_alt and pos.y < self._min_alt then vel.y = mix(vel.y, math.max(0.6, speed*0.4), 0.35)
    elseif self._max_alt and pos.y > self._max_alt then vel.y = mix(vel.y, -math.max(0.6, speed*0.4), 0.35) end

    local eye={x=pos.x,y=pos.y+0.2,z=pos.z}
    if not los_clear(eye, target) then
      local yaw = math.atan2(target.x-pos.x, target.z-pos.z)
      local side = (math.random()<0.5) and -1 or 1
      target = {x=pos.x + math.sin(yaw)*side*0.8, y=target.y, z=pos.z + math.cos(yaw)*side*0.8}
    end

    local dir=vector.direction(pos, target)
    local want={x=dir.x*speed, y=dir.y*speed + bob, z=dir.z*speed}
    if sep then want.x=want.x+sep.x; want.z=want.z+sep.z end
    vel={x=mix(vel.x,want.x,STEER_LERP), y=mix(vel.y,want.y,STEER_LERP), z=mix(vel.z,want.z,STEER_LERP)}
    obj:set_velocity(vel); obj:set_yaw(math.atan2(-vel.x, vel.z))
    play_fly(self)
    return vector.distance(pos,target) <= 0.8
  end,

  _try_enter_hive = function(self)
    if not self._home then return false end
    local p=self.object:get_pos(); if not p then return false end
    if cw_mobs and cw_mobs.hive_front_gate_ok and cw_mobs.hive_front_gate_ok(self._home, p) then
      if cw_mobs.hive_try_enter then return cw_mobs.hive_try_enter(self._home, self.object) end
    end
    return false
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
    if self._stings_done >= STINGS_TO_DIE then
      local p = self.object:get_pos()
      if p then
        minetest.add_particlespawner({
          amount=15,time=0.1,minpos=p,maxpos=p,
          minvel={x=-0.2,y=0.2,z=-0.2},maxvel={x=0.2,y=0.6,z=0.2},
          minexptime=0.4,maxexptime=0.8,minsize=1.0,maxsize=2.0,glow=2,
          texture="cw_pollen.png"
        })
      end
      self.object:remove()
    end
  end,

  on_step = function(self, dtime)
    self._t = self._t + dtime
    if self._sting_cd>0 then self._sting_cd = self._sting_cd - dtime end

    local obj=self.object; local pos=obj:get_pos(); if not pos then return end
    if not self._home and self._homeless_til and now()>self._homeless_til then obj:remove(); return end
    if not (self._min_alt and self._max_alt) and self._home then self:set_home(self._home) end
    if (self._t%4.0) < dtime then play_fly(self) end

    local must_go_home = (not is_day()) or bad_weather()
    local speed = (math.random()<0.02 and SPD_DART or SPD_CALM)

    -- AGGRO overrides
    if self._angry then
      if not self._target_obj or not self._target_obj:is_player() or now()>self._aggro_til then
        self._angry=false
      else
        local ppos = self._target_obj:get_pos()
        if ppos then
          self:_goto(dtime, {x=ppos.x,y=ppos.y+1.0,z=ppos.z}, SPD_DART)
          self:_try_sting(self._target_obj)
          return
        end
      end
    end

    if must_go_home then
      local entp, dir = self._home and hive_entrance_point(self._home) or nil
      if entp then
        local aim = {x=entp.x+dir.x*0.2, y=entp.y, z=entp.z+dir.z*0.2}
        if self:_goto(dtime, aim, speed) then
          if self:_try_enter_hive() then return end
        end
      end
      return
    end

    -- DAYTIME: forage loop + pollination
    if self._state=="idle" then
      if self._home then
        self._flower = pick_flower_near(self._home, FORAGE_R)
        if self._flower then
          local gy = ground_y_below(self._flower, 3)
          local y = math.max((gy + ALT_HOVER), self._flower.y + 0.4)
          self._target = {x=self._flower.x+0.5,y=y,z=self._flower.z+0.5}
          self._state = "forage_approach"
        else
          local c=self._home; local yaw=randf(-math.pi,math.pi); local r=randf(2,6)
          self._target = {x=c.x+math.cos(yaw)*r, y=math.max(ground_y_below(c,6)+ALT_HOVER, c.y+0.3), z=c.z+math.sin(yaw)*r}
        end
      end

    elseif self._state=="forage_approach" then
      if self._target then
        local eye={x=pos.x,y=pos.y+0.2,z=pos.z}; local tgt={x=self._target.x,y=self._target.y,z=self._target.z}
        if not los_clear(eye,tgt) and vector.distance(pos,tgt)<3.0 then
          self._flower=nil; self._state="idle"; self._target=nil
        else
          if self:_goto(dtime, tgt, speed) then
            self._state="forage_hover"; self._forage_until=self._t + FORAGE_DWELL; self._hover_seed=math.random()*math.pi*2
          end
        end
      else self._state="idle" end

    elseif self._state=="forage_hover" then
      local t=(self._t + (self._hover_seed or 0))
      local dx=math.sin(t*2.1)*0.12; local dz=math.sin(t*1.7)*0.12
      local hover={x=self._target.x+dx, y=self._target.y+math.sin(t*2.0)*0.06, z=self._target.z+dz}
      self:_goto(dtime, hover, speed*0.6)
      if self._t>=self._forage_until then
        self._has_nectar=true; self._pollen_left = POLLEN_CHARGES
        self._state="return"; self._target=nil; self._flower=nil
      end

    elseif self._state=="return" then
      local entp, dir = self._home and hive_entrance_point(self._home) or nil
      if entp then
        local aim={x=entp.x+dir.x*0.2, y=entp.y, z=entp.z+dir.z*0.2}
        if self:_goto(dtime, aim, speed) then
          if self:_try_enter_hive() then return end
        end
      end
    end

    -- Leash back to hive
    if self._home and vector.distance(pos, self._home) > LEASH_R then
      self._state="return"; self._target=nil
    end

    -- Random pollination while flying daytime
    try_pollinate_under(self)
  end,
})