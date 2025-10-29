-- cw_core/falling_leaves.lua
-- Biome-tinted falling leaves (bursts, wind, proximity), with safe wind init.

local modname = "cw_core"
cw_core = rawget(_G, "cw_core") or {}

-- ================== TUNABLES ==================
local ABM_INTERVAL        = 5
local ABM_CHANCE          = 10
local PLAYER_RADIUS       = 32
local BURST_MIN           = 2
local BURST_MAX           = 5
local SIZE_MIN            = 0.70
local SIZE_MAX            = 1.05
local LIFE_MIN            = 1.8
local LIFE_MAX            = 3.2
local BASE_SINK_MIN       = -0.55
local BASE_SINK_MAX       = -1.15
local SWAY_H              = 0.35
local WIND_STRENGTH       = 0.35
local MIN_LIGHT           = 8
local GLOW                = 0

-- Palette → hex swatches (top=dry .. bottom=lush)
local FOLIAGE_HEX16 = {
  "#7a6e3a","#807642","#877f49","#8f884f",
  "#959454","#9ca85a","#a2b661","#85c063",
  "#78c761","#6dcb5f","#62cf5d","#58d45a",
  "#4fda57","#45df54","#3de351","#34e84e",
}

-- ================== PALETTE INDEX MAPPING ==================
local foliage_idx_from_humidity = cw_core.foliage_humidity_to_palette
if type(foliage_idx_from_humidity) ~= "function" then
  local settings = minetest.settings
  local function clamp(a, lo, hi) if a<lo then return lo elseif a>hi then return hi else return a end end
  local F_MIN   = tonumber(settings:get("cw_foliage_palette_min_idx")) or 2
  local F_MAX   = tonumber(settings:get("cw_foliage_palette_max_idx")) or 14
  local F_GAMMA = tonumber(settings:get("cw_foliage_palette_gamma"))  or 0.9
  F_MIN  = clamp(math.floor(F_MIN+0.5), 0, 15)
  F_MAX  = clamp(math.floor(F_MAX+0.5), 0, 15)
  if F_MAX < F_MIN then F_MIN, F_MAX = F_MAX, F_MIN end
  foliage_idx_from_humidity = function(h)
    h = clamp(h or 50, 0, 100)
    local t = (h / 100) ^ F_GAMMA
    return clamp(math.floor(F_MIN + t * (F_MAX - F_MIN) + 0.5), 0, 15)
  end
end

local function humidity_at(pos)
  local ok, data = pcall(minetest.get_biome_data, pos)
  return (ok and data and data.humidity) or 50
end

local function foliage_hex_at(pos)
  local idx = foliage_idx_from_humidity(humidity_at(pos)) or 8
  if idx < 0 then idx = 0 elseif idx > 15 then idx = 15 end
  return FOLIAGE_HEX16[idx + 1]
end

-- ================== WIND (safe lazy init) ==================
local wind_noise -- may remain nil; we handle fallback
local function get_wind_noise()
  if wind_noise == nil then
    local ok, noise = pcall(minetest.get_perlin, {
      offset=0, scale=1,
      spread={x=256,y=256,z=256},
      seed=13579, octaves=2, persist=0.6
    })
    if ok and noise then wind_noise = noise else wind_noise = false end
  end
  return wind_noise or false
end

local function wind_vec(pos)
  local t = minetest.get_gametime()
  local wn = get_wind_noise()
  if wn then
    local wx = wn:get_3d({x=pos.x*0.05,     y=t*0.02, z=pos.z*0.05    })
    local wz = wn:get_3d({x=pos.x*0.05+2000,y=t*0.02, z=pos.z*0.05-2000})
    return { x = wx * WIND_STRENGTH, y = 0, z = wz * WIND_STRENGTH }
  else
    -- Fallback: deterministic sine/cos based “wind”
    local wx = math.sin((pos.x+0.5)*0.05 + t*0.25) * WIND_STRENGTH
    local wz = math.cos((pos.z-0.5)*0.05 + t*0.21) * WIND_STRENGTH
    return { x = wx, y = 0, z = wz }
  end
end

-- ================== FILTERS ==================
local function is_airlike(name)
  local def = minetest.registered_nodes[name]; if not def then return false end
  return (not def.walkable) or def.buildable_to
end

local function has_player_near(pos, r)
  local objs = minetest.get_objects_inside_radius(pos, r or PLAYER_RADIUS)
  for _,o in ipairs(objs) do
    if o:is_player() then return true end
  end
  return false
end

local function nice_for_particles(pos)
  if not has_player_near(pos, PLAYER_RADIUS) then return false end
  local nn = minetest.get_node(pos).name
  local def = minetest.registered_nodes[nn]
  if def and def.groups and (def.groups.water or 0) > 0 then return false end
  local below = {x=pos.x, y=pos.y-1, z=pos.z}
  if not is_airlike(minetest.get_node(below).name) then return false end
  local light = minetest.get_node_light(pos) or 0
  return light >= MIN_LIGHT
end

-- ================== ABM: BURST SPAWNER ==================
minetest.register_abm({
  label     = "cw_core:falling_leaves_visible",
  nodenames = {"group:leaves"},
  interval  = ABM_INTERVAL,
  chance    = ABM_CHANCE,
  action = function(pos, node)
    if not nice_for_particles(pos) then return end

    local hex  = foliage_hex_at(pos)
    local tex  = "cw_leaf.png^[multiply:" .. hex
    local wind = wind_vec(pos)

    local burst = math.random(BURST_MIN, BURST_MAX)
    local minpos = {x=pos.x-0.35, y=pos.y-0.1, z=pos.z-0.35}
    local maxpos = {x=pos.x+0.35, y=pos.y+0.15, z=pos.z+0.35}

    for _=1, burst do
      local swayx = (math.random() * 2 - 1) * SWAY_H
      local swayz = (math.random() * 2 - 1) * SWAY_H
      local vxmin = wind.x + math.min(0, swayx)
      local vxmax = wind.x + math.max(0, swayx)
      local vzmin = wind.z + math.min(0, swayz)
      local vzmax = wind.z + math.max(0, swayz)

      minetest.add_particlespawner({
        amount = 1,
        time   = 0.02,

        minpos = minpos, maxpos = maxpos,
        minvel = {x=vxmin, y=BASE_SINK_MIN, z=vzmin},
        maxvel = {x=vxmax, y=BASE_SINK_MAX, z=vzmax},
        minacc = {x=wind.x*0.15, y=-0.06, z=wind.z*0.15},
        maxacc = {x=wind.x*0.25, y=-0.10, z=wind.z*0.25},

        minexptime = LIFE_MIN, maxexptime = LIFE_MAX,
        minsize = SIZE_MIN,    maxsize = SIZE_MAX,

        collisiondetection = true,
        collision_removal  = true,
        object_collision   = false,

        vertical = false,
        glow     = GLOW,

        texture = tex,
      })
    end
  end
})
