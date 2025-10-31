-- cw_mode: Craft & Ruin mode helpers
-- - Instant dig when creative / cw_cheat
-- - Global stack rules (64 for all items; empty buckets = 16)
-- - Cheats hub with cw_cheat priv and convenience commands

local S = minetest.get_translator and minetest.get_translator("cw_mode") or function(s) return s end

dofile(minetest.get_modpath("cw_mode") .. "/pickblock_aux.lua")

local cfg_instant = minetest.settings:get_bool("cw_mode.instant_dig", true)
local cfg_force64 = minetest.settings:get_bool("cw_mode.force_stack64", true)
local cfg_take_one   = minetest.settings:get_bool("cw_mode.creative_take_one", true)
local cfg_no_drops   = minetest.settings:get_bool("cw_mode.creative_no_drops", true)
local cfg_single_node_stacks = minetest.settings:get_bool("cw_mode.creative_single_node_stacks", true)
local cfg_infinite_place     = minetest.settings:get_bool("cw_mode.creative_infinite_place", true)

-- Which privs /cr_cheats toggles
local grant_list = {
  fast     = minetest.settings:get_bool("cw_mode.cheats_grant_fast", true),
  fly      = minetest.settings:get_bool("cw_mode.cheats_grant_fly", true),
  noclip   = minetest.settings:get_bool("cw_mode.cheats_grant_noclip", true),
  give     = minetest.settings:get_bool("cw_mode.cheats_grant_give", true),
  teleport = minetest.settings:get_bool("cw_mode.cheats_grant_teleport", true),
}

-- Helper: does engine have a 'creative' concept?
local has_creative_priv = minetest.registered_privileges and minetest.registered_privileges["creative"]

-- Master cheat privilege
minetest.register_privilege("cw_cheat", {
  description = S("Craft & Ruin cheat access (instant dig, cheat commands)"),
  give_to_singleplayer = true,
})

-- Utility: creative-like state
local function is_creative_like(name)
  if minetest.is_creative_enabled and minetest.is_creative_enabled(name) then
    return true
  end
  if has_creative_priv and minetest.check_player_privs(name, {creative = true}) then
    return true
  end
  if minetest.check_player_privs(name, {cw_cheat = true}) then
    return true
  end
  return false
end

-----------------------------------------------------------------------
-- 1) Instant dig in creative / cw_cheat (with debounce)
-----------------------------------------------------------------------
if cfg_instant then
  local cooldown_ms = tonumber(minetest.settings:get("cw_mode.instant_dig_cooldown_ms")) or 120
  local COOLDOWN_US = math.max(0, cooldown_ms) * 1000
  local last_dig_us = {}

  minetest.register_on_leaveplayer(function(player)
    if player and player:is_player() then
      last_dig_us[player:get_player_name()] = nil
    end
  end)

  local function now_us()
    -- High-resolution time available in Luanti 5.5+; falls back to gametime * 1e6
    if minetest.get_us_time then return minetest.get_us_time() end
    return (minetest.get_gametime() or 0) * 1000000
  end

  minetest.register_on_punchnode(function(pos, node, puncher, pointed_thing)
    if not puncher or not puncher:is_player() then return end
    local name = puncher:get_player_name()
    if not is_creative_like(name) then return end

    -- Debounce per-player to stop multi-break when holding punch
    local t = now_us()
    local last = last_dig_us[name] or 0
    if (t - last) < COOLDOWN_US then return end
    last_dig_us[name] = t

    -- Safety checks
    if not node or not node.name or node.name == "air" then return end
    if minetest.is_protected(pos, name) then return end
    local def = minetest.registered_nodes[node.name]
    if not def or def.diggable == false then return end

    -- Only dig if we're actually pointing at this node (prevents stray digs)
    if pointed_thing and pointed_thing.under then
      local u = pointed_thing.under
      if not (u.x == pos.x and u.y == pos.y and u.z == pos.z) then
        return
      end
    end

    -- Perform the dig via engine path (preserves drops & callbacks)
    minetest.node_dig(pos, node, puncher)
  end)
