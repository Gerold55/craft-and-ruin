-- ======================================================
-- Craft & Ruin - Full Minecraft-like Mapgen
-- Density + Caves + Biomes + Surface + Trees + Mountain Boost
-- ======================================================

local SEA_LEVEL   = 63
local MIN_HEIGHT  = -32
local MAX_HEIGHT  = 192
local SNOWLINE    = 130
local SOIL_DEPTH  = 4
local BEACH_WIDTH = 6

-- ======================================================
-- BIOME NOISE (BT2 smooth transitions)
-- ======================================================

local np_biome = {
    offset = 0,
    scale = 1,
    spread = {x=1024, y=1024, z=1024},
    seed = 3001,
    octaves = 4,
    persist = 0.5,
    lacunarity = 2.0,
}

-- MB1 rare mountains
local function get_biome(n)
    if n < 0.20 then return "plains" end
    if n < 0.40 then return "forest" end
    if n < 0.60 then return "birch" end
    if n < 0.75 then return "cherry" end
    if n < 0.90 then return "mountain" end
    return "snowy_peak"
end

-- ======================================================
-- TERRAIN NOISE
-- ======================================================

local np_continentalness = {
    offset = 0, scale = 1,
    spread = {x=2048,y=2048,z=2048},
    seed = 1001, octaves = 5,
    persist = 0.5, lacunarity = 2.0,
}

local np_erosion = {
    offset = 0, scale = 1,
    spread = {x=1024,y=1024,z=1024},
    seed = 1002, octaves = 5,
    persist = 0.5, lacunarity = 2.0,
}

local np_ridges = {
    offset = 0, scale = 1,
    spread = {x=1024,y=1024,z=1024},
    seed = 1003, octaves = 4,
    persist = 0.5, lacunarity = 2.0,
}

-- ======================================================
-- CAVE NOISE
-- ======================================================

local np_cave_cheese = {
    offset = 0, scale = 1,
    spread = {x=256,y=256,z=256},
    seed = 2001, octaves = 3,
    persist = 0.5, lacunarity = 2.0,
}

local np_cave_second = {
    offset = 0, scale = 1,
    spread = {x=256,y=256,z=256},
    seed = 2002, octaves = 3,
    persist = 0.5, lacunarity = 2.0,
}

-- ======================================================
-- DENSITY FUNCTION (V1 LOWER TERRAIN + MOUNTAIN BOOST)
-- ======================================================

local function compute_density(x,y,z,n_cont,n_eros,n_ridge,n_cheese,n_second,biome)

    -- V1 terrain scale (your choice)
    local ny = (y - SEA_LEVEL) / 32

    -- Mountain height boost (Option A)
    local mountain_boost = 0
    if biome == "mountain" then
        mountain_boost = 0.35
    elseif biome == "snowy_peak" then
        mountain_boost = 0.55
    end

    local terrain =
        n_cont * 0.9 +
        (0.5 - n_eros) * 0.7 +
        math.max(n_ridge,0)^1.4 * 1.2 -
        ny * 1.2 +
        mountain_boost

    local caves = n_cheese - math.abs(n_second)

    return terrain - caves * 0.9
end

local function idx3d(x,y,z,minp,dim)
    return ((z-minp.z)*dim.y + (y-minp.y))*dim.x + (x-minp.x+1)
end

-- ======================================================
-- MAPGEN
-- ======================================================

