-----------------------------
-- CONFIG
-----------------------------
local ICON_BASE = 9      -- your texture size
local ICON_SCALE = 2.5     -- upscale factor (3 = Minecraft-like)
local ICON_SIZE = ICON_BASE * ICON_SCALE
local ICON_GAP  = 0
local ROW_GAP   = 28
local HOTBAR_OFFSET = 72
local MAX_ICONS = 10

local SURVIVAL_ONLY = true
local CENTER_GAP = ICON_SCALE * 15   -- Minecraft-style spacing

-----------------------------
-- TEXTURES
-----------------------------
local tex = {
  heart_full = "hudbars_icon_health.png",
  heart_half = "cw_hud_heart_half.png",
  heart_empty= "hudbars_bgicon_health.png",

  food_full  = "hbhunger_icon.png",
  food_half  = "cw_hud_food_half.png",
  food_empty = "hbhunger_bgicon.png",

  armor_full = "hbarmor_icon.png",
  armor_half = "cw_hud_armor_half.png",
  armor_empty= "hbarmor_bgicon.png",
}

-----------------------------
-- PLAYER STATE
-----------------------------
local players = {}

local function ensure_state(player)
    local name = player:get_player_name()
    if players[name] then return players[name] end

    local st = {
        visible = false,
        hud = {},
        stats = {
            hp = player:get_hp(),
            hunger = 20,
            armor = 0,
        }
    }

    players[name] = st
    return st
end

-----------------------------
-- UTILITY
-----------------------------
local function clamp(v, lo, hi)
    return math.max(lo, math.min(hi, v))
end

local function half_points(v)
    v = clamp(v, 0, 20)
    return math.floor(v * 2 + 0.5) / 2
end

-----------------------------
-- CENTERED LEFT/RIGHT OFFSETS
-----------------------------
-- Hearts + Armor = LEFT of center
local function left_of_center(i)
    return -((MAX_ICONS - i) * ICON_SIZE) - CENTER_GAP
end

local function right_of_center(i)
    return ((i - 1) * ICON_SIZE) + CENTER_GAP
end


-----------------------------
-- CREATE ROW (CENTERED)
-----------------------------
local function create_row(player, side, y_offset, full, half, empty)
    local ids = {}

    for i = 1, MAX_ICONS do
        local x = (side == "left")
            and left_of_center(i)
            or  right_of_center(i)

        ids[i] = player:hud_add({
            hud_elem_type = "image",
            position = {x = 0.5, y = 1},
            offset   = {x = x, y = -y_offset},
            text     = empty,
            scale    = {x = ICON_SCALE, y = ICON_SCALE}, -- FIXED
            alignment= {x = 0, y = 0},
            z_index  = 10,
        })
    end

    return { ids = ids, full = full, half = half, empty = empty }
end

-----------------------------
-- UPDATE ROW
-----------------------------
local function update_row(player, row, value)
    local full = math.floor(value / 2)
    local half = (value % 2 >= 1) and 1 or 0

    for i = 1, MAX_ICONS do
        local tex = row.empty
        if i <= full then
            tex = row.full
        elseif i == full + 1 and half == 1 then
            tex = row.half
        end
        player:hud_change(row.ids[i], "text", tex)
    end
end

-----------------------------
-- SHOW HUD (SIDE‑BY‑SIDE CENTERED)
-----------------------------
local function show_hud(player, st)
    if st.visible then return end

    local base_y = HOTBAR_OFFSET

    -- HEARTS (left of center)
    st.hud.hearts = create_row(
        player, "left", base_y,
        tex.heart_full, tex.heart_half, tex.heart_empty
    )

    -- ARMOR (above hearts)
    if st.stats.armor > 0 then
        st.hud.armor = create_row(
            player, "left", base_y + ROW_GAP,
            tex.armor_full, tex.armor_half, tex.armor_empty
        )
    end

    -- HUNGER (right of center)
    st.hud.hunger = create_row(
        player, "right", base_y,
        tex.food_full, tex.food_half, tex.food_empty
    )

    -- Update visuals
    update_row(player, st.hud.hearts, half_points(st.stats.hp))
    update_row(player, st.hud.hunger, half_points(st.stats.hunger))

    if st.hud.armor then
        update_row(player, st.hud.armor, half_points(st.stats.armor))
    end

    st.visible = true
end

-----------------------------
-- HIDE HUD
-----------------------------
local function hide_hud(player, st)
    if not st.visible then return end

    for _, row in pairs(st.hud) do
        if row and row.ids then
            for _, id in ipairs(row.ids) do
                player:hud_remove(id)
            end
        end
    end

    st.hud = {}
    st.visible = false
end

-----------------------------
-- SURVIVAL CHECK
-----------------------------
local function in_survival(player)
    if not SURVIVAL_ONLY then return true end
    return not minetest.is_creative_enabled(player:get_player_name())
end

-----------------------------
-- HOOKS
-----------------------------
minetest.register_on_joinplayer(function(player)
    local st = ensure_state(player)
    player:hud_set_flags({healthbar = false})

    if in_survival(player) then
        show_hud(player, st)
    end
end)

minetest.register_on_leaveplayer(function(player)
    players[player:get_player_name()] = nil
end)

minetest.register_on_player_hpchange(function(player, hp_change)
    minetest.after(0, function()
        local st = ensure_state(player)
        st.stats.hp = player:get_hp()
        if st.visible then
            update_row(player, st.hud.hearts, half_points(st.stats.hp))
        end
    end)
    return hp_change
end, true)