end


-----------------------------------------------------------------------
-- 2) Global stack rules:
--    - All items stack to 64
--    - Empty buckets stack to 16
-----------------------------------------------------------------------

-- Known empty-bucket itemstrings. Extend this list if you have custom buckets.
local BUCKET_ITEMS = {
  ["bucket:bucket_empty"] = 16, -- default Luanti bucket mod
  -- add Craft & Ruin bucket IDs here if you have them, e.g.:
  -- ["cw_core:bucket_empty"] = 16,
}

local function enforce_stack_rules()
  for name, def in pairs(minetest.registered_items) do
    local target_max = BUCKET_ITEMS[name] or 64

    -- Tools typically ignore stack_max and remain 1 by engine design; harmless to set.
    if def.stack_max ~= target_max then
      minetest.override_item(name, { stack_max = target_max })
    end
  end
  minetest.log("action", "[cw_mode] Stack rules applied: all 64; empty buckets 16.")
end

if cfg_force64 then
  -- After all mods register their items, override stack_max
  minetest.register_on_mods_loaded(enforce_stack_rules)
end

-----------------------------------------------------------------------
-- 3) Cheats hub: toggle common privs; QoL cheat commands
-----------------------------------------------------------------------
local function set_priv(player_name, priv, enabled)
  local privs = minetest.get_player_privs(player_name)
  privs[priv] = enabled or nil
  minetest.set_player_privs(player_name, privs)
end

-- /cr_cheats on|off -> toggles common privs for self
minetest.register_chatcommand("cr_cheats", {
  params = S("on|off"),
  description = S("Enable/disable common cheat privs for yourself"),
  privs = { cw_cheat = true },
  func = function(name, param)
    param = (param or ""):lower()
    if param ~= "on" and param ~= "off" then
      return false, S("Usage: /cr_cheats on|off")
    end
    local enable = (param == "on")
    for p, enabled in pairs(grant_list) do
      if enabled and minetest.registered_privileges[p] then
        set_priv(name, p, enable)
      end
    end
    if enable then
      return true, S("Cheats enabled (fast/fly/noclip/etc as configured).")
    else
      return true, S("Cheats disabled.")
    end
  end
})

-----------------------------------------------------------------------
-- Creative inventory: limit pulls to 1 item for creative-like players
-----------------------------------------------------------------------
if cfg_take_one then
  -- Helper to check if an inventory location is a creative detached inv
  local function is_creative_detached(loc)
    if not loc or loc.type ~= "detached" then return false end
    -- Common names: "creative", "creative_main", "creative_<something>"
    return tostring(loc.name):find("^creative")
  end

  -- Pre-approval hook: cap transfer count to 1 from creative invs
  minetest.register_allow_player_inventory_action(function(player, action, inventory, info)
    local name = player and player:get_player_name() or nil
    if not name or not is_creative_like(name) then return nil end

    local loc = inventory:get_location()
    if action == "move" then
      -- Moves between lists (including detached→player)
      if is_creative_detached(loc) then
        -- allow moving at most 1
        return math.min(1, info.count or 1)
      end
    elseif action == "put" then
      -- Putting from wielded stack into player inv is fine; we only care when source is creative
      -- "put" on player inventory happens when engine copies from detached->player; still cap to 1
      if is_creative_detached(loc) then
        local stack = info.stack or ItemStack(nil)
        local want = stack:get_count()
        stack:set_count(math.min(1, want))
        return stack
      end
    elseif action == "take" then
      -- Taking from player inv into creative detached is irrelevant; no change.
    end
    return nil -- default behavior
  end)

  -- Safety: after the move, ensure count is 1 (covers edge-cases/other creative mods)
  minetest.register_on_player_inventory_action(function(player, action, inventory, info)
    local name = player and player:get_player_name() or nil
    if not name or not is_creative_like(name) then return end
    if action ~= "put" and action ~= "move" then return end

    -- If destination is the player's main list, clamp the stack in that slot to 1
    if info.to_list == "main" and info.to_index and info.to_index >= 1 then
      local inv = player:get_inventory()
      if inv then
        local st = inv:get_stack("main", info.to_index)
        if not st:is_empty() and st:get_count() > 1 then
          st:set_count(1)
          inv:set_stack("main", info.to_index, st)
        end
      end
    end
  end)