minetest.register_on_generated(function(minp,maxp,seed)
    local vm,emin,emax = minetest.get_mapgen_object("voxelmanip")
    local area = VoxelArea:new({MinEdge=emin,MaxEdge=emax})
    local data = vm:get_data()

    local c_air   = minetest.get_content_id("air")
    local c_stone = minetest.get_content_id("cw_core:stone")
    local c_water = minetest.get_content_id("cw_core:water_source")
    local c_grass = minetest.get_content_id("cw_core:grass_block")
    local c_dirt  = minetest.get_content_id("cw_core:dirt")
    local c_sand  = minetest.get_content_id("cw_core:sand")
    local c_snow  = minetest.get_content_id("cw_core:snow")

    local dim = {
        x = maxp.x-minp.x+1,
        y = maxp.y-minp.y+1,
        z = maxp.z-minp.z+1,
    }

    -- noise maps
    local biome_vals  = minetest.get_perlin_map(np_biome,dim):get_3d_map_flat(minp)
    local cont_vals   = minetest.get_perlin_map(np_continentalness,dim):get_3d_map_flat(minp)
    local eros_vals   = minetest.get_perlin_map(np_erosion,dim):get_3d_map_flat(minp)
    local ridge_vals  = minetest.get_perlin_map(np_ridges,dim):get_3d_map_flat(minp)
    local cheese_vals = minetest.get_perlin_map(np_cave_cheese,dim):get_3d_map_flat(minp)
    local second_vals = minetest.get_perlin_map(np_cave_second,dim):get_3d_map_flat(minp)

    -- ==================================================
    -- PASS 1: DENSITY CARVING
    -- ==================================================

    local i = 1
    for z=minp.z,maxp.z do
    for y=minp.y,maxp.y do
    for x=minp.x,maxp.x do

        local biome = get_biome(biome_vals[i])

        local d = compute_density(
            x,y,z,
            cont_vals[i],
            eros_vals[i],
            ridge_vals[i],
            cheese_vals[i],
            second_vals[i],
            biome
        )

        local vi = area:index(x,y,z)

        if d > 0 then
            data[vi] = c_stone
        else
            data[vi] = (y <= SEA_LEVEL) and c_water or c_air
        end

        i = i + 1
    end end end

    -- ==================================================
    -- PASS 2: SURFACE RULES (BIOME-BASED)
    -- ======================================================

    for x=minp.x,maxp.x do
    for z=minp.z,maxp.z do

        local surface_y = nil

        for y=maxp.y,minp.y,-1 do
            local id = data[area:index(x,y,z)]
            if id ~= c_air and id ~= c_water then
                surface_y = y
                break
            end
        end

        if surface_y then
            local vi = area:index(x,surface_y,z)
            local biome = get_biome(biome_vals[idx3d(x,surface_y,z,minp,dim)])

            -- PLAINS OVERRIDE
            if biome == "plains" then
                data[vi] = c_grass
                for d=1,SOIL_DEPTH do
                    local yi = surface_y-d
                    if yi < minp.y then break end
                    local vi2 = area:index(x,yi,z)
                    if data[vi2] == c_stone then data[vi2] = c_dirt end
                end

            -- BEACHES
            elseif surface_y <= SEA_LEVEL + BEACH_WIDTH then
                data[vi] = c_sand
                for d=1,SOIL_DEPTH do
                    local yi = surface_y-d
                    if yi < minp.y then break end
                    local vi2 = area:index(x,yi,z)
                    if data[vi2] == c_stone or data[vi2] == c_dirt then
                        data[vi2] = c_sand
                    end
                end

            -- SNOWY PEAKS
            elseif biome == "snowy_peak" then
                data[vi] = c_snow

            -- MOUNTAINS (stone only)
            elseif biome == "mountain" then
                if surface_y >= SNOWLINE then
                    data[vi] = c_snow
                else
                    data[vi] = c_stone
                end

            -- FOREST / BIRCH / CHERRY
            else
                data[vi] = c_grass
                for d=1,SOIL_DEPTH do
                    local yi = surface_y-d
                    if yi < minp.y then break end
                    local vi2 = area:index(x,yi,z)
                    if data[vi2] == c_stone then data[vi2] = c_dirt end
                end
            end
        end
    end end

    vm:set_data(data)
    vm:write_to_map()
    vm:update_map()
end)

-- ======================================================
-- BIOME REGISTRATION (needed for trees)
-- ======================================================

local function reg_biome(name)
    minetest.register_biome({
        name = name,
        node_top = "cw_core:grass_block",
        depth_top = 1,
        node_filler = "cw_core:dirt",
        depth_filler = 3,
        y_min = MIN_HEIGHT,
        y_max = MAX_HEIGHT,
    })
end

reg_biome("plains")
reg_biome("forest")
reg_biome("birch")
reg_biome("cherry")
reg_biome("mountain")
reg_biome("snowy_peak")

