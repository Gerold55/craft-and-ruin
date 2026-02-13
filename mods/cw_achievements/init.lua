cw_achievements = {}

-- 1. EXPANDED DATA REGISTRY
local achievements_list = {
    {
        id = "iron_silt",
        title = "THE SILT SCAVENGER",
        legacy_id = "CW-001",
        location = "Iron-Silt Basin",
        description = "Deep within the rusted hulls of the Iron-Silt Basin, you recovered a package that has survived for eons. Its seals are unbroken, smelling of salt and ancient oil. This artifact remains a testament to the early era of our world.",
        icon = "cw_item_package.png", 
        goal = 1,
        reward = "default:iron_lump 10",
        color = "#ff8000"
    },
    {
        id = "torch_warden",
        title = "WARDEN OF LIGHT",
        legacy_id = "CW-002",
        location = "Whisper-Wind Spire",
        description = "The ruins are darker than the abyss. By placing 100 torches, you reclaim the Spire from the encroaching Ruin. The light acts as a beacon for those lost in the timeline wreckage.",
        icon = "cw_item_torch.png",
        goal = 100,
        reward = "default:torch 50",
        color = "#00ffcc"
    }
}

-- 2. REFINED UI RENDERER
local function get_polished_fs(player_name, selected_index)
    selected_index = selected_index or 1
    local player = minetest.get_player_by_name(player_name)
    local meta = player:get_meta()
    
    local earned = minetest.deserialize(meta:get_string("cw_earned")) or {}
    local progress = minetest.deserialize(meta:get_string("cw_progress")) or {}
    
    local current = achievements_list[selected_index]
    local p_val = progress[current.id] or 0

    -- Sidebar List: Using smaller text color codes
    local list_str = ""
    for _, a in ipairs(achievements_list) do
        local prefix = earned[a.id] and "#00FF00[X] " or "#888888[ ] "
        list_str = list_str .. minetest.colorize(earned[a.id] and "#FFFFFF" or "#AAAAAA", prefix .. a.title) .. ","
    end
    list_str = list_str:sub(1, -2)

    -- THE FORMSPEC (Extended length for elegance)
    local fs = "size[14,10]" ..
        "no_prepend[]" ..
        "real_coordinates[true]" ..
        
        -- LAYER: Background Panels
        "background9[0,0;14,10;cw_main_bg.png;false;10]" ..
        "background9[0.5,1.6;8.5,7.8;cw_panel_frame.png;false;20]" .. -- Main Frame
        "background9[9.3,2.0;4.2,6.5;cw_list_inset.png;false;15]" .. -- Sidebar Inset

        -- HEADER: Adjusted scale for smaller sub-text
        "image[0.5,0.3;1.1,1.1;cw_logo_icon.png]" ..
        "style_type[label;font=bold;font_size=20]" ..
        "label[1.8,0.6;" .. minetest.colorize("#ffffff", "CRAFT & RUIN") .. "]" ..
        "style_type[label;font=normal;font_size=12]" .. -- Smaller Version Text
        "label[1.8,0.9;" .. minetest.colorize("#ff3300", "LEGACY SYSTEM ARCHIVE // VER 1.0.4 (" .. current.legacy_id .. ")") .. "]" ..
        
        -- MAIN CONTENT: Balanced Text sizes
        "image[0.9,2.1;3.0,3.0;cw_rivet_frame.png]" ..
        "image[1.1,2.3;2.6,2.6;" .. current.icon .. "]" ..
        
        "style_type[label;font=bold;font_size=22]" .. -- Reduced from 28
        "label[4.2,2.3;" .. minetest.colorize(current.color, current.title) .. "]" ..
        "style_type[label;font=italic;font_size=13]" .. -- Reduced from 16
        "label[4.2,2.8;" .. minetest.colorize("#55FFFF", "AREA OF INTEREST: " .. current.location) .. "]" ..
        
        -- DESCRIPTION: Using smaller font_size for better text wrapping
        "style_type[textarea;font=normal;font_size=13]" ..
        "box[4.2,3.3;4.3,2.0;#00000088]" .. 
        "textarea[4.3,3.4;4.1,1.8;;;" .. current.description .. "]" ..

        -- PROGRESS BAR: Clean Neon Look
        "style_type[label;font=normal;font_size=12]" ..
        "label[0.9,5.7;" .. minetest.colorize("#888888", "RECOVERY STATUS") .. "]" ..
        "image[0.9,6.1;7.7,0.8;cw_bar_casing.png]" .. 
        "image[1.0,6.2;" .. (7.5 * (math.min(p_val, current.goal) / current.goal)) .. ",0.6;cw_neon_fill.png]" .. 
        "label[4.2,6.3;" .. minetest.colorize("#ffffff", p_val .. " / " .. current.goal) .. "]" ..
        
        -- SALVAGE: Item scale
        "label[0.9,7.5;" .. minetest.colorize("#FFA500", "IDENTIFIED SALVAGE:") .. "]" ..
        "item_image[0.9,7.9;1.0,1.0;" .. current.reward:split(" ")[1] .. "]" ..
        "label[2.1,8.3;" .. minetest.colorize("#FFFFFF", current.reward) .. "]" ..

        -- SIDEBAR: Small mono-spaced font for the Index
        "label[9.5,1.6;" .. minetest.colorize("#ffffff", "CHRONICLE INDEX") .. "]" ..
        "style_type[textlist;background=#00000000;border=false;font=mono;font_size=12]" ..
        "textlist[9.6,2.2;3.6,6.0;selector;" .. list_str .. ";" .. selected_index .. ";false]" ..
        
        -- ACTION BUTTON
        "style_type[button;bgimg=cw_button_stone.png;bgimg_pressed=cw_button_press.png;border=false;font=bold;font_size=14]" ..
        "button_exit[10.5,8.8;3,0.7;quit;BACK TO WORLD]"

    return fs
end

-- 3. LOGIC & COMMANDS
minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= "cw_achievements:ui" then return end
    if fields.selector then
        local event = minetest.explode_textlist_event(fields.selector)
        if event.type == "CHG" then
            minetest.show_formspec(player:get_player_name(), "cw_achievements:ui", 
                get_polished_fs(player:get_player_name(), event.index))
        end
    end
end)

minetest.register_chatcommand("achievements", {
    func = function(name)
        minetest.show_formspec(name, "cw_achievements:ui", get_polished_fs(name, 1))
    end,
})