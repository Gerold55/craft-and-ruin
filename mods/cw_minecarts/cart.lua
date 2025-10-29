-- cw_minecarts/cart.lua
-- MTG-like rail behavior + CopperFlow power + rideable seat (flat rails)

local v   = cw_minecarts.v
local CFG = cw_minecarts.cfg
local CART_NAME = "cw_minecarts:cart"

-- Optional sit animation via player_api
local function set_sit_anim(player, sitting)
  if type(player_api) == "table" and type(player_api.set_animation) == "function" then
    player_api.set_animation(player, sitting and "sit" or "stand", 30)
  end
end

-- Lock player input while riding
local function set_riding_physics(player, riding)
  if not (player and player.is_player and player:is_player()) then return end
  if riding then
    player:set_physics_override({speed=0, jump=0, sneak=0, gravity=1})
    player:set_eye_offset({x=0,y=3.8,z=0}, {x=0,y=0,z=0})
  else
    player:set_physics_override({speed=1, jump=1, sneak=1, gravity=1})
    player:set_eye_offset({x=0,y=0,z=0}, {x=0,y=0,z=0})
  end
end

-- Read rail flags at a rounded position
local function read_rail_flags(pos)
  local n = minetest.get_node(pos)
  local d = n and minetest.registered_nodes[n.name]
  if not (d and d.groups and d.groups.rail == 1) then
    return nil
  end
  local powered = false
  if d.groups.cw_mc_powered == 1 then
    local cf = cw_minecarts and cw_minecarts.cf
    if cf and type(cf.is_pos_powered) == "function" then
      powered = cf.is_pos_powered(pos) and true or false
    end
  end
  return {
    powered  = powered,
    brake    = (d.groups.cw_mc_brake    == 1),
    detector = (d.groups.cw_mc_detector == 1),
  }
end

local function mount(self, player)
  if self.driver then return end
  if not (player and player.is_player and player:is_player()) then return end
  self.driver = player:get_player_name()
  player:set_attach(self.object, "", {x=0, y=4.2, z=0}, {x=0, y=0, z=0})
  set_riding_physics(player, true)
  set_sit_anim(player, true)
  minetest.chat_send_player(self.driver, "Mounted. W=accelerate, S=brake, Sneak=dismount (when slow).")
end

local function dismount(self)
  if not self.driver then return end
  local player = minetest.get_player_by_name(self.driver)
  if player and player.is_player and player:is_player() then
    player:set_detach()
    set_riding_physics(player, false)
    set_sit_anim(player, false)
    local p = vector.add(self.object:get_pos(), {x=0, y=0.25, z=-0.7})
    player:set_pos(p)
  end
  self.driver = nil
end

