-- cw_atmosphere/init.lua
-- Unified sky + GLOBAL weather + per-player clouds + custom cloud overlay + rain/snow particles
-- + lightning + layered snow accumulation (3 layers -> snow block).
-- Sun texture forced: "sun.png"; Moon textures: "moon_1_classic.png".."moon_8_classic.png"
-- Custom textures used: sun.png, moon_*.png, cw_rain_drop.png, cw_snow_flake.png, cw_cloud_dark.png, cw_lightning.png
-- MIT License.

local atmo = {}
cw_atmo = atmo

-- ========= Settings =========
local S = minetest.settings
local APPLY_INTERVAL = 0.2

-- Visual options
local CUSTOM_CLOUD_OVERLAY = S:get_bool("cw_atmo_custom_clouds_overlay", true) -- particle cloud deck on top of engine clouds
local COLD_HEAT = tonumber(S:get("cw_atmo_cold_heat_threshold")) or 35 -- biome heat<= is snowy

-- Snow accumulation
local SNOW_ENABLE = S:get_bool("cw_atmo_snow_accumulate", true)
local SNOW_TICK_MS = tonumber(S:get("cw_atmo_snow_tick_ms")) or 900
local SNOW_TRIES = tonumber(S:get("cw_atmo_snow_per_tick")) or 3
local SNOW_RADIUS = tonumber(S:get("cw_atmo_snow_radius")) or 5

-- Texture names (change here if you rename files)
local TEX = {
  sun = "cw_sun.png",
  moon = "moon_%d_classic.png", -- %d = 1..8
  rain = "cw_rain_drop.png",
  snow = "cw_snow.png",
  cloud = "cw_cloud.png",
  bolt = "cw_lightning.png",
}

-- ========= Engine feature flags =========
local HAS_PLAYER_CLOUDS = false
local warned_no_player_clouds = false

-- ========= Sky colors (safe keys only) =========
local SKY_COLORS = {
  day_sky = "#8cb3ff",
  day_horizon = "#a4c6ff",
  dawn_sky = "#f3a871",
  dawn_horizon = "#ffd2a8",
  night_sky = "#0a1020",
  night_horizon = "#1a2038",
  indoors = "#404040",
}

-- ========= Baseline cloud profiles =========
local PROFILES = {
  clear = { clouds = { density=0.30, color="#ffffff", height=120, thickness=16, speed={x=0, z=-2} } },
  overcast = { clouds = { density=0.85, color="#cfd3d6", height=110, thickness=32, speed={x=0, z=-3} } },
  night_clear ={ clouds = { density=0.25, color="#cfd3ff", height=130, thickness=14, speed={x=0, z=-1} } },
}

-- ========= Weather overlays =========
local WEATHER = {
  drizzle = {
    priority=10, fx_rain=true, wind={x=-0.3, z=-0.4},
    clouds_delta = { density=0.20, color="#d9dde2", thickness=6, height=120, speed={x=0, z=-2} },
    sky_override = { day_horizon="#cfd3d6", dawn_horizon="#cfd3d6" },
  },
  storm = {
    priority=50, fx_rain=true, thunder=true, wind={x=-0.8, z=-0.6}, daynight_lock=0.30,
    clouds_target = { density=0.95, color="#8a919a", thickness=36, height=110, speed={x=0, z=-5} },
    sky_override = { day_sky="#9aa1ab", day_horizon="#4a4f57", dawn_sky="#9aa1ab", dawn_horizon="#7f8792",
                     night_sky="#4c5563", night_horizon="#2f3440" },
  },
  downpour = {
    priority=60, fx_rain=true, thunder=true, wind={x=-1.1, z=-0.7}, daynight_lock=0.25,
    clouds_target = { density=0.98, color="#666666", thickness=30, height=400, speed={x=0, z=-6} },
    sky_override = { day_sky="#aaaaaa", day_horizon="#333333", dawn_sky="#aaaaaa", dawn_horizon="#aaaaaa",
                     night_sky="#aaaaaa", night_horizon="#aaaaaa" },
  },
}

-- ========= FX tuning =========
-- Rain (fast)
local RAIN_BOX_HALF = 24
local RAIN_START_Y = 11
local RAIN_AMOUNT = 1400
local RAIN_TTL_MIN = 0.7
local RAIN_TTL_MAX = 1.2
local RAIN_SPEED_Y_MIN = -14
local RAIN_SPEED_Y_MAX = -20

