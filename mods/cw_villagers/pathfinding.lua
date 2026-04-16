cw_villagers = cw_villagers or {}
local PF = {}

function PF.find_path(start_pos, target_pos)
    if not start_pos or not target_pos then return nil end

    start_pos = vector.round(start_pos)
    target_pos = vector.round(target_pos)

    local path = minetest.find_path(
        start_pos,
        target_pos,
        60,
        1.5,
        3,
        "A*"
    )

    if not path or #path == 0 then
        return nil
    end

    for i, step in ipairs(path) do
        path[i] = {
            x = math.floor(step.x) + 0.5,
            y = math.floor(step.y),
            z = math.floor(step.z) + 0.5,
        }
    end

    return path
end

cw_villagers.pathfinding = PF
