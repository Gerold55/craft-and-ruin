-- ============================================================================
-- Craft & Ruin — v7 Mapgen (MC-Scale Terrain, Sea Level 1)
-- Biome Zones + Decorations Restored (Grass, Flowers, Mushrooms, Dead Bush)
-- ============================================================================

local SEALEVEL = 1
local SNOW_LINE = 90
local TERRAIN_OFFSET = 0

-- Content IDs
local c_air        = minetest.CONTENT_AIR
local c_stone      = minetest.get_content_id("cw_core:stone")
local c_water      = minetest.get_content_id("cw_core:water_source")
local c_grass      = minetest.get_content_id("cw_core:grass_block")
local c_dirt       = minetest.get_content_id("cw_core:dirt")
local c_snow_block = minetest.get_content_id("cw_core:snow_block")

local c_snow_1 = minetest.get_content_id("cw_core:snow_layer_1")
local c_snow_2 = minetest.get_content_id("cw_core:snow_layer_2")
local c_snow_4 = minetest.get_content_id("cw_core:snow_layer_4")

-- Decor nodes you confirmed exist
local c_grass_decor     = minetest.get_content_id("cw_core:grass_decor")
local c_flower_bluebell = minetest.get_content_id("cw_core:flower_bluebell")
local c_flower_daisy    = minetest.get_content_id("cw_core:flower_daisy")
local c_dead_bush       = minetest.get_content_id("cw_core:dead_bush")
local c_mushroom_red    = minetest.get_content_id("cw_core:mushroom_red")
local c_mushroom_brown  = minetest.get_content_id("cw_core:mushroom_brown")

-- ============================================================================
-- Noise Definitions
-- ============================================================================

local n_biome, n_temp, n_humid, n_cherry, n_clay, n_cave, n_deep, n_zone

local biome_noise = {offset=0,scale=1,spread={x=512,y=512,z=512},seed=10001,octaves=3,persist=0.5}
local temp_noise  = {offset=0,scale=1,spread={x=256,y=256,z=256},seed=10002,octaves=3,persist=0.5}
local humid_noise = {offset=0,scale=1,spread={x=256,y=256,z=256},seed=10003,octaves=3,persist=0.5}
local cherry_noise= {offset=0,scale=1,spread={x=128,y=128,z=128},seed=10004,octaves=3,persist=0.5}

-- Mesa spire noise
local clayspire_noise = {offset=0,scale=1,spread={x=96,y=64,z=96},seed=10005,octaves=4,persist=0.55}

-- Deep ocean rugged floor noise
local deep_noise = {offset=0,scale=1,spread={x=128,y=64,z=128},seed=10007,octaves=4,persist=0.5}

-- Caves
local cave_noise = {offset=0,scale=1,spread={x=64,y=32,z=64},seed=10006,octaves=4,persist=0.5}

-- ⭐ NEW: Biome Zone Noise (fixes biome mingling)
local zone_noise = {
    offset = 0,
    scale = 1,
    spread = {x=1024, y=1024, z=1024},
    seed = 20001,
    octaves = 4,
    persist = 0.5,
}

-- ============================================================================
-- Mesa Terracotta System
-- ============================================================================

local mesa_palette = {
    cw_terracotta.white,
    cw_terracotta.orange,
    cw_terracotta.yellow,
    cw_terracotta.brown,
    cw_terracotta.red,
}

local function mesa_color_for_y(y)
    local band_height = 8 + (y % 5)
    local idx = math.floor(y / band_height) % #mesa_palette
    return mesa_palette[idx + 1]
end

local function build_clayspire_column(area, data, x, z, h, y0, y1, spire_noise)
    local top = h

    -- Tall Bryce-style spires (MC-scale)
    local spire = spire_noise:get_3d({x=x, y=h, z=z})
    if spire > 0.55 then
        top = top + math.floor((spire - 0.55) * 80)
    end

    -- Erosion mask
    local erode = spire_noise:get_2d({x=x, y=z})
    if erode < -0.2 then
        top = top - math.floor((-erode) * 6)
    end

    -- Build terracotta stack
    for yy = top, top - 60, -1 do
        if yy < y0 then break end
        if yy > y1 then goto continue end

        local vi = area:index(x, yy, z)
        local terracotta = mesa_color_for_y(yy)
        data[vi] = minetest.get_content_id(terracotta)

        ::continue::
    end
end

-- ============================================================================
-- Biome Selection (with biome zones)
-- ============================================================================

