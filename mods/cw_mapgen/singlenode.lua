-- =========================================================
-- CRAFT & RUIN — SINGLENODE MINECRAFT-STYLE MAPGEN (V14)
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
    offset = 12, scale = 28,
    spread = {x = 380, y = 380, z = 380},
    seed = 5900, octaves = 4, persist = 0.5, lacunarity = 2.0
}

local np_heat = {
    offset = 50, scale = 50,
    spread = {x = 1000, y = 1000, z = 1000},
    seed = 5390, octaves = 3, persist = 0.5, lacunarity = 2.0
}

local np_humidity = {
    offset = 50, scale = 50,
    spread = {x = 1000, y = 1000, z = 1000},
    seed = 9138, octaves = 3, persist = 0.5, lacunarity = 2.0
}

local np_seabed_type = {
    offset = 0, scale = 1,
    spread = {x = 80, y = 80, z = 80},
    seed = 4192, octaves = 2, persist = 0.5, lacunarity = 2.0
}

local np_clay_patch = {
    offset = 0, scale = 1,
    spread = {x = 35, y = 35, z = 35},
    seed = 7713, octaves = 2, persist = 0.4, lacunarity = 2.0
}

---------------------------------------------------------
-- SCHEMATIC PATHS & CONSTANTS
---------------------------------------------------------
local schem_oak    = schem_path .. "oak_tree.mts"
local schem_birch  = schem_path .. "birch_tree.mts"
local schem_spruce = schem_path .. "spruce_tree.mts"

local SEA_LEVEL = 4
local BEACH_MIN = SEA_LEVEL - 2
local BEACH_MAX = SEA_LEVEL + 5

