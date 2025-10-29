local maxp = cw_copperflow.power_max

local function poke_neighbors(p)
  for _,q in ipairs(cw_copperflow.adjacent6(p)) do
    local nt = minetest.get_node_timer(q); if nt then nt:start(0.05) end
  end
end

function cw_copperflow.recompute_power(pos)
  local node = minetest.get_node_or_nil(pos); if not node then return end
  local def  = minetest.registered_nodes[node.name]; if not def then return end

  local meta = minetest.get_meta(pos)
  local self_out = tonumber(meta:get_string("cf_out")) or 0
  local best = self_out

  for _,q in ipairs(cw_copperflow.adjacent6(pos)) do
    local np = cw_copperflow.get_power(q)
    if np and np > 0 then
      if np > best then best = np end
    end
  end

  local prev = cw_copperflow.get_power(pos)
  if best ~= prev then
    cw_copperflow.set_power(pos, best, false)
    poke_neighbors(pos)
    if def.on_copper_signal then def.on_copper_signal(pos, node, best, prev) end
  end
end

function cw_copperflow.on_timer_conductive(pos)
  cw_copperflow.recompute_power(pos)
  return false
end

function cw_copperflow.drive_output(pos, strength)
  local m = minetest.get_meta(pos)
  strength = math.max(0, math.min(strength or 0, maxp))
  local prev = tonumber(m:get_string("cf_out")) or 0
  if prev ~= strength then
    m:set_string("cf_out", tostring(strength))
    local self_t = minetest.get_node_timer(pos); if self_t then self_t:start(0.05) end
    for _,q in ipairs(cw_copperflow.adjacent6(pos)) do
      local t = minetest.get_node_timer(q); if t then t:start(0.05) end
    end
  end
end

function cw_copperflow.bump(pos)
  local nt = minetest.get_node_timer(pos); if nt then nt:start(0.05) end
  for _,q in ipairs(cw_copperflow.adjacent6(pos)) do
    local t = minetest.get_node_timer(q); if t then t:start(0.05) end
  end
end
