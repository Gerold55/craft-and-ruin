-- cw_minecarts/copperflow_bridge.lua

-- Bridge to CopperFlow if present; safe fallbacks otherwise
cw_minecarts = cw_minecarts or {}
local CF = rawget(_G, "copperflow")

local bridge = {}

function bridge.is_pos_powered(pos)
  if CF and CF.power and type(CF.power.is_powered) == "function" then
    return CF.power.is_powered(pos) and true or false
  end
  -- Fallback: look for neighbor meta "cw_power" > 0
  local nbs = {
    {x= 1,y=0,z= 0},{x=-1,y=0,z= 0},
    {x= 0,y=1,z= 0},{x= 0,y=-1,z= 0},
    {x= 0,y=0,z= 1},{x= 0,y=0,z=-1},
  }
  for _,d in ipairs(nbs) do
    local p = {x=pos.x+d.x, y=pos.y+d.y, z=pos.z+d.z}
    local meta = minetest.get_meta(p)
    if meta and meta:get_int("cw_power") > 0 then
      return true
    end
  end
  return false
end

function bridge.emit_pulse(pos, strength, seconds)
  strength = strength or 1
  seconds  = seconds or 0.5

  if CF and CF.power and type(CF.power.pulse) == "function" then
    CF.power.pulse(pos, strength, seconds)
    return
  end

  -- Fallback: set a meta flag briefly
  local meta = minetest.get_meta(pos)
  if not meta then return end
  meta:set_int("cw_power", strength)
  minetest.after(seconds, function()
    local m = minetest.get_meta(pos)
    if m then m:set_int("cw_power", 0) end
  end)
end

cw_minecarts.cf = bridge
