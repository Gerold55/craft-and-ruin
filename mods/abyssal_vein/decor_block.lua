-- Remove overworld decorations in the Abyss

minetest.register_on_generated(function(minp, maxp, seed)
    if maxp.y > -200 then return end

    local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
    local area = VoxelArea:new{MinEdge=emin, MaxEdge=emax}
    local data = vm:get_data()

    local remove_set = {}
    local function rid(name)
        local cid = minetest.get_content_id(name)
        if cid ~= 0 then remove_set[cid] = true end
    end

    rid("default:tree")
    rid("default:leaves")
    rid("default:apple")
    rid("default:jungletree")
    rid("default:jungleleaves")
    rid("default:pine_tree")
    rid("default:pine_needles")
    rid("default:acacia_tree")
    rid("default:acacia_leaves")
    rid("default:aspen_tree")
    rid("default:aspen_leaves")
    rid("default:grass_1")
    rid("default:grass_2")
    rid("default:grass_3")
    rid("default:grass_4")
    rid("default:grass_5")
    rid("default:dry_grass_1")
    rid("default:dry_grass_2")
    rid("default:dry_grass_3")
    rid("default:dry_grass_4")
    rid("default:dry_grass_5")

    for z = minp.z, maxp.z do
        for y = minp.y, maxp.y do
            for x = minp.x, maxp.x do
                local vi = area:index(x,y,z)
                if remove_set[data[vi]] then
                    data[vi] = c_air
                end
            end
        end
    end

    vm:set_data(data)
    vm:write_to_map()
end)
