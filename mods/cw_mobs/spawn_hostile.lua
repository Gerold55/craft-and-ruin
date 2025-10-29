-- cw_mobs/spawn_hostile.lua
-- Hostile spawner scaffold (night checks, mobcaps, etc.) — fill in later.

local S = cw_mobs.settings
-- local U = cw_mobs.util

-- Example structure (disabled for now):
-- local accum_h = 0
-- minetest.register_globalstep(function(dtime)
--   accum_h = accum_h + dtime
--   if accum_h < S.spawn_step_hostile then return end
--   accum_h = 0
--   -- iterate cw_mobs.registry.lists.hostile with similar logic to passive
-- end)
