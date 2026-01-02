-- =============================================================
-- cw_mapgen: mapgen.lua (Full V6 Aliases + Lighting Fix)
-- =============================================================

local modpath = core.get_modpath(core.get_current_modname())

-- 1. ESSENTIAL ALIASES (Terrain)
minetest.register_alias("mapgen_stone",           "cw_core:stone")
minetest.register_alias("mapgen_dirt",            "cw_core:dirt")
minetest.register_alias("mapgen_dirt_with_grass", "cw_core:grass_block")
minetest.register_alias("mapgen_sand",            "cw_core:sand")
minetest.register_alias("mapgen_water_source",    "cw_core:water_source")
minetest.register_alias("mapgen_river_water_source", "cw_core:water_source")

-- 2. DECORATION & TREE ALIASES (The missing link)
-- These tell the V6 engine which nodes to use for its internal biome logic
minetest.register_alias("mapgen_tree",            "cw_core:log_oak")
minetest.register_alias("mapgen_leaves",          "cw_core:leaves_oak")
minetest.register_alias("mapgen_apple",           "cw_core:leaves_oak") -- Fallback for fruit
minetest.register_alias("mapgen_pine_tree",       "cw_core:log_spruce")
minetest.register_alias("mapgen_pine_needles",    "cw_core:leaves_spruce")

-- Snow & Ice Aliases
minetest.register_alias("mapgen_dirt_with_snow",  "cw_core:snow_block")
minetest.register_alias("mapgen_snowblock",       "cw_core:snow_block")
minetest.register_alias("mapgen_snow",            "cw_core:snow")
minetest.register_alias("mapgen_ice",             "cw_core:ice")

-- 3. TERRAIN MATH (Continentalness/Hills/Rivers)
local SEA_LEVEL = 16
local DIRT_THICKNESS = 4
local n_cont, n_hill, n_riv

core.register_on_generated(function(minp, maxp, seed)
    n_cont = n_cont or core.get_perlin({offset=0, scale=1, spread={x=1000, y=1000, z=1000}, seed=123, octaves=3, persist=0.5})
    n_hill = n_hill or core.get_perlin({offset=0, scale=1, spread={x=200, y=200, z=200}, seed=456, octaves=4, persist=0.6})
    n_riv  = n_riv  or core.get_perlin({offset=0, scale=1, spread={x=400, y=400, z=400}, seed=789, octaves=3, persist=0.5})

    local vm, emin, emax = core.get_mapgen_object("voxelmanip")
    local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
    local data = vm:get_data()
    
    local c_stone = core.get_content_id("cw_core:stone")
    local c_dirt  = core.get_content_id("cw_core:dirt")
    local c_grass = core.get_content_id("cw_core:grass_block")
    local c_sand  = core.get_content_id("cw_core:sand")
    local c_water = core.get_content_id("cw_core:water_source")
    local c_air   = core.get_content_id("air")

    for z = minp.z, maxp.z do
        for x = minp.x, maxp.x do
            local cn = n_cont:get_2d({x=x, y=z})
            local hn = n_hill:get_2d({x=x, y=z})
            local rn = math.abs(n_riv:get_2d({x=x, y=z}))

            local ground_y = math.floor(SEA_LEVEL + (cn * 15) + (math.max(0, hn) * 12))
            if rn < 0.05 then ground_y = ground_y - ((1 - (rn / 0.05)) * 6) end

            for y = emin.y, emax.y do
                local vi = area:index(x, y, z)
                if y <= ground_y then
                    if y == ground_y then
                        data[vi] = (y <= SEA_LEVEL + 1 and y >= SEA_LEVEL - 1) and c_sand or c_grass
                    elseif y > ground_y - DIRT_THICKNESS then
                        data[vi] = (ground_y <= SEA_LEVEL + 1) and c_sand or c_dirt
                    else
                        data[vi] = c_stone
                    end
                elseif y <= SEA_LEVEL then
                    data[vi] = c_water
                else
                    data[vi] = c_air
                end
            end
        end
    end

    -- 4. LIGHTING FIX
    vm:set_data(data)
    vm:set_lighting({day = 15, night = 0}, emin, emax)
    vm:calc_lighting()
    vm:update_liquids()
    vm:write_to_map()
end)