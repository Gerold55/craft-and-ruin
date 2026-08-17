-- Cube_World Standalone Inventory UI
-- MIT License.

-------------------- Window & Layout --------------------
local UI_W, UI_H   = 13, 12.8
local CONTENT_TOP  = 1.05
local BASELINE_Y   = CONTENT_TOP + 0.30
local STRIP_H      = 1.05
local MARGIN_X     = 0.80
local RIGHT_GUTTER = 0.80

local BG           = "#1a1a1acc"
local STRIP        = "#2a2a2acc"
local SLOT         = "#00000040"

local HOTBAR_Y     = UI_H - 1.50
local HOTBAR_X     = (UI_W - 10) / 2

local BG_INV_TEX = "cw_bg_inventory.png"
local BG_CRE_TEX = "cw_bg_creative.png"
local BG_REC_TEX = "cw_bg_recipes.png"

-- === Creative grid tuning (fills more space) ===============================
GRID_COLS, GRID_ROWS = 10, 7          -- was 14x5 → now 15x6
CELL, GAP            = 1.00, 0.10     -- slot size & spacing

-- Place the grid
GRID_X               = MARGIN_X       -- left edge
local BASE_GRID_Y    = CONTENT_TOP + 1.50
CREATIVE_Y_OFFSET    = 0.10           -- nudge up/down
GRID_Y               = BASE_GRID_Y + CREATIVE_Y_OFFSET

-- Derived sizes (do not edit directly)
GRID_W = GRID_COLS*CELL + (GRID_COLS-1)*GAP   -- 16.4 with 15×1.0 & 0.10 gaps
GRID_H = GRID_ROWS*CELL + (GRID_ROWS-1)*GAP   -- 6×1.0 + 5×0.10 = 6.5
GRID_TOTAL_W = GRID_W                          -- used to align search/categories

local TAB_NAMES  = "Inventory,Creative"

local CATS = {
  {id = "all",  label = "ALL"}, --icon = "cw_icon_all.png"
  {id="blocks", label="BLOCKS"},
  {id="items",  label="ITEMS"},
  {id="nature", label="NATURE"},
  {id="tools",  label="TOOLS"},
  {id="colored",   label="COLORED BLOCKS"},
}

