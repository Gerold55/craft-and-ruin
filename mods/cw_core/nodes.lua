-- Cube_World: cw_core/nodes.lua
-- All node registrations live here. Requires cw_core/biome_tint.lua.

local modname = core.get_current_modname()
local S = (core.get_translator and core.get_translator(modname)) or function(s) return s end

-- =========================
-- Simple sound helpers
-- =========================
local function node_sound_dirt()
  return {
    footstep = {name="default_dirt_footstep", gain=0.4},
    dig      = {name="default_dig_crumbly",   gain=0.6},
    dug      = {name="default_dug_node",      gain=0.6},
    place    = {name="default_place_node",    gain=1.0},
  }
end

local function node_sound_wood()
  return {
    footstep = {name="default_wood_footstep", gain=0.4},
    dig      = {name="default_dig_choppy",    gain=0.6},
    dug      = {name="default_dug_node",      gain=0.6},
    place    = {name="default_place_node",    gain=1.0},
  }
end

local function node_sound_stone()
  return {
    footstep = {name="default_stone_footstep", gain=0.4},
    dig      = {name="default_dig_cracky",     gain=0.6},
    dug      = {name="default_dug_node",       gain=0.6},
    place    = {name="default_place_node",     gain=1.0},
  }
end

local function node_sound_leaves()
  return {
    footstep = {name="default_grass_footstep", gain=0.45},
    dig      = {name="default_dig_snappy",     gain=0.3},
    dug      = {name="default_dug_node",       gain=0.3},
    place    = {name="default_place_node",     gain=1.0},
  }
end

--local function jitter_idx(base, lo, hi)
--	local j = math.random(-1, 1)
--	local v = base + j
--	if v < lo then v = lo elseif v > hi then v = hi end
--	return v
--end

-- Public table for cross-mod helpers
cw_core = rawget(_G, "cw_core") or {}

-- Bring in biome tint helpers (SPECS, clamp/preferred index)
local biome_mod = dofile(core.get_modpath("cw_core").."/biome_tint.lua")
local biome_tint = biome_mod and biome_mod.biome_tint or cw_core.biome_tint

-- small utils
local function _clamp(a, lo, hi) if a < lo then return lo elseif a > hi then return hi else return a end end

-- =========================
-- Core terrain nodes
-- =========================

core.register_node("cw_core:bedrock", {
  description = S("Bedrock"),
  tiles = {"cw_bedrock.png"},
  is_ground_content = true,
  sounds = node_sound_stone(),
})

core.register_node("cw_core:stone", {
  description = S("Stone"),
  tiles = {"cw_stone.png"},
  drop = "cw_core:cobble",
  is_ground_content = true,
  groups = {cracky=3, stone=1},
  sounds = node_sound_stone(),
})

core.register_node("cw_core:mountain_grass", {
  description = S("Stone"),
  tiles = {
    "cw_stone.png",
    "cw_stone.png",
    "cw_stone.png^cw_grass_side_plains_overlay.png",
},
  drop = "cw_core:cobble",
  is_ground_content = true,
  groups = {cracky=3, stone=1},
  sounds = node_sound_stone(),
})

core.register_node("cw_core:cobble", {
  description = S("Cobblestone"),
  tiles = {"cw_cobblestone.png"},
  is_ground_content = true,
  groups = {cracky=3, stone=1},
  sounds = node_sound_stone(),
})

core.register_node("cw_core:snow_block", {
  description = S("Snow"),
  tiles = {"cw_snow.png"},
  is_ground_content = true,
  groups = {crumbly=2, soil=1},
  sounds = node_sound_dirt(),
})

-- ============================================================================
-- Snow Layer (thin snow)
-- ============================================================================

minetest.register_node("cw_core:snow_layer", {
    description = "Snow Layer",
    drawtype = "nodebox",
    tiles = {"cw_core_snow.png"},
    paramtype = "light",
    buildable_to = true,
    walkable = false,
    floodable = true,
    groups = {
        crumbly = 3,
        falling_node = 1,
        snowy = 1,
        dig_immediate = 3,
        melts = 1,
    },
    node_box = {
        type = "fixed",
        fixed = {
            -- 1/16th height layer (0.0625)
            {-0.5, -0.5, -0.5, 0.5, -0.4375, 0.5},
        },
    },
    selection_box = {
        type = "fixed",
        fixed = {
            {-0.5, -0.5, -0.5, 0.5, -0.4375, 0.5},
        },
    },
})

-- ============================================================================
-- Minecraft‑style 8‑layer Snow System
-- ============================================================================

local snow_text = "cw_core_snow.png"

local function layer_box(n)
    -- n = 1..8 → height = n/8
    local h = (n / 8) - 0.5
    return {
        type = "fixed",
        fixed = {
            {-0.5, -0.5, -0.5, 0.5, h, 0.5}
        }
    }
end

for i = 1, 8 do
    minetest.register_node("cw_core:snow_layer_" .. i, {
        description = "Snow Layer (" .. i .. "/8)",
        drawtype = "nodebox",
        tiles = {snow_text},
        paramtype = "light",
        buildable_to = true,
        walkable = false,
        floodable = true,
        groups = {
            crumbly = 3,
            falling_node = 1,
            snowy = 1,
            dig_immediate = 3,
            melts = 1,
            snow_layer = i,
        },
        node_box = layer_box(i),
        selection_box = layer_box(i),
    })
end

-- ============================================================================
-- Snow Layer Stacking Logic (Minecraft behavior)
-- ============================================================================

