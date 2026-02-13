-- Cube_World core init
-- Only dofile / include other parts here, no nodes directly

local modpath = core.get_modpath(core.get_current_modname())
local biome_tint = dofile(core.get_modpath("cw_core").."/biome_tint.lua").biome_tint or cw_core.biome_tint

local MP = core.get_modpath("cw_core")
assert(MP, "[cw_core] get_modpath failed")

local function include(file)
  local p = MP .. "/" .. file
  local ok, err = pcall(dofile, p)
  if not ok then
    core.log("error", "[cw_core] failed to load "..file..": "..dump(err))
  else
    core.log("action", "[cw_core] loaded "..file)
  end
end

include("crafts.lua")   -- <<< make sure this line exists

core.register_on_newplayer(function(player)
    -- How far from origin we search
    local R = 2000   -- increase if needed

    for i = 1,200 do
        local x = math.random(-R, R)
        local z = math.random(-R, R)

        -- Try to pick a floor level there
        local y = core.get_spawn_level(x, z) or 5
        local pos = {x=x, y=y+2, z=z}

        local below = core.get_node({x=x,y=y,z=z}).name

        -- Reject water or lava surfaces
        if not (below:find("water") or below:find("lava")) then
            player:set_pos(pos)
            return
        end
    end

    -- Fallback if all attempts fail: put player at default spawn at y=5 on land
    player:set_pos({x=0,y=6,z=0})
end)

dofile(modpath .. "/nodes.lua")
dofile(modpath .. "/nodes_building.lua")
dofile(modpath .. "/terracotta.lua")
dofile(modpath .. "/trees.lua")
dofile(modpath .. "/hotbar.lua")
dofile(modpath .. "/decorations.lua")
dofile(modpath .. "/creative.lua")
dofile(modpath .. "/fences.lua")
dofile(modpath .. "/biome_debug.lua")
dofile(modpath .. "/falling_leaves.lua")
dofile(modpath .. "/mushrooms.lua")
dofile(modpath .. "/items/bottle_glass.lua")
--dofile(modpath .. "/plains_features.lua")
-- later we can also do:
-- dofile(modpath .. "/items.lua")
-- dofile(modpath .. "/biome_aliases.lua")

core.register_chatcommand("rtest", {
  params = "<itemstring>",
  description = "Print number of craft recipes for an item",
  func = function(name, param)
    if param == "" then return false, "Usage: /rtest mod:item" end
    local rec = core.get_all_craft_recipes(param)
    if not rec then
      return true, "No recipes for: "..param
    else
      return true, ("Found %d recipes for %s"):format(#rec, param)
    end
  end
})
