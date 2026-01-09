-- ============================================================================
-- Craft & Ruin — Standalone Mapgen (Explicit Climate Boundaries)
-- ============================================================================

local core = core

-- 1. GLOBAL SETTINGS
core.set_mapgen_setting("mg_name", "singlenode", true)
core.set_mapgen_setting("water_level", "63", true)
core.set_mapgen_setting("mg_flags", "nolight", true)

-- 2. THE CLEANER
core.clear_registered_biomes()
core.clear_registered_decorations()

-- 3. BIOME REGISTRATION (The Hard Walls)
-- We define these strictly so the Decoration Engine knows exactly where is where.
core.register_biome({
    name = "beach",
    y_min = 62, y_max = 64,
    heat_point = 50, humidity_point = 50,
})

core.register_biome({
    name = "desert",
    y_min = 65, y_max = 31000,
    min_heat = 70, -- DESERT ONLY EXISTS IF HEAT > 70
    heat_point = 90, humidity_point = 10,
})

core.register_biome({
    name = "meadow",
    y_min = 65, y_max = 31000,
    max_heat = 69, -- MEADOW ONLY EXISTS IF HEAT < 70
    heat_point = 50, humidity_point = 40,
})

-- 4. OPTIMIZATION LOCALS
local SEALEVEL = 63
local floor, max, min = math.floor, math.max, math.min

local c_air   = core.CONTENT_AIR
local c_stone = core.get_content_id("cw_core:stone")
local c_dirt  = core.get_content_id("cw_core:dirt")
local c_grass = core.get_content_id("cw_core:grass_block")
local c_sand  = core.get_content_id("cw_core:sand")
local c_water = core.get_content_id("cw_core:water_source")

-- 5. NOISE PARAMS
local np_cont  = { offset = 0, scale = 1, spread = {x=1200, y=1200, z=1200}, seed = 11, octaves = 4, persist = 0.5 }
local np_hills = { offset = 0, scale = 1, spread = {x=220, y=220, z=220}, seed = 99, octaves = 4, persist = 0.55 }
local np_heat  = { offset = 0, scale = 1, spread = {x=1200, y=1200, z=1200}, seed = 44, octaves = 3, persist = 0.5 }
local np_humid = { offset = 0, scale = 1, spread = {x=1200, y=1200, z=1200}, seed = 55, octaves = 3, persist = 0.5 }

-- 6. GENERATOR
core.register_on_generated(function(minp, maxp)
    local vm, emin, emax = core.get_mapgen_object("voxelmanip")
    local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
    local data = vm:get_data()

    local sidelen = maxp.x - minp.x + 1
    local ch_size = {x=sidelen, y=sidelen, z=1}
    local ch_min  = {x=minp.x, y=minp.z}

    local cont_map  = core.get_perlin_map(np_cont,  ch_size):get_2d_map_flat(ch_min)
    local hill_map  = core.get_perlin_map(np_hills, ch_size):get_2d_map_flat(ch_min)
    local heat_map  = core.get_perlin_map(np_heat,  ch_size):get_2d_map_flat(ch_min)
    local humid_map = core.get_perlin_map(np_humid, ch_size):get_2d_map_flat(ch_min)

    local i = 1
    for z = minp.z, maxp.z do
        for x = minp.x, maxp.x do
            -- Height Calculation
            local h_raw = SEALEVEL + (cont_map[i] * 20) + (hill_map[i] * 8)
            local height = floor(max(SEALEVEL - 35, min(h_raw, SEALEVEL + 120)))

            -- Biome/Surface Node Logic
            local h, m = heat_map[i], humid_map[i]
            local surf = c_grass
            
            -- IF/ELSE logic must match the min_heat registration above
            if height <= 64 then
                surf = c_sand
            elseif h > 0.4 then -- Matches roughly heat=70 (perlin is -1 to 1)
                surf = c_sand -- Desert Surface
            end

            for y = minp.y, maxp.y do
                local vi = area:index(x, y, z)
                if y <= height then
                    if y == height then
                        data[vi] = surf
                    elseif y > height - 4 then
                        data[vi] = (surf == c_sand) and c_sand or c_dirt
                    else
                        data[vi] = c_stone
                    end
                elseif y <= SEALEVEL then
                    data[vi] = c_water
                else
                    data[vi] = c_air
                end
            end
            i = i + 1
        end
    end

    vm:set_data(data)
    core.generate_decorations(vm)
    vm:calc_lighting()
    vm:update_liquids()
    vm:write_to_map()
end)