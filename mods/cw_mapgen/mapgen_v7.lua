-- ============================================================================
-- Craft & Ruin — v7 Mapgen
--   • v7 terrain (engine)
--   • Custom surface biomes (MC‑style)
--   • 8‑layer snow
--   • Trees + decor
--   • Minecraft‑style caves
-- ============================================================================

local SEALEVEL       = tonumber(minetest.get_mapgen_setting("water_level")) or 63
local TERRAIN_OFFSET = 8
local SNOW_LINE      = SEALEVEL + 80

-- Content IDs
local c_air        = minetest.CONTENT_AIR
local c_water      = minetest.get_content_id("cw_core:water_source")
local c_stone      = minetest.get_content_id("cw_core:stone")
local c_grass      = minetest.get_content_id("cw_core:grass_block")
local c_dirt       = minetest.get_content_id("cw_core:dirt")
local c_sand       = minetest.get_content_id("cw_core:sand")
local c_gravel     = minetest.get_content_id("cw_core:gravel")
local c_clay       = minetest.get_content_id("cw_core:clay")
local c_snow_block = minetest.get_content_id("cw_core:snow_block")

local c_snow_1 = minetest.get_content_id("cw_core:snow_layer_1")
local c_snow_2 = minetest.get_content_id("cw_core:snow_layer_2")
local c_snow_4 = minetest.get_content_id("cw_core:snow_layer_4")

-- ============================================================================
-- NOISE DEFINITIONS
-- ============================================================================

local biome_noise = {
    offset = 0, scale = 1,
    spread = {x=512,y=512,z=512},
    seed = 12345, octaves = 3, persist = 0.5
}

local heat_noise = {
    offset = 0, scale = 1,
    spread = {x=256,y=256,z=256},
    seed = 55123, octaves = 3, persist = 0.5
}

local humidity_noise = {
    offset = 0, scale = 1,
    spread = {x=256,y=256,z=256},
    seed = 99231, octaves = 3, persist = 0.5
}

local cherry_noise = {
    offset = 0, scale = 1,
    spread = {x=128,y=128,z=128},
    seed = 91321, octaves = 3, persist = 0.5
}

local clayspire_noise = {
    offset = 0, scale = 1,
    spread = {x=96,y=64,z=96},
    seed = 77777, octaves = 4, persist = 0.55
}

local cave_noise = {
    offset = 0,
    scale = 1,
    spread = {x=64,y=32,z=64},
    seed = 123456,
    octaves = 4,
    persist = 0.5,
}

local n_biome
local n_heat
local n_humidity
local n_cherry
local n_clayspire
local n_cave

-- ============================================================================
-- UTILS
-- ============================================================================

local function slope(hmap, i, stride)
    local h  = hmap[i]
    local hx = hmap[i + 1] or h
    local hz = hmap[i + stride] or h
    return math.abs(h - hx) + math.abs(h - hz)
end

-- ============================================================================
-- BIOME SELECTION
-- ============================================================================

local function get_biome(x, z, y, s, cherry_val, clayspire_val)
    local b  = n_biome:get_2d({x=x,y=z})
    local ht = n_heat:get_2d({x=x,y=z})
    local hu = n_humidity:get_2d({x=x,y=z})

    -- Oceans by height
    if y < SEALEVEL - 20 then return "deep_ocean" end
    if y < SEALEVEL - 2  then return "ocean"      end

    -- Ice biome: cold, higher, near snow line
    if y > SEALEVEL + 40 and ht < -0.25 then
        return "ice_biome"
    end

    -- Clayspire basin: mid‑low, special noise
    if y > SEALEVEL - 5 and y < SEALEVEL + 25 and clayspire_val > 0.55 then
        return "clayspire_basin"
    end

    -- Jungle: warm + humid, low‑mid
    if b > 0.35 and y > SEALEVEL+5 and y < SEALEVEL+40 then
        if ht > 0.45 and hu > 0.45 then
            return "jungle"
        end
    end

    -- Cherry grove: mid‑high, gentle slopes
    if b > -0.1 and b < 0.2 and y > SEALEVEL+32 and y < SEALEVEL+62 then
        if s < 1.2 and cherry_val > 0.55 then
            return "cherry_grove"
        end
    end

    -- Birch forest: mid elevation, gentle slopes
    if b > -0.05 and b < 0.05 and y > SEALEVEL+20 and y < SEALEVEL+45 then
        if s < 1.0 then
            return "birch_forest"
        end
    end

    -- Spruce forest: cooler, mid elevation
    if ht < -0.05 and y > SEALEVEL+20 and y < SEALEVEL+50 and s < 1.5 then
        return "spruce_forest"
    end

    -- Taiga forest: cold, coniferous, lower than ice
    if ht < -0.1 and hu > 0 and y > SEALEVEL+10 and y < SEALEVEL+40 then
        return "taiga_forest"
    end

    -- Mountains: high or steep
    if y > SEALEVEL+55 or s > 2.5 then
        if b > -0.4 and b < 0.4 then
            return "mountains"
        end
    end

    -- Meadows: gentle slopes, mid elevation
    if s < 1.0 and y > SEALEVEL+20 and y < SEALEVEL+45 then
        return "meadows"
    end

    -- Rolling hills: moderate slopes, mid elevation
    if s >= 1.0 and s < 2.5 and y > SEALEVEL+15 and y < SEALEVEL+50 then
        return "rolling_hills"
    end

    -- Plains: low, gentle
    if b > -0.2 and b < 0.4 and y < SEALEVEL+28 and s < 1.2 then
        return "plains"
    end

    -- Forest default
    return "forest"
