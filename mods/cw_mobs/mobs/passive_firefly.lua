-- cw_mobs/mobs/passive_firefly.lua
-- Firefly: 2x1 frames, 7-frame vertical sheet (2x7 total).
-- Cosmetic glow + brief real world-light flash (tiny invisible node).
-- FPS-friendly; robust settings; safe-guards around spawning.

local S, U = cw_mobs.settings, cw_mobs.util

-- --------------------------
-- Robust numeric settings
-- --------------------------
local function numset(key, default)
  local v = core.settings:get(key)
  if v == nil or v == "" then return default end
  v = tonumber(v)
  return v or default
end

-- Animation / visuals
local FRAMES                = 7
local FRAME_TIME            = numset("cw_mobs.firefly_frame_time", 0.12)  -- seconds per frame
local NIGHT_ONLY            = true

-- Entity (cosmetic) glow pulse
local GLOW_BASE             = numset("cw_mobs.firefly_glow_base", 3)
local GLOW_AMP              = numset("cw_mobs.firefly_glow_amp",  2)
local GLOW_FREQ             = numset("cw_mobs.firefly_glow_freq", 2.0)    -- pulses/sec
local PEAK_GLOW             = GLOW_BASE + GLOW_AMP

-- World light flash (node-based)
local FLASH_GLOW            = numset("cw_mobs.firefly_flash_glow", 10)     -- 1..14 (typical 8..14)
local FLASH_LIFETIME        = numset("cw_mobs.firefly_flash_time", 0.20)   -- seconds
local FLASH_CHANCE          = numset("cw_mobs.firefly_flash_chance", 0.35) -- 0..1 chance on peak
local FLASH_COOLDOWN        = numset("cw_mobs.firefly_flash_cooldown", 1.0) -- seconds per firefly

-- Spawn / density
local VIEW_RADIUS           = numset("cw_mobs.firefly_view_radius", S.view_radius or 32)
local VIEW_CAP              = numset("cw_mobs.firefly_view_cap",    28)    -- max per-player
local SCAN_R_XZ             = numset("cw_mobs.firefly_scan_radius_xz", 16)
local SCAN_R_Y              = numset("cw_mobs.firefly_scan_radius_y",   6)
local PLAINS_SKIP_CHANCE    = numset("cw_mobs.firefly_plains_skip",    0.60)
local LOCAL_R               = numset("cw_mobs.firefly_local_r",         8)
local LOCAL_CAP             = numset("cw_mobs.firefly_local_cap",       7)

-- Drift
local DRIFT_REPICK_CHANCE   = 0.025

-- --------------------------
-- Invisible light node (real light)
-- Requires textures/cw_mobs_empty.png (1x1 fully transparent)
-- --------------------------
core.register_node("cw_mobs:light_pulse", {
  description = "CW Light Pulse (invisible)",
  drawtype = "airlike",
  tiles = {"cw_mobs_empty.png"},
  paramtype = "light",
  sunlight_propagates = true,
  walkable = false,
  pointable = false,
  diggable = false,
  buildable_to = true,
  floodable = true,
  groups = {not_in_creative_inventory = 1},
  drop = "",
  light_source = FLASH_GLOW,
})

-- --------------------------
-- Firefly entity (REGISTERED FIRST, before any spawn code)
-- --------------------------
core.register_entity("cw_mobs:firefly", {
  initial_properties = {
    visual = "upright_sprite",
    textures = {"cw_mobs_firefly_anim.png"}, -- 2 px wide × 7 px tall; frames are 2x1 stacked vertically
    spritediv = {x = 1, y = FRAMES},
    initial_sprite_basepos = {x = 0, y = 0},

    -- Keep the 2:1 look (wider than tall) to match 2×1 frame
    visual_size = {x = 0.20, y = 0.10},

    use_texture_alpha = "blend",
    physical = false,
    collide_with_objects = false,
    pointable = false,

    glow = GLOW_BASE, -- cosmetic brightness on the sprite itself
    static_save = true,

    collisionbox = {-0.04,-0.05,-0.04, 0.04,0.05,0.04},
    nametag = "",
    makes_footstep_sound = false,
  },

  on_activate = function(self)
    self._t = 0
    self._frame = 0
    self._pulse_t = 0
    self._last_glow = GLOW_BASE
    self._drift = {x=0, y=0, z=0}
    self._next_flash_at = 0
  end,

  on_step = function(self, dtime)
    -- Optional: despawn slowly by day
    if NIGHT_ONLY and not (U and U.is_night and U.is_night()) then
      if math.random() < 0.02 then self.object:remove(); return end
    end

    -- Animate the sprite sheet
    self._t = self._t + dtime
    if self._t >= FRAME_TIME then
      self._t = self._t - FRAME_TIME
      self._frame = (self._frame + 1) % FRAMES
      self.object:set_sprite({x=0, y=self._frame}, 0, 0, true)
    end

    -- Gentle drift
    if math.random() < DRIFT_REPICK_CHANCE then
      self._drift = {
        x = (math.random() - 0.5) * 0.30,
        y = (math.random() - 0.35) * 0.20,
        z = (math.random() - 0.5) * 0.30,
      }
    end
    self.object:set_velocity(self._drift)

    -- Cosmetic glow pulse (entity-only brightness)
    self._pulse_t = self._pulse_t + dtime
    local night = (U and U.is_night and U.is_night()) or false
    local s = (math.sin(self._pulse_t * math.pi * 2 * GLOW_FREQ) * 0.5 + 0.5) * (night and 1.0 or 0.6)
    local g = math.floor(GLOW_BASE + GLOW_AMP * s + 0.5)
    if g ~= self._last_glow then
      self.object:set_properties({glow = g})

      -- On peak -> try brief world-light flash (node)
      if g >= PEAK_GLOW and self._last_glow < PEAK_GLOW then
        local now = core.get_gametime()
        if now >= (self._next_flash_at or 0) and math.random() < FLASH_CHANCE then
          local p = self.object:get_pos()
          if p then
            local np = {x = math.floor(p.x + 0.5), y = math.floor(p.y + 0.5), z = math.floor(p.z + 0.5)}

            -- only place in air/buildable_to and not protected
            local ok, n = false, core.get_node_or_nil(np)
            if n and not (core.is_protected and core.is_protected(np, "")) then
              if n.name == "air" then ok = true
              else
                local def = core.registered_nodes[n.name]
                ok = def and def.buildable_to
              end
            end

            if ok then
              core.set_node(np, {name = "cw_mobs:light_pulse"})
              core.after(FLASH_LIFETIME, function(pos2)
                local nn = core.get_node(pos2)
                if nn and nn.name == "cw_mobs:light_pulse" then core.remove_node(pos2) end
              end, np)
              self._next_flash_at = now + FLASH_COOLDOWN
            end
          end
        end
      end

      self._last_glow = g
    end
  end,

  -- Ambient: ignore punches
  on_punch = function(self) return true end,
})

