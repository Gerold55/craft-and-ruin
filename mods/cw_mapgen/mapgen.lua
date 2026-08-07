-- -- CRAFT & RUIN — COMPLETE MINECRAFT-STYLE MAPGEN FOR V7
-- Terrain shape = v7
-- Surface, biome strata, tiered oceans, rivers, and decorations = Full Minecraft style
--

---------------------------------------------------------
-- NODE SHORTCUTS
---------------------------------------------------------
local grass           = "cw_core:grass_block"
local dirt            = "cw_core:dirt"
local stone           = "cw_core:stone"
local sand            = "cw_core:sand"
local sandstone       = "cw_core:sandstone"
local gravel          = "cw_core:gravel" or "cw_core:stone"
local clay            = "cw_core:clay" or "cw_core:dirt"
local snow            = "cw_core:snow_block"
local water_source    = "cw_core:water_source"
local lava_source     = "cw_core:lava_source" or "cw_core:water_source"

local grass_decor     = "cw_core:grass_decor"
local flower_daisy    = "cw_core:flower_daisy"
local flower_bluebell = "cw_core:flower_bluebell"
local cactus          = "cw_core:cactus"
local dead_bush       = "cw_core:dead_bush"

---------------------------------------------------------
-- WATER ALIASES (REQUIRED FOR FLOWING WATER)
---------------------------------------------------------
minetest.register_alias("default:water_source", "cw_core:water_source")
minetest.register_alias("default:water_flowing", "cw_core:water_flowing")

---------------------------------------------------------
-- NOISE PARAMETERS (Minecraft Biomes & Features)
---------------------------------------------------------
local np_heat = {
    offset = 0,
    scale = 1,
    spread = {x = 1000, y = 1000, z = 1000},
    seed = 5390,
    octaves = 3,
    persist = 0.5,
    lacunarity = 2.0
}

local np_humidity = {
    offset = 0,
    scale = 1,
    spread = {x = 1000, y = 1000, z = 1000},
    seed = 9138,
    octaves = 3,
    persist = 0.5,
    lacunarity = 2.0
}

local np_sediment = {
    offset = 0,
    scale = 1,
    spread = {x = 40, y = 40, z = 40},
    seed = 7721,
    octaves = 2,
    persist = 0.5,
    lacunarity = 2.0
}

local np_continentalness = {
    offset = 0,
    scale = 1,
    spread = {x = 1800, y = 1800, z = 1800},
    seed = 3341,
    octaves = 4,
    persist = 0.5,
    lacunarity = 2.0
}

---------------------------------------------------------
-- TREE SCHEMATICS
---------------------------------------------------------
local schem_path = minetest.get_modpath("cw_mapgen") .. "/schematics/"

local oak_schem    = schem_path .. "oak_tree.mts"
local birch_schem  = schem_path .. "birch_tree.mts"
local cherry_schem = schem_path .. "cherry_tree.mts"

local MAX_TREE_HEIGHT = 12

local function place_tree_vm(vm, area, data, x, y, z, schematic)
    if y <= 10 then return end
    local pos = {x = x, y = y + 1, z = z}
    minetest.place_schematic_on_vmanip(
        vm,
        pos,
        schematic,
        "random",
        nil,
        false
    )
end

