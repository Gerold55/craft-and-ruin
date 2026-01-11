local SEALEVEL = 63

-- 1. NOISE PARAMS
local np_biome   = { offset = 0, scale = 1, spread = {x=200, y=200, z=200}, seed = 432, octaves = 3, persist = 0.6 }
local np_wetland = { offset = 0, scale = 1, spread = {x=150, y=150, z=150}, seed = 772, octaves = 3, persist = 0.7 }

-- 2. CHERRY TREE GENERATOR (Remains the same)
local function generate_cherry_tree(pos, area, data, param2_data, ids)
    local function safe_set(x, y, z, id, p2)
        if area:contains(x, y, z) then
            local vi = area:index(x, y, z)
            data[vi] = id 
            param2_data[vi] = p2 or 0
        end
    end
    local trunk_h = math.random(4, 5)
    for y = 0, trunk_h do safe_set(pos.x, pos.y + y, pos.z, ids.log, 0) end
    local d = {x=1, z=0, p2=12} 
    local curr = {x=pos.x, y=pos.y + trunk_h - 1, z=pos.z}
    for step = 1, 2 do
        curr.x = curr.x + d.x
        safe_set(curr.x, curr.y, curr.z, ids.log, d.p2)
    end
    for dx = -2, 2 do for dz = -2, 2 do for dy = -1, 1 do
        if math.abs(dx) + math.abs(dz) < 4 then
            safe_set(curr.x + dx, curr.y + dy, curr.z + dz, ids.leaves)
            safe_set(pos.x + dx, pos.y + trunk_h + dy, pos.z + dz, ids.leaves)
        end
    end end end
end

-- 3. THE GENERATOR
core.register_on_generated(function(minp, maxp, blockseed)
    local vm, emin, emax = core.get_mapgen_object("voxelmanip")
    local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
    local data = vm:get_data()
    local param2_data = vm:get_param2_data()

    local side_x = maxp.x - minp.x + 1
    local side_z = maxp.z - minp.z + 1
    local b_map = core.get_perlin_map(np_biome, {x=side_x, y=side_z, z=1}):get_2d_map_flat({x=minp.x, y=minp.z})
    local w_map = core.get_perlin_map(np_wetland, {x=side_x, y=side_z, z=1}):get_2d_map_flat({x=minp.x, y=minp.z})

    local function get_id(name) return core.registered_nodes[name] and core.get_content_id(name) or core.CONTENT_AIR end
    local ids = {
        stone = get_id("cw_core:stone"), grass = get_id("cw_core:grass_block"),
        dirt  = get_id("cw_core:dirt"),  water = get_id("cw_core:water_source"),
        sand  = get_id("cw_core:sand"),   log   = get_id("cw_core:log_cherry"),
        leaves = get_id("cw_core:leaves_cherry"),
        sand_cattail = get_id("cw_core:sand_with_cattails"),
        cat_top      = get_id("cw_core:cattail_top"),
        reed_bottom  = get_id("cw_core:reeds_bottom"),
        reed_top     = get_id("cw_core:reeds_top"),
        air = core.CONTENT_AIR
    }

    -- PASS 1: TERRAIN
    for z = minp.z, maxp.z do
        for x = minp.x, maxp.x do
            local i2d = (z - minp.z) * side_x + (x - minp.x) + 1
            local surface_y = math.floor(70 + (b_map[i2d] * 20))
            for y = minp.y, maxp.y do
                local vi = area:index(x, y, z)
                if y < surface_y then
                    local depth = surface_y - y
                    if depth > 4 then data[vi] = ids.stone
                    elseif y <= SEALEVEL then data[vi] = ids.sand
                    else data[vi] = (y == surface_y - 1) and ids.grass or ids.dirt end
                elseif y <= SEALEVEL then data[vi] = ids.water end
            end
        end
    end

    -- PASS 2: ENGINE DECORATIONS
    vm:set_data(data)
    core.generate_decorations(vm)
    data = vm:get_data()

    -- PASS 3: MANUAL DECORATIONS
    for z = minp.z, maxp.z do
        for x = minp.x, maxp.x do
            local i2d = (z - minp.z) * side_x + (x - minp.x) + 1
            local bio_val, wet_val = b_map[i2d], w_map[i2d]
            local surface_y = math.floor(70 + (bio_val * 20))

            if surface_y >= minp.y and surface_y <= maxp.y then
                local pr = PseudoRandom(blockseed + i2d)

                -- CATTAILS
                if surface_y == SEALEVEL then
                    if wet_val > 0.6 and pr:next(1, 25) == 1 then
                        local vi_b, vi_t = area:index(x, surface_y - 1, z), area:index(x, surface_y + 1, z)
                        if area:contains(x, surface_y + 1, z) then
                            data[vi_b], data[vi_t], param2_data[vi_b] = ids.sand_cattail, ids.cat_top, 16
                        end
                    end
                end

                -- REEDS
                if surface_y == SEALEVEL + 1 then
                    local is_shore = false
                    for _, c in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
                        local ni2d = (z+c[2]-minp.z)*side_x + (x+c[1]-minp.x)+1
                        if b_map[ni2d] and math.floor(70+(b_map[ni2d]*20)) <= SEALEVEL then is_shore = true; break end
                    end
                    if is_shore and pr:next(1, 6) == 1 then
                        local h_stalk = pr:next(1, 2)
                        for h = 0, h_stalk do
                            local vi = area:index(x, surface_y + h, z)
                            if area:contains(x, surface_y + h, z) then
                                data[vi] = (h == h_stalk) and ids.reed_top or ids.reed_bottom
                            end
                        end
                    end
                end

                -- CHERRY TREES (GROVE LOGIC)
                -- 1. bio_val > 0.4 defines the grove area
                -- 2. (x % 7 == 0 and z % 7 == 0) ensures a minimum of 7 nodes between trunk centers
                -- 3. pr:next(1, 3) adds a bit of "natural" jitter so they aren't a perfect grid
                if surface_y > SEALEVEL + 2 and bio_val > 0.4 then
                    if x % 7 == 0 and z % 7 == 0 then
                        if pr:next(1, 3) ~= 1 then -- 66% chance to spawn at this grid point
                            generate_cherry_tree({x=x, y=surface_y, z=z}, area, data, param2_data, ids)
                        end
                    end
                end
            end
        end
    end

    vm:set_data(data)
    vm:set_param2_data(param2_data)
    vm:calc_lighting()
    vm:write_to_map()
end)