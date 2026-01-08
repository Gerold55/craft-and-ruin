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

    -- 2. Noise Setup (Global/Absolute)
    local side_length = maxp.x - minp.x + 1
    local chunk_dims = {x = side_length, y = side_length, z = 1}
    
    -- Terrain Height Map
    local nval_height = minetest.get_perlin_map(
        {offset=0, scale=25, spread={x=200, y=200, z=200}, seed=123, octaves=5, persist=0.6},
        chunk_dims
    ):get_2d_map_flat({x=minp.x, y=minp.z})

    -- Temperature (Minecraft-style Biomes)
    local nval_heat = minetest.get_perlin_map(
        {offset=0, scale=1, spread={x=500, y=500, z=500}, seed=456, octaves=3},
        chunk_dims
    ):get_2d_map_flat({x=minp.x, y=minp.z})

    -- 3. Generation Loop
    for z = minp.z, maxp.z do
        for x = minp.x, maxp.x do
            -- IMPORTANT: Calculate 2D index based on current X/Z
            -- This prevents the "shifting" error
            local i_2d = (z - minp.z) * side_length + (x - minp.x) + 1
            
            local surface_y = math.floor(nval_height[i_2d])
            local heat      = nval_heat[i_2d]

            for y = maxp.y, minp.y, -1 do
                local vi = area:index(x, y, z)
                local depth = surface_y - y

                if y <= surface_y then
                    -- Ground logic
                    if depth == 0 then
                        -- Surface Block
                        if heat > 0.4 then data[vi] = c_sand
                        elseif heat < -0.4 then data[vi] = c_terra
                        elseif y <= 4 then data[vi] = c_sand -- Natural beach
                        else data[vi] = c_grass end
                    elseif depth <= 3 then
                        -- Filler Block
                        if heat > 0.4 then data[vi] = c_sand
                        elseif heat < -0.4 then data[vi] = c_terra
                        else data[vi] = c_dirt end
                    else
                        -- Solid Stone Core
                        data[vi] = c_stone
                    end
                elseif y <= 3 then
                    -- Sea Level
                    data[vi] = c_water
                end
            end
        end
    end

    -- 4. Finalize and Light
    vm:set_data(data)
    vm:set_lighting({day=15, night=0})
    vm:write_to_map()
end)