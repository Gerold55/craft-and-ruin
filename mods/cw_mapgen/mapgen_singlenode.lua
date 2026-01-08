-- ============================================================================
-- cw_mapgen: mapgen_singlenode.lua
-- Final 7-Step Pipeline with Lighting Fix
-- ============================================================================

minetest.clear_registered_biomes()

-- STEP 1: Biome Infrastructure
minetest.register_biome({
    name = "meadow",
    node_top = "cw_core:grass_block", depth_top = 1,
    node_filler = "cw_core:dirt", depth_filler = 3,
    heat_point = 50, humidity_point = 50,
})

minetest.register_biome({
    name = "desert",
    node_top = "cw_core:sand", depth_top = 1,
    node_filler = "cw_core:sand", depth_filler = 3,
    heat_point = 85, humidity_point = 20,
})

-- Add this to your Biome Registration block
minetest.register_biome({
    name = "beach",
    node_top = "cw_core:sand", depth_top = 1,
    node_filler = "cw_core:sand", depth_filler = 3,
    heat_point = 50, humidity_point = 40, -- Mild temp, mild humidity
    y_max = 11, -- Beaches only exist at low elevation
    y_min = 1,
})

minetest.register_on_generated(function(minp, maxp, seed)
    local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
    local data = vm:get_data()
    local area = VoxelArea:new{MinEdge=emin, MaxEdge=emax}

    -- Node IDs
    local c_stone = minetest.get_content_id("cw_core:stone")
    local c_dirt  = minetest.get_content_id("cw_core:dirt")
    local c_grass = minetest.get_content_id("cw_core:grass_block")
    local c_sand  = minetest.get_content_id("cw_core:sand")
    local c_water = minetest.get_content_id("cw_core:water_source")
    local c_air   = minetest.get_content_id("air")

    -- STEP 2: Noise Definitions
    local p_base    = minetest.get_perlin(123, 3, 0.5, 500) 
    local p_filler  = minetest.get_perlin(456, 4, 0.6, 100) 
    local p_select  = minetest.get_perlin(789, 2, 0.5, 300) 
    local p_warp    = minetest.get_perlin(222, 2, 0.5, 50)  
    local p_temp    = minetest.get_perlin(555, 3, 0.5, 800)
    local p_caves   = minetest.get_perlin(777, 3, 0.6, 30)

    for z = minp.z, maxp.z do
        for x = minp.x, maxp.x do
            -- Step 1 (Cont): Coordinate Warping
            local ox, oz = p_warp:get_2d({x=x, y=z}) * 20, p_warp:get_2d({x=z, y=x}) * 20
            local wx, wz = x + ox, z + oz
            
            -- Step 2 (Cont): Heightmap Selector Logic
            local base_n   = p_base:get_2d({x=wx, y=wz})
            local detail_n = p_filler:get_2d({x=wx, y=wz})
            local select_n = p_select:get_2d({x=wx, y=wz})
            local n_temp   = p_temp:get_2d({x=x, y=z})
            
            local is_desert = (n_temp > 0.4)
            local height_mod = (select_n > 0) and (select_n * 40) or (select_n * 5)
            local surface_y = math.floor(15 + (base_n * 10) + (detail_n * height_mod))

            for y = minp.y, maxp.y do
                local vi = area:index(x, y, z)
                local depth = surface_y - y

                -- STEP 3: Fill Terrain
                if y <= surface_y then
                    if depth == 0 then
                        if y <= 10 then data[vi] = c_sand 
                        else data[vi] = is_desert and c_sand or c_grass end
                    elseif depth <= 3 then
                        data[vi] = (is_desert or y <= 10) and c_sand or c_dirt
                    else
                        data[vi] = c_stone
                    end

                    -- STEP 4: Carve Caves
                    if depth > 4 then
                        local n_c = p_caves:get_3d({x=x, y=y, z=z})
                        if n_c > 0.65 then data[vi] = c_air end
                    end
                
                -- STEP 5: Water Bodies
                elseif y <= 8 then
                    data[vi] = c_water
                end
            end
        end
    end

    -- STEP 6.1: Initial Map Write
    vm:set_data(data)
    vm:set_lighting({day = 15, night = 0})
    vm:calc_lighting()
    vm:write_to_map()

    -- STEP 6.2: Add Vegetation (Trees & Grass)
    minetest.generate_decorations(vm)

    -- THE LIGHTING FIX FOR LEAVES
    -- We force a second lighting pass now that the trees exist
    vm:update_liquids()
    vm:calc_lighting()
    vm:update_map()
end)