-- cw_atmosphere/init.lua — Minecraft-like sky & weather for Craft & Ruin
-- Engine clouds only (no particle cloud overlay).
-- Rain/snow particles tuned for visibility; storms/downpour boost only AMOUNT.
-- Blue-tinted rain like MC; stronger tint in downpour.
-- Lightning with flash + distance-delayed thunder; optional fire on strike.
-- Layered snow accumulation: 3 layers -> cw_core:snow_block (or default:snowblock).
-- Textures: sun.png, moon_1_classic.png..moon_8_classic.png, cw_rain_drop.png, cw_snow_flake.png, cw_lightning.png
-- Optional sounds: cw_thunder_close.ogg, cw_thunder_far.ogg
-- MIT License.

local atmo = {}
cw_atmo = atmo

-- ================= Settings / Constants =================
local S = minetest.settings
local APPLY_INTERVAL = 0.20

-- Biome "cold" cutoff for snow (Luanti heat scale 0..100)
local COLD_HEAT = tonumber(S:get("cw_atmo_cold_heat_threshold")) or 35

-- Accumulating snow tick
local SNOW_ENABLE  = S:get_bool("cw_atmo_snow_accumulate", true)
local SNOW_TICK_MS = tonumber(S:get("cw_atmo_snow_tick_ms")) or 900
local SNOW_TRIES   = tonumber(S:get("cw_atmo_snow_per_tick")) or 3
local SNOW_RADIUS  = tonumber(S:get("cw_atmo_snow_radius")) or 6

-- Texture names
local TEX = {
  sun   = "sun.png",
  moon  = "moon_%d_classic.png",
  rain  = "cw_rain_drop.png",
  snow  = "cw_snow_flake.png",
  bolt  = "cw_lightning.png",
}

-- Sky palette (soft MC-like)
local SKY = {
  day_sky       = "#89b4ff",
  day_horizon   = "#a9c7ff",
  dawn_sky      = "#f2a66d",
  dawn_horizon  = "#ffd0a2",
  night_sky     = "#0a1020",
  night_horizon = "#1b243e",
  indoors       = "#404040",
}

-- Engine cloud profiles (single layer, MC feel)
local PROFILES = {
  clear       = { clouds = { height=128, thickness=12, density=0.22, color="#ffffff", speed={x=0, z=-1.6} } },
  overcast    = { clouds = { height=120, thickness=28, density=0.88, color="#bfc5cc", speed={x=0, z=-2.4} } },
  night_clear = { clouds = { height=140, thickness=12, density=0.18, color="#dfe7ff", speed={x=0, z=-1.0} } },
}

-- Weather overlays (GLOBAL) — precip_amount_boost affects AMOUNT ONLY
local WEATHER = {
  drizzle = {
    priority=10, fx_rain=true, wind={x=-0.3, z=-0.4},
    clouds_delta = { density=0.18, color="#d9dde2", thickness=6 },
    precip_amount_boost = 1.0, -- light
  },
  storm = {
    priority=50, fx_rain=true, thunder=true, daynight_lock=0.30,
    wind={x=-0.8, z=-0.6},
    clouds_target = { height=118, thickness=34, density=0.95, color="#8a919a", speed={x=0, z=-3.0} },
    precip_amount_boost = 2.5, -- dense curtain
  },
  downpour = {
    priority=60, fx_rain=true, thunder=true, daynight_lock=0.25,
    wind={x=-1.1, z=-0.8},
    clouds_target = { height=115, thickness=36, density=0.98, color="#777d86", speed={x=0, z=-3.2} },
    precip_amount_boost = 3.5, -- very dense
  },
}

-- Rain particles (MC-visible; base amounts; storms/downpour multiply AMOUNT ONLY)
local RAIN = {
  box_half = 24, start_y = 11,
  amount_bg = 1800, amount_fg = 800,   -- base total ≈ 2600 (drizzle-ish)
  ttl_min = 0.65, ttl_max = 1.05,      -- crisp streaks
  vy_min  = -24,  vy_max  = -16,       -- MC-like fall speed
  size_bg_min = 2.2, size_bg_max = 2.8,
  size_fg_min = 2.8, size_fg_max = 3.6,
  opacity = 230,                       -- base opacity
  -- Blue tint (MC vibe): colorize adds blue, opacity keeps edges
  tint_hex_light = "#6ea7ff",          -- storm
  tint_hex_heavy = "#5e99ff",          -- downpour
  tint_alpha_light = 110,              -- 0..255 (how blue it looks)
  tint_alpha_heavy = 160,
}

