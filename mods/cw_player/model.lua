-- cw_player/model.lua
-- cw_player is the authoritative Player Model API (NO player_api dependency).
-- Safe mesh/sprite fallback so the game always launches.

local MP = minetest.get_modpath(minetest.get_current_modname())
local function exists(relpath)
    -- Only checks files inside this mod; engine paths still work if provided.
    local f = io.open(MP .. "/" .. relpath, "rb")
    if f then f:close(); return true end
    return false
end

local M = {}
cw_player.model = M

-- Default definition (override via set_definition)
local DEF = {
    mesh      = "models/cw_player_character.b3d",
    textures  = {"textures/cw_player_skin.png"},
    sprite    = "textures/cw_player_dummy.png", -- fallback
    anim = {
        stand     = {x=0,   y=39,  speed=15, loop=true},
        walk      = {x=40,  y=79,  speed=20, loop=true},
        mine      = {x=80,  y=119, speed=20, loop=true},
        walk_mine = {x=120, y=159, speed=20, loop=true},
        sit       = {x=160, y=179, speed= 8, loop=true},
        lay       = {x=180, y=199, speed= 1, loop=false},
        swim      = {x=200, y=239, speed=20, loop=true},
        sneak     = {x=240, y=279, speed=12, loop=true},
        run       = {x=280, y=319, speed=24, loop=true},
    }
}

function M.set_definition(def)
    if type(def) ~= "table" then return end
    DEF = {
        mesh     = def.mesh     or DEF.mesh,
        textures = def.textures or DEF.textures,
        sprite   = def.sprite   or DEF.sprite,
        anim     = def.anim     or DEF.anim,
    }
end

local STATE = {} -- pname -> {mode="mesh"|"sprite"}

local function apply_sprite(player)
    player:set_properties({
        visual        = "upright_sprite",
        textures      = { (exists(DEF.sprite) and DEF.sprite) or "player.png" },
        visual_size   = {x=1, y=1},
        collisionbox  = {-0.3, 0.0, -0.3, 0.3, 1.8, 0.3},
        selectionbox  = {-0.3, 0.0, -0.3, 0.3, 1.8, 0.3},
    })
end

local function apply_mesh(player)
    player:set_properties({
        visual        = "mesh",
        mesh          = DEF.mesh,
        textures      = DEF.textures,
        visual_size   = {x=1, y=1},
        collisionbox  = {-0.35, 0.0, -0.35, 0.35, 1.8, 0.35},
        selectionbox  = {-0.35, 0.0, -0.35, 0.35, 1.8, 0.35},
    })
    local a = DEF.anim.stand
    if a then player:set_animation({x=a.x, y=a.y}, a.speed, 0, a.loop) end
end

function M.init(player)
    if not player or not player:is_player() then return end
    local name = player:get_player_name()
    local ok_mesh = DEF.mesh and (exists(DEF.mesh) or true) -- allow engine-searchable paths
    local ok_texs = true
    if type(DEF.textures) == "table" then
        for _, t in ipairs(DEF.textures) do
            if type(t) == "string" and t:find("^textures/") then
                if not exists(t) then ok_texs = false break end
            end
        end
    end

    if ok_mesh and ok_texs then
        apply_mesh(player)
        STATE[name] = {mode="mesh"}
    else
        minetest.log("warning", "[cw_player] Missing mesh/texture; fallback sprite for "..name)
        apply_sprite(player)
        STATE[name] = {mode="sprite"}
    end
end

function M.force_sprite(player)
    if not player then return end
    apply_sprite(player)
    STATE[player:get_player_name()] = {mode="sprite"}
end

function M.try_mesh(player)
    if not player then return end
    if DEF.mesh then
        apply_mesh(player)
        STATE[player:get_player_name()] = {mode="mesh"}
    else
        apply_sprite(player)
        STATE[player:get_player_name()] = {mode="sprite"}
    end
end

function M.set_textures(player, textures)
    if not player or type(textures) ~= "table" then return end
    local st = STATE[player:get_player_name()]
    if st and st.mode == "mesh" then
        player:set_properties({ textures = textures })
    else
        local tex = textures[1]
        if type(tex) == "string" then player:set_properties({ textures = {tex} }) end
    end
end

function M.play(player, name, speed_override)
    if not player then return end
    local st = STATE[player:get_player_name()]
    if not st or st.mode ~= "mesh" then return end
    local a = DEF.anim[name]; if not a then return end
    player:set_animation({x=a.x, y=a.y}, speed_override or a.speed, 0, a.loop)
end

function M.mode(player)
    local st = player and STATE[player:get_player_name()]
    return st and st.mode or "unknown"
end

minetest.register_on_leaveplayer(function(player)
    STATE[player:get_player_name()] = nil
end)