minetest.register_on_placenode(function(pos, newnode)
    local name = newnode.name

    if not name:find("cw_core:snow_layer_") then return end

    local below = {x=pos.x, y=pos.y-1, z=pos.z}
    local bn = minetest.get_node(below).name

    if bn:find("cw_core:snow_layer_") then
        local n = tonumber(bn:match("snow_layer_(%d+)"))
        if n and n < 8 then
            minetest.set_node(below, {name = "cw_core:snow_layer_" .. (n + 1)})
            minetest.remove_node(pos)
        elseif n == 8 then
            minetest.set_node(below, {name = "cw_core:snow_block"})
            minetest.remove_node(pos)
        end
    end
end)

core.register_node("cw_core:dirt", {
  description = S("Dirt"),
  tiles = {"cw_dirt.png"},
  is_ground_content = true,
  groups = {crumbly=2, soil=1},
  sounds = node_sound_dirt(),
})

core.register_node("cw_core:dirt_coarse", {
  description = S("Coarse Dirt"),
  tiles = {"cw_coarse_dry.png.png"},
  is_ground_content = true,
  groups = {crumbly=2, soil=1},
  sounds = node_sound_dirt(),
})

core.register_node("cw_core:podzol", {
  description = S("Podzol"),
  tiles = {
    "ws_forest_litter.png",
    "cw_dirt.png",
    { name = "cw_dirt.png^(ws_forest_litter_side.png)", align_style = "world" },
  },
  is_ground_content = true,
  groups = {crumbly=2, soil=1},
  sounds = node_sound_dirt(),
})

core.register_node("cw_core:mud", {
  description = S("Mud"),
  tiles = {"cw_mud.png"},
  is_ground_content = true,
  groups = {crumbly=2, soil=1},
  sounds = node_sound_dirt(),
})

-- (Neutral placeholder if mapgen places it directly, but our palette variant below replaces behavior)
core.register_node("cw_core:grass_block_neutral", {
  description = S("Grass Block (Neutral)"),
  tiles = {
    "cw_grass_top.png",
    "cw_dirt.png",
    { name = "cw_dirt.png^(cw_grass_side_overlay.png)", align_style = "world" },
  },
  is_ground_content = true,
  groups = {crumbly=2, soil=1, not_in_creative_inventory=1},
  drop = "cw_core:dirt",
  sounds = node_sound_dirt(),
})

-- =========================
-- Ores & Associates
-- =========================

core.register_node("cw_core:ore_coal", {
	description = S("Coal Ore"),
	tiles = {"coal_ore.png"},
	groups = {cracky = 3},
	drop = "cw_core:lump_coal",
	sounds = default and default.node_sound_wood_defaults() or node_sound_wood(),
})

core.register_node("cw_core:coalblock", {
	description = S("Coal Block"),
	tiles = {"coal_block.png"},
	is_ground_content = false,
	groups = {cracky = 3},
	sounds = default and default.node_sound_wood_defaults() or node_sound_wood(),
})

core.register_craftitem("cw_core:lump_coal", {
	description = S("Coal"),
	inventory_image = "coal.png",
	groups = {coal = 1, flammable = 1}
})

core.register_node("cw_core:ore_iron", {
	description = S("Iron Ore"),
	tiles = {"iron_ore.png"},
	groups = {cracky = 3},
	drop = "cw_core:lump_iron",
	sounds = default and default.node_sound_wood_defaults() or node_sound_wood(),
})

core.register_craftitem("cw_core:lump_iron", {
	description = S("Iron Lump"),
	inventory_image = "iron.png",
	groups = {iron = 1}
})

core.register_craftitem("cw_core:nugget_iron", {
	description = S("Iron Nugget"),
	inventory_image = "iron_nugget.png",
	groups = {iron = 1}
})

core.register_node("cw_core:ore_copper", {
	description = S("Copper Ore"),
	tiles = {"copper_ore.png"},
	groups = {cracky = 3},
	drop = "cw_core:lump_copper",
	sounds = default and default.node_sound_wood_defaults() or node_sound_wood(),
})

core.register_node("cw_core:copper_block", {
	description = S("Copper Block"),
	tiles = {"copper_block.png"},
	is_ground_content = false,
	groups = {cracky = 3},
	sounds = default and default.node_sound_wood_defaults() or node_sound_wood(),
})

core.register_craftitem("cw_core:lump_copper", {
	description = S("Copper"),
	inventory_image = "copper.png",
	groups = {coal = 1, flammable = 1}
})

core.register_node("cw_core:ore_gold", {
	description = S("Gold Ore"),
	tiles = {"gold_ore.png"},
	groups = {cracky = 3},
	drop = "cw_core:lump_gold",
	sounds = default and default.node_sound_wood_defaults() or node_sound_wood(),
})

core.register_node("cw_core:gold_block", {
	description = S("Gold Block"),
	tiles = {"gold_block.png"},
	is_ground_content = false,
	groups = {cracky = 3},
	sounds = default and default.node_sound_wood_defaults() or node_sound_wood(),
})

core.register_craftitem("cw_core:lump_gold", {
	description = S("Gold"),
	inventory_image = "gold.png",
	groups = {gold = 1}
})

core.register_craftitem("cw_core:nugget_gold", {
	description = S("Gold Nugget"),
	inventory_image = "gold_nugget.png",
	groups = {gold = 1}
})

core.register_node("cw_core:ore_emerald", {
	description = S("Emerald Ore"),
	tiles = {"emerald_ore.png"},
	groups = {cracky = 3},
	drop = "cw_core:emerald",
	sounds = default and default.node_sound_wood_defaults() or node_sound_wood(),
})

