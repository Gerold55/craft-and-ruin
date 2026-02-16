-- ============================================================================
-- Craft & Ruin — Custom V7 Terrain Generator (Full Replacement)
-- Option E‑1: Full custom terrain, oceans, rivers, clusters, decor, trees
-- ============================================================================

local SEALEVEL = 63

-- Content IDs
local c_air        = minetest.CONTENT_AIR
local c_stone      = minetest.get_content_id("cw_core:stone")
local c_dirt       = minetest.get_content_id("cw_core:dirt")
local c_grass      = minetest.get_content_id("cw_core:grass_block")
local c_sand       = minetest.get_content_id("cw_core:beach_sand")
local c_water      = minetest.get_content_id("cw_core:water_source")
local c_gravel     = minetest.get_content_id("cw_core:gravel")
local c_clay       = minetest.get_content_id("cw_core:clay")

-- Rare rivers
local RIVER_THRESHOLD = 0.010

-- ============================================================================
-- LOAD NOISEPARAMS FROM ENGINE SETTINGS
-- ============================================================================

local np_base   = minetest.get_mapgen_setting_noiseparams("mgv7_np_terrain_base")
local np_alt    = minetest.get_mapgen_setting_noiseparams("mgv7_np_terrain_alt")
local np_height = minetest.get_mapgen_setting_noiseparams("mgv7_np_height_select")

local np_river = {
    offset = 0, scale = 1,
    spread = {x=200,y=200,z=200},
    seed = 9001, octaves = 4, persistence = 0.5
}

local np_cluster = {
    offset = 0, scale = 1,
    spread = {x=80,y=80,z=80},
    seed = 12345, octaves = 3, persistence = 0.6
}

-- ============================================================================
-- PERLIN MAP OBJECTS
-- ============================================================================

local pm_base    = minetest.get_perlin_map(np_base,    {x=80, y=80, z=80})
local pm_alt     = minetest.get_perlin_map(np_alt,     {x=80, y=80, z=80})
local pm_height  = minetest.get_perlin_map(np_height,  {x=80, y=80, z=80})
local pm_river   = minetest.get_perlin_map(np_river,   {x=80, y=80, z=80})
local pm_cluster = minetest.get_perlin_map(np_cluster, {x=80, y=80, z=80})

-- ============================================================================
-- HEIGHTMAP
-- ============================================================================

local function get_height(x, z)
    local p = {x=x, y=z}

    local base = pm_base:get_2d(p) * 20 + 4
    local alt  = pm_alt:get_2d(p)  * 15 + 6
    local sel  = pm_height:get_2d(p)

    return math.floor(base * (1 - sel) + alt * sel)
end

-- ============================================================================
-- RIVER MASK
-- ============================================================================

local function get_river(x, z)
    return math.abs(pm_river:get_2d({x=x, y=z}))
end

-- ============================================================================
-- NATURAL CLUSTER MATERIAL
-- ============================================================================

local function choose_cluster(x, y, z)
    local v = pm_cluster:get_3d({x=x, y=y, z=z})
    if v > 0.35 then return c_gravel end
    if v < -0.35 then return c_clay end
    return c_stone
end

-- ============================================================================
-- SIMPLE BIOME SELECTION
-- ============================================================================

local function get_biome(x, y, z)
    if y < SEALEVEL then return "ocean" end
    if y < SEALEVEL + 4 then return "beach" end

    local h = get_height(x, z)
    if h < 10 then return "plains" end
    if h < 20 then return "forest" end
    if h < 30 then return "birch" end
    return "cherry"
end

-- ============================================================================
-- MAIN MAPGEN
-- ============================================================================

minetest.register_on_generated(function(minp, maxp, seed)
    local t0 = minetest.get_us_time()

    local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
    local area = VoxelArea:new({MinEdge=emin, MaxEdge=emax})
    local data = vm:get_data()

    local x0, y0, z0 = minp.x, minp.y, minp.z
    local x1, y1, z1 = maxp.x, maxp.y, maxp.z

    if y1 < 0 or y0 > 200 then return end

    for z = z0, z1 do
        for x = x0, x1 do

            local height = get_height(x, z)
            local rv = get_river(x, z)
            local is_river = rv < RIVER_THRESHOLD

            if is_river then
                height = height - 4
            end

            for y = y0, y1 do
                local vi = area:index(x, y, z)

                if y <= height then
                    data[vi] = choose_cluster(x, y, z)

                elseif y <= SEALEVEL then
                    data[vi] = c_water

                else
                    data[vi] = c_air
                end
            end

            -- Surface
            local surface_y = height
            if surface_y >= y0 and surface_y <= y1 then
                local vi = area:index(x, surface_y, z)
                local biome = get_biome(x, surface_y, z)

                if biome == "ocean" or biome == "beach" then
                    data[vi] = c_sand
                else
                    data[vi] = c_grass
                end

                for dy = 1, 3 do
                    local yi = surface_y - dy
                    if yi >= y0 then
                        local vi2 = area:index(x, yi, z)
                        data[vi2] = c_dirt
                    end
                end
            end
        end
    end

    vm:set_data(data)
    vm:write_to_map()
    vm:update_map()

    -- ============================================================================
    -- POSTGEN: TREES + DECOR
    -- ============================================================================

    for z = z0, z1 do
        for x = x0, x1 do
            local height = get_height(x, z)
            local surface_y = height

            if surface_y >= y0 and surface_y <= y1 then
                local biome = get_biome(x, surface_y, z)

                if biome == "forest" or biome == "birch" or biome == "cherry" then
                    if math.random() < 0.04 then
                        cw_grow_tree({x=x, y=surface_y+1, z=z}, biome)
                    end
                end

                cw_mapgen_place_decor({x=x, y=surface_y+1, z=z}, biome)
            end
        end
    end

    local t1 = minetest.get_us_time()
    minetest.log("action", "[cw_mapgen] chunk generated in " .. (t1 - t0) .. " µs")
end)

