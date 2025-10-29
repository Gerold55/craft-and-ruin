-- cw_mobs/mobs/hostile.lua
-- Copy this to start a hostile mob; then register it:

-- minetest.register_entity("cw_mobs:thornling", { ... })

-- cw_mobs.register_spawnable("cw_mobs:thornling", "hostile", {
--   view_cap    = 10,                -- per-player cap for this mob
--   view_radius = cw_mobs.settings.view_radius,
--   weight      = 1,
--   spawn_fn    = function(ppos, ctx)
--     -- night/biome checks, ground checks, add_entity(...)
--     -- return how many spawned
--     return 0
--   end
-- })
