-- Abyssal Vein Mapgen: Nether-like but original

local c_air       = minetest.get_content_id("air")
local c_bedrock   = minetest.get_content_id("cw_core:bedrock")
local c_stone     = minetest.get_content_id("abyssal_vein:abyssal_stone")
local c_shatter   = minetest.get_content_id("abyssal_vein:shatterstone")
local c_lumen     = minetest.get_content_id("abyssal_vein:lumen_soil")
local c_veinheart = minetest.get_content_id("abyssal_vein:veinheart_stone")
local c_crystal   = minetest.get_content_id("abyssal_vein:ambient_crystal")

-- Cavern noise (big voids)
local n_cavern = {
    offset = 0,
    scale = 1,
    spread = {x=160, y=80, z=160},
    seed = 12345,
    octaves = 3,
    persist = 0.5,
}

-- Pillars (vertical supports)
local n_pillars = {
    offset = 0,
    scale = 1,
    spread = {x=40, y=160, z=40},
    seed = 9876,
    octaves = 2,
    persist = 0.6,
}

-- Shelves (horizontal layers)
local n_shelves = {
    offset = 0,
    scale = 1,
    spread = {x=80, y=30, z=80},
    seed = 24680,
    octaves = 3,
    persist = 0.5,
}

-- Tunnels (winding structure)
local n_tunnels = {
    offset = 0,
    scale = 1,
    spread = {x=60, y=30, z=60},
    seed = 54321,
    octaves = 3,
    persist = 0.5,
}

local noise_cache = {}

local function get_noise()
    local vm = select(1, minetest.get_mapgen_object("voxelmanip"))
    local id = tostring(vm)
    if not noise_cache[id] then
        noise_cache[id] = {
            cavern  = minetest.get_perlin(n_cavern),
            pillars = minetest.get_perlin(n_pillars),
            shelves = minetest.get_perlin(n_shelves),
            tunnels = minetest.get_perlin(n_tunnels),
        }
    end
    return noise_cache[id]
end

-- Biome layers by depth
local function get_layer(y)
    if y > -500 then
        return "descent"          -- upper layer
    elseif y > -1500 then
        return "lumen_grove"      -- mid layer
    else
        return "veinheart"        -- deep layer
    end
end

minetest.register_on_generated(function(minp, maxp, seed)
    if maxp.y > -200 then return end -- never generate overworld here

    local noise = get_noise()
    local cavern_noise  = noise.cavern
    local pillar_noise  = noise.pillars
    local shelf_noise   = noise.shelves
    local tunnel_noise  = noise.tunnels

    local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
    local area = VoxelArea:new{MinEdge=emin, MaxEdge=emax}
    local data = vm:get_data()

    for z = minp.z, maxp.z do
        for y = minp.y, maxp.y do
            for x = minp.x, maxp.x do
                local vi = area:index(x,y,z)

                -- Bedrock ceiling
                if y > -70 then
                    data[vi] = c_bedrock
                    goto continue
                end

                -- Void gap
                if y > -200 then
                    data[vi] = c_air
                    goto continue
                end

                -- Noise samples
                local c = cavern_noise:get_3d({x=x, y=y, z=z})
                local p = pillar_noise:get_3d({x=x, y=y, z=z})
                local s = shelf_noise:get_3d({x=x, y=y, z=z})
                local t = tunnel_noise:get_3d({x=x, y=y, z=z})

                -- Solid logic
                local solid = false

                -- Caverns
                if c < -0.22 then
                    solid = true
                end

                -- Shelves (horizontal layers)
                if math.abs(s) < 0.12 then
                    solid = true
                end

                -- Pillars (vertical)
                if math.abs(p) < 0.08 then
                    solid = true
                end

                -- Tunnels
                if t > 0.38 then
                    solid = true
                end

                if not solid then
                    data[vi] = c_air
                    goto continue
                end

                -- Layer-based block selection
                local layer = get_layer(y)

                if layer == "descent" then
                    data[vi] = c_stone

                elseif layer == "lumen_grove" then
                    data[vi] = c_lumen

                else -- veinheart
                    if t > 0.1 then
                        data[vi] = c_veinheart
                    else
                        data[vi] = c_shatter
                    end
                end

                -- Crystal clusters (ceiling-biased)
                if math.random(1, 5000) == 1 then
                    local above = area:index(x, y+1, z)
                    if data[above] == c_air then
                        for dx = -1, 1 do
                            for dy = -1, 1 do
                                for dz = -1, 1 do
                                    if math.random(1, 3) == 1 then
                                        local vi2 = area:index(x+dx, y+dy, z+dz)
                                        data[vi2] = c_crystal
                                    end
                                end
                            end
                        end
                    end
                end

                ::continue::
            end
        end
    end

    vm:set_data(data)
    vm:write_to_map()
end)
