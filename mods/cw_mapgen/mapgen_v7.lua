-- ============================================================================
-- Craft & Ruin — mapgen_v7.lua
-- Engine V7 terrain + custom biomes + schematic decorations
-- No custom terrain generation. No procedural trees. No procedural decor.
-- ============================================================================

minetest.log("action", "[cw_mapgen] mapgen_v7.lua loaded")

-- We only use this file for optional post-processing.
-- Since all trees and decor are now handled by Minetest's decoration engine,
-- this file stays intentionally minimal.

minetest.register_on_generated(function(minp, maxp, seed)
    -- Optional: You can add lightweight post-processing here later.
    -- For example: biome-specific tweaks, rare structures, ruins, etc.
    -- But for now, we keep it empty to avoid interfering with engine terrain.

    -- Example placeholder:
    -- minetest.log("action", "[cw_mapgen] chunk generated: " ..
    --     minp.x .. "," .. minp.y .. "," .. minp.z)
end)

