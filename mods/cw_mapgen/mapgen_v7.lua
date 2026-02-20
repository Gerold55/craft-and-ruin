-- ============================================================================
-- Craft & Ruin – v7 Mapgen (FINAL COMPLETE FILE)
-- Snow Accumulation + Frozen Water + Mesa + Plains Smoothing + Rivers
-- ============================================================================

local SEA_LEVEL = 0

-- Content IDs
local c_dirt       = minetest.get_content_id("cw_core:dirt")
local c_sand       = minetest.get_content_id("cw_core:sand")
local c_gravel     = minetest.get_content_id("cw_core:gravel")
local c_clay       = minetest.get_content_id("cw_core:clay")
local c_water      = minetest.get_content_id("cw_core:water_source")
local c_stone      = minetest.get_content_id("cw_core:stone")
local c_snowblock  = minetest.get_content_id("cw_core:snow_block")
local c_grass      = minetest.get_content_id("cw_core:grass_block")
local c_grass_snow = minetest.get_content_id("cw_core:grass_block_snow")

-- Snow layers (F2)
local snow_layers = {
    minetest.get_content_id("cw_core:snow_layer_1"),
    minetest.get_content_id("cw_core:snow_layer_2"),
    minetest.get_content_id("cw_core:snow_layer_3"),
    minetest.get_content_id("cw_core:snow_layer_4"),
    minetest.get_content_id("cw_core:snow_layer_5"),
    minetest.get_content_id("cw_core:snow_layer_6"),
    minetest.get_content_id("cw_core:snow_layer_7"),
    minetest.get_content_id("cw_core:snow_layer_8"),
}

-- Cold biomes
local cold_biomes = {
    ice_biome    = true,
    taiga_forest = true,
    mountains    = true,
}

-- Mesa terracotta banding
local terracotta_layers = {
    "cw_core:terracotta_red",
    "cw_core:terracotta_orange",
    "cw_core:terracotta_yellow",
    "cw_core:terracotta_orange",
    "cw_core:terracotta_red",
    "cw_core:terracotta_white",
    "cw_core:terracotta_brown",
}

for i, name in ipairs(terracotta_layers) do
    terracotta_layers[i] = minetest.get_content_id(name)
end

-- River noise
local river_noise = PerlinNoise({
    offset  = 0,
    scale   = 1,
    spread  = {x = 256, y = 256, z = 256},
    seed    = 9130,
    octaves = 1,
    persist = 1,
})

-- Snow drift noise (D3)
local snow_noise = PerlinNoise({
    offset  = 0,
    scale   = 1,
    spread  = {x = 128, y = 128, z = 128},
    seed    = 20245,
    octaves = 3,
    persist = 0.5,
})

-- Blob placement
local function place_blob(area, data, x, y, z, radius, node_id)
    for dx = -radius, radius do
        for dz = -radius, radius do
            for dy = -1, 1 do
                if dx*dx + dz*dz <= radius*radius then
                    local vi = area:index(x + dx, y + dy, z + dz)
                    data[vi] = node_id
                end
            end
        end
    end
end

-- Shoreline application
local function apply_shoreline(area, data, x, z, h, biome_name)
    if h < SEA_LEVEL + 3 and h > SEA_LEVEL - 3 then
        local vi = area:index(x, h, z)

        -- Cold shores freeze
        if cold_biomes[biome_name] then
            data[vi] = c_snowblock
            return
        end

        if biome_name == "clayspire_basin" then
            data[vi] = minetest.get_content_id("cw_core:red_sand")
        elseif biome_name == "desert" then
            data[vi] = minetest.get_content_id("cw_core:desert_sand")
        else
            data[vi] = minetest.get_content_id("cw_core:beach_sand")
        end
    end
end

-- Sky exposure check (E2)
local function is_sky_exposed(pos)
    local above = {x = pos.x, y = pos.y + 1, z = pos.z}
    local ray = minetest.raycast(above, {x = pos.x, y = 31000, z = pos.z}, false, false)
    for pointed in ray do
        if pointed.type == "node" then
            return false
        end
    end
    return true
end

-- Snow accumulation (D3)
local function apply_snow(area, data, x, z, h, biome_name)
    if not cold_biomes[biome_name] then return end

    local pos = {x = x, y = h, z = z}
    if not is_sky_exposed(pos) then return end

    local depth = 1

    -- Elevation-based depth
    if h > 80 then depth = depth + 1 end
    if h > 100 then depth = depth + 1 end
    if h > 120 then depth = depth + 1 end
    if h > 140 then depth = depth + 1 end

    -- Noise-based drift
    local drift = math.floor((snow_noise:get_2d({x = x, y = z}) + 1) * 2)
    depth = depth + drift

    -- Clamp depth
    if depth < 1 then depth = 1 end
    if depth > 10 then depth = 10 end

    local vi = area:index(x, h, z)

    if depth == 1 then
        data[vi] = c_grass_snow
        return
    end

    if depth >= 10 then
        data[vi] = c_snowblock
        return
    end

    local layer_index = depth - 1
    data[vi] = snow_layers[layer_index]
