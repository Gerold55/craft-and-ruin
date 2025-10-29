-- cw_mapgen/decorations.lua
-- Spawns reeds only where the ground (grass/dirt/sand) is adjacent to water.
-- Plains-only by default; change BIOME_NAME to match your biome registration.

local BIOME_NAME = "cw_plains"  -- adjust if your biome is named differently

-- We use a simple decoration that places a single base reed node.
-- The node itself (after_place/on_construct) grows to 2-3 tall.
-- spawn_by requires a node name, so this targets your water source node.

minetest.register_decoration({
  name = "cw_mapgen:reeds_plains_shore",
  deco_type = "simple",
  place_on = {"cw_core:grass_block", "cw_core:dirt", "cw_core:sand"},
  biomes = {BIOME_NAME},
  sidelen = 16,
  -- Only place when adjacent to water
  spawn_by = "cw_core:water_source",
  num_spawn_by = 1,

  -- Light density; increase for more reeds along shores
  fill_ratio = 0.006,

  y_min = -31000, y_max = 31000,
  decoration = "cw_core:reeds",
})
