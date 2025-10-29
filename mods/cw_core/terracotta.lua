-- cw_core/terracotta.lua
-- Base + 15 colored terracotta blocks (no cyan); exposes a lookup table.

local modname = minetest.get_current_modname() or "cw_core"
local M = rawget(_G, "cw_core") or {}
_G.cw_core = M

-- ===== Texture naming =======================================================
local BASE_TERRACOTTA_TEX = "cw_terracotta.png"  -- the normal baked terracotta

local PREFIX, EXT = "cw_terracotta_", ".png"
local function make_tex(color_id) return PREFIX .. color_id .. EXT end

-- ===== Sounds (safe even without MTG) ======================================
local STONE_SOUNDS = (default and default.node_sound_stone_defaults)
  and default.node_sound_stone_defaults() or nil

-- ===== Colors (cyan removed) ===============================================
local COLORS = {
  { id="white",      label="White"      },
  { id="orange",     label="Orange"     },
  { id="magenta",    label="Magenta"    },
  { id="lite_blue",  label="Light Blue" },
  { id="yellow",     label="Yellow"     },
  { id="lime",       label="Lime"       },
  { id="pink",       label="Pink"       },
  { id="gray",       label="Gray"       },
  { id="lite_gray",  label="Light Gray" },
  -- { id="cyan",    label="Cyan" }, -- intentionally omitted
  { id="purple",     label="Purple"     },
  { id="blue",       label="Blue"       },
  { id="brown",      label="Brown"      },
  { id="green",      label="Green"      },
  { id="red",        label="Red"        },
  { id="black",      label="Black"      },
}

-- ===== Public registry ======================================================
M.TERRACOTTA = {
  base     = nil,
  list     = {},      -- array of all COLORED variant names
  by_color = {},      -- map id -> nodename
  colors   = {},      -- ordered list of ids (for iteration)
}

function M.TERRACOTTA.get(color_id)
  return M.TERRACOTTA.by_color[color_id]
end

function M.TERRACOTTA.foreach(fn)
  for _, spec in ipairs(COLORS) do
    local name = M.TERRACOTTA.by_color[spec.id]
    if name then fn(spec.id, name, spec) end
  end
end

-- ===== Base groups ==========================================================
local BASE_GROUPS = { cracky = 3, stone = 1, terracotta = 1 }

-- ===== Register base terracotta ============================================
local base_name = ("%s:terracotta"):format(modname)
minetest.register_node(base_name, {
  description = "Terracotta",
  tiles = { BASE_TERRACOTTA_TEX },
  is_ground_content = false,
  groups = BASE_GROUPS,
  sounds = STONE_SOUNDS,
})
M.TERRACOTTA.base = base_name

-- ===== Register colored variants ===========================================
for _, spec in ipairs(COLORS) do
  local nodename = ("%s:terracotta_%s"):format(modname, spec.id)

  minetest.register_node(nodename, {
    description = ("%s Terracotta"):format(spec.label),
    tiles = { make_tex(spec.id) },
    is_ground_content = false,
    groups = BASE_GROUPS,
    sounds = STONE_SOUNDS,
    _cw_color_id = spec.id,
  })

  table.insert(M.TERRACOTTA.list, nodename)
  M.TERRACOTTA.by_color[spec.id] = nodename
  table.insert(M.TERRACOTTA.colors, spec.id)
end

-- Convenience alias (allows cw_terracotta.red etc.)
cw_terracotta = setmetatable({}, {
  __index = function(_, k)
    if k == "base" then return M.TERRACOTTA.base end
    return M.TERRACOTTA.by_color[k]
  end
})

-- ===== Optional aliases if you ever need them ==============================
-- minetest.register_alias("cw_core:terracotta_light_gray", modname..":terracotta_lite_gray")
-- minetest.register_alias("cw_core:terracotta_light_blue", modname..":terracotta_lite_blue")
-- minetest.register_alias("cw_core:terracotta_cyan", modname..":terracotta_blue") -- or "air"
