-- cw_core/breaking.lua

local function is_creative(name)
    -- ONLY check the creative privilege
    return minetest.check_player_privs(name, {creative = true})
end

------------------------------------------------------------
-- 1. CREATIVE REACH (Survival stays normal)
------------------------------------------------------------
-- NORMAL SURVIVAL HAND (Minecraft-like)
minetest.register_item(":", {
    type = "none",
    wield_image = "cw_hand.png",
    wield_scale = {x=1, y=1, z=1},
    range = 4.0,
    tool_capabilities = {
        full_punch_interval = 1.0,
        max_drop_level = 0,
        groupcaps = {
            crumbly = {times={[1]=3.0, [2]=1.5, [3]=0.7}, uses=0, maxlevel=1},
        }
    }
})

-- Apply creative reach dynamically
minetest.register_on_joinplayer(function(player)
    local name = player:get_player_name()
    if is_creative(name) then
        player:set_properties({tool_capabilities = {range = 6}})
    else
        player:set_properties({tool_capabilities = {range = 4}})
    end
end)

------------------------------------------------------------
-- 2. INSTANT BREAK + NO DROPS (Creative only)
------------------------------------------------------------
local old_node_dig = minetest.node_dig
function minetest.node_dig(pos, node, digger)
    if digger and digger:is_player() and is_creative(digger:get_player_name()) then
        minetest.remove_node(pos)
        return true
    end
    return old_node_dig(pos, node, digger)
end

------------------------------------------------------------
-- 3. INFINITE PLACEMENT (Creative only)
------------------------------------------------------------
minetest.register_on_placenode(function(pos, newnode, placer, oldnode, itemstack)
    if placer and placer:is_player() and is_creative(placer:get_player_name()) then
        local item_name = itemstack:get_name()
        local idx = placer:get_wield_index()

        minetest.after(0, function()
            local inv = placer:get_inventory()
            if not inv then return end

            local stack = inv:get_stack("main", idx)
            if stack:get_name() == item_name or stack:is_empty() then
                local new_stack = ItemStack(item_name)
                new_stack:set_count(new_stack:get_stack_max())
                inv:set_stack("main", idx, new_stack)
            end
        end)
    end
end)

------------------------------------------------------------
-- 4. NO TOOL DAMAGE (Creative only)
------------------------------------------------------------
minetest.register_on_punchnode(function(pos, node, puncher)
    if puncher and puncher:is_player() and is_creative(puncher:get_player_name()) then
        local tool = puncher:get_wielded_item()
        if tool:get_wear() > 0 then
            tool:set_wear(0)
            puncher:set_wielded_item(tool)
        end
    end
end)
