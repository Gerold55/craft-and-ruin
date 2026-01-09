local core = core
local SEALEVEL = 63

-- Force spawn height well above your SEALEVEL of 63
core.set_mapgen_setting("static_spawnpoint", "0, 75, 0", true)
core.set_mapgen_setting("check__shared_breakpoints", "false", true)

-- 1. MAPGEN & BIOME REGISTRATION
core.set_mapgen_setting("mg_name", "singlenode", true)
core.set_mapgen_setting("water_level", "63", true)
core.clear_registered_biomes()

-- Biome Labels (Used by the decoration engine for filtering)
core.register_biome({ name = "beach",        y_min = 62, y_max = 64 })
core.register_biome({ name = "desert",       y_min = 65, y_max = 31000 })
core.register_biome({ name = "meadow",       y_min = 65, y_max = 31000 })
core.register_biome({ name = "cherry_grove", y_min = 65, y_max = 31000 })

-- 2. CONTENT IDS
local c_air         = core.CONTENT_AIR
local c_stone       = core.get_content_id("cw_core:stone")
local c_dirt        = core.get_content_id("cw_core:dirt")
local c_grass       = core.get_content_id("cw_core:grass_block")
local c_beach_sand  = core.get_content_id("cw_core:beach_sand")
local c_desert_sand = core.get_content_id("cw_core:desert_sand")
local c_water       = core.get_content_id("cw_core:water_source")

-- 3. NOISE PARAMS
-- 4000 spread makes biomes enormous.
local np_cont  = { offset = 0, scale = 1, spread = {x=1200, y=1200, z=1200}, seed = 11, octaves = 4, persist = 0.5 }
local np_hills = { offset = 0, scale = 1, spread = {x=220, y=220, z=220}, seed = 99, octaves = 4, persist = 0.55 }
local np_heat  = { offset = 0, scale = 1, spread = {x=4000, y=4000, z=4000}, seed = 44, octaves = 3, persist = 0.5 }
local np_humid = { offset = 0, scale = 1, spread = {x=4000, y=4000, z=4000}, seed = 55, octaves = 3, persist = 0.5 }

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
            local height = math.floor(SEALEVEL + (cont_map[i] * 20) + (hill_map[i] * 8))
            local h, m = heat_map[i], humid_map[i]
            
            -- 4. BIOME LOGIC (The "Surface" choice)
            local surf = c_grass
            
            if height <= 64 then
                surf = c_beach_sand -- All sea-level sand is BEACH
            else
                -- Above sea level, we check Heat and Humidity
                if h > 0.6 and m < -0.4 then
                    surf = c_desert_sand -- Hot & Dry = DESERT
                elseif h > 0.1 and h < 0.5 and m > 0.5 then
                    -- Moderate Temp & High Humidity = CHERRY GROVE
                    -- (Note: Using grass here, but labeled as cherry_grove biome)
                    surf = c_grass 
                end
            end

            for y = minp.y, maxp.y do
                local vi = area:index(x, y, z)
                if y <= height then
                    if y == height then
                        data[vi] = surf
                    elseif y > height - 4 then
                        -- Sub-surface: Sand biomes stay sand, Grass biomes use dirt
                        data[vi] = (surf == c_grass) and c_dirt or surf
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