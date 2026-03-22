-- ui/ui.lua
local api = cw_achievements

-- Layout offsets (tweak these to nudge regions)
local HEADER_X = 1.8
local HEADER_Y = 0.8

local MAIN_X = 0.6
local MAIN_Y = 2.4

local ICON_SIZE = 2.4
local ICON_FRAME_SIZE = 2.8
local DESC_W = 3.6
local DESC_H = 1.6

-- Area of Interest sizing (wraparound)
local AOI_H = 0.5
local AOI_Y_OFFSET = 0.80
local AOI_MAX_CHARS = 36  -- approx chars per line for wrapping; tweak if needed

-- Progress bar sizing (thinner)
local PROGRESS_BAR_WIDTH = 7.2
local PROGRESS_BAR_HEIGHT = 0.45
local PROGRESS_FILL_HEIGHT = 0.32

local SIDEBAR_X = 9.6
local SIDEBAR_Y = 2.8
local SIDEBAR_VISIBLE_HEIGHT = 5.0

local REWARD_X = 0.9
local REWARD_Y = 6.8

local COLLECT_X = 9.5
local COLLECT_Y = 8.8

-- Utility: safe getter for achievements
local function safe_get(index)
    if not api or type(api.count) ~= "function" or api.count() == 0 then
        return {
            id = "none",
            title = "NO ACHIEVEMENTS FOUND",
            legacy_id = "N/A",
            location = "N/A",
            description = "No achievements registered.",
            icon = "unknown_item.png",
            goal = 1,
            reward = nil,
            color = "#FFFFFF"
        }
    end
    return api.get_by_index(index) or api.get_by_index(1)
end

-- sanitize id for button names
local function sanitize_id(id)
    return (id or ""):gsub("[:%s]", "_")
end

-- Helper: wrap text into lines at word boundaries
local function wrap_text(s, max_chars)
    if not s or s == "" then return "" end
    local words = {}
    for w in s:gmatch("%S+") do table.insert(words, w) end
    local lines = {}
    local cur = ""
    for i, w in ipairs(words) do
        if #cur == 0 then
            cur = w
        else
            if #cur + 1 + #w <= max_chars then
                cur = cur .. " " .. w
            else
                table.insert(lines, cur)
                cur = w
            end
        end
    end
    if #cur > 0 then table.insert(lines, cur) end
    return table.concat(lines, "\\n") -- formspec label needs escaped newline
end

