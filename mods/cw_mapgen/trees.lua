-- Inside trees.lua or mapgen_singlenode.lua
local function craft_ruin_generate_cherry_tree(pos, area, data, ids)
	-- Helper to place nodes safely within the map chunk
	local function safe_set(p, id)
		if area:contains(p.x, p.y, p.z) then
			local vi = area:index(p.x, p.y, p.z)
			-- Only replace air to protect terrain
			if data[vi] == ids.air then
				data[vi] = id
			end
		end
	end

	-- Adapted Leaf Cluster Logic
	local function place_leaves_cluster(c_pos, radius)
		for x = -radius, radius do
		for y = -radius, radius do
		for z = -radius, radius do
			local p = {x = c_pos.x + x, y = c_pos.y + y, z = c_pos.z + z}
			local dist = math.sqrt(x*x + y*y + z*z)
			if dist <= radius + math.random() * 0.4 then
				safe_set(p, ids.leaves)
			end
		end
		end
		end
	end

	-- Trunk logic with your "Slight Bend"
	local height = math.random(4, 6)
	local trunk_pos = {x=pos.x, y=pos.y, z=pos.z}
	local bend_x = math.random(-1, 1)
	local bend_z = math.random(-1, 1)

	for i = 1, height do
		-- Force the trunk even if not air (so it attaches to ground)
		if area:contains(trunk_pos.x, trunk_pos.y, trunk_pos.z) then
			data[area:index(trunk_pos.x, trunk_pos.y, trunk_pos.z)] = ids.log
		end

		if i > 2 then
			trunk_pos.x = trunk_pos.x + bend_x
			trunk_pos.z = trunk_pos.z + bend_z
		end
		trunk_pos.y = trunk_pos.y + 1
	end

	local top = {x=trunk_pos.x, y=trunk_pos.y-1, z=trunk_pos.z}
	local branches = math.random(2, 4)

	-- Branch logic
	for b = 1, branches do
		local dir_x = math.random(-1, 1)
		local dir_z = math.random(-1, 1)
		if dir_x == 0 and dir_z == 0 then dir_x = 1 end

		local branch_length = math.random(2, 4)
		local branch_pos = {x=top.x, y=top.y, z=top.z}

		for i = 1, branch_length do
			branch_pos.x = branch_pos.x + dir_x
			branch_pos.y = branch_pos.y + math.random(0, 1)
			branch_pos.z = branch_pos.z + dir_z
			safe_set(branch_pos, ids.log)
		end

		-- Leaves at branch tips (Tight 5-block-ish radius as requested)
		place_leaves_cluster(branch_pos, math.random(1, 2))
	end

	-- Top cap
	place_leaves_cluster(top, 2)
end