-- Snow particles (MC-visible)
local SNOW = {
  box_half = 24, start_y = 11,
  amount_bg = 800, amount_fg = 350,
  ttl_min = 1.40, ttl_max = 2.20,
  vy_min  = -3.6, vy_max  = -2.6,
  size_bg_min = 2.0, size_bg_max = 2.6,
  size_fg_min = 2.6, size_fg_max = 3.4,
  opacity = 230,
  glow    = 1,
}

-- Lightning
local LIGHTNING_MIN_GAP, LIGHTNING_MAX_GAP = 4.0, 10.0
local LIGHTNING_NEAR_MIN, LIGHTNING_NEAR_MAX = 25, 60
local LIGHTNING_ATTEMPTS = 8
local SPEED_OF_SOUND_NPS = 340
local LIGHTNING_DAMAGE_RADIUS, LIGHTNING_DAMAGE_HP = 3.5, 8
local LIGHTNING_FIRE_CHANCE = 0.45
local LIGHTNING_FLASH_TIME  = 0.28

-- ================= State =================
local HAS_PLAYER_CLOUDS = false
local warned_no_player_clouds = false

local G = { baseline="clear", overlay=nil } -- global weather
-- per-player FX: track spawner ids (BG+FG per precip type)
local players = {} -- [name] = { fx={ rain_ids={}, snow_ids={} } }

local lightning_next_time = 0

-- ================= Helpers =================
local function clamp01(x) return (x<0 and 0) or (x>1 and 1) or x end
local function lerp(a,b,t) return a + (b-a)*t end
local function rand_between(a,b) return a + math.random()*(b-a) end

local function deepcopy(tbl)
  if type(tbl) ~= "table" then return tbl end
  local out = {}
  for k,v in pairs(tbl) do out[k] = type(v)=="table" and deepcopy(v) or v end
  return out
end

local function ensure_player(name)
  if not players[name] then players[name] = { fx = { rain_ids={}, snow_ids={} } } end
  return players[name]
end

local function is_night()
  local tod = minetest.get_timeofday() or 0.5
  return (tod <= 0.2) or (tod >= 0.8)
end

local function get_moon_phase_index()
  local day_count = (minetest.get_day_count and minetest.get_day_count()) or
                    math.floor((minetest.get_gametime() or 0) / 1200)
  return (day_count % 8) + 1
end

local function compute_target()
  local base = PROFILES[G.baseline] or PROFILES.clear
  local clouds = deepcopy(base.clouds)
  local lock_ratio, thunder = nil, false
  local wind = {x=0, z=0}
  local fx_rain = false

  if G.overlay then
    local ov = G.overlay
    local def, t = ov.def, ov.t
    if def.clouds_target then
      local ct = def.clouds_target
      clouds.height    = lerp(clouds.height or ct.height, ct.height or clouds.height, t)
      clouds.thickness = lerp(clouds.thickness or ct.thickness, ct.thickness or clouds.thickness, t)
      clouds.density   = lerp(clouds.density or ct.density, ct.density or clouds.density, t)
      if ct.color then clouds.color = ct.color end
      if ct.speed then
        clouds.speed = { x = lerp(clouds.speed.x, ct.speed.x or clouds.speed.x, t),
                         z = lerp(clouds.speed.z, ct.speed.z or clouds.speed.z, t) }
      end
    elseif def.clouds_delta then
      local d = def.clouds_delta
      if d.height    then clouds.height    = (clouds.height or 0)    + d.height end
      if d.thickness then clouds.thickness = (clouds.thickness or 0) + d.thickness end
      if d.density   then clouds.density   = clamp01((clouds.density or 0) + d.density) end
      if d.color     then clouds.color     = d.color end
      if d.speed     then clouds.speed     = { x=(clouds.speed.x + (d.speed.x or 0)),
                                               z=(clouds.speed.z + (d.speed.z or 0)) } end
    end
    if def.daynight_lock then lock_ratio = lerp(1.0, def.daynight_lock, t) end
    thunder = def.thunder and (t > 0.5) or false
    wind = def.wind or wind
    fx_rain = not not def.fx_rain
  end
  return { clouds=clouds, lock_ratio=lock_ratio, thunder=thunder, wind=wind, fx_rain=fx_rain }
end

