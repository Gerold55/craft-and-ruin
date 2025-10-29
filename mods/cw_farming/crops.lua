-- cw_farming/crops.lua
-- Plant registrations, staged growth, planting logic, and harvest drops.

local function rand_time(base, jit)
  return base + math.random(0, jit)
end

-- Shared plant node def bits
local function plant_drawdef(tex)
  return {
    drawtype = "plantlike",
    waving = 1,
    tiles = {tex},
    inventory_image = tex,
    wield_image = tex,
    paramtype = "light",
    sunlight_propagates = true,
    walkable = false,
    selection_box = { type = "fixed", fixed = {-0.3,-0.5,-0.3, 0.3,0.45,0.3} },
    groups = {snappy=3, flammable=2, plant=1, cw_crop=1, not_in_creative_inventory=1},
    sounds = default and default.node_sound_leaves_defaults and default.node_sound_leaves_defaults() or nil,
  }
end

-- Planting helper: place stage_0 onto soil/wet soil only
local function make_seed_on_place(stage0_name)
  return function(itemstack, placer, pointed_thing)
    if not pointed_thing or pointed_thing.type ~= "node" then return itemstack end
    local under = pointed_thing.under
    local above = pointed_thing.above
    local uname = minetest.get_node(under).name
    if (uname ~= "cw_farming:soil" and uname ~= "cw_farming:soil_wet") then
      return itemstack
    end
    local anode = minetest.get_node(above)
    if anode.name ~= "air" then return itemstack end
    minetest.set_node(above, {name = stage0_name})
    itemstack:take_item(1)
    return itemstack
  end
end

-- Growth step logic
local function growth_timer(pos, node, def)
  local light = minetest.get_node_light(pos)
  if not light or light < cw_farming.GROW.min_light then
    -- try again later
    minetest.get_node_timer(pos):start(rand_time(def.base_time or cw_farming.GROW.base_time, cw_farming.GROW.rand_jit))
    return
  end

  -- Hydration speeds growth (soil below wet?)
  local below = {x=pos.x, y=pos.y-1, z=pos.z}
  local soil = minetest.get_node(below).name
  local hydrated = (soil == "cw_farming:soil_wet")
  local step_ok = math.random(hydrated and 1 or 2) == 1 -- 50% speedup when hydrated

  if step_ok then
    local stage = def.stage
    if stage < def.final_stage then
      minetest.swap_node(pos, {name = def.basename .. "_" .. (stage + 1)})
    end
  end

  if def.stage < def.final_stage then
    minetest.get_node_timer(pos):start(rand_time(def.base_time or cw_farming.GROW.base_time, cw_farming.GROW.rand_jit))
  end
end

local function register_staged_crop(args)
  -- args: basename, pretty, seed_name, seed_tex, stage_textures[0..N], final_drops, base_time
  local N = #args.stage_textures - 1
  local stage_nodes = {}

  for i = 0, N do
    local name = args.basename .. "_" .. i
    local def = plant_drawdef(args.stage_textures[i+1])
    def.description = i == 0 and (args.pretty.." (Seedling)") or nil
    def.groups.not_in_creative_inventory = (i == 0) and 0 or 1
    def._cw_cropdef = {basename = args.basename, stage = i, final_stage = N, base_time = args.base_time}

    def.on_construct = function(pos)
      if i < N then
        minetest.get_node_timer(pos):start(rand_time(args.base_time or cw_farming.GROW.base_time, cw_farming.GROW.rand_jit))
      end
    end

    def.on_timer = function(pos, elapsed)
      growth_timer(pos, nil, def._cw_cropdef)
    end

    -- If soil is lost, drop the plant
    def.on_neighbor_changed = function(pos)
      local below = {x=pos.x, y=pos.y-1, z=pos.z}
      local bn = minetest.get_node(below).name
      if bn ~= "cw_farming:soil" and bn ~= "cw_farming:soil_wet" then
        minetest.remove_node(pos)
        minetest.add_item(pos, args.seed_name)
      end
    end

    -- Drops:
    if i < N then
      def.drop = args.seed_name
    else
      -- Fully grown: custom drops
      def.drop = {
        max_items = 3,
        items = args.final_drops,
      }
    end

    minetest.register_node(name, def)
    stage_nodes[i] = name
  end

  -- Seed item → on_place plants stage_0
  if args.seed_name and args.seed_tex then
    minetest.override_item(args.seed_name, {
      on_place = make_seed_on_place(args.basename .. "_0"),
    })
  end

  return stage_nodes
end

-- =======================
-- WHEAT (7 stages)
-- =======================
register_staged_crop({
  basename = "cw_farming:wheat",
  pretty = "Wheat",
  seed_name = "cw_farming:seed_wheat",
  seed_tex  = "cw_farming_seed_wheat.png",
  stage_textures = {
    "cw_farming_wheat_1.png", "cw_farming_wheat_2.png", "cw_farming_wheat_3.png", "cw_farming_wheat_4.png",
  },
  base_time = 110, -- slightly faster baseline
  final_drops = {
    {items = {"cw_farming:wheat_item"}, rarity = 1},
    {items = {"cw_farming:wheat_item"}, rarity = 2},
    {items = {"cw_farming:seed_wheat"}, rarity = 1},
    {items = {"cw_farming:seed_wheat"}, rarity = 2},
  }
})

-- =======================
-- POTATO (7 stages)
-- =======================
register_staged_crop({
  basename = "cw_farming:potato",
  pretty = "Potatoes",
  seed_name = "cw_farming:potato_raw",
  seed_tex  = "cw_farming_seed_potato.png",
  stage_textures = {
    "cw_farming_potato_0.png", "cw_farming_potato_1.png", "cw_farming_potato_2.png", "cw_farming_potato_3.png",
  },
  base_time = 120,
  final_drops = {
    {items = {"cw_farming:potato_raw"}, rarity = 1},
    {items = {"cw_farming:potato_raw"}, rarity = 1},
    {items = {"cw_farming:potato_raw"}, rarity = 2},
  }
})

-- =======================
-- CARROT (7 stages)
-- =======================
register_staged_crop({
  basename = "cw_farming:carrot",
  pretty = "Carrots",
  seed_name = "cw_farming:seed_carrot",
  seed_tex  = "cw_farming_seed_carrot.png",
  stage_textures = {
    "cw_farming_carrot_0.png", "cw_farming_carrot_1.png", "cw_farming_carrot_2.png", "cw_farming_carrot_3.png",
  },
  base_time = 120,
  final_drops = {
    {items = {"cw_farming:carrot_item"}, rarity = 1},
    {items = {"cw_farming:carrot_item"}, rarity = 1},
    {items = {"cw_farming:carrot_item"}, rarity = 2},
    {items = {"cw_farming:seed_carrot"}, rarity = 2},
  }
})
