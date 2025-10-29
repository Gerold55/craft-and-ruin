-- cw_mobs/core.lua
-- Settings, registry, utilities

local function SInt(k,d)   local v=tonumber(minetest.settings:get(k)); return v or d end
local function SFloat(k,d) local v=tonumber(minetest.settings:get(k)); return v or d end
local function SBool(k,d)  local v=minetest.settings:get_bool(k); if v==nil then return d end; return v end

cw_mobs.settings = {
  -- Global spawn cadence
  spawn_step_passive     = SFloat("cw_mobs.spawn_step_passive",     6.0),
  spawn_step_hostile     = SFloat("cw_mobs.spawn_step_hostile",     7.0),

  -- Default view bubble
  view_radius            = SInt  ("cw_mobs.view_radius",            32),

  -- Firefly defaults (can be overridden per-mob later)
  firefly_frames         = SInt  ("cw_mobs.firefly_frames",          4),
  firefly_frame_time     = SFloat("cw_mobs.firefly_frame_time",     0.15),
  firefly_night_only     = SBool ("cw_mobs.firefly_night_only",     true),
  firefly_view_cap       = SInt  ("cw_mobs.firefly_view_cap",        25),
  firefly_scan_xz        = SInt  ("cw_mobs.firefly_scan_radius_xz", 18),
  firefly_scan_y         = SInt  ("cw_mobs.firefly_scan_radius_y",   8),
  firefly_plains_skip    = SFloat("cw_mobs.firefly_plains_skip",   0.60),
  firefly_local_r        = SInt  ("cw_mobs.firefly_local_r",         8),
  firefly_local_cap      = SInt  ("cw_mobs.firefly_local_cap",       6),
  firefly_day_despawn    = SFloat("cw_mobs.firefly_day_despawn",   0.02),
  firefly_drift_repick   = SFloat("cw_mobs.firefly_drift_repick",  0.02),
}

-- Registry: each mob file registers itself here with a spawn entry.
cw_mobs.registry = {
  mobs   = {},     -- [name] = {kind="passive"/"hostile", view_cap=..., spawn_fn=..., weight=...}
  lists  = { passive = {}, hostile = {} },  -- arrays of names (preserves order/weights)
}

-- Utilities
cw_mobs.util = {}

function cw_mobs.util.is_night()
  local t = minetest.get_timeofday() or 0
  return (t <= 0.2 or t >= 0.8)
end

function cw_mobs.util.count_named(center, radius, entname)
  local n = 0
  for _,o in ipairs(minetest.get_objects_inside_radius(center, radius)) do
    local e = o:get_luaentity()
    if e and e.name == entname then n = n + 1 end
  end
  return n
end

-- Weighted choice helper (weights on registry entry, default 1)
function cw_mobs.util.weighted_pick(names)
  local total = 0
  for _,nm in ipairs(names) do total = total + (cw_mobs.registry.mobs[nm].weight or 1) end
  local r = math.random() * total
  local acc = 0
  for _,nm in ipairs(names) do
    acc = acc + (cw_mobs.registry.mobs[nm].weight or 1)
    if r <= acc then return nm end
  end
  return names[#names]
end

-- Public: register spawnable mob (called by each mob file)
-- kind = "passive"|"hostile"
-- opt fields: view_cap, view_radius, weight, spawn_fn(ppos, ctx) -> spawned_count
function cw_mobs.register_spawnable(name, kind, opt)
  assert(kind == "passive" or kind == "hostile", "kind must be passive|hostile")
  cw_mobs.registry.mobs[name] = {
    kind       = kind,
    view_cap   = opt.view_cap,     -- optional (fallback to settings or global)
    view_radius= opt.view_radius,  -- optional (fallback to global)
    weight     = opt.weight or 1,
    spawn_fn   = assert(opt.spawn_fn, "spawn_fn required"),
  }
  table.insert(cw_mobs.registry.lists[kind], name)
end