local function should_show_sun(tgt)
  if tgt.fx_rain or tgt.thunder then return false end
  return (tgt.clouds.density or 0.3) < 0.72
end

local function should_show_moon(tgt)
  if not is_night() then return false end
  if tgt.fx_rain or tgt.thunder then return false end
  return (tgt.clouds.density or 0.3) < 0.78
end

local function is_cold_biome(pos)
  local bd = minetest.get_biome_data(pos)
  if not bd then return false end
  return (bd.heat or 50) <= COLD_HEAT
end

-- ================= Sky / Clouds =================
local function apply_sky(player, tgt)
  player:set_sky({ type="regular", sky_color=SKY, clouds=true })

  -- Sun (fixed: no boolean 'sunrise' field)
  if should_show_sun(tgt) then
    player:set_sun({
      visible = true,
      texture = TEX.sun,
      scale   = 1.0,
    })
  else
    player:set_sun({ visible=false })
  end

  -- Moon
  if should_show_moon(tgt) then
    player:set_moon({
      visible = true,
      texture = string.format(TEX.moon, get_moon_phase_index()),
      scale   = 1.0,
    })
  else
    player:set_moon({ visible=false })
  end

  -- Darkness lock in storms
  if tgt.lock_ratio then player:override_day_night_ratio(tgt.lock_ratio)
  else player:override_day_night_ratio(nil) end

  -- Engine clouds
  local c = tgt.clouds or {}
  local ok = pcall(function()
    player:set_clouds({
      height    = c.height or 128,
      density   = math.max(0, math.min(1, c.density or 0.22)),
      color     = c.color or "#ffffff",
      thickness = c.thickness or 12,
      speed     = { x = (c.speed and c.speed.x) or 0, z = (c.speed and c.speed.z) or -1.6 },
    })
  end)
  if ok then
    HAS_PLAYER_CLOUDS = true
  elseif not warned_no_player_clouds then
    warned_no_player_clouds = true
    minetest.log("warning", "[cw_atmosphere] player:set_clouds unsupported; clouds will use engine default.")
  end

  -- Subtle flash during thunder
  if tgt.thunder and math.random() < 0.02 then
    player:override_day_night_ratio(1.0)
    minetest.after(0.12, function()
      if player and player:is_player() then
        if tgt.lock_ratio then player:override_day_night_ratio(tgt.lock_ratio)
        else player:override_day_night_ratio(nil) end
      end
    end)
  end
end

-- ================= Precipitation =================
local function kill_spawner(id) if id then pcall(minetest.delete_particlespawner, id) end end

local function clear_spawner_list(list)
  if not list then return end
  for _, id in ipairs(list) do kill_spawner(id) end
  for i=#list,1,-1 do list[i]=nil end
end

local function spawn_rain(player, tgt, out_ids)
  -- Amount intensity from active overlay (sizes/speeds unchanged)
  local amount_boost = 1.0
  if G.overlay and G.overlay.def and G.overlay.def.precip_amount_boost then
    amount_boost = G.overlay.def.precip_amount_boost
  end

  local amt_bg = math.floor(RAIN.amount_bg * amount_boost)
  local amt_fg = math.floor(RAIN.amount_fg * amount_boost)

  local heavy = (amount_boost >= 1.5)           -- storms/downpour
  local very_heavy = (amount_boost >= 3.0)      -- downpour

  -- Build texture modifiers
  local tex_mod = "^[opacity:" .. tostring(heavy and 255 or RAIN.opacity)
  if heavy then tex_mod = tex_mod .. "^[brighten" end
  local tint_hex  = very_heavy and RAIN.tint_hex_heavy or RAIN.tint_hex_light
  local tint_alpha = very_heavy and RAIN.tint_alpha_heavy or RAIN.tint_alpha_light
  tex_mod = tex_mod .. "^[colorize:" .. tint_hex .. ":" .. tostring(tint_alpha)
  local glow = heavy and 1 or 0

  -- background
  local id1 = minetest.add_particlespawner({
    amount = amt_bg, time = 0, attached = player,
    minpos = {x=-RAIN.box_half, y=RAIN.start_y,     z=-RAIN.box_half},
    maxpos = {x= RAIN.box_half, y=RAIN.start_y + 2, z= RAIN.box_half},
    minvel = {x=(tgt.wind.x or 0)-0.4, y=RAIN.vy_min, z=(tgt.wind.z or 0)-0.4},
    maxvel = {x=(tgt.wind.x or 0)+0.4, y=RAIN.vy_max, z=(tgt.wind.z or 0)+0.4},
    minacc = {x=0, y=-22, z=0}, maxacc = {x=0, y=-26, z=0},
    minexptime = RAIN.ttl_min, maxexptime = RAIN.ttl_max,
    minsize = RAIN.size_bg_min, maxsize = RAIN.size_bg_max,
    collisiondetection = true, collision_removal = true, object_collision = false,
    vertical = true, glow = glow,
    texture = TEX.rain .. tex_mod,
  })
  -- foreground
  local id2 = minetest.add_particlespawner({
    amount = amt_fg, time = 0, attached = player,
    minpos = {x=-RAIN.box_half, y=RAIN.start_y,     z=-RAIN.box_half},
    maxpos = {x= RAIN.box_half, y=RAIN.start_y + 2, z= RAIN.box_half},
    minvel = {x=(tgt.wind.x or 0)-0.4, y=RAIN.vy_min, z=(tgt.wind.z or 0)-0.4},
    maxvel = {x=(tgt.wind.x or 0)+0.4, y=RAIN.vy_max, z=(tgt.wind.z or 0)+0.4},
    minacc = {x=0, y=-22, z=0}, maxacc = {x=0, y=-26, z=0},
    minexptime = RAIN.ttl_min, maxexptime = RAIN.ttl_max,
    minsize = RAIN.size_fg_min, maxsize = RAIN.size_fg_max,
    collisiondetection = true, collision_removal = true, object_collision = false,
    vertical = true, glow = glow,
    texture = TEX.rain .. tex_mod,
  })
  out_ids[1], out_ids[2] = id1, id2
