cw_villagers = cw_villagers or {}
local PF = cw_villagers.pathfinding

function cw_villagers.assign_farmer_job(self)
    local pos = self.object:get_pos()
    if not pos then return end

    local target = cw_villagers.find_farm_spot(pos)
    if not target then return end

    self.job = "farmer"
    self.target = target
    self.path = PF.find_path(pos, target)
    self.state = self.path and "walking" or "idle"

    local keys = {}
    for k,_ in pairs(cw_villagers.farms) do
        keys[#keys+1] = k
    end
    if #keys == 0 then return end

    local choice = keys[math.random(#keys)]
    self.farm_template = cw_villagers.farms[choice]
    self.farm_index = 1
end

function cw_villagers.farmer_step(self)
    if not self.farm_template then
        self.state = "idle"
        return
    end

    local entry = self.farm_template[self.farm_index]
    if not entry then
        self.state = "idle"
        return
    end

    local pos = vector.add(self.target, entry.pos)
    minetest.set_node(pos, {name = entry.name})

    self.farm_index = self.farm_index + 1
end
