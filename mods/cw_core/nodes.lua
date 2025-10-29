-- Cube_World: cw_core/nodes.lua
-- All node registrations live here. Requires cw_core/biome_tint.lua.

local modname = minetest.get_current_modname()
local S = (minetest.get_translator and minetest.get_translator(modname)) or function(s) return s end

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
local biome_mod = dofile(minetest.get_modpath("cw_core").."/biome_tint.lua")
local biome_tint = biome_mod and biome_mod.biome_tint or cw_core.biome_tint

-- small utils
local function _clamp(a, lo, hi) if a < lo then return lo elseif a > hi then return hi else return a end end

-- =========================
-- Core terrain nodes
-- =========================

minetest.register_node("cw_core:stone", {
  description = S("Stone"),
  tiles = {"cw_stone.png"},
  drop = "cw_core:cobble",
  is_ground_content = true,
  groups = {cracky=3, stone=1},
  sounds = node_sound_stone(),
})

minetest.register_node("cw_core:cobble", {
  description = S("Cobblestone"),
  tiles = {"cw_cobblestone.png"},
  is_ground_content = true,
  groups = {cracky=3, stone=1},
  sounds = node_sound_stone(),
})

minetest.register_node("cw_core:dirt", {
  description = S("Dirt"),
  tiles = {"cw_dirt.png"},
  is_ground_content = true,
  groups = {crumbly=2, soil=1},
  sounds = node_sound_dirt(),
})

minetest.register_node("cw_core:mud", {
  description = S("Mud"),
  tiles = {"cw_mud.png"},
  is_ground_content = true,
  groups = {crumbly=2, soil=1},
  sounds = node_sound_dirt(),
})

