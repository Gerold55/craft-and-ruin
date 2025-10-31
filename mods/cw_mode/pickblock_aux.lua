-- cw_mode / pickblock_aux.lua
-- AUX1-only Pick Block with smart hotbar placement / swapping
-- MIT License

-- ===== Config =====
local RAY_DIST    = 8         -- how far to look for a node
local COOLDOWN_MS = 180       -- debounce to avoid repeats while holding AUX1
-- Hotbar length: try setting first, fall back to common defaults
local DEFAULT_HOTBAR = tonumber(minetest.settings:get("hotbar_items")) or 10

-- ===== Helpers =====
local function now_us()
  if minetest.get_us_time then return minetest.get_us_time() end
  return (minetest.get_gametime() or 0) * 1e6
end

local function is_creative_like(name)
  return (minetest.is_creative_enabled and minetest.is_creative_enabled(name))
      or (minetest.registered_privileges.creative and minetest.check_player_privs(name, {creative=true}))
      or minetest.check_player_privs(name, {cw_cheat=true})
end

local function raycast_node_name(player, dist)
  dist = dist or RAY_DIST
  local pos = player:get_pos(); if not pos then return end
  local eyeh = (player:get_properties().eye_height or 1.625)
  local eye  = {x=pos.x, y=pos.y + eyeh, z=pos.z}
  local dir  = player:get_look_dir()
  local to   = {x=eye.x + dir.x * dist, y=eye.y + dir.y * dist, z=eye.z + dir.z * dist}

  for hit in minetest.raycast(eye, to, true, false) do
    if hit.type == "node" and hit.under then
      local n = minetest.get_node(hit.under)
      if n and n.name and n.name ~= "air" and minetest.registered_nodes[n.name] then
        return n.name
      end
    end
  end
end

-- Move an inventory stack to the first empty hotbar slot and select it,
-- or swap with wield if no empty slot.
local function move_to_hotbar_or_swap(player, itemname)
  local inv = player:get_inventory(); if not inv then return end
  local size_main = inv:get_size("main") or 0
  if size_main <= 0 then return end

  local wield_idx = player:get_wield_index()
  local hotbar_len = math.min(DEFAULT_HOTBAR, size_main)

  -- Find an existing stack of the item anywhere in main
  local found_idx
  for i = 1, size_main do
    local st = inv:get_stack("main", i)
    if not st:is_empty() and st:get_name() == itemname then
      found_idx = i
      break
    end
  end
  if not found_idx then return false end

  -- Already wielding it? done.
  if found_idx == wield_idx then return true end

  -- Look for first empty slot in hotbar
  local empty_hotbar_idx
  for i = 1, hotbar_len do
    if inv:get_stack("main", i):is_empty() then
      empty_hotbar_idx = i
      break
    end
  end

  if empty_hotbar_idx then
    -- Move found stack into empty hotbar slot
    local found_stack = inv:get_stack("main", found_idx)
    inv:set_stack("main", empty_hotbar_idx, found_stack)
    inv:set_stack("main", found_idx, ItemStack(nil))

    -- Swap that hotbar slot with wield to make it selected
    local wield_stack  = inv:get_stack("main", wield_idx)
    local picked_stack = inv:get_stack("main", empty_hotbar_idx)
    inv:set_stack("main", wield_idx, picked_stack)
    inv:set_stack("main", empty_hotbar_idx, wield_stack)
    return true
  else
    -- Hotbar full → swap found stack with current wield
    local wield_stack = inv:get_stack("main", wield_idx)
    local found_stack = inv:get_stack("main", found_idx)
    inv:set_stack("main", wield_idx, found_stack)
    inv:set_stack("main", found_idx, wield_stack)
    return true
  end
end

local function do_pickblock(pname)
  local player = minetest.get_player_by_name(pname); if not player then return end
  local itemname = raycast_node_name(player, RAY_DIST); if not itemname then return end

  -- 1) If item exists in inventory → hotbar move/swap behavior
  if move_to_hotbar_or_swap(player, itemname) then
    return
  end

  -- 2) Not in inventory
  local inv = player:get_inventory(); if not inv then return end
  local wield_idx = player:get_wield_index()

  if is_creative_like(pname) then
    inv:set_stack("main", wield_idx, ItemStack(itemname .. " 1"))
    return
  end

  -- Optional: allow cw_cheat to conjure 1 even in survival
  if minetest.check_player_privs(pname, {cw_cheat=true}) then
    inv:set_stack("main", wield_idx, ItemStack(itemname .. " 1"))
  end
end

-- ===== Driver: AUX1 edge press with debounce =====
local last_aux_state = {} -- [playername] = bool
local last_press_us  = {} -- [playername] = timestamp
local COOLDOWN_US    = (COOLDOWN_MS or 0) * 1000

minetest.register_on_leaveplayer(function(p)
  if not p or not p:is_player() then return end
  local n = p:get_player_name()
  last_aux_state[n] = nil
  last_press_us[n]  = nil
end)

minetest.register_globalstep(function(dtime)
  for _, p in ipairs(minetest.get_connected_players()) do
    local name = p:get_player_name()
    local ctrl = p:get_player_control() or {}
    local prev = last_aux_state[name] or false
    local nowv = not not ctrl.aux1

    if nowv and not prev then
      local t  = now_us()
      local lt = last_press_us[name] or 0
      if (t - lt) >= COOLDOWN_US then
        do_pickblock(name)
        last_press_us[name] = t
      end
    end

    last_aux_state[name] = nowv
  end
end)