core.register_craftitem("cw_core:emerald", {
	description = S("Emerald"),
	inventory_image = "emerald.png",
	groups = {gold = 1}
})

core.register_node("cw_core:emerald_block", {
	description = S("Emerald Block"),
	tiles = {"emerald_block.png"},
	is_ground_content = false,
	groups = {cracky = 3},
	sounds = default and default.node_sound_wood_defaults() or node_sound_wood(),
})

-- =========================
-- Wood & foliage
-- =========================

core.register_node("cw_core:log_oak", {
  description = S("Oak Log"),
  tiles = {"cw_oak_log_top.png","cw_oak_log_top.png","cw_oak_log.png"},
  paramtype2 = "facedir",
  groups = {tree=1, choppy=2, oddly_breakable_by_hand=1, flammable=2},
  sounds = default and default.node_sound_wood_defaults() or node_sound_wood(),
  on_place = core.rotate_node
})

core.register_node("cw_core:planks_oak", {
  description = S("Oak Planks"),
  tiles = {"oak_planks.png"},
  paramtype2 = "facedir",
  groups = {wood=1, choppy=2, oddly_breakable_by_hand=1, flammable=2},
  sounds = default and default.node_sound_wood_defaults() or node_sound_wood(),
})

core.register_node("cw_core:log_birch", {
  description = S("Birch Log"),
  tiles = {"cw_birch_log_top.png","cw_birch_log_top.png","cw_birch_log.png"},
  paramtype2 = "facedir",
  groups = {tree=1, choppy=2, oddly_breakable_by_hand=1, flammable=2},
  sounds = default and default.node_sound_wood_defaults() or node_sound_wood(),
  on_place = core.rotate_node
})

core.register_node("cw_core:planks_birch", {
  description = S("Birch Planks"),
  tiles = {"cw_birch_planks.png"},
  paramtype2 = "facedir",
  groups = {wood=1, choppy=2, oddly_breakable_by_hand=1, flammable=2},
  sounds = default and default.node_sound_wood_defaults() or node_sound_wood(),
})

core.register_node("cw_core:log_spruce", {
  description = S("Spruce Log"),
  tiles = {"cw_spruce_log_top.png","cw_spruce_log_top.png","cw_spruce_log.png"},
  paramtype2 = "facedir",
  groups = {tree=1, choppy=2, oddly_breakable_by_hand=1, flammable=2},
  sounds = default and default.node_sound_wood_defaults() or node_sound_wood(),
  on_place = core.rotate_node
})

core.register_node("cw_core:planks_spruce", {
  description = S("Spruce Planks"),
  tiles = {"cw_spruce_planks.png"},
  paramtype2 = "facedir",
  groups = {wood=1, choppy=2, oddly_breakable_by_hand=1, flammable=2},
  sounds = default and default.node_sound_wood_defaults() or node_sound_wood(),
})

core.register_node("cw_core:log_jungle", {
  description = S("Jungle Log"),
  tiles = {"cw_jungle_log_top.png","cw_jungle_log_top.png","cw_jungle_log.png"},
  paramtype2 = "facedir",
  groups = {tree=1, choppy=2, oddly_breakable_by_hand=1, flammable=2},
  sounds = default and default.node_sound_wood_defaults() or node_sound_wood(),
  on_place = core.rotate_node
})

core.register_node("cw_core:planks_jungle", {
  description = S("Jungle Planks"),
  tiles = {"cw_jungle_planks.png"},
  paramtype2 = "facedir",
  groups = {wood=1, choppy=2, oddly_breakable_by_hand=1, flammable=2},
  sounds = default and default.node_sound_wood_defaults() or node_sound_wood(),
})

core.register_node("cw_core:log_cherry", {
  description = S("Cherry Log"),
  tiles = {"cherry_log_top.png","cherry_log_top.png","cherry_log.png"},
  paramtype2 = "facedir",
  groups = {tree=1, choppy=2, oddly_breakable_by_hand=1, flammable=2},
  sounds = default and default.node_sound_wood_defaults() or node_sound_wood(),
  on_place = core.rotate_node
})

core.register_node("cw_core:planks_cherry", {
  description = S("Cherry Planks"),
  tiles = {"cherry_planks.png"},
  paramtype2 = "facedir",
  groups = {wood=1, choppy=2, oddly_breakable_by_hand=1, flammable=2},
  sounds = default and default.node_sound_wood_defaults() or node_sound_wood(),
})

core.register_node("cw_core:leaves_cherry", {
    description = "Cherry Leaves",
    drawtype = "allfaces_optional",
    waving = 1,
    tiles = { "cherry_leaves.png" }, -- Use your final green texture here
    use_texture_alpha = "clip",
    paramtype = "light",
    -- Removed palette and color logic
    groups = { snappy=3, leafdecay=1, flammable=2, leaves=1 },
    drop = {
        max_items = 1,
        items = {
            { items = { "cw_core:cherry_sapling" }, rarity = 20 },
        }
    },
    -- Simplified sound check
    sounds = (default and default.node_sound_leaves_defaults and default.node_sound_leaves_defaults()) or nil,
})

