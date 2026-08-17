-- cw_core/decorations.lua
-- Reeds + palette-tinted decor grass + flowers (Plains-friendly)

local MOD = "cw_core"
cw_core = rawget(_G, "cw_core") or {}

-- Translator
local S = (core.get_translator and core.get_translator(MOD)) or function(s) return s end

-- ===== Local helpers (scoped to this file) =====
local function _clamp(a, lo, hi)
  if a < lo then return lo elseif a > hi then return hi else return a end
end

local function _node_sound_leaves_fallback()
  if default and default.node_sound_leaves_defaults then
    return default.node_sound_leaves_defaults()
  end
  return {
    footstep = {name="default_grass_footstep", gain=0.45},
    dig      = {name="default_dig_snappy",     gain=0.3},
    dug      = {name="default_dug_node",       gain=0.3},
    place    = {name="default_place_node",     gain=1.0},
  }
end

-- Biome tint module (expected to be set by cw_core/biome_tint.lua via cw_core.biome_tint)
local biome_tint = cw_core.biome_tint

-- Simple humidity getter (fallback)
local function humidity_at(pos)
  local ok, data = pcall(core.get_biome_data, pos)
  return (ok and data and data.humidity) or 50
end

local MOD = core.get_current_modname()
local S = core.get_translator(MOD)

-- 1. UPDATED BASES: Added the new mapgen sand types
local BASES = {
    [MOD..":grass_block"]  = true,
    [MOD..":dirt"]         = true,
    [MOD..":sand"]         = true,
    [MOD..":beach_sand"]   = true, -- Compatibility with Mapgen
    [MOD..":desert_sand"]  = true, -- Compatibility with Mapgen
}

-- ============================================================================
-- Reeds (Bottom + Top system)
-- ============================================================================

-- Nodes reeds are allowed to grow on
local BASES = {
    ["cw_core:dirt"] = true,
    ["cw_core:grass_block"] = true,
    ["cw_core:sand"] = true,
    ["cw_core:beach_sand"] = true,
}

-- 2. UTILITIES
local function _is_water(nm)
    local def = core.registered_nodes[nm]
    return def and def.groups and (def.groups.water or 0) > 0
end

local function _water_adjacent(pos)
    local dirs = {{x=1,y=0,z=0},{x=-1,y=0,z=0},{x=0,y=0,z=1},{x=0,y=0,z=-1}}
    for _, d in ipairs(dirs) do
        local nn = core.get_node({x = pos.x + d.x, y = pos.y + d.y, z = pos.z + d.z}).name
        if _is_water(nn) then return true end
    end
    return false
end

local function _can_reeds_survive_at(pos)
    local below = core.get_node({x=pos.x, y=pos.y-1, z=pos.z}).name
    if not BASES[below] then return false end
    if not _water_adjacent({x=pos.x, y=pos.y-1, z=pos.z}) then return false end
    return true
end

local function _get_stack_info(pos)
    local p = vector.new(pos)
    while true do
        local below = core.get_node({x=p.x, y=p.y-1, z=p.z}).name
        if below == MOD..":reeds_bottom" then p.y = p.y - 1 else break end
    end
    local bottom = vector.new(p)
    local height = 1
    p.y = p.y + 1
    while true do
        local nm = core.get_node(p).name
        if nm == MOD..":reeds_bottom" or nm == MOD..":reeds_top" then
            height = height + 1
            p.y = p.y + 1
        else break end
    end
    return bottom, height
end

core.register_node(MOD..":reeds_bottom", {
    description = S("Reeds"),
    drawtype = "plantlike",
    waving = 1,
    tiles = {"cw_reeds.png"},
    inventory_image = "cw_reeds.png",
    paramtype = "light",
    paramtype2 = "degrotate",
    sunlight_propagates = true,
    walkable = false,
    buildable_to = true,
    groups = {snappy = 3, flammable = 2, attached_node = 1, reeds = 1},

    after_place_node = function(pos)
        if not _can_reeds_survive_at(pos) then
            core.remove_node(pos)
            return true
        end
        local above = {x=pos.x, y=pos.y+1, z=pos.z}
        if core.get_node(above).name == "air" then
            core.set_node(above, {name = MOD..":reeds_top"})
        end
    end,

    -- Breaking the bottom breaks the entire stack above it
    after_destruct = function(pos)
        local p = {x=pos.x, y=pos.y+1, z=pos.z}
        while true do
            local nm = core.get_node(p).name
            if nm == MOD..":reeds_top" or nm == MOD..":reeds_bottom" then
                core.remove_node(p)
                p.y = p.y + 1
            else
                break
            end
        end
    end,
})

