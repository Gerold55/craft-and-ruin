local modname = minetest.get_current_modname()
local mp = minetest.get_modpath(modname)

local SEA_LEVEL = 62
local MIN_BUILD_Y = -64
local MAX_BUILD_Y = 512

-- Aliases are critical for the decoration engine to ground trees correctly
minetest.register_alias("mapgen_stone", "cw_core:stone")
minetest.register_alias("mapgen_water_source", "cw_core:water_source")

local cid = {}
local function init_cids()
    cid.air    = minetest.CONTENT_AIR
    cid.stone  = minetest.get_content_id("cw_core:stone")
    cid.dirt   = minetest.get_content_id("cw_core:dirt")
    cid.grass  = minetest.get_content_id("cw_core:grass_block")
    cid.sand   = minetest.get_content_id("cw_core:sand")
    cid.water  = minetest.get_content_id("cw_core:water_source")
    cid.snow   = minetest.get_content_id("cw_core:snow")
end
init_cids()

--------------------------------------------------
-- Biome Registration
--------------------------------------------------
minetest.clear_registered_biomes()

-- Carpathian Foothills: Rolling green slopes
minetest.register_biome({
    name = "carpathian_foothills",
    heat_point = 45,
    humidity_point = 65,
    y_min = SEA_LEVEL - 4,
    y_max = 140,
})

-- Carpathian Peaks: High stone and snow
minetest.register_biome({
    name = "carpathian_peaks",
    heat_point = 25,
    humidity_point = 40,
    y_min = 141,
    y_max = MAX_BUILD_Y,
})

--------------------------------------------------
-- 3D Noise Parameters (Vast Minecraft Scale)
--------------------------------------------------
local np_mountain = {
    offset = 0, scale = 1,
    spread = {x = 350, y = 180, z = 350}, -- Huge spread = Smooth rolling hills
    seed = 881, octaves = 5, persist = 0.5
}

--------------------------------------------------
-- Main Generator
--------------------------------------------------
minetest.register_on_generated(function(minp, maxp, seed)
    if maxp.y < MIN_BUILD_Y or minp.y > MAX_BUILD_Y then return end

    local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
    local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
    local data = vm:get_data()

    -- Calculate 3D Perlin Map for smooth density
    local chulens = {x = maxp.x - minp.x + 1, y = maxp.y - minp.y + 1, z = maxp.z - minp.z + 1}
    local nvals = minetest.get_perlin_map(np_mountain, chulens):get_3d_map_flat(minp)

    local nix = 1
    for z = minp.z, maxp.z do
        for y = minp.y, maxp.y do
            for x = minp.x, maxp.x do
                local vi = area:index(x, y, z)
                
                -- Density Equation: Noise minus a height-based gradient
                local gradient = (y - SEA_LEVEL) / 25 
                local density = nvals[nix] - gradient
                
                if density > 0 then
                    -- Detect surface by "peeking" at density of block above
                    local dens_above = (nvals[nix + 1] or 0) - ((y + 1 - SEA_LEVEL) / 25)
                    
                    if dens_above <= 0 then
                        -- SURFACE RULES
                        if y < SEA_LEVEL then
                            data[vi] = cid.sand -- Ocean floor
                        elseif y <= SEA_LEVEL + 2 then
                            data[vi] = cid.sand -- Proper Shoreline
                        elseif y > 180 then
                            data[vi] = cid.snow -- High Mountain Snow
                        else
                            data[vi] = cid.grass -- Dry Foothills
                        end
                    else
                        -- FILLER RULES (Removes random dirt patches)
                        if density < 0.12 then
                            data[vi] = cid.dirt
                        else
                            data[vi] = cid.stone
                        end
                    end
                else
                    -- WATER OR AIR
                    data[vi] = (y <= SEA_LEVEL) and cid.water or cid.air
                end
                nix = nix + 1
            end
        end
    end

    vm:set_data(data)
    vm:set_lighting({day = 15, night = 0}, emin, emax)
    
    -- Triggers birch trees and beehives ONLY on dry grass!
    minetest.generate_decorations(vm)

    vm:calc_lighting()
    vm:update_liquids()
    vm:write_to_map()
end)