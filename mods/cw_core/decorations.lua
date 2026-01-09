-- cw_core/decorations.lua
-- Reeds + palette-tinted decor grass + flowers (Plains-friendly)

local MOD = "cw_core"
cw_core = rawget(_G, "cw_core") or {}

-- Translator
local S = (minetest.get_translator and minetest.get_translator(MOD)) or function(s) return s end

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
  local ok, data = pcall(minetest.get_biome_data, pos)
  return (ok and data and data.humidity) or 50
end

local MOD = minetest.get_current_modname()
local S = minetest.get_translator(MOD)

-- 1. UPDATED BASES: Added the new mapgen sand types
local BASES = {
    [MOD..":grass_block"]  = true,
    [MOD..":dirt"]         = true,
    [MOD..":sand"]         = true,
    [MOD..":beach_sand"]   = true, -- Compatibility with Mapgen
    [MOD..":desert_sand"]  = true, -- Compatibility with Mapgen
}

-- 2. UTILITIES
local function _is_water(nm)
    local def = minetest.registered_nodes[nm]
    return def and def.groups and (def.groups.water or 0) > 0
end

local function _water_adjacent(pos)
    local dirs = {
        {x= 1,y=0,z= 0},{x=-1,y=0,z= 0},
        {x= 0,y=0,z= 1},{x= 0,y=0,z=-1},
    }
    for _, d in ipairs(dirs) do
        local nn = minetest.get_node({x=pos.x+d.x, y=pos.y+d.y, z=pos.z+d.z}).name
        if _is_water(nn) then return true end
    end
    return false
end

local function _can_reeds_survive_at(pos)
    -- Check if it's on a valid base node
    local below = minetest.get_node({x=pos.x, y=pos.y-1, z=pos.z}).name
    if not BASES[below] then return false end
    
    -- Check for water adjacency at the base level
    if not _water_adjacent({x=pos.x, y=pos.y-1, z=pos.z}) then return false end
    return true
end

local function _get_stack_info(pos)
    local p = {x=pos.x, y=pos.y, z=pos.z}
    -- Find the true bottom (the first reed on top of sand/dirt)
    while minetest.get_node({x=p.x, y=p.y-1, z=p.z}).name == MOD..":reeds" do
        p.y = p.y - 1
    end
    local bottom = {x=p.x, y=p.y, z=p.z}
    
    -- Count total height from bottom
    local height = 0
    while minetest.get_node(p).name == MOD..":reeds" do
        height = height + 1
        p.y = p.y + 1
    end
    return bottom, height
end

-- 3. NODE DEFINITION
minetest.register_node(MOD..":reeds", {
    description = S("Reeds"),
    drawtype = "plantlike",
    waving = 1,
    tiles = {"cw_reeds.png"},
    inventory_image = "cw_reeds.png",
    wield_image = "cw_reeds.png",
    use_texture_alpha = "clip",
    paramtype = "light",
    paramtype2 = "degrotate",
    
    sunlight_propagates = true,
    walkable = false,
    buildable_to = true,
    groups = {snappy=3, flammable=2, attached_node=1, reeds=1},
    
    selection_box = { type="fixed", fixed = {-0.25, -0.5, -0.25, 0.25, 0.5, 0.25} },

    -- Survival Check for manual placement
    after_place_node = function(pos, placer)
        local bottom_pos, _ = _get_stack_info(pos)
        if not _can_reeds_survive_at(bottom_pos) then
            minetest.remove_node(pos)
            return true -- Block placement
        end
    end,
})

-- 4. GROWTH ABM
-- Handles natural growth over time (up to 3 tall)
minetest.register_abm({
    label = "Reeds natural growth",
    nodenames = {MOD..":reeds"},
    neighbors = {"group:water"}, -- Only run ABM near water for performance
    interval = 20,
    chance = 10,
    action = function(pos)
        local bottom_pos, height = _get_stack_info(pos)
        
        -- Validate survival
        if not _can_reeds_survive_at(bottom_pos) then
            minetest.remove_node(pos)
            return
        end

        -- Try to grow if under max height
        if height < 3 then
            local top_pos = {x=bottom_pos.x, y=bottom_pos.y + height, z=bottom_pos.z}
            if minetest.get_node(top_pos).name == "air" then
                minetest.set_node(top_pos, {name = MOD..":reeds"})
            end
        end
    end,
})

-- ====== DECOR GRASS (palette tinted like Minecraft) ========================

local GRASS_PALETTE = "cw_grass_palette.png" -- 1x16 vertical

-- Palette clamp/gamma for decor grass (re-use foliage settings or grass settings)
local settings = minetest.settings
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
  local node = minetest.get_node(pos)
  if node.name ~= MOD..":grass_decor" then return end
  local def = minetest.registered_nodes[node.name]
  if not def or def.paramtype2 ~= "color" or not def.palette then return end
  local idx = _decor_grass_index_for_pos(pos)
  if (node.param2 or 0) ~= idx then
    node.param2 = idx
    minetest.swap_node(pos, node)
  end
end

minetest.register_node(MOD..":grass_decor", {
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
minetest.register_lbm({
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
  minetest.register_node(MOD..":flower_"..name, {
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

minetest.register_node("cw_core:dead_bush", {
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