core.register_node(MOD..":reeds_top", {
    drawtype = "plantlike",
    waving = 1,
    tiles = {"cw_reeds_top.png"},
    paramtype = "light",
    paramtype2 = "degrotate",
    sunlight_propagates = true,
    walkable = false,
    buildable_to = true,
    groups = {snappy = 3, flammable = 2, not_in_creative_inventory = 1, reeds = 1},

    -- Breaking the top should NOT break the bottom.
    after_destruct = function(pos)
        -- intentionally empty
    end,
})

core.register_abm({
    label = "Reeds natural growth",
    nodenames = {MOD..":reeds_bottom"},
    neighbors = {"group:water"},
    interval = 20,
    chance = 10,
    action = function(pos)
        local bottom, height = _get_stack_info(pos)

        -- If the bottom can't survive, remove the whole plant
        if not _can_reeds_survive_at(bottom) then
            core.remove_node(bottom)
            return
        end

        -- Grow up to 5 blocks tall (Minecraft sugarcane height)
        if height >= 5 then
            return
        end

        -- Find the top-most reed
        local top_pos = {x = bottom.x, y = bottom.y + height - 1, z = bottom.z}
        local new_top = {x = top_pos.x, y = top_pos.y + 1, z = top_pos.z}

        -- Grow if air above
        if core.get_node(new_top).name == "air" then
            core.set_node(top_pos, {name = MOD..":reeds_bottom"})
            core.set_node(new_top, {name = MOD..":reeds_top"})
        end
    end,
})

-- ====== DECOR GRASS (palette tinted like Minecraft) ========================

local GRASS_PALETTE = "cw_grass_palette.png" -- 1x16 vertical

-- Palette clamp/gamma for decor grass (re-use foliage settings or grass settings)
local settings = core.settings
local G_MIN   = tonumber(settings:get("cw_grass_palette_min_idx")) or 4
local G_MAX   = tonumber(settings:get("cw_grass_palette_max_idx")) or 11
local G_GAMMA = tonumber(settings:get("cw_grass_palette_gamma"))  or 0.95
do
  local m = math.floor((G_MIN or 0)+0.5); local M = math.floor((G_MAX or 15)+0.5)
  G_MIN, G_MAX = _clamp(m,0,15), _clamp(M,0,15)
  if G_MAX < G_MIN then G_MIN, G_MAX = G_MAX, G_MIN end
  G_GAMMA = _clamp(G_GAMMA, 0.5, 2.0)
end

local function humidity_to_palette_idx(h)
  h = _clamp(h or 50, 0, 100)
  local t = (h / 100) ^ G_GAMMA
  local idx = G_MIN + t * (G_MAX - G_MIN)
  return math.floor(idx + 0.5)
end

-- pick biome-preferred grass index (Plains=2 via biome_tint), else fallback
local function _decor_grass_index_for_pos(pos)
  if biome_tint and biome_tint.preferred_grass_index then
    local pref = biome_tint.preferred_grass_index(pos)
    if pref ~= nil then
      if biome_tint.clamp_grass_index then
        return biome_tint.clamp_grass_index(pos, pref)
      end
      return pref
    end
  end
  local idx = humidity_to_palette_idx(humidity_at(pos))
  if biome_tint and biome_tint.clamp_grass_index then
    idx = biome_tint.clamp_grass_index(pos, idx)
  end
  return idx
end

-- Expose an updater just for decor grass
function cw_core.update_decor_grass_tint(pos)
  local node = core.get_node(pos)
  if node.name ~= MOD..":grass_decor" then return end
  local def = core.registered_nodes[node.name]
  if not def or def.paramtype2 ~= "color" or not def.palette then return end
  local idx = _decor_grass_index_for_pos(pos)
  if (node.param2 or 0) ~= idx then
    node.param2 = idx
    core.swap_node(pos, node)
  end
