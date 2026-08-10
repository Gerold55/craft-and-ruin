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

include("crafts.lua")

core.register_on_newplayer(function(player)
    -- How far from origin we search
    local R = 2000

    for i = 1,200 do
        local x = math.random(-R, R)
        local z = math.random(-R, R)

        local y = core.get_spawn_level(x, z) or 5
        local pos = {x=x, y=y+2, z=z}

        local below = core.get_node({x=x,y=y,z=z}).name

        if not (below:find("water") or below:find("lava")) then
            player:set_pos(pos)
            return
        end
    end

    player:set_pos({x=0,y=6,z=0})
end)

------------------------------------------------------------
-- 1. HAND & MODE HANDLER
------------------------------------------------------------
-- We no longer register the hand here. 
-- It is handled dynamically inside hand_mode.lua to prevent conflicts.
include("hand_mode.lua")

------------------------------------------------------------
-- 2. WORLD & CONTENT LOAD
------------------------------------------------------------
include("nodes.lua")
include("nodes_building.lua")
include("torch.lua")
include("terracotta.lua")
include("trees.lua")
include("hotbar.lua")
include("decorations.lua")
include("fences.lua")
include("biome_debug.lua")
include("falling_leaves.lua")
include("mushrooms.lua")
include("items/bottle_glass.lua")

------------------------------------------------------------
-- 3. UTILITIES
------------------------------------------------------------
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

function cw_core.grow_tree(pos, tree_type)
    local trunk
    local leaves

    if tree_type == "oak" then
        trunk  = "cw_core:log_oak"
        leaves = "cw_core:leaves_oak"
    elseif tree_type == "birch" then
        trunk  = "cw_core:log_birch"
        leaves = "cw_core:leaves_birch"
    elseif tree_type == "cherry" then
        trunk  = "cw_core:log_cherry"
        leaves = "cw_core:leaves_cherry"
    else
        return
    end

    local height = math.random(4, 6)
    for y = 0, height - 1 do
        minetest.set_node({x=pos.x, y=pos.y + y, z=pos.z}, {name = trunk})
    end

    local top = pos.y + height - 1
    local function place_leaf(x, y, z)
        local p = {x=x, y=y, z=z}
        if minetest.get_node(p).name == "air" then
            minetest.set_node(p, {name = leaves})
        end
    end

    for dx = -3, 3 do
        for dz = -3, 3 do
            if dx*dx + dz*dz <= 9 then place_leaf(pos.x + dx, top, pos.z + dz) end
        end
    end
    for dx = -2, 2 do
        for dz = -2, 2 do
            if dx*dx + dz*dz <= 4 then place_leaf(pos.x + dx, top + 1, pos.z + dz) end
        end
    end
    for dx = -1, 1 do
        for dz = -1, 1 do
            place_leaf(pos.x + dx, top + 2, pos.z + dz)
        end
    end
end