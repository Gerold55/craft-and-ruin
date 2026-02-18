-- ============================================================================
-- Craft & Ruin — MAPGEN (PART 1 / 3)
-- Safe noise manager, constants, mesa palette, helpers
-- ============================================================================

local modname = minetest.get_current_modname()

-- ============================================================================
-- CONSTANTS
-- ============================================================================

SEA_LEVEL = 1

local c_air         = minetest.get_content_id("air")
local c_stone       = minetest.get_content_id("cw_core:stone")
local c_dirt        = minetest.get_content_id("cw_core:dirt")
local c_grass       = minetest.get_content_id("cw_core:grass_block")
local c_sand        = minetest.get_content_id("cw_core:sand")
local c_water       = minetest.get_content_id("cw_core:water_source")

-- ============================================================================
-- MESA TERRACOTTA PALETTE (YOUR EXACT IDS)
-- ============================================================================

local mesa_palette = {
    "cw_core:terracotta_white",
    "cw_core:terracotta_orange",
    "cw_core:terracotta_yellow",
    "cw_core:terracotta_brown",
    "cw_core:terracotta_red",
}

-- Convert to content IDs for speed
for i = 1, #mesa_palette do
    mesa_palette[i] = minetest.get_content_id(mesa_palette[i])
end

-- ============================================================================
-- SAFE NOISE MANAGER (ALL NOISES CENTRALIZED)
-- ============================================================================

local Noise = {}

local function make_perlin(def)
    return minetest.get_perlin(def)
end

local function init_noise()
    Noise.terrain = make_perlin({
        offset = 0, scale = 1,
        spread = {x=512, y=256, z=512},
        seed = 10001, octaves = 5, persist = 0.5
    })

    Noise.mountain = make_perlin({
        offset = 0, scale = 1,
        spread = {x=768, y=384, z=768},
        seed = 10002, octaves = 5, persist = 0.55
    })

    Noise.ridge = make_perlin({
        offset = 0, scale = 1,
        spread = {x=512, y=256, z=512},
        seed = 10003, octaves = 4, persist = 0.5
    })

    Noise.valley = make_perlin({
        offset = 0, scale = 1,
        spread = {x=512, y=256, z=512},
        seed = 10004, octaves = 4, persist = 0.5
    })

    Noise.beach = make_perlin({
        offset = 0, scale = 1,
        spread = {x=256, y=128, z=256},
        seed = 10005, octaves = 3, persist = 0.5
    })

    Noise.clay = make_perlin({
        offset = 0, scale = 1,
        spread = {x=128, y=64, z=128},
        seed = 10006, octaves = 3, persist = 0.5
    })

    Noise.deep = make_perlin({
        offset = 0, scale = 1,
        spread = {x=512, y=256, z=512},
        seed = 10007, octaves = 4, persist = 0.5
    })

    Noise.cave = make_perlin({
        offset = 0, scale = 1,
        spread = {x=64, y=32, z=64},
        seed = 10008, octaves = 4, persist = 0.5
    })
end

-- Initialize once
init_noise()

local function get_noise(name)
    if not Noise[name] then
        init_noise()
    end
    return Noise[name]
end

-- ============================================================================
-- HELPER: GET HEIGHT FROM TERRAIN NOISE
-- ============================================================================

local function get_height(x, z)
    local n_terr  = get_noise("terrain"):get_2d({x=x, y=z})
    local n_mnt   = get_noise("mountain"):get_2d({x=x, y=z})
    local n_ridge = get_noise("ridge"):get_2d({x=x, y=z})
    local n_val   = get_noise("valley"):get_2d({x=x, y=z})

    -- Base terrain
    local h = n_terr * 20

    -- Mountains
    if n_mnt > 0.4 then
        h = h + (n_mnt - 0.4) * 80
    end

    -- Ridges
    h = h + n_ridge * 10

    -- Valleys
    h = h - math.abs(n_val) * 8

    return math.floor(h)
end

-- ============================================================================
-- MESA TERRACOTTA BANDING
-- ============================================================================

