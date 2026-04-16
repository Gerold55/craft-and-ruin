cw_villagers = cw_villagers or {}
local N = cw_villagers.nodes

local function add(t, x, y, z, name)
    t[#t+1] = {pos={x=x,y=y,z=z}, name=name}
end

local function farm_5x5()
    local t = {}

    for x=-2,2 do
        for z=-2,2 do
            if z == 0 then
                add(t, x, 0, z, N.water)
            else
                add(t, x, 0, z, N.farmland)
                add(t, x, 1, z, N.crop)
            end
        end
    end

    return t
end

local function farm_7x7()
    local t = {}

    for x=-3,3 do
        for z=-3,3 do
            if x==-3 or x==3 or z==-3 or z==3 then
                -- border left as is
            elseif x==0 and z==0 then
                add(t, x, 0, z, N.water)
            else
                add(t, x, 0, z, N.farmland)
                add(t, x, 1, z, N.crop)
            end
        end
    end

    return t
end

cw_villagers.farms = {
    farm_5x5 = farm_5x5(),
    farm_7x7 = farm_7x7(),
}
