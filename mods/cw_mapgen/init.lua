-- ============================================================================
-- Craft & Ruin - Mapgen Init
-- Loads climate system, biome logic, and main mapgen
-- ============================================================================

local modpath = minetest.get_modpath("cw_mapgen")

-- Climate system (temperature, humidity, continentalness, erosion)
dofile(modpath .. "/climate.lua")

-- Biome selection (climate grid + mesa logic)
dofile(modpath .. "/biomes.lua")

-- Main terrain generator (terrain, oceans, mesa, caves, decor, trees)
dofile(modpath .. "/mapgen_v7.lua")

-- Optional: log confirmation
minetest.log("action", "[cw_mapgen] Climate-driven worldgen loaded successfully.")
