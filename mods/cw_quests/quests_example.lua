-- quests_example.lua
-- ============================================
-- CHAPTER DEFINITIONS
-- ============================================

cw_quests.chapters = {
    {
        id = "chapter_1",
        title = "The First Steps",
        desc = [[
Your journey begins with the basics of survival.
Learn the land, gather resources, and understand the world that has forgotten itself.
        ]],
        categories = { "Overworld" }
    },

    {
        id = "chapter_2",
        title = "Shadows Beneath",
        desc = [[
Below the surface lies a network of forgotten tunnels and ancient ruins.
Strange echoes and remnants of old civilizations await discovery.
        ]],
        categories = { "Caves", "Ruins" }
    },

    {
        id = "chapter_3",
        title = "The Turning Sky",
        desc = [[
The world above is changing.
Storms grow stronger, stars shift in unfamiliar patterns, and something watches from afar.
        ]],
        categories = { "Skylands", "Stormfront" }
    }
}

-- ============================================
-- QUEST DEFINITIONS
-- ============================================

cw_quests.register_quest({
    id = "awakening",
    title = "Awakening in the Ruins",
    category = "Overworld",
    desc = "Gather basic materials to survive in this forgotten land.",
    objectives = {
        wood  = { desc = "Collect 5 wood",  count = 5 },
        stone = { desc = "Collect 8 stone", count = 8 },
    },
    reward = function(player)
        player:get_inventory():add_item("main", "default:axe_wood")
        minetest.chat_send_player(player:get_player_name(), "You received a Wooden Axe.")
    end,
})

cw_quests.register_quest({
    id = "shelter",
    title = "Shelter Against the Night",
    category = "Overworld",
    desc = "Build a crude shelter before darkness falls.",
    objectives = {
        walls = { desc = "Place 10 cobblestone blocks", count = 10 },
    },
    requires = { "awakening" },
    reward = function(player)
        player:get_inventory():add_item("main", "default:torch 8")
        minetest.chat_send_player(player:get_player_name(), "You received 8 Torches.")
    end,
})

cw_quests.register_quest({
    id = "first_cave",
    title = "Into the Shallow Caves",
    category = "Caves",
    desc = "Explore the shallow caves and gather early minerals.",
    objectives = {
        coal = { desc = "Mine 6 coal ore", count = 6 },
    },
    reward = function(player)
        player:get_inventory():add_item("main", "default:pick_stone")
        minetest.chat_send_player(player:get_player_name(), "You received a Stone Pickaxe.")
    end,
})

cw_quests.register_quest({
    id = "ancient_ruins",
    title = "Whispers of the Old World",
    category = "Ruins",
    desc = "Investigate the strange ruins hidden underground.",
    objectives = {
        bricks = { desc = "Collect 4 mossy stone bricks", count = 4 },
    },
    requires = { "first_cave" },
    reward = function(player)
        player:get_inventory():add_item("main", "default:steel_ingot 2")
        minetest.chat_send_player(player:get_player_name(), "You received 2 Steel Ingots.")
    end,
})

cw_quests.register_quest({
    id = "skylands_intro",
    title = "The Floating Isles",
    category = "Skylands",
    desc = "Reach the floating islands above and gather sky fragments.",
    objectives = {
        sky_frag = { desc = "Collect 3 sky fragments", count = 3 },
    },
    reward = function(player)
        player:get_inventory():add_item("main", "default:diamond")
        minetest.chat_send_player(player:get_player_name(), "You received a Diamond.")
    end,
})

cw_quests.register_quest({
    id = "stormfront_warning",
    title = "Stormfront Rising",
    category = "Stormfront",
    desc = "Strange storms gather on the horizon. Prepare yourself.",
    objectives = {
        wool = { desc = "Collect 6 wool for insulation", count = 6 },
    },
    reward = function(player)
        player:get_inventory():add_item("main", "default:helmet_steel")
        minetest.chat_send_player(player:get_player_name(), "You received a Steel Helmet.")
    end,
})

-- ============================================
-- PROGRESS HOOKS
-- ============================================

minetest.register_on_dignode(function(pos, oldnode, digger)
    if not digger or not digger:is_player() then return end
    local name = digger:get_player_name()

    -- Awakening quest
    if oldnode.name == "default:tree" then
        cw_quests.give_quest(digger, "awakening")
        cw_quests.add_progress(digger, "awakening", "wood", 1)
    elseif oldnode.name == "default:stone" then
        cw_quests.give_quest(digger, "awakening")
        cw_quests.add_progress(digger, "awakening", "stone", 1)
    end

    -- Caves quest
    if oldnode.name == "default:coal_ore" then
        cw_quests.give_quest(digger, "first_cave")
        cw_quests.add_progress(digger, "first_cave", "coal", 1)
    end

    -- Ruins quest
    if oldnode.name == "default:mossycobble" then
        cw_quests.give_quest(digger, "ancient_ruins")
        cw_quests.add_progress(digger, "ancient_ruins", "bricks", 1)
    end
end)

minetest.register_on_placenode(function(pos, newnode, placer)
    if not placer or not placer:is_player() then return end

    -- Shelter quest
    if newnode.name == "default:cobble" then
        cw_quests.give_quest(placer, "shelter")
        cw_quests.add_progress(placer, "shelter", "walls", 1)
    end
end)

