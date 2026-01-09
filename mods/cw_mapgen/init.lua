-- ============================================================================
-- Craft & Ruin — Init
-- ============================================================================

local mp = minetest.get_modpath(minetest.get_current_modname())

-- 1. PRE-REGISTRATION (Visuals & Utility)
dofile(mp .. "/grass_tint.lua")
dofile(mp .. "/leaves_tint.lua")

-- 2. CONTENT REGISTRATION (Tell the engine what exists before we build)
-- These files should contain core.register_biome and core.register_decoration
dofile(mp .. "/ores.lua")
dofile(mp .. "/decor_postgen.lua") 

local function move_to_surface(player)
    local pos = player:get_pos()
    -- Start high and look for the first non-air block
    local ground = core.get_spawn_level(pos.x, pos.z)
    
    if ground then
        player:set_pos({x = pos.x, y = ground + 2, z = pos.z})
    else
        -- Fallback: if map isn't loaded, force them above sea level
        player:set_pos({x = pos.x, y = 70, z = pos.z})
    end
end

core.register_on_newplayer(function(player)
    move_to_surface(player)
end)

core.register_on_respawnplayer(function(player)
    move_to_surface(player)
    return true -- Tells the engine we handled the spawn position
end)

-- 3. THE GENERATORS
-- We check the mapgen setting to decide which generator to load.
local mg = minetest.get_mapgen_setting("mg_name") or ""

if mg == "singlenode" then
    -- This file contains your core.register_on_generated logic
    dofile(mp .. "/mapgen_singlenode.lua")
    -- Load features that depend on the singlenode generation
    dofile(mp .. "/caves.lua")
elseif mg == "v6" then
    dofile(mp .. "/mapgen_v6.lua")
else
    minetest.log("warning", "[cw_mapgen] Unsupported mg_name: " .. mg .. ". Custom mapgen might not run.")
end