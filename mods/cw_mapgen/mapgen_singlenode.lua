--------------------------------------------------
-- cw_mapgen - singlenode overworld mapgen
-- Minecraft-like, biome-driven, simple & tweakable
--------------------------------------------------

local modname = minetest.get_current_modname()
local mp = minetest.get_modpath(modname)

--------------------------------------------------
-- Basic settings
--------------------------------------------------

local SEA_LEVEL = 62
local MIN_BUILD_Y = -64
local MAX_BUILD_Y = 256

-- Only run this if mapgen is singlenode
local mg_name = minetest.get_mapgen_setting("mg_name") or ""
if mg_name ~= "singlenode" then
    minetest.log("action", "[cw_mapgen] singlenode mapgen disabled (mg_name="..mg_name..")")
    return
end

-- Aliases are required for the decoration engine to ground trees correctly
minetest.register_alias("mapgen_stone", "cw_core:stone")
minetest.register_alias("mapgen_water_source", "cw_core:water_source")

minetest.log("action", "[cw_mapgen] singlenode mapgen active")

--------------------------------------------------
-- Content IDs (with fallbacks)
--------------------------------------------------

local cid = {}

local function reg(name, fallback)
    local id = minetest.get_content_id(name)
    if id == 0 and fallback then
        id = minetest.get_content_id(fallback)
    end
    return id
end

local function init_cids()
    cid.air = minetest.CONTENT_AIR
    cid.ignore = minetest.CONTENT_IGNORE

    cid.stone = reg("cw_core:stone", "default:stone")
    cid.dirt = reg("cw_core:dirt", "default:dirt")
    cid.grass = reg("cw_core:grass_block", "default:dirt_with_grass")
    cid.sand = reg("cw_core:sand", "default:sand")
    cid.red_sand = reg("cw_core:sand_red", "default:sand")
    cid.gravel = reg("cw_core:gravel", "default:gravel")
    cid.water = reg("cw_core:water_source", "default:water_source")

    -- Terracotta (Clayspire Basin)
    cid.terracotta_orange = reg("cw_core:terracotta_orange", "default:clay")
    cid.terracotta_red = reg("cw_core:terracotta_red", "default:clay")
    cid.terracotta_brown = reg("cw_core:terracotta_brown", "default:clay")
    cid.terracotta_yellow = reg("cw_core:terracotta_yellow", "default:clay")
    cid.terracotta_white = reg("cw_core:terracotta_white", "default:clay")
    cid.terracotta_light_grey = reg("cw_core:terracotta_lite_gray", "default:clay")
end

init_cids()

--------------------------------------------------
-- Simple hash-based RNG
--------------------------------------------------

local function hash2(x, z, salt)
    local n = minetest.hash_node_position({x = x, y = salt or 0, z = z})
    n = (n * 1103515245 + 12345) % 2147483648
    return n
end

--------------------------------------------------
-- Perlin noise configuration
--------------------------------------------------

local NOISE_CFG = {
    continent = { spread = 2048, octaves = 4, persist = 0.5, scale = 1.0 },
    hills = { spread = 512, octaves = 4, persist = 0.5, scale = 1.0 },
    detail = { spread = 128, octaves = 3, persist = 0.5, scale = 1.0 },

    temp = { spread = 4096, octaves = 3, persist = 0.5, scale = 1.0 },
    humid = { spread = 4096, octaves = 3, persist = 0.5, scale = 1.0 },
    moist = { spread = 1024, octaves = 2, persist = 0.5, scale = 1.0 },
}

local n_cont, n_hills, n_detail
local n_temp, n_humid, n_moist
local noise_ready = false

local function make_perlin(base_seed, salt, cfg, label)
    local seed = (base_seed or 0) + (salt or 0)
    return minetest.get_perlin({
        offset = 0,
        scale = cfg.scale or 1.0,
        spread = { x = cfg.spread, y = cfg.spread, z = cfg.spread },
        seed = seed,
        octaves = cfg.octaves or 3,
        persist = cfg.persist or 0.5,
    })
