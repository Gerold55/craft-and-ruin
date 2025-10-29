-- cw_minecarts/init.lua
local MP = minetest.get_modpath(minetest.get_current_modname())

-- Global table + defaults
-- inside cw_minecarts = cw_minecarts or { cfg = { ... } }
cw_minecarts = cw_minecarts or {
  cfg = {
    physics_mode   = "hybrid",
    max_speed      = 9.0,
    cruise_speed   = 5.5,
    gravity        = 9.81,
    rail_friction  = 0.15,
    brake_mult     = 0.35,
    boost_mult     = 1.35,
    det_pulse_time = 0.6,
    cart_scale     = 10,  -- <— bump this up/down (1.0 = old size). Try 1.35 or 1.5
  }
}

dofile(MP.."/util.lua")
dofile(MP.."/copperflow_bridge.lua")

-- Safety net: ensure bridge table always exists
cw_minecarts.cf = cw_minecarts.cf or {
  is_pos_powered = function(_) return false end,
  emit_pulse     = function(_, _, _) end,
}

dofile(MP.."/rails.lua")
dofile(MP.."/cart.lua")
