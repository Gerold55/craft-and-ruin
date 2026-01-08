minetest.register_on_generated(function(minp, maxp, seed)
    local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
    local data = vm:get_data()
    local area = VoxelArea:new{MinEdge=emin, MaxEdge=emax}

    -- 1. Content IDs
    local c_stone = minetest.get_content_id("cw_core:stone")
    local c_dirt  = minetest.get_content_id("cw_core:dirt")
    local c_grass = minetest.get_content_id("cw_core:grass")
    local c_sand  = minetest.get_content_id("cw_core:sand")
    local c_terra = minetest.get_content_id("cw_core:terracotta_red")
    local c_water = minetest.get_content_id("cw_core:water_source")

    -- 2. Noise Setup (Seeded globally to prevent chunk lines)
    -- Height: Lower scale and higher spread for that "v6" rolling plains feel
    local perlin_height = minetest.get_perlin(12345, 4, 0.5, 200)
    -- Temperature: Determines the Biome (Heat)
    local perlin_temp   = minetest.get_perlin(67890, 3, 0.5, 500)

    -- 3. Generation Loop
    -- Order MUST be Z -> X -> Y to prevent the "Shifted Layer" issue
    for z = minp.z, maxp.z do
        for x = minp.x, maxp.x do
            
            -- Get global height and temperature for this column
            local noise_h = perlin_height:get_2d({x=x, y=z})
            local temp    = perlin_temp:get_2d({x=x, y=z})
            
            -- Calculate actual height (v6 style scaling)
            local surface_y = math.floor(noise_h * 15 + 10)
            
            -- Determine Biome type (Minecraft v6 Temperature Logic)
            local biome = "meadow"
            if temp > 0.4 then
                biome = "desert"
            elseif temp < -0.4 then
                biome = "clayspire"
            end

            for y = minp.y, maxp.y do
                local vi = area:index(x, y, z)
                
                if y <= surface_y then
                    -- Absolute Depth calculation (The FIX for dirt lines)
                    local depth = surface_y - y

                    if depth == 0 then
                        -- SURFACE
                        if y <= 5 then 
                            data[vi] = c_sand -- Beach
                        elseif biome == "desert" then 
                            data[vi] = c_sand
                        elseif biome == "clayspire" then 
                            data[vi] = c_terra
                        else 
                            data[vi] = c_grass 
                        end
                    elseif depth <= 3 then
                        -- FILLER
                        if biome == "desert" then 
                            data[vi] = c_sand
                        elseif biome == "clayspire" then 
                            data[vi] = c_terra
                        else 
                            data[vi] = c_dirt 
                        end
                    else
                        -- CORE
                        data[vi] = c_stone
                    end
                else
                    -- ABOVE GROUND
                    if y <= 5 then
                        data[vi] = c_water
                    end
                end
            end
        end
    end

    -- 4. Finalize
    vm:set_data(data)
    vm:set_lighting({day=15, night=0})
    vm:write_to_map()
end)