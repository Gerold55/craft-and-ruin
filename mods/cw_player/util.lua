-- cw_player/util.lua
local M = {}

function M.clamp(x, lo, hi)
    if x < lo then return lo end
    if x > hi then return hi end
    return x
end

function M.get_meta_tbl(player, key)
    local meta = player:get_meta()
    local raw = meta:get_string(key)
    if raw == "" then return {} end
    local t = minetest.deserialize(raw)
    if type(t) ~= "table" then t = {} end
    return t
end

function M.set_meta_tbl(player, key, tbl)
    local meta = player:get_meta()
    meta:set_string(key, minetest.serialize(tbl or {}))
end

cw_player = cw_player or {}
cw_player.util = M
