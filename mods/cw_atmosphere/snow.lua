-- ============================================================================
-- cw_atmosphere: snow.lua
-- Minecraft-style snow weather with stacking layers (1–8)
-- ============================================================================

local SNOW_LAYER_PREFIX = "cw_core:snow_layer_"
local SNOW_BLOCK = "cw_core:snow_block"

-- Biomes that snow
local SNOW_BIOMES = {
    snowy_taiga = true,
    snowy_plains = true,
    frozen_ocean = true,
}

-- Helper: check if biome supports snow
local function is_snow_biome(pos)
    local biome_data = core.get_biome_data(pos)
    if not biome_data then return false end
    local biome_name = core.get_biome_name(biome_data.biome)
    return SNOW_BIOMES[biome_name] == true
end

-- Helper: get layer number from node name
local function get_layer_number(name)
    return tonumber(name:match("snow_layer_(%d+)"))
end

-- Snowfall ABM
core.register_abm({
    label = "cw_atmosphere: snowfall",
    nodenames = {
        "cw_core:grass_block_snow",
        "cw_core:grass_block",
        "cw_core:dirt",
        -- allow snow to fall on existing layers
        "cw_core:snow_layer_1",
        "cw_core:snow_layer_2",
        "cw_core:snow_layer_3",
        "cw_core:snow_layer_4",
        "cw_core:snow_layer_5",
        "cw_core:snow_layer_6",
        "cw_core:snow_layer_7",
        "cw_core:snow_layer_8",
    },
    interval = 20,
    chance = 12,

    action = function(pos, node)
        if not is_snow_biome(pos) then return end

        local above = {x=pos.x, y=pos.y+1, z=pos.z}
        local above_node = core.get_node(above)

        -- Must see sky
        if core.get_node_light(above, 0.5) == nil then return end
        if core.get_node_light(above, 0.5) < 12 then return end

        -- Place initial snow layer
        if above_node.name == "air" then
            core.set_node(above, {name = SNOW_LAYER_PREFIX .. "1"})
            return
        end

        -- Stack layers
        local layer_num = get_layer_number(above_node.name)
        if layer_num then
            if layer_num < 8 then
                core.set_node(above, {name = SNOW_LAYER_PREFIX .. (layer_num + 1)})
            else
                core.set_node(above, {name = SNOW_BLOCK})
            end
        end
    end,
})