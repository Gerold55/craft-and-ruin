local core = core
local SEALEVEL = 63

-- 1. CHERRY TREE GENERATOR
local function generate_cherry_tree(pos, area, data)
    local c_log    = core.get_content_id("cw_core:log_cherry")
    local c_leaves = core.get_content_id("cw_core:leaves_cherry")
    local c_air    = core.CONTENT_AIR

    local trunk_h = math.random(3, 5)
    for dy = 0, trunk_h do
        local vi = area:index(pos.x, pos.y + dy, pos.z)
        if area:contains(pos.x, pos.y + dy, pos.z) then data[vi] = c_log end
    end

    local top_y = pos.y + trunk_h
    for dy = -1, 2 do
        local radius = (dy < 1) and 3 or 2
        for dx = -radius, radius do
            for dz = -radius, radius do
                if math.abs(dx) + math.abs(dz) <= radius + 1 then
                    local lx, ly, lz = pos.x + dx, top_y + dy, pos.z + dz
                    if area:contains(lx, ly, lz) then
                        local vi = area:index(lx, ly, lz)
                        if data[vi] == c_air then data[vi] = c_leaves end
                    end
                end
            end
        end
    end
end

-- 2. NOISE PARAMETERS
local np_terrain = { offset = 0, scale = 1, spread = {x=500, y=500, z=500}, seed = 592, octaves = 5, persist = 0.5 }
local np_rough   = { offset = 0, scale = 1, spread = {x=100, y=100, z=100}, seed = 123, octaves = 3, persist = 0.4 }

-- Helper function to blend between two values
local function lerp(a, b, t)
    return a + (b - a) * t
end

-- 3. THE ON_GENERATED FUNCTION
core.register_on_generated(function(minp, maxp)
    local vm, emin, emax = core.get_mapgen_object("voxelmanip")
    local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
    local data = vm:get_data()
    
    local side_x, side_z = maxp.x - minp.x + 1, maxp.z - minp.z + 1
    local ch_size = {x = side_x, y = side_z, z = 1}
    local ch_min  = {x = minp.x, y = minp.z}

    local t_map = core.get_perlin_map(np_terrain, ch_size):get_2d_map_flat(ch_min)
    local r_map = core.get_perlin_map(np_rough,   ch_size):get_2d_map_flat(ch_min)

    local c_stone   = core.get_content_id("cw_core:stone")
    local c_water   = core.get_content_id("cw_core:water_source")
    local c_sand    = core.get_content_id("cw_core:beach_sand")
    local c_grass   = core.get_content_id("cw_core:grass_block")
    local c_dirt    = core.get_content_id("cw_core:dirt")
    local c_bedrock = core.get_content_id("cw_core:bedrock")
    local c_air     = core.CONTENT_AIR

    local i = 1
    for z = minp.z, maxp.z do
        for x = minp.x, maxp.x do
            local nv = t_map[i]
            local rv = r_map[i]
            
            local h_final = 0
            local biome = "plains"

            -- SMOOTH TERRAIN INTERPOLATION (The Spline)
            -- nv ranges roughly from -1.0 to 1.0
            if nv < -0.25 then
                -- Ocean floor
                h_final = lerp(-25, -5, (nv + 1.0) / 0.75)
                biome = "ocean"
            elseif nv < 0.0 then
                -- Ocean to Beach transition
                local t = (nv + 0.25) / 0.25
                h_final = lerp(-5, 1, t)
                biome = "beach"
            elseif nv < 0.1 then
                -- Beach to Plains transition
                local t = nv / 0.1
                h_final = lerp(1, 4, t)
                biome = "beach"
            elseif nv < 0.5 then
                -- Rolling Plains
                local t = (nv - 0.1) / 0.4
                h_final = lerp(4, 12, t) + (rv * 3)
                biome = "plains"
            else
                -- Plains to Mountain transition
                local t = (nv - 0.5) / 0.5
                h_final = lerp(12, 45, t) + (rv * 6)
                biome = "cherry_grove"
            end

            local height = math.floor(SEALEVEL + h_final)

            -- NODE ASSIGNMENT based on final height/biome
            local c_top, c_filler = c_grass, c_dirt
            if height <= SEALEVEL + 1 then
                c_top, c_filler = c_sand, c_sand
            end

            -- TERRAIN PLACEMENT
            for y = minp.y, maxp.y do
                local vi = area:index(x, y, z)
                
                -- 5-Layer Bedrock
                local dist_from_bottom = y - (-64) 
                local is_bedrock = false
                if dist_from_bottom <= 4 and dist_from_bottom >= 0 then
                    if dist_from_bottom == 0 then is_bedrock = true
                    else
                        local chance = (5 - dist_from_bottom) * 2
                        if (x * 31 + y * 7 + z * 13) % 10 < chance then is_bedrock = true end
                    end
                end

                if is_bedrock then
                    data[vi] = c_bedrock
                elseif y <= height then
                    if y == height then data[vi] = c_top
                    elseif y > height - 4 then data[vi] = c_filler
                    else data[vi] = c_stone end
                elseif y <= SEALEVEL then
                    data[vi] = c_water
                else
                    data[vi] = c_air
                end
            end

            -- TREES
            if biome == "cherry_grove" and math.random(1, 180) == 1 then
                generate_cherry_tree({x=x, y=height + 1, z=z}, area, data)
            end

            i = i + 1
        end
    end

    vm:set_data(data)
    core.generate_decorations(vm)
    vm:update_liquids()
    vm:calc_lighting()
    vm:write_to_map()
end)

-- 4. SPAWN LOGIC
core.register_on_newplayer(function(player)
    local p = player:get_pos()
    core.after(0.5, function()
        for y = 160, 50, -1 do
            local node = core.get_node({x=p.x, y=y, z=p.z}).name
            if node ~= "air" and node ~= "ignore" and node ~= "cw_core:water_source" then
                player:set_pos({x=p.x, y=y+2, z=p.z})
                break
            end
        end
    end)
end)