local function get_biome(x, z, y, s, b, t, h, ch, clay, zone)

    -- Zone families
    -- zone < -0.33 = cold
    -- zone <  0.33 = temperate
    -- else         = warm

    -- Deep ocean
    if y < -10 then return "deep_ocean" end

    -- Shallow ocean
    if y < 1 then return "ocean" end

    -- COLD FAMILY -------------------------------------------------------------
    if zone < -0.33 then
        if y > 80 and t < -0.25 then return "ice_biome" end
        if y > 70 or s > 2.5 then return "mountains" end
        if t < -0.1 and h > 0 and y > 35 and y < 65 then return "taiga_forest" end
        if t < -0.05 and y > 35 and y < 65 and s < 1.5 then return "spruce_forest" end
        return "forest"
    end

    -- TEMPERATE FAMILY --------------------------------------------------------
    if zone < 0.33 then
        if y > 45 and y < 75 and s < 1.2 and ch > 0.55 then return "cherry_grove" end
        if y > 30 and y < 55 and s < 1.0 and math.abs(b) < 0.1 then return "birch_forest" end
        if s < 1.0 and y > 25 and y < 45 then return "meadows" end
        if s >= 1.0 and s < 2.5 and y > 30 and y < 60 then return "rolling_hills" end
        if y < 25 and s < 1.2 then return "plains" end
        return "forest"
    end

    -- WARM FAMILY -------------------------------------------------------------
    if t > 0.35 and h > 0.35 and y > 5 and y < 45 then return "jungle" end
    if y > 10 and y < 50 and clay > 0.55 then return "clayspire_basin" end

    return "forest"
end

-- ============================================================================
-- DECORATION + TREE FUNCTIONS (FINAL, SAFE)
-- ============================================================================

local function place_tree(pos, biome)
    -- Placeholder trees until you add real schematics
    if biome == "forest" then
        if math.random(1, 25) == 1 then
            minetest.spawn_tree(pos, {axiom="FFFF", rules_a={}})
        end
    elseif biome == "birch_forest" then
        if math.random(1, 30) == 1 then
            minetest.spawn_tree(pos, {axiom="FFFF", rules_a={}})
        end
    elseif biome == "spruce_forest" or biome == "taiga_forest" then
        if math.random(1, 35) == 1 then
            minetest.spawn_tree(pos, {axiom="FFFF", rules_a={}})
        end
    elseif biome == "jungle" then
        if math.random(1, 20) == 1 then
            minetest.spawn_tree(pos, {axiom="FFFF", rules_a={}})
        end
    elseif biome == "cherry_grove" then
        if math.random(1, 40) == 1 then
            minetest.spawn_tree(pos, {axiom="FFFF", rules_a={}})
        end
    end
end


local function place_decor(pos, biome)
    -- Plains: grass + occasional flowers
    if biome == "plains" then
        if math.random(1, 4) == 1 then
            minetest.set_node(pos, {name="cw_core:grass_decor"})
        elseif math.random(1, 20) == 1 then
            minetest.set_node(pos, {name="cw_core:flower_daisy"})
        end

    -- Meadows: more flowers
    elseif biome == "meadows" then
        if math.random(1, 3) == 1 then
            minetest.set_node(pos, {name="cw_core:grass_decor"})
        elseif math.random(1, 12) == 1 then
            minetest.set_node(pos, {name="cw_core:flower_bluebell"})
        elseif math.random(1, 14) == 1 then
            minetest.set_node(pos, {name="cw_core:flower_daisy"})
        end

    -- Forests: sparse grass + mushrooms
    elseif biome == "forest" or biome == "birch_forest" then
        if math.random(1, 6) == 1 then
            minetest.set_node(pos, {name="cw_core:grass_decor"})
        elseif math.random(1, 40) == 1 then
            minetest.set_node(pos, {name="cw_core:mushroom_red"})
        elseif math.random(1, 40) == 1 then
            minetest.set_node(pos, {name="cw_core:mushroom_brown"})
        end

    -- Taiga / Spruce: very sparse + mushrooms
    elseif biome == "spruce_forest" or biome == "taiga_forest" then
        if math.random(1, 10) == 1 then
            minetest.set_node(pos, {name="cw_core:grass_decor"})
        elseif math.random(1, 50) == 1 then
            minetest.set_node(pos, {name="cw_core:mushroom_brown"})
        end

    -- Jungle: dense grass_decor
    elseif biome == "jungle" then
        if math.random(1, 2) == 1 then
            minetest.set_node(pos, {name="cw_core:grass_decor"})
        end

    -- Cherry Grove: soft flowers + grass
    elseif biome == "cherry_grove" then
        if math.random(1, 5) == 1 then
            minetest.set_node(pos, {name="cw_core:grass_decor"})
        elseif math.random(1, 18) == 1 then
            minetest.set_node(pos, {name="cw_core:flower_bluebell"})
        end

    -- Mesa: dead bushes
    elseif biome == "clayspire_basin" then
        if math.random(1, 25) == 1 then
            minetest.set_node(pos, {name="cw_core:dead_bush"})
        end
    end
end

-- ============================================================================
-- Main Mapgen
-- ============================================================================

