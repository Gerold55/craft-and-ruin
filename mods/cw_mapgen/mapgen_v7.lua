-- ============================================================================
-- Craft & Ruin — V7 Mapgen
-- Biomes + Terrain + Trees + Decor + 8‑Layer Snow System
-- ============================================================================
-- Biomes:
--  • Plains
--  • Forest
--  • Birch Forest (rare)
--  • Cherry Grove
--  • Jungle
--  • Mountains (forested, snow‑capped)
--  • Ocean / Deep Ocean
--
-- Features:
--  • 8‑layer Minecraft‑style snow
--  • Smooth snow transitions
--  • Engine oceans preserved
--  • Terrain offset + biome spacing
-- ============================================================================

local SEALEVEL = tonumber(minetest.get_mapgen_setting("water_level")) or 63
local TERRAIN_OFFSET = 8
local SNOW_LINE = SEALEVEL + 80

-- Content IDs
local c_air        = minetest.CONTENT_AIR
local c_water      = minetest.get_content_id("cw_core:water_source")
local c_stone      = minetest.get_content_id("cw_core:stone")
local c_dirt       = minetest.get_content_id("cw_core:dirt")
local c_grass      = minetest.get_content_id("cw_core:grass_block")
local c_sand       = minetest.get_content_id("cw_core:sand")
local c_gravel     = minetest.get_content_id("cw_core:gravel")
local c_clay       = minetest.get_content_id("cw_core:clay")
local c_snow_block = minetest.get_content_id("cw_core:snow_block")

-- Snow layers
local c_snow_1 = minetest.get_content_id("cw_core:snow_layer_1")
local c_snow_2 = minetest.get_content_id("cw_core:snow_layer_2")
local c_snow_4 = minetest.get_content_id("cw_core:snow_layer_4")

-- ============================================================================
-- NOISE FIELDS
-- ============================================================================

local cherry_noise = {
    offset = 0, scale = 1,
    spread = {x=128,y=128,z=128},
    seed = 91321, octaves = 3, persist = 0.5
}

local jungle_heat_noise = {
    offset = 0, scale = 1,
    spread = {x=256,y=256,z=256},
    seed = 55123, octaves = 3, persist = 0.5
}

local jungle_humidity_noise = {
    offset = 0, scale = 1,
    spread = {x=256,y=256,z=256},
    seed = 99231, octaves = 3, persist = 0.5
}

local biome_noise = {
    offset = 0, scale = 1,
    spread = {x=512,y=512,z=512},
    seed = 12345, octaves = 3, persist = 0.5
}

local nobj_cherry
local nobj_jungle_heat
local nobj_jungle_humidity
local nobj_biome

-- ============================================================================
-- SLOPE CALCULATION
-- ============================================================================

local function get_slope(hmap, index, stride_x)
    local h  = hmap[index]
    local hx = hmap[index + 1] or h
    local hz = hmap[index + stride_x] or h
    return math.abs(h - hx) + math.abs(h - hz)
end

-- ============================================================================
-- BIOME SELECTION
-- ============================================================================

local function get_biome(x, z, y, slope, cherry_val)
    local b = nobj_biome:get_2d({x=x, y=z})
    local heat = nobj_jungle_heat:get_2d({x=x, y=z})
    local humidity = nobj_jungle_humidity:get_2d({x=x, y=z})

    if y < SEALEVEL - 20 then return "deep_ocean" end
    if y < SEALEVEL - 2 then return "ocean" end

    if b > 0.35 then
        if y > SEALEVEL + 5 and y < SEALEVEL + 40 then
            if heat > 0.45 and humidity > 0.45 then
                return "jungle"
            end
        end
    end

    if b > -0.1 and b < 0.2 then
        if y > SEALEVEL + 32 and y < SEALEVEL + 62 then
            if slope < 1.2 and cherry_val > 0.55 then
                return "cherry_grove"
            end
        end
    end

    if b > -0.05 and b < 0.05 then
        if y > SEALEVEL + 20 and y < SEALEVEL + 45 then
            if slope < 1.0 then
                return "birch_forest"
            end
        end
    end

    if y > SEALEVEL + 55 or slope > 2.5 then
        if b > -0.4 and b < 0.4 then
            return "mountains"
        end
    end

    if b > -0.2 and b < 0.4 then
        if y < SEALEVEL + 28 then
            return "plains"
        end
    end

    if b > -0.3 and b < 0.3 then
        if y < SEALEVEL + 48 then
            return "forest"
        end
    end

    return "forest"
