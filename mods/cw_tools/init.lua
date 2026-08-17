-- mods/cw_tools/init.lua
-- CW Tools: tools + Better Beginnings primitives + flint hatchet + fishing rod with bobber entity
local modname = core.get_current_modname() or "cw_tools"

-- Utility
local function pname(player) return player and player:get_player_name() or "" end

-- =========================
-- Items and Tools
-- =========================

-- Rock (primitive resource)
core.register_craftitem(modname .. ":rock", {
    description = "Rock",
    inventory_image = "rock.png",
})

-- Flint resource
core.register_craftitem(modname .. ":flint", {
    description = "Flint",
    inventory_image = "flint.png",
})

-- Ingot placeholder (replace with your progression material if desired)
core.register_craftitem(modname .. ":ingot", {
    description = "CW Ingot",
    inventory_image = "ingot.png",
})

-- Helper to register a set of tools for a material
local function register_toolset(material_key, material_name, ingot_item, stats)
    -- stats: table with uses, times (groupcaps times table), full_punch_interval, damage
    
    -- Sword
    minetest.register_tool(modname .. ":" .. material_key .. "_sword", {
        description = material_name .. " Sword",
        inventory_image = "tool_" .. material_key .. "axe.png", -- Adjusted texture naming
        tool_capabilities = {
            full_punch_interval = stats.full_punch_interval,
            max_drop_level = 1,
            groupcaps = {
                snappy = { times = stats.snappy_times, uses = stats.uses, maxlevel = 1 }
            },
            damage_groups = { fleshy = stats.sword_damage }
        },
        groups = { weapon = 1 }
    })

    -- Pickaxe
    minetest.register_tool(modname .. ":" .. material_key .. "_pickaxe", {
        description = material_name .. " Pickaxe",
        inventory_image = "tool_" .. material_key .. "pick.png",
        tool_capabilities = {
            full_punch_interval = stats.full_punch_interval,
            max_drop_level = 3,
            groupcaps = {
                cracky = { times = stats.cracky_times, uses = stats.uses, maxlevel = stats.maxlevel_cracky or 3 }
            },
            damage_groups = { fleshy = stats.tool_damage }
        },
        groups = { tool = 1 }
    })

    -- Axe
    minetest.register_tool(modname .. ":" .. material_key .. "_axe", {
        description = material_name .. " Axe",
        inventory_image = "tool_" .. material_key .. "axe.png",
        tool_capabilities = {
            full_punch_interval = stats.full_punch_interval,
            max_drop_level = 2,
            groupcaps = {
                choppy = { times = stats.choppy_times, uses = stats.uses, maxlevel = stats.maxlevel_choppy or 2 }
            },
            damage_groups = { fleshy = stats.tool_damage }
        },
        groups = { tool = 1 }
    })

    -- Shovel
    minetest.register_tool(modname .. ":" .. material_key .. "_shovel", {
        description = material_name .. " Shovel",
        inventory_image = "tool_" .. material_key .. "shovel.png",
        tool_capabilities = {
            full_punch_interval = stats.full_punch_interval,
            max_drop_level = 1,
            groupcaps = {
                crumbly = { times = stats.crumbly_times, uses = stats.uses, maxlevel = stats.maxlevel_crumbly or 2 }
            },
            damage_groups = { fleshy = stats.tool_damage }
        },
        groups = { tool = 1 }
    })

    -- Recipes (standard Minecraft patterns)
    -- Sword
    minetest.register_craft({
        output = modname .. ":" .. material_key .. "_sword",
        recipe = {
            {"", ingot_item, ""},
            {"", ingot_item, ""},
            {"", "default:stick", ""}
        }
    })
    -- Pickaxe
    minetest.register_craft({
        output = modname .. ":" .. material_key .. "_pickaxe",
        recipe = {
            {ingot_item, ingot_item, ingot_item},
            {"", "default:stick", ""},
            {"", "default:stick", ""}
        }
    })
    -- Axe
    minetest.register_craft({
        output = modname .. ":" .. material_key .. "_axe",
        recipe = {
            {ingot_item, ingot_item, ""},
            {ingot_item, "default:stick", ""},
            {"", "default:stick", ""}
        }
    })
    -- Shovel
    minetest.register_craft({
        output = modname .. ":" .. material_key .. "_shovel",
        recipe = {
            {"", ingot_item, ""},
            {"", "default:stick", ""},
            {"", "default:stick", ""}
        }
    })
end

