-- ============================================================================
-- noise.lua (Noise Manager for Terrain)
-- ============================================================================

local noise = {}
local NoiseObjects = {}

-- Noise parameter definitions
local NOISE_DEFS = {

    terrain = {
        offset = 0, scale = 1,
        spread = {x=250, y=250, z=250},
        seed = 9001, octaves = 5, persist = 0.5
    },

    mountain = {
        offset = 0, scale = 1,
        spread = {x=600, y=600, z=600},
        seed = 9002, octaves = 5, persist = 0.55
    },

    ridge = {
        offset = 0, scale = 1,
        spread = {x=150, y=150, z=150},
        seed = 9003, octaves = 4, persist = 0.5
    },

    valley = {
        offset = 0, scale = 1,
        spread = {x=300, y=300, z=300},
        seed = 9004, octaves = 4, persist = 0.5
    },

    deep = {
        offset = 0, scale = 1,
        spread = {x=400, y=400, z=400},
        seed = 9005, octaves = 4, persist = 0.5
    },

    clay = {
        offset = 0, scale = 1,
        spread = {x=80, y=80, z=80},
        seed = 9006, octaves = 3, persist = 0.5
    },

    cave = {
        offset = 0, scale = 1,
        spread = {x=100, y=100, z=100},
        seed = 9007, octaves = 3, persist = 0.5
    },
}

-- Create noise objects on demand
local function ensure_noise(name)
    if NoiseObjects[name] then
        return NoiseObjects[name]
    end

    local def = NOISE_DEFS[name]
    if not def then
        minetest.log("error", "[cw_mapgen] Unknown noise: " .. tostring(name))
        return nil
    end

    local obj = minetest.get_perlin(def)
    NoiseObjects[name] = obj
    return obj
end

-- Public API
function noise.get(name)
    return ensure_noise(name)
end

return noise

