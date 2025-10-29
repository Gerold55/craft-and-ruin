-- cw_core/nodes_building.lua
-- MIT License. Self-contained: glass, stairs, slabs, 2-node doors (hinged L/R, 2/16 thick, wall-aware, texture flip),
-- trapdoors (single texture), and example crafts.

local modname = minetest.get_current_modname() or "cw_core"

-- ======================
-- Small utilities
-- ======================
local function tcopy(src)
  local dst = {}
  for k,v in pairs(src or {}) do dst[k] = v end
  return dst
end

local function tmerge(a, b)
  local out = tcopy(a or {})
  for k,v in pairs(b or {}) do out[k] = v end
  return out
end

local function sound_defaults()
  return {
    footstep = {name="", gain=0},
    dug      = {name="", gain=0},
    dig      = {name="", gain=0},
    place    = {name="", gain=0},
  }
end

local function can_modify(pos, player)
  return player and not minetest.is_protected(pos, player:get_player_name())
end

local function swapnode(pos, name, param2)
  local n = minetest.get_node(pos)
  if not n or n.name == "ignore" then return end
  n.name = name
  if param2 ~= nil then n.param2 = param2 end
  minetest.swap_node(pos, n)
end

-- ======================
-- Glass
-- ======================
minetest.register_node("cw_core:glass", {
  description = "Glass",
  drawtype = "glasslike",
  tiles = {"cw_glass.png"},
  use_texture_alpha = "blend",
  paramtype = "light",
  sunlight_propagates = true,
  is_ground_content = false,
  groups = {cracky=3, oddly_breakable_by_hand=3},
  sounds = sound_defaults(),
})

minetest.register_node("cw_core:glass_framed", {
  description = "Framed Glass",
  drawtype = "glasslike_framed_optional",
  tiles = {"cw_glass.png", "cw_glass.png", "cw_glass.png"},
  use_texture_alpha = "blend",
  paramtype = "light",
  sunlight_propagates = true,
  is_ground_content = false,
  groups = {cracky=3, oddly_breakable_by_hand=3},
  sounds = sound_defaults(),
})

-- ======================
-- Base blocks (examples)
-- ======================
minetest.register_node("cw_core:stone", {
  description = "Stone",
  tiles = {"cw_stone.png"},
  groups = {cracky=3, stone=1},
  sounds = sound_defaults(),
})

minetest.register_node("cw_core:planks_oak", {
  description = "Oak Planks",
  tiles = {"oak_planks.png"},
  groups = {choppy=2, oddly_breakable_by_hand=2, wood=1},
  sounds = sound_defaults(),
})

-- ======================
-- Stairs & Slabs mini-API
-- ======================
local function register_slab(def)
  -- def: {basename, desc, texture, groups, sounds, base_node}
  local name = def.basename.."_slab"
  minetest.register_node(name, {
    description = def.desc.." Slab",
    tiles = {def.texture},
    paramtype = "light",
    drawtype = "nodebox",
    paramtype2 = "facedir",
    node_box = { type="fixed", fixed = { {-0.5,-0.5,-0.5, 0.5,0.0,0.5} } },
    selection_box = { type="fixed", fixed = {-0.5,-0.5,-0.5, 0.5,0.0,0.5} },
    groups = tcopy(def.groups or {}),
    sounds = def.sounds or sound_defaults(),

    -- Merge behavior & top placement
    on_place = function(itemstack, placer, pointed)
      if not placer or not pointed or pointed.type ~= "node" then
        return minetest.item_place(itemstack, placer, pointed)
      end
      local under, above = pointed.under, pointed.above
      local playername = placer:get_player_name()
      if minetest.is_protected(above, playername) then return itemstack end

      -- Merge two lower slabs -> full block
      local n_under = minetest.get_node(under)
      if n_under.name == name then
        if not minetest.is_creative_enabled(playername) then itemstack:take_item() end
        minetest.set_node(under, {name = def.base_node})
        return itemstack
      end

      -- Place as upper slab if clicking underside
      local dy = above.y - under.y
      local place_upper = (dy < 0)
      if place_upper then
        local upper_name = name.."_top"
        if not minetest.registered_nodes[upper_name] then
          minetest.register_node(upper_name, {
            description = def.desc.." Slab (Top)",
            tiles = {def.texture},
            paramtype = "light",
            drawtype = "nodebox",
            node_box = { type="fixed", fixed = { {-0.5,0.0,-0.5, 0.5,0.5,0.5} } },
            selection_box = { type="fixed", fixed = {-0.5,0.0,-0.5, 0.5,0.5,0.5} },
            groups = tcopy(def.groups or {}), drop = name,
            sounds = def.sounds or sound_defaults(),
          })
        end
        if not minetest.is_creative_enabled(playername) then itemstack:take_item() end
        minetest.set_node(above, {name = upper_name})
        return itemstack
      end

      return minetest.item_place(itemstack, placer, pointed)
    end,
  })