-- Build the formspec
local function get_polished_fs(player_name, selected_index)
    selected_index = tonumber(selected_index) or 1
    if api and type(api.count) == "function" then
        selected_index = math.max(1, math.min(selected_index, api.count()))
    else
        selected_index = 1
    end

    local player = minetest.get_player_by_name(player_name)
    if not player then return "size[4,2]label[0,0;Player not found]" end

    local meta = player:get_meta()
    local earned = minetest.deserialize(meta:get_string("cw_earned")) or {}
    local progress = minetest.deserialize(meta:get_string("cw_progress")) or {}
    local collected = minetest.deserialize(meta:get_string("cw_collected")) or {}

    local current = safe_get(selected_index)
    local p_val = progress[current.id] or 0
    local is_collected = collected[current.id] == true

    -- Build chronicle list string (escape commas in titles)
    local list_items = {}
    if api and api.registry then
        for _, a in ipairs(api.registry) do
            local prefix = earned[a.id] and "[X] " or "[ ] "
            local safe_title = (a.title or ""):gsub(",", " - ")
            list_items[#list_items + 1] = minetest.formspec_escape(prefix .. safe_title)
        end
    end
    local list_str = table.concat(list_items, ",")

    -- Reward block
    local reward_block = ""
    if current.reward and current.reward ~= "" then
        local reward_item = current.reward:match("([^%s]+)") or "unknown_item"
        reward_block =
            "label[" .. tostring(REWARD_X) .. "," .. tostring(REWARD_Y) .. ";" ..
            minetest.colorize("#FFA500", "IDENTIFIED SALVAGE:") .. "]" ..
            "item_image[" .. tostring(REWARD_X) .. "," .. tostring(REWARD_Y + 0.4) .. ";1,1;" .. reward_item .. "]" ..
            "label[" .. tostring(REWARD_X + 1.2) .. "," .. tostring(REWARD_Y + 0.8) .. ";" ..
            minetest.colorize("#FFFFFF", current.reward) .. "]"

        if earned[current.id] and not is_collected then
            reward_block = reward_block ..
                "button[" .. tostring(COLLECT_X) .. "," .. tostring(COLLECT_Y) .. ";3,0.7;collect_" .. sanitize_id(current.id) .. ";COLLECT]"
        elseif earned[current.id] and is_collected then
            reward_block = reward_block ..
                "label[" .. tostring(COLLECT_X) .. "," .. tostring(COLLECT_Y) .. ";" .. minetest.colorize("#00FF00", "COLLECTED") .. "]"
        end
    end

    -- Progress fill width calculation
    local fill_width = PROGRESS_BAR_WIDTH * (math.min(p_val, current.goal) / math.max(current.goal, 1))
    if fill_width < 0.05 then fill_width = 0.05 end

    -- Compute progress positions
    local PROGRESS_SHIFT = 0.4
    local progress_label_y = MAIN_Y + ICON_FRAME_SIZE + 0.12 + PROGRESS_SHIFT
    local progress_bar_y = MAIN_Y + ICON_FRAME_SIZE + 0.42 + PROGRESS_SHIFT
    local progress_fill_y = progress_bar_y + 0.06

    -- Progress text centered inside the bar
    -- approximate centering: place at bar midpoint minus a small half-width offset
    local progress_text_x = MAIN_X + (PROGRESS_BAR_WIDTH / 2) - 0.6
    local progress_text_y = progress_bar_y + (PROGRESS_BAR_HEIGHT / 2) - 0.06

    -- AOI positions and wrapped label
    local aoi_label_y = MAIN_Y + 0.46
    local aoi_text_y = MAIN_Y + AOI_Y_OFFSET
    local wrapped_aoi = wrap_text(tostring(current.location or "Unknown"), AOI_MAX_CHARS)

    -- Description positions (below AOI)
    local desc_box_y = aoi_text_y + AOI_H + 0.18
    local desc_text_y = desc_box_y + 0.04

    local fs =
        "size[14,10]" ..
        "real_coordinates[true]" ..

        "background[0,0;14,10;ach_background.png]" ..

        -- Header
        "label[" .. tostring(HEADER_X) .. "," .. tostring(HEADER_Y) .. ";" .. minetest.colorize("#FFD700", "ACHIEVEMENTS") .. "]" ..
        "label[" .. tostring(HEADER_X) .. "," .. tostring(HEADER_Y + 0.3) .. ";" .. minetest.colorize("#FF3300", "LEGACY SYSTEM ARCHIVE // " .. (current.legacy_id or "CW-001")) .. "]" ..

        -- Icon and title
        "image[" .. tostring(MAIN_X) .. "," .. tostring(MAIN_Y) .. ";" .. tostring(ICON_FRAME_SIZE) .. "," .. tostring(ICON_FRAME_SIZE) .. ";ach_icon.png]" ..
        "image[" .. tostring(MAIN_X + 0.2) .. "," .. tostring(MAIN_Y + 0.2) .. ";" .. tostring(ICON_SIZE) .. "," .. tostring(ICON_SIZE) .. ";" .. (current.icon or "unknown_item.png") .. "]" ..
        "label[" .. tostring(MAIN_X + ICON_FRAME_SIZE + 0.35) .. "," .. tostring(MAIN_Y + 0.08) .. ";" .. minetest.colorize(current.color or "#FFFFFF", current.title or "Untitled") .. "]" ..

        -- AOI header + wrapped, non-editable label (uses escaped \n)
        "label[" .. tostring(MAIN_X + ICON_FRAME_SIZE + 0.35) .. "," .. tostring(aoi_label_y) .. ";" .. minetest.colorize("#55FFFF", "AREA OF INTEREST:") .. "]" ..
        "label[" .. tostring(MAIN_X + ICON_FRAME_SIZE + 0.35) .. "," .. tostring(aoi_text_y) .. ";" .. minetest.formspec_escape(wrapped_aoi) .. "]" ..

        -- Description box (below AOI)
        "box[" .. tostring(MAIN_X + ICON_FRAME_SIZE + 0.35) .. "," .. tostring(desc_box_y) .. ";" .. tostring(DESC_W) .. "," .. tostring(DESC_H) .. ";#00000088]" ..
        "textarea[" .. tostring(MAIN_X + ICON_FRAME_SIZE + 0.4) .. "," .. tostring(desc_text_y) .. ";" .. tostring(DESC_W - 0.1) .. "," .. tostring(DESC_H - 0.1) .. ";;;" .. minetest.formspec_escape(current.description or "") .. "]" ..

        -- Progress bar and fill
        "label[" .. tostring(MAIN_X) .. "," .. tostring(progress_label_y) .. ";" .. minetest.colorize("#888888", "RECOVERY STATUS") .. "]" ..
        "image[" .. tostring(MAIN_X) .. "," .. tostring(progress_bar_y) .. ";" .. tostring(PROGRESS_BAR_WIDTH) .. "," .. tostring(PROGRESS_BAR_HEIGHT) .. ";cw_bar_casing.png]" ..
        "image[" .. tostring(MAIN_X + 0.08) .. "," .. tostring(progress_fill_y) .. ";" .. tostring(fill_width) .. "," .. tostring(PROGRESS_FILL_HEIGHT) .. ";cw_neon_fill.png]" ..

        -- Progress numbers centered inside the bar
        "label[" .. tostring(progress_text_x) .. "," .. tostring(progress_text_y) .. ";" .. minetest.colorize("#FFFFFF", tostring(p_val) .. " / " .. tostring(current.goal)) .. "]" ..

        -- Reward block
        reward_block ..

        -- Sidebar chronicle index
        "label[" .. tostring(SIDEBAR_X) .. "," .. tostring(SIDEBAR_Y - 0.4) .. ";" .. minetest.colorize("#FFFFFF", "CHRONICLE INDEX") .. "]" ..
        "textlist[" .. tostring(SIDEBAR_X) .. "," .. tostring(SIDEBAR_Y) .. ";3.6," .. tostring(SIDEBAR_VISIBLE_HEIGHT) .. ";selector;" .. list_str .. ";" .. tostring(selected_index) .. ";false]" ..

        -- Exit
        "button_exit[10.5,9.0;3,0.7;quit;BACK TO WORLD]"

    return fs
end

-- Handle formspec events
minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= "cw_achievements:ui" then return end

    -- Collect button handler
    for field in pairs(fields) do
        if field:sub(1, 8) == "collect_" then
            local safe_id = field:sub(9)
            local real_id = nil
            if api and api.registry then
                for _, a in ipairs(api.registry) do
                    if sanitize_id(a.id) == safe_id then
                        real_id = a.id
                        break
                    end
                end
            end
            if real_id then
                api.collect_reward(player, real_id)
            end
            minetest.show_formspec(player:get_player_name(), "cw_achievements:ui", get_polished_fs(player:get_player_name(), 1))
            return
        end
    end

    -- Sidebar selection handler
    if fields.selector then
        local event = minetest.explode_textlist_event(fields.selector)
        if event.type == "CHG" then
            minetest.show_formspec(player:get_player_name(), "cw_achievements:ui", get_polished_fs(player:get_player_name(), event.index))
        end
    end
end)

-- Chat command to open UI
minetest.register_chatcommand("achievements", {
    func = function(name)
        minetest.show_formspec(name, "cw_achievements:ui", get_polished_fs(name, 1))
    end,
})