end

-- ============================================================================
-- DECORATION
-- ============================================================================

local function try_cluster(pos, node_list, chance)
    if math.random() >= chance then return end

    for i = 1, 16 do
        local ox = pos.x + math.random(-3,3)
        local oz = pos.z + math.random(-3,3)
        local oy = pos.y

        local p = {x=ox,y=oy,z=oz}
        local pb = {x=ox,y=oy-1,z=oz}

        if minetest.get_node(p).name == "air" then
            if minetest.get_node(pb).name == "cw_core:grass_block" then
                minetest.set_node(p, {name=node_list[math.random(#node_list)]})
            end
        end
    end
end

local function place_decor(pos, biome)
    if minetest.get_node(pos).name ~= "air" then return end
    if minetest.get_node({x=pos.x,y=pos.y-1,z=pos.z}).name ~= "cw_core:grass_block" then return end

    local grass = {"cw_core:grass_decor"}
    local flowers = {"cw_core:flower_bluebell", "cw_core:flower_daisy"}

    if biome == "plains" then
        try_cluster(pos, grass, 0.40)
        try_cluster(pos, flowers, 0.10)

    elseif biome == "forest" then
        try_cluster(pos, grass, 0.15)

    elseif biome == "birch_forest" then
        try_cluster(pos, grass, 0.20)
        try_cluster(pos, flowers, 0.08)

    elseif biome == "cherry_grove" then
        try_cluster(pos, grass, 0.25)
        try_cluster(pos, flowers, 0.12)

    elseif biome == "jungle" then
        try_cluster(pos, grass, 0.50)
        try_cluster(pos, flowers, 0.05)

    elseif biome == "mountains" then
        try_cluster(pos, grass, 0.08)
    end
end

-- ============================================================================
-- TREE PLACEMENT
-- ============================================================================

local function place_tree(pos, biome)
    local below = {x=pos.x,y=pos.y-1,z=pos.z}
    if minetest.get_node(below).name ~= "cw_core:grass_block" then return end

    if biome == "forest" and math.random() < 0.04 then
        cw_core.grow_tree(pos, "oak")

    elseif biome == "birch_forest" and math.random() < 0.08 then
        cw_core.grow_tree(pos, "birch")

    elseif biome == "mountains" then
        if math.random() < 0.03 then
            if math.random() < 0.6 then
                cw_core.grow_tree(pos, "birch")
            else
                cw_core.grow_tree(pos, "oak")
            end
        end

    elseif biome == "cherry_grove" and math.random() < 0.10 then
        cw_core.grow_tree(pos, "cherry")

    elseif biome == "jungle" then
        if math.random() < 0.10 then
            cw_core.grow_tree(pos, "jungle")
        elseif math.random() < 0.06 then
            cw_core.grow_tree(pos, "jungle_bush")
        end
    end
end

-- ============================================================================
-- UNDERWATER BLOBS
-- ============================================================================

local function place_underwater_blob(data, area, x, y, z)
    local mat = (math.random() < 0.5) and c_gravel or c_clay
    local size = math.random(4, 8)

    for i = 1, size do
        local dx = x + math.random(-2,2)
        local dy = y + math.random(-1,1)
        local dz = z + math.random(-2,2)

        local vi = area:index(dx,dy,dz)
        if data[vi] == c_stone then
            data[vi] = mat
        end
    end
end

-- ============================================================================
-- MAIN MAPGEN
-- ============================================================================

minetest.register_on_generated(function(minp, maxp, seed)
    local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
    local area = VoxelArea:new({MinEdge=emin, MaxEdge=emax})
    local data = vm:get_data()

    local raw_heightmap = minetest.get_mapgen_object("heightmap")
    local adjusted_heightmap = {}

    local x0,y0,z0 = minp.x,minp.y,minp.z
    local x1,y1,z1 = maxp.x,maxp.y,maxp.z

    local stride_x = (x1 - x0 + 1)
    local i = 1

    nobj_cherry = nobj_cherry or minetest.get_perlin(cherry_noise)
    nobj_jungle_heat = nobj_jungle_heat or minetest.get_perlin(jungle_heat_noise)
    nobj_jungle_humidity = nobj_jungle_humidity or minetest.get_perlin(jungle_humidity_noise)
    nobj_biome = nobj_biome or minetest.get_perlin(biome_noise)

    -- Apply vertical offset
    for z=z0,z1 do
        for x=x0,x1 do
            adjusted_heightmap[i] = raw_heightmap[i] + TERRAIN_OFFSET
            i = i + 1
        end
    end

    -- Terrain fill
    i = 1
    for z=z0,z1 do
        for x=x0,x1 do

            local height = adjusted_heightmap[i]
            local slope = get_slope(adjusted_heightmap, i, stride_x)
            local cherry_val = nobj_cherry:get_2d({x=x,y=z})
            local biome = get_biome(x,z,height,slope,cherry_val)
            i = i + 1

            for y=y0,y1 do
                local vi = area:index(x,y,z)

                if y <= height then
                    data[vi] = c_stone
                elseif y > height and y > SEALEVEL then
                    data[vi] = c_air
                end
            end

            -- Surface
            if height >= y0 and height <= y1 then
                local vi = area:index(x,height,z)

                if biome == "ocean" or biome == "deep_ocean" then
                    local depth = SEALEVEL - height

                    if biome == "ocean" then
                        if depth <= 3 then
                            data[vi] = c_sand
                        elseif depth <= 12 then
                            data[vi] = (math.random() < 0.75) and c_gravel or c_sand
                        else
                            data[vi] = (math.random() < 0.20) and c_clay or c_gravel
                        end

                        for dy=1,3 do
                            local yi = height - dy
                            if yi >= y0 then
                                local vi2 = area:index(x,yi,z)
                                data[vi2] = (depth <= 3) and c_sand or c_gravel
                            end
                        end

                    elseif biome == "deep_ocean" then
                        data[vi] = (math.random() < 0.35) and c_clay or c_gravel

                        for dy=1,4 do
                            local yi = height - dy
                            if yi >= y0 then
                                local vi2 = area:index(x,yi,z)
                                data[vi2] = c_gravel
                            end
                        end

                        if math.random() < 0.05 then
                            place_underwater_blob(data,area,x,height-1,z)
                        end
                    end

                else
                    -- LAND SURFACE + SNOW SYSTEM
                    if biome == "mountains" then

                        if height >= SNOW_LINE + 20 then
                            data[vi] = c_snow_block

                        elseif height >= SNOW_LINE + 10 then
                            data[vi] = c_snow_block
                            local vi2 = area:index(x,height+1,z)
                            data[vi2] = c_snow_4

                        elseif height >= SNOW_LINE + 5 then
                            data[vi] = c_grass
                            local vi2 = area:index(x,height+1,z)
                            data[vi2] = c_snow_2

                        elseif height >= SNOW_LINE then
                            data[vi] = c_grass
                            local vi2 = area:index(x,height+1,z)
                            data[vi2] = c_snow_1

                        else
                            data[vi] = c_grass
                        end

                        if height < SNOW_LINE + 20 then
                            for dy=1,3 do
                                local yi = height - dy
                                if yi >= y0 then
                                    local vi2 = area:index(x,yi,z)
                                    data[vi2] = c_dirt
                                end
                            end
                        end

                    else
                        data[vi] = c_grass
                        for dy=1,3 do
                            local yi = height - dy
                            if yi >= y0 then
                                local vi2 = area:index(x,yi,z)
                                data[vi2] = c_dirt
                            end
                        end
                    end
                end
            end
        end
    end

    vm:set_data(data)
    vm:write_to_map()
    vm:update_map()

    -- Trees + Decor
    i = 1
    for z=z0,z1 do
        for x=x0,x1 do
            local height = adjusted_heightmap[i]
            local slope = get_slope(adjusted_heightmap, i, stride_x)
            local cherry_val = nobj_cherry:get_2d({x=x,y=z})
            local biome = get_biome(x,z,height,slope,cherry_val)
            i = i + 1

            if height >= y0 and height <= y1 then
                local pos = {x=x,y=height+1,z=z}

                if biome ~= "ocean" and biome ~= "deep_ocean" then
                    place_tree(pos, biome)
                    place_decor(pos, biome)
                end
            end
        end
    end
end)

