-- =========================================================
-- CRAFT & RUIN — AUTHENTIC MINECRAFT MAPGEN (V32 - SAVANNA-DESERT BORDER)
-- =========================================================

local mod_name = minetest.get_current_modname() or "cw_core"
local schem_path = minetest.get_modpath(mod_name) .. "/schematics/"

---------------------------------------------------------
-- ALIASES
---------------------------------------------------------
minetest.register_alias_force("default:water_source", "cw_core:water_source")
minetest.register_alias_force("default:water_flowing", "cw_core:water_flowing")
minetest.register_alias_force("default:lava_source", "cw_core:lava_source")

---------------------------------------------------------
-- NOISE PARAMETERS
---------------------------------------------------------
local np_terrain = {
    offset = 10, scale = 24,
    spread = {x = 700, y = 700, z = 700},
    seed = 5900, octaves = 4, persist = 0.45, lacunarity = 2.0
}

local np_roughness = {
    offset = 0, scale = 3,
    spread = {x = 180, y = 180, z = 180},
    seed = 1234, octaves = 2, persist = 0.4, lacunarity = 2.0
}

local np_ocean_depth = {
    offset = 0, scale = 14,
    spread = {x = 900, y = 900, z = 900},
    seed = 4412, octaves = 3, persist = 0.5, lacunarity = 2.0
}

local np_seabed_relief = {
    offset = 0, scale = 5,
    spread = {x = 150, y = 150, z = 150},
    seed = 8821, octaves = 2, persist = 0.4, lacunarity = 2.0
}

local np_heat = {
    offset = 50, scale = 50,
    spread = {x = 800, y = 800, z = 800},
    seed = 5390, octaves = 3, persist = 0.5, lacunarity = 2.0
}

local np_humidity = {
    offset = 50, scale = 50,
    spread = {x = 800, y = 800, z = 800},
    seed = 9138, octaves = 3, persist = 0.5, lacunarity = 2.0
}

local np_seabed_type = {
    offset = 0, scale = 1,
    spread = {x = 15, y = 15, z = 15},
    seed = 4192, octaves = 2, persist = 0.3, lacunarity = 2.5
}

local np_clay_patch = {
    offset = 0, scale = 1,
    spread = {x = 10, y = 10, z = 10},
    seed = 7713, octaves = 2, persist = 0.3, lacunarity = 2.5
}

---------------------------------------------------------
-- SCHEMATIC PATHS
---------------------------------------------------------
local schem_oak_1  = schem_path .. "tree_oak_1.mts"
local schem_oak_2  = schem_path .. "tree_oak_2.mts"
local schem_oak_3  = schem_path .. "tree_oak_3.mts"
local schem_birch  = schem_path .. "birch_tree.mts"
local schem_spruce = schem_path .. "spruce_tree.mts"

local SEA_LEVEL = 4
local DEEP_OCEAN_THRESHOLD = -3

