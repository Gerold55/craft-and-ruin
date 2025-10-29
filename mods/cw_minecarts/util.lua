-- cw_minecarts/util.lua

-- Ensure global table exists even if load order shifts
cw_minecarts = cw_minecarts or {}

local V = {}

function V.copy(v) return {x=v.x, y=v.y, z=v.z} end
function V.add(a,b) return {x=a.x+b.x, y=a.y+b.y, z=a.z+b.z} end
function V.mul(a,s) return {x=a.x*s, y=a.y*s, z=a.z*s} end
function V.len(a) return math.sqrt(a.x*a.x + a.y*a.y + a.z*a.z) end
function V.norm(a)
  local l = V.len(a)
  if l < 1e-6 then return {x=0,y=0,z=0} end
  return {x=a.x/l, y=a.y/l, z=a.z/l}
end
function V.clamp(v, max)
  local l = V.len(v)
  if l > max then
    local n = V.norm(v)
    v.x, v.y, v.z = n.x*max, n.y*max, n.z*max
  end
  return v
end

function cw_minecarts.dir_to_yaw(dir)
  return math.atan2((dir and dir.x) or 0, (dir and dir.z) or 0)
end

-- Is there a rail node at pos?
function cw_minecarts.is_rail(pos)
  local n = minetest.get_node(pos)
  local d = n and minetest.registered_nodes[n.name]
  return (d and d.groups and d.groups.rail == 1) or false
end

-- Convert velocity to axis-aligned unit dir (ignores Y). Returns {x,y,z}.
function cw_minecarts.vel_to_axial_dir(vel)
  vel = vel or {x=0,y=0,z=0}
  local ax, az = math.abs(vel.x), math.abs(vel.z)
  if ax < 0.001 and az < 0.001 then return {x=0,y=0,z=0} end
  if ax >= az then
    return {x = (vel.x >= 0) and 1 or -1, y=0, z=0}
  else
    return {x=0, y=0, z = (vel.z >= 0) and 1 or -1}
  end
end

-- Get next rail direction on flat rails. prefer_dir is an axial hint (unit).
-- Returns one of: {1,0,0}, {-1,0,0}, {0,0,1}, {0,0,-1} or {0,0,0} if none.
function cw_minecarts.get_rail_direction(pos, prefer_dir)
  local p = vector.round(pos)
  if not cw_minecarts.is_rail(p) then return {x=0,y=0,z=0} end

  -- Try preferred direction first, if valid
  if prefer_dir then
    local ax = math.abs(prefer_dir.x or 0)
    local az = math.abs(prefer_dir.z or 0)
    if (ax + az) == 1 then
      local pp = {x=p.x + (prefer_dir.x or 0), y=p.y, z=p.z + (prefer_dir.z or 0)}
      if cw_minecarts.is_rail(pp) then
        return {x=prefer_dir.x or 0, y=0, z=prefer_dir.z or 0}
      end
    end
  end

  -- Otherwise try the four cardinal neighbors
  local candidates = {
    {x= 1,y=0,z= 0}, {x=-1,y=0,z= 0},
    {x= 0,y=0,z= 1}, {x= 0,y=0,z=-1},
  }
  for _,d in ipairs(candidates) do
    local pp = {x=p.x+d.x, y=p.y, z=p.z+d.z}
    if cw_minecarts.is_rail(pp) then
      return {x=d.x, y=0, z=d.z}
    end
  end

  return {x=0,y=0,z=0}
end

cw_minecarts.v = V
