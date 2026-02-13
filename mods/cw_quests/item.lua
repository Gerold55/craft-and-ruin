-- item.lua

minetest.register_craftitem("cw_quests:questbook", {
    description = "Quest Journal",
    inventory_image = "cw_quests_questbook.png",
    stack_max = 1,

    on_use = function(stack, user)
        if user and user:is_player() then
            cw_quests.open_questbook(user:get_player_name())
        end
        return stack
    end,
})

minetest.register_craft({
    output = "cw_quests:questbook",
    recipe = {
        {"default:paper", "default:paper", "default:paper"},
        {"default:paper", "default:book",  "default:paper"},
        {"",              "default:stick", ""},
    }
})

