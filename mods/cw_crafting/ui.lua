-- cw_crafting/ui.lua

function cw_crafting.show_reclamation_ui(player, station)
    local name = player:get_player_name()
    local meta = player:get_meta()

    local fs = "size[11,8]label[0,0;Craft & Ruin – Reclamation Interface]"
    local y = 1

    for id, p in pairs(cw_crafting.processes) do
        if p.station == station then
            if meta:get_int("bp_"..p.blueprint) == 1 then
                fs = fs ..
                    "button[0,"..y..";8,1;proc_"..id..";"..p.name.."]"
                y = y + 1
            end
        end
    end

    minetest.show_formspec(name, "cw_crafting:reclaim", fs)
end

minetest.register_on_player_receive_fields(function(player, form, fields)
    if form ~= "cw_crafting:reclaim" then return end

    for field,_ in pairs(fields) do
        if field:sub(1,5) == "proc_" then
            local id = field:sub(6)
            cw_crafting.run_process(player, id)
            cw_crafting.show_reclamation_ui(player, "assembler")
        end
    end
end)