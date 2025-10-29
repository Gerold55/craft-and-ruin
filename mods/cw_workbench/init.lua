-- mods/cw_workbench/init.lua
-- Crafting Table: 3x3 grid only when using the table; restore to 2x2 after.
-- License: MIT
local MOD = minetest.get_current_modname()
local modpath = minetest.get_modpath(minetest.get_current_modname())
local MP = minetest.get_modpath("cw_workbench")
dofile(modpath .. "/crafts.lua")

-- Optional: simple nodebox/tiles; replace with your art.
minetest.register_node("cw_workbench:crafting_table", {
  description = "Crafting Table",
  tiles = {
    "crafting_table_top.png", "crafting_table_bottom.png",
    "crafting_table_side2.png", "crafting_table_side3.png",
    "crafting_table_side.png", "crafting_table_side3.png",
  },
  groups = {choppy=2, oddly_breakable_by_hand=2, handy=1},
  sounds = default and default.node_sound_wood_defaults() or nil,

  on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
    if not clicker or not clicker:is_player() then return end
    local inv = clicker:get_inventory()
    -- switch to 3x3
    inv:set_size("craft", 9)
    inv:set_width("craft", 3)

    local UI_W, UI_H = 10, 10
    local HOTBAR_Y = UI_H - 1.25
    local HOTBAR_X = (UI_W - 9) / 2

    local fs = ("size[%d,%d]"):format(UI_W, UI_H)
    fs = fs .. "bgcolor[#0A0A0ADD;true]background9[0,0;"..UI_W..","..UI_H..";gui_formbg.png;true;10]"
    fs = fs .. "label[0.6,0.4;Crafting Table]"
    -- 3x3 craft grid
    fs = fs .. "list[current_player;craft;0.6,1.0;3,3;]"
    fs = fs .. "list[current_player;craftpreview;4.2,2.0;1,1;]"
    -- inventory + hotbar
    fs = fs .. "list[current_player;main;0.55,"..(UI_H-5.3)..";9,3;9]"
    fs = fs .. ("list[current_player;main;%0.2f,%0.2f;9,1;]"):format(HOTBAR_X, HOTBAR_Y)
    fs = fs .. "listring[current_player;main]listring[current_player;craft]"

    minetest.show_formspec(clicker:get_player_name(), "cw_workbench:ui", fs)
  end,
})

-- When the player closes the workbench UI, restore 2x2 crafting
local function restore_2x2(playername)
  local player = minetest.get_player_by_name(playername)
  if not player then return end
  local inv = player:get_inventory()
  if inv then
    inv:set_size("craft", 4)
    inv:set_width("craft", 2)
  end
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
  if formname ~= "cw_workbench:ui" then return false end
  if fields.quit then
    restore_2x2(player:get_player_name())
  end
  return false
end)

minetest.register_on_leaveplayer(function(player)
  -- safety: ensure they don't get stuck at 3x3
  local inv = player:get_inventory()
  if inv and inv:get_size("craft") ~= 4 then
    inv:set_size("craft", 4)
    inv:set_width("craft", 2)
  end
end)
