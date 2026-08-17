-- mods/cw_workbench/init.lua
-- Crafting Table: 3x3 grid only when using the table; restore to 2x2 after.
-- License: MIT
local MOD = minetest.get_current_modname()
local modpath = minetest.get_modpath(minetest.get_current_modname())
local MP = minetest.get_modpath("cw_workbench")
dofile(modpath .. "/crafts.lua")

-- Safe function to restore 2x2 crafting and prevent item loss from slots 5-9
local function restore_2x2(playername)
	local player = minetest.get_player_by_name(playername)
	if not player then return end
	local inv = player:get_inventory()
	if inv then
		local craft_list = inv:get_list("craft")
		if craft_list then
			for i = 5, 9 do
				if craft_list[i] and not craft_list[i]:is_empty() then
					local leftover = inv:add_item("main", craft_list[i])
					if not leftover:is_empty() then
						minetest.item_drop(leftover, player, player:get_pos())
					end
					craft_list[i] = ItemStack("")
				end
			end
			inv:set_list("craft", craft_list)
		end
		inv:set_size("craft", 4)
		inv:set_width("craft", 2)
	end
end

minetest.register_node("cw_workbench:crafting_table", {
	description = "Crafting Table",
	tiles = {
		"crafting_table_top.png", "crafting_table_bottom.png",
		"crafting_table_side2.png", "crafting_table_side3.png",
		"crafting_table_side.png", "crafting_table_side3.png",
	},
	groups = {choppy = 2, oddly_breakable_by_hand = 2, handy = 1},
	sounds = default and default.node_sound_wood_defaults() or nil,

	on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
		if not clicker or not clicker:is_player() then return end
		local inv = clicker:get_inventory()
		
		-- Switch player inventory craft grid to 3x3 first
		inv:set_size("craft", 9)
		inv:set_width("craft", 3)

		-- Force engine to recalculate craft recipe output by touching the inventory list
		inv:set_list("craft", inv:get_list("craft"))

		-- Centered layout configuration (UI width = 9)
		local UI_W, UI_H = 9.0, 9.0
		local fs = ("size[%d,%d]"):format(UI_W, UI_H)
		fs = fs .. "bgcolor[#0A0A0ADD;true]background9[0,0;" .. UI_W .. "," .. UI_H .. ";gui_formbg.png;true;10]"
		
		-- Title
		fs = fs .. "label[1.5,0.4;Crafting Table]"
		
		-- Centered 3x3 craft grid & result slot
		fs = fs .. "list[current_player;craft;1.5,0.9;3,3;]"
		fs = fs .. "label[4.9,2.1;->]"
		fs = fs .. "list[current_player;craftresult;5.6,1.8;1,1;]"
		
		-- Main inventory & Hotbar (centered at width 9)
		fs = fs .. "list[current_player;main;0,4.2;9,3;9]"
		fs = fs .. "list[current_player;main;0,7.6;9,1;]"
		
		-- List rings for shift-clicking
		fs = fs .. "listring[current_player;main]listring[current_player;craft]"
		fs = fs .. "listring[current_player;main]listring[current_player;craftresult]"

		minetest.show_formspec(clicker:get_player_name(), "cw_workbench:ui", fs)
	end,
})

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "cw_workbench:ui" then return false end
	if fields.quit then
		restore_2x2(player:get_player_name())
	end
	return false
end)

minetest.register_on_leaveplayer(function(player)
	local inv = player:get_inventory()
	if inv and inv:get_size("craft") ~= 4 then
		restore_2x2(player:get_player_name())
	end
end)