end

core.register_node(MOD..":grass_decor", {
  description = S("Grass"),
  drawtype = "plantlike",
  waving = 1,
  tiles = { "cw_grass.png" },         -- grayscale/neutral base recommended
  inventory_image = "cw_grass.png",
  wield_image     = "cw_grass.png",
  use_texture_alpha = "clip",

  paramtype  = "light",
  paramtype2 = "color",
  palette    = GRASS_PALETTE,
  palette_index = math.floor((G_MIN + G_MAX) / 2),
  color         = "#8EB971",

  sunlight_propagates = true,
  walkable = false,
  buildable_to = true,

  groups = {snappy=3, flammable=2, attached_node=1},
  sounds = _node_sound_leaves_fallback(),
  selection_box = { type = "fixed", fixed = {-0.3,-0.5,-0.3, 0.3,0.3,0.3} },

  on_construct     = cw_core.update_decor_grass_tint,
  after_place_node = cw_core.update_decor_grass_tint,
})

-- One-time LBM: retint existing decor grass (NOT leaves)
core.register_lbm({
  name = MOD..":tint_grass_decor_once",
  nodenames = { MOD..":grass_decor" },
  run_at_every_load = false,
  action = cw_core.update_decor_grass_tint,
})

-- ====== FLOWERS ============================================================

local flowers = {
  {"daisy",    "Daisy"},
  {"bluebell", "Bluebell"},
}
for _, f in ipairs(flowers) do
  local name, desc = f[1], f[2]
  core.register_node(MOD..":flower_"..name, {
    description = S(desc),
    drawtype = "plantlike",
    tiles = {"cw_flower_"..name..".png"},
    inventory_image = "cw_flower_"..name..".png",
    wield_image     = "cw_flower_"..name..".png",

    use_texture_alpha = "clip",
    paramtype = "light",
    sunlight_propagates = true,
    walkable = false,
    buildable_to = true,

    groups = {snappy=3, flammable=2, flower=1, attached_node=1},
    sounds = _node_sound_leaves_fallback(),
    selection_box = { type = "fixed", fixed = {-0.25,-0.5,-0.25, 0.25,0.25,0.25} },
  })
end

core.register_node("cw_core:dead_bush", {
    description = "Dead Bush",
    drawtype = "plantlike",
    visual_scale = 1.0,
    -- Use your specific texture name here
    tiles = {"ws_dry_shrub.png"},
    inventory_image = "ws_dry_shrub.png",
    wield_image = "ws_dry_shrub.png",
    paramtype = "light",
    sunlight_propagates = true,
    walkable = false,
    buildable_to = true,
    groups = {snappy = 3, flammable = 2, attached_node = 1},
    sounds = {footstep = {name = "default_grass_footstep", gain = 0.5}},
    selection_box = {
        type = "fixed",
        fixed = {-0.3, -0.5, -0.3, 0.3, 0.3, 0.3},
    },
})

-- ===================================================================
-- Cattail Items
-- ===================================================================

local function is_water(name)
	return minetest.get_item_group(name, "water") > 0
end

