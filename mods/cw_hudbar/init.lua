-- cw_hudbar/init.lua
-- Minecraft-like HUD:
--   Hearts bottom-left (above hotbar), Armor directly above Hearts, Hunger bottom-right.
--   Uses 9x9 textures at native size. Survival-only. Engine hearts disabled.
--   Armor row auto-hides when armor = 0.
-- MIT License.

-- ==================
-- CONFIG (safe defaults; can override in minetest.conf)
-- ==================
local MAX_ICONS  = 10
local HP_MAX     = 20
local HUNGER_MAX = 20
local ARMOR_MAX  = 20

-- Your icon geometry
local ICON_PX  = tonumber(minetest.settings:get("cw_hudbar_icon_px")) or 9
local GAP_PX   = tonumber(minetest.settings:get("cw_hudbar_icon_gap_px")) or 2

-- Placement (RAW pixels; the engine multiplies these by hud_scaling automatically)
-- Tuned to sit clearly ABOVE the hotbar even with big UI scales/skins.
local HOTBAR_MARGIN_PX = tonumber(minetest.settings:get("cw_hudbar_margin_px")) or 88
local ROW_GAP_PX       = tonumber(minetest.settings:get("cw_hudbar_row_gap_px")) or 22
local SIDE_MARGIN_PX   = tonumber(minetest.settings:get("cw_hudbar_side_px"))   or 14

-- Show only in Survival
local SURVIVAL_ONLY    = true

-- Simple hunger logic (placeholder)
local HUNGER_TICK_SECONDS = 90
local REGEN_THRESHOLD     = 18
local REGEN_INTERVAL      = 4
local STARVE_AT_ZERO      = true

-- ==================
-- YOUR TEXTURES (9x9)
-- ==================
local tex = {
  heart_full = "hudbars_icon_health.png",
  heart_half = "cw_hud_heart_half.png",
  heart_empty= "hudbars_bgicon_health.png",

  food_full  = "hbhunger_icon.png",
  food_half  = "cw_hud_food_half.png",
  food_empty = "hbhunger_bgicon.png",

  armor_full = "hbarmor_icon.png",
  armor_half = "cw_hud_armor_half.png",
  armor_empty= "hbarmor_bgicon.png",
}

-- ==================
-- STATE
-- ==================
local players = {}
-- players[name] = {
--   visible = bool,
--   hud = { hearts={ids}, hunger={ids}, armor={ids} },
--   stats = { hp_max=20, hunger=20, armor=0 },
--   timers = { hunger=0, regen=0 },
-- }

-- ==================
-- UTIL
-- ==================
local function clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi else return v end end
local function to_half_points(p) p = clamp(p,0,20); return math.floor(p*2+0.5)/2 end

local function row_total_width()
  return MAX_ICONS * ICON_PX + (MAX_ICONS - 1) * GAP_PX
end

-- Compute per-icon params.
-- side: "left" or "right"; tier: 1(bottom row at that side), 2(row above)
local function icon_params(i, tier, side)
  local y = HOTBAR_MARGIN_PX + (tier - 1) * ROW_GAP_PX
  if side == "left" then
    local x = SIDE_MARGIN_PX + (i - 1) * (ICON_PX + GAP_PX)
    return {x=x,  y=-y}, {x=0, y=0}, {x=0.0, y=1.0}
  else
    local x = SIDE_MARGIN_PX + (MAX_ICONS - i) * (ICON_PX + GAP_PX)
    return {x=-x, y=-y}, {x=0, y=0}, {x=1.0, y=1.0}
  end
end

local function add_icon(player, off, align, pos, texture)
  return player:hud_add({
    hud_elem_type = "image",
    position = pos,                 -- bottom-left (0,1) or bottom-right (1,1)
    offset   = off,                 -- RAW px; engine applies hud_scaling
    text     = texture,
    scale    = { x = 1, y = 1 },    -- draw at native texture size (prevents blow-up/squish)
    alignment= align,               -- neutral
    z_index  = 10,
  })
end

local function create_row(player, side, tier, full_tex, half_tex, empty_tex)
  local ids = {}
  for i = 1, MAX_ICONS do
    local off, align, pos = icon_params(i, tier, side)
    ids[i] = add_icon(player, off, align, pos, empty_tex)
  end
  return { ids = ids, full = full_tex, half = half_tex, empty = empty_tex, side=side, tier=tier }
