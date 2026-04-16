-- creative.lua
function fs_creative(player, S)
    local fs = { page_bg("cw_bg_creative.png") }
    
    -- Search UI
    fs[#fs+1] = ("field[%f,0.5;8,0.7;cw_csearch;;%s]"):format(GRID_X, minetest.formspec_escape(S.csearch or ""))
    fs[#fs+1] = "button[9,0.45;1.2,0.8;cw_csearch_go;Find]"
    fs[#fs+1] = "button[10.3,0.45;1.2,0.8;cw_csearch_clear;X]"

    -- Category Buttons
    local cx = GRID_X
    local cat_w = (GRID_TOTAL_W / #CATS) - 0.05
    for _, c in ipairs(CATS) do
        local style = (S.cat == c.id) and "bgcolor=#ffffff44" or "bgcolor=#00000066"
        fs[#fs+1] = ("style[cw_cat_%s;%s]button[%f,1.4;%f,0.7;cw_cat_%s;%s]"):format(c.id, style, cx, cat_w, c.id, c.label)
        cx = cx + cat_w + 0.05
    end

    -- Grid Items
    local list = CATALOG[S.cat] or {}
    -- Simple filter for search
    local filtered = {}
    for _, name in ipairs(list) do
        if name:find(S.csearch:lower()) then table.insert(filtered, name) end
    end

    local start_idx = math.floor(S.scroll or 0) * GRID_COLS
    for i = 1, (GRID_ROWS * GRID_COLS) do
        local item = filtered[start_idx + i]
        local r, c = math.floor((i-1)/GRID_COLS), (i-1)%GRID_COLS
        local x, y = GRID_X + c*1.1, GRID_Y + r*1.1
        
        fs[#fs+1] = ("box[%f,%f;1,1;%s]"):format(x, y, SLOT)
        if item then
            fs[#fs+1] = ("item_image_button[%f,%f;1,1;%s;cw_item_%d;]"):format(x, y, item, i)
        end
    end

    -- Scrollbar
    local max_s = math.max(0, math.ceil(#filtered / GRID_COLS) - GRID_ROWS)
    fs[#fs+1] = ("scrollbar[11.8,%f;0.4,%f;vertical;cw_scroll;%d]"):format(GRID_Y, GRID_H, S.scroll or 0)

    -- Hotbar
    fs[#fs+1] = ("list[current_player;main;1.5,%f;9,1;0]"):format(HOTBAR_Y)
    return table.concat(fs)
end