-- Snow (slow, floaty)
local SNOW_BOX_HALF = 24
local SNOW_START_Y = 11
local SNOW_AMOUNT = 900
local SNOW_TTL_MIN = 1.4
local SNOW_TTL_MAX = 2.0
local SNOW_SPEED_Y_MIN = -2.8
local SNOW_SPEED_Y_MAX = -4.0

-- Particle cloud overlay (custom cloud texture)
local CLOUD_DECK_Y = 64
local CLOUD_BAND_HALF = 48
local CLOUD_AMOUNT_MAIN = 70
local CLOUD_AMOUNT_EXTRA = 40
local CLOUD_PART_MIN = 16
local CLOUD_PART_MAX = 48
local CLOUD_TTL_MIN = 8
local CLOUD_TTL_MAX = 15

-- ========= Lightning =========
local LIGHTNING_MIN_GAP = 4.0
local LIGHTNING_MAX_GAP = 10.0
local LIGHTNING_NEAR_MIN = 25
local LIGHTNING_NEAR_MAX = 60
local LIGHTNING_FIND_ATTEMPTS = 8
local LIGHTNING_DAMAGE_RADIUS = 3.5
local LIGHTNING_DAMAGE_HP = 8
local LIGHTNING_FIRE_CHANCE = 0.45
local LIGHTNING_SCORCH_TIME = 0.28
local SPEED_OF_SOUND_NODES_PER_SEC = 340

-- ========= Global state =========
local G = { baseline="clear", overlay=nil }
local players = {} -- [name] -> { fx={ rain_id=nil, snow_id=nil, cloud_ids={} } }

-- ========= Helpers =========
local function clamp01(x) return (x<0 and 0) or (x>1 and 1) or x end
local function lerp(a,b,t) return a + (b-a)*t end
local function rand_between(a,b) return a + math.random()*(b-a) end

local function plus_or_target(base, delta, target, t)
  local function vcopy(tbl) local o={}; for k,v in pairs(tbl or {}) do o[k]=type(v)=="table" and vcopy(v) or v end; return o end
  local res = vcopy(base or {})
  if target then
    for k,v in pairs(target) do
      if type(v)=="number" then res[k] = lerp(res[k] or v, v, t)
      elseif type(v)=="table" then res[k] = { x=lerp((res[k] and res[k].x or 0), v.x or 0, t),
                                              z=lerp((res[k] and res[k].z or 0), v.z or 0, t) }
      else res[k]=v end
    end
  elseif delta then
    for k,v in pairs(delta) do
      if type(v)=="number" then res[k] = (res[k] or 0) + v
      elseif type(v)=="table" then
        local bx,bz = (res[k] and res[k].x or 0), (res[k] and res[k].z or 0)
        res[k] = { x=bx+(v.x or 0), z=bz+(v.z or 0) }
      else res[k]=v end
    end
  end
  return res
end

local function ensure_player(name)
  if players[name] then return players[name] end
  players[name] = { fx = { rain_id=nil, snow_id=nil, cloud_ids={} } }
  return players[name]
end

-- Moon phase 1..8
local function get_moon_phase_index()
  local day_count = minetest.get_day_count and minetest.get_day_count() or nil
  if not day_count then day_count = math.floor((minetest.get_gametime() or 0) / 1200) end
  return (day_count % 8) + 1
end

-- Compute weather target
local function compute_target()
  local prof = PROFILES[G.baseline] or PROFILES.clear
  local clouds = prof.clouds
  local lock_ratio, thunder = nil, false
  local wind = {x=0, z=0}
  local fx_rain = false

  if G.overlay then
    local ov, def, t = G.overlay, G.overlay.def, G.overlay.t
    clouds = plus_or_target(clouds, def.clouds_delta, def.clouds_target, t)
    if def.daynight_lock then lock_ratio = lerp(1.0, def.daynight_lock, t) end
    thunder = def.thunder and (t > 0.5) or false
    wind = def.wind or wind
    fx_rain = not not def.fx_rain
  end
  return { clouds=clouds, lock_ratio=lock_ratio, thunder=thunder, wind=wind, fx_rain=fx_rain }
