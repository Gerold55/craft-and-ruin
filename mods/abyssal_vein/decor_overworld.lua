-- Overworld decorations (grass, flowers, trees, etc.)
-- These MUST NOT spawn in the Abyssal Vein.

minetest.register_on_generated(function(minp, maxp)
    if maxp.y < -200 then
        return -- below portal realm threshold → do nothing
    end

    -- Example overworld decor (replace with your actual ones)
    minetest.spawn_falling_node = minetest.spawn_falling_node -- placeholder
end)
