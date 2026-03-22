local api = cw_achievements

-- Visit specific biomes (uses check_type = "biome_visit" and a biome key)
api.register({
    id = "visit_desert",
    title = "Visit Desert",
    legacy_id = "MTG-001",
    location = "Desert",
    description = "Set foot on the hot sands of a desert biome.",
    icon = "default_desert_sand.png",
    check_type = "biome_visit",
    biome = "desert",
    goal = 1,
    reward = "default:apple 3",
    color = "#E0C068",
})

api.register({
    id = "visit_snow",
    title = "Visit Snow",
    legacy_id = "MTG-002",
    location = "Snowy Tundra",
    description = "Explore a snowy biome and feel the chill.",
    icon = "default_snow.png",
    check_type = "biome_visit",
    biome = "snow",
    goal = 1,
    reward = "default:coal_lump 4",
    color = "#AEE7FF",
})

api.register({
    id = "visit_rainforest",
    title = "Visit Rainforest",
    legacy_id = "MTG-003",
    location = "Rainforest",
    description = "Wander into the dense, humid rainforest.",
    icon = "default_rainforest_litter.png",
    check_type = "biome_visit",
    biome = "rainforest",
    goal = 1,
    reward = "default:jungletree_sapling 2",
    color = "#2ECC71",
})

api.register({
    id = "visit_plains",
    title = "Visit Plains",
    legacy_id = "MTG-004",
    location = "Plains",
    description = "Roam the open grassy plains.",
    icon = "default_grass_1.png",
    check_type = "biome_visit",
    biome = "plains",
    goal = 1,
    reward = "farming:seed_wheat 5",
    color = "#9AD34D",
})

api.register({
    id = "visit_mountain",
    title = "Visit Mountain",
    legacy_id = "MTG-005",
    location = "Mountain",
    description = "Climb the rocky heights of a mountain biome.",
    icon = "default_stone.png",
    check_type = "biome_visit",
    biome = "mountain",
    goal = 1,
    reward = "default:cobble 16",
    color = "#B0B0B0",
})

-- Visit a set number of distinct biomes
api.register({
    id = "visit_all_biomes",
    title = "World Wanderer",
    legacy_id = "MTG-010",
    location = "Various",
    description = "Visit several distinct biomes across the world.",
    icon = "default_map.png",
    check_type = "visit_all",
    goal = 5, -- adjust to the number of biome keys you want to require
    reward = "default:gold_ingot 2",
    color = "#FFD166",
})

-- Obtain specific items (inventory checks)
api.register({
    id = "obtain_mese",
    title = "Mese Seeker",
    legacy_id = "MTG-020",
    location = "Caverns",
    description = "Acquire a mese crystal.",
    icon = "default_mese_crystal.png",
    check_type = "inventory_item",
    item = "default:mese_crystal",
    goal = 1,
    reward = "default:mese 1",
    color = "#FFB86B",
})

api.register({
    id = "obtain_diamond",
    title = "Diamond Hunter",
    legacy_id = "MTG-021",
    location = "Deep Mines",
    description = "Find and hold a diamond.",
    icon = "default_diamond.png",
    check_type = "inventory_item",
    item = "default:diamond",
    goal = 1,
    reward = "default:diamond 1",
    color = "#7BE0FF",
})

-- Reach near the world border (distance from origin)
api.register({
    id = "near_world_border",
    title = "Edge of the World",
    legacy_id = "MTG-030",
    location = "Far Lands",
    description = "Travel far from the origin and approach the world border.",
    icon = "default_obsidian.png",
    check_type = "position_distance",
    radius = 3000, -- tune this radius to your server/world settings
    goal = 1,
    reward = "default:obsidian 4",
    color = "#6A5ACD",
})

