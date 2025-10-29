local G = cw_copperflow.groups

local THICK = 0.02
local PAD   = 0.001

local function rect(u1,v1,u2,v2)
  local x1 = (u1/16)-0.5; local x2=(u2/16)-0.5
  local z1 = (v1/16)-0.5; local z2=(v2/16)-0.5
  return {x1,-0.5+PAD,z1, x2,-0.5+PAD+THICK,z2}
end

local function armN() return rect(7,0,9,8) end
local function armE() return rect(8,7,16,9) end
local function armS() return rect(7,8,9,16) end
local function armW() return rect(0,7,8,9) end
local function core() return rect(7,7,9,9) end

local function hasbit(x,b) return (x % (2*b)) >= b end
local function mask_nodebox(mask)
  local t = { core() }
  if hasbit(mask,1) then t[#t+1]=armN() end
  if hasbit(mask,2) then t[#t+1]=armE() end
  if hasbit(mask,4) then t[#t+1]=armS() end
  if hasbit(mask,8) then t[#t+1]=armW() end
  return { type="fixed", fixed=t }
end

local function is_wire(nm) return nm and nm:find("^cw_copperflow:copper_wire_m%d+$") end

local function conductive_neighbor(pos)
  local n = minetest.get_node_or_nil(pos); if not n or n.name=="air" then return false end
  if is_wire(n.name) then return true end
  local def = minetest.registered_nodes[n.name]
  if not def then return false end
  if def.groups and (def.groups[G.conductive] or def.groups[G.emitter] or def.groups[G.consumer]) then return true end
  return (def.walkable ~= false) and (not def.buildable_to)
end

local OFF = {
  {dx=0,dz=-1,bit=1}, {dx=1,dz=0,bit=2}, {dx=0,dz=1,bit=4}, {dx=-1,dz=0,bit=8}
}

local function compute_mask(pos)
  local m = 0
  for _,d in ipairs(OFF) do
    local q = {x=pos.x+d.dx,y=pos.y,z=pos.z+d.dz}
    if conductive_neighbor(q) then m = m + d.bit end
  end
  return m
end

local function update_self_and_neighbors(pos)
  local n = minetest.get_node(pos)
  local mask = compute_mask(pos)
  local target = "cw_copperflow:copper_wire_m"..mask
  if n.name ~= target then minetest.swap_node(pos, {name=target, param2=0}) end
  for _,d in ipairs(OFF) do
    local q = {x=pos.x+d.dx,y=pos.y,z=pos.z+d.dz}
    local nn = minetest.get_node_or_nil(q)
    if nn and is_wire(nn.name) then
      local m2 = compute_mask(q)
      local tgt = "cw_copperflow:copper_wire_m"..m2
      if nn.name ~= tgt then minetest.swap_node(q, {name=tgt, param2=0}) end
    end
  end
  cw_copperflow.bump(pos)
end

for mask=0,15 do
  minetest.register_node("cw_copperflow:copper_wire_m"..mask, {
    description = "Copper Wire",
    tiles = {"cf_wire.png"},
    drawtype = "nodebox",
    node_box = mask_nodebox(mask),
    use_texture_alpha = "clip",
    paramtype = "light",
    sunlight_propagates = true,
    walkable = false,
    groups = {snappy=1, oddly_breakable_by_hand=1, [G.wire]=1, [G.conductive]=1, not_in_creative_inventory = (mask==0) and 0 or 1},
    drop = "cw_copperflow:copper_wire_m0",
    on_construct = function(pos) cw_copperflow.set_power(pos,0,false); minetest.get_node_timer(pos):start(0.05) end,
    on_timer = cw_copperflow.on_timer_conductive,
    after_place_node = function(pos, placer, itemstack, pointed)
      update_self_and_neighbors(pos)
    end,
    after_dig_node = function(pos) cw_copperflow.bump(pos) end,
  })
end

minetest.register_alias_force("cw_copperflow:copper_wire", "cw_copperflow:copper_wire_m0")

minetest.register_craftitem("cw_copperflow:copper_wire_item", {
  description = "Copper Wire",
  inventory_image = "cf_wire_item.png",
  on_place = function(stack, placer, pointed)
    if pointed and pointed.type == "node" then
      local pos = pointed.above
      if minetest.is_protected(pos, placer:get_player_name()) then return stack end
      minetest.set_node(pos, {name="cw_copperflow:copper_wire_m0"})
      update_self_and_neighbors(pos)
      if not minetest.is_creative_enabled(placer:get_player_name()) then stack:take_item() end
      return stack
    end
    return minetest.item_place(stack, placer, pointed)
  end
})
