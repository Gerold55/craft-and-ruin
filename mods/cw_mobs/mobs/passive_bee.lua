-- cw_mobs/mobs/passive_bee.lua
local core = core
cw_mobs = rawget(_G, "cw_mobs") or {}

-------------------------
-- Config
-------------------------
local FLY_START, FLY_END = 1, 20 -- fly animation
local ATTACK_START, ATTACK_END = 21, 41
local ANIM_FPS = 20

local MAX_SPEED = 3.0
local ACCEL = 6.0
local YAW_SPEED = 5.0

local MIN_ALT = 0.6 -- above ground
local MAX_ALT = 3.0

local MAX_FORAGE_DIST = 16
local MAX_HOME_DIST = 32
local MAX_TRIP_TIME = 60 -- seconds out before forcing return

local FLOWER_HOVER_TIME_MIN = 1.5
local FLOWER_HOVER_TIME_MAX = 3.5

local POLLEN_MAX_USES = 10 -- like MC
local POLLEN_CHANCE = 0.01 -- 1% per step while above crops

local STING_RANGE = 1.3
local STING_DAMAGE = 3
local STING_LIFETIME = 4 -- seconds after sting to die

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

local function bad_weather()
  return cw_mobs.is_bad_weather and cw_mobs.is_bad_weather() or false
end

local function set_anim(self, kind)
  local o = self.object
  if not o then return end
  if kind == "attack" then
    o:set_animation({x=ATTACK_START, y=ATTACK_END}, ANIM_FPS, 0, true)
  else
    o:set_animation({x=FLY_START, y=FLY_END}, ANIM_FPS, 0, true)
  end
end

local function ground_y(pos)
  local px = math.floor(pos.x + 0.5)
  local pz = math.floor(pos.z + 0.5)
  for y = math.floor(pos.y + 1), math.floor(pos.y) - 24, -1 do
    local n = core.get_node({x=px,y=y,z=pz})
    local def = core.registered_nodes[n.name]
    if def and def.walkable then
      return y
    end
  end
  return pos.y - 24
end

local function clamp(v,a,b)
  if v < a then return a end
  if v > b then return b end
  return v
end

local function distance(a,b)
  return vector.distance(a,b)
end

local function dir_to(a,b)
  return vector.direction(a,b)
end

local function is_flower_pos(p)
  local n = core.get_node(p)
  return core.get_item_group(n.name, "flower") > 0
end

local function is_air(p)
  return core.get_node(p).name == "air"
end

local function find_home_hive(pos, radius)
  local minp = {x=pos.x-radius,y=pos.y-4,z=pos.z-radius}
  local maxp = {x=pos.x+radius,y=pos.y+4,z=pos.z+radius}
  local list = core.find_nodes_in_area(minp, maxp, {"cw_mobs:beehive","cw_mobs:beehive_full"})
  local best, best_d
  for _,hp in ipairs(list) do
    if cw_mobs.hive_space(hp) > 0 then
      local d = distance(pos, hp)
      if not best_d or d < best_d then
        best, best_d = hp, d
      end
    end
  end
  return best
end

