
freecam_data = {}

minetest.register_entity("freecam:clone", {
    initial_properties = {
        visual = "mesh",
        mesh = "character.b3d",
        textures = {"character.png"},
        collisionbox = {0,0,0,0,0,0},
        pointable = false,
    },
})


local old_is_protected = minetest.is_protected

function minetest.is_protected(pos, name)
    local data = freecam_data[name]
    if data and data.active then

        return true
    end
    return old_is_protected(pos, name)
end

minetest.register_on_punchnode(function(pos, node, puncher, pointed_thing)
    if puncher then
        local name = puncher:get_player_name()
        if freecam_data[name] and freecam_data[name].active then
            return true
        end
    end
end)

minetest.register_on_punchplayer(function(player, hitter, time_from_last_punch, tool_capabilities, dir, damage)
    if player and freecam_data[player:get_player_name()] then return true end
    if hitter and freecam_data[hitter:get_player_name()] then return true end
end)

minetest.register_globalstep(function(dtime)
    for name, data in pairs(freecam_data) do
        local player = minetest.get_player_by_name(name)
        if player and data.active then
            player:set_properties({ interaction_range = 0 })
        end
    end
end)

minetest.register_chatcommand("freecam", {
    params = "<player> <true|false>",
    description = "Enable or disable Freecam mode on the server",
    privs = {privs = true},
    func = function(name, param)
        local args = string.split(param, " ")
        local target_name = args[1]
        local action = args[2]

        local target = minetest.get_player_by_name(target_name)
        if not target then return false, "Player offline or not found." end

        if not freecam_data[target_name] then
            freecam_data[target_name] = {
                active = false,
                pos_corpo = nil,
                clone = nil,
                old_visual_size = nil,
                old_interaction_range = 4
            }
        end

        local data = freecam_data[target_name]

        if action == "true" then
            if data.active then return false, "Freecam is already active for this player." end

            data.active = true
            data.pos_corpo = target:get_pos()
            data.old_visual_size = target:get_properties().visual_size
            data.old_interaction_range = target:get_properties().interaction_range or 4

            local clone = minetest.add_entity(data.pos_corpo, "freecam:clone")
            if clone then
                clone:set_properties({
                    mesh = target:get_properties().mesh,
                    textures = target:get_properties().textures,
                })
                clone:set_yaw(target:get_look_horizontal())
                data.clone = clone
            end

            target:set_properties({ visual_size = {x=0, y=0, z=0} })
            target:set_armor_groups({immortal = 1})

            return true, "Freecam mode ENABLED for " .. target_name .. "."

        elseif action == "false" then
            if not data.active then return false, "Freecam is not active for this player." end

            data.active = false

            if data.clone then
                data.clone:remove()
            end

            target:set_pos(data.pos_corpo)

            target:set_properties({
                visual_size = data.old_visual_size or {x=1, y=1, z=1},
                interaction_range = data.old_interaction_range or 4
            })
            target:set_armor_groups({fleshy = 100})

            freecam_data[target_name] = nil
            return true, "Freecam mode DISABLED for " .. target_name .. "."
        else
            return false, "Usage: /freecam <player> <true|false>"
        end
    end
})

minetest.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    if freecam_data[name] then
        if freecam_data[name].clone then freecam_data[name].clone:remove() end
        freecam_data[name] = nil
    end
end)
