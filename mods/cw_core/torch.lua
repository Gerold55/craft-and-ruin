local TORCH_LIGHT = 12

------------------------------------------------------------
-- PARTICLE FLAME SYSTEM
------------------------------------------------------------
local function spawn_torch_flame_particles(pos, dir)
    local offset = {x = 0, y = 0, z = 0}

    if dir == "floor" then
        offset = {x = 0, y = 0.28, z = 0}

    elseif dir == "wall_x+" then
        offset = {x = 0.18, y = 0.22, z = 0}

    elseif dir == "wall_x-" then
        offset = {x = -0.18, y = 0.22, z = 0}

    elseif dir == "wall_z+" then
        offset = {x = 0, y = 0.22, z = 0.18}

    elseif dir == "wall_z-" then
        offset = {x = 0, y = 0.22, z = -0.18}
    end

    local p = vector.add(pos, offset)

    minetest.add_particlespawner({
        amount = 10,
        time = 0.1,

        minpos = {x = p.x - 0.05, y = p.y,     z = p.z - 0.05},
        maxpos = {x = p.x + 0.05, y = p.y+0.1, z = p.z + 0.05},

        minvel = {x = -0.03, y = 0.1, z = -0.03},
        maxvel = {x =  0.03, y = 0.25, z =  0.03},

        minacc = {x = 0, y = 0.1, z = 0},
        maxacc = {x = 0, y = 0.2, z = 0},

        minexptime = 0.3,
        maxexptime = 0.7,

        minsize = 1.5,
        maxsize = 2.5,

        texture = "mytorch_flame.png",
        glow = TORCH_LIGHT,
    })
end

local function start_timer(pos)
    minetest.get_node_timer(pos):start(0.2)
end

local function torch_timer(pos)
    local node = minetest.get_node(pos)
    local p2 = node.param2

    local dir = "floor"
    if p2 == 2 then dir = "wall_z+"
    elseif p2 == 3 then dir = "wall_z-"
    elseif p2 == 4 then dir = "wall_x+"
    elseif p2 == 5 then dir = "wall_x-" end

    spawn_torch_flame_particles(pos, dir)
    return true
end

------------------------------------------------------------
-- FLOOR TORCH (mesh)
------------------------------------------------------------
minetest.register_node("cw_core:torch", {
    description = "Torch",
    drawtype = "mesh",
    mesh = "torch_floor.obj",
    tiles = {"mytorch_torch.png"},
    inventory_image = "mytorch_torch_inv.png",
    wield_image = "mytorch_torch_inv.png",

    paramtype = "light",
    sunlight_propagates = true,
    walkable = false,
    light_source = TORCH_LIGHT,

    groups = {choppy=2, dig_immediate=3, flammable=1},

    on_construct = start_timer,
    on_timer = torch_timer,
})

------------------------------------------------------------
-- WALL TORCH (mesh)
------------------------------------------------------------
minetest.register_node("cw_core:torch_wall", {
    description = "Wall Torch",
    drawtype = "mesh",
    mesh = "torch_wall.obj",
    tiles = {"mytorch_torch.png"},
    inventory_image = "mytorch_torch_inv.png",
    wield_image = "mytorch_torch_inv.png",

    paramtype = "light",
    paramtype2 = "wallmounted",
    sunlight_propagates = true,
    walkable = false,
    light_source = TORCH_LIGHT,

    groups = {choppy=2, dig_immediate=3, flammable=1, attached_node=1},

    on_place = function(itemstack, placer, pointed_thing)
        local under = pointed_thing.under
        local above = pointed_thing.above
        local wdir = minetest.dir_to_wallmounted(vector.subtract(under, above))
        return minetest.item_place(itemstack, placer, pointed_thing, wdir)
    end,

    on_construct = start_timer,
    on_timer = torch_timer,
})
