local active_cameras = {}  -- joueurs en mode caméra
local sneak_state = {}     -- état Sneak
local cameras = {}         -- ID → position
local max_cameras = 9

-- 🔹 Trouver un ID libre
local function get_free_camera_id()
    for i = 1, max_cameras do
        if not cameras[i] then
            return i
        end
    end
    return nil
end

-- 🔹 Formspect affichant les 9 caméras + boutons Quitter/Continuer
local function show_camera_form(player)
    local pname = player:get_player_name()
    local formspec = [[
        formspec_version[4]
        size[8,7]
        label[0.5,0.5;Mode Caméra - Choisissez une vue:]
    ]]

    -- Générer les 9 boutons ou labels (3 lignes × 3 colonnes)
    local x, y = 0.5, 1.5
    for i = 1, max_cameras do
        if cameras[i] then
            -- Bouton actif
            formspec = formspec ..
                string.format("button[%0.1f,%0.1f;2,0.8;cam%d;Caméra %d]", x, y, i, i)
        else
            -- Bouton désactivé simulé (label gris)
            formspec = formspec ..
                string.format("label[%0.1f,%0.1f;Vide %d]", x, y+0.2, i)
        end

        x = x + 2.2
        if i % 3 == 0 then
            x = 0.5
            y = y + 1
        end
    end

    -- Boutons Quitter / Continuer
    formspec = formspec .. [[
        button_exit[2,5.2;2,0.8;quit;Quitter]
        button[4,5.2;2,0.8;continue;Continuer]
    ]]

    minetest.show_formspec(pname, "camera_node:menu", formspec)
end

-- 🔹 Déclaration du node Caméra
minetest.register_node("camera_node:camera", {
    description = "Caméra",
    tiles = {"camera_node.png"},
    groups = {cracky = 3},
    paramtype2 = "facedir",

    -- Quand une caméra est placée
    on_construct = function(pos)
        local id = get_free_camera_id()
        if not id then
            minetest.chat_send_all("❌ Limite de 9 caméras atteinte !")
            minetest.set_node(pos, {name="air"})
            return
        end
        cameras[id] = vector.new(pos)
        minetest.chat_send_all("📷 Caméra " .. id .. " placée.")
    end,

    -- Quand une caméra est enlevée
    on_destruct = function(pos)
        for id, cpos in pairs(cameras) do
            if vector.equals(cpos, pos) then
                cameras[id] = nil
                minetest.chat_send_all("🗑 Caméra " .. id .. " supprimée.")
                break
            end
        end
    end,

    -- Activation caméra
    on_rightclick = function(pos, node, player)
        local pname = player:get_player_name()
        local original_pos = vector.round(player:get_pos())
        local original_yaw = player:get_look_horizontal()

        -- Position caméra
        local cam_pos = vector.new(pos.x, pos.y + 1.5, pos.z)
        local cam_yaw = minetest.dir_to_yaw(minetest.facedir_to_dir(node.param2 or 0))

        player:set_pos(cam_pos)
        player:set_look_horizontal(cam_yaw)
        player:set_physics_override({speed = 0, jump = 0})
        minetest.chat_send_player(pname, "📷 Vue caméra activée... (Sneak pour menu)")

        active_cameras[pname] = {
            original_pos = original_pos,
            original_yaw = original_yaw
        }
        sneak_state[pname] = false
    end,
})

-- 🔹 Sneak → ouvre menu
minetest.register_globalstep(function(dtime)
    for pname in pairs(active_cameras) do
        local player = minetest.get_player_by_name(pname)
        if player then
            local sneak_pressed = player:get_player_control().sneak
            if sneak_pressed and not sneak_state[pname] then
                show_camera_form(player)
            end
            sneak_state[pname] = sneak_pressed
        end
    end
end)

-- 🔹 Gestion boutons menu
minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname == "camera_node:menu" then
        local pname = player:get_player_name()

        -- Quitter
        if fields.quit and active_cameras[pname] then
            player:set_pos(active_cameras[pname].original_pos)
            player:set_look_horizontal(active_cameras[pname].original_yaw)
            player:set_physics_override({speed = 1, jump = 1})
            minetest.chat_send_player(pname, "↩ Sortie de la caméra.")
            active_cameras[pname] = nil
            sneak_state[pname] = nil
            return
        end

        -- Continuer (ferme formspec)
        if fields.continue then
            minetest.chat_send_player(pname, "📷 Vous restez en mode caméra.")
            minetest.close_formspec(pname, "camera_node:menu")
        end

        -- Boutons caméras actifs
        for i = 1, max_cameras do
            if fields["cam" .. i] and cameras[i] then
                local pos = cameras[i]
                local cam_yaw = minetest.dir_to_yaw(minetest.facedir_to_dir(minetest.get_node(pos).param2 or 0))
                player:set_pos({x=pos.x, y=pos.y+1.5, z=pos.z})
                player:set_look_horizontal(cam_yaw)
                minetest.chat_send_player(pname, "📷 Vue caméra " .. i)
            end
        end
    end
end)