end

-- Visibility rules
local function should_show_sun(tgt)
  if tgt.fx_rain or tgt.thunder then return false end
  return (tgt.clouds and (tgt.clouds.density or 0.3) or 0.3) < 0.72
end

local function is_night_now()
  local tod = minetest.get_timeofday() or 0.5
  return (tod <= 0.2) or (tod >= 0.8)
end

local function should_show_moon(tgt)
  if not is_night_now() then return false end
  if tgt.fx_rain or tgt.thunder then return false end
  return (tgt.clouds and (tgt.clouds.density or 0.3) or 0.3) < 0.78
end

-- ========= Apply sky/clouds =========
local function apply_sky(player, tgt)
  -- sky
  local sc = {
    day_sky=SKY_COLORS.day_sky, day_horizon=SKY_COLORS.day_horizon,
    dawn_sky=SKY_COLORS.dawn_sky, dawn_horizon=SKY_COLORS.dawn_horizon,
    night_sky=SKY_COLORS.night_sky, night_horizon=SKY_COLORS.night_horizon,
    indoors=SKY_COLORS.indoors,
  }
  if G.overlay and G.overlay.def and G.overlay.def.sky_override then
    local so = G.overlay.def.sky_override
    sc.day_sky = so.day_sky or sc.day_sky
    sc.day_horizon = so.day_horizon or sc.day_horizon
    sc.dawn_sky = so.dawn_sky or sc.dawn_sky
    sc.dawn_horizon = so.dawn_horizon or sc.dawn_horizon
    sc.night_sky = so.night_sky or sc.night_sky
    sc.night_horizon = so.night_horizon or sc.night_horizon
  end
  player:set_sky({ type="regular", sky_color=sc, clouds=true })

  -- sun (FIXED Lua syntax)
  local show_sun = should_show_sun(tgt)
  if show_sun then
    player:set_sun({
      visible = true,
      texture = TEX.sun,
      scale = 1.0,
      sunrise = true,
      sunrise_visible = true,
    })
  else
    player:set_sun({
      visible = false,
      sunrise = true,
      sunrise_visible = false,
    })
  end

  -- moon
  local show_moon = should_show_moon(tgt)
  if show_moon then
    player:set_moon({
      visible = true,
      texture = string.format(TEX.moon, get_moon_phase_index()),
      scale = 1.0
    })
  else
    player:set_moon({ visible = false })
  end

  -- brightness lock
  if tgt.lock_ratio then player:override_day_night_ratio(tgt.lock_ratio)
  else player:override_day_night_ratio(nil) end

  -- per-player clouds (engine)
  local c = tgt.clouds or {}
  local ok = pcall(function()
    player:set_clouds({
      height = c.height or 120,
      density = math.max(0, math.min(1, c.density or 0.3)),
      color = c.color or "#ffffff",
      thickness = c.thickness or 16,
      speed = { x = (c.speed and c.speed.x) or 0, z = (c.speed and c.speed.z) or -2 },
    })
  end)
  if ok then HAS_PLAYER_CLOUDS = true
  elseif not warned_no_player_clouds then
    warned_no_player_clouds = true
    minetest.log("warning", "[cw_atmosphere] player:set_clouds unsupported; using particle cloud deck fallback.")
  end

  -- occasional flash during thunder
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

-- ========= Utils =========
local function is_outdoor(pos)
  local p1 = {x=pos.x, y=pos.y+1, z=pos.z}
  local p2 = {x=pos.x, y=pos.y+20, z=pos.z}
  local ray = minetest.raycast(p1,p2,false,false)
  for hit in ray do if hit.type=="node" then return false end end
  return true
end

-- ========= Precipitation (rain/snow) + Cloud overlays =========
local function kill_spawner(id) if id then pcall(minetest.delete_particlespawner, id) end end

local function is_cold_biome(pos)
  local bd = minetest.get_biome_data(pos)
  if not bd then return false end
  return (bd.heat or 50) <= COLD_HEAT
end

