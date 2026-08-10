-- =========================================================
-- CRAFT & RUIN — FIXED MINECRAFT-STYLE MAPGEN FOR V7
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

local np_erosion = {
    offset = 0, scale = 1,
    spread = {x = 800, y = 800, z = 800},
    seed = 3341, octaves = 4, persist = 0.6, lacunarity = 2.0
}

---------------------------------------------------------
-- SCHEMATIC PATHS
---------------------------------------------------------
local schem_oak    = schem_path .. "oak_tree.mts"
local schem_birch  = schem_path .. "birch_tree.mts"
local schem_cherry = schem_path .. "cherry_tree.mts"
local schem_spruce = schem_path .. "spruce_tree.mts"

local MAX_TREE_HEIGHT = 14
local SEA_LEVEL = 4

---------------------------------------------------------
-- MAPGEN MAIN REGISTER
---------------------------------------------------------
minetest.register_on_generated(function(minp, maxp, seed)
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

    local ch_size_2d = {x = maxp.x - minp.x + 1, y = maxp.z - minp.z + 1, z = 1}

    -- Fetch 2D Perlin Noise Maps
    local map_heat    = minetest.get_perlin_map(np_heat, ch_size_2d):get_2d_map_flat({x = minp.x, y = minp.z})
    local map_humid   = minetest.get_perlin_map(np_humidity, ch_size_2d):get_2d_map_flat({x = minp.x, y = minp.z})
    local map_erosion = minetest.get_perlin_map(np_erosion, ch_size_2d):get_2d_map_flat({x = minp.x, y = minp.z})

    local index_2d = 0

    ---------------------------------------------------------
    -- SINGLE-PASS TERRAIN RE-STRATIFICATION
    ---------------------------------------------------------
    for z = minp.z, maxp.z do
        for x = minp.x, maxp.x do
            index_2d = index_2d + 1
            local heat = map_heat[index_2d]
            local humid = map_humid[index_2d]
            local erosion = map_erosion[index_2d]

            local is_desert = (heat > 65 and humid < 35)
            local is_taiga  = (heat < 35 and humid > 45)
            local is_tundra = (heat < 25)

            -- Scan top-down for actual solid terrain surface
            local surface_y = nil
            for y = emax.y, minp.y, -1 do
                local vi = area:index(x, y, z)
                local id = data[vi]

                if id ~= c_air and id ~= c_water and id ~= c_ignore then
                    surface_y = y
                    break
                end
            end

            -- Apply Biome Strata only if a valid surface exists in this chunk column
            if surface_y and surface_y >= minp.y and surface_y <= maxp.y then
                
                -- 1. UNDERWATER / OCEAN BED (At or below Sea Level)
                if surface_y <= SEA_LEVEL then
                    local vi_surf = area:index(x, surface_y, z)
                    if erosion > 0.35 then
                        data[vi_surf] = c_gravel
                    elseif erosion < -0.35 then
                        data[vi_surf] = c_clay
                    else
                        data[vi_surf] = c_sand
                    end

                    -- Subbed Sandstone
                    for depth = 1, 3 do
                        local sub_y = surface_y - depth
                        if sub_y >= minp.y then
                            data[area:index(x, sub_y, z)] = c_sandstone
                        end
                    end

                -- 2. DRY LAND SURFACE
                else
                    local vi_surf = area:index(x, surface_y, z)

                    -- Top Node Assignment
                    if is_desert then
                        data[vi_surf] = c_sand
                    elseif is_tundra and surface_y >= 75 then
                        data[vi_surf] = c_snow_block
                    elseif is_taiga then
                        data[vi_surf] = c_podzol
                    else
                        data[vi_surf] = c_grass
                    end

                    -- Subsoil Layers (2 to 3 nodes deep)
                    for depth = 1, 3 do
                        local sub_y = surface_y - depth
                        if sub_y >= minp.y then
                            local sub_vi = area:index(x, sub_y, z)
                            if is_desert then
                                data[sub_vi] = c_sandstone
                            else
                                data[sub_vi] = c_dirt
                            end
                        end
                    end

                    ---------------------------------------------------------
                    -- SURFACE DECORATION & TREES
                    ---------------------------------------------------------
                    local above_y = surface_y + 1
                    if above_y <= maxp.y then
                        local above_vi = area:index(x, above_y, z)

                        -- Ensure the space above is open air before placing flora
                        if data[above_vi] == c_air then
                            
                            -- Deserts
                            if is_desert then
                                local roll = pr:next(1, 150)
                                if roll == 1 then
                                    data[above_vi] = c_cactus
                                    if above_y + 1 <= maxp.y then
                                        data[area:index(x, above_y + 1, z)] = c_cactus
                                    end
                                elseif roll <= 4 then
                                    data[above_vi] = c_dead_bush
                                end

                            -- Grasslands, Taiga & Forests
                            elseif data[vi_surf] == c_grass or data[vi_surf] == c_podzol then
                                local is_edge_safe = (x > minp.x + 3 and x < maxp.x - 3 and z > minp.z + 3 and z < maxp.z - 3)
                                local tree_roll = pr:next(1, 180)

                                if is_edge_safe and tree_roll <= 6 and (above_y + MAX_TREE_HEIGHT <= maxp.y) then
                                    local pos = {x = x, y = above_y, z = z}
                                    if is_taiga then
                                        minetest.place_schematic_on_vmanip(vm, pos, schem_spruce, "random", nil, false)
                                    elseif humid > 55 and pr:next(1, 2) == 1 then
                                        minetest.place_schematic_on_vmanip(vm, pos, schem_birch, "random", nil, false)
                                    else
                                        minetest.place_schematic_on_vmanip(vm, pos, schem_oak, "random", nil, false)
                                    end
                                else
                                    -- Flowers & Grass
                                    local flora_roll = pr:next(1, 100)
                                    if flora_roll <= 18 then
                                        data[above_vi] = c_grass_decor
                                    elseif flora_roll <= 22 then
                                        data[above_vi] = (pr:next(1, 2) == 1) and c_flower_daisy or c_flower_blue
                                    end
                                end
                            end
                        end
                    end
                end

            end
        end
    end

    ---------------------------------------------------------
    -- WRITE DATA BACK TO MAP
    ---------------------------------------------------------
    vm:calc_lighting()
    vm:set_data(data)
    vm:write_to_map()
end)