local function get_mesa_color(y)
    -- Mesa bands repeat every 5 nodes
    local band = (math.floor(y / 5) % #mesa_palette) + 1
    return mesa_palette[band]
end

local function is_mesa_biome(biome)
    return biome == "mesa" or biome == "badlands"
end

-- ============================================================================
-- DEEP OCEAN SHAPING
-- ============================================================================

local function get_ocean_depth(x, z)
    local n_deep = get_noise("deep"):get_2d({x=x, y=z})
    -- Deep oceans: -20 to -50
    return -20 - math.floor(n_deep * 30)
end

-- ============================================================================
-- CLAY POCKETS (RIVERBEDS, LAKES, BEACHES)
-- ============================================================================

local function is_clay_here(x, y, z)
    local n = get_noise("clay"):get_3d({x=x, y=y, z=z})
    return n > 0.55
end

-- ============================================================================
-- CAVE CARVER (SAFE VERSION)
-- ============================================================================

local function carve_caves(area, data, minp, maxp)
    local n_cave = get_noise("cave")

    for idx in area:iterp(minp, maxp) do
        local pos = area:position(idx)

        if pos.y < SEA_LEVEL - 1 then
            local n = n_cave:get_3d(pos)
            if n > 0.35 then
                data[idx] = c_air
            end
        end
    end
end

-- ============================================================================
-- TERRAIN FILL LOOP
-- ============================================================================

local function generate_terrain(area, data, minp, maxp)
    local emin, emax = area.MinEdge, area.MaxEdge

    for z = minp.z, maxp.z do
        for x = minp.x, maxp.x do

            --------------------------------------------------------------------
            -- HEIGHT
            --------------------------------------------------------------------
            local h = get_height(x, z)

            -- Deep ocean override
            if h < SEA_LEVEL then
                local deep = get_ocean_depth(x, z)
                if h < deep then
                    h = deep
                end
            end

            --------------------------------------------------------------------
            -- CLIMATE (SAFE)
            --------------------------------------------------------------------
            local cl = climate.get_climate(x, z)
            if not cl or not cl.temp then
                -- fallback climate (never crash)
                cl = {
                    temp = 0,
                    humid = 0,
                    cont = 0,
                    eros = 0,
                    climate_zone = "temperate_medium"
                }
            end

            --------------------------------------------------------------------
            -- BIOME (SAFE)
            --------------------------------------------------------------------
            local biome = biomes.get_biome(x, z, h, 0, cl)
            if not biome then
                biome = "plains" -- safe fallback
            end

            --------------------------------------------------------------------
            -- TERRAIN FILL
            --------------------------------------------------------------------
            for y = minp.y, maxp.y do
                local vi = area:index(x, y, z)

                if y <= h then
                    ----------------------------------------------------------------
                    -- BASE STONE
                    ----------------------------------------------------------------
                    data[vi] = c_stone

                    ----------------------------------------------------------------
                    -- MESA TERRACOTTA
                    ----------------------------------------------------------------
                    if is_mesa_biome(biome) then
                        data[vi] = get_mesa_color(y)

                    ----------------------------------------------------------------
                    -- CLAY POCKETS
                    ----------------------------------------------------------------
                    elseif is_clay_here(x, y, z) then
                        data[vi] = minetest.get_content_id("cw_core:clay")
                    end

                elseif y <= SEA_LEVEL then
                    ----------------------------------------------------------------
                    -- WATER
                    ----------------------------------------------------------------
                    data[vi] = c_water
                end
            end
        end
    end
end

-- ============================================================================
-- SURFACE PLACEMENT
-- ============================================================================

local function place_surface(area, data, x, z, h, biome)
    local top_vi = area:index(x, h, z)
    local under_vi = area:index(x, h - 1, z)

    -- Mesa biomes use terracotta bands (already placed in PART 2)
    if biome == "mesa" or biome == "badlands" then
        return
    end

    -- Beaches
    if biome == "beach" then
        data[top_vi] = c_sand
        data[under_vi] = c_sand
        return
    end

    -- Snow biomes
    if biome == "snow" or biome == "tundra" or biome == "taiga" then
        data[top_vi] = minetest.get_content_id("cw_core:snow")
        data[under_vi] = c_dirt
        return
    end

    -- Default: grass + dirt
    data[top_vi] = c_grass
    data[under_vi] = c_dirt
end

-- ============================================================================
-- TREE + DECOR HOOKS (STUBS FOR NOW)
-- ============================================================================

local function place_trees_and_decor(area, data, x, z, h, biome)
    -- You can expand this later:
    -- if biome == "forest" then spawn_oak_tree(...)
    -- if biome == "taiga" then spawn_spruce_tree(...)
    -- if biome == "jungle" then spawn_jungle_tree(...)
    -- if biome == "savanna" then spawn_acacia_tree(...)
end

-- ============================================================================
-- FINAL ON_GENERATED CALLBACK
-- ============================================================================

minetest.register_on_generated(function(minp, maxp, seed)
    local t0 = minetest.get_us_time()

    local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
    local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
    local data = vm:get_data()

    -- PART 2: terrain fill
    generate_terrain(area, data, minp, maxp)

    -- PART 2: caves
    carve_caves(area, data, minp, maxp)

    -- PART 3: surface + decor
    for z = minp.z, maxp.z do
        for x = minp.x, maxp.x do
            local h = get_height(x, z)

            -- Deep ocean override
            if h < SEA_LEVEL then
                local deep = get_ocean_depth(x, z)
                if h < deep then
                    h = deep
                end
            end

            -- Biome from climate
            local cl = climate.get_climate(x, z)
            local biome = biomes.get_biome(x, z, h, 0, cl)

            -- Surface placement
            if h >= minp.y and h <= maxp.y then
                place_surface(area, data, x, z, h, biome)
            end

            -- Trees + decor
            place_trees_and_decor(area, data, x, z, h, biome)
        end
    end

    vm:set_data(data)
    vm:write_to_map()
    vm:update_map()

    local t1 = minetest.get_us_time()
    minetest.log("action", "[cw_mapgen] Chunk generated in " .. (t1 - t0) .. " µs")
end)

