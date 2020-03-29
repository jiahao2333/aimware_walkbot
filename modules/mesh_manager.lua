local walkbot_mesh_manager = {}
local walkbot = nil

local current_area = nil
local cached_areas = {}
local cached_connections = {}
local current_mesh = nil

walkbot_mesh_manager.NAV_MESH_CROUCH = bit.lshift(1, 0)
walkbot_mesh_manager.NAV_MESH_JUMP = bit.lshift(1, 1)
walkbot_mesh_manager.NAV_MESH_NO_JUMP = bit.lshift(1, 3)
walkbot_mesh_manager.NAV_MESH_STAIRS = bit.lshift(1, 13)

function walkbot_mesh_manager.set_mesh(mesh_data)
    current_mesh = mesh_data
    current_area = nil
    cached_areas = {}
    cached_connections = {}
end

function walkbot_mesh_manager.areas()
    if (current_mesh == nil) then return end
    return current_mesh["Areas"]
end

function walkbot_mesh_manager.find_place_by_id(place_id)
    if (current_mesh == nil) then return end
    local found_place = nil

    for i=1, #current_mesh["Places"] do
        local ladder = current_mesh["Places"][i]

        if (ladder["ID"] == place_id) then
            found_place = ladder
            break;
        end
    end

    return found_place
end

function walkbot_mesh_manager.is_current_area(area_id)
    if (current_area == nil) then return false end
    return area_id == current_area["ID"]
end