end

local function register_stair(def)
  local name = def.basename.."_stair"
  minetest.register_node(name, {
    description = def.desc.." Stair",
    tiles = {def.texture},
    paramtype = "light",
    drawtype = "nodebox",
    paramtype2 = "facedir",
    node_box = {
      type = "fixed",
      fixed = {
        {-0.5,-0.5,-0.5,  0.5, 0.0, 0.5},
        {-0.5, 0.0, 0.0,  0.5, 0.5, 0.5},
      }
    },
    groups = tcopy(def.groups or {}),
    sounds = def.sounds or sound_defaults(),
  })
end

local function register_stairs_and_slabs(basename, desc, texture, base_node, groups)
  local common = {
    basename = basename, desc = desc, texture = texture,
    base_node = base_node, groups = groups, sounds = sound_defaults()
  }
  register_slab(common)
  register_stair(common)
end

register_stairs_and_slabs("cw_core:stone",        "Stone", "cw_stone.png",   "cw_core:stone",      {cracky=3, stone=1})
register_stairs_and_slabs("cw_core:planks_oak",   "Oak",   "oak_planks.png", "cw_core:planks_oak", {choppy=2, oddly_breakable_by_hand=2, wood=1})

-- ======================
-- 2-NODE DOOR (hinged L/R, 2/16 thick, auto-mirror, wall-aware, handle flip on right-hinge)
-- ======================
local DOOR_PREFIX      = "cw_core:door_wood"
local DOOR_TEX_BOTTOM  = "cw_oak_door_bottom.png" -- exact filenames per user
local DOOR_TEX_TOP     = "cw_oak_door_top.png"    -- exact filenames per user

-- Thickness = 2/16 = 0.125 → 0.5 - 0.125 = 0.375
local BOX_CLOSED = { {-0.5,-0.5, 0.375, 0.5, 0.5, 0.5} }   -- door leaf near +Z
local BOX_OPEN_R = { { 0.375,-0.5,-0.5, 0.5, 0.5, 0.5} }   -- swings to +X (right hinge)
local BOX_OPEN_L = { {-0.5,-0.5,-0.5, -0.375,0.5, 0.5} }   -- swings to -X (left hinge)

-- Facedir helpers
local FD2DIR = {
  [0]={x=0,y=0,z=1},  -- facing +Z
  [1]={x=1,y=0,z=0},  -- +X
  [2]={x=0,y=0,z=-1}, -- -Z
  [3]={x=-1,y=0,z=0}, -- -X
}
local function left_of(dir)  return {x=-dir.z, y=0, z= dir.x} end
local function right_of(dir) return {x= dir.z, y=0, z=-dir.x} end
local function add(a,b) return {x=a.x+b.x, y=a.y+b.y, z=a.z+b.z} end

-- Name helpers
local function node_name(prefix, top, open, hinge) -- hinge = "l" or "r"
  return string.format("%s_%s_%s_%s", prefix, top and "top" or "bottom", open and "open" or "closed", hinge)
end

-- Texture flip helper: handle painted on RIGHT edge → flip for right-hinge so handle faces center/away from wall.
-- Minetest face order: {up, down, right, left, back, front}
local function door_tiles_for(top, hinge)
  local base = top and DOOR_TEX_TOP or DOOR_TEX_BOTTOM
  if hinge == "l" then
    -- Left hinge: inside/front = unflipped; outside/back = flipped
    return {
      base,        -- up
      base,        -- down
      base,        -- right
      base,        -- left
      base.."^[transformFX", -- back (outside) flipped
      base,        -- front (inside) normal
    }
  else
    -- Right hinge: inside/front = flipped; outside/back = unflipped
    return {
      base,        -- up
      base,        -- down
      base,        -- right
      base,        -- left
      base,        -- back (outside) normal
      base.."^[transformFX", -- front (inside) flipped
    }
  end
end