-- Define stats for each tier
-- times tables: lower values = faster mining for that level
local tiers = {
    wood = {
        name = "Wood",
        ingot = "default:wood",
        uses = 60,
        full_punch_interval = 2.0,
        snappy_times = {[1]=2.4, [2]=1.2, [3]=0.6},
        cracky_times = {[1]=2.8, [2]=1.4, [3]=0.7},
        choppy_times = {[1]=2.4, [2]=1.2, [3]=0.6},
        crumbly_times = {[1]=2.0, [2]=1.0, [3]=0.5},
        sword_damage = 4,
        tool_damage = 2
    },

    stone = {
        name = "Stone",
        ingot = "default:cobble",
        uses = 132,
        full_punch_interval = 1.6,
        snappy_times = {[1]=1.8, [2]=0.9, [3]=0.45},
        cracky_times = {[1]=1.6, [2]=0.8, [3]=0.4},
        choppy_times = {[1]=1.6, [2]=0.8, [3]=0.4},
        crumbly_times = {[1]=1.2, [2]=0.6, [3]=0.3},
        sword_damage = 5,
        tool_damage = 3
    },

    iron = {
        name = "Iron",
        ingot = "default:steel_ingot",
        uses = 250,
        full_punch_interval = 1.2,
        snappy_times = {[1]=1.4, [2]=0.7, [3]=0.35},
        cracky_times = {[1]=1.2, [2]=0.6, [3]=0.3},
        choppy_times = {[1]=1.2, [2]=0.6, [3]=0.3},
        crumbly_times = {[1]=1.0, [2]=0.5, [3]=0.25},
        sword_damage = 6,
        tool_damage = 4
    },

    gold = {
        name = "Gold",
        ingot = "default:gold_ingot",
        uses = 32,
        full_punch_interval = 0.8,
        snappy_times = {[1]=1.0, [2]=0.5, [3]=0.25},
        cracky_times = {[1]=0.9, [2]=0.45, [3]=0.22},
        choppy_times = {[1]=0.9, [2]=0.45, [3]=0.22},
        crumbly_times = {[1]=0.7, [2]=0.35, [3]=0.17},
        sword_damage = 4,
        tool_damage = 2
    },

    diamond = {
        name = "Diamond",
        ingot = "default:diamond",
        uses = 1561,
        full_punch_interval = 0.9,
        snappy_times = {[1]=1.2, [2]=0.6, [3]=0.3},
        cracky_times = {[1]=1.0, [2]=0.5, [3]=0.25},
        choppy_times = {[1]=1.0, [2]=0.5, [3]=0.25},
        crumbly_times = {[1]=0.8, [2]=0.4, [3]=0.2},
        sword_damage = 7,
        tool_damage = 5
    }
}

-- Register each tier
for key, t in pairs(tiers) do
    register_toolset(key, t.name, t.ingot, {
        uses = t.uses,
        full_punch_interval = t.full_punch_interval,
        snappy_times = t.snappy_times,
        cracky_times = t.cracky_times,
        choppy_times = t.choppy_times,
        crumbly_times = t.crumbly_times,
        sword_damage = t.sword_damage,
        tool_damage = t.tool_damage,
        maxlevel_cracky = 3,
        maxlevel_choppy = 2,
        maxlevel_crumbly = 2
    })
end

-- Rock Hatchet (primitive hatchet)
core.register_tool(modname .. ":rock_hatchet", {
    description = "Rock Hatchet",
    inventory_image = "rock_hatchet.png",
    tool_capabilities = {
        full_punch_interval = 1.2,
        max_drop_level = 0,
        groupcaps = {
            choppy = {times = {[1]=2.5, [2]=1.5}, uses = 40, maxlevel = 1},
        },
        damage_groups = {fleshy = 2},
    },
    sound = {breaks = "default_tool_breaks"},
    groups = {tool = 1}
})

-- Flint Hatchet (better than rock hatchet)
core.register_tool(modname .. ":flint_hatchet", {
    description = "Flint Hatchet",
    inventory_image = "flint_hatchet.png",
    tool_capabilities = {
        full_punch_interval = 1.0, -- faster than rock hatchet
        max_drop_level = 1,
        groupcaps = {
            choppy = {times = {[1]=1.8, [2]=0.9, [3]=0.45}, uses = 180, maxlevel = 1},
        },
        damage_groups = {fleshy = 3},
    },
    sound = {breaks = "default_tool_breaks"},
    groups = {tool = 1}
})

-- =========================
-- Better Beginnings mechanics
-- =========================

-- 1) Spawn rocks on gravel/stone surfaces occasionally
core.register_abm({
    label = modname .. ":spawn_rocks",
    nodenames = {"default:gravel", "default:stone"},
    neighbors = {"air"},
    interval = 30,
    chance = 200, -- tune spawn frequency
    action = function(pos, node)
        local above = {x = pos.x, y = pos.y + 1, z = pos.z}
        if core.get_node(above).name == "air" then
            core.add_item(above, modname .. ":rock")
        end
    end,
})

