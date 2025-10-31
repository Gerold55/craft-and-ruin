-- cw_mapgen / mapgen_v7.lua  (fixed full-column writer)
local SEA_LEVEL   = 62
local WORLD_TOP   = 300
local WORLD_BOTTOM= -300

-- simple 0..1 RNG (no bit32)
local function hash01(x,z,salt)
  local n = minetest.hash_node_position({x=x,y=salt or 0,z=z})
  n = ( (n * 1103515245 + 12345) % 0x7fffffff )
  return (n % 10000) / 10000.0
end

local function perlin2(cfg)
  return minetest.get_perlin({
    offset=0, scale=cfg.scale or 1,
    spread={x=cfg.x or 256,y=cfg.y or 256,z=cfg.z or 256},
    seed=cfg.seed or 0, octaves=cfg.oct or 3, persist=cfg.pers or 0.5, lacunarity=2.0
  })
end

-- lazy content ids
local CID=setmetatable({}, {__index=function(t,k)local id=minetest.get_content_id(k);rawset(t,k,id);return id end})
local NODES={
  air="air",
  stone="cw_core:stone",
  dirt="cw_core:dirt",
  grass="cw_core:grass_block",
  sand="cw_core:sand",
  red_sand="cw_core:red_sand",
  water_src="cw_core:water_source",
  ore_gold="cw_core:ore_gold",
}

-- terracotta palette (no cyan)
local TERR={
 "cw_core:terracotta_white","cw_core:terracotta_orange","cw_core:terracotta_magenta",
 "cw_core:terracotta_light_blue","cw_core:terracotta_yellow","cw_core:terracotta_lime",
 "cw_core:terracotta_pink","cw_core:terracotta_gray","cw_core:terracotta_light_gray",
 "cw_core:terracotta_purple","cw_core:terracotta_blue","cw_core:terracotta_brown",
 "cw_core:terracotta_green","cw_core:terracotta_red","cw_core:terracotta_black"
}

-- boot noises once per chunk
local N=nil
local function ensure_noises()
  if N then return end
  N={
    temp  = perlin2{ x=1024,y=1024,z=1024, seed=93121, oct=3, pers=0.55 },
    humid = perlin2{ x=1024,y=1024,z=1024, seed=48293, oct=3, pers=0.55 },
    cont  = perlin2{ x=2048,y=2048,z=2048, seed=15031, oct=4, pers=0.53 },
    weird = perlin2{ x= 768,y= 768,z= 768, seed=77777, oct=2, pers=0.60 },
    elev  = perlin2{ x= 256,y= 256,z= 256, seed=34561, oct=5, pers=0.50 },
    river = perlin2{ x= 512,y= 512,z= 512, seed=60413, oct=3, pers=0.55 },
  }
end

local function TH(x,z)
  return 0.5+0.5*N.temp:get_2d({x=x,y=z}), 0.5+0.5*N.humid:get_2d({x=x,y=z}), 0.5+0.5*N.cont:get_2d({x=x,y=z})
end

-- biome router
local function biome_at(x,z)
  local T,H,C=TH(x,z)
  if C<0.20 then return "deep_ocean"
  elseif C<0.30 then return "ocean" end
  if T>0.70 and H<0.35 then
    if C>0.45 and C<0.75 and hash01(x,z,901)<0.06 then return "clayspire_basin" end
    return "desert"
  end
  if T>0.55 and H>0.70 and math.abs(N.river:get_2d({x=x,y=z}))<0.08 then return "swamp" end
  if T<0.35 then return (H>0.50) and "snowy_taiga" or "taiga" end
  if H>0.55 then return (hash01(x,z,1203)<0.35) and "forest" or "birch_forest" end
  return (hash01(x,z,77)<0.35) and "meadows" or "plains"
end

-- height field
local function ground_y(x,z)
  local base=N.elev:get_2d({x=x,y=z})
  local cont=N.cont:get_2d({x=x,y=z})
  local hills=N.weird:get_2d({x=x,y=z})
  local c01=0.5+0.5*cont
  local coast_gain=math.max(0,c01-0.30)/0.70
  local ampl=22+36*coast_gain
  return SEA_LEVEL + math.floor(base*ampl + hills*ampl*0.35 + 0.5)
end