end

local function spawn_snow(player, tgt, out_ids)
  -- background
  local id1 = minetest.add_particlespawner({
    amount = SNOW.amount_bg, time = 0, attached = player,
    minpos = {x=-SNOW.box_half, y=SNOW.start_y,     z=-SNOW.box_half},
    maxpos = {x= SNOW.box_half, y=SNOW.start_y + 2, z= SNOW.box_half},
    minvel = {x=(tgt.wind.x or 0)-0.25, y=SNOW.vy_min, z=(tgt.wind.z or 0)-0.25},
    maxvel = {x=(tgt.wind.x or 0)+0.25, y=SNOW.vy_max, z=(tgt.wind.z or 0)+0.25},
    minacc = {x=0, y=-1.4, z=0}, maxacc = {x=0, y=-1.8, z=0},
    minexptime = SNOW.ttl_min, maxexptime = SNOW.ttl_max,
    minsize = SNOW.size_bg_min, maxsize = SNOW.size_bg_max,
    collisiondetection = true, collision_removal = true, object_collision = false,
    vertical = true, glow = SNOW.glow,
    texture = TEX.snow .. "^[opacity:" .. tostring(SNOW.opacity),
  })
  -- foreground
  local id2 = minetest.add_particlespawner({
    amount = SNOW.amount_fg, time = 0, attached = player,
    minpos = {x=-SNOW.box_half, y=SNOW.start_y,     z=-SNOW.box_half},
    maxpos = {x= SNOW.box_half, y=SNOW.start_y + 2, z= SNOW.box_half},
    minvel = {x=(tgt.wind.x or 0)-0.25, y=SNOW.vy_min, z=(tgt.wind.z or 0)-0.25},
    maxvel = {x=(tgt.wind.x or 0)+0.25, y=SNOW.vy_max, z=(tgt.wind.z or 0)+0.25},
    minacc = {x=0, y=-1.4, z=0}, maxacc = {x=0, y=-1.8, z=0},
    minexptime = SNOW.ttl_min, maxexptime = SNOW.ttl_max,
    minsize = SNOW.size_fg_min, maxsize = SNOW.size_fg_max,
    collisiondetection = true, collision_removal = true, object_collision = false,
    vertical = true, glow = SNOW.glow,
    texture = TEX.snow .. "^[opacity:" .. tostring(SNOW.opacity),
  })
  out_ids[1], out_ids[2] = id1, id2
end

