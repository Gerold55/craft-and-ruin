-- ============================================================================
-- CRAFT & RUIN MAPGEN (CLEAN VERSION — NO WATER)
-- Terrain → Caves → Surface → Decorations → WRITE
-- ============================================================================

local c_air        = minetest.get_content_id("air")
local c_stone      = minetest.get_content_id("cw_core:stone")
local c_dirt       = minetest.get_content_id("cw_core:dirt")
local c_grass      = minetest.get_content_id("cw_core:grass_block")
local c_sand       = minetest.get_content_id("cw_core:sand")

local c_leaves_oak    = minetest.get_content_id("cw_core:leaves_oak")
local c_leaves_birch  = minetest.get_content_id("cw_core:leaves_birch")
local c_leaves_cherry = minetest.get_content_id("cw_core:leaves_cherry")

local c_grass_decor     = minetest.get_content_id("cw_core:grass_decor")
local c_flower_daisy    = minetest.get_content_id("cw_core:flower_daisy")
local c_flower_bluebell = minetest.get_content_id("cw_core:flower_bluebell")

-- Add your mushrooms / dead bush if needed
-- local c_mushroom_brown = ...
-- local c_mushroom_red   = ...
-- local c_dead_bush      = ...

-- ============================================================================
-- HEIGHT NOISE
-- ============================================================================

local n_base = PerlinNoise({offset=0,scale=1,spread={x=512,y=512,z=512},seed=12345,octaves=3,persist=0.5})
local n_hills = PerlinNoise({offset=0,scale=1,spread={x=256,y=256,z=256},seed=54321,octaves=4,persist=0.5})
local n_mountains = PerlinNoise({offset=0,scale=1,spread={x=384,y=384,z=384},seed=98765,octaves=5,persist=0.6})

local function get_height_raw(x, z)
    local base = 60 + n_base:get_2d({x=x,y=z}) * 10
    local hills = math.max(0, n_hills:get_2d({x=x,y=z})) * 20
    local mountains = math.max(0, n_mountains:get_2d({x=x,y=z}) - 0.25) * 80
    local h = base + hills + mountains
    return math.min(math.max(h, 40), 140)
end

-- ============================================================================
-- BIOME NOISE
-- ============================================================================

local n_heat = PerlinNoise({offset=50,scale=50,spread={x=256,y=256,z=256},seed=11111,octaves=3,persist=0.5})
local n_humidity = PerlinNoise({offset=50,scale=50,spread={x=256,y=256,z=256},seed=22222,octaves=3,persist=0.5})

local function get_biome(x, z, h)
    local heat = n_heat:get_2d({x=x,y=z})
    local hum  = n_humidity:get_2d({x=x,y=z})

    if heat > 70 and hum < 30 then return "desert" end
    if h > 85 and heat < 45 and hum > 40 then return "cherry" end
    if heat < 55 and hum > 55 then return "birch" end
    return "plains"
end

-- ============================================================================
-- SOLID CHECK (for true surface detection)
-- ============================================================================

local function is_solid(node)
    return node ~= c_air
       and node ~= c_leaves_oak
       and node ~= c_leaves_birch
       and node ~= c_leaves_cherry
       and node ~= c_grass_decor
       and node ~= c_flower_daisy
       and node ~= c_flower_bluebell
end

-- ============================================================================
-- MAIN MAPGEN (NO WATER)
-- ============================================================================

minetest.register_on_generated(function(minp, maxp)
    local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
    local area = VoxelArea:new({MinEdge=emin, MaxEdge=emax})
    local data = vm:get_data()

    local pr = PseudoRandom(minp.x * 13 + minp.z * 37)

    -- PASS 1: terrain, caves, surface
    for z = minp.z, maxp.z do
        for x = minp.x, maxp.x do

            local h_raw = get_height_raw(x, z)
            local biome = get_biome(x, z, h_raw)
            local h = math.floor(h_raw)
            local h_top = math.min(h, maxp.y)

            -- stone
            for y = minp.y, h_top do
                data[area:index(x,y,z)] = c_stone
            end

            -- caves
            for y = minp.y, h_top do
                cw_mapgen_carve_caves(data, area, x, y, z, h_top)
            end

            -- air above
            for y = h_top+1, maxp.y do
                data[area:index(x,y,z)] = c_air
            end

            -- surface
            if biome == "desert" then
                for y = h_top-4, h_top do
                    if y >= minp.y then
                        data[area:index(x,y,z)] = c_sand
                    end
                end
            else
                if h_top >= minp.y then data[area:index(x,h_top,z)] = c_grass end
                if h_top-1 >= minp.y then data[area:index(x,h_top-1,z)] = c_dirt end
            end
        end
    end

    -- PASS 2: decorations (no water)
    for z = minp.z, maxp.z do
        for x = minp.x, maxp.x do

            -- true surface height
            local real_h = nil
            for y = maxp.y, minp.y, -1 do
                local vi = area:index(x,y,z)
                if is_solid(data[vi]) then
                    real_h = y
                    break
                end
            end
            if not real_h then goto continue end

            local h_raw = get_height_raw(x, z)
            local biome = get_biome(x, z, h_raw)

            -- DECORATIONS
            if biome == "plains" then
                if pr:next(1, 20) == 1 then
                    data[area:index(x, real_h+1, z)] = c_flower_daisy
                end
                if pr:next(1, 10) == 1 then
                    data[area:index(x, real_h+1, z)] = c_grass_decor
                end

            elseif biome == "birch" then
                if pr:next(1, 30) == 1 then
                    data[area:index(x, real_h+1, z)] = c_flower_bluebell
                end
                if pr:next(1, 12) == 1 then
                    data[area:index(x, real_h+1, z)] = c_grass_decor
                end

            elseif biome == "cherry" then
                if pr:next(1, 14) == 1 then
                    data[area:index(x, real_h+1, z)] = c_grass_decor
                end

            elseif biome == "desert" then
                -- add dead bushes or cactus later
            end

            ::continue::
        end
    end

    vm:set_data(data)
    vm:write_to_map()
    vm:update_map()
end)
