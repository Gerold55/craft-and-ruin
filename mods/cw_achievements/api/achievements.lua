cw_achievements = {
    registry = {}
}

function cw_achievements.register(def)
    assert(def.id, "Achievement requires an id")
    cw_achievements.registry[#cw_achievements.registry + 1] = def
end

function cw_achievements.get_by_index(i)
    return cw_achievements.registry[i]
end

function cw_achievements.get(id)
    for _, a in ipairs(cw_achievements.registry) do
        if a.id == id then return a end
    end
end

function cw_achievements.count()
    return #cw_achievements.registry
end

