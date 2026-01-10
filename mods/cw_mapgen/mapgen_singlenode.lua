local SEALEVEL = 63

-- 1. NOISE PARAMETERS
local np_biome   = { offset = 0, scale = 1, spread = {x=200, y=200, z=200}, seed = 432, octaves = 3, persist = 0.6 }
local np_wetland = { offset = 0, scale = 1, spread = {x=150, y=150, z=150}, seed = 772, octaves = 3, persist = 0.7 }

-- 2. L-SHAPED CHERRY TREE FUNCTION
local function generate_cherry_tree(pos, area, data, param2_data, ids)
	local function safe_set(x, y, z, id, p2)
		if area:contains(x, y, z) then
			local vi = area:index(x, y, z)
			data[vi] = id 
			param2_data[vi] = p2 or 0
		end
	end

	local function leaf_cluster(px, py, pz)
		for dy = 0, 1 do
			local r = (dy == 0) and 2 or 1
			for dx = -r, r do
				for dz = -r, r do
					if math.abs(dx) + math.abs(dz) < 4 then
						safe_set(px+dx, py+dy, pz+dz, ids.leaves)
					end
				end
			end
		end
	end

	local trunk_h = math.random(4, 5)
	for y = 0, trunk_h do safe_set(pos.x, pos.y + y, pos.z, ids.log, 0) end

	local branch_dirs = {{x=1,z=0,p2=12}, {x=-1,z=0,p2=12}, {x=0,z=1,p2=4}, {x=0,z=-1,p2=4}}
	for i = 1, 2 do
		local d = branch_dirs[math.random(1, #branch_dirs)]
		local curr = {x=pos.x, y=pos.y + (trunk_h - math.random(1, 2)), z=pos.z}
		for step = 1, 3 do
			curr.x, curr.z = curr.x + d.x, curr.z + d.z
			if step == 2 then curr.y = curr.y + 1 end
			safe_set(curr.x, curr.y, curr.z, ids.log, d.p2)
		end
		leaf_cluster(curr.x, curr.y, curr.z)
	end
	leaf_cluster(pos.x, pos.y + trunk_h, pos.z)
end

-- 3. THE GENERATOR
core.register_on_generated(function(minp, maxp)
    local vm, emin, emax = core.get_mapgen_object("voxelmanip")
    local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
    local data, param2_data = vm:get_data(), vm:get_param2_data()

    local side_x, side_z = maxp.x - minp.x + 1, maxp.z - minp.z + 1
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
        reed         = get_id("cw_core:reed"), air = core.CONTENT_AIR
    }

    for z = minp.z, maxp.z do
        for x = minp.x, maxp.x do
            local i2d = (z - minp.z) * side_x + (x - minp.x) + 1
            local bio_val, wet_val = b_map[i2d] or 0, w_map[i2d] or 0
            local surface_y = math.floor(70 + (bio_val * 20))

            for y = minp.y, maxp.y do
                local vi = area:index(x, y, z)
                local depth = surface_y - y

                -- TERRAIN LAYERING
                if y < surface_y then
                    if depth > 4 then data[vi] = ids.stone 
                    elseif y <= SEALEVEL then data[vi] = ids.sand
                    else data[vi] = (y == surface_y - 1) and ids.grass or ids.dirt end
                elseif y <= SEALEVEL then
                    data[vi] = ids.water
                end

                -- DECORATION PHASE
                if y == surface_y then
                    -- 1. CATTAILS (Strictly at water edge)
                    if surface_y <= SEALEVEL and surface_y >= SEALEVEL - 1 and wet_val > 0.4 then
                        -- Check if land is neighbor
                        local is_shore = false
                        for _, c in ipairs({{x=1,z=0}, {x=-1,z=0}, {x=0,z=1}, {x=0,z=-1}}) do
                            local ni2d = (z+c.z - minp.z) * side_x + (x+c.x - minp.x) + 1
                            if math.floor(70 + ((b_map[ni2d] or 0) * 20)) > SEALEVEL then
                                is_shore = true; break
                            end
                        end

                        if is_shore and math.random(1, 5) == 1 then
                            local vi_b = area:index(x, y - 1, z)
                            local vi_t = area:index(x, y + 1, z)
                            if area:contains(x, y+1, z) then
                                data[vi_b] = ids.sand_cattail
                                param2_data[vi_b] = 16
                                data[vi_t] = ids.cat_top
                            end
                        end
                    end

                    -- 2. REEDS (On dry land immediately next to water)
                    if surface_y > SEALEVEL and surface_y <= SEALEVEL + 1 then
                        local near_water = false
                        for _, c in ipairs({{x=1,z=0}, {x=-1,z=0}, {x=0,z=1}, {x=0,z=-1}}) do
                             local ni2d = (z+c.z - minp.z) * side_x + (x+c.x - minp.x) + 1
                             if math.floor(70 + ((b_map[ni2d] or 0) * 20)) <= SEALEVEL then
                                 near_water = true; break
                             end
                        end
                        if near_water and math.random(1, 4) == 1 then
                            for rh = 0, math.random(1, 2) do
                                if area:contains(x, y+rh, z) then
                                    data[area:index(x, y+rh, z)] = ids.reed
                                end
                            end
                        end
                    end

                    -- 3. CHERRY TREES
                    if surface_y > SEALEVEL + 2 and bio_val > 0.6 and math.random(1, 60) == 1 then
                        generate_cherry_tree({x=x, y=surface_y, z=z}, area, data, param2_data, ids)
                    end
                end
            end
        end
    end

    vm:set_data(data)
    vm:set_param2_data(param2_data)
    vm:set_lighting({day=15, night=0})
    vm:calc_lighting()
	core.generate_decorations(vm)
    vm:write_to_map()
end)