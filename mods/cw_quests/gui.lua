-- gui.lua

cw_quests.gui.state = {}

local function show(name, fs)
    minetest.show_formspec(name, "cw_quests:journal", fs)
end

local function set_state(name, page, data)
    cw_quests.gui.state[name] = { page = page }
    if data then
        for k, v in pairs(data) do
            cw_quests.gui.state[name][k] = v
        end
    end
end

local function get_state(name)
    return cw_quests.gui.state[name] or {}
end

-------------------------------------------------------
-- INTRO PAGES
-------------------------------------------------------
local function render_intro(name)
    local st = get_state(name)
    local page = st.intro_page or 1
    local text = cw_quests.gui.intro_pages[page]

    local fs = [[
        formspec_version[6]
        size[14,9]
        image[0,0;14,9;cw_quests_journal_bg.png]
        label[1,0.7;The Lost Chronicle]
        hypertext[1,1.3;12,6;intro;]] .. minetest.formspec_escape(text) .. [[]
    ]]

    if page > 1 then
        fs = fs .. "button[1,7.5;3,1;intro_prev;← Back]"
    end
    if page < #cw_quests.gui.intro_pages then
        fs = fs .. "button[10,7.5;3,1;intro_next;Next →]"
    else
        fs = fs .. "button[10,7.5;3,1;intro_continue;Continue]"
    end

    show(name, fs)
end

-------------------------------------------------------
-- CHAPTER LIST (FIXED)
-------------------------------------------------------

-- FIXED: Only titles go into the textlist.
-- No IDs, no semicolons, no malformed pairs.
local function build_chapter_list()
    local lines = {}
    for _, ch in ipairs(cw_quests.chapters) do
        table.insert(lines, minetest.formspec_escape(ch.title))
    end
    return table.concat(lines, ",")
end

local function render_chapters(name)
    local st = get_state(name)
    local chapter_desc = st.chapter_desc or "Select a chapter."

    local fs = [[
        formspec_version[6]
        size[14,9]
        image[0,0;14,9;cw_quests_journal_bg.png]

        label[1,0.7;Chapters]
        textlist[1,1.3;5.5,6;chapter_list;]] .. build_chapter_list() .. [[]
        hypertext[7,1.3;6,5.5;chapter_info;]] .. minetest.formspec_escape(chapter_desc) .. [[]
        button[1,7.5;3,1;back_intro;← Journal]
    ]]

    if st.chapter then
        fs = fs .. "button[10,7.5;3,1;chapter_continue;Continue →]"
    end

    show(name, fs)
end

-------------------------------------------------------
-- CATEGORY LIST
-------------------------------------------------------
local function build_category_list(chapter)
    local lines = {}
    for _, cat in ipairs(chapter.categories) do
        table.insert(lines, minetest.formspec_escape(cat))
    end
    return table.concat(lines, ",")
end

local function render_categories(name)
    local st = get_state(name)
    local chapter = st.chapter

    local fs = [[
        formspec_version[6]
        size[14,9]
        image[0,0;14,9;cw_quests_journal_bg.png]

        label[1,0.7;Categories]
        textlist[1,1.3;5.5,6;cat_list;]] .. build_category_list(chapter) .. [[]
        hypertext[7,1.3;6,5.5;cat_info;Select a category.]
        button[1,7.5;3,1;back_chapters;← Chapters]
    ]]

    show(name, fs)
end

-------------------------------------------------------
-- QUEST LIST
-------------------------------------------------------
local function build_quest_list(name, cat)
    local pdata = cw_quests.get_player_quests(name)
    local lines = {}

    for _, id in ipairs(cw_quests.categories[cat] or {}) do
        local q = cw_quests.registered[id]
        if q then
            local st = pdata[id]
            local status = "[Locked]"
            if st then
                status = st.completed and "[Complete]" or "[In Progress]"
            end
            table.insert(lines, minetest.formspec_escape(status .. " " .. q.title))
        end
    end

    return table.concat(lines, ",")
end

local function render_quests(name, cat)
    local fs = [[
        formspec_version[6]
        size[14,9]
        image[0,0;14,9;cw_quests_journal_bg.png]
        label[1,0.7;Category:]
        label[2.5,0.7;]] .. minetest.formspec_escape(cat) .. [[]
        textlist[1,1.3;5.5,6;quest_list;]] .. build_quest_list(name, cat) .. [[]
        hypertext[7,1.3;6,5.5;quest_info;Select a quest.]
        button[1,7.5;3,1;back_categories;← Categories]
    ]]

    show(name, fs)
