local SEALEVEL = 63

-- ========= Noise definitions =========

local np_height = {
    offset = 0,
    scale = 1,
    spread = {x = 512, y = 512, z = 512},
    seed = 1001,
    octaves = 4,
    persist = 0.5,
}

local np_hills = {
    offset = 0,
    scale = 1,
    spread = {x = 256, y = 256, z = 256},
    seed = 1002,
    octaves = 3,
    persist = 0.5,
}

-- Moderate erosion
local np_erosion = {
    offset = 0,
    scale = 1,
    spread = {x = 300, y = 300, z = 300},
    seed = 3001,
    octaves = 4,
    persist = 0.55,
}

-- Wide subtle ridges (axis-aligned)
local np_ridged = {
    offset = 0,
    scale = 1,
    spread = {x = 600, y = 600, z = 600},
    seed = 4001,
    octaves = 3,
    persist = 0.5,
}

-- Rivers
local np_rivers = {
    offset = 0,
    scale = 1,
    spread = {x = 300, y = 300, z = 300},
    seed = 2001,
    octaves = 3,
    persist = 0.5,
}

-- Cherry grove mask
local np_cherry = {
    offset = 0,
    scale = 1,
    spread = {x = 200, y = 200, z = 200},
    seed = 9001,
    octaves = 3,
    persist = 0.55,
}

-- Sediment patches
local np_patch = {
    offset = 0,
    scale = 1,
    spread = {x = 64, y = 64, z = 64},
    seed = 4444,
    octaves = 3,
    persist = 0.5,
}

-- ========= Cherry tree generator =========

local function generate_cherry_tree(pos, area, data, ids)
    local function set(x, y, z, id)
        if area:contains(x, y, z) then
            data[area:index(x, y, z)] = id
        end
    end

    local trunk_h = math.random(5, 7)
    for dy = 0, trunk_h do
        set(pos.x, pos.y + dy, pos.z, ids.log)
    end

    local top_y = pos.y + trunk_h

    for r = 2, 4 do
        local y_layer = top_y + (4 - r)
        for dx = -r, r do
            for dz = -r, r do
                if math.abs(dx) + math.abs(dz) <= r + 1 then
                    if math.random() < 0.9 then
                        set(pos.x + dx, y_layer, pos.z + dz, ids.leaves)
                    end
                end
            end
        end
    end
end