local function ensure_precip(player, pst, tgt)
  -- if no precip required, clear both spawners
  if not tgt.fx_rain then
    if pst.fx.rain_id then kill_spawner(pst.fx.rain_id); pst.fx.rain_id=nil end
    if pst.fx.snow_id then kill_spawner(pst.fx.snow_id); pst.fx.snow_id=nil end
    return
  end

  local cold = is_cold_biome(player:get_pos())

  -- switchers: rain vs snow
  if cold then
    if pst.fx.rain_id then kill_spawner(pst.fx.rain_id); pst.fx.rain_id=nil end
    if not pst.fx.snow_id then
      pst.fx.snow_id = minetest.add_particlespawner({
        amount = SNOW_AMOUNT, time = 0,
        attached = player,
        minpos = {x=-SNOW_BOX_HALF, y=SNOW_START_Y, z=-SNOW_BOX_HALF},
        maxpos = {x= SNOW_BOX_HALF, y=SNOW_START_Y + 2, z= SNOW_BOX_HALF},
        minvel = {x=(tgt.wind.x or 0)-0.3, y=SNOW_SPEED_Y_MAX, z=(tgt.wind.z or 0)-0.3},
        maxvel = {x=(tgt.wind.x or 0)+0.3, y=SNOW_SPEED_Y_MIN, z=(tgt.wind.z or 0)+0.3},
        minacc = {x=0, y=-1.5, z=0}, maxacc = {x=0, y=-2.0, z=0},
        minexptime = SNOW_TTL_MIN, maxexptime = SNOW_TTL_MAX,
        minsize = 1.3, maxsize = 2.2,
        collisiondetection = true, collision_removal = true, object_collision = false,
        vertical = true, glow = 0,
        texture = TEX.snow,
      })
    end
  else
    if pst.fx.snow_id then kill_spawner(pst.fx.snow_id); pst.fx.snow_id=nil end
    if not pst.fx.rain_id then
      pst.fx.rain_id = minetest.add_particlespawner({
        amount = RAIN_AMOUNT, time = 0,
        attached = player,
        minpos = {x=-RAIN_BOX_HALF, y=RAIN_START_Y, z=-RAIN_BOX_HALF},
        maxpos = {x= RAIN_BOX_HALF, y=RAIN_START_Y + 2, z= RAIN_BOX_HALF},
        minvel = {x=(tgt.wind.x or 0)-0.5, y=RAIN_SPEED_Y_MAX, z=(tgt.wind.z or 0)-0.5},
        maxvel = {x=(tgt.wind.x or 0)+0.5, y=RAIN_SPEED_Y_MIN, z=(tgt.wind.z or 0)+0.5},
        minacc = {x=0, y=-22, z=0}, maxacc = {x=0, y=-26, z=0},
        minexptime = RAIN_TTL_MIN, maxexptime = RAIN_TTL_MAX,
        minsize = 1.1, maxsize = 1.8,
        collisiondetection = true, collision_removal = true, object_collision = false,
        vertical = true, glow = 0,
        texture = TEX.rain,
      })
    end
  end
end

local function clear_cloud_deck(pst)
  for _, id in ipairs(pst.fx.cloud_ids or {}) do kill_spawner(id) end
  pst.fx.cloud_ids = {}
end

local function ensure_cloud_overlay(player, pst, tgt)
  local need = CUSTOM_CLOUD_OVERLAY or (not HAS_PLAYER_CLOUDS)
  if not need then if #pst.fx.cloud_ids > 0 then clear_cloud_deck(pst) end; return end
  if #pst.fx.cloud_ids > 0 then return end

  local function spawner(dx, dz, amt)
    return minetest.add_particlespawner({
      amount = amt, time = 0,
      attached = player,
      minpos = {x=-CLOUD_BAND_HALF, y=CLOUD_DECK_Y, z=-CLOUD_BAND_HALF},
      maxpos = {x= CLOUD_BAND_HALF, y=CLOUD_DECK_Y + 6, z= CLOUD_BAND_HALF},
      minvel = {x=dx - 0.4, y=0, z=dz - 0.4},
      maxvel = {x=dx + 0.4, y=0, z=dz + 0.4},
      minacc = {x=0, y=0, z=0}, maxacc = {x=0, y=0, z=0},
      minexptime = CLOUD_TTL_MIN, maxexptime = CLOUD_TTL_MAX,
      minsize = CLOUD_PART_MIN, maxsize = CLOUD_PART_MAX,
      collisiondetection = false, collision_removal = false, object_collision = false,
      vertical = false, glow = 0,
      texture = TEX.cloud,
    })
  end

  local windx = (tgt.wind.x or -0.6)
  local windz = (tgt.wind.z or -0.4)
  pst.fx.cloud_ids = {
    spawner(windx * 0.8, windz * 0.3, CLOUD_AMOUNT_MAIN),
    spawner(windx * 0.4, windz * 0.9, CLOUD_AMOUNT_MAIN),
    spawner(windx * 0.6, windz * 0.6, CLOUD_AMOUNT_EXTRA),
  }
