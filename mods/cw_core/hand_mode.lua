-----------------------------
-- HAND + TOOL MODE SWITCHING
-- Craft & Ruin
-----------------------------

-- Survival hand (Minecraft-like)
local SURVIVAL_HAND = {
    full_punch_interval = 1.0,
    max_drop_level = 0,
    groupcaps = {
        crumbly = {times = {[3] = 1.20}, uses = 0},
        snappy  = {times = {[3] = 0.40}, uses = 0},
        oddly_breakable_by_hand = {
            times = {[1] = 0.50, [2] = 1.00, [3] = 2.00},
            uses = 0
        },
    },
    damage_groups = {fleshy = 1},
}

-- Creative hand (instant break)
local CREATIVE_HAND = {
    full_punch_interval = 0.0,
    max_drop_level = 3,
    groupcaps = {
        cracky = {times = {[1] = 0, [2] = 0, [3] = 0}, uses = 0},
        crumbly = {times = {[1] = 0, [2] = 0, [3] = 0}, uses = 0},
        snappy = {times = {[1] = 0, [2] = 0, [3] = 0}, uses = 0},
        choppy = {times = {[1] = 0, [2] = 0, [3] = 0}, uses = 0},
        oddly_breakable_by_hand = {
            times = {[1] = 0, [2] = 0, [3] = 0},
            uses = 0
        },
    },
    damage_groups = {fleshy = 1},
}

-----------------------------
-- APPLY HAND MODE
-----------------------------
local function apply_hand_mode(player)
    local name = player:get_player_name()

    if minetest.is_creative_enabled(name) then
        minetest.register_item(":", {tool_capabilities = CREATIVE_HAND})
    else
        minetest.register_item(":", {tool_capabilities = SURVIVAL_HAND})
    end
end

-----------------------------
-- APPLY TOOL MODE
-----------------------------
local function apply_tool_mode(player)
    local name = player:get_player_name()
    local inv = player:get_inventory()
    local stack = inv:get_stack("main", player:get_wield_index())

    if stack:is_empty() then return end

    local def = minetest.registered_tools[stack:get_name()]
    if not def then return end

    if not def.original_tool_capabilities then
        def.original_tool_capabilities = def.tool_capabilities
    end

    if minetest.is_creative_enabled(name) then
        -- Instant break for tools
        stack:get_definition().tool_capabilities = {
            full_punch_interval = 0,
            uses = 0,
            groupcaps = {
                cracky = {times = {[1] = 0, [2] = 0, [3] = 0}, uses = 0},
                crumbly = {times = {[1] = 0, [2] = 0, [3] = 0}, uses = 0},
                snappy = {times = {[1] = 0, [2] = 0, [3] = 0}, uses = 0},
            }
        }
    else
        -- Restore normal tool behavior
        stack:get_definition().tool_capabilities = def.original_tool_capabilities
    end
end

-----------------------------
-- HOOKS (Broken code above so lets not load this)   TEMPORARY UNTIL IM TOLD WHAT THIS IS FOR
-----------------------------
---minetest.register_on_joinplayer(function(player)
---    apply_hand_mode(player)
---    apply_tool_mode(player)
---end)

---minetest.register_on_player_inventory_action(function(player)
---    apply_tool_mode(player)
---end)

---minetest.register_on_player_receive_fields(function(player, formname, fields)
---    if fields.creative_toggle then
---        apply_hand_mode(player)
---        apply_tool_mode(player)
---    end
---end)
