-- ============================================================================
-- cw_mapgen: mapgen_pools.lua
-- Rare natural water pools for meadow biome (Minecraft-style)
-- ============================================================================

local c_water = minetest.get_content_id("cw_core:water_source")
local c_air   = minetest.CONTENT_AIR

-- Very rare, large-scale noise
local n_pools = minetest.get_perlin({
    offset = 0,
    scale = 1,
    spread = {x = 512, y = 512, z = 512},
    seed = 94123,
    octaves = 1,
    persist = 0.5,
})

-- API FUNCTION
-- Called by main mapgen AFTER terrain is placed
function cw_mapgen_generate_pools(vm, area, data, minp, maxp, heightmap, biomemap)
    for z = minp.z, maxp.z do
        for x = minp.x, maxp.x do
            local pool_noise = n_pools:get_2d({x = x, y = z})
            if pool_noise <= 0.55 then
                goto continue_x
            end

            -- Only meadow biome
            if biomemap[z][x] ~= "meadow" then
                goto continue_x
            end

            local surface_y = heightmap[z][x]
            if not surface_y then
                goto continue_x
            end

            -- Organic shape
            local radius = 4 + math.random(0, 2)

            for dz = -radius, radius do
                for dx = -radius, radius do
                    local dist = math.sqrt(dx * dx + dz * dz)
                    if dist > radius then
                        goto continue_dx
                    end

                    local px = x + dx
                    local pz = z + dz
                    local py = surface_y - math.floor((radius - dist) * 0.6)

                    local vi_air = area:index(px, py + 1, pz)
                    local vi_water = area:index(px, py, pz)

                    data[vi_air] = c_air
                    data[vi_water] = c_water

                    ::continue_dx::
                end
            end

            ::continue_x::
        end
    end
end
