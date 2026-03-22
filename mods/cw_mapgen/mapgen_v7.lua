-- ============================================================================
-- SUPER SIMPLE CUSTOM MAPGEN (Stable)
-- Plains → Hills → Mountains
-- One callback, no rivers, no snow, no surfaces
-- ============================================================================

local SEA_LEVEL = 0

local c_air   = minetest.get_content_id("air")
local c_stone = minetest.get_content_id("cw_core:stone")
local c_dirt  = minetest.get_content_id("cw_core:dirt")
local c_grass = minetest.get_content_id("cw_core:grass_block")
local c_water = minetest.get_content_id("cw_core:water_source")

-- Base terrain noise
local n_base = PerlinNoise({
    offset = 0,
    scale = 1,
    spread = {x = 512, y = 512, z = 512},
    seed = 12345,
    octaves = 3,
    persist = 0.5,
})

-- Hills noise
local n_hills = PerlinNoise({
    offset = 0,
    scale = 1,
    spread = {x = 256, y = 256, z = 256},
    seed = 54321,
    octaves = 4,
    persist = 0.5,
})

-- Mountains noise
local n_mountains = PerlinNoise({
    offset = 0,
    scale = 1,
    spread = {x = 384, y = 384, z = 384},
    seed = 98765,
    octaves = 5,
    persist = 0.6,
})

-- Height function
local function get_height(x, z)
    local base = 60 + n_base:get_2d({x = x, y = z}) * 10
    local hills = math.max(0, n_hills:get_2d({x = x, y = z})) * 20
    local mountains = math.max(0, n_mountains:get_2d({x = x, y = z}) - 0.25) * 80

    local h = base + hills + mountains

    if h < 40 then h = 40 end
    if h > 140 then h = 140 end

    return math.floor(h)
end

-- ============================================================================
-- MAIN MAPGEN (one callback, stable)
-- ============================================================================

minetest.register_on_generated(function(minp, maxp)
    local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
    local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
    local data = vm:get_data()

    for z = minp.z, maxp.z do
        for x = minp.x, maxp.x do

            local h = get_height(x, z)

            -- Fill stone
            for y = minp.y, h do
                if y >= minp.y then
                    data[area:index(x, y, z)] = c_stone
                end
            end

            -- Fill air above
            for y = h + 1, maxp.y do
                data[area:index(x, y, z)] = c_air
            end

            -- Water fill
            for y = h + 1, SEA_LEVEL do
                if y >= minp.y then
                    data[area:index(x, y, z)] = c_water
                end
            end

            -- Surface grass
            if h >= minp.y then
                data[area:index(x, h, z)] = c_grass
            end
        end
    end

    vm:set_data(data)
    vm:write_to_map()
    vm:update_map()
end)