local function ensure_precip(player, pst, tgt)
  if not tgt.fx_rain then
    clear_spawner_list(pst.fx.rain_ids)
    clear_spawner_list(pst.fx.snow_ids)
    return
  end

  local cold = is_cold_biome(player:get_pos())

  if cold then
    clear_spawner_list(pst.fx.rain_ids)
    if #pst.fx.snow_ids == 0 then spawn_snow(player, tgt, pst.fx.snow_ids) end
  else
    clear_spawner_list(pst.fx.snow_ids)
    if #pst.fx.rain_ids == 0 then spawn_rain(player, tgt, pst.fx.rain_ids) end
  end
end

-- ================= Lightning =================
local function schedule_next_lightning()
  lightning_next_time = (minetest.get_us_time()/1e6) + rand_between(LIGHTNING_MIN_GAP, LIGHTNING_MAX_GAP)
end
schedule_next_lightning()

local function find_lightning_target_near(pos)
  local start_y = pos.y + 80
  for _=1, LIGHTNING_ATTEMPTS do
    local r = rand_between(LIGHTNING_NEAR_MIN, LIGHTNING_NEAR_MAX)
    local ang = math.random() * math.pi * 2
    local sx = pos.x + r * math.cos(ang)
    local sz = pos.z + r * math.sin(ang)
    local y = start_y
    local hit_y
    while y > pos.y - 200 do
      local p1 = {x=sx, y=y,   z=sz}
      local p2 = {x=sx, y=y-8, z=sz}
      local ray = minetest.raycast(p1, p2, false, true)
      local iv = ray and ray:next()
      if iv and iv.type == "node" then hit_y = math.floor(iv.above.y); break end
      y = y - 8
    end
    if hit_y then return vector.round({x=sx, y=hit_y, z=sz}) end
  end
  return nil
end

local function do_lightning_strike(hitpos, tgt)
  -- visual bolt (stacked quads)
  local top_y, seg = hitpos.y + 40, 6
  local y = top_y
  while y > hitpos.y do
    minetest.add_particlespawner({
      amount=1, time=0.05,
      minpos={x=hitpos.x-0.4, y=y, z=hitpos.z-0.4},
      maxpos={x=hitpos.x+0.4, y=y+seg, z=hitpos.z+0.4},
      minvel={x=0,y=0,z=0}, maxvel={x=0,y=0,z=0},
      minacc={x=0,y=0,z=0}, maxacc={x=0,y=0,z=0},
      minexptime=0.08, maxexptime=0.12,
      minsize=64, maxsize=96, vertical=true, glow=14,
      texture=TEX.bolt,
    })
    y = y - seg
  end

  -- flash near players
  for _, p in ipairs(minetest.get_connected_players()) do
    local dist = vector.distance(p:get_pos(), hitpos)
    if dist <= 80 then
      p:override_day_night_ratio(1.0)
      minetest.after(LIGHTNING_FLASH_TIME, function()
        if p and p:is_player() then
          if tgt and tgt.lock_ratio then p:override_day_night_ratio(tgt.lock_ratio)
          else p:override_day_night_ratio(nil) end
        end
      end)
    end
  end

  -- thunder with distance delay
  local function play_thunder_for(p)
    if not p or not p:is_player() then return end
    local dist  = vector.distance(p:get_pos(), hitpos)
    local delay = dist / SPEED_OF_SOUND_NPS
    local name  = (dist < 40) and "cw_thunder_close" or "cw_thunder_far"
    if minetest.sound_play then
      minetest.after(delay, function()
        if p and p:is_player() then
          minetest.sound_play(name, { to_player=p:get_player_name(), gain=0.9, pitch=1.0 }, true)
        end
      end)
    end
  end
  for _, p in ipairs(minetest.get_connected_players()) do play_thunder_for(p) end

  -- damage & optional fire
  local objs = minetest.get_objects_inside_radius(hitpos, LIGHTNING_DAMAGE_RADIUS)
  for _, obj in ipairs(objs) do
    if (obj.is_player and obj:is_player()) or obj:get_luaentity() then
      if obj.get_hp and obj.set_hp then
        obj:set_hp(math.max(0, obj:get_hp() - LIGHTNING_DAMAGE_HP))
      end
    end
  end
  if math.random() < LIGHTNING_FIRE_CHANCE and minetest.get_modpath("fire") then
    local p = vector.new(hitpos)
    if minetest.get_node(p).name == "air" then
      local below = {x=p.x, y=p.y-1, z=p.z}
      local def = minetest.registered_nodes[minetest.get_node(below).name]
      if def and def.walkable then minetest.set_node(p, {name="fire:basic_flame"}) end
    end
  end
end

