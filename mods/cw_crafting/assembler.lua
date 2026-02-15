-- cw_crafting/assembler.lua

minetest.register_node("cw_crafting:assembler", {
    description = "Reclamation Assembler",
    tiles = {"assembler.png"},
    groups = {cracky=2},

    on_rightclick = function(pos, node, player)
        cw_crafting.show_reclamation_ui(player, "assembler")
    end
})