-- Registrar for a specific half/open/hinge
local function door_node(prefix, desc, top, open, hinge)
  minetest.register_node(node_name(prefix, top, open, hinge), {
    description = desc .. (top and " (Top)" or " (Bottom)") .. (hinge=="l" and " [Left]" or " [Right]"),
    tiles = door_tiles_for(top, hinge),
    drawtype = "nodebox",
    paramtype = "light",
    paramtype2 = "facedir",
    use_texture_alpha = "clip",
    sunlight_propagates = true,
    is_ground_content = false,
    node_box = { type = "fixed",
      fixed = (open and (hinge=="r" and BOX_OPEN_R or BOX_OPEN_L) or BOX_CLOSED)
    },
    selection_box = { type = "fixed",
      fixed = (open and (hinge=="r" and BOX_OPEN_R or BOX_OPEN_L) or BOX_CLOSED)
    },
    groups = {choppy=2, oddly_breakable_by_hand=2, door=1, not_in_creative_inventory=1},
    sounds = sound_defaults(),
    drop = "",

    on_rightclick = function(pos, node, clicker, itemstack)
      if not can_modify(pos, clicker) then return itemstack end
      local facedir = node.param2 or 0
      local is_top_here = node.name:find("_top_") ~= nil
      local my_hinge = node.name:sub(-1) -- "l" or "r"
      local base = is_top_here and {x=pos.x,y=pos.y-1,z=pos.z} or pos
      local bot  = base
      local topP = {x=base.x, y=base.y+1, z=base.z}
      local now_open = node.name:find("_open_") ~= nil
      local new_open = not now_open

      swapnode(bot,  node_name(prefix, false, new_open, my_hinge), facedir)
      swapnode(topP, node_name(prefix,  true, new_open, my_hinge), facedir)
      return itemstack
    end,

    after_destruct = function(pos, oldnode)
      local partner = oldnode.name:find("_top_") and {x=pos.x,y=pos.y-1,z=pos.z} or {x=pos.x,y=pos.y+1,z=pos.z}
      local n = minetest.get_node_or_nil(partner)
      if n and n.name:find(prefix)==1 then minetest.remove_node(partner) end
    end,
  })
end

-- Register 8 nodes: (top/bottom) × (open/closed) × (hinge L/R)
for _,hinge in ipairs({"l","r"}) do
  door_node(DOOR_PREFIX, "Wooden Door", false, false, hinge)
  door_node(DOOR_PREFIX, "Wooden Door",  true, false, hinge)
  door_node(DOOR_PREFIX, "Wooden Door", false,  true, hinge)
  door_node(DOOR_PREFIX, "Wooden Door",  true,  true, hinge)
end

-- Hinge decision helpers
local function is_walkable_node(name)
  local def = minetest.registered_nodes[name]
  return def and def.walkable == true
end

-- Wall-aware, then mirror next to existing door, then player lateral fallback.
local function choose_hinge_on_place(pos, facedir, placer)
  local dir = FD2DIR[facedir] or {x=0,y=0,z=1}
  local L  = {x=-dir.z, y=0, z= dir.x}   -- left of facing
  local R  = {x= dir.z, y=0, z=-dir.x}   -- right of facing
  local left_pos  = {x=pos.x+L.x, y=pos.y, z=pos.z+L.z}
  local right_pos = {x=pos.x+R.x, y=pos.y, z=pos.z+R.z}

  -- 1) Prefer hinge on wall side so handle (opposite edge) is away from wall.
  local left_solid  = is_walkable_node(minetest.get_node(left_pos).name)
  local right_solid = is_walkable_node(minetest.get_node(right_pos).name)
  if left_solid and not right_solid then  return "l" end
  if right_solid and not left_solid then  return "r" end

  -- 2) Mirror if neighbor door exists (same facing).
  local function bottom_name_at(p)
    local n = minetest.get_node(p).name
    if n:find(DOOR_PREFIX.."_bottom_") == 1 then return n end
    return nil
  end
  local left_door  = bottom_name_at(left_pos)
  local right_door = bottom_name_at(right_pos)
  if left_door then   return "r" end  -- mirror the neighbor (handles meet)
  if right_door then  return "l" end

  -- 3) Fallback: player lateral position relative to doorway center.
  if placer then
    local p = placer:get_pos() or {x=pos.x, y=pos.y, z=pos.z}
    local rel = (p.x - (pos.x + 0.5)) * L.x + (p.z - (pos.z + 0.5)) * L.z
    return (rel > 0) and "r" or "l"
  end
  return "l"
end

