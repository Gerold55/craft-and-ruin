-- ============================================================================
-- Craft & Ruin — mapgen_v7.lua (DIAGNOSTIC MODE)
-- Logs biome, node, and mapgen state to help debug "stone everywhere"
-- ============================================================================

minetest.log("action", "[cw_mapgen] DIAGNOSTIC mapgen_v7.lua loaded")

-- Check if biomes exist
local biome_list = minetest.registered_biomes or {}
local biome_count = 0
for name, def in pairs(biome_list) do
    biome_count = biome_count + 1
end

minetest.log("action", "[cw_mapgen] Registered biomes count = " .. biome_count)

if biome_count == 0 then
    minetest.log("error", "[cw_mapgen] NO BIOMES REGISTERED! World will be all stone.")
end

-- Check if critical nodes exist
local function check_node(name)
    if minetest.registered_nodes[name] then
        minetest.log("action", "[cw_mapgen] Node OK: " .. name)
    else
        minetest.log("error", "[cw_mapgen] MISSING NODE: " .. name .. " (biomes using this will fail!)")
    end
end

check_node("cw_core:grass_block")
check_node("cw_core:dirt")
check_node("cw_core:beach_sand")
check_node("cw_core:desert_sand")
check_node("cw_core:stone")

-- Check if decorations exist
local deco_count = 0
for name, def in pairs(minetest.registered_decorations or {}) do
    deco_count = deco_count + 1
end
minetest.log("action", "[cw_mapgen] Registered decorations count = " .. deco_count)

if deco_count == 0 then
    minetest.log("warning", "[cw_mapgen] No decorations registered. Trees/grass will not spawn.")
end

-- Check if any mod cleared biomes AFTER registration
minetest.register_on_mods_loaded(function()
    local count_after = 0
    for _ in pairs(minetest.registered_biomes or {}) do
        count_after = count_after + 1
    end

    if count_after < biome_count then
        minetest.log("error", "[cw_mapgen] Another mod cleared biomes AFTER registration!")
        minetest.log("error", "[cw_mapgen] Biomes before: " .. biome_count .. ", after: " .. count_after)
    end
end)

-- Log biome per chunk
minetest.register_on_generated(function(minp, maxp, seed)
    local pos = {x = minp.x + 8, y = maxp.y - 1, z = minp.z + 8}
    local data = minetest.get_biome_data(pos)

    if not data then
        minetest.log("error", "[cw_mapgen] No biome data for chunk at " ..
            minp.x .. "," .. minp.y .. "," .. minp.z)
        return
    end

    local biome_name = minetest.get_biome_name(data.biome) or "nil"

    minetest.log("action", "[cw_mapgen] Chunk " ..
        minp.x .. "," .. minp.y .. "," .. minp.z ..
        " biome = " .. biome_name)
end)