minetest.register_node("cw_core:pink_petals", {
	description = "Pink Petals",
	drawtype = "nodebox",
	tiles = {"pink_petals.png"}, -- Ensure this image has transparency
	inventory_image = "pink_petals.png",
	paramtype = "light",
	sunlight_propagates = true,
	use_texture_alpha = "clip",
	walkable = false,
	buildable_to = true,
	groups = {snappy = 3, attached_node = 1},
	node_box = {
		type = "fixed",
		-- This is 0.001 units thick, sitting right on the grass
		fixed = {-0.5, -0.5, -0.5, 0.5, -0.499, 0.5}, 
	},
	selection_box = {
		type = "fixed",
		fixed = {-0.5, -0.5, -0.5, 0.5, -0.4, 0.5},
	},
})

minetest.register_abm({
	label = "Cherry Sapling Growth",
	nodenames = {"cw_core:cherry_sapling"},
	interval = 60,
	chance = 20,
	action = function(pos)
		local light = minetest.get_node_light(pos)
		if not light or light < 13 then return end

		local below = minetest.get_node({x=pos.x, y=pos.y-1, z=pos.z}).name
		if minetest.get_item_group(below, "soil") == 0 then return end

		minetest.remove_node(pos)
		craft_ruin_generate_cherry_tree(pos)
	end
})

--========================================================
-- Leaves (palette-tinted, biome uniform)
--  - paramtype2="color"
--  - Palettes are 1x16 VERTICAL
--========================================================

local FOLIAGE_PALETTE = "cw_foliage_palette.png" -- 1x16 vertical

-- Fallback humidity→palette (only used if biome has no preferred index)
local settings = core.settings
local F_MIN   = tonumber(settings:get("cw_foliage_palette_min_idx")) or 3
local F_MAX   = tonumber(settings:get("cw_foliage_palette_max_idx")) or 12
local F_GAMMA = tonumber(settings:get("cw_foliage_palette_gamma"))  or 0.9
local FLIP_FOLIAGE_PALETTE = false
do
  local m = math.floor((F_MIN or 0)+0.5); local M = math.floor((F_MAX or 15)+0.5)
  F_MIN, F_MAX = _clamp(m,0,15), _clamp(M,0,15)
  if F_MAX < F_MIN then F_MIN, F_MAX = F_MAX, F_MIN end
  F_GAMMA = _clamp(F_GAMMA, 0.5, 2.0)
end

local function foliage_humidity_to_palette(h)
  h = _clamp(h or 50, 0, 100)
  local t = (h / 100) ^ F_GAMMA
  local idx = F_MIN + t * (F_MAX - F_MIN)
  idx = math.floor(idx + 0.5)
  if FLIP_FOLIAGE_PALETTE then idx = 15 - idx end
  return idx
end
cw_core.foliage_humidity_to_palette = foliage_humidity_to_palette

--local lo =
--	tonumber(core.settings:get("cw_grass_palette_min_idx")) or 4
--  local hi =
--	tonumber(core.settings:get("cw_grass_palette_max_idx")) or 11
--  idx = jitter_idx(idx, lo, hi)

local function humidity_at(pos)
  local ok, data = pcall(core.get_biome_data, pos)
  return (ok and data and data.humidity) or 50
end

local function choose_leaf_index_for_pos(pos)
  local pref = biome_tint and biome_tint.preferred_leaf_index(pos)
  if pref ~= nil then return pref end
  local idx = foliage_humidity_to_palette(humidity_at(pos))
  return biome_tint and biome_tint.clamp_leaf_index(pos, idx) or idx
end

function cw_core.update_leaf_tint(pos, keep_idx)
  local node = core.get_node(pos)
  local def = core.registered_nodes[node.name]
  if not def or def.paramtype2 ~= "color" or not def.palette then return end
  local idx = keep_idx or choose_leaf_index_for_pos(pos)
  if (node.param2 or 0) ~= idx then
    node.param2 = idx
    core.swap_node(pos, node)
  end
end

core.register_node("cw_core:leaves_oak", {
  description = "Oak Leaves",
  drawtype = "allfaces_optional",
  waving = 1,
  tiles = { "cw_oak_leaves.png" }, -- neutral gray texture recommended
  use_texture_alpha = "clip",
  paramtype  = "light",
  paramtype2 = "color",
  palette    = FOLIAGE_PALETTE,
  palette_index = math.floor((F_MIN + F_MAX) / 2),
  color         = "#8EB971",
  groups = { snappy=3, leafdecay=1, flammable=2, leaves=1 },
  drop = {
    max_items = 1,
    items = {
      { items = { "cw_core:oak_sapling" }, rarity = 20 },
    }
  },
  sounds = (default and default.node_sound_leaves_defaults and default.node_sound_leaves_defaults()) or node_sound_leaves(),
  after_place_node = function(pos)
    cw_core.update_leaf_tint(pos)
  end,
})

core.register_node("cw_core:leaves_birch", {
  description = "Birch Leaves",
  drawtype = "allfaces_optional",
  waving = 1,
  tiles = { "cw_birch_leaves.png" }, -- neutral gray texture recommended
  use_texture_alpha = "clip",
  paramtype  = "light",
  paramtype2 = "color",
  palette    = FOLIAGE_PALETTE,
  palette_index = math.floor((F_MIN + F_MAX) / 2),
  color         = "#8EB971",
  groups = { snappy=3, leafdecay=1, flammable=2, leaves=1 },
  drop = {
    max_items = 1,
    items = {
      { items = { "cw_core:birch_sapling" }, rarity = 20 },
    }
  },
  sounds = (default and default.node_sound_leaves_defaults and default.node_sound_leaves_defaults()) or node_sound_leaves(),
  after_place_node = function(pos)
    cw_core.update_leaf_tint(pos)
  end,
})

