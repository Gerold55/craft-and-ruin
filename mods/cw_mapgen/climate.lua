local climate = {}
local N = {}

local function make_perlin(def)
    return minetest.get_perlin(def)
end

local function ensure_noise()
    if N.temp then return end

    N.temp = make_perlin({
        offset=0, scale=1,
        spread={x=4000,y=4000,z=4000},
        seed=10111, octaves=4, persist=0.5
    })

    N.humid = make_perlin({
        offset=0, scale=1,
        spread={x=4000,y=4000,z=4000},
        seed=10112, octaves=4, persist=0.5
    })

    N.cont = make_perlin({
        offset=0, scale=1,
        spread={x=6000,y=6000,z=6000},
        seed=10113, octaves=4, persist=0.55
    })
end

local function classify_zone(temp, humid)
    local t =
        (temp < -0.33 and "cold") or
        (temp <  0.33 and "temperate") or
        "hot"

    local h =
        (humid < -0.33 and "dry") or
        (humid <  0.33 and "medium") or
        "wet"

    return t .. "_" .. h
end

function climate.get_climate(x, z)
    ensure_noise()

    local temp  = N.temp:get_2d({x=x,y=z})
    local humid = N.humid:get_2d({x=x,y=z})
    local cont  = N.cont:get_2d({x=x,y=z})

    return {
        temp  = temp,
        humid = humid,
        cont  = cont,
        zone  = classify_zone(temp, humid),
    }
end

return climate