---------------------------------------------------------
-- MAPGEN MAIN REGISTER
---------------------------------------------------------
minetest.register_on_generated(function(minp, maxp, seed)
    if minp.y > 120 or maxp.y < -64 then return end

    local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
    local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
    local data = vm:get_data()
    local pr = PseudoRandom(seed + minp.x + minp.z)

    local c_air        = minetest.CONTENT_AIR
    local c_ignore     = minetest.CONTENT_IGNORE
    local c_stone      = minetest.get_content_id("cw_core:stone")
    local c_dirt       = minetest.get_content_id("cw_core:dirt")
    local c_grass      = minetest.get_content_id("cw_core:grass_block")
    local c_podzol     = minetest.get_content_id("cw_core:podzol") or c_dirt
    local c_sand       = minetest.get_content_id("cw_core:sand")
    local c_sandstone  = minetest.get_content_id("cw_core:sandstone")
    local c_gravel     = minetest.get_content_id("cw_core:gravel")
    local c_clay       = minetest.get_content_id("cw_core:clay")
    local c_water      = minetest.get_content_id("cw_core:water_source")
    
    local c_grass_decor  = minetest.get_content_id("cw_core:grass_decor")
    local c_flower_daisy = minetest.get_content_id("cw_core:flower_daisy")
    local c_flower_blue  = minetest.get_content_id("cw_core:flower_bluebell")
    local c_cactus       = minetest.get_content_id("cw_core:cactus")
    local c_dead_bush    = minetest.get_content_id("cw_core:dead_bush")

    if c_stone == c_ignore then return end

    local pad = 8
    local min_x = minp.x - pad
    local max_x = maxp.x + pad
    local min_z = minp.z - pad
    local max_z = maxp.z + pad

    local xsize = max_x - min_x + 1
    local zsize = max_z - min_z + 1
    local ch_size_2d = {x = xsize, y = zsize, z = 1}

    local map_terrain   = minetest.get_perlin_map(np_terrain, ch_size_2d):get_2d_map_flat({x = min_x, y = min_z})
    local map_roughness = minetest.get_perlin_map(np_roughness, ch_size_2d):get_2d_map_flat({x = min_x, y = min_z})
    local map_ocean     = minetest.get_perlin_map(np_ocean_depth, ch_size_2d):get_2d_map_flat({x = min_x, y = min_z})
    local map_relief    = minetest.get_perlin_map(np_seabed_relief, ch_size_2d):get_2d_map_flat({x = min_x, y = min_z})
    local map_heat      = minetest.get_perlin_map(np_heat, ch_size_2d):get_2d_map_flat({x = min_x, y = min_z})
    local map_humid     = minetest.get_perlin_map(np_humidity, ch_size_2d):get_2d_map_flat({x = min_x, y = min_z})
    local map_seabed    = minetest.get_perlin_map(np_seabed_type, ch_size_2d):get_2d_map_flat({x = min_x, y = min_z})
    local map_clay      = minetest.get_perlin_map(np_clay_patch, ch_size_2d):get_2d_map_flat({x = min_x, y = min_z})

    local function get_noise_index(x, z)
        local lx = x - min_x + 1
        local lz = z - min_z + 1
        return lz * xsize + lx - xsize
    end

    local heights = {}
    for z = minp.z, maxp.z do
        heights[z] = {}
        for x = minp.x, maxp.x do
            local ni = get_noise_index(x, z)
            local base_h = (map_terrain[ni] or 12) + (map_roughness[ni] or 0)
            local ocean_val = map_ocean[ni] or 0
            if base_h <= SEA_LEVEL + 2 then
                base_h = base_h - math.max(0, ocean_val)
            end
            heights[z][x] = math.floor(base_h)
        end
    end

    ---------------------------------------------------------
    -- PASS 1: BUILD SEAMLESS ORDERED BIOMES
    ---------------------------------------------------------
    for z = minp.z, maxp.z do
        for x = minp.x, maxp.x do
            local ni = get_noise_index(x, z)
            local surface_y = heights[z][x]

            local heat = map_heat[ni] or 50
            local humid = map_humid[ni] or 50
            local seabed_noise = map_seabed[ni] or 0
            local clay_noise = map_clay[ni] or 0

            local is_deep_ocean = (surface_y <= DEEP_OCEAN_THRESHOLD)
            local is_ocean      = (surface_y <= SEA_LEVEL and not is_deep_ocean)
            local is_beach      = (surface_y >= SEA_LEVEL and surface_y <= SEA_LEVEL + 1)
            
            -- Biome hierarchy: Deserts flow directly into Savannahs as heat/humidity transition
            local is_desert     = (heat > 70 and humid < 35 and not is_ocean)
            local is_savannah   = (heat > 60 and not is_desert and humid < 55 and not is_ocean and not is_beach)
            local is_jungle     = (heat > 62 and humid >= 65 and surface_y > SEA_LEVEL + 4 and not is_ocean and not is_beach)

            for y = minp.y, maxp.y do
                local vi = area:index(x, y, z)

                if y <= surface_y then
                    if y < surface_y - 3 then
                        data[vi] = c_stone
                    elseif is_deep_ocean or is_ocean then
                        if clay_noise > 0.8 and y <= surface_y - 1 then
                            data[vi] = c_clay
                        elseif seabed_noise > 0.7 then
                            data[vi] = c_gravel
                        elseif seabed_noise < -0.7 then
                            data[vi] = c_dirt
                        else
                            data[vi] = c_sand
                        end
                    else
                        if is_beach then
                            data[vi] = c_sand
                        elseif is_desert then
                            data[vi] = (y == surface_y) and c_sand or c_sandstone
                        else
                            data[vi] = (y == surface_y) and c_grass or c_dirt
                        end
                    end
                elseif y <= SEA_LEVEL then
                    data[vi] = c_water
                else
                    data[vi] = c_air
                end
            end
        end
    end

    vm:set_data(data)

    ---------------------------------------------------------
    -- PASS 2: POPULATE FLORA & TREES
    ---------------------------------------------------------
    for z = minp.z, maxp.z do
        for x = minp.x, maxp.x do
            local ni = get_noise_index(x, z)
            local surface_y = heights[z][x]

            local heat = map_heat[ni] or 50
            local humid = map_humid[ni] or 50

            local is_ocean  = (surface_y <= SEA_LEVEL)
            local is_beach  = (surface_y >= SEA_LEVEL and surface_y <= SEA_LEVEL + 1)
            local is_desert = (heat > 70 and humid < 35 and not is_ocean)
            local is_jungle = (heat > 62 and humid >= 65 and surface_y > SEA_LEVEL + 4 and not is_ocean and not is_beach)
            local is_savannah = (heat > 60 and not is_desert and humid < 55 and not is_ocean and not is_beach)

            if surface_y >= minp.y and surface_y <= maxp.y then
                local vi_surf = area:index(x, surface_y, z)
                local surface_node = data[vi_surf]
                local above_y = surface_y + 1

                if above_y <= maxp.y then
                    local above_vi = area:index(x, above_y, z)

                    if not is_ocean and not is_beach and surface_y > SEA_LEVEL + 1 and not is_desert and (surface_node == c_grass or surface_node == c_podzol) then
                        local tree_roll = pr:next(1, 25)

                        if tree_roll == 1 and (surface_y + 14 <= maxp.y) and x >= minp.x + 7 and x <= maxp.x - 7 and z >= minp.z + 7 and z <= maxp.z - 7 then
                            local pos = {x = x, y = surface_y, z = z}
                            if is_jungle then
                                minetest.place_schematic(pos, schem_oak_2, "random", nil, false)
                            elseif is_savannah then
                                minetest.place_schematic(pos, schem_oak_3, "random", nil, false)
                            else
                                local oak_choice = pr:next(1, 3)
                                local selected_oak = schem_oak_1
                                if oak_choice == 2 then selected_oak = schem_oak_2 end
                                minetest.place_schematic(pos, selected_oak, "random", nil, false)
                            end
                        else
                            local flora_roll = pr:next(1, 100)
                            if flora_roll <= 18 then
                                data[above_vi] = c_grass_decor
                            elseif flora_roll <= 22 then
                                data[above_vi] = (pr:next(1, 2) == 1) and c_flower_daisy or c_flower_blue
                            end
                        end
                    elseif is_desert and surface_y > SEA_LEVEL + 1 then
                        local roll = pr:next(1, 150)
                        if roll == 1 then
                            data[above_vi] = c_cactus
                            if above_y + 1 <= maxp.y then
                                data[area:index(x, above_y + 1, z)] = c_cactus
                            end
                        elseif roll <= 4 then
                            data[above_vi] = c_dead_bush
                        end
                    end
                end
            end
        end
    end

    ---------------------------------------------------------
    -- FINAL WRITE BACK
    ---------------------------------------------------------
    vm:calc_lighting()
    vm:set_data(data)
    vm:write_to_map()
end)