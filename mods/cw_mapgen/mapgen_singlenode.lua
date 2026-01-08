-- ============================================================================
-- cw_mapgen: mapgen_singlenode.lua
-- Biomes: Plains (Meadow), Desert, Taiga, Beach, Ocean, River
-- Fix: Ponds restricted to Plains, Rare Rivers, Expansive Oceans
-- ============================================================================

minetest.register_on_generated(function(minp, maxp, seed)
    local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
    local data = vm:get_data()
    local area = VoxelArea:new{MinEdge=emin, MaxEdge=emax}

    local c_stone  = minetest.get_content_id("cw_core:stone")
    local c_dirt   = minetest.get_content_id("cw_core:dirt")
    local c_grass  = minetest.get_content_id("cw_core:grass_block")
    local c_sand   = minetest.get_content_id("cw_core:sand")
    local c_water  = minetest.get_content_id("cw_core:water_source")
    local c_air    = minetest.get_content_id("air")

    -- Noises
    local perlin_height = minetest.get_perlin(123, 3, 0.5, 300)
    local perlin_temp   = minetest.get_perlin(456, 3, 0.5, 500)
    local perlin_river  = minetest.get_perlin(111, 4, 0.4, 250) -- Rare snaking rivers
    local perlin_pool   = minetest.get_perlin(789, 5, 0.6, 15)  -- Jagged small ponds

    local function get_surface_y(x, z, biome)
        local n_h = perlin_height:get_2d({x=x, y=z})
        -- Meadow (2.4) for extreme Minecraft flatness. Taiga (1.3) for hills.
        local power = (biome == "meadow") and 2.4 or (biome == "desert" and 1.8 or 1.3)
        local h_m = n_h > 0 and (n_h ^ power) or (n_h * 0.2)
        return math.floor(h_m * 18 + 12)
    end

    for z = minp.z, maxp.z do
        for x = minp.x, maxp.x do
            local temp = perlin_temp:get_2d({x=x, y=z})
            local river_n = math.abs(perlin_river:get_2d({x=x, y=z}))
            
            -- 1. BIOME SELECTION
            local biome = "meadow"
            if temp > 0.4 then biome = "desert"
            elseif temp < -0.4 then biome = "taiga" end
            
            local surface_y = get_surface_y(x, z, biome)
            
            -- 2. RIVER LOGIC (Narrower & Rarer)
            local is_river = (river_n < 0.025 and surface_y > 5 and surface_y < 16)
            if is_river then surface_y = 5 end

            -- 3. PLAINS POND LOGIC (Now restricted ONLY to Plains/Meadow)
            local pool_n = perlin_pool:get_2d({x=x, y=z})
            local is_flat = (surface_y == get_surface_y(x+1, z, biome))
            local is_plains_pond = (biome == "meadow" and pool_n > 0.91 and is_flat and not is_river)

            for y = minp.y, maxp.y do
                local vi = area:index(x, y, z)
                local depth = surface_y - y

                if is_plains_pond or (is_river and y <= 5) then
                    -- Water for Ponds or Rivers
                    if y == surface_y or (is_river and y == 5) then 
                        data[vi] = c_water
                    elseif depth == 1 or (is_river and y == 4) then 
                        data[vi] = (biome == "desert" and c_sand or c_dirt) 
                    end
                
                elseif y <= surface_y then
                    if depth == 0 then
                        -- Surface Block logic
                        if y <= 7 then data[vi] = c_sand -- Beaches
                        elseif biome == "desert" then data[vi] = c_sand
                        else data[vi] = c_grass end
                    elseif depth <= 3 then
                        data[vi] = (biome == "desert" or y <= 7) and c_sand or c_dirt
                    else
                        data[vi] = c_stone
                    end
                elseif y <= 5 then
                    data[vi] = c_water -- Oceans
                end
            end
        end
    end

    vm:set_data(data)
    vm:set_lighting({day=15, night=0})
    vm:write_to_map()
end)