end

local function ensure_noises()
    if noise_ready then return end
    local base_seed = tonumber(minetest.get_mapgen_setting("seed")) or os.time()
    n_cont = make_perlin(base_seed, 101, NOISE_CFG.continent, "continent")
    n_hills = make_perlin(base_seed, 202, NOISE_CFG.hills, "hills")
    n_detail = make_perlin(base_seed, 303, NOISE_CFG.detail, "detail")
    n_temp = make_perlin(base_seed, 404, NOISE_CFG.temp, "temp")
    n_humid = make_perlin(base_seed, 505, NOISE_CFG.humid, "humid")
    n_moist = make_perlin(base_seed, 606, NOISE_CFG.moist, "moist")
    noise_ready = true
end

--------------------------------------------------
-- Height & climate
--------------------------------------------------

local function ground_height(x, z)
    ensure_noises()
    local c = n_cont:get_2d({x=x, y=z})
    local h = n_hills:get_2d({x=x, y=z})
    local d = n_detail:get_2d({x=x, y=z})
    local base = SEA_LEVEL - 4 + c * 30
    local hills = math.max(h, 0) * 18
    local detail = d * 3
    local y = base + hills + detail
    if y < MIN_BUILD_Y + 8 then y = MIN_BUILD_Y + 8 end
    if y > MAX_BUILD_Y - 16 then y = MAX_BUILD_Y - 16 end
    return math.floor(y + 0.5)
end

local function climate_params(x, z)
    ensure_noises()
    return {
        T = 0.5 + 0.5 * n_temp:get_2d({x=x, y=z}),
        H = 0.5 + 0.5 * n_humid:get_2d({x=x, y=z}),
        M = 0.5 + 0.5 * n_moist:get_2d({x=x, y=z})
    }
end

--------------------------------------------------
-- Biome definitions
--------------------------------------------------

local biomes = {
    {
        name = "ocean",
        node_top = cid.sand,
        node_filler = cid.sand,
        node_stone = cid.stone,
        min_y = MIN_BUILD_Y,
        max_y = SEA_LEVEL + 2,
        cond = function(p) return p.height < SEA_LEVEL - 2 end,
    },
    {
        name = "deep_ocean",
        node_top = cid.sand,
        node_filler = cid.gravel,
        node_stone = cid.stone,
        min_y = MIN_BUILD_Y,
        max_y = SEA_LEVEL - 4,
        cond = function(p) return p.height < SEA_LEVEL - 12 end,
    },
    {
        name = "desert",
        node_top = cid.sand,
        node_filler = cid.sand,
        node_stone = cid.stone,
        min_y = MIN_BUILD_Y,
        max_y = MAX_BUILD_Y,
        cond = function(p) return p.T > 0.7 and p.M < 0.25 and p.height > SEA_LEVEL - 3 end,
    },
    {
        name = "swamp",
        node_top = cid.dirt,
        node_filler = cid.dirt,
        node_stone = cid.stone,
        min_y = MIN_BUILD_Y,
        max_y = SEA_LEVEL + 2,
        cond = function(p) return p.M > 0.7 and p.height <= SEA_LEVEL + 1 and p.height >= SEA_LEVEL - 4 end,
    },
    {
        name = "meadow",
        node_top = cid.grass,
        node_filler = cid.dirt,
        node_stone = cid.stone,
        min_y = SEA_LEVEL + 1,
        max_y = MAX_BUILD_Y,
        cond = function(p) return p.T >= 0.4 and p.T <= 0.8 and p.M >= 0.3 and p.M <= 0.8 and p.height > SEA_LEVEL + 4 end,
    },
    {
        name = "plains",
        node_top = cid.grass,
        node_filler = cid.dirt,
        node_stone = cid.stone,
        min_y = SEA_LEVEL - 2,
        max_y = MAX_BUILD_Y,
        cond = function(p) return p.T > 0.45 and p.M > 0.25 and p.M < 0.75 end,
    },
    {
        name = "forest",
        node_top = cid.grass,
        node_filler = cid.dirt,
        node_stone = cid.stone,
        min_y = SEA_LEVEL,
        max_y = MAX_BUILD_Y,
        cond = function(p) return p.T > 0.45 and p.M >= 0.6 end,
    },
    {
        name = "birch_forest",
        node_top = cid.grass,
        node_filler = cid.dirt,
        node_stone = cid.stone,
        min_y = SEA_LEVEL,
        max_y = MAX_BUILD_Y,
        cond = function(p) return p.T > 0.5 and p.T < 0.8 and p.M > 0.45 and p.M < 0.75 end,
    },
    {
        name = "taiga",
        node_top = cid.grass,
        node_filler = cid.dirt,
        node_stone = cid.stone,
        min_y = SEA_LEVEL - 2,
        max_y = MAX_BUILD_Y,
        cond = function(p) return p.T >= 0.2 and p.T <= 0.45 and p.M > 0.4 end,
    },
    {
        name = "snowy_taiga",
        node_top = cid.grass,
        node_filler = cid.dirt,
        node_stone = cid.stone,
        min_y = SEA_LEVEL,
        max_y = MAX_BUILD_Y,
        cond = function(p) return p.T < 0.25 and p.height > SEA_LEVEL + 4 end,
    },
    {
        name = "clayspire_basin",
        node_top = cid.terracotta_orange,
        node_filler = cid.terracotta_brown,
        node_stone = cid.terracotta_red,
        min_y = SEA_LEVEL + 4,
        max_y = MAX_BUILD_Y,
        cond = function(p)
            return p.T > 0.6 and p.M < 0.4 and p.height > SEA_LEVEL + 8 and math.abs(p.detail) > 0.55
        end,
    },
}