core.register_node("cw_core:leaves_spruce", {
  description = "Spruce Leaves",
  drawtype = "allfaces_optional",
  waving = 1,
  tiles = { "cw_spruce_leaves.png" }, -- neutral gray texture recommended
  use_texture_alpha = "clip",
  paramtype  = "light",
  paramtype2 = "color",
  palette    = FOLIAGE_PALETTE,
  palette_index = math.floor((F_MIN + F_MAX) / 2),
  color         = "#8EB971",
  groups = { snappy=3, leafdecay=1, flammable=2, leaves=1 },
  drop = {
    max_items = 1,
    items = {
      { items = { "cw_core:spruce_sapling" }, rarity = 20 },
    }
  },
  sounds = (default and default.node_sound_leaves_defaults and default.node_sound_leaves_defaults()) or node_sound_leaves(),
  after_place_node = function(pos)
    cw_core.update_leaf_tint(pos)
  end,
})

core.register_node("cw_core:leaves_jungle", {
  description = "Jungle Leaves",
  drawtype = "allfaces_optional",
  waving = 1,
  tiles = { "cw_jungle_leaves.png" }, -- neutral gray texture recommended
  use_texture_alpha = "clip",
  paramtype  = "light",
  paramtype2 = "color",
  palette    = FOLIAGE_PALETTE,
  palette_index = math.floor((F_MIN + F_MAX) / 2),
  color         = "#8EB971",
  groups = { snappy=3, leafdecay=1, flammable=2, leaves=1 },
  drop = {
    max_items = 1,
    items = {
      { items = { "cw_core:jungle_sapling" }, rarity = 20 },
    }
  },
  sounds = (default and default.node_sound_leaves_defaults and default.node_sound_leaves_defaults()) or node_sound_leaves(),
  after_place_node = function(pos)
    cw_core.update_leaf_tint(pos)
  end,
})

-- ========= One-time LBM to normalize legacy leaves (fixes chunk border mismatch) =========
core.register_lbm({
  name = "cw_core:tint_leaves_once",
  nodenames = {"group:leaves"},
  run_at_every_load = false,
  action = function(pos, node)
    local def = core.registered_nodes[node.name]
    if not def or not (def.groups and def.groups.leaves) then return end
    if def.paramtype2 ~= "color" or not def.palette then return end
    cw_core.update_leaf_tint(pos)
  end,
})

-- ========= Dev command: /retint_leaves [radius] =========
core.register_chatcommand("retint_leaves", {
  params = "[radius]",
  description = "Force-retint palette leaves in a radius (default 96).",
  privs = {server = true},
  func = function(name, param)
    local radius = tonumber(param) or 96
    local player = core.get_player_by_name(name)
    if not player then return false, "No player." end
    local p = vector.round(player:get_pos())
    local minp = vector.subtract(p, radius)
    local maxp = vector.add(p, radius)

    local vm = core.get_voxel_manip()
    local emin, emax = vm:read_from_map(minp, maxp)
    local area = VoxelArea:new({MinEdge=emin, MaxEdge=emax})
    local data = vm:get_data()
    local p2   = vm:get_param2_data()

    -- Build a set of palette-leaf content IDs
    local LEAF_CID = {}
    for name2, def in pairs(core.registered_nodes) do
      if def and def.groups and def.groups.leaves
         and def.paramtype2 == "color" and def.palette then
        LEAF_CID[core.get_content_id(name2)] = true
      end
    end

    local changed = false
    for z=minp.z, maxp.z do
      for y=minp.y, maxp.y do
        for x=minp.x, maxp.x do
          local vi = area:index(x,y,z)
          local id = data[vi]
          if LEAF_CID[id] then
            local pref = biome_tint and biome_tint.preferred_leaf_index({x=x,y=y,z=z})
            local idx
            if pref ~= nil then
              idx = pref
            else
              local ok, bd = pcall(core.get_biome_data, {x=x,y=y,z=z})
              local h = (ok and bd and bd.humidity) or 50
              local base = foliage_humidity_to_palette(h)
              idx = (biome_tint and biome_tint.clamp_leaf_index({x=x,y=y,z=z}, base)) or base
            end
            if p2[vi] ~= idx then p2[vi] = idx; changed = true end
          end
        end
      end
    end

    if changed then
      vm:set_param2_data(p2)
      vm:write_to_map()
    end
    return true, ("Retinted leaves in radius %d."):format(radius)
  end
})

-- SAPLING (simple placeholder that calls cw_core.grow_oak if you provide it)
core.register_node("cw_core:oak_sapling", {
  description = S("Oak Sapling"),
  drawtype = "plantlike",
  tiles = {"cw_oak_sapling.png"},
  inventory_image = "cw_oak_sapling.png",
  wield_image = "cw_oak_sapling.png",
  paramtype = "light",
  sunlight_propagates = true,
  walkable = false,
  buildable_to = true,
  groups = {snappy=2, dig_immediate=3, flammable=2, attached_node=1, sapling=1},
  selection_box = {type="fixed", fixed={-0.2,-0.5,-0.2, 0.2,0.35,0.2}},
  on_construct = function(pos)
    core.get_node_timer(pos):start(math.random(60, 120))
  end,
  on_timer = function(pos)
    local under = core.get_node({x=pos.x, y=pos.y-1, z=pos.z}).name
    if under ~= "cw_core:dirt" and under ~= "cw_core:grass_block" and under ~= "cw_core:sand" then
      return true -- retry later
    end
    if cw_core and cw_core.grow_oak then
      cw_core.grow_oak(pos, nil)
      return false
    end
    return true
  end,
})

