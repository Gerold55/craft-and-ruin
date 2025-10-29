-- cw_minecarts/rails.lua
local S = minetest.get_translator and minetest.get_translator("cw_minecarts") or function(s) return s end
local metal_sounds = (default and default.node_sound_metal_defaults and default.node_sound_metal_defaults()) or nil

-- Ultra-thin selector so rails feel flat to target
local THIN_SEL = { type="fixed", fixed={-0.5, -0.5, -0.5, 0.5, -0.48, 0.5} }

-- SAFE accessor for CopperFlow bridge
local function CF_is_powered(pos)
  local cf = cw_minecarts and cw_minecarts.cf
  if cf and type(cf.is_pos_powered) == "function" then
    return cf.is_pos_powered(pos) and true or false
  end
  return false
end

local base = {
  drawtype = "raillike",
  paramtype = "light",
  is_ground_content = false,
  sunlight_propagates = true,
  walkable = false,
  climbable = false,
  selection_box = THIN_SEL,
  groups = {rail=1, attached_node=1, handy=1},
  sounds = metal_sounds,
}

local function reg(name, def)
  local nd = table.copy(base)
  for k,v in pairs(def) do nd[k]=v end
  minetest.register_node("cw_minecarts:"..name, nd)
end

-- BASIC RAIL
reg("rail", {
  description = S("Rail"),
  tiles = {"cw_rail_basic.png"},
  inventory_image = "cw_rail_basic.png",
  wield_image = "cw_rail_basic.png",
})

-- POWERED RAIL (two-state with safe polling)
local function powered_timer(pos)
  local powered = CF_is_powered(pos)
  local node = minetest.get_node(pos)
  local want = powered and "cw_minecarts:powered_rail_on" or "cw_minecarts:powered_rail_off"
  if node.name ~= want then
    minetest.swap_node(pos, {name=want, param2=node.param2})
  end
  return true -- keep polling
end

reg("powered_rail_off", {
  description = S("Powered Rail"),
  tiles = {"cw_rail_powered_off.png"},
  inventory_image = "cw_rail_powered_off.png",
  wield_image = "cw_rail_powered_off.png",
  groups = {rail=1, attached_node=1, handy=1, cw_mc_powered=1},
  on_construct = function(pos) minetest.get_node_timer(pos):start(0.5) end,
  on_timer = powered_timer,
})

reg("powered_rail_on", {
  description = S("Powered Rail (On)"),
  tiles = {"cw_rail_powered_on.png"},
  inventory_image = "cw_rail_powered_on.png",
  wield_image = "cw_rail_powered_on.png",
  light_source = 3,
  groups = {rail=1, attached_node=1, handy=1, not_in_creative_inventory=1, cw_mc_powered=1},
  drop = "cw_minecarts:powered_rail_off",
  on_construct = function(pos) minetest.get_node_timer(pos):start(0.5) end,
  on_timer = powered_timer,
})

minetest.register_alias("cw_minecarts:powered_rail", "cw_minecarts:powered_rail_off")

-- DETECTOR RAIL (cart will emit CopperFlow pulse when passing)
reg("detector_rail", {
  description = S("Detector Rail"),
  tiles = {"cw_rail_detector.png"},
  inventory_image = "cw_rail_detector.png",
  wield_image = "cw_rail_detector.png",
  groups = {rail=1, attached_node=1, handy=1, cw_mc_detector=1},
})

-- BRAKE RAIL (increases friction/slowdown in cart physics)
reg("brake_rail", {
  description = S("Brake Rail"),
  tiles = {"cw_rail_brake.png"},
  inventory_image = "cw_rail_brake.png",
  wield_image = "cw_rail_brake.png",
  groups = {rail=1, attached_node=1, handy=1, cw_mc_brake=1},
})

-- CRAFTS (adjust to your items if needed)
minetest.register_craft({
  output = "cw_minecarts:rail 16",
  recipe = {
    {"", "default:steel_ingot", ""},
    {"default:steel_ingot", "group:stick", "default:steel_ingot"},
    {"", "default:steel_ingot", ""},
  }
})

minetest.register_craft({
  output = "cw_minecarts:powered_rail_off 6",
  recipe = {
    {"default:gold_ingot","group:stick","default:gold_ingot"},
    {"default:gold_ingot","default:mese_crystal","default:gold_ingot"},
    {"default:gold_ingot","group:stick","default:gold_ingot"},
  }
})

minetest.register_craft({
  output = "cw_minecarts:detector_rail 6",
  recipe = {
    {"default:copper_ingot","group:stick","default:copper_ingot"},
    {"default:copper_ingot","default:steel_ingot","default:copper_ingot"},
    {"default:copper_ingot","group:stick","default:copper_ingot"},
  }
})

minetest.register_craft({
  output = "cw_minecarts:brake_rail 6",
  recipe = {
    {"default:steel_ingot","group:stick","default:steel_ingot"},
    {"default:steel_ingot","default:stone","default:steel_ingot"},
    {"default:steel_ingot","group:stick","default:steel_ingot"},
  }
})
