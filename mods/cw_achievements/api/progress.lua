-- api/progress.lua
local api = cw_achievements

local function save(player, earned, progress, collected)
    local meta = player:get_meta()
    meta:set_string("cw_earned", minetest.serialize(earned))
    meta:set_string("cw_progress", minetest.serialize(progress))
    meta:set_string("cw_collected", minetest.serialize(collected))
end

------------------------------------------------------------
-- Increment progress
------------------------------------------------------------
function api.increment(player, id, amount)
    local meta = player:get_meta()
    local earned = minetest.deserialize(meta:get_string("cw_earned")) or {}
    local progress = minetest.deserialize(meta:get_string("cw_progress")) or {}
    local collected = minetest.deserialize(meta:get_string("cw_collected")) or {}

    if earned[id] then return end

    local ach = api.get(id)
    if not ach then return end

    progress[id] = (progress[id] or 0) + amount

    if progress[id] >= ach.goal then
        api.unlock(player, id)
    else
        save(player, earned, progress, collected)
    end
end

------------------------------------------------------------
-- Unlock achievement
------------------------------------------------------------
function api.unlock(player, id)
    local meta = player:get_meta()
    local earned = minetest.deserialize(meta:get_string("cw_earned")) or {}
    local progress = minetest.deserialize(meta:get_string("cw_progress")) or {}
    local collected = minetest.deserialize(meta:get_string("cw_collected")) or {}

    earned[id] = true
    progress[id] = api.get(id).goal
    collected[id] = false

    save(player, earned, progress, collected)

    local ach = api.get(id)

    if api.notify then
        api.notify(player, ach)
    end

    minetest.chat_send_player(
        player:get_player_name(),
        minetest.colorize("#00FF00", "[ACHIEVEMENT UNLOCKED] ") ..
        minetest.colorize("#FFFFFF", ach.title)
    )
end

------------------------------------------------------------
-- Collect reward
------------------------------------------------------------
function api.collect_reward(player, id)
    local meta = player:get_meta()
    local earned = minetest.deserialize(meta:get_string("cw_earned")) or {}
    local collected = minetest.deserialize(meta:get_string("cw_collected")) or {}

    if not earned[id] then return false, "Not unlocked" end
    if collected[id] then return false, "Already collected" end

    local ach = api.get(id)
    if not ach or not ach.reward then return false, "No reward" end

    local item, count = ach.reward:match("([^ ]+) (%d+)")
    player:get_inventory():add_item("main", item .. " " .. count)

    collected[id] = true
    meta:set_string("cw_collected", minetest.serialize(collected))

    return true
end