---------------------------------------------------------
-- MAIN MAPGEN PASS
---------------------------------------------------------
minetest.register_on_generated(function(minp, maxp, seed)
    local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
    local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
    local data = vm:get_data()
    local pr = PseudoRandom(seed)

    local cid = {
        grass           = minetest.get_content_id(grass),
        dirt            = minetest.get_content_id(dirt),
        stone           = minetest.get_content_id(stone),
        sand            = minetest.get_content_id(sand),
        sandstone       = minetest.get_content_id(sandstone),
        gravel          = minetest.get_content_id(gravel),
        clay            = minetest.get_content_id(clay),
        snow            = minetest.get_content_id(snow),
        water           = minetest.get_content_id(water_source),
        lava            = minetest.get_content_id(lava_source),
        air             = minetest.get_content_id("air"),

        grass_decor     = minetest.get_content_id(grass_decor),
        flower_daisy    = minetest.get_content_id(flower_daisy),
        flower_bluebell = minetest.get_content_id(flower_bluebell),
        cactus          = minetest.get_content_id(cactus),
        dead_bush       = minetest.get_content_id(dead_bush),
    }

    if cid.stone == nil or cid.air == nil then
        return
    end

    local ch_size = {x = maxp.x - minp.x + 1, y = maxp.y - minp.y + 1, z = maxp.z - minp.z + 1}
    local noise_heat = minetest.get_perlin_map(np_heat, ch_size):get_2d_map_flat({x = minp.x, y = minp.z})
    local noise_humid = minetest.get_perlin_map(np_humidity, ch_size):get_2d_map_flat({x = minp.x, y = minp.z})
    local noise_sediment = minetest.get_perlin_map(np_sediment, ch_size):get_2d_map_flat({x = minp.x, y = minp.z})
    local noise_continental = minetest.get_perlin_map(np_continentalness, ch_size):get_2d_map_flat({x = minp.x, y = minp.z})

    local function is_tree_edge_safe(x, z)
        return x > minp.x and x < maxp.x and z > minp.z and z < maxp.z
    end

    local SEA_LEVEL = 4

    ---------------------------------------------------------
    -- PASS 1: TRUE EXTERIOR SURFACE SCAN
    ---------------------------------------------------------
    local surface_heights = {}
    local is_coastal = {}
    local ni = 0

    for z = minp.z, maxp.z do
        for x = minp.x, maxp.x do
            ni = ni + 1
            local surface_y = nil
            local found_air_above = false
            
            for y = emax.y, minp.y, -1 do
                if area:contains(x, y, z) then
                    local vi = area:index(x, y, z)
                    local id = data[vi]
                    
                    if id == cid.air or id == cid.water then
                        found_air_above = true
                    elseif found_air_above and id and id ~= cid.water and id ~= cid.lava and id ~= minetest.CONTENT_IGNORE then
                        surface_y = y
                        break
                    end
                end
            end
            surface_heights[ni] = surface_y

            local near_water = false
            if surface_y and surface_y > SEA_LEVEL and surface_y <= SEA_LEVEL + 6 then
                for _, offset in ipairs({{1,0}, {-1,0}, {0,1}, {0,-1}}) do
                    local nx, nz = x + offset[1], z + offset[2]
                    if area:contains(nx, surface_y, nz) then
                        local neighbor_id = data[area:index(nx, surface_y, nz)]
                        if neighbor_id == cid.water then
                            near_water = true
                            break
                        end
                    end
                end
            end
            is_coastal[ni] = near_water
        end
    end

    ---------------------------------------------------------
    -- PASS 2: PROPER MINECRAFT BIOME GENERATION
    ---------------------------------------------------------
    ni = 0
    for z = minp.z, maxp.z do
        for x = minp.x, maxp.x do
            ni = ni + 1
            local surface_y = surface_heights[ni]
            local coastal = is_coastal[ni]
            local continent = noise_continental[ni] or 0

            -- 1. Uniform Water Table Fill up to SEA_LEVEL
            for y = minp.y, SEA_LEVEL do
                if area:contains(x, y, z) then
                    local vi = area:index(x, y, z)
                    data[vi] = cid.water
                end
            end

            -- 2. Tiered Ocean Bathymetry
            if continent < -0.15 then
                local depth_factor = math.abs(continent + 0.15) * 40
                local target_ocean_floor = math.floor(SEA_LEVEL - math.min(25, math.max(2, depth_factor)))
                
                if surface_y and surface_y > target_ocean_floor then
                    for y = surface_y, target_ocean_floor + 1, -1 do
                        if area:contains(x, y, z) then
                            local vi = area:index(x, y, z)
                            data[vi] = cid.water
                        end
                    end
                    surface_y = target_ocean_floor
                elseif surface_y == nil then
                    surface_y = target_ocean_floor
                end
            end

            -- 3. Underwater Floor Strata
            if surface_y and surface_y <= SEA_LEVEL then
                local vi = area:index(x, surface_y, z)
                local sed_val = noise_sediment[ni] or 0
                
                if sed_val < -0.45 then
                    data[vi] = cid.clay
                elseif sed_val >= -0.45 and sed_val < 0.2 then
                    data[vi] = cid.sand
                    for i = 1, 3 do
                        local vi2 = area:index(x, surface_y - i, z)
                        if area:contains(x, surface_y - i, z) then
                            data[vi2] = cid.sandstone
                        end
                    end
                elseif sed_val >= 0.2 and sed_val < 0.5 then
                    data[vi] = cid.gravel
                else
                    data[vi] = cid.dirt
                end

            -- 4. Land Surface Biome Processing
            elseif surface_y and surface_y > SEA_LEVEL then
                local heat = noise_heat[ni] or 0
                local humid = noise_humid[ni] or 0
                local vi = area:index(x, surface_y, z)
                local current_id = data[vi]
                
                local is_steep = false
                for _, offset in ipairs({{1,0}, {-1,0}, {0,1}, {0,-1}}) do
                    local nx, nz = x + offset[1], z + offset[2]
                    local ny = surface_y
                    while ny >= minp.y and area:contains(nx, ny, nz) do
                        local nid = data[area:index(nx, ny, nz)]
                        if nid ~= cid.air and nid ~= cid.water then
                            break
                        end
                        ny = ny - 1
                    end
                    if math.abs(surface_y - ny) > 4 then
                        is_steep = true
                        break
                    end
                end

                if not is_steep and (current_id == cid.stone or current_id == cid.dirt or current_id == cid.sand or current_id == cid.sandstone) then
                    
                    -- SNOWY PEAKS BIOME
                    if surface_y >= 85 then
                        data[vi] = cid.snow
                        for i = 1, 3 do
                            local vi2 = area:index(x, surface_y - i, z)
                            if area:contains(x, surface_y - i, z) then
                                data[vi2] = cid.stone
                            end
                        end

                    -- DESERT BIOME (Strict heat & humidity check, avoiding coastal strips)
                    elseif heat > 0.30 and humid < -0.10 and not coastal and surface_y > SEA_LEVEL + 4 then
                        data[vi] = cid.sand
                        for i = 1, 4 do
                            local vi2 = area:index(x, surface_y - i, z)
                            if area:contains(x, surface_y - i, z) then
                                data[vi2] = cid.sandstone
                            end
                        end

                        local above_vi = area:index(x, surface_y + 1, z)
                        if area:contains(x, surface_y + 1, z) and data[above_vi] == cid.air then
                            local roll = pr:next(1, 120)
                            if roll == 1 then
                                data[above_vi] = cid.cactus
                            elseif roll <= 4 then
                                data[above_vi] = cid.dead_bush
                            end
                        end

                    -- BEACHES (Coastal and low elevations)
                    elseif coastal or (surface_y > SEA_LEVEL and surface_y <= SEA_LEVEL + 4) then
                        data[vi] = cid.sand
                        for i = 1, 4 do
                            local vi2 = area:index(x, surface_y - i, z)
                            if area:contains(x, surface_y - i, z) then
                                data[vi2] = cid.sandstone
                            end
                        end

                    -- GRASSLANDS / FORESTS
                    else
                        data[vi] = cid.grass
                        
                        for i = 1, 3 do
                            local vi2 = area:index(x, surface_y - i, z)
                            if area:contains(x, surface_y - i, z) then
                                data[vi2] = cid.dirt
                            end
                        end

                        local above_vi = area:index(x, surface_y + 1, z)
                        if surface_y > SEA_LEVEL + 6 and area:contains(x, surface_y + 1, z) and data[above_vi] == cid.air then
                            local placed_decor = false
                            
                            if is_tree_edge_safe(x, z) and (surface_y + MAX_TREE_HEIGHT <= maxp.y) then
                                local tree_chance = pr:next(1, 300)
                                local threshold = (humid > 0.2) and 18 or 35
                                
                                if tree_chance <= threshold then
                                    if heat < -0.1 then
                                        place_tree_vm(vm, area, data, x, surface_y, z, birch_schem)
                                        placed_decor = true
                                    elseif humid > 0.3 and pr:next(1, 2) == 1 then
                                        place_tree_vm(vm, area, data, x, surface_y, z, cherry_schem)
                                        placed_decor = true
                                    else
                                        place_tree_vm(vm, area, data, x, surface_y, z, oak_schem)
                                        placed_decor = true
                                    end
                                end
                            end

                            if not placed_decor then
                                local flora_roll = pr:next(1, 100)
                                if flora_roll <= 22 then
                                    data[above_vi] = cid.grass_decor
                                elseif flora_roll <= 26 then
                                    data[above_vi] = (pr:next(1, 2) == 1) and cid.flower_daisy or cid.flower_bluebell
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    vm:calc_lighting()
    vm:set_data(data)
    vm:write_to_map()
end)