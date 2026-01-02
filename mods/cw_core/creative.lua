-- cw_core/breaking.lua

local function is_creative(name)
    return minetest.settings:get_bool("creative_mode") or 
           minetest.check_player_privs(name, {creative = true})
end

-- 1. INCREASE REACH (Minecraft Creative reach is further than survival)
-- This applies to the "Hand" which is the default tool
minetest.register_item(":", {
    type = "none",
    wield_image = "cw_hand.png",
    wield_scale = {x=1, y=1, z=1},
    range = 6.0, -- Increased from 4.0 to 6.0 for that "Creative" reach
    tool_capabilities = {
        full_punch_interval = 0.5,
        max_drop_level = 3,
        groupcaps = {
            crumbly = {times={[1]=0.5, [2]=0.2, [3]=0.1}, uses=0, maxlevel=3},
            snappy  = {times={[1]=0.5, [2]=0.2, [3]=0.1}, uses=0, maxlevel=3},
            choppy  = {times={[1]=0.5, [2]=0.2, [3]=0.1}, uses=0, maxlevel=3},
            cracky  = {times={[1]=0.5, [2]=0.2, [3]=0.1}, uses=0, maxlevel=3},
        }
    }
})

-- 2. INSTANT BREAK & NO DROPS
-- This overrides the default digging logic
local old_node_dig = minetest.node_dig
function minetest.node_dig(pos, node, digger)
    if digger and digger:is_player() and is_creative(digger:get_player_name()) then
        -- In MC Creative: 1. Node disappears instantly. 2. No item drops on floor.
        minetest.remove_node(pos)
        return true
    end
    return old_node_dig(pos, node, digger)
end

-- 3. INFINITE PLACEMENT (The "Item stays in hand" fix)
minetest.register_on_placenode(function(pos, newnode, placer, oldnode, itemstack, pointed_thing)
    if placer and placer:is_player() and is_creative(placer:get_player_name()) then
        -- We return a "Full Stack" of the item used back to the player's hand
        local item_name = itemstack:get_name()
        local wield_index = placer:get_wield_index()

        -- We use a 0-second timer to refill the slot AFTER the engine tries to delete 1
        minetest.after(0, function()
            local inv = placer:get_inventory()
            if inv then
                local stack = inv:get_stack("main", wield_index)
                -- Only refill if the player is still holding the same item type
                if stack:get_name() == item_name or stack:is_empty() then
                    local new_stack = ItemStack(item_name)
                    new_stack:set_count(new_stack:get_stack_max())
                    inv:set_stack("main", wield_index, new_stack)
                end
            end
        end)
    end
end)

-- 4. NO ITEM DAMAGE
-- Tools like axes or shovels won't lose durability in creative
minetest.register_on_punchnode(function(pos, node, puncher, pointed)
    if puncher and puncher:is_player() and is_creative(puncher:get_player_name()) then
        local tool = puncher:get_wielded_item()
        if tool:get_wear() > 0 then
            tool:set_wear(0)
            puncher:set_wielded_item(tool)
        end
    end
end)