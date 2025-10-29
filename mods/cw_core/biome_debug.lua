-- cw_core/biome_debug.lua
-- /biome     : print biome + climate + palette indices at player pos
-- /biomehud  : toggle small live HUD with the same info

local mod = minetest.get_current_modname()
cw_core     = rawget(_G, "cw_core") or {}
cw_mapgen   = rawget(_G, "cw_mapgen") or {}

local hud_players = {}   -- [playername] = {id=..., on=true}

local function get_biome_report(pos)
  -- Fallbacks if mapgen exports aren't present (avoid crashes)
  local sampler = cw_mapgen.sample_all
  local grass_i = cw_mapgen.smoothed_grass_index
  local water_i = cw_mapgen.smoothed_water_index
  local pick    = cw_mapgen.pick_biome

  local x, z = math.floor(pos.x+0.5), math.floor(pos.z+0.5)
  local y, rm, ocean_t, P = 0, 0, 0, {T=0, H=0, C=0, E=0, W=0, D=0}
  if sampler then y, rm, ocean_t, P = sampler(x, z) end

  local biome = (pick and pick(P, y, rm, ocean_t)) or {id="(unknown)"}
  local grass_idx = grass_i and grass_i(x, z) or -1
  local water_idx = water_i and water_i(x, z) or -1

  -- Actual placed node palette readings at feet block and leaves nearby
  local n_here = minetest.get_node({x=x, y=pos.y-1, z=z})
  local param2_here = n_here and n_here.param2 or -1
  local leaf_param2 = -1
  local function scan_for_leaves()
    local r = 2
    for dz=-r,r do for dy=0,3 do for dx=-r,r do
      local p = {x=x+dx, y=pos.y+dy, z=z+dz}
      local n = minetest.get_node(p)
      local def = n and minetest.registered_nodes[n.name]
      if def and def.groups and (def.groups.leaves or 0) > 0 and def.paramtype2 == "color" then
        leaf_param2 = n.param2 or 0
        return
      end
    end end end
  end
  scan_for_leaves()

  return {
    x=x, z=z, y_est=math.floor(y+0.5),
    biome=biome.id,
    T=P.T, H=P.H, C=P.C, E=P.E, W=P.W, D=P.D,
    rm=rm, ocean_t=ocean_t,
    grass_idx=grass_idx, water_idx=water_idx,
    ground_name = n_here and n_here.name or "(nil)",
    ground_p2   = param2_here,
    leaf_p2     = leaf_param2,
  }
end

local function fmt_pct(v) return string.format("%.0f%%", v*100) end
local function fmt01(v)   return string.format("%.2f", v) end

local function make_report_text(r)
  return table.concat({
    ("Biome: %s  @(%d, %d)"):format(r.biome, r.x, r.z),
    ("Climate  T:%s  H:%s  C:%s  E:%s  W:%s  D:%s")
      :format(fmt01(r.T), fmt01(r.H), fmt01(r.C), fmt01(r.E), fmt01(r.W), fmt01(r.D)),
    ("Rivers rm:%s  Ocean:%s"):format(fmt01(r.rm), fmt01(r.ocean_t)),
    ("Palettes  grass:%d  water:%d"):format(r.grass_idx, r.water_idx),
    ("Ground: %s  p2:%d   Leaf p2:%d"):format(r.ground_name, r.ground_p2, r.leaf_p2),
  }, "\n")
end

-- /biome : one-shot print
minetest.register_chatcommand("biome", {
  description = "Show biome + climate and palette indices at your location",
  privs = {interact = true},
  func = function(name)
    local plr = minetest.get_player_by_name(name)
    if not plr then return false, "No player." end
    local r = get_biome_report(plr:get_pos())
    local lines = make_report_text(r)
    minetest.chat_send_player(name, lines)
    return true
  end
})

-- HUD helpers
local function add_hud(player)
  local name = player:get_player_name()
  if hud_players[name] and hud_players[name].id then return end
  local id = player:hud_add({
    hud_elem_type = "text",
    position = {x=0.01, y=0.02},
    offset = {x=0, y=0},
    text = "",
    number = 0xFFFFFF,
    alignment = {x=1, y=1},
    scale = {x=100, y=20},
  })
  hud_players[name] = {id=id, on=true}
end

local function remove_hud(player)
  local name = player:get_player_name()
  local h = hud_players[name]
  if h and h.id then
    player:hud_remove(h.id)
  end
  hud_players[name] = nil
end

minetest.register_chatcommand("biomehud", {
  description = "Toggle live biome/palette HUD",
  privs = {interact = true},
  func = function(name)
    local plr = minetest.get_player_by_name(name)
    if not plr then return false, "No player." end
    if not hud_players[name] then
      add_hud(plr)
      return true, "Biome HUD: ON"
    else
      remove_hud(plr)
      return true, "Biome HUD: OFF"
    end
  end
})

-- Update HUD ~2x/sec
local acc = 0
minetest.register_globalstep(function(dtime)
  acc = acc + dtime
  if acc < 0.5 then return end
  acc = 0
  for name, h in pairs(hud_players) do
    local plr = minetest.get_player_by_name(name)
    if plr and h.id then
      local r = get_biome_report(plr:get_pos())
      local txt = make_report_text(r)
      plr:hud_change(h.id, "text", txt)
    end
  end
end)

-- Cleanup on leave
minetest.register_on_leaveplayer(function(player) remove_hud(player) end)