-- 1b) Spawn flint occasionally on gravel surfaces (rare)
core.register_abm({
    label = modname .. ":spawn_flint",
    nodenames = {"default:gravel"},
    neighbors = {"air"},
    interval = 60,
    chance = 800, -- rare; tune as desired
    action = function(pos, node)
        local above = {x = pos.x, y = pos.y + 1, z = pos.z}
        if core.get_node(above).name == "air" then
            core.add_item(above, modname .. ":flint")
        end
    end,
})

-- 2) Prevent bare-hand tree chopping: make hand ineffective on choppy group
local hand = core.registered_items["default:hand"]
if hand then
    core.override_item("default:hand", {
        tool_capabilities = {
            full_punch_interval = 1.6,
            max_drop_level = 0,
            groupcaps = {
                choppy = {times = {[1]=999.0}, uses = 0, maxlevel = 0},
                snappy = {times = {[1]=999.0}, uses = 0, maxlevel = 0},
                cracky = {times = {[1]=999.0}, uses = 0, maxlevel = 0},
                crumbly = {times = {[1]=999.0}, uses = 0, maxlevel = 0},
            },
            damage_groups = {fleshy = 1},
        }
    })
end

-- 3) Increase stick drops from leaves when dug but do not drop rocks
core.register_on_dignode(function(pos, oldnode, digger)
    if not oldnode or not oldnode.name then return end
    if oldnode.name:find("leaves") then
        -- extra stick chance only
        if math.random() < 0.6 then
            core.add_item(pos, "default:stick")
        end
        -- no rock drop from leaves
    end
end)

-- 4) Gravel dig: small chance to drop flint when gravel is dug
core.register_on_dignode(function(pos, oldnode, digger)
    if not oldnode or not oldnode.name then return end
    if oldnode.name == "default:gravel" then
        if math.random() < 0.08 then -- 8% chance; tune as needed
            core.add_item(pos, modname .. ":flint")
        end
    end
end)

-- 5) Gate stone mining: require a pickaxe (soft gate: restore node and message)
core.register_on_dignode(function(pos, oldnode, digger)
    if not oldnode or not oldnode.name then return end
    if oldnode.name == "default:stone" then
        if digger and digger:is_player() then
            local wield = digger:get_wielded_item()
            local toolname = wield and wield:get_name() or ""
            if not (toolname:find("pick") or toolname:find(modname .. ":pickaxe") or toolname:find("steel")) then
                core.set_node(pos, oldnode)
                core.chat_send_player(digger:get_player_name(),
                    "You need a pickaxe to mine stone. Craft a pickaxe first.")
            end
        end
    end
end)

-- 6) Recipes: rock hatchet, flint hatchet, primitive pick (rock-based), and standard tools using ingot
core.register_craft({
    output = modname .. ":rock_hatchet",
    recipe = {
        {"", modname .. ":rock", ""},
        {"", "default:stick", ""},
        {"", "default:stick", ""},
    }
})

-- Flint hatchet recipe (flint + sticks)
core.register_craft({
    output = modname .. ":flint_hatchet",
    recipe = {
        {"", modname .. ":flint", ""},
        {"", "default:stick", ""},
        {"", "default:stick", ""},
    }
})

-- Optional upgrade: rock hatchet + flint -> flint hatchet (shapeless)
core.register_craft({
    type = "shapeless",
    output = modname .. ":flint_hatchet",
    recipe = {modname .. ":rock_hatchet", modname .. ":flint"},
})

core.register_craft({
    output = "default:pick_wood",
    recipe = {
        {modname .. ":rock", modname .. ":rock", modname .. ":rock"},
        {"", "default:stick", ""},
        {"", "default:stick", ""},
    }
})

-- Standard tool recipes using ingot
core.register_craft({
    output = modname .. ":sword",
    recipe = {
        {"", modname .. ":ingot", ""},
        {"", modname .. ":ingot", ""},
        {"", "default:stick", ""},
    }
})

core.register_craft({
    output = modname .. ":pickaxe",
    recipe = {
        {modname .. ":ingot", modname .. ":ingot", modname .. ":ingot"},
        {"", "default:stick", ""},
        {"", "default:stick", ""},
    }
})

core.register_craft({
    output = modname .. ":axe",
    recipe = {
        {modname .. ":ingot", modname .. ":ingot", ""},
        {modname .. ":ingot", "default:stick", ""},
        {"", "default:stick", ""},
    }
})

core.register_craft({
    output = modname .. ":shovel",
    recipe = {
        {"", modname .. ":ingot", ""},
        {"", "default:stick", ""},
        {"", "default:stick", ""},
    }
})

core.register_craft({
    output = modname .. ":fishing_rod",
    recipe = {
        {modname .. ":ingot", "", ""},
        {"", "default:stick", ""},
        {"", "", "default:stick"},
    }
})