end

local function update_player_fx(player, pst, tgt)
  ensure_precip(player, pst, tgt)
  ensure_cloud_overlay(player, pst, tgt)
end

-- ========= Lightning =========
local function find_lightning_target_near(pos)
  local start_y = pos.y + 80
  for _ = 1, LIGHTNING_FIND_ATTEMPTS do
    local r = rand_between(LIGHTNING_NEAR_MIN, LIGHTNING_NEAR_MAX)
    local ang = math.random() * math.pi * 2
    local sx = pos.x + r * math.cos(ang)
    local sz = pos.z + r * math.sin(ang)
    local y = start_y
    local hit_y
    while y > pos.y - 200 do
      local p1 = {x=sx, y=y, z=sz}
      local p2 = {x=sx, y=y-8, z=sz}
      local ray = minetest.raycast(p1, p2, false, true)
      local iv = ray and ray:next()
      if iv and iv.type == "node" then
        hit_y = math.floor(iv.above.y)
        break
      end
      y = y - 8
    end
    if hit_y then return vector.round({x=sx, y=hit_y, z=sz}) end
  end
  return nil
end

local function do_lightning_strike(hitpos, tgt)
  local top_y, seg_h, y = hitpos.y + 40, 6, hitpos.y + 40
  while y > hitpos.y do
    minetest.add_particlespawner({
      amount=1, time=0.05,
      minpos={x=hitpos.x-0.4, y=y, z=hitpos.z-0.4},
      maxpos={x=hitpos.x+0.4, y=y+seg_h, z=hitpos.z+0.4},
      minvel={x=0,y=0,z=0}, maxvel={x=0,y=0,z=0},
      minacc={x=0,y=0,z=0}, maxacc={x=0,y=0,z=0},
      minexptime=0.08, maxexptime=0.12,
      minsize=64, maxsize=96, vertical=true, glow=14,
      texture=TEX.bolt,
    })
    y = y - seg_h
  end

  for _, p in ipairs(minetest.get_connected_players()) do
    local dist = vector.distance(p:get_pos(), hitpos)
    if dist <= 80 then
      p:override_day_night_ratio(1.0)
      minetest.after(LIGHTNING_SCORCH_TIME, function()
        if p and p:is_player() then
          if tgt and tgt.lock_ratio then p:override_day_night_ratio(tgt.lock_ratio)
          else p:override_day_night_ratio(nil) end
        end
      end)
    end
  end

  -- Thunder with distance-based delay (Lua-safe)
local function play_thunder_for(p)
  if not p or not p:is_player() then return end
  local dist = vector.distance(p:get_pos(), hitpos)
  local delay = dist / SPEED_OF_SOUND_NODES_PER_SEC
  local name
  if dist < 40 then
    name = "cw_thunder_close"
  else
    name = "cw_thunder_far"
  end

  -- Only play if the sound exists / sound API available
  if minetest.sound_play then
    minetest.after(delay, function()
      if p and p:is_player() then
        minetest.sound_play(name, { to_player = p:get_player_name(), gain = 0.9, pitch = 1.0 }, true)
      end
    end)
  end
end

for _, p in ipairs(minetest.get_connected_players()) do
  play_thunder_for(p)
end

  local objs = minetest.get_objects_inside_radius(hitpos, LIGHTNING_DAMAGE_RADIUS)
  for _, obj in ipairs(objs) do
    if (obj.is_player and obj:is_player()) or obj:get_luaentity() then
      if obj.get_hp and obj.set_hp then obj:set_hp(math.max(0, obj:get_hp() - LIGHTNING_DAMAGE_HP)) end
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

