------------------------------------------------------------
-- CREATIVE PRIVILEGE CHECK
------------------------------------------------------------
function is_creative(player)
    return minetest.check_player_privs(player:get_player_name(), {creative = true})
end


------------------------------------------------------------
-- CREATIVE FORM SPEC (FULLY SCROLLABLE WITH DETACHED INVENTORY)
------------------------------------------------------------
function fs_creative(player, S)
    if not is_creative(player) then
        return fs_survival(player, S)
    end

    local player_name = player:get_player_name()
    local fs = { page_bg("cw_bg_creative.png") }

    --------------------------------------------------------
    -- SEARCH BAR
    --------------------------------------------------------
    fs[#fs+1] = ("field[%f,0.5;8,0.7;cw_csearch;;%s]")
        :format(GRID_X, minetest.formspec_escape(S.csearch or ""))

    fs[#fs+1] = "button[9,0.45;1.2,0.8;cw_csearch_go;Find]"
    fs[#fs+1] = "button[10.3,0.45;1.2,0.8;cw_csearch_clear;X]"


    --------------------------------------------------------
    -- CATEGORY BUTTONS
    --------------------------------------------------------
    local cx = GRID_X
    local cat_w = (GRID_TOTAL_W / #CATS) - 0.05

    for _, c in ipairs(CATS) do
        local style = (S.cat == c.id)
            and "bgcolor=#ffffff44"
            or  "bgcolor=#00000066"

        fs[#fs+1] = ("style[cw_cat_%s;%s]button[%f,1.4;%f,0.7;cw_cat_%s;%s]")
            :format(c.id, style, cx, cat_w, c.id, c.label)

        cx = cx + cat_w + 0.05
    end


    --------------------------------------------------------
    -- FILTER ITEMS & POPULATE DETACHED INVENTORY
    --------------------------------------------------------
    local list = CATALOG[S.cat] or {}
    local filtered = {}
    local search = (S.csearch or ""):lower()

    for _, name in ipairs(list) do
        if name:lower():find(search, 1, true) then
            table.insert(filtered, name)
        end
    end

    -- Update the detached inventory content for this player
    local inv_name = "creative_" .. player_name
    local inv = minetest.get_inventory({type = "detached", name = inv_name})
    if inv then
        inv:set_size("main", #filtered)
        local stack_list = {}
        for _, item_name in ipairs(filtered) do
            table.insert(stack_list, ItemStack(item_name))
        end
        inv:set_list("main", stack_list)
    end

    --------------------------------------------------------
    -- SCROLL SETTINGS
    --------------------------------------------------------
    local total_rows = math.ceil(#filtered / GRID_COLS)
    local max_scroll = math.max(0, total_rows - GRID_ROWS)

    -- Ensure scroll stays in bounds
    S.scroll = math.min(max_scroll, math.max(0, S.scroll or 0))

    --------------------------------------------------------
    -- SCROLL CONTAINER & DETACHED INVENTORY LIST
    --------------------------------------------------------
    local win_x = GRID_X
    local win_y = GRID_Y
    local win_w = GRID_COLS * 1.1
    local win_h = GRID_ROWS * 1.1

    -- Open scroll container tied to 'cw_scroll'
    fs[#fs+1] = ("scroll_container[%f,%f;%f,%f;cw_scroll;vertical;%d]")
        :format(win_x, win_y, win_w, win_h, S.scroll)

    -- Draw slot backgrounds underneath the inventory grid slots
    for r = 0, total_rows - 1 do
        for c = 0, GRID_COLS - 1 do
            if (r * GRID_COLS + c + 1) <= #filtered then
                fs[#fs+1] = ("box[%f,%f;1,1;%s]"):format(c * 1.1, r * 1.1, SLOT)
            end
        end
    end

    -- Native inventory list pulling directly from the detached inventory
    fs[#fs+1] = ("list[detached:%s;main;0,0;%d,%d;]")
        :format(inv_name, GRID_COLS, total_rows)

    fs[#fs+1] = "scroll_container_end[]"


    --------------------------------------------------------
    -- SCROLLBAR
    --------------------------------------------------------
    fs[#fs+1] = ("scrollbaroptions[min=0;max=%d;smallstep=1;largestep=%d;arrows=hide]")
        :format(max_scroll, GRID_ROWS)

    fs[#fs+1] = ("scrollbar[11.8,%f;0.4,%f;vertical;cw_scroll;%d]")
        :format(GRID_Y, GRID_H, S.scroll)


    --------------------------------------------------------
    -- HOTBAR
    --------------------------------------------------------
    fs[#fs+1] = ("list[current_player;main;1.5,%f;9,1;0]")
        :format(HOTBAR_Y)

    return table.concat(fs)
end


------------------------------------------------------------
-- ENTRY POINT
------------------------------------------------------------
function my_inventory.show(player, page, S)
    if page == "creative" and not is_creative(player) then
        page = "survival"
    end

    if page == "creative" then
        return fs_creative(player, S)
    else
        return fs_survival(player, S)
    end
end