-- =========================
-- Fishing rod with bobber entity
-- =========================

-- Catch items
core.register_craftitem(modname .. ":common_fish", {
    description = "Common Fish",
    inventory_image = "common_fish.png",
    on_use = core.item_eat(4)
})

core.register_craftitem(modname .. ":rare_fish", {
    description = "Rare Fish",
    inventory_image = "rare_fish.png",
    on_use = core.item_eat(8)
})

core.register_craftitem(modname .. ":trash_item", {
    description = "Old Boot",
    inventory_image = "trash_item.png"
})

-- Bobber entity definition
core.register_entity(modname .. ":bobber", {
    initial_properties = {
        physical = false,
        collisionbox = {0,0,0, 0,0,0},
        visual = "sprite",
        textures = {"fishing_rod.png"},
        pointable = false,
        glow = 0,
    },

    owner = nil,
    timer = 0,
    bite_time = nil,
    caught = false,

    on_activate = function(self, staticdata, dtime_s)
        self.timer = 0
        self.bite_time = 2 + math.random() * 6
    end,

    on_step = function(self, dtime)
        self.timer = self.timer + dtime
        local pos = self.object:get_pos()
        if pos then
            local y = math.sin(self.timer * 2) * 0.02
            self.object:set_pos({x = pos.x, y = pos.y + y, z = pos.z})
        end

        if not self.caught and self.timer >= (self.bite_time or 3) then
            self.caught = true
            if pos then
                core.add_particle({
                    pos = pos,
                    velocity = {x=0, y=0.5, z=0},
                    acceleration = {x=0, y=-1, z=0},
                    expirationtime = 0.6,
                    size = 4,
                    texture = "default_water.png",
                })
            end
            core.after(0.1, function()
                if not self.object then return end
                local owner = self.owner and core.get_player_by_name(self.owner)
                if owner and owner:is_player() then
                    local inv = owner:get_inventory()
                    if inv and inv:room_for_item("main", modname .. ":common_fish") then
                        local r = math.random()
                        local catch = nil
                        if r < 0.02 then
                            catch = modname .. ":rare_fish"
                        elseif r < 0.65 then
                            catch = modname .. ":common_fish"
                        else
                            catch = modname .. ":trash_item"
                        end
                        inv:add_item("main", catch)
                        core.chat_send_player(self.owner, "You caught: " .. (core.registered_items[catch].description or catch))
                    else
                        core.chat_send_player(self.owner, "No room in inventory for catch.")
                    end
                end
                if self.object then self.object:remove() end
            end)
        end
    end,

    on_punch = function(self, puncher)
        if puncher and puncher:is_player() and puncher:get_player_name() == self.owner then
            core.chat_send_player(self.owner, "You reeled in the line.")
            if self.object then self.object:remove() end
        end
    end,
})

-- Fishing rod item: casts bobber entity
core.register_tool(modname .. ":fishing_rod", {
    description = "CW Fishing Rod",
    inventory_image = "fishing_rod.png",
    stack_max = 1,
    on_use = function(itemstack, user, pointed_thing)
        if not user or not user:is_player() then return itemstack end
        local name = user:get_player_name()
        local pos = user:get_pos()
        if not pos then return itemstack end

        local dir = user:get_look_dir()
        local cast_pos = {
            x = math.floor(pos.x + dir.x * 4 + 0.5),
            y = math.floor(pos.y + dir.y * 4 + 0.5),
            z = math.floor(pos.z + dir.z * 4 + 0.5)
        }
        local node = core.get_node_or_nil(cast_pos)
        if not node or not node.name:find("water") then
            for dy = 0, -3, -1 do
                local p = {x = cast_pos.x, y = cast_pos.y + dy, z = cast_pos.z}
                local n = core.get_node_or_nil(p)
                if n and n.name:find("water") then
                    cast_pos = p
                    node = n
                    break
                end
            end
        end

        if not node or not node.name:find("water") then
            core.chat_send_player(name, "You need to cast into water.")
            return itemstack
        end

        local spawn_pos = {x = cast_pos.x + 0.0, y = cast_pos.y + 0.2, z = cast_pos.z + 0.0}
        local obj = core.add_entity(spawn_pos, modname .. ":bobber")
        if obj then
            local luaent = obj:get_luaentity()
            if luaent then
                luaent.owner = name
            end
            core.chat_send_player(name, "You cast the fishing rod.")
            local wear = math.floor(65535 / 250)
            itemstack:add_wear(wear)
            if itemstack:get_wear() >= 65535 then
                core.chat_send_player(name, "Your fishing rod broke.")
                return ItemStack(nil)
            end
        end

        return itemstack
    end
})

