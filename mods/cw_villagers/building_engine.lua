cw_villagers = cw_villagers or {}

local queue = {}

function cw_villagers.enqueue_build(template, origin)
    queue[#queue+1] = {
        template = template,
        index = 1,
        origin = vector.round(origin),
    }
end

local function step_build()
    if #queue == 0 then return end

    local job = queue[1]
    local entry = job.template[job.index]

    if not entry then
        table.remove(queue, 1)
        return
    end

    local pos = vector.add(job.origin, entry.pos)
    minetest.set_node(pos, {name = entry.name})

    job.index = job.index + 1
end

local acc = 0
minetest.register_globalstep(function(dtime)
    acc = acc + dtime
    if acc >= 0.05 then
        acc = 0
        step_build()
    end
end)
