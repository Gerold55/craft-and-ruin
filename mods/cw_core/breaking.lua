-- cw_core/breaking.lua
-- Hand/tool breaking setup + punch/dig hooks for animation & FX

local MOD = "cw_core"

-- ---------------------------------------
-- 1) Give the player hand real dig power
-- ---------------------------------------
-- This makes “bare hand” able to break dirt/grass/leaves/flowers quickly,
-- wood slowly, and stone not by hand (like MC).
minetest.register_item(":", {
  type = "none",
  wield_image = "cw_hand.png", -- optional; add the texture if you have one
  wield_scale = {x=1, y=1, z=1},
  range = 4.0,

  tool_capabilities = {
    full_punch_interval = 0.9,
    max_drop_level = 0,
    damage_groups = {fleshy = 1},

    groupcaps = {
      -- dirt/grass/sand/etc.
      crumbly = {
        times = { [1]=2.0, [2]=0.7, [3]=0.3 },
        uses = 0, maxlevel = 1
      },
      -- leaves/flowers/plants
      snappy = {
        times = { [1]=1.5, [2]=0.6, [3]=0.2 },
        uses = 0, maxlevel = 1
      },
      -- wood (slow by hand)
      choppy = {
        times = { [1]=3.0, [2]=1.6, [3]=0.9 },
        uses = 0, maxlevel = 1
      },
      -- stone (intentionally omitted, so hand can’t mine stone)
    },
    punch_attack_uses = 0,
  },
})

-- ---------------------------------------------------
-- 2) Breaking animation while punching a breakable
-- ---------------------------------------------------
-- If you’re using player_api or your own anim system, we’ll try both.
local function set_mining_anim(player, active)
  -- If you have your own animation hook, put it here:
  if cw_core and cw_core.play_break_anim then
    cw_core.play_break_anim(player, active)
    return
  end
  -- Fallback to player_api (commonly used in subgames)
  if player_api and player_api.set_animation then
    if active then
      player_api.set_animation(player, "mine")
    else
      player_api.set_animation(player, "stand")
    end
  end
end

-- Cooldown so we don’t spam sounds while punching
local last_punch = {}

minetest.register_on_punchnode(function(pos, node, puncher, pointed)
  if not (puncher and puncher:is_player()) then return end

  -- Start/refresh mining animation
  set_mining_anim(puncher, true)

  -- Soft tick sound feedback while punching (optional)
  local name = puncher:get_player_name()
  local now = minetest.get_us_time()
  if (last_punch[name] or 0) + 180000 < now then -- 0.18s
    last_punch[name] = now
    minetest.sound_play("cw_break_tap", {pos=pos, gain=0.15, max_hear_distance=16}, true)
  end
end)

-- cw_core/compat_breaking.lua
-- Give reasonable break groups to nodes from ANY mod (non-destructive).
-- Adds crumbly/snappy/choppy/cracky heuristically if missing.

local function add_group_at_least(nodename, group, want)
  local def = minetest.registered_nodes[nodename]
  if not def then return end
  local groups = table.copy(def.groups or {})
  local cur = groups[group]
  if (not cur) or (cur < want) then
    groups[group] = want
    minetest.override_item(nodename, { groups = groups })
  end
end

-- Light heuristics so we don't overreach. Only add a group if:
--  1) Node already hints at that material via an existing group, OR
--  2) Node name strongly suggests the material, OR
--  3) It's a plantlike/leafy node (snappy)
local function classify_and_patch(name, def)
  local g = def.groups or {}
  local n = name

  -- Skip items that should never be mined like normal blocks
  if g.liquid or def.liquidtype == "source" or def.liquidtype == "flowing" then return end
  if g.immortal or g.unbreakable then return end

  -- Plants / leaves / decorations → snappy
  if g.leaves or g.flower or g.grass_decor or g.attached_node
     or def.drawtype == "plantlike" or def.drawtype == "allfaces_optional" then
    add_group_at_least(name, "snappy", g.snappy or 3)
    return
  end

  -- Dirt / soil / sand / gravel → crumbly
  if g.soil or g.spreading_dirt_type or g.sand or g.dirt
     or n:find("dirt", 1, true) or n:find("sand", 1, true) or n:find("gravel", 1, true) then
    add_group_at_least(name, "crumbly", g.crumbly or 2)
    return
  end

  -- Wood / tree / planks → choppy
  if g.tree or g.wood or n:find("log", 1, true) or n:find("wood", 1, true) or n:find("planks", 1, true) then
    add_group_at_least(name, "choppy", g.choppy or 2)
    return
  end

  -- Stone / ores → cracky (hand still won't mine: your hand has no cracky caps)
  if g.stone or g.ore or n:find("stone", 1, true) or n:find("ore_", 1, true) then
    add_group_at_least(name, "cracky", g.cracky or 3)
    return
  end

  -- Glass / ice → cracky or snappy (many games use cracky=3)
  if g.glass or def.drawtype == "glasslike" then
    add_group_at_least(name, "cracky", g.cracky or 3)
    return
  end

  -- Default fallback: if it's a normal, walkable block with no groups at all,
  -- give it a gentle "crumbly" so players aren't stuck with unbreakables.
  if def.walkable ~= false and next(g) == nil then
    add_group_at_least(name, "crumbly", 3)
  end
end

minetest.register_on_mods_loaded(function()
  for name, def in pairs(minetest.registered_nodes) do
    classify_and_patch(name, def)
  end
end)


-- ---------------------------------------------------
-- 4) Ensure common nodes are actually “breakable”
-- ---------------------------------------------------
-- ensure that a node has a given group set to at least a given value
function ensure_group(nodename, groupname, value)
    local def = minetest.registered_nodes[nodename]
    if not def then return end

    -- copy group table (don't mutate original table)
    local newgroups = table.copy(def.groups or {})

    -- only set if not present or lower
    local old = newgroups[groupname]
    if not old or old < value then
        newgroups[groupname] = value
        minetest.override_item(nodename, { groups = newgroups })
    end
end

-- Make sure core blocks respond to hand/tool mining as expected
minetest.register_on_mods_loaded(function()
  ensure_group("cw_core:dirt",          "crumbly", 2)
  ensure_group("cw_core:grass_block",   "crumbly", 2)
  ensure_group("cw_core:grass_block_snow","crumbly", 2)
  ensure_group("cw_core:sand",          "crumbly", 3)

  ensure_group("cw_core:oak_leaves",    "snappy", 3)
  ensure_group("cw_core:flower_daisy",  "snappy", 3)
  ensure_group("cw_core:flower_bluebell","snappy", 3)
  ensure_group("cw_core:grass_decor",   "snappy", 3)
  ensure_group("cw_core:reeds",         "snappy", 3)

  ensure_group("cw_core:oak_log",       "choppy", 2)
  -- stone should stay hard by hand; give it cracky group but hand lacks cracky caps
  ensure_group("cw_core:stone",         "cracky", 3)
end)