core.register_node("cw_core:birch_sapling", {
  description = S("Birch Sapling"),
  drawtype = "plantlike",
  tiles = {"cw_birch_sapling.png"},
  inventory_image = "cw_birch_sapling.png",
  wield_image = "cw_birch_sapling.png",
  paramtype = "light",
  sunlight_propagates = true,
  walkable = false,
  buildable_to = true,
  groups = {snappy=2, dig_immediate=3, flammable=2, attached_node=1, sapling=1},
  selection_box = {type="fixed", fixed={-0.2,-0.5,-0.2, 0.2,0.35,0.2}},
  on_construct = function(pos)
    core.get_node_timer(pos):start(math.random(60, 120))
  end,
  on_timer = function(pos)
    local under = core.get_node({x=pos.x, y=pos.y-1, z=pos.z}).name
    if under ~= "cw_core:dirt" and under ~= "cw_core:grass_block" and under ~= "cw_core:sand" then
      return true -- retry later
    end
    if cw_core and cw_core.grow_oak then
      cw_core.grow_oak(pos, nil)
      return false
    end
    return true
  end,
})

core.register_node("cw_core:cherry_sapling", {
  description = S("Cherry Sapling"),
  drawtype = "plantlike",
  tiles = {"cw_cherry_sapling.png"},
  inventory_image = "cw_cherry_sapling.png",
  wield_image = "cw_cherry_sapling.png",
  paramtype = "light",
  sunlight_propagates = true,
  walkable = false,
  buildable_to = true,
  groups = {snappy=2, dig_immediate=3, flammable=2, attached_node=1, sapling=1},
  selection_box = {type="fixed", fixed={-0.2,-0.5,-0.2, 0.2,0.35,0.2}},
  on_construct = function(pos)
    core.get_node_timer(pos):start(math.random(60, 120))
  end,
  on_timer = function(pos)
    local under = core.get_node({x=pos.x, y=pos.y-1, z=pos.z}).name
    if under ~= "cw_core:dirt" and under ~= "cw_core:grass_block" and under ~= "cw_core:sand" then
      return true -- retry later
    end
    if cw_core and cw_core.grow_oak then
      cw_core.grow_oak(pos, nil)
      return false
    end
    return true
  end,
})

--========================================================
-- Palette GRASS (paramtype2="color") + SNOW variant
--  - TOP + SIDES tinted (palette)
--  - Dirt base never tinted; overlays carry tint
--  - Decay under solid cover (except snow)
--  - Spreads to exposed dirt
--  - Creative “plains” item that swaps to palette node on place
--  - Plains biome uses uniform preferred index (from biome_tint: 2)
--========================================================

local GRASS_PALETTE = "cw_grass_palette.png"  -- 1x16 vertical
local DEFAULT_INV_INDEX = 9
local DEFAULT_INV_COLOR = "#8EB971"
local DECAY_SECONDS_MIN = 6
local DECAY_SECONDS_MAX = 10

-- Humidity→palette mapping (fallback when biome has no preferred index)
local PAL_MIN  = tonumber(settings:get("cw_grass_palette_min_idx")) or 4
local PAL_MAX  = tonumber(settings:get("cw_grass_palette_max_idx")) or 11
local PAL_GAMMA= tonumber(settings:get("cw_grass_palette_gamma"))  or 0.9
local FLIP_GRASS_PALETTE = false
do
  local m = math.floor((PAL_MIN or 0)+0.5); local M = math.floor((PAL_MAX or 15)+0.5)
  PAL_MIN, PAL_MAX = _clamp(m,0,15), _clamp(M,0,15)
  if PAL_MAX < PAL_MIN then PAL_MIN, PAL_MAX = PAL_MAX, PAL_MIN end
  PAL_GAMMA = _clamp(PAL_GAMMA, 0.5, 2.0)
end

local function humidity_to_palette(h)
  h = _clamp(h or 50, 0, 100)
  local t = (h / 100) ^ PAL_GAMMA
  local idx = PAL_MIN + t * (PAL_MAX - PAL_MIN)
  idx = math.floor(idx + 0.5)
  if FLIP_GRASS_PALETTE then idx = 15 - idx end
  return idx
end
cw_core.humidity_to_palette = humidity_to_palette

local function has_snow_above(pos)
  local up = {x=pos.x, y=pos.y+1, z=pos.z}
  local nn = core.get_node(up).name
  local def = core.registered_nodes[nn]
  return (def and def.groups and def.groups.snow and def.groups.snow > 0) or false
end

local function should_decay_to_dirt(pos)
  local up = {x=pos.x, y=pos.y+1, z=pos.z}
  local upnode = core.get_node(up)
  local updef  = core.registered_nodes[upnode.name]
  if (not updef) or (not updef.walkable) or updef.buildable_to then return false end
  if updef.groups and updef.groups.snow and updef.groups.snow > 0 then return false end
  return true
end

local function choose_grass_index_for_pos(pos)
  local pref = biome_tint and biome_tint.preferred_grass_index(pos)
  if pref ~= nil then return pref end
  local idx = humidity_to_palette(humidity_at(pos))
  return biome_tint and biome_tint.clamp_grass_index(pos, idx) or idx
end

-- API for other mods
function cw_core.get_grass_node_for_humidity(h, _, snow)
  local name = snow and "cw_core:grass_block_snow" or "cw_core:grass_block"
  local p2   = humidity_to_palette(h)
  return name, p2
