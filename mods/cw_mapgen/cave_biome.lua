-- ============================================================
--  CAVE WORLD — Minecraft‑like underground biome system
-- ============================================================

local ids = {
    air         = minetest.get_content_id("air"),
    stone       = minetest.get_content_id("cw_core:stone"),
    moss        = minetest.get_content_id("cw_core:moss"),
    glowplant   = minetest.get_content_id("cw_core:glow_plant"),
    crystal     = minetest.get_content_id("cw_core:crystal_block"),
}

-- 3D cave noise (Minecraft‑like)
local cave_noise = minetest.get_perlin({
    offset = 0,
    scale = 1,
    spread = {x=64, y=32, z=64},
    seed = 12345,
    octaves = 4,
    persist = 0.5,
})

-- Crystal biome mask
local crystal_noise = minetest.get_perlin({
    offset = 0,
    scale = 1,
    spread = {x=128, y=128, z=128},
    seed = 98765,
    octaves = 3,
    persist = 0.6,
})

-- Lush biome mask
local lush_noise = minetest.get_perlin({
    offset = 0,
    scale = 1,
    spread = {x=96, y=96, z=96},
    seed = 54321,
    octaves = 3,
    persist = 0.5,
})

-- ============================================================
--  MAIN CAVE GENERATOR
-- ============================================================

minetest.register_on_generated(function(minp, maxp, seed)
    local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
    local area = VoxelArea:new{MinEdge=emin, MaxEdge=emax}
    local data = vm:get_data()

    for z = minp.z, maxp.z do
        for y = minp.y, maxp.y do
            for x = minp.x, maxp.x do

                local vi = area:index(x, y, z)

                ------------------------------------------------------------
                -- 1. Fill everything with stone first
                ------------------------------------------------------------
                data[vi] = ids.stone

                ------------------------------------------------------------
                -- 2. Carve caves (Minecraft‑like)
                ------------------------------------------------------------
                local n = cave_noise:get3d({x=x, y=y, z=z})
                if n > 0.12 then
                    data[vi] = ids.air
                end
            end
        end
    end

    -- ============================================================
    --  SECOND PASS: BIOMES INSIDE CAVES
    -- ============================================================

    for z = minp.z, maxp.z do
        for y = minp.y, maxp.y do
            for x = minp.x, maxp.x do

                local vi = area:index(x, y, z)
                if data[vi] ~= ids.air then goto continue end

                local crystal = crystal_noise:get3d({x=x, y=y, z=z})
                local lush    = lush_noise:get3d({x=x, y=y, z=z})

                ------------------------------------------------------------
                -- CRYSTAL CAVES
                ------------------------------------------------------------
                if crystal > 0.55 then
                    local dirs = {
                        {1,0,0}, {-1,0,0},
                        {0,1,0}, {0,-1,0},
                        {0,0,1}, {0,0,-1},
                    }
                    for _,d in ipairs(dirs) do
                        local vi2 = area:index(x+d[1], y+d[2], z+d[3])
                        if data[vi2] == ids.stone then
                            data[vi2] = ids.crystal
                        end
                    end
                end

                ------------------------------------------------------------
                -- LUSH GLOWING CAVES
                ------------------------------------------------------------
                if lush > 0.45 then
                    -- Moss floor
                    local vi_floor = area:index(x, y-1, z)
                    if data[vi_floor] == ids.stone then
                        data[vi_floor] = ids.moss
                    end

                    -- Glow plants hanging from ceiling
                    local vi_ceiling = area:index(x, y+1, z)
                    if data[vi_ceiling] == ids.stone and math.random() < 0.1 then
                        data[vi] = ids.glowplant
                    end
                end

                ::continue::
            end
        end
    end

    vm:set_data(data)
    vm:write_to_map()
end)

