-- ============================================================================
-- CRAFT & RUIN WATER SYSTEM (FINAL, SIMPLE, NO FLOATING)
-- Lakes + puddles only (no rivers yet)
-- ============================================================================

local c_air   = minetest.get_content_id("air")
local c_water = minetest.get_content_id("cw_core:water_source")

local function safe_index(area, x, y, z, minp, maxp)
    if x < minp.x or x > maxp.x then return nil end
    if y < minp.y or y > maxp.y then return nil end
    if z < minp.z or z > maxp.z then return nil end
    return area:index(x, y, z)
end

local function carve_bowl(data, area, cx, cz, h, radius, depth, minp, maxp)
    for dx = -radius, radius do
        for dz = -radius, radius do
            local dist = math.sqrt(dx*dx + dz*dz)
            if dist <= radius then
                local x = cx + dx
                local z = cz + dz
                local drop = math.floor((1 - dist / radius) * depth)

                for y = h, h - drop, -1 do
                    local vi = safe_index(area, x, y, z, minp, maxp)
                    if vi then data[vi] = c_air end
                end

                local vy = h - drop
                local vi2 = safe_index(area, x, vy, z, minp, maxp)
                if vi2 then data[vi2] = c_water end
            end
        end
    end
end

function cw_mapgen_generate_water(data, area, x, z, h, biome, pr, minp, maxp)
    -- LAKES (rare)
    if biome ~= "desert" and pr:next(1, 4500) == 1 then
        if h <= minp.y + 6 then return end

        local radius = pr:next(4, 10)
        local depth  = pr:next(2, 4)

        if x - radius < minp.x or x + radius > maxp.x then return end
        if z - radius < minp.z or z + radius > maxp.z then return end

        carve_bowl(data, area, x, z, h, radius, depth, minp, maxp)
        return
    end

    -- PUDDLES (common)
    if biome ~= "desert" and pr:next(1, 600) == 1 then
        if h <= minp.y + 3 then return end

        local radius = pr:next(1, 2)

        if x - radius < minp.x or x + radius > maxp.x then return end
        if z - radius < minp.z or z + radius > maxp.z then return end

        carve_bowl(data, area, x, z, h, radius, 1, minp, maxp)
        return
    end
end
