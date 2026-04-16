-- ============================================================================
-- CRAFT & RUIN – Safe Player Spawn
-- Spawns player at surface level in safe biomes
-- ============================================================================

local SAFE_BIOMES = {
    plains = true,
    birch_forest = true,
    forest = true,
}

-- Find ground level at (x, z)
local function get_ground_y(x, z)
    for y = 200, -50, -1 do
        local node = minetest.get_node_or_nil({x = x, y = y, z = z})
        if node and node.name ~= "air" then
            return y
        end
    end
    return nil
end

local function find_spawn_pos()
    for _ = 1, 200 do
        local x = math.random(-200, 200)
        local z = math.random(-200, 200)

        local y = get_ground_y(x, z)
        if not y then
            goto continue
        end

        -- Avoid underwater spawns
        if y <= 0 then
            goto continue
        end

        -- Check biome
        local biome_data = minetest.get_biome_data({x = x, y = y, z = z})
        if not biome_data then
            goto continue
        end

        local biome_name = minetest.get_biome_name(biome_data.biome)
        if SAFE_BIOMES[biome_name] then
            return {x = x, y = y + 1, z = z}
        end

        ::continue::
    end

    -- Fallback spawn
    return {x = 0, y = 10, z = 0}
end

minetest.register_on_newplayer(function(player)
    local pos = find_spawn_pos()
    player:set_pos(pos)
end)