end

-----------------------------------------------------------------------
-- Creative-like players: keep NODE stacks at 1 in inventory
-- (Covers any creative UI that our inventory hooks miss)
-----------------------------------------------------------------------
if cfg_single_node_stacks then
  local sweep_step = 0.25 -- seconds; light load
  local acc = 0

  minetest.register_globalstep(function(dtime)
    acc = acc + dtime
    if acc < sweep_step then return end
    acc = 0

    for _, player in ipairs(minetest.get_connected_players()) do
      local name = player:get_player_name()
      if is_creative_like(name) then
        local inv = player:get_inventory()
        if inv then
          local size = inv:get_size("main") or 0
          for i = 1, size do
            local st = inv:get_stack("main", i)
            if not st:is_empty() then
              local itemname = st:get_name()
              if minetest.registered_nodes[itemname] and st:get_count() > 1 then
                st:set_count(1)
                inv:set_stack("main", i, st)
              end
            end
          end
        end
      end
    end
  end)
end


-----------------------------------------------------------------------
-- Creative-like players: placing nodes doesn't consume them
-----------------------------------------------------------------------
if cfg_infinite_place then
  minetest.register_on_placenode(function(pos, newnode, placer, oldnode, itemstack, pointed_thing)
    if not placer or not placer:is_player() then return end
    local name = placer:get_player_name()
    if not is_creative_like(name) then return end

    -- Only for nodes (blocks/torches/rails/etc)
    local placed = itemstack and not itemstack:is_empty() and itemstack:get_name() or newnode.name
    if not placed or not minetest.registered_nodes[placed] then return end

    local inv = placer:get_inventory()
    if not inv then return end
    local idx = placer:get_wield_index()
    if not idx or idx < 1 then return end

    -- Restore/keep exactly 1 of the placed node in the wield slot
    local current = inv:get_stack("main", idx)
    -- If some items consumed or slot emptied, refill to 1 of the same node
    if current:is_empty() or current:get_name() ~= placed or current:get_count() < 1 then
      local st = ItemStack(placed .. " 1")
      inv:set_stack("main", idx, st)
    else
      -- If the count decremented (e.g., became 0 or <1), clamp back to 1
      if current:get_count() ~= 1 then
        current:set_count(1)
        inv:set_stack("main", idx, current)
      end
    end
  end)
end

-----------------------------------------------------------------------
-- No drops when creative-like players dig nodes
-----------------------------------------------------------------------
if cfg_no_drops then
  -- Remove any drops that were added to inventory and clean nearby item entities
  local ITEM_ENTITY_NAMES = { "__builtin:item", "item" } -- engine/game variants

  minetest.register_on_dignode(function(pos, oldnode, digger)
    if not digger or not digger:is_player() then return end
    local pname = digger:get_player_name()
    if not is_creative_like(pname) then return end

    -- 1) Remove item entities spawned by the dig (if any)
    for _, obj in ipairs(minetest.get_objects_inside_radius(pos, 2)) do
      local ent = obj:get_luaentity()
      if ent and ent.name then
        for _, n in ipairs(ITEM_ENTITY_NAMES) do
          if ent.name == n then
            obj:remove()
            break
          end
        end
      end
    end

    -- 2) Remove items that might have been added to player inventory
    local inv = digger:get_inventory()
    if not inv then return end

    -- Compute theoretical drops for this node with the current tool
    local wield = digger:get_wielded_item()
    local drops = minetest.get_node_drops(oldnode.name, wield:get_name())

    -- Consolidate similar drops (e.g., {"default:cobble", "default:cobble 2"})
    local counts = {}
    for _, d in ipairs(drops) do
      local st = ItemStack(d)
      if not st:is_empty() then
        local k = st:get_name()
        counts[k] = (counts[k] or 0) + (st:get_count() or 1)
      end
    end

    -- Remove those from inventory (ignore if not present)
    for itemname, count in pairs(counts) do
      if count > 0 then
        inv:remove_item("main", ItemStack(itemname .. " " .. count))
      end
    end
  end)
