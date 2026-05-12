-- cw_core/breaking.lua

local function is_creative(name)
    -- ONLY check the creative privilege
    return minetest.check_player_privs(name, {creative = true})
end

local creative_caps = {
    full_punch_interval = 0.0,
    max_drop_level = 3,
    groupcaps = {
        crumbly = {times={[1]=0.0, [2]=0.0, [3]=0.0}, uses=0, maxlevel=3},
        cracky  = {times={[1]=0.0, [2]=0.0, [3]=0.0}, uses=0, maxlevel=3},
        choppy  = {times={[1]=0.0, [2]=0.0, [3]=0.0}, uses=0, maxlevel=3},
        snappy  = {times={[1]=0.0, [2]=0.0, [3]=0.0}, uses=0, maxlevel=3},
    }
}

minetest.register_on_joinplayer(function(player)
    local name = player:get_player_name()

    if minetest.check_player_privs(name, {creative = true}) then
        player:set_properties({tool_capabilities = creative_caps})
    else
        player:set_properties({tool_capabilities = nil}) -- use default hand
    end
end)

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