end

function cw_core.pick_grass_variant_by_humidity(_)
  return "cw_core:grass_block"
end

function cw_core.update_grass_state(pos, force_snow, keep_idx)
  local node = core.get_node(pos)
  local snow = (force_snow == true) or has_snow_above(pos)
  local target = snow and "cw_core:grass_block_snow" or "cw_core:grass_block"
  local idx = keep_idx or choose_grass_index_for_pos(pos)
  if node.name ~= target or (node.param2 or 0) ~= idx then
    core.swap_node(pos, { name = target, param2 = idx })
  end
  
--  local lo =
--	tonumber(core.settings:get("cw_grass_palette_min_idx")) or 4
--  local hi =
--	tonumber(core.settings:get("cw_grass_palette_max_idx")) or 11
--  idx = jitter_idx(idx, lo, hi)
  
  if target == "cw_core:grass_block" then
    if should_decay_to_dirt(pos) then
      core.get_node_timer(pos):start(math.random(DECAY_SECONDS_MIN, DECAY_SECONDS_MAX))
    else
      core.get_node_timer(pos):stop()
    end
  end
end

-- Actual palette grass (uses paramtype2=color + overlay tint)
core.register_node("cw_core:grass_block", {
  description = "Grass Block",
  tiles = {
    "cw_grass_top.png",                            -- tinted
    { name="cw_dirt.png", color="white" },         -- not tinted
    { name="cw_dirt.png", color="white" },         -- not tinted
  },
  overlay_tiles = {
    "", "",
    { name="cw_grass_side_overlay.png", tileable_vertical=false }, -- tinted overlay
  },

  paramtype2    = "color",
  palette       = GRASS_PALETTE,
  palette_index = DEFAULT_INV_INDEX,
  color         = DEFAULT_INV_COLOR,
  wield_scale   = { x=1.05, y=1.05, z=1.05 },

  groups = { crumbly=2, soil=1, grass_block=1, spreading_dirt_type=1, not_in_creative_inventory=1 },
  drop   = "cw_core:dirt",
  sounds = node_sound_dirt(),

  after_place_node = function(pos)
    cw_core.update_grass_state(pos, false) -- uniform or fallback chosen inside
  end,

  on_construct        = function(pos) cw_core.update_grass_state(pos, false) end,
  on_neighbor_changed = function(pos) cw_core.update_grass_state(pos) end,

  on_timer = function(pos)
    if should_decay_to_dirt(pos) then
      core.swap_node(pos, { name = "cw_core:dirt" })
      return false
    end
    return true
  end,
})

-- Creative item (pretty icon) that swaps to palette node on place
core.register_node("cw_core:grass_block_plains", {
  description = "Grass Block",
  tiles = {
    "cw_grass_top_plains.png",
    { name="cw_dirt.png", color="white" },
    { name="cw_dirt.png", color="white" },
  },
  overlay_tiles = { "", "", { name="cw_grass_side_plains_overlay.png", tileable_vertical=false } },
  paramtype2    = "color",
  palette       = GRASS_PALETTE,
  palette_index = DEFAULT_INV_INDEX,
  color         = DEFAULT_INV_COLOR,
  wield_scale   = { x=1.05, y=1.05, z=1.05 },
  groups = { crumbly=2, soil=1, grass_block=1 },
  drop   = "cw_core:dirt",

  after_place_node = function(pos)
    core.swap_node(pos, { name = "cw_core:grass_block", param2 = 0 })
    cw_core.update_grass_state(pos, false) -- snap to biome-preferred immediately
  end,
})

-- Snowed grass
core.register_node("cw_core:grass_block_snow", {
  description = "Grass Block (Snowed)",
  tiles = {
    "cw_grass_top_snow.png",
    { name="cw_dirt.png", color="white" },
    { name="cw_dirt.png", color="white" },
  },
  overlay_tiles = {
    "", "",
    { name="cw_grass_side_snow_overlay.png", color="white", tileable_vertical=false },
  },
  paramtype2    = "color",
  palette       = GRASS_PALETTE,
  palette_index = DEFAULT_INV_INDEX,
  color         = DEFAULT_INV_COLOR,
  groups = { crumbly=2, soil=1, grass_block=1, not_in_creative_inventory=1 },
  drop   = "cw_core:dirt",
  sounds = node_sound_dirt(),
  on_construct        = function(pos) cw_core.update_grass_state(pos, true) end,
  on_neighbor_changed = function(pos) cw_core.update_grass_state(pos) end,
})

-- One-time LBM to retint existing maps
core.register_lbm({
  name = "cw_core:tint_grass_once",
  nodenames = { "cw_core:grass_block", "cw_core:grass_block_snow" },
  run_at_every_load = false,
  action = function(pos, node)
    cw_core.update_grass_state(pos, node.name == "cw_core:grass_block_snow")
  end,
})

-- Legacy aliases (old g01..g16 series)
for i = 1, 16 do
  core.register_alias("cw_core:grass_block_g"..("%02d"):format(i), "cw_core:grass_block")
end

-- Grass spread ABM
core.register_abm({
  label = "cw_core:grass_spread",
  nodenames = { "cw_core:dirt" },
  neighbors = { "cw_core:grass_block", "cw_core:grass_block_snow" },
  interval = 7,
  chance   = 25,
  action = function(pos)
    local above = {x=pos.x, y=pos.y+1, z=pos.z}
    local above_def = core.registered_nodes[core.get_node(above).name]
    if above_def and above_def.walkable and not above_def.buildable_to then return end
    local light = core.get_node_light(above, 0.5) or 0
    if light < 9 then return end
    core.swap_node(pos, { name = "cw_core:grass_block", param2 = 0 })
    cw_core.update_grass_state(pos)
  end
})