-- Build CATALOG.all from the other categories (unique, stable order)
local function rebuild_all_list()
  local seen, all = {}, {}
  -- choose the order you want them merged in:
  local order = {"blocks","items","nature","tools","colored"}
  for _,k in ipairs(order) do
    local t = CATALOG[k] or {}
    for i = 1, #t do
      local name = t[i]
      if not seen[name] then
        seen[name] = true
        all[#all+1] = name
      end
    end
  end
  CATALOG.all = all
end

-- Flip if your build supports model[]
local USE_MODEL = false

-- Full-page background image (drawn behind everything else on the page)
local function page_bg(tex)
  if not tex or tex == "" then return "" end
  -- draws at (0,0) and stretches to the formspec size
  return ("image[0,0;%0.2f,%0.2f;%s]"):format(UI_W, UI_H, tex)
end

-------------------- Per-player state -------------------
local P = {}
local function st(name)
    local player = minetest.get_player_by_name(name)
    local creative = false

    if minetest.is_creative_enabled then
        creative = minetest.is_creative_enabled(name)
    elseif minetest.settings then
        creative = minetest.settings:get_bool("creative_mode")
    end

    P[name] = P[name] or {
        tab = creative and 2 or 1, -- go straight to creative tab
        cat = "all",               -- default category = ALL
        csearch = "",
        scroll = 0,
        rquery = "",
        pressed_book = false,
    }

    return P[name]
end
minetest.register_on_leaveplayer(function(p) P[p:get_player_name()] = nil end)

-------------------- Inventories ------------------------
local function ensure_main_9(player)
  local inv = player:get_inventory()
  inv:set_size("main", 36); inv:set_width("main", 9)
end
local function ensure_2x2(player)
  local inv = player:get_inventory()
  inv:set_size("craft", 4); inv:set_width("craft", 2)
end
-- Detached 1-slot trash per player.
local function ensure_trash(player)
  local name = player:get_player_name()
  local det  = "cw_trash:" .. name
  if minetest.get_inventory({ type = "detached", name = det }) then
    return det
  end

  local inv = minetest.create_detached_inventory(det, {
    -- Accept any stack size; we'll delete it immediately.
    allow_put = function(_, _, _, stack, player)
      return stack:get_count()
    end,

    -- Instantly delete whatever arrives here.
    on_put = function(inv, listname, index, stack, player)
      inv:set_stack(listname, index, nil)  -- clear
      -- (Optional) little “poof” sound or particles:
      -- minetest.sound_play("trash", {to_player = player:get_player_name(), gain = 0.2}, true)
    end,

    -- Don’t allow taking/moving out (not necessary, but tidy).
    allow_take = function() return 0 end,
    allow_move = function(_,_,_,_,_,_) return 0 end,
  })

  inv:set_size("trash", 1)
  return det
end

local ARMOR_ORDER = {"helmet","chestplate","leggings","boots","shield"}
local function ensure_detached(player)
  local name = player:get_player_name()
  local detname = "cw_ui_armor:"..name
  if minetest.get_inventory({type="detached", name=detname}) then return detname end
  local det = minetest.create_detached_inventory(detname, {
    allow_put=function(_,_,i,stk)
      local def=minetest.registered_items[stk:get_name()] or {}
      local g=def.groups or {}
      local k=ARMOR_ORDER[i+1]
      if k=="helmet"     and (g.armor_head or g.helmet)     then return stk:get_count() end
      if k=="chestplate" and (g.armor_torso or g.chestplate) then return stk:get_count() end
      if k=="leggings"   and (g.armor_legs or g.leggings)    then return stk:get_count() end
      if k=="boots"      and (g.armor_feet or g.boots)       then return stk:get_count() end
      if k=="shield"     and (g.shield or g.armor_shield)    then return stk:get_count() end
      return stk:get_count()
    end,
    allow_take=function() return 99 end,
    allow_move=function(_,_,_,_,_,c) return c end,
  })
  det:set_size("armor", 5)
  return detname
end

minetest.register_on_joinplayer(function(player)
  ensure_main_9(player); ensure_2x2(player); ensure_detached(player)
  ensure_trash(player)
  minetest.after(0.05, function()
    if player and player:is_player() then
      player:set_inventory_formspec(build_formspec(player))
    end
  end)
end)

-------------------- Creative catalog -------------------
-----------------------------------------------------------------------
-- Creative catalog (DECLARE FIRST, then functions that use it)
-----------------------------------------------------------------------
local CATALOG = {
  blocks = {},
  items  = {},
  copper = {},
  nature = {},
  tools  = {},
  colored   = {},
  all    = {},   -- keep a slot for 'all' to avoid nil lookups
}

-- optional: category button list (already in your file)
-- CATS = { {id="all",label="ALL"}, {id="blocks",label="BLOCKS"}, ... }

-- Helper: build CATALOG.all by merging other categories (unique, stable)
local function rebuild_all_list()
  local seen, all = {}, {}
  -- choose merge order you want reflected in ALL:
  local order = {"blocks","items","nature","tools","colored"}
  for _, k in ipairs(order) do
    local t = CATALOG[k] or {}
    for i = 1, #t do
      local name = t[i]
      if not seen[name] then
        seen[name] = true
        all[#all + 1] = name
      end
    end
  end
  CATALOG.all = all
end

-- Simple classifiers (keep your versions if you’ve edited them)
local function is_tool(def)
  local g = def.groups or {}
  return def.type == "tool" or g.tool or g.pickaxe or g.shovel or g.axe or g.hoe or g.sword
end

local function is_block(def)
  return (def.type == "node") or (def.walkable and (def.tiles or def.mesh or def.node_box))
end

local function is_wireish(n, d)
  local g = d.groups or {}
  if g.copper or g.wire or g.logic or g.electric or g.signal then return true end
  n = n:lower()
  return n:find("copper",1,true) or n:find("wire",1,true) or n:find("lever",1,true) or n:find("switch",1,true)
end

local function is_nature(n, d)
  local g = d.groups or {}

  -- group-based nature detection
  if g.tree or g.leaves or g.sapling or g.flower or g.grass or g.soil or g.mushroom or g.petals then
    return true
  end

  -- name-based nature detection
  n = n:lower()
  if n:find("mushroom",1,true) or n:find("fungus",1,true) or n:find("petal",1,true) then
    return true
  end

  return n:find("dirt",1,true) or n:find("sand",1,true) or n:find("water",1,true) or
         n:find("ice",1,true) or n:find("log",1,true) or n:find("leaf",1,true)
end

local function show_ok(_, d)
  if (d.groups or {}).not_in_creative_inventory == 1 then return false end
  if d.drawtype == "airlike" and d.type ~= "tool" then
    return (d.inventory_image or "") ~= ""
  end
  return true
end

local function sort_fn(a, b)
  local da = (minetest.registered_items[a].description or ""):lower()
  local db = (minetest.registered_items[b].description or ""):lower()
  if da == db then return a < b else return da < db end
end

-- Now fill categories, then build ALL (AFTER fill + sort)
minetest.register_on_mods_loaded(function()

  -- list of color keywords to detect
  local COLOR_WORDS = {
    "red","blue","green","yellow","purple","cyan","magenta",
    "orange","black","white","gray","grey","brown","pink"
  }

  -- helper: detect colored blocks (but NOT plants, NOT items)
  local function is_colored_block(name, def)
    -- must be a block
    if not is_block(def) then return false end

    -- must NOT be nature (plants, leaves, flowers, saplings, grass)
    if is_nature(name, def) then return false end

    -- check for color words in name
    local lname = name:lower()
    for _,word in ipairs(COLOR_WORDS) do
      if lname:find(word, 1, true) then
        return true
      end
    end

    return false
  end

  -- main sorting loop
  for name, def in pairs(minetest.registered_items) do
    if show_ok(name, def) then

      -- NEW: colored block detection (items + plants excluded)
      if is_colored_block(name, def) then
        CATALOG.colored[#CATALOG.colored+1] = name

      elseif is_wireish(name, def) then
        CATALOG.copper[#CATALOG.copper+1] = name

      elseif is_tool(def) then
        CATALOG.tools[#CATALOG.tools+1] = name

      elseif is_block(def) and is_nature(name, def) then
        CATALOG.nature[#CATALOG.nature+1] = name

      elseif is_block(def) then
        CATALOG.blocks[#CATALOG.blocks+1] = name

      elseif def.type == "craft" or def.type == "none" then
        CATALOG.items[#CATALOG.items+1] = name

      else
        CATALOG.items[#CATALOG.items+1] = name
      end
    end
  end

  -- sort everything except 'all' (we rebuild it next)
  for k, lst in pairs(CATALOG) do
    if k ~= "all" then table.sort(lst, sort_fn) end
  end

  -- IMPORTANT: build the 'all' list after others exist
  rebuild_all_list()
end)


local function filter_items(lst, q)
  if not q or q=="" then return lst end
  q=q:lower(); local out={}
  for _,n in ipairs(lst) do
    local d=minetest.registered_items[n] or {}
    local s=(d.description or ""):lower().." "..n:lower()
    if s:find(q,1,true) then out[#out+1]=n end
  end
  return out
end

local function grid_slice_by_scroll(list, top_row)
  local start_index = top_row*GRID_COLS + 1
  local end_index   = start_index + GRID_COLS*GRID_ROWS - 1
  local out = {}
  for i=start_index, math.min(#list, end_index) do out[#out+1] = list[i] end
  return out
end

-------------------- Recipes helper ---------------------
local function recipe_grid(x0, y0, r)
    local CELL, GAP = 1.0, 0.10
    local step = CELL + GAP
    local items = r.items or {}
    local width = (r.method == "shaped" or r.method == "normal") and (r.width or 3) or 3
    
    local fs = {} -- Use a table for faster string concatenation
    
    for i = 1, 9 do
        local row = math.floor((i - 1) / 3) + 1
        local col = (i - 1) % 3 + 1
        
        -- Calculate coordinates once per slot
        local x = x0 + (col - 1) * step
        local y = y0 + (row - 1) * step
        
        -- Always draw the slot background
        fs[#fs + 1] = ("box[%0.2f,%0.2f;1,1;%s]"):format(x, y, SLOT)
        
        -- Determine which item belongs in this slot
        local item_name = ""
        if r.method == "shapeless" then
            item_name = items[i] or ""
        else
            -- For shaped/normal: map 1D items list to 2D grid based on recipe width
            local r_row = math.floor((i - 1) / 3)
            local r_col = (i - 1) % 3
            
            if r_col < width then
                local index = (r_row * width) + r_col + 1
                item_name = items[index] or ""
            end
        end
        
        if item_name ~= "" then
            fs[#fs + 1] = ("item_image[%0.2f,%0.2f;1,1;%s]"):format(x, y, item_name)
        end
    end
    
    return table.concat(fs)
end

-------------------- Header -----------------------------
local function header(tab)
    -- Initialize with version and layout settings
    local fs = ("formspec_version[6]size[%0.2f,%0.2f]position[0.5,0.5]anchor[0.5,0.5]")
                :format(UI_W, UI_H)

    -- 1. Main Background: Using background9 for a sliced, scalable texture.
    -- Removed the redundant #00000000 bgcolor to keep the string lean.
    fs = fs .. ("background9[0,0;%0.2f,%0.2f;%s;8]")
                :format(UI_W, UI_H, bg_tex)

    -- 2. Slot Styling: Transparent slot backgrounds with subtle hover/selected states.
    -- Format: [slot_bg_normal; slot_bg_hover; slot_border; label_color; highlight_color]
    fs = fs .. "listcolors[#00000000;#8C7C5B99;#FFFFFF22;#101010;#FFFFFF]"

    -- 3. Navigation: The tab header.
    fs = fs .. ("tabheader[0.2,0.2;cw_tabs;%s;%d;true;true]")
                :format(TAB_NAMES, tab)

    -- 4. Visual Separation: A horizontal strip/divider below the tabs.
    -- Moved slightly to ensure it doesn't overlap the tab bottom border.
    fs = fs .. ("box[0,%0.2f;%0.2f,%0.2f;%s]")
                :format(CONTENT_TOP - 0.1, UI_W, STRIP_H, STRIP)

    return fs
end

-------------------- Page: Inventory --------------------
local ARMOR_ICONS = {
  helmet     = "cw_icon_helmet.png",
  chestplate = "cw_icon_chestplate.png",
  leggings   = "cw_icon_leggings.png",
  boots      = "cw_icon_boots.png",
  shield     = "cw_icon_shield.png",
}

local function fs_inventory(player, S)
  ensure_2x2(player); local det=ensure_detached(player)
  local fs=""
  
  fs = fs .. page_bg(BG_INV_TEX)
  
  -- Armor column (left stack like the concept)
  local ax, ay = MARGIN_X, CONTENT_TOP - 0.65
  local ROW_STEP = 1.30
  local function armor_row(slot_index, row_index, key, label_text)
  local y = ay + row_index * ROW_STEP
  -- draw icon under slot
  local icon = ARMOR_ICONS[key] or "cw_slot_armor.png"
  fs = fs .. ("image[%0.2f,%0.2f;1,1;%s]"):format(ax, y, icon)

  -- actual inventory slot
  fs = fs .. ("list[detached:%s;armor;%0.2f,%0.2f;1,1;%d]")
            :format(det, ax, y, slot_index)

  -- label
  fs = fs .. ("label[%0.2f,%0.2f;%s]"):format(ax + 1.35, y + 0.30, label_text)
end
  armor_row(0, 0, "helmet",     "Helmet")
  armor_row(1, 1, "chestplate", "Chestplate")
  armor_row(2, 2, "leggings",   "Pants")
  armor_row(3, 3, "boots",      "Boots")
  armor_row(4, 4, "shield",     "Shield")

  -- Player model / placeholder near armor
  local MODEL_W, MODEL_H = 4.0, 6.2
  local model_x = ax + 3.6
  local model_y = ay + 0.08
  if USE_MODEL then
    fs = fs .. ("model[%0.2f,%0.2f;%0.1f,%0.1f;cw_model;character.b3d;character.png;0,0;0;0;30;0;79;false]")
              :format(model_x, model_y, MODEL_W, MODEL_H)
  else
    fs = fs .. ("box[%0.2f,%0.2f;%0.1f,%0.1f;#00000066]")
              :format(model_x, model_y, MODEL_W, MODEL_H)
  end

  -- === Crafting cluster (Minecraft-style: output RIGHT under grid) =========
  local right_edge = UI_W - RIGHT_GUTTER
  local craft_x = right_edge - 2.7
  local craft_y = CONTENT_TOP - 0.05

  fs = fs .. ("label[%0.2f,%0.2f;Crafting]")
      :format(craft_x + 0.25, craft_y - 0.53)

  fs = fs .. ("box[%0.2f,%0.2f;2.2,2.2;%s]list[current_player;craft;%0.2f,%0.2f;2,2;]")
      :format(craft_x, craft_y, "#00000020", craft_x, craft_y)

  local out_x = craft_x + 1.28
  local out_y = craft_y + 4
  fs = fs .. ("box[%0.2f,%0.2f;1,1;%s]list[current_player;craftpreview;%0.2f,%0.2f;1,1;]")
      :format(out_x, out_y, SLOT, out_x, out_y)

  -- Recipes image button (LEFT of output) with pressed-state
  local rec_x = out_x - 1.15
  local rec_y = out_y + 0.05
  local rec_img = (S.pressed_book and "cw_recipe_book_button_pressed.png")
               or "cw_recipe_book_button.png"
  fs = fs .. ("image_button[%0.2f,%0.2f;0.9,0.9;%s;cw_open_recipes;]")
      :format(rec_x, rec_y, rec_img)

  -- Main inventory + hotbar
local MAIN_X = (UI_W - 11.3) / 2   -- ← X for the 3×9
local MAIN_Y = craft_y + 6.50   -- ← Y for the 3×9 (your value)

local HB_X   = MAIN_X           -- ← X for hotbar (match 3×9)
local HB_Y   = HOTBAR_Y         -- ← Y for hotbar (global), change if you want it higher/lower

fs = fs .. ("list[current_player;main;%0.2f,%0.2f;9,3;9]"):format(MAIN_X, MAIN_Y)
fs = fs .. ("list[current_player;main;%0.2f,%0.2f;9,1;]"):format(HB_X,   HB_Y)
fs = fs .. "listring[current_player;main]listring[current_player;craft]"

  return fs
end

-- Build current creative list + max row for scrolling
local function creative_list_and_maxscroll(S)
  local base = CATALOG[S.cat] or {}
  local list = filter_items(base, S.csearch)
  local total_rows = math.max(1, math.ceil(#list / GRID_COLS))
  local max_scroll = math.max(0, total_rows - GRID_ROWS)
  return list, max_scroll
end

-- Force scroll to an integer row within [0, max_scroll]
local function clamp_scroll(v, max_scroll)
  -- v can be "12", "val:12", "CHG:12" depending on engine
  if type(v) == "string" then
    v = tonumber(v) or tonumber(v:match("[-%d]+")) or 0
  end
  v = math.floor((v or 0) + 0.0001)
  if v < 0 then v = 0 end
  if v > max_scroll then v = max_scroll end
  return v
end

-- ===================== Creative Tab (fixed & complete) ====================
local function fs_creative(player, S)
    -- 1. Permission Check (Simplified)
    local name = player:get_player_name()
    local is_creative = minetest.is_creative_enabled and minetest.is_creative_enabled(name) or 
                        (minetest.settings and minetest.settings:get_bool("creative_mode"))

    if not is_creative then
        return ("style_type[label;font=bold;font_size=18]label[%0.2f,%0.2f;Access Denied: Creative Mode Required]")
                :format(MARGIN_X, BASELINE_Y)
               .. ("list[current_player;main;%0.2f,%0.2f;8,1;]"):format(HOTBAR_X, HOTBAR_Y)
    end

    -- 2. State & Data Prep
    S.cat = S.cat or "all"
    S.scroll = S.scroll or 0
    local list = filter_items(CATALOG[S.cat] or {}, S.csearch)
    local max_scroll = math.max(0, math.ceil(#list / GRID_COLS) - GRID_ROWS)
    if S.scroll > max_scroll then S.scroll = max_scroll end

    local fs = { page_bg(BG_CRE_TEX) }

    -- 3. Search & Header Area
    -- Using a combined search bar for a cleaner "modern browser" look
    local SEARCH_W = GRID_TOTAL_W - 2.5
    fs[#fs+1] = ("field[%0.2f,0.5;%0.2f,0.7;cw_csearch;;%s]")
                :format(GRID_X, SEARCH_W, minetest.formspec_escape(S.csearch or ""))
    fs[#fs+1] = "field_close_on_enter[cw_csearch;false]"
    
    -- Compact Action Buttons
    fs[#fs+1] = ("style[cw_csearch_go;bgcolor=#3366ff;textcolor=#ffffff]button[%0.2f,0.45;1.2,0.8;cw_csearch_go;Find]")
                :format(GRID_X + SEARCH_W + 0.1)
    fs[#fs+1] = ("button[%0.2f,0.45;1.1,0.8;cw_csearch_clear;Clear]")
                :format(GRID_X + SEARCH_W + 1.4)

    -- 4. Category Navigation (Modern Tab Style)
    local cx = GRID_X
    local CAT_W = (GRID_TOTAL_W / #CATS) - 0.05
    for _, c in ipairs(CATS) do
        local style = (S.cat == c.id) and "bgcolor=#ffffff33;font=bold" or "bgcolor=#00000066"
        fs[#fs+1] = ("style[cw_cat_%s;%s]button[%0.2f,1.4;%0.2f,0.7;cw_cat_%s;%s]")
                    :format(c.id, style, cx, CAT_W, c.id, c.label)
        cx = cx + CAT_W + 0.05
    end

    -- 5. Items Grid with "Soft" Slot Backgrounds
    fs[#fs+1] = ("box[%0.2f,%0.2f;%0.2f,%0.2f;#00000044]"):format(GRID_X - 0.1, GRID_Y - 0.1, GRID_TOTAL_W + 0.2, GRID_H + 0.2)
    
    local slice = grid_slice_by_scroll(list, S.scroll)
    for i = 1, (GRID_ROWS * GRID_COLS) do
        local name = slice[i]
        local row = math.floor((i - 1) / GRID_COLS)
        local col = (i - 1) % GRID_COLS
        local xx = GRID_X + col * (CELL + GAP)
        local yy = GRID_Y + row * (CELL + GAP)

        -- Slot visual
        fs[#fs+1] = ("box[%0.2f,%0.2f;%0.2f,%0.2f;%s]"):format(xx, yy, CELL, CELL, SLOT)
        
        if name then
            local btn_name = "cw_item_" .. i
            fs[#fs+1] = ("item_image_button[%0.2f,%0.2f;%0.2f,%0.2f;%s;%s;]")
                        :format(xx, yy, CELL, CELL, name, btn_name)
            local desc = minetest.registered_items[name] and minetest.registered_items[name].description or name
            fs[#fs+1] = ("tooltip[%s;%s]"):format(btn_name, minetest.formspec_escape(desc))
        end
    end

    -- 6. Integrated Scrollbar
    local SB_X = GRID_X + GRID_TOTAL_W + 0.15
    fs[#fs+1] = ("scrollbaroptions[max=%d;thumbsize=%d]scrollbar[%0.2f,%0.2f;0.4,%0.2f;vertical;cw_scroll;%d]")
                :format(max_scroll, GRID_ROWS, SB_X, GRID_Y, GRID_H, S.scroll)

    -- 7. Footer: Player Hotbar
    fs[#fs+1] = "label[0.85," .. (UI_H - 1.8) .. ";Quick Access]"
    fs[#fs+1] = ("list[current_player;main;0.85,%0.2f;9,1;]"):format(UI_H - 1.4)

    -- 8. Utility Logic (Shift-Click Trash)
    local det_trash = ensure_trash(player)
    fs[#fs+1] = ("list[detached:%s;trash;-10,-10;1,1;]"):format(det_trash)
    fs[#fs+1] = ("listring[current_player;main]listring[detached:%s;trash]"):format(det_trash)

    return table.concat(fs)
end

 -- ===================== Creative Tab (wrapped correctly) =====================
local function fs_creative(player, S)
  -- data prep (you can keep your existing permission check above this function if you want)
  S.cat    = S.cat    or "all"
  S.scroll = S.scroll or 0

  local base       = CATALOG[S.cat] or {}
  local list       = filter_items(base, S.csearch)
  local total_rows = math.max(1, math.ceil(#list / GRID_COLS))
  local max_scroll = math.max(0, total_rows - GRID_ROWS)
  if S.scroll > max_scroll then S.scroll = max_scroll end

  -- =================== Tunable anchors (edit these numbers) =================
  -- Search row (aligned to grid width)
  local SEARCH_X   = GRID_X
  local SEARCH_Y   = 0.50
  local BTN_W      = 1.20
  local GAP_FIND   = 0.20
  local GAP_CLEAR  = 0.10
  local SEARCH_W   = GRID_TOTAL_W - (BTN_W + BTN_W) - (GAP_FIND + GAP_CLEAR)

  -- Category row (evenly spans grid width)
  local CAT_X      = GRID_X
  local CAT_Y      = SEARCH_Y + 0.95          -- just under search
  local CAT_GAP    = 0.08
  local CAT_H      = 0.90
  local CAT_W      = (GRID_TOTAL_W - CAT_GAP * (#CATS - 1)) / #CATS

  -- Grid background: hug the grid (no spill onto hotbar)
  local BG_X       = GRID_X
  local BG_Y       = GRID_Y - 0.06
  local BG_W       = GRID_TOTAL_W
  local BG_H       = GRID_H + 0.12

  -- Scrollbar: hug grid right edge
  local SB_W       = 0.50
  local SB_X       = GRID_X + GRID_TOTAL_W + 0.12
  local SB_Y       = BG_Y                -- use BG_Y so it aligns with grid
  local SB_H       = BG_H

  -- Creative hotbar: nudge up a bit so it sits clear of the bg
  local HB_X_C     = 0.85
  local HB_Y_C     = UI_H - 1.50
  -- =========================================================================

  local fs = ""

  fs = fs .. page_bg(BG_CRE_TEX)

  -- Row 1: Search / Find / Clear
  fs = fs .. ("field[%0.2f,%0.2f;%0.2f,0.8;cw_csearch;;%s]field_close_on_enter[cw_csearch;false]")
            :format(SEARCH_X, SEARCH_Y, SEARCH_W, minetest.formspec_escape(S.csearch or ""))

  local FIND_X  = SEARCH_X + SEARCH_W + GAP_FIND
  local CLEAR_X = FIND_X + BTN_W + GAP_CLEAR

  fs = fs .. ("button[%0.2f,%0.2f;%0.1f,0.8;cw_csearch_go;Find]")
            :format(FIND_X,  SEARCH_Y, BTN_W)
  fs = fs .. ("button[%0.2f,%0.2f;%0.1f,0.8;cw_csearch_clear;Clear]")
            :format(CLEAR_X, SEARCH_Y, BTN_W)

  -- Row 2: Categories
  local cx = CAT_X
  for _,c in ipairs(CATS) do
    fs = fs .. ("button[%0.2f,%0.2f;%0.2f,%0.2f;cw_cat_%s;%s]")
              :format(cx, CAT_Y, CAT_W, CAT_H, c.id, c.label)
    cx = cx + CAT_W + CAT_GAP
  end

  -- Grid background
  fs = fs .. ("box[%0.2f,%0.2f;%0.2f,%0.2f;#00000018]"):format(BG_X, BG_Y, BG_W, BG_H)

  -- Grid cells (visible slice by scroll)
  local slice = grid_slice_by_scroll(list, S.scroll)
  local i = 0
  for r = 0, GRID_ROWS - 1 do
    for c = 0, GRID_COLS - 1 do
      i = i + 1
      local name = slice[i]
      local xx = GRID_X + c * (CELL + GAP)
      local yy = GRID_Y + r * (CELL + GAP)
      fs = fs .. ("box[%0.2f,%0.2f;%0.2f,%0.2f;%s]"):format(xx, yy, CELL, CELL, SLOT)
      if name then
        local bid = "cw_item_" .. i
        fs = fs .. ("item_image_button[%0.2f,%0.2f;%0.2f,%0.2f;%s;%s;]")
                  :format(xx, yy, CELL, CELL, name, bid)
        local desc = (minetest.registered_items[name].description or name)
        fs = fs .. ("tooltip[%s;%s]"):format(bid, minetest.formspec_escape(desc))
      end
    end
  end

  -- Scrollbar
  fs = fs .. ("scrollbaroptions[max=%d;thumbsize=%d]")
            :format(math.max(1, max_scroll), math.max(1, GRID_ROWS))
  fs = fs .. ("scrollbar[%0.2f,%0.2f;%0.2f,%0.2f;vertical;cw_scroll;%d]")
            :format(SB_X, SB_Y, SB_W, SB_H, S.scroll)

  -- Creative hotbar (visible)
  fs = fs .. ("list[current_player;main;%0.2f,%0.2f;9,1;]"):format(HB_X_C, HB_Y_C)

  -- Hidden trash + listring
  local det_trash = ensure_trash(player)
  fs = fs .. ("list[detached:%s;trash;-100,-100;1,1;]"):format(det_trash)
  fs = fs .. ("listring[current_player;main]listring[detached:%s;trash]"):format(det_trash)

  return fs
end

-- ================= Page: Recipes (always shows a centered 3x3) =============
local function fs_recipes(player, S)
  local fs = ""

  -- ---- Tunables (move pieces by editing these numbers) --------------------
  local TOP_Y      = 0.55
  local BACK_X     = 0.55
  local FIELD_X    = 1.45
  local FIELD_W    = 8.50
  local BTN_GAP    = 0.20
  local BTN_W      = 1.10

  -- Grid geometry (do not change cell size unless you want different slot size)
  local CELL, GAP  = 1.00, 0.10
  local GRID_W     = 3 * (CELL + GAP) - GAP          -- width of 3 cells
  local BLOCK_W    = GRID_W + 1.20                   -- grid + space to output
  local GRID_Y     = CONTENT_TOP + 1.20              -- vertical anchor of grid
  local GRID_X     = (UI_W - BLOCK_W) / 2            -- center horizontally
  local OUT_X      = GRID_X + GRID_W + 0.60          -- output box x
  local OUT_Y      = GRID_Y + 1.10                    -- output box y

  local TEXT_X     = MARGIN_X
  local TEXT_Y     = GRID_Y + 3.80
  local TEXT_W     = UI_W - 2 * MARGIN_X
  local TEXT_H     = UI_H - TEXT_Y - 1.60
  -- -------------------------------------------------------------------------

  -- Page background (optional image hook)
  fs = fs .. page_bg(BG_REC_TEX)

  -- Top row (Back + query + Clear + Go)
  fs = fs .. ("button[%0.2f,%0.2f;0.80,0.80;cw_rq_back;Back]"):format(BACK_X, TOP_Y-0.04)
  fs = fs .. ("field[%0.2f,%0.2f;%0.2f,0.8;cw_rq;Output (mod:item);%s]")
          :format(FIELD_X, TOP_Y, FIELD_W, minetest.formspec_escape(S.rquery or ""))

  local clear_x = FIELD_X + FIELD_W + BTN_GAP
  local go_x    = clear_x + BTN_W + BTN_GAP
  fs = fs .. ("button[%0.2f,%0.2f;%0.1f,0.8;cw_rq_clear;Clear]"):format(clear_x, TOP_Y-0.04, BTN_W)
  fs = fs .. ("button[%0.2f,%0.2f;%0.1f,0.8;cw_rq_go;Go]")     :format(go_x,    TOP_Y-0.04, 1.00)

  -- ---- Always draw a placeholder grid + output box (empty) ----------------
  for r = 0, 2 do
    for c = 0, 2 do
      local x = GRID_X + c * (CELL + GAP)
      local y = GRID_Y + r * (CELL + GAP)
      fs = fs .. ("box[%0.2f,%0.2f;1,1;%s]"):format(x, y, SLOT)
    end
  end
  -- output box placeholder
  fs = fs .. ("box[%0.2f,%0.2f;1,1;%s]"):format(OUT_X, OUT_Y, SLOT)

  -- ---- If a query exists, draw the FIRST recipe on top of the grid --------
  local text_content =
      "Type an exact output (mod:item) and press Go.\n\n" ..
      "Tip: Paste itemstrings like cw_core:planks_oak"

  local q = (S.rquery or "")
  if q ~= "" then
    local recs = minetest.get_all_craft_recipes(q)
    if recs and recs[1] then
      local r = recs[1]

      -- Paint inputs (reuses your helper to position items over the boxes)
      fs = fs .. recipe_grid(GRID_X, GRID_Y, r)

      -- Paint output item over the output placeholder
      fs = fs .. ("item_image[%0.2f,%0.2f;1,1;%s]"):format(OUT_X, OUT_Y, q)

      -- Summary text
      local methods = {}
      for _, rr in ipairs(recs) do
        local m = rr.method or "normal"
        methods[m] = (methods[m] or 0) + 1
      end
      local lines = {"Results for: "..q, ""}
      for m, cnt in pairs(methods) do
        lines[#lines+1] = ("• %s: %d pattern(s)"):format(m, cnt)
      end
      lines[#lines+1] = ""
      lines[#lines+1] = "Showing the first pattern centered above."
      lines[#lines+1] = "Click \"Clear\" and search another item."
      text_content = table.concat(lines, "\n")
    else
      text_content = "No recipes found for: "..q
    end
  end

  -- ---- Text (wrapped) under the grid --------------------------------------
  local ht = minetest.formspec_escape(text_content:gsub("\n", "<br>"))
  fs = fs .. ("hypertext[%0.2f,%0.2f;%0.2f,%0.2f;cw_r_text;%s]")
          :format(TEXT_X, TEXT_Y, TEXT_W, TEXT_H, ht)

  -- Hotbar
  fs = fs .. ("list[current_player;main;%0.2f,%0.2f;9,1;]listring[current_player;main]")
          :format(0.85, HOTBAR_Y)

  return fs
end

-------------------- Compose & Events -------------------
function build_formspec(player)
  local S = st(player:get_player_name())
  local fs = header(S.tab)
  if S.tab==1 then fs = fs .. fs_inventory(player, S)
  elseif S.tab==2 then fs = fs .. fs_creative(player, S)
  else fs = fs .. fs_recipes(player, S) end
  return fs
end

local function refresh(p) p:set_inventory_formspec(build_formspec(p)) end

minetest.register_on_player_receive_fields(function(player, formname, fields)
  if formname ~= "" then return false end
  local name = player:get_player_name()
  local S = st(name)
  local name = player:get_player_name()
local S = st(name)

if (minetest.is_creative_enabled and minetest.is_creative_enabled(name))
  or (minetest.settings and minetest.settings:get_bool("creative_mode"))
then
    S.tab = 2
    S.cat = "all"
else
    S.tab = 1
end

  if fields.cw_tabs then
    local n=tonumber(fields.cw_tabs)
    if n and n>=1 and n<=3 then
        S.tab=n
        if n == 2 then -- entering creative tab
            S.cat = "all"
            S.scroll = 0
        end
    end
end

  -- Inventory: recipe button with pressed flash then open Recipes
  if fields.cw_open_recipes then
    S.pressed_book = true
    refresh(player)
    minetest.after(0.08, function()
      if not player or not player:is_player() then return end
      S.pressed_book = false
      S.tab = 3
      refresh(player)
    end)
    return true
  end

  -- Creative interactions
  if fields.cw_csearch_go and fields.cw_csearch then S.csearch=fields.cw_csearch or ""; S.scroll=0 end
  if fields.cw_csearch_clear then S.csearch=""; S.scroll=0 end
  if fields.cw_csearch and fields.key_enter_field=="cw_csearch" then S.csearch=fields.cw_csearch or ""; S.scroll=0 end
  for _,c in ipairs(CATS) do if fields["cw_cat_"..c.id] then S.cat=c.id; S.scroll=0 end end
  if fields.cw_scroll then
  -- Recompute list & max for the current filter/category before clamping
  local _, max_scroll = creative_list_and_maxscroll(S)
  S.scroll = clamp_scroll(fields.cw_scroll, max_scroll)
end
  if S.tab==2 then
    local base=filter_items(CATALOG[S.cat] or {}, S.csearch)
    local slice=grid_slice_by_scroll(base, S.scroll)
    for i=1,#slice do
      if fields["cw_item_"..i] then
        local it = slice[i]
        if it then
          local inv=player:get_inventory()
          local def=minetest.registered_items[it]
          local stack=ItemStack(it.." "..math.min(99, (def and def.stack_max) or 99))
          if inv:room_for_item("main", stack) then inv:add_item("main", stack)
          else local pos=player:get_pos(); pos.y=pos.y+0.5; minetest.add_item(pos, stack) end
        end
        break
      end
    end
  end

  -- Recipes
  if fields.cw_rq_back then S.tab=1 end
  if fields.cw_rq_clear then S.rquery="" end
  if (fields.cw_rq and fields.key_enter_field=="cw_rq") or fields.cw_rq_go then
    S.rquery = fields.cw_rq or ""
  end

  refresh(player); return true
end)

minetest.register_chatcommand("inv", {
  description = "Open Cube_World inventory",
  func = function(name)
    local p = minetest.get_player_by_name(name)
    if p then
        local S = st(name)

        -- Auto-go to creative tab if allowed
        if (minetest.is_creative_enabled and minetest.is_creative_enabled(name))
          or (minetest.settings and minetest.settings:get_bool("creative_mode"))
        then
            S.tab = 2
            S.cat = "all"
        else
            S.tab = 1
        end

        refresh(p)
    end
end
})