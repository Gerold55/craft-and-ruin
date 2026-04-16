-- survival.lua
local ARMOR_ICONS = {
    helmet = "cw_icon_helmet.png", chestplate = "cw_icon_chestplate.png",
    leggings = "cw_icon_leggings.png", boots = "cw_icon_boots.png", shield = "cw_icon_shield.png"
}

function fs_inventory(player, S)
    local fs = { page_bg("cw_bg_inventory.png") }
    local ax, ay = MARGIN_X, CONTENT_TOP - 0.65
    
    -- Armor Rows
    for i, key in ipairs({"helmet", "chestplate", "leggings", "boots", "shield"}) do
        local y = ay + (i-1) * 1.30
        fs[#fs+1] = ("image[%0.2f,%0.2f;1,1;%s]"):format(ax, y, ARMOR_ICONS[key] or "")
        fs[#fs+1] = ("list[current_player;main;%0.2f,%0.2f;1,1;%d]"):format(ax, y, i+20) 
        fs[#fs+1] = ("label[%0.2f,%0.2f;%s]"):format(ax + 1.2, y + 0.5, key:gsub("^%l", string.upper))
    end

    -- Crafting Logic
    local craft_x, craft_y = (UI_W - RIGHT_GUTTER) - 2.7, CONTENT_TOP + 0.2
    fs[#fs+1] = ("label[%f,%f;Crafting]"):format(craft_x, craft_y - 0.4)
    fs[#fs+1] = ("list[current_player;craft;%0.2f,%0.2f;2,2;]"):format(craft_x, craft_y)
    
    -- Output and Recipe Book
    local out_x, out_y = craft_x + 0.6, craft_y + 2.5
    fs[#fs+1] = ("list[current_player;craftpreview;%0.2f,%0.2f;1,1;]"):format(out_x + 0.8, out_y)
    fs[#fs+1] = ("image_button[%0.2f,%0.2f;0.8,0.8;cw_recipe_book_button.png;cw_open_recipes;]"):format(out_x - 0.2, out_y + 0.1)

    -- Player Inventory Slots
    local inv_x = (UI_W - 10) / 2
    fs[#fs+1] = ("list[current_player;main;%0.2f,%0.2f;9,3;9]"):format(inv_x, 7.5)
    fs[#fs+1] = ("list[current_player;main;%0.2f,%0.2f;9,1;0]"):format(inv_x, HOTBAR_Y)

    return table.concat(fs)
end