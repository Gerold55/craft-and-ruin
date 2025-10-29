-- cw_mobs/spawn_passive.lua
-- Per-player passive spawner: iterates all registered passive mobs

local S, U = cw_mobs.settings, cw_mobs.util

-- Try to spawn one batch for a single passive mob near player ppos
local function spawn_one_passive(name, ppos)
  local entry = cw_mobs.registry.mobs[name]; if not entry then return 0 end

  local radius = entry.view_radius or S.view_radius
  local cap    = entry.view_cap    or S[name:gsub(":", "_").."_view_cap"] or 24  -- per-mob overrideable
  local have   = U.count_named(ppos, radius, name)
  if have >= cap then return 0 end

  -- Delegate to the mob's spawn_fn; it should respect caps & environment
  -- and return how many were actually spawned.
  local ctx = { settings = S, util = U, name = name, cap = cap, radius = radius }
  return entry.spawn_fn(ppos, ctx) or 0
end

local accum = 0
minetest.register_globalstep(function(dtime)
  accum = accum + dtime
  if accum < S.spawn_step_passive then return end
  accum = 0

  local list = cw_mobs.registry.lists.passive
  if #list == 0 then return end

  for _,pl in ipairs(minetest.get_connected_players()) do
    local ppos = pl:get_pos()
    if ppos then
      -- You can pick weighted or iterate all. Here: try a few weighted picks to keep it light.
      for _=1,3 do
        local name = cw_mobs.util.weighted_pick(list)
        spawn_one_passive(name, ppos)
      end
    end
  end
end)