---------------------------------------------------------
-- MAPGEN MAIN REGISTER
---------------------------------------------------------
minetest.register_on_generated(function(minp, maxp, seed)
    if minp.y > 120 or maxp.y < -64 then return end

    local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
    local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
    local data = vm:get_data()
    local pr = PseudoRandom(seed + minp.x + minp.z)

    -- Resolve Content IDs cleanly
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
    local c_snow_block = minetest.get_content_id("cw_core:snow_block")
    local c_water      = minetest.get_content_id("cw_core:water_source")
    
    -- Decor IDs
    local c_grass_decor  = minetest.get_content_id("cw_core:grass_decor")
    local c_flower_daisy = minetest.get_content_id("cw_core:flower_daisy")
    local c_flower_blue  = minetest.get_content_id("cw_core:flower_bluebell")
    local c_cactus       = minetest.get_content_id("cw_core:cactus")
    local c_dead_bush    = minetest.get_content_id("cw_core:dead_bush")

    if c_stone == c_ignore then return end

    local min_x = minp.x - 1
    local max_x = maxp.x + 1
    local min_z = minp.z - 1
    local max_z = maxp.z + 1

    local xsize = max_x - min_x + 1
    local zsize = max_z - min_z + 1
    local ch_size_2d = {x = xsize, y = zsize, z = 1}

    local map_terrain   = minetest.get_perlin_map(np_terrain, ch_size_2d):get_2d_map_flat({x = min_x, y = min_z})
    local map_heat      = minetest.get_perlin_map(np_heat, ch_size_2d):get_2d_map_flat({x = min_x, y = min_z})
    local map_humid     = minetest.get_perlin_map(np_humidity, ch_size_2d):get_2d_map_flat({x = min_x, y = min_z})
    local map_seabed    = minetest.get_perlin_map(np_seabed_type, ch_size_2d):get_2d_map_flat({x = min_x, y = min_z})
    local map_clay      = minetest.get_perlin_map(np_clay_patch, ch_size_2d):get_2d_map_flat({x = min_x, y = min_z})

    local function get_noise_index(x, z)
        local lx = x - min_x + 1
        local lz = z - min_z + 1
        return lz * xsize + lx - xsize
    end

    ---------------------------------------------------------
    -- PASS 1: BUILD TERRAIN, BEACHES & JUNGLE PODZOL SURFACES
    ---------------------------------------------------------
    for z = minp.z, maxp.z do
        for x = minp.x, maxp.x do
            local ni = get_noise_index(x, z)
            local base_h = map_terrain[ni] or 12
            local surface_y = math.floor(base_h)

            local heat = map_heat[ni] or 50
            local humid = map_humid[ni] or 50
            local seabed_noise = map_seabed[ni] or 0
            local clay_noise = map_clay[ni] or 0

            -- Biome criteria (High heat & high humidity defines the jungle biome using podzol)
            local is_jungle = (heat > 65 and humid > 65)
            local is_desert = (heat > 68 and humid < 35)
            local is_taiga  = (heat < 35 and humid > 45)
            local is_tundra = (heat < 25)

            for y = minp.y, maxp.y do
                local vi = area:index(x, y, z)

                if y <= surface_y then
                    if y < surface_y - 3 then
                        data[vi] = c_stone
                    elseif y <= SEA_LEVEL then
                        if clay_noise > 0.45 and y <= SEA_LEVEL - 1 then
                            data[vi] = c_clay
                        elseif seabed_noise > 0.4 then
                            data[vi] = c_gravel
                        elseif seabed_noise < -0.45 then
                            data[vi] = c_dirt
                        else
                            data[vi] = c_sand
                        end
                    else
                        if y >= BEACH_MIN and y <= BEACH_MAX and not is_tundra then
                            data[vi] = c_sand
                        elseif is_desert then
                            data[vi] = (y == surface_y) and c_sand or c_sandstone
                        elseif is_tundra and y >= 75 then
                            data[vi] = c_snow_block
                        elseif is_jungle then
                            -- Jungle top surface is podzol; subsoil is dirt
                            data[vi] = (y == surface_y) and c_podzol or c_dirt
                        elseif is_taiga then
                            data[vi] = (y == surface_y) and c_podzol or c_dirt
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

    -- Write base terrain data to map buffer so schematics anchor correctly
    vm:set_data(data)

    ---------------------------------------------------------
    -- PASS 2: POPULATE FLORA & TREES (EXCLUDING PODZOL)
    ---------------------------------------------------------
    for z = minp.z, maxp.z do
        for x = minp.x, maxp.x do
            local ni = get_noise_index(x, z)
            local base_h = map_terrain[ni] or 12
            local surface_y = math.floor(base_h)

            local heat = map_heat[ni] or 50
            local humid = map_humid[ni] or 50
            local is_desert = (heat > 68 and humid < 35)
            local is_taiga  = (heat < 35 and humid > 45)

            if surface_y >= minp.y and surface_y <= maxp.y then
                local vi_surf = area:index(x, surface_y, z)
                local surface_node = data[vi_surf]
                local above_y = surface_y + 1

                if above_y <= maxp.y then
                    local above_vi = area:index(x, above_y, z)

                    -- Only grow grass/flowers on standard grass blocks (podzol is excluded)
                    if surface_y > BEACH_MAX and surface_node == c_grass then
                        local tree_roll = pr:next(1, 20)

                        if tree_roll == 1 and (surface_y + 12 <= maxp.y) then
                            local pos = {x = x, y = surface_y, z = z}
                            if is_taiga then
                                minetest.place_schematic(pos, schem_spruce, "random", nil, false)
                            elseif humid > 60 and pr:next(1, 2) == 1 then
                                minetest.place_schematic(pos, schem_birch, "random", nil, false)
                            else
                                minetest.place_schematic(pos, schem_oak, "random", nil, false)
                            end
                        else
                            local flora_roll = pr:next(1, 100)
                            if flora_roll <= 18 then
                                data[above_vi] = c_grass_decor
                            elseif flora_roll <= 22 then
                                data[above_vi] = (pr:next(1, 2) == 1) and c_flower_daisy or c_flower_blue
                            end
                        end
                    elseif is_desert and surface_y >= SEA_LEVEL then
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