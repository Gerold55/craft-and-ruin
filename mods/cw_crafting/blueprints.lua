-- cw_crafting/blueprints.lua

minetest.register_craftitem("cw_crafting:blueprint_basic_metals", {
    description = "Blueprint: Basic Metals",
    inventory_image = "blueprint.png",

    on_use = function(itemstack, player)
        local meta = player:get_meta()
        meta:set_int("bp_basic_metals", 1)

        minetest.chat_send_player(
            player:get_player_name(),
            "Blueprint unlocked: Basic Metals"
        )

        itemstack:take_item()
        return itemstack
    end
})