minetest.register_entity(CART_NAME, {
  initial_properties = {
    physical = false,                 -- MTG behavior
    collide_with_objects = false,
    collisionbox = {-0.5,-0.5,-0.5, 0.5,0.5,0.5},
    selectionbox = {-0.5,-0.5,-0.5, 0.5,0.5,0.5},
    visual = "mesh",
    mesh = "minecart.obj",             -- or "cube"
    textures = {"minecart.png"},
	visual_size = VIS,
    static_save = true,
    hp_max = 10,
  },

  driver       = nil,
  punched      = false,               -- one-shot impulse flag
  velocity_imp = {x=0, y=0, z=0},
  old_dir      = {x=1, y=0, z=0},
  old_pos      = nil,
  det_cooldown = 0,

  on_activate = function(self, staticdata)
    self.object:set_armor_groups({immortal=1})
    if type(staticdata) == "string" and staticdata ~= "" and string.sub(staticdata, 1, 6) == "return" then
      local data = minetest.deserialize(staticdata)
      if type(data) == "table" and data.old_dir then
        self.old_dir = data.old_dir
      end
    end
  end,

  get_staticdata = function(self)
    return minetest.serialize({ old_dir = self.old_dir })
  end,

  on_rightclick = function(self, clicker)
    if not (clicker and clicker.is_player and clicker:is_player()) then return end
    local name = clicker:get_player_name()
    if (self.driver ~= nil) and (name == self.driver) then
      local vel = self.object:get_velocity()
      local spd = v.len({x=vel.x, y=0, z=vel.z})
      if spd <= 1.0 then
        dismount(self)
      else
        minetest.chat_send_player(name, "Too fast to dismount. Tap S to brake.")
      end
    elseif (self.driver == nil) then
      mount(self, clicker)
    end
  end,

  on_detach_child = function(self, child)
    if child and child.get_player_name then
      local nm = child:get_player_name()
      if nm == self.driver then
        set_riding_physics(child, false)
        set_sit_anim(child, false)
        self.driver = nil
      end
    end
  end,

  on_punch = function(self, puncher, tflp, toolcaps, dir)
    local pos = self.object:get_pos()

    -- Sneak-punch to pick up
    if puncher and puncher.is_player and puncher:is_player() then
      local ctrl = puncher:get_player_control() or {}
      if ctrl.sneak then
        if self.driver then
          local pl = minetest.get_player_by_name(self.driver)
          if pl then
            set_riding_physics(pl, false)
            set_sit_anim(pl, false)
            pl:set_detach()
          end
          self.driver = nil
        end
        local inv = puncher:get_inventory()
        if not minetest.is_creative_enabled(puncher:get_player_name()) then
          local leftover = inv:add_item("main", "cw_minecarts:cart_item")
          if leftover and not leftover:is_empty() then
            minetest.add_item(pos, leftover)
          end
        end
        self.object:remove()
        return
      end
    end

    -- Nudge along rail axis
    local hint = cw_minecarts.vel_to_axial_dir(dir or {x=0, y=0, z=0})
    local prefer = ((math.abs(hint.x) + math.abs(hint.z)) == 1) and hint or self.old_dir
    local rail_dir = cw_minecarts.get_rail_direction(pos, prefer)
    if (rail_dir.x == 0) and (rail_dir.z == 0) then return end

    local punch_interval = 1
    if toolcaps and ((toolcaps.full_punch_interval or 0) > 0) then
      punch_interval = toolcaps.full_punch_interval
    end
    tflp = math.min(tflp or punch_interval, punch_interval)
    local f = 2 * (tflp / punch_interval)

    self.velocity_imp = {x = rail_dir.x * f, y = 0, z = rail_dir.z * f}
    self.punched = true
    self.old_dir = {x = rail_dir.x, y = 0, z = rail_dir.z}
  end,

  on_step = function(self, dtime)
    self.det_cooldown = math.max(0, self.det_cooldown - dtime)

    local pos = self.object:get_pos()
    local vel = self.object:get_velocity()

    -- Apply one-shot impulse
    if self.punched then
      vel = v.add(vel, self.velocity_imp)
      self.object:set_velocity(vel)
      self.punched = false
    elseif (math.abs(vel.x) < 0.0001) and (math.abs(vel.z) < 0.0001) then
      return
    end

    -- Driver controls
    local ctrl = nil
    if self.driver then
      local pl = minetest.get_player_by_name(self.driver)
      if pl then ctrl = pl:get_player_control() end
    end

    -- Direction from velocity (axis-locked)
    local dir = cw_minecarts.vel_to_axial_dir(vel)
    local dir_changed = not ((dir.x == self.old_dir.x) and (dir.z == self.old_dir.z))

    -- Skip re-checking same node
    if (self.old_pos ~= nil) and (not self.punched) and (not dir_changed) then
      local p1 = vector.round(pos)
      local p2 = vector.round(self.old_pos)
      if (p1.x == p2.x) and (p1.y == p2.y) and (p1.z == p2.z) then
        return
      end
    end

    -- Determine next rail direction
    local new_dir = cw_minecarts.get_rail_direction(pos, dir)
    if (new_dir.x == 0) and (new_dir.z == 0) then
      -- dead end: stop centered
      local stop_pos = vector.round(pos)
      self.object:move_to(stop_pos)
      self.object:set_velocity({x=0, y=0, z=0})
      self.object:set_acceleration({x=0, y=0, z=0})
      self.old_pos = vector.new(stop_pos)
      return
    end

    -- Snap to rail center on moving axis
    if (new_dir.z ~= 0) and (math.floor(pos.x + 0.5) ~= pos.x) then
      pos.x = math.floor(pos.x + 0.5)
    end
    if (new_dir.x ~= 0) and (math.floor(pos.z + 0.5) ~= pos.z) then
      pos.z = math.floor(pos.z + 0.5)
    end

    -- Acceleration model (MTG-like + CopperFlow/Brake + W/S)
    local acc = 0
    if ctrl and ctrl.down then acc = acc - 3.0 else acc = acc - 0.4 end
    if ctrl and ctrl.up   then acc = acc + 3.0 end

    local flags = read_rail_flags(vector.round(pos)) or {}
    if flags.brake   then acc = acc - 4.0 end
    if flags.powered then acc = math.max(acc, 2.5) end

    local speed = v.len({x=vel.x, y=0, z=vel.z})
    local next_speed = math.max(0, speed + acc * dtime)
    local maxs = math.max(1.0, CFG.max_speed)
    if next_speed > maxs then next_speed = maxs end

    local new_vel = {x = new_dir.x * next_speed, y = 0, z = new_dir.z * next_speed}
    self.object:set_acceleration({x = new_dir.x * acc, y = 0, z = new_dir.z * acc})

    -- Round on turns to avoid drift, keep Y glued to rail
    local need_move_to = false
    if dir_changed then
      pos = vector.round(pos)
      need_move_to = true
    end
    pos.y = math.floor(pos.y + 0.5)

    if need_move_to then
      self.object:set_pos(pos)
    else
      self.object:move_to(pos)
    end
    self.object:set_velocity(new_vel)

    -- Yaw like MTG
    local yaw = 0
    if (new_dir.x < 0) then
      yaw = 0.5
    elseif (new_dir.x > 0) then
      yaw = 1.5
    elseif (new_dir.z < 0) then
      yaw = 1
    end
    self.object:set_yaw(yaw * math.pi)

    -- Detector pulse (rate-limited)
    if flags.detector and (self.det_cooldown <= 0) then
      local cf = cw_minecarts and cw_minecarts.cf
      if cf and type(cf.emit_pulse) == "function" then
        cf.emit_pulse(vector.round(pos), 1, CFG.det_pulse_time)
      end
      self.det_cooldown = 0.25
    end

    self.old_pos = vector.round(pos)
    self.old_dir = {x = new_dir.x, y = 0, z = new_dir.z}
  end,
})

