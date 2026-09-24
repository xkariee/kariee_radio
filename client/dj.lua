DjStations = {}
local spawnedProps = {}

---@return number|nil model the model hash, or nil if it failed to load in time
local function requestDjModel()
    local model = Config.DjMixerModel
    if not LoadModel(model) then return nil end
    return model
end

---Opens the radio NUI bound to this station.
local function tryOpenDjStation(stationId)
    local station = DjStations[stationId]
    if not station then
        ESX.ShowNotification(Config.Messages.no_station_nearby)
        return
    end

    OpenRadio({ kind = 'dj', id = ('dj:%s'):format(stationId), stationId = stationId })
end

local function spawnStationProp(station)
    if spawnedProps[station.id] and DoesEntityExist(spawnedProps[station.id]) then
        exports.ox_target:removeLocalEntity(spawnedProps[station.id])
        DeleteObject(spawnedProps[station.id])
    end
    local model = requestDjModel()
    if not model then return end
    local obj = CreateObject(model, station.pos_x, station.pos_y, station.pos_z, false, false, false)
    SetEntityHeading(obj, station.heading or 0.0)
    FreezeEntityPosition(obj, true)
    SetEntityCollision(obj, true, true)
    spawnedProps[station.id] = obj
    SetModelAsNoLongerNeeded(model)

    station.interiorId = GetInteriorAtCoords(station.pos_x, station.pos_y, station.pos_z)

    exports.ox_target:addLocalEntity(obj, {
        {
            name = 'kariee_radio_dj_' .. station.id,
            icon = 'fa-solid fa-music',
            label = 'Play Radio',
            distance = Config.Placement.targetDistance,
            onSelect = function() tryOpenDjStation(station.id) end,
        },
    })
end

local function removeStationProp(stationId)
    local obj = spawnedProps[stationId]
    if obj and DoesEntityExist(obj) then
        exports.ox_target:removeLocalEntity(obj)
        DeleteObject(obj)
    end
    spawnedProps[stationId] = nil
end

RegisterNetEvent('kariee_radio:dj:created', function(station)
    DjStations[station.id] = station
    spawnStationProp(station)
end)

RegisterNetEvent('kariee_radio:dj:removed', function(stationId)
    DjStations[stationId] = nil
    removeStationProp(stationId)
end)

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(250) end
    local stations = lib.callback.await('kariee_radio:dj:getAll', false)
    for id, station in pairs(stations or {}) do
        DjStations[id] = station
        spawnStationProp(station)
    end
end)

-- ─── Placement tool ─────────────────────────────────────────────────────────

local function rotationToDirection(rotation)
    local rad = math.pi / 180
    local x, y, z = rotation.x * rad, rotation.y * rad, rotation.z * rad
    return vector3(-math.sin(z) * math.abs(math.cos(x)), math.cos(z) * math.abs(math.cos(x)), math.sin(x))
end

local function raycastGhostPos()
    local camCoords = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(2)
    local dir = rotationToDirection(camRot)
    local dest = camCoords + dir * Config.Placement.maxDistance
    local rayHandle = StartShapeTestRay(camCoords.x, camCoords.y, camCoords.z, dest.x, dest.y, dest.z, 1, PlayerPedId(), 0)
    local _, hit, endCoords = GetShapeTestResult(rayHandle)
    return hit == 1 and endCoords or dest
end

