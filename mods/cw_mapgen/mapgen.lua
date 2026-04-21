--
-- CRAFT & RUIN — COMPLETE MINECRAFT-STYLE MAPGEN FOR V7
-- Terrain shape = v7
-- Surface, decorations, and trees = custom
--

---------------------------------------------------------
-- NODE SHORTCUTS
---------------------------------------------------------
local grass     = "cw_core:grass_block"
local dirt      = "cw_core:dirt"
local stone     = "cw_core:stone"
local sand      = "cw_core:sand"
local sandstone = "cw_core:sandstone"
local snow      = "cw_core:snow_block"

local grass_decor     = "cw_core:grass_decor"
local flower_daisy    = "cw_core:flower_daisy"
local flower_bluebell = "cw_core:flower_bluebell"
local cactus          = "cw_core:cactus"
local dead_bush       = "cw_core:dead_bush"

---------------------------------------------------------
-- WATER ALIASES (REQUIRED FOR FLOWING WATER)
---------------------------------------------------------
minetest.register_alias("default:water_source", "cw_core:water_source")
minetest.register_alias("default:water_flowing", "cw_core:water_flowing")

---------------------------------------------------------
-- TREE SCHEMATICS
---------------------------------------------------------
local schem_path = minetest.get_modpath("cw_mapgen") .. "/schematics/"

local oak_schem    = schem_path .. "oak_tree.mts"
local birch_schem  = schem_path .. "birch_tree.mts"
local cherry_schem = schem_path .. "cherry_tree.mts"

local MAX_TREE_HEIGHT = 12  -- adjust if your tallest schematic is higher

-- voxelmanip‑safe tree placement
local function place_tree_vm(vm, area, data, x, y, z, schematic)
    local pos = {x = x, y = y + 1, z = z}
    minetest.place_schematic_on_vmanip(
        vm,        -- VoxelManip object
        pos,
        schematic,
        "random",
        nil,
        false
    )
end

---------------------------------------------------------
-- MAIN MAPGEN PASS
---------------------------------------------------------
minetest.register_on_generated(function(minp, maxp, seed)
    local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
    local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
    local data = vm:get_data()
    local pr = PseudoRandom(seed)

    local cid = {
        grass = minetest.get_content_id(grass),
        dirt = minetest.get_content_id(dirt),
        stone = minetest.get_content_id(stone),
        sand = minetest.get_content_id(sand),
        sandstone = minetest.get_content_id(sandstone),
        snow = minetest.get_content_id(snow),

        grass_decor = minetest.get_content_id(grass_decor),
        flower_daisy = minetest.get_content_id(flower_daisy),
        flower_bluebell = minetest.get_content_id(flower_bluebell),
        cactus = minetest.get_content_id(cactus),
        dead_bush = minetest.get_content_id(dead_bush),
    }

    ---------------------------------------------------------
    -- PASS 1: SURFACE FIXING (Minecraft‑style layering)
    ---------------------------------------------------------
    for z = minp.z, maxp.z do
        for x = minp.x, maxp.x do

            -- Find surface
            local surface_y = nil
            for y = maxp.y, minp.y, -1 do
                local vi = area:index(x, y, z)
                local id = data[vi]

                if id == cid.stone or id == cid.dirt or id == cid.sand or id == cid.sandstone then
                    surface_y = y
                    break
                end
            end

            if surface_y then
                local y = surface_y
                local vi = area:index(x, y, z)
                local id = data[vi]

                -- DESERT
                if id == cid.sand then
                    data[vi] = cid.sand
                    for i = 1, 4 do
                        local vi2 = area:index(x, y - i, z)
                        if data[vi2] == cid.stone then
                            data[vi2] = cid.sandstone
                        end
                    end

                -- SNOWY SLOPES
                elseif y >= 90 then
                    data[vi] = cid.snow

                -- STONY PEAKS
                elseif y >= 100 then
                    data[vi] = cid.stone

                -- NORMAL GRASS / MEADOW
                else
                    data[vi] = cid.grass
                    for i = 1, 5 do
                        local vi2 = area:index(x, y - i, z)
                        if data[vi2] == cid.stone then
                            data[vi2] = cid.dirt
                        end
                    end
                end
            end
        end
    end

    ---------------------------------------------------------
    -- PASS 2: DECORATIONS (grass, flowers, cactus, bushes)
    ---------------------------------------------------------
    for z = minp.z, maxp.z do
        for x = minp.x, maxp.x do

            -- Find surface again
            local surface_y = nil
            for y = maxp.y, minp.y, -1 do
                local vi = area:index(x, y, z)
                local id = data[vi]
                if id == cid.grass or id == cid.sand or id == cid.snow or id == cid.stone then
                    surface_y = y
                    break
                end
            end

            if not surface_y then goto continue_decor end

            local y = surface_y
            local vi = area:index(x, y, z)
            local id = data[vi]

            -- PLAINS / MEADOW DECOR
            if id == cid.grass then
                if pr:next(1, 100) <= 12 then
                    data[area:index(x, y + 1, z)] = cid.grass_decor
                end

                if pr:next(1, 100) <= 3 then
                    data[area:index(x, y + 1, z)] =
                        (pr:next(1, 2) == 1) and cid.flower_daisy or cid.flower_bluebell
                end
            end

            -- DESERT DECOR
            if id == cid.sand then
                if pr:next(1, 200) == 1 then
                    data[area:index(x, y + 1, z)] = cid.cactus
                end

                if pr:next(1, 100) == 1 then
                    data[area:index(x, y + 1, z)] = cid.dead_bush
                end
            end

            ::continue_decor::
        end
    end

    ---------------------------------------------------------
    -- PASS 3: TREES (oak, birch, cherry) — edge + height safe
    ---------------------------------------------------------
    for z = minp.z + 1, maxp.z - 1 do      -- avoid x/z edges
        for x = minp.x + 1, maxp.x - 1 do  -- avoid x/z edges

            -- Find grass surface
            local surface_y = nil
            for y = maxp.y, minp.y, -1 do
                local vi = area:index(x, y, z)
                local id = data[vi]
                if id == cid.grass then
                    surface_y = y
                    break
                end
            end

            if not surface_y then goto continue_trees end

            local y = surface_y

            -- avoid cutting off tops at chunk ceiling
            if y + MAX_TREE_HEIGHT > maxp.y then
                goto continue_trees
            end

            -- OAK (plains-ish)
            if y <= 80 and pr:next(1, 300) == 1 then
                place_tree_vm(vm, area, data, x, y, z, oak_schem)
            end

            -- BIRCH
            if y <= 90 and pr:next(1, 300) == 1 then
                place_tree_vm(vm, area, data, x, y, z, birch_schem)
            end

            -- CHERRY
            if y <= 90 and pr:next(1, 350) == 1 then
                place_tree_vm(vm, area, data, x, y, z, cherry_schem)
            end

            ::continue_trees::
        end
    end

    vm:set_data(data)
    vm:write_to_map()
end)
