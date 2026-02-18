-- ============================================================================
-- biomes.lua
-- Biome selection using climate grid + elevation + slope + continentalness
-- ============================================================================

local biomes = {}

-- Elevation thresholds
local SEA = 1
local DEEP_OCEAN = -10

-- Climate grid mapping
local CLIMATE_GRID = {
    cold_dry      = "ice_wastes",
    cold_medium   = "taiga",
    cold_wet      = "spruce_forest",

    temperate_dry    = "rolling_hills",
    temperate_medium = "plains",
    temperate_wet    = "cherry_grove",

    hot_dry      = "desert",
    hot_medium   = "savanna",
    hot_wet      = "jungle",
}

-- Mesa is special: not climate-based
local function is_mesa(climate, y, slope)
    return climate.cont > 0.45 and climate.eros < -0.1 and y > 5 and y < 60
end

-- Main biome selector
function biomes.get_biome(x, z, y, slope, climate)
    -- Oceans
    if y < DEEP_OCEAN then return "deep_ocean" end
    if y < SEA then return "ocean" end

    -- Mountains
    if y > 75 then return "mountains" end

    -- Mesa (special terrain biome)
    if is_mesa(climate, y, slope) then
        return "mesa"
    end

    -- Climate grid
    local zone = climate.climate_zone
    local biome = CLIMATE_GRID[zone]

    -- Fallback
    return biome or "plains"
end

return biomes