local function runPlacementTool()
    local ped = PlayerPedId()
    local model = requestDjModel()
    if not model then
        ESX.ShowNotification('Failed to load the DJ mixer model, try again.')
        return
    end
    local startCoords = GetEntityCoords(ped)
    local ghost = CreateObject(model, startCoords.x, startCoords.y, startCoords.z, false, false, false)
    SetEntityAlpha(ghost, 180, false)
    SetEntityCollision(ghost, false, false)
    SetModelAsNoLongerNeeded(model)

    FreezeEntityPosition(ped, true)

    local heightOffset = 0.0
    local heading = GetEntityHeading(ped)
    local confirmed = false
    local finalPos = startCoords

    while true do
        Wait(0)

        DisableControlAction(0, 24, true)  -- attack
        DisableControlAction(0, 25, true)  -- aim
        DisableControlAction(0, 37, true)  -- weapon wheel
        DisableControlAction(0, 75, true)  -- exit vehicle

        local basePos = raycastGhostPos()
        finalPos = vector3(basePos.x, basePos.y, basePos.z + heightOffset)
        SetEntityCoordsNoOffset(ghost, finalPos.x, finalPos.y, finalPos.z, false, false, false)

        if IsControlPressed(0, 174) then -- INPUT_FRONTEND_LEFT
            heading = (heading + Config.Placement.rotateStep) % 360
        elseif IsControlPressed(0, 175) then -- INPUT_FRONTEND_RIGHT
            heading = (heading - Config.Placement.rotateStep) % 360
        end

        if IsControlPressed(0, 172) then -- INPUT_FRONTEND_UP
            heightOffset = heightOffset + Config.Placement.heightStep
        elseif IsControlPressed(0, 173) then -- INPUT_FRONTEND_DOWN
            heightOffset = heightOffset - Config.Placement.heightStep
        end

        SetEntityHeading(ghost, heading)
        ESX.ShowHelpNotification(Config.Messages.placement_help, true)

        if IsControlJustPressed(0, 201) then -- INPUT_FRONTEND_ACCEPT (Enter)
            confirmed = true
            break
        end

        if IsControlJustPressed(0, 200) then -- INPUT_FRONTEND_PAUSE (Esc)
            confirmed = false
            break
        end
    end

    FreezeEntityPosition(ped, false)
    DeleteObject(ghost)

    if not confirmed then
        ESX.ShowNotification(Config.Messages.placement_cancelled)
        return
    end

    local newInteriorId = GetInteriorAtCoords(finalPos.x, finalPos.y, finalPos.z)
    if newInteriorId ~= 0 then
        for _, station in pairs(DjStations) do
            if station.interiorId == newInteriorId then
                ESX.ShowNotification(Config.Messages.dj_interior_occupied)
                return
            end
        end
    end

    local station, err = lib.callback.await('kariee_radio:dj:create', false, { x = finalPos.x, y = finalPos.y, z = finalPos.z }, heading, 'DJ Station')
    if not station then
        ESX.ShowNotification(err == 'no_permission' and Config.Messages.no_permission or 'Failed to create DJ station.')
        return
    end

    ESX.ShowNotification(Config.Messages.placement_saved)
    OpenRadio({ kind = 'dj', id = ('dj:%s'):format(station.id), stationId = station.id })
end

RegisterCommand('createdj', function()
    if not NetworkIsPlayerActive(PlayerId()) or not PlayerLoaded then
        ESX.ShowNotification(Config.Messages.not_ready)
        return
    end
    CreateThread(runPlacementTool)
end, false)

-- ─── Reopen / remove an existing station ───────────────────────────────────

local function nearestStation()
    local coords = GetEntityCoords(PlayerPedId())
    local closestId, closestDist
    for id, station in pairs(DjStations) do
        local dist = #(coords - vector3(station.pos_x, station.pos_y, station.pos_z))
        if dist <= Config.Placement.interactRange and (not closestDist or dist < closestDist) then
            closestId, closestDist = id, dist
        end
    end
    return closestId
end

RegisterCommand('dj', function()
    local id = nearestStation()
    if not id then
        ESX.ShowNotification(Config.Messages.no_station_nearby)
        return
    end
    tryOpenDjStation(id)
end, false)

RegisterCommand('removedj', function()
    local id = nearestStation()
    if not id then
        ESX.ShowNotification(Config.Messages.no_station_nearby)
        return
    end
    local ok = lib.callback.await('kariee_radio:dj:remove', false, id)
    if ok then
        DjStations[id] = nil
        removeStationProp(id)
    end
    ESX.ShowNotification(ok and Config.Messages.station_removed or Config.Messages.no_permission)
end, false)