local lightning_next_time = 0
local function schedule_next_lightning()
  lightning_next_time = (minetest.get_us_time()/1e6) + rand_between(LIGHTNING_MIN_GAP, LIGHTNING_MAX_GAP)
end
schedule_next_lightning()

-- ========= Layered Snow Accumulation =========
local SNOW_NODE do
  local c = {"cw_core:snow_layer","default:snow"}
  for _,n in ipairs(c) do local d=minetest.registered_nodes[n]; if d and d.paramtype2=="leveled" then SNOW_NODE=n break end end
end
local SNOW_BLOCK do
  local c = {"cw_core:snow_block","default:snowblock"}
  for _,n in ipairs(c) do if minetest.registered_nodes[n] then SNOW_BLOCK=n break end end
end

local LAYER_UNIT=8; local LAYERS_TO_BLOCK=3; local THRESHOLD_P2=LAYER_UNIT*LAYERS_TO_BLOCK
local function air(pos) return minetest.get_node(pos).name=="air" end
local function top_air_above_solid(p)
  local pos=vector.round(p)
  for y=pos.y+6, pos.y-8, -1 do
    local here={x=pos.x,y=y,z=pos.z}; local below={x=pos.x,y=y-1,z=pos.z}
    local nh=minetest.get_node(here).name; local nb=minetest.get_node(below).name
    local defb=minetest.registered_nodes[nb]
    if nh=="air" and defb and defb.walkable and defb.liquidtype=="none" then return here end
  end; return nil
end
local function add_snow_layer_at(pos)
  if not (SNOW_NODE and SNOW_BLOCK) then return end
  local n = minetest.get_node(pos)
  if n.name==SNOW_BLOCK then
    local above={x=pos.x,y=pos.y+1,z=pos.z}
    if air(above) then minetest.set_node(above,{name=SNOW_NODE,param2=LAYER_UNIT})
    else local an=minetest.get_node(above); if an.name==SNOW_NODE then
      local p2=an.param2 or 0
      if p2 < THRESHOLD_P2 - LAYER_UNIT then
        minetest.swap_node(above,{name=SNOW_NODE,param2=math.min(63,p2+LAYER_UNIT)})
      else minetest.swap_node(above,{name=SNOW_BLOCK}) end
    end end; return
  end
  if n.name=="air" then minetest.set_node(pos,{name=SNOW_NODE,param2=LAYER_UNIT}); return end
  if n.name==SNOW_NODE then
    local p2=n.param2 or 0; local new_p2=math.min(63,p2+LAYER_UNIT)
    if new_p2 >= THRESHOLD_P2 then
      minetest.swap_node(pos,{name=SNOW_BLOCK})
      if new_p2 > THRESHOLD_P2 then local above={x=pos.x,y=pos.y+1,z=pos.z}; if air(above) then minetest.set_node(above,{name=SNOW_NODE,param2=LAYER_UNIT}) end end
    else minetest.swap_node(pos,{name=SNOW_NODE,param2=new_p2}) end
    return
  end
  local def=minetest.registered_nodes[n.name]
  if def and def.walkable and def.liquidtype=="none" then if air(pos) then minetest.set_node(pos,{name=SNOW_NODE,param2=LAYER_UNIT}) end end
end

local snow_next_time = {}
local function maybe_accumulate_snow_for(player, tgt)
  if not (SNOW_ENABLE and SNOW_NODE and SNOW_BLOCK) then return end
  if not tgt.fx_rain then return end
  local base=player:get_pos(); if not is_cold_biome(base) then return end
  local name=player:get_player_name(); local now_ms=math.floor(minetest.get_us_time()/1000)
  if now_ms < (snow_next_time[name] or 0) then return end
  snow_next_time[name] = now_ms + SNOW_TICK_MS
  for _=1, SNOW_TRIES do
    local dx=math.random(-SNOW_RADIUS,SNOW_RADIUS); local dz=math.random(-SNOW_RADIUS,SNOW_RADIUS)
    local top=top_air_above_solid({x=base.x+dx,y=base.y,z=base.z+dz})
    if top and is_outdoor(top) then add_snow_layer_at(top) end
  end
end

