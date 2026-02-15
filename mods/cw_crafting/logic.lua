-- cw_crafting/logic.lua

function cw_crafting.player_has_inputs(player, process)
    local inv = player:get_inventory()
    for _, req in ipairs(process.inputs) do
        if not inv:contains_item("main",
            req.item.." "..req.count) then
            return false
        end
    end
    return true
end

function cw_crafting.run_process(player, id)
    local p = cw_crafting.processes[id]
    if not p then return end

    if not cw_crafting.player_has_inputs(player, p) then
        minetest.chat_send_player(
            player:get_player_name(),
            "Missing materials!"
        )
        return
    end

    local inv = player:get_inventory()
    for _, req in ipairs(p.inputs) do
        inv:remove_item("main",
            req.item.." "..req.count)
    end

    inv:add_item("main",
        p.output.item.." "..p.output.count)

    minetest.chat_send_player(
        player:get_player_name(),
        "Reclaimed: "..p.name
    )
end