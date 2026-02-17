minetest.register_on_generated(function(minp, maxp, seed)
    local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
    local area = VoxelArea:new{MinEdge=emin, MaxEdge=emax}
    local data = vm:get_data()

    local c_air   = minetest.get_content_id("air")
    local c_water = minetest.get_content_id("cw_core:water_source")

    for z = minp.z, maxp.z do
        for y = minp.y, maxp.y do
            if y <= 1 then
                for x = minp.x, maxp.x do
                    local vi = area:index(x, y, z)
                    if data[vi] == c_air then
                        data[vi] = c_water
                    end
                end
            end
        end
    end

    vm:set_data(data)
    vm:write_to_map()
end)