minetest.register_on_generated(function(minp, maxp, seed)
    local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
    local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
    local data = vm:get_data()

    local sidelen_x = maxp.x - minp.x + 1
    local sidelen_z = maxp.z - minp.z + 1

    -- Fetch noise maps
    local height_map = minetest.get_perlin_map(np_height, {x = sidelen_x, y = sidelen_z})
        :get_2d_map_flat({x = minp.x, y = minp.z})

    local hills_map = minetest.get_perlin_map(np_hills, {x = sidelen_x, y = sidelen_z})
        :get_2d_map_flat({x = minp.x, y = minp.z})

    local erosion_map = minetest.get_perlin_map(np_erosion, {x = sidelen_x, y = sidelen_z})
        :get_2d_map_flat({x = minp.x, y = minp.z})

    local ridged_map = minetest.get_perlin_map(np_ridged, {x = sidelen_x, y = sidelen_z})
        :get_2d_map_flat({x = minp.x, y = minp.z})

    local river_map = minetest.get_perlin_map(np_rivers, {x = sidelen_x, y = sidelen_z})
        :get_2d_map_flat({x = minp.x, y = minp.z})

    local cherry_map = minetest.get_perlin_map(np_cherry, {x = sidelen_x, y = sidelen_z})
        :get_2d_map_flat({x = minp.x, y = minp.z})

    local patch_map = minetest.get_perlin_map(np_patch, {x = sidelen_x, y = sidelen_z})
        :get_2d_map_flat({x = minp.x, y = minp.z})

    -- IDs
    local function id(n) return minetest.get_content_id(n) end
    local ids = {
        stone  = id("cw_core:stone"),
        dirt   = id("cw_core:dirt"),
        grass  = id("cw_core:grass_block"),
        sand   = id("cw_core:sand"),
        gravel = id("cw_core:gravel"),
        clay   = id("cw_core:clay"),
        water  = id("cw_core:water_source"),
        log    = id("cw_core:log_cherry"),
        leaves = id("cw_core:leaves_cherry"),
        air    = minetest.CONTENT_AIR,
    }

    local heightmap = {}
    local surface_y = {}

-- PASS 1: terrain shaping + solid fill
    local i2d = 1

    for z = minp.z, maxp.z do
        for x = minp.x, maxp.x do

            -- Base terrain
            local base   = height_map[i2d] * 40
            local hills  = hills_map[i2d] * 15
            local shaped = base + hills

            -- Erosion softened
            local e = erosion_map[i2d]
            local slope_factor = 1 + math.abs(e) * 0.25

            -- Ridges softened
            local r = math.abs(ridged_map[i2d]) * 7
            local ridge_blend = 0.75
            local ridge_term =
                r * ridge_blend +
                r * (1 - ridge_blend) * (1 - math.abs(e))

            -- Final height
            local h = shaped * slope_factor + ridge_term

            -- Soft river carving
            local river = math.abs(river_map[i2d])
            if river < 0.03 then
                local depth = (0.03 - river) * 6
                h = h - depth
            end

            h = math.floor(64 + h)
            heightmap[i2d] = h

            -- Compute slope for band‑free stone depth
            local hL = height_map[i2d - 1] or height_map[i2d]
            local hR = height_map[i2d + 1] or height_map[i2d]
            local hU = height_map[i2d - sidelen_x] or height_map[i2d]
            local hD = height_map[i2d + sidelen_x] or height_map[i2d]

            local slope = math.max(
                math.abs(hL - hR),
                math.abs(hU - hD)
            )

            -- Band‑free stone depth
            local stone_depth = math.floor(2 + slope * 1.2)

            -- Solid fill
            for y = minp.y, maxp.y do
                local vi = area:index(x, y, z)
                if y <= h then
                    if y < h - stone_depth then
                        data[vi] = ids.stone
                    else
                        data[vi] = ids.dirt
                    end
                else
                    if y <= SEALEVEL then
                        data[vi] = ids.water
                    else
                        data[vi] = ids.air
                    end
                end
            end

            i2d = i2d + 1
        end
    end

-- PASS 2: surface materials
    local function get_h(ix, iz)
        if ix < 0 or iz < 0 or ix >= sidelen_x or iz >= sidelen_z then return nil end
        return heightmap[iz * sidelen_x + ix + 1]
    end

    i2d = 1
    for z = minp.z, maxp.z do
        local iz = z - minp.z
        for x = minp.x, maxp.x do
            local ix = x - minp.x
            local h  = heightmap[i2d]
            local vi = area:index(x, h, z)

            local river = math.abs(river_map[i2d])
            local patch = patch_map[i2d]

            local hL = get_h(ix - 1, iz) or h
            local hR = get_h(ix + 1, iz) or h
            local hU = get_h(ix, iz - 1) or h
            local hD = get_h(ix, iz + 1) or h
            local slope = math.max(math.abs(hL - hR), math.abs(hU - hD))

            local function set_sediment(depth, node)
                for dy = 0, depth - 1 do
                    local yy = h - dy
                    if yy < minp.y then break end
                    local vi2 = area:index(x, yy, z)
                    local nid = data[vi2]
                    if nid == ids.dirt or nid == ids.stone then
                        data[vi2] = node
                    end
                end
            end

            -- Rivers
            if river < 0.03 then
                if patch > 0.45 then
                    set_sediment(3, ids.gravel)
                elseif patch < -0.45 then
                    set_sediment(3, ids.clay)
                else
                    set_sediment(3, ids.sand)
                end

            -- Beaches
            elseif h >= SEALEVEL - 1 and h <= SEALEVEL + 1 and slope < 1.5 then
                set_sediment(2, ids.sand)

            -- Deep ocean
            elseif h < SEALEVEL - 8 then
                if patch > 0.45 then
                    set_sediment(5, ids.gravel)
                elseif patch < -0.45 then
                    set_sediment(5, ids.clay)
                else
                    set_sediment(5, ids.sand)
                end

            -- Land
            else
                if h > SEALEVEL then
                    data[vi] = ids.grass
                end
            end

            i2d = i2d + 1
        end
    end

    -- PASS 3: compute surface_y
    for z = minp.z, maxp.z do
        local iz = z - minp.z
        for x = minp.x, maxp.x do
            local ix  = x - minp.x
            local idx = iz * sidelen_x + ix + 1

            local found_y = nil
            for y = maxp.y, minp.y, -1 do
                local vi = area:index(x, y, z)
                local nid = data[vi]
                if nid ~= ids.air and nid ~= ids.water then
                    found_y = y
                    break
                end
            end

            surface_y[idx] = found_y
        end
    end

    -- PASS 4: cherry trees (only in cherry groves)
    for z = minp.z + 4, maxp.z - 4 do
        local iz = z - minp.z
        for x = minp.x + 4, maxp.x - 4 do
            local ix  = x - minp.x
            local idx = iz * sidelen_x + ix + 1

            local sy     = surface_y[idx]
            local cherry = cherry_map[idx]

            if sy and sy > SEALEVEL + 5 and cherry > 0.45 then
                local hL = get_h(ix - 1, iz) or sy
                local hR = get_h(ix + 1, iz) or sy
                local hU = get_h(ix, iz - 1) or sy
                local hD = get_h(ix, iz + 1) or sy
                local slope = math.max(math.abs(hL - hR), math.abs(hU - hD))

                if slope < 10 then
                    if math.random() < 0.25 then
                        local base_vi = area:index(x, sy, z)
                        local base_id = data[base_vi]
                        if base_id ~= ids.air and base_id ~= ids.water then
                            generate_cherry_tree({x = x, y = sy + 1, z = z}, area, data, ids)
                        end
                    end
                end
            end
        end
    end

    vm:set_data(data)
    vm:calc_lighting()
    vm:write_to_map()
end)