-- paint full column (FIX: fill whole y-range)
local function write_column(area,data,minp,maxp,x,z,surf_y,biome)
  local cid_air   = CID[NODES.air]
  local cid_stone = CID[NODES.stone]
  local cid_water = CID[NODES.water_src]
  local top,fill  = NODES.grass, NODES.dirt
  if biome=="desert" or biome=="clayspire_basin" then top=NODES.red_sand; fill=NODES.red_sand
  elseif biome=="beach" then top=NODES.sand; fill=NODES.sand end
  local cid_top, cid_fill = CID[top], CID[fill]

  -- 1) below seafloor / crust
  for y=minp.y, math.min(surf_y-4, maxp.y) do
    data[area:index(x,y,z)] = cid_stone
  end
  -- 2) 3 layers of fill
  for k=3,1,-1 do
    local y=surf_y-k
    if y>=minp.y and y<=maxp.y then data[area:index(x,y,z)] = cid_fill end
  end
  -- 3) top block
  if surf_y>=minp.y and surf_y<=maxp.y then
    data[area:index(x,surf_y,z)] = cid_top
  end
  -- 4) water up to sea level
  if SEA_LEVEL>surf_y then
    for y=math.max(surf_y+1, minp.y), math.min(SEA_LEVEL, maxp.y) do
      data[area:index(x,y,z)] = cid_water
    end
  end
  -- 5) clear air above sea (don’t leave junk from previous mg layer)
  for y=math.max(SEA_LEVEL+1, minp.y), maxp.y do
    -- only clear where not stone/top/fill to avoid punching spires later
    local i=area:index(x,y,z)
    if data[i]~=cid_stone then data[i]=cid_air end
  end
end

-- clayspire column bands
local function paint_clayspire_column(area,data,minp,maxp,x,z,top_y)
  local off=math.floor(hash01(x,z,311)*#TERR)
  for y=top_y, math.max(top_y-32, minp.y), -1 do
    local idx=((top_y - y) / 1 + off) % #TERR + 1
    data[area:index(x,y,z)]=CID[TERR[idx]]
  end
end

-- spires
local function build_spires(area,data,minp,maxp,seed)
  local p=minetest.get_perlin({offset=0,scale=1,spread={x=96,y=96,z=96},seed=0x41F2A+seed,octaves=3,persist=0.55,lacunarity=2.0})
  for z=minp.z,maxp.z do
    for x=minp.x,maxp.x do
      if biome_at(x,z)=="clayspire_basin" then
        local y0=ground_y(x,z)
        local s=p:get_2d({x=x,y=z})
        if s>0.35 then
          local h=math.floor(6+(s-0.35)*28)
          for y=y0+1, math.min(y0+h, maxp.y) do
            local idx=area:index(x,y,z)
            if data[idx]==CID[NODES.air] then
              local band=((y-y0)/1)%#TERR+1
              data[idx]=CID[TERR[band]]
            else break end
          end
        end
      end
    end
  end
end

-- extra gold in clayspire
local function gold_bias(area,data,minp,maxp)
  local cid_stone=CID[NODES.stone]; local cid_gold=CID[NODES.ore_gold]
  for z=minp.z,maxp.z do for x=minp.x,maxp.x do
    if biome_at(x,z)=="clayspire_basin" then
      for y=math.max(8,minp.y), math.min(48,maxp.y) do
        local i=area:index(x,y,z)
        if data[i]==cid_stone and hash01(x*13+y*7,z*11,909)<0.0075 then data[i]=cid_gold end
      end
    end
  end end
end

minetest.set_mapgen_params({mgname="v7", water_level=SEA_LEVEL})

minetest.register_on_generated(function(minp,maxp,seed)
  if not minp or not maxp then return end
  ensure_noises()

  local vm,emin,emax=minetest.get_mapgen_object("voxelmanip")
  local area=VoxelArea:new{MinEdge=emin,MaxEdge=emax}
  local data=vm:get_data()
  local p2  =vm:get_param2_data()

  for z=minp.z,maxp.z do
    for x=minp.x,maxp.x do
      local bio=biome_at(x,z)
      local gy =ground_y(x,z)
      gy=math.max(minp.y+4, math.min(gy, maxp.y-1)) -- keep surface inside chunk
      write_column(area,data,minp,maxp,x,z,gy,bio)
      if bio=="clayspire_basin" then paint_clayspire_column(area,data,minp,maxp,x,z,gy) end
    end
  end

  build_spires(area,data,minp,maxp,seed)
  gold_bias(area,data,minp,maxp)

  vm:set_data(data); vm:set_param2_data(p2)
  vm:calc_lighting(minp,maxp)
  vm:write_to_map()

  if cw_mapgen and cw_mapgen.run_decor_postgen then
    cw_mapgen.run_decor_postgen("v7")
  end
end)