local function pick_biome(x, z, height)
    local c = climate_params(x, z)
    c.height = height
    c.detail = n_detail:get_2d({x=x, y=z})

    for _, b in ipairs(biomes) do
        if height >= b.min_y and height <= b.max_y and b.cond(c) then
            return b
        end
    end

    return (height < SEA_LEVEL - 4) and biomes[1] or biomes[6]
end

--------------------------------------------------
-- Column composer
--------------------------------------------------

local function compose_column(area, data, x, z, minp_y, maxp_y)
    local gy = ground_height(x, z)
    local biome = pick_biome(x, z, gy)

    local top = biome.node_top or cid.grass
    local filler = biome.node_filler or cid.dirt
    local stone = biome.node_stone or cid.stone

    for y = minp_y, maxp_y do
        local vi = area:index(x, y, z)

        if y <= gy then
            -- ground / underground
            if y == gy then
                -- SURFACE LOGIC: Prevent grass under water
                if gy <= SEA_LEVEL then
                    data[vi] = (biome.name == "desert") and cid.sand or filler
                else
                    data[vi] = top
                end
            elseif y > gy - 4 then
                data[vi] = filler
            else
                data[vi] = stone
            end
        else
            -- above ground
            if y <= SEA_LEVEL and gy < SEA_LEVEL then
                data[vi] = cid.water
            else
                data[vi] = cid.air
            end
        end
    end
end

--------------------------------------------------
-- On generated
--------------------------------------------------

minetest.register_on_generated(function(minp, maxp, seed)
    if maxp.y < MIN_BUILD_Y or minp.y > MAX_BUILD_Y then
        return
    end

    ensure_noises()

    local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
    local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
    local data = vm:get_data()

    for z = minp.z, maxp.z do
        for x = minp.x, maxp.x do
            compose_column(area, data, x, z, minp.y, maxp.y)
        end
    end

    vm:set_data(data)
    
    -- Recalculate light and place decorations (trees/bees)
    vm:set_lighting({day = 15, night = 0}, emin, emax)
    minetest.generate_decorations(vm)

    vm:calc_lighting()
    vm:update_liquids()
    vm:write_to_map()
end)