-- Placement item (MTG-like): under/above rail
minetest.register_craftitem("cw_minecarts:cart_item", {
  description = "Minecart",
  inventory_image = "cw_cart_item.png",
  stack_max = 1,

  on_place = function(itemstack, placer, pointed_thing)
    if not (pointed_thing and pointed_thing.type == "node") then return itemstack end

    local under = pointed_thing.under
    local above = pointed_thing.above
    local spawn = nil

    if cw_minecarts.is_rail(under) then
      spawn = vector.new(under)
    elseif cw_minecarts.is_rail(above) then
      spawn = vector.new(above)
    else
      return itemstack
    end

    local obj = minetest.add_entity(spawn, CART_NAME)
    minetest.sound_play({name = "default_place_node_metal", gain = 0.5}, {pos = spawn}, true)

    local player_name = (placer and placer.get_player_name) and placer:get_player_name() or ""
    if obj and (not minetest.is_creative_enabled(player_name)) then
      itemstack:take_item()
    end
    return itemstack
  end,
})

-- Recipe
minetest.register_craft({
  output = "cw_minecarts:cart_item",
  recipe = {
    {"default:steel_ingot", "", "default:steel_ingot"},
    {"default:steel_ingot", "default:steel_ingot", "default:steel_ingot"},
  }
})