-- ========= Public API =========
local function apply_all_players()
  local tgt = compute_target()
  for name,pst in pairs(players) do
    local p=minetest.get_player_by_name(name)
    if p then
      apply_sky(p,tgt)
      update_player_fx(p,pst,tgt)
      maybe_accumulate_snow_for(p,tgt)
    end
  end
end

function atmo.set_profile(_, key)
  if PROFILES[key] then G.baseline=key end
  apply_all_players()
end

function atmo.push_weather(_, key, opts)
  local def=WEATHER[key]; if not def then return end
  opts=opts or {}; local dur=opts.duration or 60; local fi=opts.fade_in or 3; local fo=opts.fade_out or 3
  if G.overlay and def.priority < (G.overlay.priority or 0) then return end
  G.overlay = { key=key, def=def, t=0, phase="in", timers={fi=fi, hold=math.max(0, dur-fi-fo), fo=fo}, priority=def.priority or 0 }
  apply_all_players()
end

function atmo.clear_weather(_, fade_out)
  if not G.overlay then return end
  G.overlay.phase="out"; G.overlay.timers.fo = fade_out or 1
  apply_all_players()
end

-- ========= Hooks =========
minetest.register_on_joinplayer(function(player)
  ensure_player(player:get_player_name())
  local tod=minetest.get_timeofday() or 0.5
  if tod>0.2 and tod<0.8 then G.baseline="clear" else G.baseline="night_clear" end
  minetest.after(0.2, function()
    if not player or not player:is_player() then return end
    local tgt=compute_target()
    apply_sky(player,tgt)
    update_player_fx(player, players[player:get_player_name()], tgt)
    maybe_accumulate_snow_for(player,tgt)
  end)
end)

minetest.register_on_leaveplayer(function(player)
  if not player then return end
  local pst=players[player:get_player_name()]
  if pst then
    if pst.fx.rain_id then kill_spawner(pst.fx.rain_id) end
    if pst.fx.snow_id then kill_spawner(pst.fx.snow_id) end
    if pst.fx.cloud_ids then for _,id in ipairs(pst.fx.cloud_ids) do kill_spawner(id) end end
    players[player:get_player_name()] = nil
  end
end)

-- ========= Globalstep =========
local accum=0
minetest.register_globalstep(function(dtime)
  accum = accum + dtime
  if accum < APPLY_INTERVAL then return end
  local dt=accum; accum=0

  if G.overlay then
    local ov=G.overlay
    if ov.phase=="in" then
      if ov.timers.fi<=0 then ov.phase="hold"; ov.t=1
      else ov.t=clamp01(ov.t + dt/ov.timers.fi); ov.timers.fi=ov.timers.fi - dt end
    elseif ov.phase=="hold" then
      if ov.timers.hold<=0 then ov.phase="out"
      else ov.timers.hold=ov.timers.hold - dt end
    elseif ov.phase=="out" then
      if ov.timers.fo<=0 then G.overlay=nil
      else ov.t=clamp01(ov.t - dt/ov.timers.fo); ov.timers.fo=ov.timers.fo - dt end
    end
  end

  local tgt=compute_target()
  for name,pst in pairs(players) do
    local p=minetest.get_player_by_name(name)
    if p then
      apply_sky(p,tgt)
      update_player_fx(p,pst,tgt)
      maybe_accumulate_snow_for(p,tgt)
    end
  end

  local now=minetest.get_us_time()/1e6
  if (G.overlay and G.overlay.def and G.overlay.def.thunder) and now >= lightning_next_time then
    local online=minetest.get_connected_players()
    if #online>0 then
      local anchor=online[math.random(1,#online)]
      local target=find_lightning_target_near(anchor:get_pos())
      if target then do_lightning_strike(target,tgt) end
    end
    schedule_next_lightning()
  end
end)

-- ========= Chat commands =========
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
    local key,sec = param:match("^(%S+)%s*(%S*)$")
    local dur = tonumber(sec) or 60
    if not WEATHER[key] then return false, "Unknown weather: "..tostring(key) end
    atmo.push_weather(nil, key, {duration=dur})
    return true, "Weather -> "..key.." ("..dur.."s)"
  end
})

minetest.register_chatcommand("atmo_clear", {
  params="[fade_out_sec]",
  description="Clear global weather",
  func=function() atmo.clear_weather(nil,1); return true,"Weather cleared" end
})