-- --- SAND -------------------------------------------------------------------
-- Both look identical, both drop the same item
local sand_def = {
    description = "Sand",
    tiles = {"cw_sand.png"},
    groups = {crumbly = 3, sand = 1, falling_node = 1},
    drop = "cw_core:sand",
    sounds = {footstep = {name = "default_grass_footstep", gain = 0.25}}
}

-- 1. Register the "Master" Sand (This one shows in inventory)
core.register_node("cw_core:sand", sand_def)

-- 2. Create a modified version for the variants
-- We use core.copy to avoid changing the original table
local hidden_sand = table.copy(sand_def)
hidden_sand.groups.not_in_creative_inventory = 1

-- 3. Register the variants using the hidden definition
core.register_node("cw_core:beach_sand", hidden_sand)
core.register_node("cw_core:desert_sand", hidden_sand)

core.register_node("cw_core:sand_red", {
  description = "Red Sand",
  tiles = {"cw_sand_red.png"},
  is_ground_content = true,
  groups = {crumbly = 3, falling_node = 1, sand = 1},
})

local WATER_PALETTE = "cw_water_palette.png" -- 1x16 vertical

-- --- WATER (STATIC SOURCE; palette-tinted, including inventory) -------------
core.register_node("cw_core:water_source", {
  description = "Water Source",
  drawtype   = "liquid",

  -- IMPORTANT: give the base tiles color="palette" so the item stack is tinted.
  tiles = {{
    name = "cw_water_still.png",
    animation = { type = "vertical_frames", aspect_w = 16, aspect_h = 16, length = 2.0 },
    color = "palette",
  }},

  special_tiles = {
    { name = "cw_water_still.png",
      animation = { type = "vertical_frames", aspect_w = 16, aspect_h = 16, length = 2.0 },
      backface_culling = false, color = "palette" },
    { name = "cw_water_still.png",
      animation = { type = "vertical_frames", aspect_w = 16, aspect_h = 16, length = 2.0 },
      backface_culling = true,  color = "palette" },
    { name = "cw_water_flow.png",
      animation = { type = "vertical_frames", aspect_w = 16, aspect_h = 16, length = 0.8 },
      backface_culling = false, color = "palette" },
    { name = "cw_water_flow.png",
      animation = { type = "vertical_frames", aspect_w = 16, aspect_h = 16, length = 0.8 },
      backface_culling = true,  color = "palette" },
  },

  use_texture_alpha = "blend",   -- keep a single alpha mode
  paramtype  = "light",
  paramtype2 = "color",
  palette    = WATER_PALETTE,

  -- DEFAULT ITEM TINT so inventory/wield are colored out of the box
  palette_index = math.floor((F_MIN + F_MAX) / 2),  -- or pick the one you like
  color         = "#3A6FC8",                        -- harmless default hex

  sunlight_propagates = true,
  walkable = false,
  pointable = false,
  diggable = false,
  buildable_to = true,
  drowning = 1,

  liquidtype = "source",
  liquid_alternative_source  = "cw_core:water_source",
  liquid_alternative_flowing = "cw_core:water_source",
  liquid_viscosity = 1,

  post_effect_color = { a=96, r=30, g=60, b=90 },
  groups = { water=1, liquid=1, puts_out_fire=1 },
})

-- Fallback sounds (reuse your helpers if present)
local function _snd_dirt()
  return (node_sound_dirt and node_sound_dirt())
      or (default and default.node_sound_dirt_defaults and default.node_sound_dirt_defaults())
      or {}
end

local function _snd_stone()
  return (node_sound_stone and node_sound_stone())
      or (default and default.node_sound_stone_defaults and default.node_sound_stone_defaults())
      or {}
end

-- -----------------------
-- GRAVEL
-- -----------------------
core.register_node("cw_core:gravel", {
  description = "Gravel",
  tiles = {"cw_gravel.png"},            -- ↑ add this texture
  is_ground_content = true,

  -- Falls when unsupported
  groups = {
    crumbly = 2,
    falling_node = 1,
    gravel = 1,
  },

  sounds = _snd_stone(),

  -- Keep it simple: drop itself for now
  drop = "cw_core:gravel",
})

-- -----------------------
-- CLAY
-- -----------------------
core.register_node("cw_core:clay", {
  description = "Clay",
  tiles = {"cw_clay.png"},              -- ↑ add this texture
  is_ground_content = true,

  groups = {
    crumbly = 2,
    clay = 1,
  },

  sounds = _snd_dirt(),

  -- Simple drop for now (node itself). If you later add clay balls,
  -- change this to drop items instead.
  drop = "cw_core:clay",
})

-- -------- Desert props (future biome) --------
core.register_node(modname..":cactus", {
  description="Cactus",
  tiles={"cw_cactus_top.png","cw_cactus_top.png","cw_cactus_side.png"},
  paramtype2="facedir",
  groups={snappy=1,choppy=3,oddly_breakable_by_hand=1,flammable=1,cactus=1},
  sounds=node_sound_wood(),
})

-- =========================
-- Mapgen aliases (optional)
-- =========================
core.register_alias("mapgen_stone", "cw_core:stone")
core.register_alias("mapgen_dirt",  "cw_core:dirt")
core.register_alias("mapgen_water", "cw_core:water_source")
