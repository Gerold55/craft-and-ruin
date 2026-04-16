cw_villagers = cw_villagers or {}

local function is_flat(pos)
    local function solid(p)
        local n = minetest.get_node(p).name
        local def = minetest.registered_nodes[n]
        return def and def.walkable
    end

    return solid(pos)
       and solid({x=pos.x+1, y=pos.y, z=pos.z})
       and solid({x=pos.x,   y=pos.y, z=pos.z+1})
       and solid({x=pos.x+1, y=pos.y, z=pos.z+1})
end

local function score_spot(pos, origin)
    local score = 0

    if is_flat(pos) then score = score + 6 end

    local d = vector.distance(pos, origin)
    if d > 6 and d < 40 then score = score + 5 end

    local above = minetest.get_node({x=pos.x, y=pos.y+1, z=pos.z}).name
    if above == "air" then score = score + 3 end

    score = score + math.random(0, 3)

    return score
end

function cw_villagers.find_build_spot(origin)
    local best, best_score = nil, -999

    for dx=-20,20 do
        for dz=-20,20 do
            local pos = {x=origin.x+dx, y=origin.y, z=origin.z+dz}
            local s = score_spot(pos, origin)
            if s > best_score then
                best_score = s
                best = pos
            end
        end
    end

    return best
end

function cw_villagers.find_farm_spot(origin)
    local best, best_score = nil, -999

    for dx=-20,20 do
        for dz=-20,20 do
            local pos = {x=origin.x+dx, y=origin.y, z=origin.z+dz}
            local n = minetest.get_node(pos).name
            if n == "default:dirt_with_grass" or n == "default:dirt" then
                local s = 5 - (vector.distance(origin, pos) * 0.1)
                s = s + math.random(0, 3)
                if s > best_score then
                    best_score = s
                    best = pos
                end
            end
        end
    end

    return best
end