local function find_flower_near_home(home, radius)
  if not home then return nil end
  local minp = {x=home.x-radius,y=home.y-2,z=home.z-radius}
  local maxp = {x=home.x+radius,y=home.y+3,z=home.z+radius}
  local flowers = core.find_nodes_in_area(minp, maxp, {"group:flower"})
  if #flowers == 0 then return nil end
  return flowers[math.random(1, #flowers)]
end

local function random_idle_offset(home)
  local angle = math.random() * math.pi * 2
  local r = 2 + math.random() * 4
  return {
    x = home.x + 0.5 + math.cos(angle) * r,
    y = home.y + 1.2 + math.random() * 1.0,
    z = home.z + 0.5 + math.sin(angle) * r,
  }
end

local function fly_towards(self, dtime, target, speed)
  local obj = self.object
  local pos = obj:get_pos()
  if not pos or not target then return end

  local gy = ground_y(pos)
  local min_y = gy + MIN_ALT
  local max_y = gy + MAX_ALT

  target = {
    x = target.x,
    y = clamp(target.y, min_y, max_y),
    z = target.z
  }

  local vel = obj:get_velocity() or {x=0,y=0,z=0}
  local dir = dir_to(pos, target)
  if dir.x == 0 and dir.y == 0 and dir.z == 0 then
    return
  end

  local desired = {
    x = dir.x * speed,
    y = dir.y * speed,
    z = dir.z * speed,
  }

  local ax = clamp(desired.x - vel.x, -ACCEL*dtime, ACCEL*dtime)
  local ay = clamp(desired.y - vel.y, -ACCEL*dtime, ACCEL*dtime)
  local az = clamp(desired.z - vel.z, -ACCEL*dtime, ACCEL*dtime)

  vel = {
    x = vel.x + ax,
    y = vel.y + ay,
    z = vel.z + az,
  }

  obj:set_velocity(vel)

  local yaw = obj:get_yaw() or 0
  local target_yaw = math.atan2(-vel.x, vel.z)
  local diff = (target_yaw - yaw + math.pi*3) % (math.pi*2) - math.pi
  local step = clamp(diff, -YAW_SPEED*dtime, YAW_SPEED*dtime)
  obj:set_yaw(yaw + step)
end

-------------------------
-- Entity
-------------------------
local Bee = {
  initial_properties = {
    visual = "mesh",
    mesh = "bee.glb",
    textures = {"bee.png"},
    visual_size = {x=6, y=6},
    collisionbox = {-0.25,-0.20,-0.25, 0.25,0.25,0.25},
    physical = false,
    pointable = true,
    static_save = true,
    glow = 0,
  },

  _state = "idle", -- idle, to_flower, at_flower, to_hive, leaving_hive, angry
  _home = nil,
  _target = nil, -- current target pos
  _flower = nil, -- current flower pos
  _flower_end_time = 0,

  _has_nectar = false,
  _pollen_uses = 0,

  _trip_start = 0,
  _sting_target = nil,
  _stung_at = nil,
}

function Bee:_reset_forage()
  self._flower = nil
  self._target = nil
  self._has_nectar = false
  self._pollen_uses = 0
  self._trip_start = now()
end

function Bee:set_home(pos)
  self._home = {x=pos.x, y=pos.y, z=pos.z}
end

function Bee:make_angry(player)
  if not player or not player:is_player() then return end
  self._state = "angry"
  self._sting_target = player
  set_anim(self, "attack")
end

function Bee:get_staticdata()
  return core.serialize({
    home = self._home,
    has_nectar = self._has_nectar,
    pollen_uses = self._pollen_uses,
  })
end

function Bee:on_activate(data)
  if data and data ~= "" then
    local ok, s = pcall(core.deserialize, data)
    if ok and type(s) == "table" then
      self._home = s.home
      self._has_nectar = s.has_nectar or false
      self._pollen_uses = s.pollen_uses or 0
    end
  end

  if not self._home then
    local pos = self.object:get_pos() or {x=0,y=0,z=0}
    local hive = find_home_hive(pos, 16)
    if hive then
      self:set_home(hive)
    end
  end

  self._trip_start = now()
  self._state = "idle"
  set_anim(self, "fly")
end

function Bee:on_punch(hitter)
  if hitter and hitter:is_player() then
    self:make_angry(hitter)
  end
  return true
end

local function bee_should_return_home(self)
  if not self._home then return false end
  if self._has_nectar then return true end
  if not is_day() or bad_weather() then return true end
  if (now() - (self._trip_start or now())) > MAX_TRIP_TIME then return true end
  return false
end

local function bee_choose_flower(self)
  if not self._home then return nil end
  local f = find_flower_near_home(self._home, MAX_FORAGE_DIST)
  if not f then return nil end
  return f
end

local function bee_set_state_to_flower(self, fpos)
  self._flower = {x=fpos.x, y=fpos.y, z=fpos.z}
  local gy = ground_y(self._flower)
  local alt = clamp(gy + 1.3, gy + MIN_ALT, gy + MAX_ALT)
  self._target = {x=fpos.x + 0.5, y=alt, z=fpos.z + 0.5}
  self._state = "to_flower"
end

local function bee_set_state_idle(self)
  self._state = "idle"
  self._flower = nil
  if self._home then
    self._target = random_idle_offset(self._home)
  else
    local p = self.object:get_pos() or {x=0,y=0,z=0}
    self._target = {
      x = p.x + (math.random() - 0.5) * 6,
      y = p.y + 1 + (math.random() - 0.5),
      z = p.z + (math.random() - 0.5) * 6,
    }
  end
end

local function bee_set_state_to_hive(self)
  if not self._home then
    bee_set_state_idle(self)
    return
  end
  local gate, _ = cw_mobs.hive_entrance_point(self._home)
  self._target = gate
  self._state = "to_hive"
end

local function bee_above_flower_good(self)
  if not self._flower then return false end
  local pos = self.object:get_pos()
  if not pos then return false end
  local fx = self._flower.x + 0.5
  local fz = self._flower.z + 0.5
  local dx = math.abs(pos.x - fx)
  local dz = math.abs(pos.z - fz)
  local dy = pos.y - (self._flower.y + 0.5)
  return dx <= 0.5 and dz <= 0.5 and dy >= 0.8 and dy <= 2.2
end

local function bee_try_pollinate_crops(self)
  if not self._has_nectar or self._pollen_uses <= 0 then
    return
  end
  if math.random() >= POLLEN_CHANCE then
    return
  end

  local pos = self.object:get_pos()
  if not pos then return end

  local px = math.floor(pos.x + 0.5)
  local pz = math.floor(pos.z + 0.5)

  for dy = -2, 0 do
    local p = {x=px, y=math.floor(pos.y) + dy, z=pz}
    local n = core.get_node(p)
    if n.name ~= "air" then
      local g1 = core.get_item_group(n.name, "crop")
      local g2 = core.get_item_group(n.name, "cw_crop")
      if g1 > 0 or g2 > 0 then
        if cw_mobs.grow_crop then
          cw_mobs.grow_crop(p, n)
        end
        self._pollen_uses = self._pollen_uses - 1
        if self._pollen_uses <= 0 then
          self._has_nectar = false
        end
        return
      end
    end
  end
end

local function bee_try_sting(self, dtime)
  if not self._sting_target or not self._sting_target:is_player() then
    return
  end
  local pos = self.object:get_pos()
  local tpos = self._sting_target:get_pos()
  if not pos or not tpos then return end

  local d = distance(pos, tpos)
  if d <= STING_RANGE and not self._stung_at then
    self._sting_target:punch(self.object, 0.1, {
      full_punch_interval = 1.0,
      damage_groups = {fleshy = STING_DAMAGE}
    }, dir_to(pos, tpos))

    self._stung_at = now()
    set_anim(self, "attack")
  end

  if self._stung_at then
    if (now() - self._stung_at) >= STING_LIFETIME then
      self.object:remove()
    end
  end
end

function Bee:on_step(dtime)
  local obj = self.object
  local pos = obj:get_pos()
  if not pos then return end

  -- angry behavior
  if self._state == "angry" then
    if not self._sting_target or not self._sting_target:is_player() then
      self._state = "idle"
      set_anim(self, "fly")
      bee_set_state_idle(self)
      return
    end
    local tpos = self._sting_target:get_pos()
    if tpos then
      fly_towards(self, dtime, {x=tpos.x, y=tpos.y+0.5, z=tpos.z}, MAX_SPEED)
      bee_try_sting(self, dtime)
    end
    return
  end

  -- if moved too far from home, force return
  if self._home and distance(pos, self._home) > MAX_HOME_DIST then
    self._has_nectar = true -- force them to want to go home
  end

  -- decide when to go home
  if bee_should_return_home(self) and self._state ~= "to_hive" then
    bee_set_state_to_hive(self)
  end

  -- state machine
  if self._state == "idle" or self._state == "leaving_hive" then
    if (not self._target) or distance(pos, self._target) < 0.6 then
      -- pick a flower if available
      local f = bee_choose_flower(self)
      if f then
        bee_set_state_to_flower(self, f)
      else
        bee_set_state_idle(self)
      end
    end
    fly_towards(self, dtime, self._target, MAX_SPEED * 0.6)

  elseif self._state == "to_flower" then
    if not self._flower or not is_flower_pos(self._flower) then
      bee_set_state_idle(self)
      return
    end
    fly_towards(self, dtime, self._target, MAX_SPEED * 0.9)
    if bee_above_flower_good(self) then
      self._state = "at_flower"
      self._flower_end_time = now() + math.random() * (FLOWER_HOVER_TIME_MAX - FLOWER_HOVER_TIME_MIN) + FLOWER_HOVER_TIME_MIN
    end

  elseif self._state == "at_flower" then
    if not self._flower or not is_flower_pos(self._flower) then
      bee_set_state_idle(self)
      return
    end
    -- hover in place gently
    fly_towards(self, dtime, self._target, MAX_SPEED * 0.3)
    if now() >= self._flower_end_time then
      -- gained nectar & pollen
      self._has_nectar = true
      self._pollen_uses = POLLEN_MAX_USES
      bee_set_state_to_hive(self)
    end

  elseif self._state == "to_hive" then
    if not self._home then
      bee_set_state_idle(self)
      return
    end
    local gate, _ = cw_mobs.hive_entrance_point(self._home)
    if gate then
      self._target = gate
      fly_towards(self, dtime, gate, MAX_SPEED)
      local dist_gate = distance(pos, gate)
      if dist_gate < 0.4 then
        -- try to enter
        if cw_mobs.hive_try_enter(self._home, self.object) then
          -- success: this entity is removed inside hive
          return
        else
          -- can't enter (full), loiter near hive
          bee_set_state_idle(self)
        end
      end
    else
      bee_set_state_idle(self)
    end
  end

  -- pollination while carrying pollen
  bee_try_pollinate_crops(self)
end

core.register_entity("cw_mobs:bee", Bee)