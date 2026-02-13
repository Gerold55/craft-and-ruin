-- api.lua

cw_quests.registered = {}
cw_quests.categories = {}
cw_quests.categories_order = {}
cw_quests.playerdata = {}
cw_quests.chapters = {}

cw_quests.creator_name = "Brandon"

cw_quests.gui = cw_quests.gui or {}
cw_quests.gui.intro_pages = {
    [1] = [[
You awaken in a land that remembers more than it reveals.

Ruins lie half-buried beneath the soil, their stones worn smooth by storms older than memory.
No maps survive. No voices greet you. Only the wind moves freely here.

Yet something watches — not with eyes, but with the quiet patience of a world waiting to be rebuilt.
]],
    [2] = [[
This journal is your companion.

It will record discoveries, guide your steps, and reveal tasks left unfinished by those who came before.
Some quests will test your skill. Others will demand courage.

Every page you complete brings the world one step closer to remembering itself.

Turn the page when you're ready.
]],
}

local function ensure_player(name)
    cw_quests.playerdata[name] = cw_quests.playerdata[name] or {}
    return cw_quests.playerdata[name]
end

function cw_quests.register_quest(def)
    assert(def.id)
    assert(def.title)
    assert(def.category)
    assert(def.objectives)

    cw_quests.registered[def.id] = def

    if not cw_quests.categories[def.category] then
        cw_quests.categories[def.category] = {}
        table.insert(cw_quests.categories_order, def.category)
    end

    table.insert(cw_quests.categories[def.category], def.id)
end

function cw_quests.get_player_quests(name)
    return cw_quests.playerdata[name] or {}
end

local function has_prereqs(name, id)
    local q = cw_quests.registered[id]
    if not q or not q.requires then return true end

    local pdata = cw_quests.get_player_quests(name)
    for _, req in ipairs(q.requires) do
        if not pdata[req] or not pdata[req].completed then
            return false
        end
    end
    return true
end

function cw_quests.give_quest(player, id)
    local name = player:get_player_name()
    local pdata = ensure_player(name)

    if pdata[id] then return end
    if not has_prereqs(name, id) then return end

    pdata[id] = { progress = {}, completed = false }

    local q = cw_quests.registered[id]
    minetest.chat_send_player(name, "New Quest: " .. q.title)
end

function cw_quests.add_progress(player, id, obj, amt)
    local name = player:get_player_name()
    local pdata = cw_quests.playerdata[name]
    if not pdata or not pdata[id] then return end

    local q = cw_quests.registered[id]
    if not q or not q.objectives[obj] then return end

    local state = pdata[id]
    amt = amt or 1

    state.progress[obj] = math.min(
        (state.progress[obj] or 0) + amt,
        q.objectives[obj].count
    )

    for oid, odef in pairs(q.objectives) do
        if (state.progress[oid] or 0) < odef.count then
            return
        end
    end

    if not state.completed then
        state.completed = true
        if q.reward then q.reward(player) end
        minetest.chat_send_player(name, "Quest Completed: " .. q.title)
    end
end

function cw_quests.manual_submit(player, id)
    local name = player:get_player_name()
    local pdata = cw_quests.get_player_quests(name)
    local state = pdata[id]
    if not state then return end

    local q = cw_quests.registered[id]

    for oid, odef in pairs(q.objectives) do
        if (state.progress[oid] or 0) < odef.count then
            minetest.chat_send_player(name, "Requirements not met.")
            return
        end
    end

    if not state.completed then
        state.completed = true
        if q.reward then q.reward(player) end
        minetest.chat_send_player(name, "Quest Completed: " .. q.title)
    end
end

