-- cw_mapgen/decor_postgen.lua
-- Post-generation decorations for Craft & Ruin

-------------------------------------------------
-- Utility: fast deterministic pseudo-random 0..1
-------------------------------------------------
local function hash01(x, z, salt)
 local n = minetest.hash_node_position({x = x, y = salt or 0, z = z})
 -- simple mixer for LuaJIT (no ~ or bit32)
 n = (n * 1103515245 + 12345) % 2147483647
 return (n % 10000) / 10000
end

local function clamp01(n)
 if n < 0 then return 0 end
 if n > 1 then return 1 end
 return n
end

-------------------------------------------------
-- Surface search
-------------------------------------------------
local function find_surface_y(area, data, ids, x, z, top_y, bot_y)
 local air = ids.air or minetest.CONTENT_AIR
 local wsrc = ids.water_source
 for y = top_y, bot_y, -1 do
  local vi = area:index(x, y, z)
  local id = data[vi]
  if id ~= air and id ~= wsrc then
   if data[area:index(x, y+1, z)] == air then
    return y
   end
   return y
  end
 end
end

local function is_air(ids, id)
 return id == (ids.air or minetest.CONTENT_AIR)
end

local function is_water(ids, id)
 return id == ids.water_source or id == ids.water_flowing
end

-------------------------------------------------
-- Trees
-------------------------------------------------
local function place_log(area, data, x, y, z, h, log)
 for i = 0, h-1 do
  data[area:index(x, y+i, z)] = log
 end
end

local function leaves_blob(area, data, ids, cx, cy, cz, rx, ry, rz, leaves)
 local air = ids.air or minetest.CONTENT_AIR
 for dz = -rz, rz do
  for dy = -ry, ry do
   for dx = -rx, rx do
    local d = (dx*dx)/(rx*rx)+(dy*dy)/(ry*ry)+(dz*dz)/(rz*rz)
    if d <= 1 then
     local vi = area:index(cx+dx, cy+dy, cz+dz)
     if data[vi] == air then data[vi] = leaves end
    end
   end
  end
 end
end

local function place_oak(area, data, ids, x, y, z)
 local log = ids.oak_log or ids.tree
 local leaves = ids.oak_leaves or ids.leaves
 local h = 4 + math.floor(hash01(x,z,5)*3)
 place_log(area, data, x, y+1, z, h, log)
 leaves_blob(area, data, ids, x, y+h+1, z, 2,1,2, leaves)
end

local function place_spruce(area, data, ids, x, y, z)
 local log = ids.spruce_log or ids.pine_tree or ids.tree
 local leaves = ids.spruce_needles or ids.pine_needles
 local h = 6 + math.floor(hash01(x,z,6)*4)
 place_log(area, data, x, y+1, z, h, log)
 for i=0,3 do
  leaves_blob(area, data, ids, x, y+h-i, z, 3-i,1,3-i, leaves)
 end
end

-------------------------------------------------
-- Grass / Flowers / Reeds / Mushrooms
-------------------------------------------------
local function place_grass(area, data, ids, vi_above)
 if ids.grass_decor and is_air(ids, data[vi_above]) then
  data[vi_above] = ids.grass_decor
 end
end

local function place_flower(area, data, ids, vi_above, x, z)
 local f = hash01(x,z,200)
 local air = ids.air or minetest.CONTENT_AIR
 if data[vi_above] ~= air then return end
 if f < 0.33 and ids.flower_daisy then data[vi_above] = ids.flower_daisy
 elseif f < 0.66 and ids.flower_blue then data[vi_above] = ids.flower_blue
 elseif ids.flower_tulip then data[vi_above] = ids.flower_tulip end
end

local function near_water(area, data, ids, x, y, z)
 for dz=-3,3 do for dx=-3,3 do
  local id=data[area:index(x+dx,y,z+dz)]
  if is_water(ids,id) then return true end
 end end
end

local function place_reeds(area, data, ids, x, y, z, vi_above)
 if ids.reeds and near_water(area,data,ids,x,y,z) and is_air(ids,data[vi_above]) then
  data[vi_above]=ids.reeds
 end
end

-------------------------------------------------
-- Mushroom: only when covered by leaves/blocks
-------------------------------------------------
local function place_mushroom(area,data,ids,x,y,z,vi_above)
 local a2=data[area:index(x,y+2,z)]
 if not is_air(ids,a2) then
  local f=hash01(x,z,300)
  if f<0.5 and ids.mushroom_brown then data[vi_above]=ids.mushroom_brown
  elseif ids.mushroom_red then data[vi_above]=ids.mushroom_red end
 end
end

-------------------------------------------------
-- Main scatter
-------------------------------------------------
local function scatter(area,data,ids,emin,emax,step,density_fn,place_fn)
 local top=emax.y
 local bot=emin.y

 for z=emin.z,emax.z,step do
  for x=emin.x,emax.x,step do
   if hash01(x,z,999) < density_fn(x,z) then
    local sy=find_surface_y(area,data,ids,x,z,top,bot)
    if sy then
     local vi=area:index(x,sy,z)
     local vi_above=area:index(x,sy+1,z)
     place_fn(x,z,sy,vi,vi_above)
    end
   end
  end
 end
end

-------------------------------------------------
-- Exported entry point
-------------------------------------------------
local M = {}

function M.run_chunk(area,data,p2,ids,emin,emax,biome_at)

 -- grass
 scatter(area,data,ids,emin,emax,8,
  function(x,z)
   local b=biome_at(x,z)
   return (b=="plains" and 0.25)
    or (b=="forest" and 0.18)
    or 0.05
  end,
  function(x,z,sy,vi,vi_above) place_grass(area,data,ids,vi_above) end
 )

 -- flowers
 scatter(area,data,ids,emin,emax,12,
  function(x,z)
   local b=biome_at(x,z)
   return (b=="plains" and 0.10) or 0.01
  end,
  function(x,z,sy,vi,vi_above) place_flower(area,data,ids,vi_above,x,z) end
 )

 -- reeds
 scatter(area,data,ids,emin,emax,8,
  function(x,z) return 0.06 end,
  function(x,z,sy,vi,vi_above) place_reeds(area,data,ids,x,sy,z,vi_above) end
 )

 -- mushrooms
 scatter(area,data,ids,emin,emax,10,
  function(x,z) return 0.03 end,
  function(x,z,sy,vi,vi_above) place_mushroom(area,data,ids,x,sy,z,vi_above) end
 )

 -- trees
 scatter(area,data,ids,emin,emax,14,
  function(x,z)
   local b=biome_at(x,z)
   return (b=="forest" and 0.20)
    or (b=="taiga" and 0.25)
    or (b=="plains" and 0.04)
    or 0
  end,
  function(x,z,sy)
   local b=biome_at(x,z)
   if b=="taiga" then place_spruce(area,data,ids,x,sy,z)
   else place_oak(area,data,ids,x,sy,z) end
  end
 )

end

return M