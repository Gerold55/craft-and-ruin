---------------------------------------------------------
-- 1. DEFINE THE HANDS
---------------------------------------------------------
local CAPS_SURVIVAL = {
    full_punch_interval = 1.0,
    max_drop_level = 0,
    groupcaps = {
        crumbly = {times = {[1]=1.5, [2]=1.2, [3]=0.8}},
        snappy  = {times = {[1]=1.0, [2]=0.7, [3]=0.4}},
        choppy  = {times = {[1]=3.0, [2]=2.0, [3]=1.5}},
        cracky  = {times = {[1]=5.0, [2]=4.0, [3]=3.0}},
    },
    damage_groups = {fleshy = 1},
}

local CAPS_CREATIVE = {
    full_punch_interval = 0.1,
    max_drop_level = 3,
    groupcaps = {
        cracky={times={[1]=0,[2]=0,[3]=0}},
        crumbly={times={[1]=0,[2]=0,[3]=0}},
        choppy={times={[1]=0,[2]=0,[3]=0}},
        snappy={times={[1]=0,[2]=0,[3]=0}},
    },
    damage_groups = {fleshy = 10},
}

---------------------------------------------------------
-- 2. THE NUCLEAR OVERRIDE
---------------------------------------------------------
-- We override the hand to have NO capabilities by default.
-- This prevents the client from assuming it can break anything.
minetest.override_item("", {
    wield_image = "cw_hand.png",
    tool_capabilities = CAPS_SURVIVAL, -- Start as survival
})

---------------------------------------------------------
-- 3. FORCED REFRESH FUNCTION
---------------------------------------------------------
local function sync_hand(player)
    if not player then return end
    local name = player:get_player_name()
    
    -- Check if the player is ACTUALLY in creative via the privilege
    -- or the global setting. 
    local is_creative = minetest.is_creative_enabled(name)
    
    if is_creative then
        player:set_properties({tool_capabilities = CAPS_CREATIVE})
    else
        -- Using a blank table first, then survival, can force a client sync
        player:set_properties({tool_capabilities = CAPS_SURVIVAL})
    end
end

---------------------------------------------------------
-- 4. THE "STUBBORN" HOOKS
---------------------------------------------------------

-- Hook 1: On Join
minetest.register_on_joinplayer(function(player)
    -- We run it 3 times at different intervals to catch the client
    -- as it finishes loading the world.
    minetest.after(0.2, sync_hand, player)
    minetest.after(1.0, sync_hand, player)
    minetest.after(2.0, sync_hand, player)
end)

-- Hook 2: On Toggle (Matches your UI)
minetest.register_on_player_receive_fields(function(player, formname, fields)
    if fields.creative_toggle or fields.quit then
        minetest.after(0.1, sync_hand, player)
    end
end)