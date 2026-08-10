cw_xp = {}

-- 1. HUD: Display XP to the player
local xp_huds = {}

minetest.register_on_joinplayer(function(player)
    local meta = player:get_meta()
    local xp = meta:get_int("cw_xp:score")
    
    xp_huds[player:get_player_name()] = player:hud_add({
        hud_elem_type = "text",
        position = {x = 0.5, y = 0.85},
        offset = {x = 0, y = 0},
        text = "Crafting XP: " .. xp,
        number = 0xFFFFFF,
        scale = {x = 100, y = 20},
    })
end)

-- Function to update the HUD and Meta
function cw_xp.add_xp(player, amount)
    local meta = player:get_meta()
    local xp = meta:get_int("cw_xp:score")
    local new_xp = xp + amount
    meta:set_int("cw_xp:score", new_xp)
    
    local name = player:get_player_name()
    player:hud_change(xp_huds[name], "text", "Crafting XP: " .. new_xp)
end

-- 2. DROP MECHANIC: Gain XP from breaking blocks
minetest.register_on_dignode(function(pos, oldnode, digger)
    if not digger or not digger:is_player() then return end
    
    -- Define XP values for different block types
    local xp_gain = 1 -- Default
    if minetest.get_item_group(oldnode.name, "stone") > 0 then
        xp_gain = 3
    elseif minetest.get_item_group(oldnode.name, "cracked") > 0 then
        xp_gain = 5 -- "Ruined" blocks give more
    end
    
    cw_xp.add_xp(digger, xp_gain)
end)

-- 3. CRAFTING MECHANIC: Consume XP for difficult items
-- Example table of "Difficult" items and their costs
local difficult_crafts = {
    ["default:steel_ingot"] = 15,
    ["default:pick_diamond"] = 100,
    ["cw_xp:ancient_core"] = 500,
}

minetest.register_on_craft(function(itemstack, crafter, recipe, table)
    local item_name = itemstack:get_name()
    local cost = difficult_crafts[item_name]
    
    if cost then
        local meta = crafter:get_meta()
        local current_xp = meta:get_int("cw_xp:score")
        
        if current_xp < cost then
            minetest.chat_send_player(crafter:get_player_name(), 
                "Insufficient XP! You need " .. cost .. " XP to craft this.")
            -- Return an empty stack to cancel the craft
            return ItemStack("") 
        else
            -- Deduct the XP
            cw_xp.add_xp(crafter, -cost)
            minetest.chat_send_player(crafter:get_player_name(), 
                "Used " .. cost .. " XP to stabilize the craft.")
        end
    end
end)