minetest.register_craftitem("cw_core:door_wood", {
  description = "Wooden Door",
  inventory_image = DOOR_TEX_BOTTOM, -- bottom as icon
  stack_max = 99,
  on_place = function(itemstack, placer, pointed)
    if not placer or pointed.type ~= "node" then return itemstack end
    local pos = pointed.above
    local top = {x=pos.x, y=pos.y+1, z=pos.z}
    if minetest.get_node(pos).name ~= "air" or minetest.get_node(top).name ~= "air" then return itemstack end
    if not (can_modify(pos, placer) and can_modify(top, placer)) then return itemstack end

    local facedir = minetest.dir_to_facedir(placer:get_look_dir(), true)
    local hinge   = choose_hinge_on_place(pos, facedir, placer)  -- "l" or "r"

    minetest.set_node(pos, {name=node_name(DOOR_PREFIX,false,false,hinge), param2=facedir})
    minetest.set_node(top, {name=node_name(DOOR_PREFIX, true,false,hinge), param2=facedir})

    if not minetest.is_creative_enabled(placer:get_player_name()) then itemstack:take_item() end
    return itemstack
  end
})

-- ======================
-- Trapdoors v2 (MC-like face placement & open toward attached block)
-- ======================
local TRAP_PREFIX = "cw_core:trapdoor_wood"
local TRAP_TEX    = "cw_trapdoor_wood.png"

-- Nodeboxes:
-- Horizontal plates for floor/ceiling closed states
local TD_BOX_CLOSED_BOTTOM = { {-0.5,-0.5,-0.5, 0.5,-0.375,0.5} } -- sits on floor (bottom mount)
local TD_BOX_CLOSED_TOP    = { {-0.5, 0.375,-0.5, 0.5, 0.5, 0.5} } -- sits on ceiling (top mount)
-- Vertical plate used for "open" when floor/ceiling mounted (hinges at block edge visually)
local TD_BOX_OPEN_VERTICAL = { { 0.375,-0.5,-0.5, 0.5, 0.5, 0.5} } -- rotated by facedir

-- Side-mounted:
--  - CLOSED: vertical plate flush against the block face we clicked
--  - OPEN:   horizontal plate flipped upward toward the block (top-half shelf)
local TD_SIDE_CLOSED_VERT  = { {-0.5,-0.5, 0.375, 0.5, 0.5, 0.5} } -- base assumes block at +Z; facedir rotates
local TD_SIDE_OPEN_TOP     = { {-0.5, 0.375,-0.5, 0.5, 0.5, 0.5} } -- horizontal top half (flipped up toward block)

-- Helpers for facedir mapping (Y-rotation only)
local function normal_to_facedir(n)
  if math.abs(n.x) > math.abs(n.z) then
    return (n.x > 0) and 1 or 3   -- +X or -X
  else
    return (n.z > 0) and 0 or 2   -- +Z or -Z
  end
end

-- Register nodes: three mount families (bottom/top/side) × (closed/open)
local function trapdoor_node(name, desc, draw_box, groups_extra)
  minetest.register_node(name, {
    description = desc,
    tiles = {TRAP_TEX},
    drawtype = "nodebox",
    use_texture_alpha = "clip",
    paramtype = "light",
    paramtype2 = "facedir",            -- used for side + to rotate open vertical on floor/ceiling too
    sunlight_propagates = true,
    is_ground_content = false,
    node_box = { type="fixed", fixed = draw_box },
    selection_box = { type="fixed", fixed = draw_box },
    groups = tmerge({choppy=2, oddly_breakable_by_hand=2, door=1, not_in_creative_inventory=1}, groups_extra or {}),
    sounds = sound_defaults(),
    drop = "",

    on_rightclick = function(pos, node, clicker, itemstack)
      if not can_modify(pos, clicker) then return itemstack end
      local fd = node.param2 or 0

      -- name format: cw_core:trapdoor_wood_<mount>_<state>
      local mount = (name:find("_bottom_") and "bottom")
                 or (name:find("_top_")    and "top")
                 or "side"
      local open  = name:find("_open") ~= nil

      local target
      if mount == "side" then
        target = TRAP_PREFIX .. "_side_" .. (open and "closed" or "open")
      elseif mount == "bottom" then
        target = TRAP_PREFIX .. "_bottom_" .. (open and "closed" or "open")
      else -- top
        target = TRAP_PREFIX .. "_top_" .. (open and "closed" or "open")
      end

      -- swap state, preserve facedir
      local n = minetest.get_node(pos)
      n.name = target
      n.param2 = fd
      minetest.swap_node(pos, n)
      return itemstack
    end,
  })
end

