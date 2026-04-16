-- recipes.lua
function fs_recipes(player, S)
    local fs = { page_bg("cw_bg_recipes.png") }
    
    fs[#fs+1] = "label[1.5,0.5;Recipe Search]"
    fs[#fs+1] = ("field[1.5,1.0;8,0.7;cw_rq;;%s]"):format(minetest.formspec_escape(S.rquery or ""))
    fs[#fs+1] = "button[9.6,0.9;1.2,0.8;cw_rq_go;Go]"
    
    -- Centered 3x3 Grid
    local gx, gy = 3.5, 2.5
    for r = 0, 2 do
        for c = 0, 2 do
            fs[#fs+1] = ("box[%f,%f;1,1;%s]"):format(gx + c*1.1, gy + r*1.1, SLOT)
        end
    end
    
    -- Result Area
    fs[#fs+1] = "image[7.5,3.6;1,1;gui_arrow.png]"
    fs[#fs+1] = ("box[8.7,3.6;1,1;%s]"):format(SLOT)
    
    fs[#fs+1] = ("list[current_player;main;1.5,%f;9,1;0]"):format(HOTBAR_Y)
    return table.concat(fs)
end