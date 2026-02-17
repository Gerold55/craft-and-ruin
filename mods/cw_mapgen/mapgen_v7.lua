-- ============================================================================
-- Craft & Ruin — V7 Mapgen (Engine Terrain + Custom Biomes + Decor + Blobs)
-- ============================================================================

local SEALEVEL = tonumber(minetest.get_mapgen_setting("water_level")) or 1

-- Content IDs
local c_air    = minetest.CONTENT_AIR
local c_water  = minetest.get_content_id("cw_core:water_source")
local c_stone  = minetest.get_content_id("cw_core:stone")
local c_dirt   = minetest.get_content_id("cw_core:dirt")
local c_grass  = minetest.get_content_id("cw_core:grass_block")
local c_sand   = minetest.get_content_id("cw_core:sand")
local c_gravel = minetest.get_content_id("cw_core:gravel")
local c_clay   = minetest.get_content_id("cw_core:clay")

-- ============================================================================
-- SLOPE CALCULATION
-- ============================================================================

local function get_slope(heightmap, index, stride_x)
    local h  = heightmap[index]
    local hx = heightmap[index + 1] or h
    local hz = heightmap[index + stride_x] or h
    return math.abs(h - hx) + math.abs(h - hz)
end

-- ============================================================================
-- BIOME SELECTION (MC-style cherry grove)
-- ============================================================================

local function get_biome(y, slope)
    -- Cherry grove: rare, mid-high elevation, gentle slopes
    if y > SEALEVEL + 28 and y < SEALEVEL + 52 then
        if slope < 1.2 then  -- gentle hills only
            -- deterministic rarity: only 1 in 24 columns
            if ((y + slope * 10) % 24) < 1 then
                return "cherry_grove"
            end
        end
    end

    -- fallback biomes
    if y < SEALEVEL - 2 then
        return "ocean"
    elseif y < SEALEVEL + 2 then
        return "beach"
    elseif y < SEALEVEL + 20 then
        return "plains"
    elseif y < SEALEVEL + 40 then
        return "forest"
    else
        return "mountain"
    end
end

-- ============================================================================
-- DECORATION LISTS
-- ============================================================================

local decor_list = {
    grass = {
        "cw_core:grass_decor"
    },
    flowers = {
        "cw_core:flower_bluebell",
        "cw_core:flower_daisy"
    }
}

-- ============================================================================
-- DECORATION PLACEMENT
-- ============================================================================

local function place_decor(pos, biome)
    if biome == "plains" then
        if math.random() < 0.25 then
            minetest.set_node(pos, {name = decor_list.grass[math.random(#decor_list.grass)]})
        end
        if math.random() < 0.08 then
            minetest.set_node(pos, {name = decor_list.flowers[math.random(#decor_list.flowers)]})
        end
        return
    end

    if biome == "forest" then
        if math.random() < 0.20 then
            minetest.set_node(pos, {name = decor_list.grass[math.random(#decor_list.grass)]})
        end
        return
    end

    if biome == "cherry_grove" then
        if math.random() < 0.30 then
            minetest.set_node(pos, {name = "cw_core:grass_decor"})
        end
        if math.random() < 0.10 then
            minetest.set_node(pos, {name = "cw_core:flower_daisy"})
        end
        return
    end

    if biome == "mountain" then
        if math.random() < 0.05 then
            minetest.set_node(pos, {name = "cw_core:grass_decor"})
        end
        return
    end
end

-- ============================================================================
-- TREE PLACEMENT (fixed floating trees + cherry grove only)
-- ============================================================================

local function place_tree(pos, biome)
    local below = {x=pos.x, y=pos.y-1, z=pos.z}
    local bn = minetest.get_node(below).name

    -- Only place trees on grass or dirt
    if bn ~= "cw_core:grass_block" and bn ~= "cw_core:dirt" then
        return
    end

    -- Clear decor so trees don't float
    local here = minetest.get_node(pos).name
    if here ~= "air" then
        minetest.set_node(pos, {name="air"})
    end

    if biome == "forest" then
        if math.random() < 0.04 then
            cw_core.grow_tree(pos, "oak")
        end

    elseif biome == "mountain" then
        if math.random() < 0.02 then
            cw_core.grow_tree(pos, "birch")
        end

    elseif biome == "cherry_grove" then
        if math.random() < 0.10 then
            cw_core.grow_tree(pos, "cherry")
        end
    end
end

-- ============================================================================
-- UNDERWATER GRAVEL/CLAY BLOBS
-- ============================================================================

local function place_underwater_blob(data, area, x, y, z)
    local mat = (math.random() < 0.5) and c_gravel or c_clay
    local size = math.random(4, 8)

    for i = 1, size do
        local dx = x + math.random(-2, 2)
        local dy = y + math.random(-1, 1)
        local dz = z + math.random(-2, 2)

        local vi = area:index(dx, dy, dz)
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
    local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
    local data = vm:get_data()

    local heightmap = minetest.get_mapgen_object("heightmap")

    local x0, y0, z0 = minp.x, minp.y, minp.z
    local x1, y1, z1 = maxp.x, maxp.y, maxp.z

    local stride_x = (x1 - x0 + 1)
    local i = 1

    for z = z0, z1 do
        for x = x0, x1 do

            local height = heightmap[i]
            local slope = get_slope(heightmap, i, stride_x)
            i = i + 1

            -- Fill terrain
            for y = y0, y1 do
                local vi = area:index(x, y, z)

                if y <= height then
                    data[vi] = c_stone
                elseif y <= SEALEVEL then
                    data[vi] = c_water
                else
                    data[vi] = c_air
                end
            end

            -- Surface replacement
            if height >= y0 and height <= y1 then
                local vi = area:index(x, height, z)
                local biome = get_biome(height, slope)

                if biome == "ocean" or biome == "beach" then
                    data[vi] = c_sand
                else
                    data[vi] = c_grass
                end

                -- Dirt under grass
                for dy = 1, 3 do
                    local yi = height - dy
                    if yi >= y0 then
                        local vi2 = area:index(x, yi, z)
                        data[vi2] = c_dirt
                    end
                end
            end

            -- Underwater blobs
            if height < SEALEVEL - 3 then
                if math.random() < 0.02 then
                    place_underwater_blob(data, area, x, height - 1, z)
                end
            end
        end
    end

    vm:set_data(data)
    vm:write_to_map()
    vm:update_map()

    -- ============================================================================
    -- POSTGEN DECOR + TREES
    -- ============================================================================

    i = 1
    for z = z0, z1 do
        for x = x0, x1 do
            local height = heightmap[i]
            local slope = get_slope(heightmap, i, stride_x)
            local biome = get_biome(height, slope)
            i = i + 1

            if height >= y0 and height <= y1 then
                local pos = {x=x, y=height+1, z=z}

                place_tree(pos, biome)
                place_decor(pos, biome)
            end
        end
    end
end)

