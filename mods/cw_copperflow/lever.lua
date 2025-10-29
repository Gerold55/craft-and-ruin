local G = cw_copperflow.groups

local function toggle(pos, node, turn_on)
  local on = turn_on
  if on == nil then on = (node.name == "cw_copperflow:lever_off") end
  local newname = on and "cw_copperflow:lever_on" or "cw_copperflow:lever_off"
  if node.name ~= newname then
    minetest.swap_node(pos, {name=newname, param2=node.param2})
  end
  cw_copperflow.drive_output(pos, on and cw_copperflow.power_max or 0)
  cw_copperflow.bump(pos)
end

local common = {
  drawtype   = "nodebox",
  paramtype  = "light",
  paramtype2 = "wallmounted",
  sunlight_propagates = true,
  walkable = false,
  node_box = { type="fixed", fixed = { -0.2,-0.5,-0.2, 0.2,-0.4,0.2 } },
  groups = {cracky=2, [G.emitter]=1, [G.conductive]=1},
  on_construct = function(pos) cw_copperflow.set_power(pos,0,false); minetest.get_node_timer(pos):start(0.05) end,
  on_timer = function(pos) cw_copperflow.recompute_power(pos); return false end,
  on_rightclick = function(pos, node, clicker) toggle(pos, node) end,
  on_punch      = function(pos, node, puncher) toggle(pos, node) end,
}

minetest.register_node("cw_copperflow:lever_off", setmetatable({
  description = "Copper Lever",
  tiles = {"cf_lever.png"},
}, {__index=common}))

minetest.register_node("cw_copperflow:lever_on", setmetatable({
  description = "Copper Lever (ON)",
  tiles = {"cf_lever.png^[brighten"},
  drop  = "cw_copperflow:lever_off",
  groups = {cracky=2, [G.emitter]=1, [G.conductive]=1, not_in_creative_inventory=1},
  on_construct = function(pos)
    cw_copperflow.drive_output(pos, cw_copperflow.power_max)
    minetest.get_node_timer(pos):start(0.05)
  end,
}, {__index=common}))