end

local function update_row(player, row, value_points)
  if not row or not row.ids then return end
  local p2 = clamp(value_points, 0, 20)
  local full_icons = math.floor(p2 / 2)
  local half_icon  = ((p2 % 2) >= 1) and 1 or 0
  for i = 1, MAX_ICONS do
    local texname = row.empty
    if i <= full_icons then
      texname = row.full
    elseif i == full_icons + 1 and half_icon == 1 then
      texname = row.half
    end
    player:hud_change(row.ids[i], "text", texname)
  end
end

local function remove_row(player, row)
  if not row or not row.ids then return end
  for _, id in ipairs(row.ids) do if id then pcall(function() player:hud_remove(id) end) end end
end

local function in_survival(name)
  if not SURVIVAL_ONLY then return true end
  return not minetest.is_creative_enabled(name)
end

local function ensure_player_state(player)
  local name = player:get_player_name()
  local st = players[name]
  if st then return st end
  local pm = player:get_meta()
  local hunger = tonumber(pm:get_string("cw_hudbar:hunger")) or HUNGER_MAX
  local armor  = tonumber(pm:get_string("cw_hudbar:armor"))  or 0
  st = {
    visible = false,
    hud = { hearts=nil, hunger=nil, armor=nil },
    stats = { hp_max = HP_MAX, hunger = clamp(hunger,0,HUNGER_MAX), armor = clamp(armor,0,ARMOR_MAX) },
    timers = { hunger=0, regen=0 },
  }
  players[name] = st
  return st
end

local function save_meta(name)
  local obj = minetest.get_player_by_name(name)
  local st = players[name]
  if not obj or not st then return end
  local pm = obj:get_meta()
  pm:set_string("cw_hudbar:hunger", tostring(st.stats.hunger))
  pm:set_string("cw_hudbar:armor",  tostring(st.stats.armor))
end

-- ==================
-- BUILD / SHOW
-- ==================
local function show_hud(player, st)
  if st.visible then return end
  -- Left: hearts bottom (tier 1), armor above (tier 2)
  st.hud.hearts = create_row(player, "left",  1, tex.heart_full, tex.heart_half, tex.heart_empty)
  -- (armor row is created only if armor > 0; else hidden)
  if st.stats.armor > 0 then
    st.hud.armor  = create_row(player, "left",  2, tex.armor_full, tex.armor_half, tex.armor_empty)
  end
  -- Right: hunger bottom (tier 1)
  st.hud.hunger = create_row(player, "right", 1, tex.food_full,  tex.food_half,  tex.food_empty)

  update_row(player, st.hud.hearts, to_half_points(player:get_hp()))
  update_row(player, st.hud.hunger, to_half_points(st.stats.hunger))
  if st.hud.armor then update_row(player, st.hud.armor, to_half_points(st.stats.armor)) end
  st.visible = true
end

local function hide_hud(player, st)
  if not st.visible then return end
  remove_row(player, st.hud.hearts); st.hud.hearts=nil
  remove_row(player, st.hud.hunger); st.hud.hunger=nil
  if st.hud.armor then remove_row(player, st.hud.armor); st.hud.armor=nil end
  st.visible = false
end

local function refresh_visibility(player, st)
  local name = player:get_player_name()
  if in_survival(name) then
    if not st.visible then show_hud(player, st) end
  else
    if st.visible then hide_hud(player, st) end
  end
end

-- Create/destroy armor row based on current armor value
local function sync_armor_row(player, st)
  local has_row = st.hud.armor ~= nil
  if st.stats.armor > 0 and not has_row and st.visible then
    st.hud.armor = create_row(player, "left", 2, tex.armor_full, tex.armor_half, tex.armor_empty)
    update_row(player, st.hud.armor, to_half_points(st.stats.armor))
  elseif st.stats.armor <= 0 and has_row then
    remove_row(player, st.hud.armor); st.hud.armor = nil
  end
end

-- ==================
-- PUBLIC API
-- ==================
cw_hudbar = {}

function cw_hudbar.get_hunger(player) return ensure_player_state(player).stats.hunger end

function cw_hudbar.add_hunger(player, delta)
  local st = ensure_player_state(player)
  st.stats.hunger = clamp(st.stats.hunger + (delta or 0), 0, HUNGER_MAX)
  if st.visible and st.hud.hunger then
    update_row(player, st.hud.hunger, to_half_points(st.stats.hunger))
  end
  save_meta(player:get_player_name())
