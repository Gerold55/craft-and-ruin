local M = cw_copperflow

function M.adjacent6(p)
  return {
    {x=p.x+1,y=p.y,z=p.z},{x=p.x-1,y=p.y,z=p.z},
    {x=p.x,y=p.y+1,z=p.z},{x=p.x,y=p.y-1,z=p.z},
    {x=p.x,y=p.y,z=p.z+1},{x=p.x,y=p.y,z=p.z-1},
  }
end

function M.get_power(p)
  local n = minetest.get_node_or_nil(p); if not n then return 0 end
  local m = minetest.get_meta(p)
  return tonumber(m:get_string("cf_power")) or 0
end

function M.set_power(p, val, fire_timer)
  local n = minetest.get_node_or_nil(p); if not n then return end
  local m = minetest.get_meta(p)
  local v = math.max(0, math.min(val or 0, cw_copperflow.power_max))
  m:set_string("cf_power", tostring(v))
  if fire_timer then minetest.get_node_timer(p):start(0.05) end
end

function M.bump3(pos)
  for dx=-1,1 do for dy=-1,1 do for dz=-1,1 do
    local q={x=pos.x+dx,y=pos.y+dy,z=pos.z+dz}
    local t=minetest.get_node_timer(q); if t then t:start(0.05) end
  end end end
end