end

-- ============================================================================
-- MAIN CALLBACK
-- ============================================================================

minetest.register_on_generated(function(minp, maxp)
    local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
    local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
    local data = vm:get_data()

    local heightmap = minetest.get_mapgen_object("heightmap")
    local biomemap  = minetest.get_mapgen_object("biomemap")

    local index = 1

    for z = minp.z, maxp.z do
        for x = minp.x, maxp.x do

            local h = heightmap[index]
            local biome_id = biomemap[index]
            local biome_name = minetest.get_biome_name(biome_id)

            local rv = math.abs(river_noise:get_2d({x = x, y = z}))

            -- 1. PLAINS HEIGHT SMOOTHING
            if biome_name == "plains" and h > SEA_LEVEL + 10 then
                local reduction = math.floor((h - (SEA_LEVEL + 10)) * 0.6)
                local new_h = h - reduction

                if new_h >= minp.y then
                    local vi_old = area:index(x, h, z)
                    local vi_new = area:index(x, new_h, z)
                    data[vi_new] = data[vi_old]
                    h = new_h
                end
            end

            -- 2. SHORELINES
            apply_shoreline(area, data, x, z, h, biome_name)

            -- 3. RIVERBED BLOBS
			if h < SEA_LEVEL and h > SEA_LEVEL - 8 then
				local r = math.random()
			if r < 0.4 then
				place_blob(area, data, x, h, z, 2, c_sand)
			elseif r < 0.7 then
				place_blob(area, data, x, h, z, 2, c_gravel)
			elseif r < 0.9 then
				place_blob(area, data, x, h, z, 2, c_dirt)
			else
				place_blob(area, data, x, h, z, 2, c_clay)
			end
		end


            -- 4. RIVERBED BLOBS
            if h < SEA_LEVEL and h > SEA_LEVEL - 8 then
                local r = math.random()
                if r < 0.4 then
                    place_blob(area, data, x, h, z, 2, c_sand)
                elseif r < 0.7 then
                    place_blob(area, data, x, h, z, 2, c_gravel)
                elseif r < 0.9 then
                    place_blob(area, data, x, h, z, 2, c_dirt)
                else
                    place_blob(area, data, x, h, z, 2, c_clay)
                end
            end

            -- 5. MESA TERRACOTTA BANDING
            if biome_name == "clayspire_basin" then
                for y = minp.y, maxp.y do
                    local vi = area:index(x, y, z)
                    if data[vi] == c_stone then
                        local layer_index = (math.floor(y / 4) % #terracotta_layers) + 1
                        data[vi] = terracotta_layers[layer_index]
                    end
                end
            end

            -- 6. FREEZE WATER SURFACE IN COLD BIOMES
            if cold_biomes[biome_name] then
                local vi_surface = area:index(x, SEA_LEVEL, z)
                if data[vi_surface] == c_water then
                    data[vi_surface] = c_snowblock
                end

                local vi_river = area:index(x, h + 1, z)
                if data[vi_river] == c_water then
                    data[vi_river] = c_snowblock
                end
            end

            -- 7. SNOW ACCUMULATION (D3 + E2)
            apply_snow(area, data, x, z, h, biome_name)

            index = index + 1
        end
    end

    vm:set_data(data)
    vm:write_to_map()
    vm:update_map()
end)

-- ============================================================================
-- SNOW REMOVAL → GRASS REVERSION (R1)
-- ============================================================================

for _, layer in ipairs({
    "cw_core:snow_layer_1",
    "cw_core:snow_layer_2",
    "cw_core:snow_layer_3",
    "cw_core:snow_layer_4",
    "cw_core:snow_layer_5",
    "cw_core:snow_layer_6",
    "cw_core:snow_layer_7",
    "cw_core:snow_layer_8",
}) do
    minetest.override_item(layer, {
        on_dig = function(pos, node, digger)
            local below = {x = pos.x, y = pos.y - 1, z = pos.z}
            local n = minetest.get_node(below)
            if n.name == "cw_core:grass_block_snow" then
                minetest.set_node(below, {name = "cw_core:grass_block"})
            end
            minetest.node_dig(pos, node, digger)
        end
    })
end