function walkbot_mesh_manager.find_closest_area(area_vector)
    if (current_mesh == nil) then return end

    local within_areas = {}

    for i=1, #current_mesh["Areas"] do
        local area = current_mesh["Areas"][i]

        if (area_vector.x >= area["NorthWest"]["X"] and
            area_vector.x <= area["SouthEast"]["X"] and
            area_vector.y >= area["NorthWest"]["Y"] and
            area_vector.y <= area["SouthEast"]["Y"] and
            #area["Connections"] > 0
        ) then
            table.insert(within_areas, area)
        end
    end

    if (#within_areas > 0) then
        local within_areas_closest = nil
        local within_areas_closest_distance = 99999
        for i=1, #within_areas do
            local area = within_areas[i]
            local z_distance = math.abs((area_vector.z - area["NorthWest"]["Z"]) + (area_vector.z - area["SouthEast"]["Z"]))

            if z_distance <= within_areas_closest_distance then
                within_areas_closest_distance = z_distance

                within_areas_closest = area
            end
        end
        return within_areas_closest
    end

    local closest_area = nil
    local closest_area_distance = 99999
    for i=1, #current_mesh["Areas"] do
        local area = current_mesh["Areas"][i]

        if (#area["Connections"] > 0) then
            local distance = (area_vector - walkbot_mesh_manager.center_of_node(area)):Length()

            if distance < closest_area_distance then
                closest_area_distance = distance
                closest_area = area
            end
        end
    end

    return closest_area
end

function walkbot_mesh_manager.find_area_by_id(area_id)
    if (current_mesh == nil) then return end

    if (cached_areas[area_id] ~= nil) then
        return cached_areas[area_id]
    end

    local found_area = nil

    for i=1, #current_mesh["Areas"] do
        local area = current_mesh["Areas"][i]

        if (area["ID"] == area_id) then
            found_area = area
            break;
        end
    end

    if (found_area == nil) then return end

    cached_areas[area_id] = found_area

    return found_area
end

function walkbot_mesh_manager.find_ladder_by_id(ladder_id)
    if (current_mesh == nil) then return end
    local found_ladder = nil

    for i=1, #current_mesh["Ladders"] do
        local ladder = current_mesh["Ladders"][i]

        if (ladder["ID"] == ladder_id) then
            found_ladder = ladder
            break;
        end
    end

    return found_ladder
end

local function find_z_at_location(point1, point2, location)
    local z_angle = math.tan(math.rad((point1 - point2):Angles()["pitch"]))
    return point1["z"] + z_angle * (Vector3(point1["x"], point1["y"], 0) - location):Length()
end

local function intersection_north(area, connection_area)
    local north_y = connection_area["SouthEast"]["Y"]
    local south_y = area["NorthWest"]["Y"]
    local west_x = 0
    local east_x = 0

    local north_west_z = 0
    local north_east_z = 0
    local south_east_z = 0
    local south_west_z = 0

    if (area["NorthWest"]["X"] >= connection_area["NorthWest"]["X"]) then
        west_x = area["NorthWest"]["X"]
        south_west_z = area["NorthWest"]["Z"]

        north_west_z = find_z_at_location(
            Vector3(connection_area["NorthWest"]["X"], connection_area["SouthEast"]["Y"], connection_area["SouthWestZ"]),
            Vector3(connection_area["SouthEast"]["X"], connection_area["SouthEast"]["Y"], connection_area["SouthEast"]["Z"]),
            Vector3(area["NorthWest"]["X"], area["NorthWest"]["Y"], 0)
        )

        if (area["NorthWest"]["X"] == connection_area["NorthWest"]["X"]) then
            north_west_z = connection_area["SouthWestZ"]
        end
    else
        west_x = connection_area["NorthWest"]["X"]
        north_west_z = connection_area["SouthWestZ"]

        south_west_z = find_z_at_location(
            Vector3(area["NorthWest"]["X"], area["NorthWest"]["Y"], area["NorthWest"]["Z"]),
            Vector3(area["SouthEast"]["X"], area["NorthWest"]["Y"], area["NorthEastZ"]),
            Vector3(connection_area["NorthWest"]["X"], area["NorthWest"]["Y"], 0)
        )
    end

    if (area["SouthEast"]["X"] <= connection_area["SouthEast"]["X"]) then
        east_x = area["SouthEast"]["X"]
        south_east_z = area["NorthEastZ"]

        north_east_z = find_z_at_location(
            Vector3(connection_area["NorthWest"]["X"], connection_area["SouthEast"]["Y"], connection_area["SouthWestZ"]),
            Vector3(connection_area["SouthEast"]["X"], connection_area["SouthEast"]["Y"], connection_area["SouthEast"]["Z"]),
            Vector3(area["SouthEast"]["X"], area["NorthWest"]["Y"], 0)
        )

        if (area["SouthEast"]["X"] == connection_area["SouthEast"]["X"]) then
            north_east_z = connection_area["SouthEast"]["Z"]
        end
    else
        east_x = connection_area["SouthEast"]["X"]
        north_east_z = connection_area["SouthEast"]["Z"]

        south_east_z = find_z_at_location(
            Vector3(area["NorthWest"]["X"], area["NorthWest"]["Y"], area["NorthWest"]["Z"]),
            Vector3(area["SouthEast"]["X"], area["NorthWest"]["Y"], area["NorthEastZ"]),
            Vector3(connection_area["SouthEast"]["X"], area["NorthWest"]["Y"], 0)
        )
    end

    return Vector3(west_x, north_y, north_west_z), Vector3(east_x, north_y, north_east_z), Vector3(east_x, south_y, south_east_z), Vector3(west_x, south_y, south_west_z)
end

local function intersection_west(area, connection_area)
    local north_y = 0
    local south_y = 0
    local west_x = connection_area["SouthEast"]["X"]
    local east_x = area["NorthWest"]["X"]

    local north_west_z = 0
    local north_east_z = 0
    local south_east_z = 0
    local south_west_z = 0

    if (area["NorthWest"]["Y"] >= connection_area["NorthWest"]["Y"]) then
        north_y = area["NorthWest"]["Y"]
        north_east_z = area["NorthWest"]["Z"]

        north_west_z = find_z_at_location(
            Vector3(connection_area["SouthEast"]["X"], connection_area["NorthWest"]["Y"], connection_area["NorthEastZ"]),
            Vector3(connection_area["SouthEast"]["X"], connection_area["SouthEast"]["Y"], connection_area["SouthEast"]["Z"]),
            Vector3(area["NorthWest"]["X"], area["NorthWest"]["Y"], 0)
        )

        if (area["NorthWest"]["Y"] == connection_area["NorthWest"]["Y"]) then
            north_west_z = connection_area["NorthEastZ"]
        end
    else
        north_y = connection_area["NorthWest"]["Y"]
        north_west_z = connection_area["NorthEastZ"]

        north_east_z = find_z_at_location(
            Vector3(area["NorthWest"]["X"], area["NorthWest"]["Y"], area["NorthWest"]["Z"]),
            Vector3(area["NorthWest"]["X"], area["SouthEast"]["Y"], area["SouthWestZ"]),
            Vector3(connection_area["SouthEast"]["X"], connection_area["NorthWest"]["Y"], 0)
        )
    end

    if (area["SouthEast"]["Y"] <= connection_area["SouthEast"]["Y"]) then
        south_y = area["SouthEast"]["Y"]
        south_east_z = area["SouthWestZ"]

        south_west_z = find_z_at_location(
            Vector3(connection_area["SouthEast"]["X"], connection_area["NorthWest"]["Y"], connection_area["NorthEastZ"]),
            Vector3(connection_area["SouthEast"]["X"], connection_area["SouthEast"]["Y"], connection_area["SouthEast"]["Z"]),
            Vector3(area["NorthWest"]["X"], area["SouthEast"]["Y"], 0)
        )

        if (area["SouthEast"]["Y"] == connection_area["SouthEast"]["Y"]) then
            south_west_z = connection_area["SouthEast"]["Z"]
        end
    else
        south_y = connection_area["SouthEast"]["Y"]
        south_west_z = connection_area["SouthEast"]["Z"]

        south_east_z = find_z_at_location(
            Vector3(area["NorthWest"]["X"], area["NorthWest"]["Y"], area["NorthWest"]["Z"]),
            Vector3(area["NorthWest"]["X"], area["SouthEast"]["Y"], area["SouthWestZ"]),
            Vector3(connection_area["SouthEast"]["X"], connection_area["SouthEast"]["Y"], 0)
        )
    end

    return Vector3(west_x, north_y, north_west_z), Vector3(east_x, north_y, north_east_z), Vector3(east_x, south_y, south_east_z), Vector3(west_x, south_y, south_west_z)
end

local function intersection_south(area, connection_area)
    return intersection_north(connection_area, area)
end

local function intersection_east(area, connection_area)
    return intersection_west(connection_area, area)
end

local function find_connection_intersection(area, connection)
    local direction = connection["Direction"]
    local connection_area = connection["Area"]

    local north_west, north_east, south_east, south_west = nil, nil, nil, nil

    if (direction == 0) then
        north_west, north_east, south_east, south_west = intersection_north(area, connection_area)
    elseif (direction == 1) then
        north_west, north_east, south_east, south_west = intersection_east(area, connection_area)
    elseif (direction == 2) then
        north_west, north_east, south_east, south_west = intersection_south(area, connection_area)
    elseif (direction == 3) then
        north_west, north_east, south_east, south_west = intersection_west(area, connection_area)
    end

    return north_west, north_east, south_east, south_west
end

local function center_between_vectors(v1, v2)
    return (v2 + v1) / 2
end

function walkbot_mesh_manager.connection_walking_point(connection)
    local direction = connection["Direction"]

    if (direction == 0) then
        return center_between_vectors(connection["Intersection"][1], connection["Intersection"][2])
    elseif (direction == 1) then
        return center_between_vectors(connection["Intersection"][2], connection["Intersection"][3])
    elseif (direction == 2) then
        return center_between_vectors(connection["Intersection"][3], connection["Intersection"][4])
    elseif (direction == 3) then
        return center_between_vectors(connection["Intersection"][1], connection["Intersection"][4])
    end
end

function walkbot_mesh_manager.center_of_node(node)
    local top_left = Vector3(node["NorthWest"]["X"], node["NorthWest"]["Y"], node["NorthWest"]["Z"])
    local bottom_right = Vector3(node["SouthEast"]["X"], node["SouthEast"]["Y"], node["SouthEast"]["Z"])
    return (top_left + bottom_right) / 2
end

function walkbot_mesh_manager.center_of_intersection(intersection)
    return (intersection[1] + intersection[3]) / 2
end

function walkbot_mesh_manager.find_connections(area)
    if (area == nil) then return {} end
    if (current_mesh == nil) then return end

    local connections = {}

    if (cached_connections[area["ID"]] ~= nil) then
        return cached_connections[area["ID"]]
    end

    for i=1, #area["Connections"] do
        connections[i] = {}
        connections[i]["Direction"] = area["Connections"][i]["Direction"]
        connections[i]["Area"] = walkbot_mesh_manager.find_area_by_id(area["Connections"][i]["TargetAreaID"])

        local north_west, north_east, south_east, south_west = find_connection_intersection(area, connections[i])
        connections[i]["Intersection"] = {north_west, north_east, south_east, south_west}
    end

    for i=1, #area["LadderConnections"] do
        local ladder = area["LadderConnections"][i]
        local connection_index = #connections + 1

        connections[connection_index] = {}

        local ladder_entity = walkbot_mesh_manager.find_ladder_by_id(ladder["TargetID"])

        if (ladder["Direction"] == 0) then
            connections[connection_index]["Area"] = walkbot_mesh_manager.find_area_by_id(ladder_entity["TopForwardAreaID"])
            if (ladder_entity["Direction"] == 0) then
                connections[connection_index]["Direction"] = 2
            elseif (ladder_entity["Direction"] == 1) then
                connections[connection_index]["Direction"] = 3
            elseif (ladder_entity["Direction"] == 2) then
                connections[connection_index]["Direction"] = 0
            elseif (ladder_entity["Direction"] == 3) then
                connections[connection_index]["Direction"] = 1
            end
        else
            connections[connection_index]["Area"] = walkbot_mesh_manager.find_area_by_id(ladder_entity["BottomAreaID"])
            connections[connection_index]["Direction"] = ladder_entity["Direction"]
        end

        connections[connection_index]["LadderDirection"] = ladder["Direction"]

        local north_west, north_east, south_east, south_west = find_connection_intersection(area, connections[connection_index])
        connections[connection_index]["Intersection"] = {north_west, north_east, south_east, south_west}
    end

    cached_connections[area["ID"]] = connections

    return connections
end

function walkbot_mesh_manager.find_connection_to_target_id(area, target_id)
    local connections =  walkbot_mesh_manager.find_connections(area)
    if (connections == nil) then return end

    for i=1, #connections do
        local connection = connections[i]
        if (connection["Area"]["ID"] == target_id) then
            return connection
        end
    end
end

function walkbot_mesh_manager.current_area()
    return current_area
end

local function update_current_area_id()
    local local_player = entities.GetLocalPlayer()
    if (local_player == nil) then return end

    local local_player_vector = local_player:GetAbsOrigin()

    current_area = walkbot_mesh_manager.find_closest_area(local_player_vector)

    if (current_area == nil) then return end

    walkbot.mesh_navigation.set_origin(current_area["ID"])

    return
end

local function initialize()
    callbacks.Register("CreateMove", "walkbot_debug_update_current_area", update_current_area_id)
end

function walkbot_mesh_manager.connect(walkbot_instance)
    walkbot = walkbot_instance
    initialize()
end

return walkbot_mesh_manager