-- cw_mobs/api.lua
-- Small helpers shared by mobs

local U, S = cw_mobs.util, cw_mobs.settings

-- Generic: find a tiny free 2-node column at pos (feet/head both non-walkable)
function cw_mobs.try_spawn_at_air(pos, name)
  local feet = {x=pos.x, y=pos.y, z=pos.z}
  local head = {x=pos.x, y=pos.y+1, z=pos.z}
  local fdef = minetest.registered_nodes[minetest.get_node(feet).name]
  local hdef = minetest.registered_nodes[minetest.get_node(head).name]
  if fdef and hdef and (not fdef.walkable) and (not hdef.walkable) then
    minetest.add_entity(feet, name)
    return true
  end
  return false
end

-- Count how many of 'name' are near 'ppos' within radius (defaults to settings.view_radius)
function cw_mobs.count_near(ppos, name, radius)
  return U.count_named(ppos, radius or S.view_radius, name)
end

-- Simple spawn egg helper (optional)
function cw_mobs.register_spawn_egg(itemname, mobname, desc, image)
  minetest.register_craftitem(itemname, {
    description = desc or ("Spawn "..mobname),
    inventory_image = image or "default_stick.png",
    stack_max = 64,
    on_place = function(stack, placer, pt)
      if pt and pt.above then
        local pos = vector.new(pt.above); pos.y = pos.y + 1
        if cw_mobs.try_spawn_at_air(pos, mobname) then
          if placer and not minetest.is_creative_enabled(placer:get_player_name()) then
            stack:take_item(1)
          end
        end
      end
      return stack
    end
  })
end
