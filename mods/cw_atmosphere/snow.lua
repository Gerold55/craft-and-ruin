-- ============================================================================
-- cw_atmosphere: snow.lua
-- Minecraft-style snow weather with stacking layers
-- ============================================================================

local SNOW_LAYER = "cw_core:snow_layer"
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

-- Snowfall ABM
core.register_abm({
    label = "cw_atmosphere: snowfall",
    nodenames = {
        "cw_core:grass_block_snow",
        "cw_core:grass_block",
        "cw_core:dirt",
        "cw_core:snow_layer",
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

        -- Place initial snow
        if above_node.name == "air" then
            core.set_node(above, {
                name = SNOW_LAYER,
                param2 = 1
            })
            return
        end

        -- Stack layers
        if above_node.name == SNOW_LAYER then
            local layers = above_node.param2 or 1

            if layers < 8 then
                core.swap_node(above, {
                    name = SNOW_LAYER,
                    param2 = layers + 1
                })
            else
                core.set_node(above, {name = SNOW_BLOCK})
            end
        end
    end,
})
