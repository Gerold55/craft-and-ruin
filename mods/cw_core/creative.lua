-- =========================================================
-- CRAFT & RUIN — HAND CAPABILITIES & TRUE CREATIVE MODE
-- =========================================================

---------------------------------------------------------
-- 1. CAPABILITY DEFINITIONS
---------------------------------------------------------

local HAND_CAPS_SURVIVAL = {
    full_punch_interval = 1.0,
    max_drop_level = 0,
    groupcaps = {
        crumbly = {times = {[1] = 1.50, [2] = 1.20, [3] = 0.80}, uses = 0},
        snappy  = {times = {[1] = 1.00, [2] = 0.70, [3] = 0.40}, uses = 0},
        choppy  = {times = {[1] = 3.00, [2] = 2.00, [3] = 1.50}, uses = 0},
        cracky  = {times = {[1] = 5.00, [2] = 4.00, [3] = 3.00}, uses = 0},
        oddly_breakable_by_hand = {times = {[1] = 0.50, [2] = 1.00, [3] = 2.00}, uses = 0},
    },
    damage_groups = {fleshy = 1},
}

local HAND_CAPS_CREATIVE = {
    full_punch_interval = 0.1,
    max_drop_level = 3,
    groupcaps = {
        cracky  = {times = {[1] = 0, [2] = 0, [3] = 0}},
        crumbly = {times = {[1] = 0, [2] = 0, [3] = 0}},
        snappy  = {times = {[1] = 0, [2] = 0, [3] = 0}},
        choppy  = {times = {[1] = 0, [2] = 0, [3] = 0}},
    },
    damage_groups = {fleshy = 10},
}

---------------------------------------------------------
-- 2. THE GLOBAL OVERRIDE (CRITICAL)
---------------------------------------------------------
minetest.override_item("", {
    wield_image = "cw_hand.png",
    wield_scale = {x = 1, y = 1, z = 1},
    tool_capabilities = HAND_CAPS_SURVIVAL,
})

---------------------------------------------------------
-- 3. DYNAMIC HAND MODE TOGGLE
---------------------------------------------------------
local function apply_creative_mode(player)
    if not player or not player:is_player() then return end
    
    local name = player:get_player_name()
    local is_creative = minetest.is_creative_enabled(name)

    if is_creative then
        -- Applies Instabreak (0-time breaking for all groups)
        player:set_properties({
            tool_capabilities = HAND_CAPS_CREATIVE
        })
    else
        player:set_properties({
            tool_capabilities = nil
        })
    end
end

-----------------------------------
-- TRUE GLOBAL INFINITE STACK HOOK 
-----------------------------------
minetest.register_on_placenode(function(pos, newnode, placer, oldnode, itemstack, pointed_thing)
    if placer and placer:is_player() then
        local player_name = placer:get_player_name()
        if minetest.is_creative_enabled(player_name) then
            minetest.after(0, function()
                if placer and placer:is_player() then
                    local inv = placer:get_inventory()
                    local WieldedIndex = placer:get_wielded_index()
                    local current_stack = inv:get_stack("main", WieldedIndex)
                    
                    if not current_stack:is_empty() then
                        current_stack:set_count(current_stack:get_stack_max())
                        inv:set_stack("main", WieldedIndex, current_stack)
                    end
                end
            end)
        end
    end
end)

---------------------------------------------------------
-- 5. EVENT HOOKS
---------------------------------------------------------
minetest.register_on_joinplayer(function(player)
    minetest.after(0.2, apply_creative_mode, player)
    minetest.after(1.0, apply_creative_mode, player)
end)

minetest.register_on_player_receive_fields(function(player, formname, fields)
    if fields.creative_toggle or fields.quit then
        minetest.after(0.1, apply_creative_mode, player)
    end
end)