-- --------------------------
-- Spawning (tree-biased, FPS-friendly), defined AFTER entity registration
-- --------------------------
local function try_spawn_firefly_at(pos)
  -- If for any reason the entity isn't registered yet, bail gracefully and log
  if not core.registered_entities["cw_mobs:firefly"] then
    core.log("error", "[cw_mobs] Firefly entity not registered yet; skipping spawn")
    return false
  end

  local feet = {x=pos.x, y=pos.y, z=pos.z}
  local head = {x=pos.x, y=pos.y+1, z=pos.z}
  local fdef = core.registered_nodes[core.get_node(feet).name]
  local hdef = core.registered_nodes[core.get_node(head).name]
  if fdef and hdef and (not fdef.walkable) and (not hdef.walkable) then
    if (not NIGHT_ONLY) or (U and U.is_night and U.is_night()) then
      local ok, obj = pcall(core.add_entity, feet, "cw_mobs:firefly")
      if ok and obj then return true end
      core.log("error", "[cw_mobs] add_entity failed for cw_mobs:firefly at "
        .. core.pos_to_string(feet))
    end
  end
  return false
end

local function spawn_fireflies(ppos, ctx)
  if NIGHT_ONLY and not (U and U.is_night and U.is_night()) then return 0 end

  local cap    = ctx.cap or VIEW_CAP
  local radius = ctx.radius or VIEW_RADIUS
  local have   = U.count_named(ppos, radius, "cw_mobs:firefly")
  if have >= cap then return 0 end

  -- scan for leaves near player
  local minp = {x=ppos.x - SCAN_R_XZ, y=ppos.y - SCAN_R_Y, z=ppos.z - SCAN_R_XZ}
  local maxp = {x=ppos.x + SCAN_R_XZ, y=ppos.y + SCAN_R_Y, z=ppos.z + SCAN_R_XZ}
  local leaves, counts = core.find_nodes_in_area(minp, maxp, {"group:leaves"})
  local leaf_n = (counts and (counts["group:leaves"] or 0)) or (#leaves or 0)

  -- conservative tries to save FPS
  local tries
  if leaf_n >= 400 then      tries = 5
  elseif leaf_n >= 250 then  tries = 4
  elseif leaf_n >= 100 then  tries = 3
  elseif leaf_n >= 30  then  tries = 2
  else                       tries = 1 end

  local spawned = 0
  for _=1,tries do
    if have + spawned >= cap then break end
    local base
    if leaf_n >= 30 and leaves and #leaves > 0 then
      local lp = leaves[math.random(#leaves)]
      base = {
        x = lp.x + (math.random()-0.5)*2.6,
        y = lp.y + 1 + math.random(0, 2),
        z = lp.z + (math.random()-0.5)*2.6,
      }
    else
      base = {
        x = ppos.x + math.random(-10, 10),
        y = ppos.y + math.random(-1, 2),
        z = ppos.z + math.random(-10, 10),
      }
      if math.random() < PLAINS_SKIP_CHANCE then goto continue end
    end

    if U.count_named(base, LOCAL_R, "cw_mobs:firefly") <= LOCAL_CAP then
      if try_spawn_firefly_at(base) then
        spawned = spawned + 1
      end
    end
    ::continue::
  end

  return spawned
end

-- Register with your modular framework (AFTER all the above exists)
cw_mobs.register_spawnable("cw_mobs:firefly", "passive", {
  view_cap    = VIEW_CAP,
  view_radius = VIEW_RADIUS,
  weight      = 3,
  spawn_fn    = spawn_fireflies,
})