-- ===================================================================
-- THE ROOTED BASE (Floor of the water)
-- ===================================================================
minetest.register_node("cw_core:sand_with_cattails", {
	description = "Cattail Rooted Base",
	drawtype = "plantlike_rooted",
	waving = 1,
	tiles = {"cw_sand.png"}, 
	special_tiles = {{ name = "cw_cattail_bottom.png", tileable_vertical = true }},
	paramtype = "light",
	paramtype2 = "leveled", 
	groups = { snappy = 3, flora = 1, oddly_breakable_by_hand = 3, not_in_creative_inventory = 1 },
	walkable = false,
	drop = "cw_core:cattail_roots",
	selection_box = {
		type = "fixed",
		fixed = {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5}, -- Click the sand to dig
	},

	-- RIGHT-CLICK TO DELETE (Leaves sand, returns roots)
	on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
		local name = clicker:get_player_name()
		if minetest.is_protected(pos, name) then return itemstack end

		minetest.set_node(pos, {name = "cw_core:sand"})
		local top_pos = {x = pos.x, y = pos.y + 2, z = pos.z}
		if minetest.get_node(top_pos).name == "cw_core:cattail_top" then
			minetest.remove_node(top_pos)
		end

		local roots_item = "cw_core:cattail_roots"
		if not minetest.settings:get_bool("creative_mode") then
			local inv = clicker:get_inventory()
			if inv:room_for_item("main", roots_item) then
				inv:add_item("main", roots_item)
			else
				minetest.add_item(pos, roots_item)
			end
		end
		minetest.sound_play("default_dig_snappy", {pos = pos, gain = 0.5})
		return itemstack
	end,

	-- LEFT-CLICK (DIG)
	after_destruct = function(pos)
		minetest.set_node(pos, {name = "cw_core:sand"}) -- Leave sand behind
		local top_pos = {x = pos.x, y = pos.y + 2, z = pos.z}
		if minetest.get_node(top_pos).name == "cw_core:cattail_top" then
			minetest.remove_node(top_pos)
		end
	end,
})

-- ===================================================================
-- THE TOP PART (Visible brown fluff)
-- ===================================================================
minetest.register_node("cw_core:cattail_top", {
	description = "Cattail Top",
	drawtype = "plantlike",
	tiles = {"cw_cattail_top.png"},
	paramtype = "light",
	walkable = false,
	groups = { snappy = 3, flora = 1, not_in_creative_inventory = 1 },
	drop = "cw_core:cattail_fiber",
	selection_box = {
		type = "fixed",
		fixed = {-0.15, -0.5, -0.15, 0.15, 0.5, 0.15}, -- Thin box
	},
	after_destruct = function(pos)
		local base_pos = {x = pos.x, y = pos.y - 2, z = pos.z}
		if minetest.get_node(base_pos).name == "cw_core:sand_with_cattails" then
			minetest.set_node(base_pos, {name = "cw_core:sand"})
		end
	end,
})

-- ===================================================================
-- THE PLACEMENT ITEM (Roots)
-- ===================================================================
minetest.register_craftitem("cw_core:cattail_roots", {
	description = "Cattail Roots",
	inventory_image = "cw_cattail_roots.png",
	on_place = function(itemstack, placer, pointed_thing)
		if pointed_thing.type ~= "node" then return itemstack end
		local under = pointed_thing.under
		local node_under = minetest.get_node(under)
		local base_pos, water_pos

		if minetest.get_item_group(node_under.name, "sand") > 0 or node_under.name == "cw_core:sand" then
			base_pos = vector.new(under)
			water_pos = {x = under.x, y = under.y + 1, z = under.z}
		elseif is_water(node_under.name) then
			base_pos = {x = under.x, y = under.y - 1, z = under.z}
			water_pos = vector.new(under)
		end

		if not base_pos then return itemstack end

		-- Shoreline Check: Is there land nearby at water level?
		local near_shore = false
		for _, c in ipairs({{x=1,z=0}, {x=-1,z=0}, {x=0,z=1}, {x=0,z=-1}}) do
			local n_pos = {x=water_pos.x+c.x, y=water_pos.y, z=water_pos.z+c.z}
			local n_name = minetest.get_node(n_pos).name
			if not is_water(n_name) and n_name ~= "air" then
				near_shore = true; break
			end
		end

		if not near_shore then
			minetest.chat_send_player(placer:get_player_name(), "Must be planted near a shore!")
			return itemstack
		end

		local top_pos = {x = base_pos.x, y = base_pos.y + 2, z = base_pos.z}
		if is_water(minetest.get_node(water_pos).name) and minetest.get_node(top_pos).name == "air" then
			minetest.set_node(base_pos, { name = "cw_core:sand_with_cattails", param2 = 16 })
			minetest.set_node(top_pos, { name = "cw_core:cattail_top" })
			if not minetest.settings:get_bool("creative_mode") then itemstack:take_item() end
		end
		return itemstack
	end,
})