end

function cw_hudbar.set_hunger(player, value)
  local st = ensure_player_state(player)
  st.stats.hunger = clamp(value, 0, HUNGER_MAX)
  if st.visible and st.hud.hunger then
    update_row(player, st.hud.hunger, to_half_points(st.stats.hunger))
  end
  save_meta(player:get_player_name())
end

-- For food items: on_use = cw_hudbar.eat(points)
function cw_hudbar.eat(points)
  return function(itemstack, user, pt)
    if user and user:is_player() then cw_hudbar.add_hunger(user, points or 0) end
    return itemstack
  end
end

function cw_hudbar.set_armor(player, value)
  local st = ensure_player_state(player)
  st.stats.armor = clamp(value, 0, ARMOR_MAX)
  sync_armor_row(player, st)
  if st.visible and st.hud.armor then
    update_row(player, st.hud.armor, to_half_points(st.stats.armor))
  end
  save_meta(player:get_player_name())
end

function cw_hudbar.add_armor(player, delta)
  cw_hudbar.set_armor(player, ensure_player_state(player).stats.armor + (delta or 0))
end

-- ==================
-- HOOKS
-- ==================
minetest.register_on_joinplayer(function(player)
  -- Disable engine hearts
  player:hud_set_flags({ healthbar = false })

  local st = ensure_player_state(player)
  refresh_visibility(player, st)
  if st.visible then
    update_row(player, st.hud.hearts, to_half_points(player:get_hp()))
    update_row(player, st.hud.hunger, to_half_points(st.stats.hunger))
    sync_armor_row(player, st)
  end
end)

minetest.register_on_leaveplayer(function(player)
  if not player then return end
  local name = player:get_player_name()
  save_meta(name)
  players[name] = nil
end)

-- Keep hearts synced with engine HP
minetest.register_on_player_hpchange(function(player, hp_change, reason)
  minetest.after(0, function()
    if player and player:is_player() then
      local st = ensure_player_state(player)
      if st.visible and st.hud.hearts then
        update_row(player, st.hud.hearts, to_half_points(player:get_hp()))
      end
    end
  end)
  return hp_change
end, true)

-- Hunger/regen/starvation + visibility polling
local accum, vis_poll = 0, 0
minetest.register_globalstep(function(dtime)
  accum = accum + dtime
  vis_poll = vis_poll + dtime

  if accum >= 1 then
    local tick = accum; accum = 0
    for name, st in pairs(players) do
      local player = minetest.get_player_by_name(name)
      if not player then goto continue end

      st.timers.hunger = st.timers.hunger + tick
      if st.timers.hunger >= HUNGER_TICK_SECONDS then
        st.timers.hunger = st.timers.hunger - HUNGER_TICK_SECONDS
        if st.stats.hunger > 0 then
          st.stats.hunger = st.stats.hunger - 1
          if st.visible and st.hud.hunger then
            update_row(player, st.hud.hunger, to_half_points(st.stats.hunger))
          end
          save_meta(name)
        end
      end

      if STARVE_AT_ZERO and st.stats.hunger == 0 then
        local hp = player:get_hp()
        if hp > 1 then player:set_hp(hp - 1) end
      end

      st.timers.regen = st.timers.regen + tick
      if st.stats.hunger >= REGEN_THRESHOLD and st.timers.regen >= REGEN_INTERVAL then
        st.timers.regen = 0
        local hp = player:get_hp()
        if hp < st.stats.hp_max then player:set_hp(hp + 1) end
      end

      ::continue::
    end
  end

  if vis_poll >= 0.3 then
    vis_poll = 0
    for name, st in pairs(players) do
      local player = minetest.get_player_by_name(name)
      if player then refresh_visibility(player, st) end
    end
  end
end)

-- ==================
-- OPTIONAL demo items (remove if not needed)
-- ==================
--minetest.register_craftitem("cw_hudbar:cooked_beef", {
--  description = "Cooked Beef (fills 8 hunger)",
--  inventory_image = "cw_food_steak.png",
--  on_use = cw_hudbar.eat(8),
--})

--minetest.register_craftitem("cw_hudbar:bread", {
--  description = "Bread (fills 5 hunger)",
--  inventory_image = "cw_food_bread.png",
--  on_use = cw_hudbar.eat(5),
--})