-- (Neutral placeholder if mapgen places it directly, but our palette variant below replaces behavior)
minetest.register_node("cw_core:grass_block_neutral", {
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

minetest.register_node("cw_core:ore_coal", {
	description = S("Coal Ore"),
	tiles = {"coal_ore.png"},
	groups = {cracky = 3},
	drop = "cw_core:lump_coal",
	sounds = default and default.node_sound_wood_defaults() or node_sound_wood(),
})

minetest.register_node("cw_core:coalblock", {
	description = S("Coal Block"),
	tiles = {"coal_block.png"},
	is_ground_content = false,
	groups = {cracky = 3},
	sounds = default and default.node_sound_wood_defaults() or node_sound_wood(),
})

minetest.register_craftitem("cw_core:lump_coal", {
	description = S("Coal"),
	inventory_image = "coal.png",
	groups = {coal = 1, flammable = 1}
})

minetest.register_node("cw_core:ore_iron", {
	description = S("Iron Ore"),
	tiles = {"iron_ore.png"},
	groups = {cracky = 3},
	drop = "cw_core:lump_iron",
	sounds = default and default.node_sound_wood_defaults() or node_sound_wood(),
})

minetest.register_craftitem("cw_core:lump_iron", {
	description = S("Iron Lump"),
	inventory_image = "iron.png",
	groups = {iron = 1}
})

minetest.register_craftitem("cw_core:nugget_iron", {
	description = S("Iron Nugget"),
	inventory_image = "iron_nugget.png",
	groups = {iron = 1}
})

minetest.register_node("cw_core:ore_copper", {
	description = S("Copper Ore"),
	tiles = {"copper_ore.png"},
	groups = {cracky = 3},
	drop = "cw_core:lump_copper",
	sounds = default and default.node_sound_wood_defaults() or node_sound_wood(),
})

minetest.register_node("cw_core:copper_block", {
	description = S("Copper Block"),
	tiles = {"copper_block.png"},
	is_ground_content = false,
	groups = {cracky = 3},
	sounds = default and default.node_sound_wood_defaults() or node_sound_wood(),
})

minetest.register_craftitem("cw_core:lump_copper", {
	description = S("Copper"),
	inventory_image = "copper.png",
	groups = {coal = 1, flammable = 1}
})

minetest.register_node("cw_core:ore_gold", {
	description = S("Gold Ore"),
	tiles = {"gold_ore.png"},
	groups = {cracky = 3},
	drop = "cw_core:lump_gold",
	sounds = default and default.node_sound_wood_defaults() or node_sound_wood(),
})

minetest.register_node("cw_core:gold_block", {
	description = S("Gold Block"),
	tiles = {"gold_block.png"},
	is_ground_content = false,
	groups = {cracky = 3},
	sounds = default and default.node_sound_wood_defaults() or node_sound_wood(),
})

minetest.register_craftitem("cw_core:lump_gold", {
	description = S("Gold"),
	inventory_image = "gold.png",
	groups = {gold = 1}
})

minetest.register_craftitem("cw_core:nugget_gold", {
	description = S("Gold Nugget"),
	inventory_image = "gold_nugget.png",
	groups = {gold = 1}
})

-- =========================
-- Wood & foliage
-- =========================

minetest.register_node("cw_core:oak_log", {
  description = S("Oak Log"),
  tiles = {"cw_oak_log_top.png","cw_oak_log_top.png","cw_oak_log.png"},
  paramtype2 = "facedir",
  groups = {tree=1, choppy=2, oddly_breakable_by_hand=1, flammable=2},
  sounds = default and default.node_sound_wood_defaults() or node_sound_wood(),
})

minetest.register_node("cw_core:planks_oak", {
  description = S("Oak Planks"),
  tiles = {"oak_planks.png"},
  paramtype2 = "facedir",
  groups = {wood=1, choppy=2, oddly_breakable_by_hand=1, flammable=2},
  sounds = default and default.node_sound_wood_defaults() or node_sound_wood(),
})

minetest.register_node("cw_core:birch_log", {
  description = S("Birch Log"),
  tiles = {"cw_birch_log_top.png","cw_birch_log_top.png","cw_birch_log.png"},
  paramtype2 = "facedir",
  groups = {tree=1, choppy=2, oddly_breakable_by_hand=1, flammable=2},
  sounds = default and default.node_sound_wood_defaults() or node_sound_wood(),
})

minetest.register_node("cw_core:planks_birch", {
  description = S("Birch Planks"),
  tiles = {"cw_birch_planks.png"},
  paramtype2 = "facedir",
  groups = {wood=1, choppy=2, oddly_breakable_by_hand=1, flammable=2},
  sounds = default and default.node_sound_wood_defaults() or node_sound_wood(),
})

minetest.register_node("cw_core:spruce_log", {
  description = S("Spruce Log"),
  tiles = {"cw_spruce_log_top.png","cw_spruce_log_top.png","cw_spruce_log.png"},
  paramtype2 = "facedir",
  groups = {tree=1, choppy=2, oddly_breakable_by_hand=1, flammable=2},
  sounds = default and default.node_sound_wood_defaults() or node_sound_wood(),
})

minetest.register_node("cw_core:planks_spruce", {
  description = S("Spruce Planks"),
  tiles = {"cw_spruce_planks.png"},
  paramtype2 = "facedir",
  groups = {wood=1, choppy=2, oddly_breakable_by_hand=1, flammable=2},
  sounds = default and default.node_sound_wood_defaults() or node_sound_wood(),
})

--========================================================
-- Leaves (palette-tinted, biome uniform)
--  - paramtype2="color"
--  - Palettes are 1x16 VERTICAL
--========================================================

local FOLIAGE_PALETTE = "cw_foliage_palette.png" -- 1x16 vertical

-- Fallback humidity→palette (only used if biome has no preferred index)
local settings = minetest.settings
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
--	tonumber(minetest.settings:get("cw_grass_palette_min_idx")) or 4
--  local hi =
--	tonumber(minetest.settings:get("cw_grass_palette_max_idx")) or 11
--  idx = jitter_idx(idx, lo, hi)

local function humidity_at(pos)
  local ok, data = pcall(minetest.get_biome_data, pos)
  return (ok and data and data.humidity) or 50
end

local function choose_leaf_index_for_pos(pos)
  local pref = biome_tint and biome_tint.preferred_leaf_index(pos)
  if pref ~= nil then return pref end
  local idx = foliage_humidity_to_palette(humidity_at(pos))
  return biome_tint and biome_tint.clamp_leaf_index(pos, idx) or idx
end

function cw_core.update_leaf_tint(pos, keep_idx)
  local node = minetest.get_node(pos)
  local def = minetest.registered_nodes[node.name]
  if not def or def.paramtype2 ~= "color" or not def.palette then return end
  local idx = keep_idx or choose_leaf_index_for_pos(pos)
  if (node.param2 or 0) ~= idx then
    node.param2 = idx
    minetest.swap_node(pos, node)
  end
end

minetest.register_node("cw_core:oak_leaves", {
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

minetest.register_node("cw_core:birch_leaves", {
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

minetest.register_node("cw_core:spruce_leaves", {
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

-- ========= One-time LBM to normalize legacy leaves (fixes chunk border mismatch) =========
minetest.register_lbm({
  name = "cw_core:tint_leaves_once",
  nodenames = {"group:leaves"},
  run_at_every_load = false,
  action = function(pos, node)
    local def = minetest.registered_nodes[node.name]
    if not def or not (def.groups and def.groups.leaves) then return end
    if def.paramtype2 ~= "color" or not def.palette then return end
    cw_core.update_leaf_tint(pos)
  end,
})

-- ========= Dev command: /retint_leaves [radius] =========
minetest.register_chatcommand("retint_leaves", {
  params = "[radius]",
  description = "Force-retint palette leaves in a radius (default 96).",
  privs = {server = true},
  func = function(name, param)
    local radius = tonumber(param) or 96
    local player = minetest.get_player_by_name(name)
    if not player then return false, "No player." end
    local p = vector.round(player:get_pos())
    local minp = vector.subtract(p, radius)
    local maxp = vector.add(p, radius)

    local vm = minetest.get_voxel_manip()
    local emin, emax = vm:read_from_map(minp, maxp)
    local area = VoxelArea:new({MinEdge=emin, MaxEdge=emax})
    local data = vm:get_data()
    local p2   = vm:get_param2_data()

    -- Build a set of palette-leaf content IDs
    local LEAF_CID = {}
    for name2, def in pairs(minetest.registered_nodes) do
      if def and def.groups and def.groups.leaves
         and def.paramtype2 == "color" and def.palette then
        LEAF_CID[minetest.get_content_id(name2)] = true
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
              local ok, bd = pcall(minetest.get_biome_data, {x=x,y=y,z=z})
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
minetest.register_node("cw_core:oak_sapling", {
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
    minetest.get_node_timer(pos):start(math.random(60, 120))
  end,
  on_timer = function(pos)
    local under = minetest.get_node({x=pos.x, y=pos.y-1, z=pos.z}).name
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
  local nn = minetest.get_node(up).name
  local def = minetest.registered_nodes[nn]
  return (def and def.groups and def.groups.snow and def.groups.snow > 0) or false
end

local function should_decay_to_dirt(pos)
  local up = {x=pos.x, y=pos.y+1, z=pos.z}
  local upnode = minetest.get_node(up)
  local updef  = minetest.registered_nodes[upnode.name]
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
  local node = minetest.get_node(pos)
  local snow = (force_snow == true) or has_snow_above(pos)
  local target = snow and "cw_core:grass_block_snow" or "cw_core:grass_block"
  local idx = keep_idx or choose_grass_index_for_pos(pos)
  if node.name ~= target or (node.param2 or 0) ~= idx then
    minetest.swap_node(pos, { name = target, param2 = idx })
  end
  
--  local lo =
--	tonumber(minetest.settings:get("cw_grass_palette_min_idx")) or 4
--  local hi =
--	tonumber(minetest.settings:get("cw_grass_palette_max_idx")) or 11
--  idx = jitter_idx(idx, lo, hi)
  
  if target == "cw_core:grass_block" then
    if should_decay_to_dirt(pos) then
      minetest.get_node_timer(pos):start(math.random(DECAY_SECONDS_MIN, DECAY_SECONDS_MAX))
    else
      minetest.get_node_timer(pos):stop()
    end
  end
end

-- Actual palette grass (uses paramtype2=color + overlay tint)
minetest.register_node("cw_core:grass_block", {
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
      minetest.swap_node(pos, { name = "cw_core:dirt" })
      return false
    end
    return true
  end,
})

-- Creative item (pretty icon) that swaps to palette node on place
minetest.register_node("cw_core:grass_block_plains", {
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
    minetest.swap_node(pos, { name = "cw_core:grass_block", param2 = 0 })
    cw_core.update_grass_state(pos, false) -- snap to biome-preferred immediately
  end,
})

-- Snowed grass
minetest.register_node("cw_core:grass_block_snow", {
  description = "Grass Block (Snowed)",
  tiles = {
    "cw_grass_top_snow.png",
    { name="cw_dirt.png", color="white" },
    { name="cw_dirt.png", color="white" },
  },
  overlay_tiles = {
    "", "",
    { name="cw_grass_side_overlay.png", tileable_vertical=false },
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
minetest.register_lbm({
  name = "cw_core:tint_grass_once",
  nodenames = { "cw_core:grass_block", "cw_core:grass_block_snow" },
  run_at_every_load = false,
  action = function(pos, node)
    cw_core.update_grass_state(pos, node.name == "cw_core:grass_block_snow")
  end,
})

-- Legacy aliases (old g01..g16 series)
for i = 1, 16 do
  minetest.register_alias("cw_core:grass_block_g"..("%02d"):format(i), "cw_core:grass_block")
end

-- Grass spread ABM
minetest.register_abm({
  label = "cw_core:grass_spread",
  nodenames = { "cw_core:dirt" },
  neighbors = { "cw_core:grass_block", "cw_core:grass_block_snow" },
  interval = 7,
  chance   = 25,
  action = function(pos)
    local above = {x=pos.x, y=pos.y+1, z=pos.z}
    local above_def = minetest.registered_nodes[minetest.get_node(above).name]
    if above_def and above_def.walkable and not above_def.buildable_to then return end
    local light = minetest.get_node_light(above, 0.5) or 0
    if light < 9 then return end
    minetest.swap_node(pos, { name = "cw_core:grass_block", param2 = 0 })
    cw_core.update_grass_state(pos)
  end
})

-- --- SAND -------------------------------------------------------------------
minetest.register_node("cw_core:sand", {
  description = "Sand",
  tiles = {"cw_sand.png"},
  is_ground_content = true,
  groups = {crumbly = 3, falling_node = 1, sand = 1},
})

minetest.register_node("cw_core:sand_red", {
  description = "Red Sand",
  tiles = {"cw_sand_red.png"},
  is_ground_content = true,
  groups = {crumbly = 3, falling_node = 1, sand = 1},
})

local WATER_PALETTE = "cw_water_palette.png" -- 1x16 vertical

-- --- WATER (STATIC SOURCE; palette-tinted, including inventory) -------------
minetest.register_node("cw_core:water_source", {
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
minetest.register_node("cw_core:gravel", {
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
minetest.register_node("cw_core:clay", {
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
minetest.register_node(modname..":cactus", {
  description="Cactus",
  tiles={"cw_cactus_top.png","cw_cactus_top.png","cw_cactus_side.png"},
  paramtype2="facedir",
  groups={snappy=1,choppy=3,oddly_breakable_by_hand=1,flammable=1,cactus=1},
  sounds=node_sound_wood(),
})
minetest.register_node(modname..":dead_bush", {
  description="Dead Bush", drawtype="plantlike",
  tiles={"cw_dead_bush.png"}, inventory_image="cw_dead_bush.png", wield_image="cw_dead_bush.png",
  use_texture_alpha="clip", paramtype="light", sunlight_propagates=true, walkable=false, buildable_to=true,
  groups={snappy=3,flammable=2,attached_node=1}, sounds=node_sound_leaves(),
})

-- =========================
-- Mapgen aliases (optional)
-- =========================
minetest.register_alias("mapgen_stone", "cw_core:stone")
minetest.register_alias("mapgen_dirt",  "cw_core:dirt")
minetest.register_alias("mapgen_water", "cw_core:water_source")