end

-- ============================================================================
-- DECORATION
-- ============================================================================

local function cluster(pos, nodes, chance)
    if math.random() >= chance then return end
    for i=1,16 do
        local p = {
            x = pos.x + math.random(-3,3),
            y = pos.y,
            z = pos.z + math.random(-3,3)
        }
        local pb = {x=p.x,y=p.y-1,z=p.z}
        if minetest.get_node(p).name == "air" and
           minetest.get_node(pb).name == "cw_core:grass_block" then
            minetest.set_node(p, {name = nodes[math.random(#nodes)]})
        end
    end
end

local function place_decor(pos, biome)
    if minetest.get_node(pos).name ~= "air" then return end
    if minetest.get_node({x=pos.x,y=pos.y-1,z=pos.z}).name ~= "cw_core:grass_block" then return end

    local grass   = {"cw_core:grass_decor"}
    local flowers = {"cw_core:flower_bluebell","cw_core:flower_daisy"}

    if biome == "plains" then
        cluster(pos, grass,   0.40)
        cluster(pos, flowers, 0.10)
    elseif biome == "meadows" then
        cluster(pos, grass,   0.35)
        cluster(pos, flowers, 0.18)
    elseif biome == "forest" then
        cluster(pos, grass,   0.15)
    elseif biome == "birch_forest" then
        cluster(pos, grass,   0.20)
        cluster(pos, flowers, 0.08)
    elseif biome == "cherry_grove" then
        cluster(pos, grass,   0.25)
        cluster(pos, flowers, 0.12)
    elseif biome == "jungle" then
        cluster(pos, grass,   0.50)
        cluster(pos, flowers, 0.05)
    elseif biome == "rolling_hills" then
        cluster(pos, grass,   0.22)
        cluster(pos, flowers, 0.06)
    elseif biome == "spruce_forest" or biome == "taiga_forest" then
        cluster(pos, grass,   0.10)
    elseif biome == "mountains" then
        cluster(pos, grass,   0.08)
    elseif biome == "clayspire_basin" then
        cluster(pos, grass,   0.18)
    end
end

-- ============================================================================
-- TREES
-- ============================================================================

local function place_tree(pos, biome)
    local below = {x=pos.x,y=pos.y-1,z=pos.z}
    if minetest.get_node(below).name ~= "cw_core:grass_block" then return end

    if biome == "forest" and math.random() < 0.04 then
        cw_core.grow_tree(pos,"oak")
    elseif biome == "plains" and math.random() < 0.01 then
        cw_core.grow_tree(pos,"oak")
    elseif biome == "meadows" and math.random() < 0.02 then
        cw_core.grow_tree(pos,"oak")
    elseif biome == "birch_forest" and math.random() < 0.08 then
        cw_core.grow_tree(pos,"birch")
    elseif biome == "cherry_grove" and math.random() < 0.10 then
        cw_core.grow_tree(pos,"cherry")
    elseif biome == "rolling_hills" and math.random() < 0.03 then
        cw_core.grow_tree(pos,"oak")
    elseif biome == "spruce_forest" and math.random() < 0.09 then
        cw_core.grow_tree(pos,"spruce")
    elseif biome == "taiga_forest" and math.random() < 0.08 then
        cw_core.grow_tree(pos,"taiga_spruce")
    elseif biome == "mountains" and math.random() < 0.03 then
        cw_core.grow_tree(pos, math.random()<0.6 and "birch" or "oak")
    elseif biome == "jungle" then
        if math.random() < 0.10 then
            cw_core.grow_tree(pos,"jungle")
        elseif math.random() < 0.06 then
            cw_core.grow_tree(pos,"jungle_bush")
        end
    end
end

-- ============================================================================
-- MAIN MAPGEN (SURFACE + CAVES + DECOR)
-- ============================================================================

minetest.register_on_generated(function(minp, maxp, seed)
    local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
    local area           = VoxelArea:new({MinEdge=emin,MaxEdge=emax})
    local data           = vm:get_data()

    local raw_hmap = minetest.get_mapgen_object("heightmap")
    local hmap     = {}

    local x0,y0,z0 = minp.x,minp.y,minp.z
    local x1,y1,z1 = maxp.x,maxp.y,maxp.z

    local stride = (x1 - x0 + 1)
    local i = 1

    -- Init noise
    n_biome    = n_biome    or minetest.get_perlin(biome_noise)
    n_heat     = n_heat     or minetest.get_perlin(heat_noise)
    n_humidity = n_humidity or minetest.get_perlin(humidity_noise)
    n_cherry   = n_cherry   or minetest.get_perlin(cherry_noise)
    n_clayspire= n_clayspire or minetest.get_perlin(clayspire_noise)
    n_cave     = n_cave     or minetest.get_perlin(cave_noise)

    -- Apply vertical offset to v7 heightmap
    for z=z0,z1 do
        for x=x0,x1 do
            hmap[i] = raw_hmap[i] + TERRAIN_OFFSET
            i = i + 1
        end
    end

    -- SURFACE PASS (do not touch underground)
    i = 1
    for z=z0,z1 do
        for x=x0,x1 do
            local height = hmap[i]
            local s      = slope(hmap, i, stride)
            local cherry = n_cherry:get_2d({x=x,y=z})
            local clayv  = n_clayspire:get_2d({x=x,y=z})
            local biome  = get_biome(x,z,height,s,cherry,clayv)
            i = i + 1

            if height >= y0 and height <= y1 then
                local vi = area:index(x,height,z)

                if biome == "ocean" or biome == "deep_ocean" then
                    -- Let v7 handle ocean floors; don't overwrite
                elseif biome == "ice_biome" then
                    data[vi] = c_snow_block
                    for dy=1,3 do
                        local yi = height - dy
                        if yi >= y0 then
                            data[area:index(x,yi,z)] = c_dirt
                        end
                    end
                elseif biome == "mountains" then
                    if height >= SNOW_LINE + 20 then
                        data[vi] = c_snow_block
                    elseif height >= SNOW_LINE + 10 then
                        data[vi] = c_snow_block
                        data[area:index(x,height+1,z)] = c_snow_4
                    elseif height >= SNOW_LINE + 5 then
                        data[vi] = c_grass
                        data[area:index(x,height+1,z)] = c_snow_2
                    elseif height >= SNOW_LINE then
                        data[vi] = c_grass
                        data[area:index(x,height+1,z)] = c_snow_1
                    else
                        data[vi] = c_grass
                    end
                    for dy=1,3 do
                        local yi = height - dy
                        if yi >= y0 then
                            data[area:index(x,yi,z)] = c_dirt
                        end
                    end
                elseif biome == "clayspire_basin" then
                    data[vi] = c_clay
                    for dy=1,3 do
                        local yi = height - dy
                        if yi >= y0 then
                            data[area:index(x,yi,z)] = c_clay
                        end
                    end
                else
                    data[vi] = c_grass
                    for dy=1,3 do
                        local yi = height - dy
                        if yi >= y0 then
                            data[area:index(x,yi,z)] = c_dirt
                        end
                    end
                end
            end
        end
    end

    -- CAVES PASS (Minecraft‑style, below sea level)
    if maxp.y < SEALEVEL - 5 then
        for idx in area:iterp(minp, maxp) do
            local pos = area:position(idx)
            if pos.y < SEALEVEL - 5 then
                local n = n_cave:get_3d(pos)
                if n > 0.35 and data[idx] == c_stone then
                    data[idx] = c_air
                end
            end
        end
    end

    vm:set_data(data)
    vm:write_to_map()
    vm:update_map()

    -- DECOR + TREES PASS
    i = 1
    for z=z0,z1 do
        for x=x0,x1 do
            local height = hmap[i]
            local s      = slope(hmap, i, stride)
            local cherry = n_cherry:get_2d({x=x,y=z})
            local clayv  = n_clayspire:get_2d({x=x,y=z})
            local biome  = get_biome(x,z,height,s,cherry,clayv)
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