-- ================= Layered Snow (3 layers -> block) =================
local SNOW_NODE -- leveled node for layers
do
  for _, n in ipairs({"cw_core:snow_layer", "default:snow"}) do
    local d = minetest.registered_nodes[n]
    if d and d.paramtype2 == "leveled" then SNOW_NODE = n break end
  end
end
local SNOW_BLOCK
do
  for _, n in ipairs({"cw_core:snow_block", "default:snowblock"}) do
    if minetest.registered_nodes[n] then SNOW_BLOCK = n break end
  end
end
local LAYER_UNIT, LAYERS_TO_BLOCK = 8, 3
local THRESHOLD_P2 = LAYER_UNIT * LAYERS_TO_BLOCK

local function air(pos) return minetest.get_node(pos).name == "air" end
local function top_air_above_solid(p)
  local pos = vector.round(p)
  for y = pos.y + 6, pos.y - 8, -1 do
    local here  = {x=pos.x, y=y,   z=pos.z}
    local below = {x=pos.x, y=y-1, z=pos.z}
    local nb = minetest.get_node(below).name
    local defb = minetest.registered_nodes[nb]
    if minetest.get_node(here).name == "air" and defb and defb.walkable and defb.liquidtype == "none" then
      return here
    end
  end
  return nil
end

local function add_snow_layer_at(pos)
  if not (SNOW_NODE and SNOW_BLOCK) then return end
  local n = minetest.get_node(pos)

  if n.name == SNOW_BLOCK then
    local above = {x=pos.x, y=pos.y+1, z=pos.z}
    if air(above) then
      minetest.set_node(above, {name=SNOW_NODE, param2=LAYER_UNIT})
    else
      local an = minetest.get_node(above)
      if an.name == SNOW_NODE then
        local p2 = an.param2 or 0
        if p2 < THRESHOLD_P2 - LAYER_UNIT then
          minetest.swap_node(above, {name=SNOW_NODE, param2=math.min(63, p2 + LAYER_UNIT)})
        else
          minetest.swap_node(above, {name=SNOW_BLOCK})
        end
      end
    end
    return
  end

  if n.name == "air" then
    minetest.set_node(pos, {name=SNOW_NODE, param2=LAYER_UNIT})
    return
  end

  if n.name == SNOW_NODE then
    local p2 = n.param2 or 0
    local new_p2 = math.min(63, p2 + LAYER_UNIT)
    if new_p2 >= THRESHOLD_P2 then
      minetest.swap_node(pos, {name=SNOW_BLOCK})
      if new_p2 > THRESHOLD_P2 then
        local above = {x=pos.x, y=pos.y+1, z=pos.z}
        if air(above) then minetest.set_node(above, {name=SNOW_NODE, param2=LAYER_UNIT}) end
      end
    else
      minetest.swap_node(pos, {name=SNOW_NODE, param2=new_p2})
    end
    return
  end

  local def = minetest.registered_nodes[n.name]
  if def and def.walkable and def.liquidtype == "none" then
    if air(pos) then minetest.set_node(pos, {name=SNOW_NODE, param2=LAYER_UNIT}) end
  end
end

local snow_next_time = {}
local function maybe_accumulate_snow_for(player, tgt)
  if not (SNOW_ENABLE and SNOW_NODE and SNOW_BLOCK) then return end
  if not tgt.fx_rain then return end
  local base = player:get_pos()
  if not is_cold_biome(base) then return end

  local now_ms = math.floor(minetest.get_us_time()/1000)
  local name = player:get_player_name()
  if now_ms < (snow_next_time[name] or 0) then return end
  snow_next_time[name] = now_ms + SNOW_TICK_MS

  for _=1, SNOW_TRIES do
    local dx = math.random(-SNOW_RADIUS, SNOW_RADIUS)
    local dz = math.random(-SNOW_RADIUS, SNOW_RADIUS)
    local top = top_air_above_solid({x=base.x+dx, y=base.y, z=base.z+dz})
    if top then add_snow_layer_at(top) end
  end
end

-- ================= Public API =================
local function apply_all_players()
  local tgt = compute_target()
  for name, pst in pairs(players) do
    local p = minetest.get_player_by_name(name)
    if p then
      apply_sky(p, tgt)
      ensure_precip(p, pst, tgt)
      maybe_accumulate_snow_for(p, tgt)
    end
  end
end

function atmo.set_profile(_, key)
  if PROFILES[key] then G.baseline = key end
  apply_all_players()
