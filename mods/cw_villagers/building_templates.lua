cw_villagers = cw_villagers or {}
local N = cw_villagers.nodes

local function add(t, x, y, z, name)
    t[#t+1] = {pos={x=x,y=y,z=z}, name=name}
end

local function cottage_small()
    local t = {}

    -- Foundation
    for x=-2,2 do
        for z=-3,3 do
            add(t, x, 0, z, N.cobble)
        end
    end

    -- Walls
    for y=1,3 do
        for x=-2,2 do
            for z=-3,3 do
                if x==-2 or x==2 or z==-3 or z==3 then
                    add(t, x, y, z, N.plaster)
                end
            end
        end
    end

    -- Log corners
    for y=1,3 do
        add(t, -2, y, -3, N.log)
        add(t,  2, y, -3, N.log)
        add(t, -2, y,  3, N.log)
        add(t,  2, y,  3, N.log)
    end

    -- Door
    add(t, 0, 1, -3, "air")
    add(t, 0, 1, -3, N.door)

    -- Windows
    add(t, -2, 2, 0, N.glass)
    add(t,  2, 2, 0, N.glass)

    -- Roof
    for x=-3,3 do
        for z=-4,4 do
            add(t, x, 4, z, N.roof)
        end
    end

    return t
end

local function cottage_long()
    local t = {}

    -- Foundation
    for x=-3,3 do
        for z=-2,2 do
            add(t, x, 0, z, N.cobble)
        end
    end

    -- Walls
    for y=1,3 do
        for x=-3,3 do
            for z=-2,2 do
                if x==-3 or x==3 or z==-2 or z==2 then
                    add(t, x, y, z, N.plaster)
                end
            end
        end
    end

    -- Log corners
    for y=1,3 do
        add(t, -3, y, -2, N.log)
        add(t,  3, y, -2, N.log)
        add(t, -3, y,  2, N.log)
        add(t,  3, y,  2, N.log)
    end

    -- Door
    add(t, 0, 1, -2, "air")
    add(t, 0, 1, -2, N.door)

    -- Windows
    add(t, -1, 2, 2, N.glass)
    add(t,  1, 2, 2, N.glass)

    -- Roof
    for x=-4,4 do
        for z=-3,3 do
            add(t, x, 4, z, N.roof)
        end
    end

    return t
end

cw_villagers.buildings = {
    cottage_small = cottage_small(),
    cottage_long  = cottage_long(),
}
