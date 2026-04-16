cw_villagers = cw_villagers or {}
local PF = cw_villagers.pathfinding

function cw_villagers.move_toward(self, target, speed)
    local pos = self.object:get_pos()
    if not pos or not target then return end

    local dir = vector.direction(pos, target)
    if dir.x == 0 and dir.z == 0 then return end

    local target_yaw = minetest.dir_to_yaw(dir)
    local current_yaw = self.object:get_yaw()
    local new_yaw = current_yaw + (target_yaw - current_yaw) * 0.25
    self.object:set_yaw(new_yaw)

    local vel = self.object:get_velocity()
    self.object:set_velocity({
        x = dir.x * speed,
        y = vel.y,
        z = dir.z * speed,
    })
end

function cw_villagers.walk_state(self, dtime)
    local pos = self.object:get_pos()
    if not pos then return end

    if not self.path or #self.path == 0 then
        if self.job == "builder" then
            self.state = "building"
        elseif self.job == "farmer" then
            self.state = "farming"
        else
            self.state = "idle"
        end
        return
    end

    local next_step = self.path[1]

    if vector.distance(pos, next_step) < 0.4 then
        table.remove(self.path, 1)
        return
    end

    cw_villagers.move_toward(self, next_step, 2.5)

    if self.last_pos then
        if vector.distance(self.last_pos, pos) < 0.05 then
            self.stuck_timer = self.stuck_timer + dtime
            if self.stuck_timer > 1 then
                self.path = nil
                self.state = "idle"
                self.stuck_timer = 0
            end
        else
            self.stuck_timer = 0
        end
    end

    self.last_pos = vector.new(pos)
end

minetest.register_entity("cw_villagers:villager", {
    initial_properties = {
        physical = true,
        collide_with_objects = true,
        collisionbox = {-0.3, -0.01, -0.3, 0.3, 1.7, 0.3},
        stepheight = 1.1,
        visual = "mesh",
        mesh = "character.b3d",
        textures = {"character.png"},
        acceleration = {x = 0, y = -9.81, z = 0},
    },

    state = "idle",
    job = "builder",
    path = nil,
    target = nil,
    stuck_timer = 0,
    last_pos = nil,

    on_step = function(self, dtime)
        local pos = self.object:get_pos()
        if not pos then return end

        if self.state == "idle" then
            if math.random() < 0.5 then
                cw_villagers.assign_builder_job(self)
            else
                cw_villagers.assign_farmer_job(self)
            end

        elseif self.state == "walking" then
            cw_villagers.walk_state(self, dtime)

        elseif self.state == "building" then
            cw_villagers.builder_step(self)

        elseif self.state == "farming" then
            cw_villagers.farmer_step(self)
        end
    end,
})

minetest.register_chatcommand("spawn_villager", {
    description = "Spawn a villager",
    func = function(name)
        local p = minetest.get_player_by_name(name)
        if not p then return end
        local pos = p:get_pos()
        pos.y = pos.y + 1
        minetest.add_entity(pos, "cw_villagers:villager")
    end
})

minetest.register_chatcommand("spawn_builder", {
    description = "Spawn a builder villager (legacy)",
    func = function(name)
        local p = minetest.get_player_by_name(name)
        if not p then return end
        local pos = p:get_pos()
        pos.y = pos.y + 1
        local obj = minetest.add_entity(pos, "cw_villagers:villager")
        local ent = obj and obj:get_luaentity()
        if ent then
            ent.job = "builder"
            ent.state = "idle"
        end
    end
})

minetest.register_chatcommand("spawn_farmer", {
    description = "Spawn a farmer villager",
    func = function(name)
        local p = minetest.get_player_by_name(name)
        if not p then return end
        local pos = p:get_pos()
        pos.y = pos.y + 1
        local obj = minetest.add_entity(pos, "cw_villagers:villager")
        local ent = obj and obj:get_luaentity()
        if ent then
            ent.job = "farmer"
            ent.state = "idle"
        end
    end
})
