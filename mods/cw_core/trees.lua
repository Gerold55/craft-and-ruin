-- ============================================================================
-- cw_core: Tree Growth (Schematics) + Creative Fixes + Leaf Decay
-- ============================================================================

local MODPATH = minetest.get_modpath("cw_core")

-- Creative check helper
local function is_creative(name)
	return minetest.settings:get_bool("creative_mode") or 
	       minetest.check_player_privs(name, {creative = true})
end

-- Tint helper (Kept from your original code)
local function leaf_p2_at(pos)
	if cw_biome and cw_biome.get_palette_index_at_pos then
		local idx = cw_biome.get_palette_index_at_pos(pos) or 170
		return math.max(0, math.min(255, idx))
	end
	return 170
end

-- Refill hand in Creative (Minecraft behavior)
local function creative_refill(placer)
	if placer and is_creative(placer:get_player_name()) then
		local idx = placer:get_wield_index()
		minetest.after(0, function()
			local inv = placer:get_inventory()
			local stack = inv:get_stack("main", idx)
			if not stack:is_empty() then
				stack:set_count(stack:get_stack_max())
				inv:set_stack("main", idx, stack)
			end
		end)
	end
end

-------------------------------------------------------------------------------
-- 1. SCHEMATIC PLACER
-------------------------------------------------------------------------------
-- This replaces your place_oak_trunk_and_leaves function
local function grow_tree_schematic(pos, variant)
	local schem_path = MODPATH .. "/schematics/tree_" .. variant .. ".mts"
	
	-- Remove sapling
	minetest.remove_node(pos)
	
	-- Place Schematic (Centered: assuming 5x5 area, adjust -2 if needed)
	minetest.place_schematic(
		{x = pos.x - 2, y = pos.y, z = pos.z - 2},
		schem_path,
		"random",
		nil,
		false
	)
	
	-- Post-process: Apply palette tinting to leaves in the area
	-- This ensures the schematic leaves match the biome color
	local radius = 3
	local nodes = minetest.find_nodes_in_area(
		{x=pos.x-radius, y=pos.y, z=pos.z-radius},
		{x=pos.x+radius, y=pos.y+10, z=pos.z+radius},
		{"cw_core:"..variant.."_leaves"}
	)
	for _, p in ipairs(nodes) do
		minetest.set_node(p, {name="cw_core:"..variant.."_leaves", param2 = leaf_p2_at(p)})
	end
end

-------------------------------------------------------------------------------
-- 2. SAPLING DEFINITIONS (Oak, Birch, Spruce)
-------------------------------------------------------------------------------
local tree_types = {
	{ name = "oak", desc = "Oak Sapling" },
	{ name = "birch", desc = "Birch Sapling" },
	{ name = "spruce", desc = "Spruce Sapling" },
}

for _, t in ipairs(tree_types) do
	minetest.register_node("cw_core:" .. t.name .. "_sapling", {
		description = t.desc,
		drawtype = "plantlike",
		tiles = {"cw_" .. t.name .. "_sapling.png"},
		inventory_image = "cw_" .. t.name .. "_sapling.png",
		paramtype = "light",
		sunlight_propagates = true,
		walkable = false,
		selection_box = { type = "fixed", fixed = {-0.3, -0.5, -0.3, 0.3, 0.3, 0.3} },
		groups = {snappy = 3, sapling = 1, attached_node = 1},
		
		on_place = function(itemstack, placer, pointed_thing)
			local stack = minetest.item_place(itemstack, placer, pointed_thing)
			creative_refill(placer)
			return stack
		end,
		
		on_construct = function(pos)
			-- Minecraft-style random growth delay
			minetest.get_node_timer(pos):start(math.random(200, 400))
		end,
		
		on_timer = function(pos)
			grow_tree_schematic(pos, t.name)
			return false
		end,
	})
end

-------------------------------------------------------------------------------
-- 3. LEAF DECAY (Supports all types)
-------------------------------------------------------------------------------
minetest.register_abm({
	label = "cw_core:leaf_decay",
	nodenames = {"cw_core:oak_leaves", "cw_core:birch_leaves", "cw_core:spruce_leaves"},
	interval = 7, 
	chance = 12,
	action = function(pos, node)
		local tree_type = node.name:match(":(%w+)_leaves")
		local log_name = "cw_core:" .. tree_type .. "_log"
		
		-- Look for log within 4 nodes
		local logs = minetest.find_nodes_in_area(
			{x=pos.x-4, y=pos.y-4, z=pos.z-4},
			{x=pos.x+4, y=pos.y+4, z=pos.z+4},
			{log_name}
		)
		
		if #logs == 0 then
			-- Drop sapling chance
			if math.random(1, 20) == 1 then
				minetest.add_item(pos, "cw_core:" .. tree_type .. "_sapling")
			end
			minetest.set_node(pos, {name="air"})
		end
	end
})