end

-- /cr_gm creative|survival -> toggle creative priv if present
minetest.register_chatcommand("cr_gm", {
  params = S("creative|survival"),
  description = S("Switch your game mode (requires appropriate privileges)"),
  func = function(name, param)
    param = (param or ""):lower()
    if param ~= "creative" and param ~= "survival" then
      return false, S("Usage: /cr_gm creative|survival")
    end

    if has_creative_priv then
      if not (minetest.check_player_privs(name, {cw_cheat = true}) or minetest.check_player_privs(name, {server = true})) then
        return false, S("You lack permission to change your game mode.")
      end
      set_priv(name, "creative", (param == "creative"))
      return true, S("Set mode to ")..param..S(".")
    else
      -- No creative priv in this game: fall back to cw_cheat behavior.
      if param == "creative" then
        if not minetest.check_player_privs(name, {cw_cheat = true}) then
          return false, S("No creative system present; grant yourself 'cw_cheat' to use instant dig.")
        end
        return true, S("Creative-like behavior enabled via cw_cheat (instant dig).")
      else
        return true, S("Survival selected. Remove 'cw_cheat' with /revoke ")..name..S(" cw_cheat for true survival behavior.")
      end
    end
  end
})

-- /cr_time day|night|noon|midnight|<0..1>
minetest.register_chatcommand("cr_time", {
  params = S("day|night|noon|midnight|<0..1>"),
  description = S("Set world time (cheat)"),
  privs = { cw_cheat = true },
  func = function(_, param)
    param = (param or ""):lower()
    local map = { day = 0.23, night = 0.73, noon = 0.5, midnight = 0.0 }
    local v = map[param]
    if not v then
      v = tonumber(param)
      if not v or v < 0 or v > 1 then
        return false, S("Usage: /cr_time day|night|noon|midnight|<0..1>")
      end
    end
    minetest.set_timeofday(v)
    return true, S("Time set.")
  end
})

-- /cr_heal [<hp>] (default: to full)
minetest.register_chatcommand("cr_heal", {
  params = S("[hp]"),
  description = S("Heal yourself (cheat)"),
  privs = { cw_cheat = true },
  func = function(name, param)
    local player = minetest.get_player_by_name(name)
    if not player then return false, S("Player not found.") end
    local max = player:get_properties().hp_max or 20
    local v = tonumber(param) or max
    v = math.max(0, math.min(v, max))
    player:set_hp(v)
    return true, S("Healed to ")..v..S(" HP.")
  end
})

-- /cr_give <item> [count] (clamped to 64)
minetest.register_chatcommand("cr_give", {
  params = S("<item> [count]"),
  description = S("Give yourself an item (count clamped to 64)"),
  privs = { cw_cheat = true },
  func = function(name, param)
    local item, count = param:match("^%s*(%S+)%s*(%S*)%s*$")
    if not item or item == "" then
      return false, S("Usage: /cr_give <item> [count]")
    end
    count = tonumber(count) or 1
    count = math.max(1, math.min(64, count))
    if not minetest.registered_items[item] then
      return false, S("Unknown item: ")..item
    end
    local inv = minetest.get_inventory({type="player", name=name})
    if not inv then return false, S("No inventory.") end
    local stack = ItemStack(item.." "..count)
    local leftover = inv:add_item("main", stack)
    if not leftover:is_empty() then
      local player = minetest.get_player_by_name(name)
      if player then
        minetest.add_item(player:get_pos(), leftover)
      end
    end
    return true, S("Gave ")..count..S("x ")..item
  end
})
