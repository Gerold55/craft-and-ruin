-- =========================================================
-- CRAFT & RUIN — HAND CAPABILITIES & CREATIVE UTILITIES
-- =========================================================

---------------------------------------------------------
-- 1. CAPABILITY DEFINITIONS
---------------------------------------------------------

local HAND_CAPS_SURVIVAL = {
    full_punch_interval = 1.0,
    max_drop_level = 0,
    groupcaps = {
        -- Level 2 matches your grass blocks exactly
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
-- We override the empty hand item "" during mod load.
-- This forces the CLIENT to see the survival times by default.
minetest.override_item("", {
    wield_image = "cw_hand.png",
    wield_scale = {x = 1, y = 1, z = 1},
    tool_capabilities = HAND_CAPS_SURVIVAL,
})

---------------------------------------------------------
-- 3. DYNAMIC TOGGLE & INFINITE STACK FUNCTIONS
---------------------------------------------------------

local function apply_hand_mode(player)
    if not player or not player:is_player() then return end
    
    local name = player:get_player_name()
    local is_creative = minetest.is_creative_enabled(name)

    if is_creative then
        -- Give the player object "God Mode" powers
        player:set_properties({
            tool_capabilities = HAND_CAPS_CREATIVE
        })
    else
        -- Set to NIL for survival. This forces the engine to
        -- use the tool_capabilities of the hand item we defined in Step 2.
        player:set_properties({
            tool_capabilities = nil
        })
    end
end

-- Function to wrap node placement with infinite stack logic for creative players
local function infinite_place_node(itemstack, placer, pointed_thing)
    -- Perform normal node placement
    local ret = minetest.item_place(itemstack, placer, pointed_thing)
    
    -- Check if the player is in creative mode
    if placer and placer:is_player() then
        local player_name = placer:get_player_name()
        if minetest.is_creative_enabled(player_name) then
            -- Keep the item stack count at maximum (or prevent decrement)
            itemstack:set_count(itemstack:get_definition().stack_max or 99)
        end
    end
    
    return ret
end

---------------------------------------------------------
-- 4. HOOKS (Join, UI Toggle & Global Callbacks)
---------------------------------------------------------

minetest.register_on_joinplayer(function(player)
    -- Multi-stage delay to force the client to sync
    minetest.after(0.2, apply_hand_mode, player)
    minetest.after(1.0, apply_hand_mode, player)
end)

minetest.register_on_player_receive_fields(function(player, formname, fields)
    -- Trigger on UI buttons or when closing the inventory (fields.quit)
    if fields.creative_toggle or fields.quit then
        minetest.after(0.1, apply_hand_mode, player)
    end
end)