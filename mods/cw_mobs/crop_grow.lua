-- cw_mobs/crop_grow.lua
-- Advance crops exactly one stage when bees pollinate them.

cw_mobs = rawget(_G, "cw_mobs") or {}
cw_mobs._crop_next = cw_mobs._crop_next or {}

-- Optional: explicit chains if your names are irregular
function cw_mobs.register_crop_chain(chain)
  for i=1, #chain-1 do
    cw_mobs._crop_next[chain[i]] = chain[i+1]
  end
end

-- Optional: auto series like prefix.."0"..max (e.g., "cw_core:wheat_" 0..7)
function cw_mobs.register_crop_series(prefix, min_stage, max_stage)
  for i=min_stage, max_stage-1 do
    local cur = prefix..i
    local nxt = prefix..(i+1)
    if minetest.registered_nodes[cur] and minetest.registered_nodes[nxt] then
      cw_mobs._crop_next[cur] = nxt
    end
  end
end

-- Param2-based stages: set groups = { crop_stage_by_param2=1, crop_stage_max=7 }
local function bump_param2_if_supported(pos, node)
  local def = minetest.registered_nodes[node.name]; if not def then return false end
  if (def.groups and def.groups.crop_stage_by_param2 == 1) then
    local max = (def.groups.crop_stage_max or 0)
    local p2  = node.param2 or 0
    if p2 < max then
      node.param2 = p2 + 1
      minetest.swap_node(pos, node)
      return true
    end
  end
  return false
end

function cw_mobs.grow_crop(pos, node)
  node = node or minetest.get_node(pos)
  if not node or not node.name then return false end

  -- 1) explicit map wins
  local nxt = cw_mobs._crop_next[node.name]
  if nxt and minetest.registered_nodes[nxt] then
    minetest.swap_node(pos, {name=nxt})
    return true
  end

  -- 2) common suffix patterns
  local base, num = node.name:match("^(.-)_stage_(%d+)$")
  if base and num then
    local n = tonumber(num)
    local candidate = base.."_stage_"..(n+1)
    if minetest.registered_nodes[candidate] then
      minetest.swap_node(pos, {name=candidate})
      return true
    end
  end
  base, num = node.name:match("^(.-)_(%d+)$")
  if base and num then
    local n = tonumber(num)
    local candidate = base.."_"..(n+1)
    if minetest.registered_nodes[candidate] then
      minetest.swap_node(pos, {name=candidate})
      return true
    end
  end

  -- 3) param2 scheme
  if bump_param2_if_supported(pos, node) then return true end

  return false
end
