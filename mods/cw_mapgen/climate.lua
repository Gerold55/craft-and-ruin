-- ============================================================================
-- climate.lua (HARDENED VERSION)
-- ============================================================================

local climate = {}

-- INTERNAL NOISE STATE
local Noise = {
    temp  = nil,
    humid = nil,
    cont  = nil,
    eros  = nil,
}

local function make_perlin(def)
    return minetest.get_perlin(def)
end

local function init_noise()
    Noise.temp = make_perlin({
        offset = 0, scale = 1,
        spread = {x=800, y=800, z=800},
        seed = 10111, octaves = 4, persist = 0.5
    })

    Noise.humid = make_perlin({
        offset = 0, scale = 1,
        spread = {x=800, y=800, z=800},
        seed = 10112, octaves = 4, persist = 0.5
    })

    Noise.cont = make_perlin({
        offset = 0, scale = 1,
        spread = {x=1600, y=1600, z=1600},
        seed = 10113, octaves = 5, persist = 0.55
    })

    Noise.eros = make_perlin({
        offset = 0, scale = 1,
        spread = {x=600, y=600, z=600},
        seed = 10114, octaves = 4, persist = 0.5
    })
end

local function ensure_noise()
    if Noise.temp and Noise.temp.get_2d
       and Noise.humid and Noise.humid.get_2d
       and Noise.cont and Noise.cont.get_2d
       and Noise.eros and Noise.eros.get_2d then
        return
    end

    init_noise()

    -- If for some reason init still failed, don’t crash the game.
    if not (Noise.temp and Noise.temp.get_2d) then
        minetest.log("error", "[climate] Noise init failed, using fallback climate.")
    end
end

local function classify_zone(temp, humid)
    local tband =
        (temp < -0.33 and "cold") or
        (temp <  0.33 and "temperate") or
        "hot"

    local hband =
        (humid < -0.33 and "dry") or
        (humid <  0.33 and "medium") or
        "wet"

    return tband .. "_" .. hband
end

function climate.get_climate(x, z)
    ensure_noise()

    -- Absolute last‑resort fallback: never crash here.
    if not (Noise.temp and Noise.temp.get_2d) then
        return {
            temp = 0,
            humid = 0,
            cont = 0,
            eros = 0,
            climate_zone = "temperate_medium",
        }
    end

    local temp  = Noise.temp:get_2d({x=x, y=z})
    local humid = Noise.humid:get_2d({x=x, y=z})
    local cont  = Noise.cont:get_2d({x=x, y=z})
    local eros  = Noise.eros:get_2d({x=x, y=z})

    return {
        temp = temp,
        humid = humid,
        cont = cont,
        eros = eros,
        climate_zone = classify_zone(temp, humid),
    }
end

return climate