-- Bottom (floor) mount
trapdoor_node(TRAP_PREFIX.."_bottom_closed", "Wooden Trapdoor (Floor, Closed)", TD_BOX_CLOSED_BOTTOM)
trapdoor_node(TRAP_PREFIX.."_bottom_open",   "Wooden Trapdoor (Floor, Open)",   TD_BOX_OPEN_VERTICAL)

-- Top (ceiling) mount
trapdoor_node(TRAP_PREFIX.."_top_closed", "Wooden Trapdoor (Ceiling, Closed)", TD_BOX_CLOSED_TOP)
trapdoor_node(TRAP_PREFIX.."_top_open",   "Wooden Trapdoor (Ceiling, Open)",   TD_BOX_OPEN_VERTICAL)

-- Side mount
trapdoor_node(TRAP_PREFIX.."_side_closed", "Wooden Trapdoor (Side, Closed)", TD_SIDE_CLOSED_VERT)
trapdoor_node(TRAP_PREFIX.."_side_open",   "Wooden Trapdoor (Side, Open)",   TD_SIDE_OPEN_TOP)

-- Placeable item: decide mount from clicked face (pointed.normal) and set facedir for side
minetest.register_craftitem("cw_core:trapdoor_wood", {
  description = "Wooden Trapdoor",
  inventory_image = TRAP_TEX,
  stack_max = 99,

  on_place = function(itemstack, placer, pointed)
  if not placer or pointed.type ~= "node" then return itemstack end

  local under = pointed.under
  local above = pointed.above
  local pos   = above -- place in the adjacent air node
  if minetest.get_node(pos).name ~= "air" then return itemstack end
  if not can_modify(pos, placer) then return itemstack end

  -- Normal from clicked block face to placement pos
  local n = { x = above.x - under.x, y = above.y - under.y, z = above.z - under.z }
  -- Player yaw → facedir (0..3), used for floor/ceiling orientation
  local fd_look = minetest.dir_to_facedir(placer:get_look_dir(), true)

  if n.y == 1 then
    -- TOP of block clicked → floor mount (closed horizontal on floor)
    -- Use player yaw so opening vertical orientation matches player turn.
    minetest.set_node(pos, {name = TRAP_PREFIX.."_bottom_closed", param2 = fd_look})

  elseif n.y == -1 then
    -- BOTTOM of block clicked → ceiling mount
    minetest.set_node(pos, {name = TRAP_PREFIX.."_top_closed", param2 = fd_look})

  else
    -- SIDE face clicked → side mount (vertical closed), rotate so plate is flush to the block.
    -- n points from block -> air, so use -n for facedir.
    local inv = { x = -n.x, y = 0, z = -n.z }  -- rotate around Y only
    local fd  = normal_to_facedir(inv)
    minetest.set_node(pos, {name = TRAP_PREFIX.."_side_closed", param2 = fd})
  end

  if not minetest.is_creative_enabled(placer:get_player_name()) then
    itemstack:take_item()
  end
  return itemstack
end
})

-- ======================
-- Example crafts
-- ======================
minetest.register_craft({
  output = "cw_core:door_wood",
  recipe = {
    {"cw_core:planks_oak","cw_core:planks_oak"},
    {"cw_core:planks_oak","cw_core:planks_oak"},
    {"cw_core:planks_oak","cw_core:planks_oak"},
  }
})

minetest.register_craft({
  output = "cw_core:trapdoor_wood 2",
  recipe = {
    {"cw_core:planks_oak","cw_core:planks_oak","cw_core:planks_oak"},
    {"cw_core:planks_oak","cw_core:planks_oak","cw_core:planks_oak"},
  }
})

minetest.register_craft({
  output = "cw_core:stone_slab 6",
  recipe = { {"cw_core:stone","cw_core:stone","cw_core:stone"} }
})
minetest.register_craft({
  output = "cw_core:planks_oak_slab 6",
  recipe = { {"cw_core:planks_oak","cw_core:planks_oak","cw_core:planks_oak"} }
})

minetest.register_craft({
  output = "cw_core:stone_stair 4",
  recipe = {
    {"cw_core:stone","",""},
    {"cw_core:stone","cw_core:stone",""},
    {"cw_core:stone","cw_core:stone","cw_core:stone"},
  }
})
minetest.register_craft({
  output = "cw_core:planks_oak_stair 4",
  recipe = {
    {"cw_core:planks_oak","",""},
    {"cw_core:planks_oak","cw_core:planks_oak",""},
    {"cw_core:planks_oak","cw_core:planks_oak","cw_core:planks_oak"},
  }
})
