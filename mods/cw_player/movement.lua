-- cw_player/movement.lua
-- Sprint with stamina drain; regen when resting.

local cfg   = cw_player.cfg
local stats = cw_player.stats

local tick = 0
minetest.register_globalstep(function(dtime)
    tick = tick + dtime
    if tick < 0.1 then return end
    local dt = tick
    tick = 0

    for _, player in ipairs(minetest.get_connected_players()) do
        local ctrl = player:get_player_control()
        local sprinting = false

        if cfg.sprint_key_is_aux1 then
            sprinting = ctrl.aux1 and (ctrl.up or ctrl.down or ctrl.left or ctrl.right)
        else
            sprinting = (ctrl.up or ctrl.down or ctrl.left or ctrl.right)
        end

        if cfg.enable_stamina then
            local sta = stats.get(player, "stamina") or 100
            if sprinting and sta > 0 then
                sta = math.max(0, sta - math.ceil(8 * dt))   -- ~8/sec drain
            else
                sta = math.min(100, sta + math.ceil(6 * dt)) -- ~6/sec regen
            end
            stats.set(player, "stamina", sta, true) -- silent; HUD sync elsewhere
            if sta <= 0 then sprinting = false end
        end

        player:set_physics_override({ speed = sprinting and cfg.sprint_multiplier or 1.0 })
    end
end)
