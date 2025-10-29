local G = cw_copperflow.groups

minetest.register_node("cw_copperflow:actuator", {
  description = "Copper Actuator",
  tiles = {"cf_act_top.png","cf_act_bottom.png","cf_act_side.png^cf_act_head.png"},
  paramtype2 = "facedir",
  groups = {cracky=2, [G.consumer]=1, [G.conductive]=1},
  on_construct = function(pos)
    cw_copperflow.set_power(pos, 0, false)
    minetest.get_node_timer(pos):start(0.05)
  end,
  on_timer = function(pos)
    local pow  = cw_copperflow.get_power(pos)
    if pow <= 0 then return true end
    local node = minetest.get_node(pos)
    local dir  = minetest.facedir_to_dir(node.param2)
    local front = vector.add(pos, dir)
    local ahead = vector.add(front, dir)
    local nfront = minetest.get_node_or_nil(front)
    local nahead = minetest.get_node_or_nil(ahead)
    if nfront and nfront.name ~= "air" and nahead and (nahead.name == "air" or (minetest.registered_nodes[nahead.name] or {}).buildable_to) then
      minetest.swap_node(ahead, nfront)
      minetest.set_node(front, {name = "air"})
      minetest.sound_play("default_dug_node", {pos=ahead, gain=0.35})
    end
    return true
  end,
  on_copper_signal = function(pos, node, now, prev)
    if (prev or 0) == 0 and now > 0 then minetest.get_node_timer(pos):start(0.05) end
  end,
})
