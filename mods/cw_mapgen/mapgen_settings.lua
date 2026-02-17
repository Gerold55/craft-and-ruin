-- ============================================================================
-- Craft & Ruin — Mapgen Settings (MUST LOAD BEFORE mapgen_v7.lua)
-- ============================================================================

minetest.set_mapgen_setting("mg_name", "v7", true)
minetest.set_mapgen_setting("mgv7_spflags", "mountains,noridges,nofloatlands,nocaverns", true)
minetest.set_mapgen_setting("mg_flags", "nocaves,nodungeons,light,decorations,biomes,ores", true)

minetest.set_mapgen_setting_noiseparams("mgv7_np_terrain_persist", {
    offset = 0.6, scale = 0.1,
    spread = {x=500,y=500,z=500},
    seed = 539, octaves = 3, persistence = 0.6, lacunarity = 2.0
}, true)

minetest.set_mapgen_setting_noiseparams("mgv7_np_beach", {
    offset = 0, scale = 1,
    spread = {x=250,y=250,z=250},
    seed = 59420, octaves = 3, persistence = 0.5, lacunarity = 2.0
}, true)

minetest.set_mapgen_setting_noiseparams("mgv7_np_terrain_base", {
    octaves = 5, lacunarity = 2.1, persistence = 0.8,
    spread = {x=1600,y=1600,z=1600},
    scale = 20, seed = 82341, offset = 4
}, true)

minetest.set_mapgen_setting_noiseparams("mgv7_np_terrain_alt", {
    octaves = 5, lacunarity = 2.0, persistence = 0.6,
    spread = {x=600,y=600,z=600},
    scale = 15, seed = 82341, offset = 6
}, true)

minetest.set_mapgen_setting_noiseparams("mgv7_np_height_select", {
    octaves = 6, lacunarity = 2.1, persistence = 0.7,
    spread = {x=1000,y=1000,z=1000},
    scale = 4.5, seed = 4213, offset = -7, flags = "eased"
}, true)

minetest.set_mapgen_setting_noiseparams("mgv7_np_mountain", {
    octaves = 1, lacunarity = 2.0, persistence = 0.3,
    spread = {x=120,y=120,z=120},
    scale = 0.7, seed = 82341, offset = 0
}, true)

minetest.set_mapgen_setting_noiseparams("mgv7_np_mount_height", {
    octaves = 1, lacunarity = 2.0, persistence = 0.3,
    spread = {x=100,y=100,z=100},
    scale = 60, seed = 82341, offset = 30
}, true)

