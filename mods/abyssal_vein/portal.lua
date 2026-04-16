-- Abyssal Vein Portal System

local function is_frame(pos)
    return minetest.get_node(pos).name == "abyssal_vein:portal_frame"
end

local function make_portal(pos)
    for y = 0, 2 do
        local p = {x = pos.x, y = pos.y + y, z = pos.z}
        minetest.set_node(p, {name="abyssal_vein:portal_air"})
    end
end

minetest.override_item("abyssal_vein:portal_core", {
    on_place = function(itemstack, placer, pointed)
        local pos = pointed.under
        if not pos then return end

        local x = pos.x
        local y = pos.y
        local z = pos.z

        if is_frame({x=x-1,y=y,z=z}) and
           is_frame({x=x+1,y=y,z=z}) and
           is_frame({x=x-1,y=y+1,z=z}) and
           is_frame({x=x+1,y=y+1,z=z}) and
           is_frame({x=x-1,y=y+2,z=z}) and
           is_frame({x=x+1,y=y+2,z=z}) and
           is_frame({x=x-1,y=y+3,z=z}) and
           is_frame({x=x,y=y+3,z=z}) and
           is_frame({x=x+1,y=y+3,z=z}) then

            make_portal({x=x, y=y+1, z=z})
            itemstack:take_item()
            return itemstack
        end
    end
})

minetest.register_abm({
    label = "Abyssal Portal Teleport",
    nodenames = {"abyssal_vein:portal_air"},
    interval = 1,
    chance = 1,
    action = function(pos)
        for _,player in ipairs(minetest.get_connected_players()) do
            local ppos = player:get_pos()
            if vector.distance(ppos, pos) < 1.2 then
                if ppos.y > -200 then
                    player:set_pos({x=ppos.x, y=-19500, z=ppos.z})
                else
                    player:set_pos({x=ppos.x, y=10, z=ppos.z})
                end
            end
        end
    end
})