end

-------------------------------------------------------
-- QUEST DETAIL
-------------------------------------------------------
local function render_quest_detail(name, qid)
    local q = cw_quests.registered[qid]
    local pdata = cw_quests.get_player_quests(name)
    local st = pdata[qid]

    local text = q.title .. "\n\n" .. q.desc .. "\n\nObjectives:\n"
    for oid, odef in pairs(q.objectives) do
        local cur = st and (st.progress[oid] or 0) or 0
        text = text .. string.format("- %s: %d/%d\n", odef.desc, cur, odef.count)
    end

    local fs = [[
        formspec_version[6]
        size[14,9]
        image[0,0;14,9;cw_quests_journal_bg.png]
        label[1,0.7;Quest Details]
        hypertext[1,1.3;7,6;details;]] .. minetest.formspec_escape(text) .. [[]
        button[8.5,2.1;4,1;submit;Manual Submit]
        button[1,7.5;3,1;back_quests;← Quests]
    ]]

    show(name, fs)
end

-------------------------------------------------------
-- ENTRY POINT
-------------------------------------------------------
function cw_quests.open_questbook(name)
    set_state(name, "intro", { intro_page = 1 })
    render_intro(name)
end

-------------------------------------------------------
-- HANDLER
-------------------------------------------------------
minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= "cw_quests:journal" then return end
    local name = player:get_player_name()
    local st = get_state(name)

    ---------------------------------------------------
    -- INTRO
    ---------------------------------------------------
    if st.page == "intro" then
        if fields.intro_next then st.intro_page = st.intro_page + 1 return render_intro(name) end
        if fields.intro_prev then st.intro_page = st.intro_page - 1 return render_intro(name) end
        if fields.intro_continue then set_state(name, "chapters") return render_chapters(name) end
    end

    ---------------------------------------------------
    -- CHAPTERS
    ---------------------------------------------------
    if fields.back_intro then
        set_state(name, "intro", { intro_page = 1 })
        return render_intro(name)
    end

    if fields.chapter_list and st.page == "chapters" then
        local ev = minetest.explode_textlist_event(fields.chapter_list)
        if ev.type == "CHG" then
            local chapter = cw_quests.chapters[ev.index]
            if chapter then
                set_state(name, "chapters", {
                    chapter = chapter,
                    chapter_desc = chapter.desc
                })
                return render_chapters(name)
            end
        end
    end

    if fields.chapter_continue and st.page == "chapters" and st.chapter then
        set_state(name, "categories", { chapter = st.chapter })
        return render_categories(name)
    end

    ---------------------------------------------------
    -- CATEGORIES
    ---------------------------------------------------
    if fields.back_chapters then
        set_state(name, "chapters", { chapter_desc = st.chapter_desc })
        return render_chapters(name)
    end

    if fields.cat_list and st.page == "categories" then
        local ev = minetest.explode_textlist_event(fields.cat_list)
        if ev.type == "CHG" then
            local chapter = st.chapter
            local cat = chapter.categories[ev.index]
            if cat then
                set_state(name, "quests", { category = cat, chapter = chapter })
                return render_quests(name, cat)
            end
        end
    end

    ---------------------------------------------------
    -- QUESTS
    ---------------------------------------------------
    if fields.back_categories then
        set_state(name, "categories", { chapter = st.chapter })
        return render_categories(name)
    end

    if fields.quest_list and st.page == "quests" then
        local ev = minetest.explode_textlist_event(fields.quest_list)
        if ev.type == "CHG" then
            local cat = st.category
            local qid = cw_quests.categories[cat][ev.index]
            if qid then
                set_state(name, "quest_detail", { quest = qid, category = cat, chapter = st.chapter })
                return render_quest_detail(name, qid)
            end
        end
    end

    ---------------------------------------------------
    -- QUEST DETAIL
    ---------------------------------------------------
    if fields.back_quests then
        set_state(name, "quests", { category = st.category, chapter = st.chapter })
        return render_quests(name, st.category)
    end

    if fields.submit then
        cw_quests.manual_submit(player, st.quest)
        return render_quest_detail(name, st.quest)
    end
end)

