-- ============================================================================
-- CRAFT & RUIN CAVE SYSTEM (Minecraft-style, narrow + winding)
-- ============================================================================

local c_air   = minetest.get_content_id("air")
local c_stone = minetest.get_content_id("cw_core:stone")

-- ====== CAVE NOISE FIELDS ===================================================
-- These values are tuned to produce Minecraft-like caves:
-- - narrow tunnels
-- - occasional small caverns
-- - very few giant voids

-- Tunnel noise (main carving)
local cave_tunnel_noise = PerlinNoise({
    offset = 0,
    scale = 1,
    spread = {x = 48, y = 24, z = 48},
    seed = 123456,
    octaves = 3,
    persist = 0.5,
})

-- Cavern noise (rare chambers)
local cave_cavern_noise = PerlinNoise({
    offset = 0,
    scale = 1,
    spread = {x = 96, y = 48, z = 96},
    seed = 987654,
    octaves = 2,
    persist = 0.5,
})

-- ============================================================================
-- Cave Carving Function
-- ============================================================================

function cw_mapgen_carve_caves(data, area, x, y, z, surface_y)
    -- Never carve near the surface
    if y >= surface_y - 4 then
        return
    end

    -- Get noise values
    local t = cave_tunnel_noise:get_3d({x = x, y = y, z = z})
    local c = cave_cavern_noise:get_3d({x = x, y = y, z = z})

    -- Minecraft-like thresholds:
    -- Tunnels: narrow, winding
    -- Caverns: rare, small
    local carve = false

    -- Narrow tunnels
    if math.abs(t) > 0.62 then
        carve = true
    end

    -- Small caverns
    if c > 0.70 then
        carve = true
    end

    if not carve then return end

    -- Carve only stone
    local vi = area:index(x, y, z)
    if data[vi] == c_stone then
        data[vi] = c_air
    end
end