minetest.register_on_generated(function(minp, maxp, seed)
    local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
    local area = VoxelArea:new({MinEdge=emin, MaxEdge=emax})
    local data = vm:get_data()

    local raw_hmap = minetest.get_mapgen_object("heightmap")
    local hmap = {}

    local x0,y0,z0 = minp.x,minp.y,minp.z
    local x1,y1,z1 = maxp.x,maxp.y,maxp.z
    local stride = (x1 - x0 + 1)

    -- Init noise
    n_biome   = n_biome   or minetest.get_perlin(biome_noise)
    n_temp    = n_temp    or minetest.get_perlin(temp_noise)
    n_humid   = n_humid   or minetest.get_perlin(humid_noise)
    n_cherry  = n_cherry  or minetest.get_perlin(cherry_noise)
    n_clay    = n_clay    or minetest.get_perlin(clayspire_noise)
    n_cave    = n_cave    or minetest.get_perlin(cave_noise)
    n_deep    = n_deep    or minetest.get_perlin(deep_noise)
    n_zone    = n_zone    or minetest.get_perlin(zone_noise)

    -- Heightmap fix
    local i = 1
    for z=z0,z1 do
        for x=x0,x1 do
            local rh = raw_hmap[i]
            hmap[i] = (rh ~= -31000) and (rh + TERRAIN_OFFSET) or nil
            i = i + 1
        end
    end

    -- Surface pass
    i = 1
    for z=z0,z1 do
        for x=x0,x1 do
            local h = hmap[i]
            if h then
                local hx = hmap[i+1] or h
                local hz = hmap[i+stride] or h
                local s = math.abs(h - hx) + math.abs(h - hz)

                local b = n_biome:get_2d({x=x,y=z})
                local t = n_temp:get_2d({x=x,y=z})
                local hu= n_humid:get_2d({x=x,y=z})
                local ch= n_cherry:get_2d({x=x,y=z})
                local cl= n_clay:get_2d({x=x,y=z})
                local zone = n_zone:get_2d({x=x,y=z})

                local biome = get_biome(x,z,h,s,b,t,hu,ch,cl,zone)

                if h >= y0 and h <= y1 then
                    local vi = area:index(x,h,z)

                    if biome == "clayspire_basin" then
                        build_clayspire_column(area, data, x, z, h, y0, y1, n_clay)

                    elseif biome == "mountains" then
                        if h >= SNOW_LINE + 20 then
                            data[vi] = c_snow_block
                        elseif h >= SNOW_LINE + 10 then
                            data[vi] = c_snow_block
                            data[area:index(x,h+1,z)] = c_snow_4
                        elseif h >= SNOW_LINE + 5 then
                            data[vi] = c_grass
                            data[area:index(x,h+1,z)] = c_snow_2
                        elseif h >= SNOW_LINE then
                            data[vi] = c_grass
                            data[area:index(x,h+1,z)] = c_snow_1
                        else
                            data[vi] = c_grass
                        end
                        for dy=1,3 do
                            local yi = h - dy
                            if yi >= y0 then data[area:index(x,yi,z)] = c_dirt end
                        end

                    elseif biome == "ice_biome" then
                        data[vi] = c_snow_block
                        for dy=1,3 do
                            local yi = h - dy
                            if yi >= y0 then data[area:index(x,yi,z)] = c_dirt end
                        end

                    elseif biome == "ocean" or biome == "deep_ocean" then
                        if biome == "deep_ocean" then
                            local d = n_deep:get_3d({x=x,y=h,z=z})
                            if d > 0.4 then
                                data[vi] = c_stone
                            end
                        end

                    else
                        data[vi] = c_grass
                        for dy=1,3 do
                            local yi = h - dy
                            if yi >= y0 then data[area:index(x,yi,z)] = c_dirt end
                        end
                    end
                end
            end
            i = i + 1
        end
    end

    -- Caves
    if maxp.y < SEALEVEL - 1 then
        for idx in area:iterp(minp, maxp) do
            local pos = area:position(idx)
            if pos.y < SEALEVEL - 1 and data[idx] == c_stone then
                local n = n_cave:get_3d(pos)
                if n > 0.35 then data[idx] = c_air end
            end
        end
    end

    vm:set_data(data)
    vm:write_to_map()
    vm:update_map()

    -- ============================================================================
    -- ⭐ DECOR + TREE PASS (RESTORED)
    -- ============================================================================

    local i2 = 1
    for z=z0,z1 do
        for x=x0,x1 do
            local h = hmap[i2]
            if h then
                local hx = hmap[i2+1] or h
                local hz = hmap[i2+stride] or h
                local s = math.abs(h - hx) + math.abs(h - hz)

                local b = n_biome:get_2d({x=x,y=z})
                local t = n_temp:get_2d({x=x,y=z})
                local hu= n_humid:get_2d({x=x,y=z})
                local ch= n_cherry:get_2d({x=x,y=z})
                local cl= n_clay:get_2d({x=x,y=z})
                local zone = n_zone:get_2d({x=x,y=z})

                local biome = get_biome(x,z,h,s,b,t,hu,ch,cl,zone)

                if biome ~= "ocean" and biome ~= "deep_ocean" then
                    local pos = {x=x, y=h+1, z=z}
                    place_tree(pos, biome)
                    place_decor(pos, biome)
                end
            end
            i2 = i2 + 1
        end
    end
end)