end

function atmo.push_weather(_, key, opts)
  local def = WEATHER[key]; if not def then return end
  opts = opts or {}
  local dur = opts.duration or 60
  local fi  = opts.fade_in or 3
  local fo  = opts.fade_out or 3
  if G.overlay and def.priority < (G.overlay.priority or 0) then return end
  G.overlay = { key=key, def=def, t=0, phase="in",
                timers={fi=fi, hold=math.max(0, dur-fi-fo), fo=fo},
                priority=def.priority or 0 }
  apply_all_players()
end

function atmo.clear_weather(_, fade_out)
  if not G.overlay then return end
  G.overlay.phase="out"
  G.overlay.timers.fo = fade_out or 1
  apply_all_players()
end

-- ================= Hooks / Loop =================
minetest.register_on_joinplayer(function(player)
  local name = player:get_player_name()
  ensure_player(name)
  local tod = minetest.get_timeofday() or 0.5
  if tod > 0.2 and tod < 0.8 then G.baseline = "clear" else G.baseline = "night_clear" end
  minetest.after(0.2, function()
    if not player or not player:is_player() then return end
    local tgt = compute_target()
    apply_sky(player, tgt)
    ensure_precip(player, players[name], tgt)
    maybe_accumulate_snow_for(player, tgt)
  end)
end)

minetest.register_on_leaveplayer(function(player)
  if not player then return end
  local name = player:get_player_name()
  local pst = players[name]
  if pst then
    clear_spawner_list(pst.fx.rain_ids)
    clear_spawner_list(pst.fx.snow_ids)
    players[name] = nil
  end
end)

local accum = 0
minetest.register_globalstep(function(dtime)
  accum = accum + dtime
  if accum < APPLY_INTERVAL then return end
  local dt = accum; accum = 0

  -- advance overlay
  if G.overlay then
    local ov = G.overlay
    if ov.phase == "in" then
      if ov.timers.fi <= 0 then ov.phase="hold"; ov.t=1
      else ov.t = clamp01(ov.t + dt / ov.timers.fi); ov.timers.fi = ov.timers.fi - dt end
    elseif ov.phase == "hold" then
      if ov.timers.hold <= 0 then ov.phase="out"
      else ov.timers.hold = ov.timers.hold - dt end
    elseif ov.phase == "out" then
      if ov.timers.fo <= 0 then G.overlay = nil
      else ov.t = clamp01(ov.t - dt / ov.timers.fo); ov.timers.fo = ov.timers.fo - dt end
    end
  end

  local tgt = compute_target()

  for name, pst in pairs(players) do
    local p = minetest.get_player_by_name(name)
    if p then
      apply_sky(p, tgt)
      ensure_precip(p, pst, tgt)
      maybe_accumulate_snow_for(p, tgt)
    end
  end

  -- lightning scheduler
  local now = minetest.get_us_time()/1e6
  local has_thunder = (G.overlay and G.overlay.def and G.overlay.def.thunder)
  if has_thunder and now >= lightning_next_time then
    local online = minetest.get_connected_players()
    if #online > 0 then
      local anchor = online[math.random(1, #online)]
      local target = find_lightning_target_near(anchor:get_pos())
      if target then do_lightning_strike(target, tgt) end
    end
    schedule_next_lightning()
  end
end)

-- ================= Chat Commands (debug) =================
minetest.register_chatcommand("atmo_profile", {
  params="<clear|overcast|night_clear>",
  description="Set baseline sky profile (global)",
  func=function(name,param)
    if PROFILES[param] then G.baseline=param; apply_all_players() end
    return true, "Profile -> "..(PROFILES[param] and param or G.baseline)
  end
})

minetest.register_chatcommand("atmo_weather", {
  params="<drizzle|storm|downpour> [seconds]",
  description="Start global weather",
  func=function(name,param)
    local key, sec = param:match("^(%S+)%s*(%S*)$")
    local dur = tonumber(sec) or 60
    if not WEATHER[key] then return false, "Unknown weather: "..tostring(key) end
    atmo.push_weather(nil, key, { duration = dur })
    return true, "Weather -> "..key.." ("..dur.."s)"
  end
})

minetest.register_chatcommand("atmo_clear", {
  params="[fade_out_sec]",
  description="Clear global weather",
  func=function(name, param)
    atmo.clear_weather(nil, tonumber(param) or 1)
    return true, "Weather cleared"
  end
})
