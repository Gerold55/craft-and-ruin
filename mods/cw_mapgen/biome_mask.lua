-- cw_mapgen/biome_mask.lua
-- Lightweight biome mask for singlenode pipelines.
-- Classifies columns as "cw_swamp" or "cw_plains" using 2D perlin + altitude vs water level.

local M = {}
cw_mapgen = cw_mapgen or {}

-- Sea level (use your game setting)
local SEA = tonumber(minetest.settings:get("water_level")) or 1

-- Tunables (change in minetest.conf if you want)
local SWAMP_NOISE_SEED   = tonumber(minetest.settings:get("cw_swamp_noise_seed"))   or 52911
local SWAMP_NOISE_SCALE  = tonumber(minetest.settings:get("cw_swamp_noise_scale"))  or 1.0
local SWAMP_NOISE_SPREAD = tonumber(minetest.settings:get("cw_swamp_noise_spread")) or 96
local SWAMP_THRESHOLD    = tonumber(minetest.settings:get("cw_swamp_threshold"))    or 0.35
local SWAMP_ALT_MAX      = tonumber(minetest.settings:get("cw_swamp_alt_max"))      or (SEA + 12)
local SWAMP_ALT_MIN      = tonumber(minetest.settings:get("cw_swamp_alt_min"))      or (SEA - 3)

local n_swamp = minetest.get_perlin({
  seed    = SWAMP_NOISE_SEED,
  octaves = 3,
  persist = 0.55,
  spread  = {x=SWAMP_NOISE_SPREAD, y=SWAMP_NOISE_SPREAD, z=SWAMP_NOISE_SPREAD},
})

-- Decide if a column (x,z) at surface y should be swamp
local function is_swamp_at(x, y, z)
  if y < SWAMP_ALT_MIN or y > SWAMP_ALT_MAX then return false end
  local v = n_swamp:get_2d({x=x, y=z}) * SWAMP_NOISE_SCALE
  return v > SWAMP_THRESHOLD
end

-- API: fast query by position (provide surface_y)
function M.get_biome_at(x, y, z)
  return is_swamp_at(x, y, z) and "cw_swamp" or "cw_plains"
end

cw_mapgen.get_biome_at = M.get_biome_at

-- ---------- Integrate with your tint system ----------
-- If you already use cw_core.biome_tint.* the grass/leaves/decor will pick consistent indices.
cw_core = rawget(_G, "cw_core") or {}
cw_core.biome_tint = cw_core.biome_tint or {}

-- Preferred palette indices (0..15). Adjust to your palette.
local PREF_IDX = {
  cw_plains = 2,   -- your existing plains index
  cw_swamp  = 3,   -- slightly darker/olive
}

-- Returns preferred grass index at pos using our mask; falls back to humidity mapping if needed
local function surface_biome_pref_index(pos)
  -- You can pass in the real surface y if you have it; otherwise this is "good enough"
  local y = pos.y or SEA
  local b = M.get_biome_at(pos.x, y, pos.z)
  return PREF_IDX[b]
end

function cw_core.biome_tint.preferred_grass_index(pos)
  return surface_biome_pref_index(pos)
end
function cw_core.biome_tint.preferred_leaf_index(pos)
  return surface_biome_pref_index(pos)
end

-- Gentle clamps so extremes never show up
function cw_core.biome_tint.clamp_grass_index(_, idx) return math.max(2, math.min(12, idx)) end
function cw_core.biome_tint.clamp_leaf_index(_, idx)  return math.max(2, math.min(12, idx)) end

return M
