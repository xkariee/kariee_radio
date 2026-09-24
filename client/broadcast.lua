-- Mirrors the server's ActiveBroadcasts table and, every Config.TickInterval ms, works out how
-- loud (if at all) *this* client should hear each one. Distance/interior/vehicle-seal logic only
-- - the actual audio playback lives in the NUI (web/src/services/audioEngine.ts).

local broadcasts = {}
local lastVolume = {}

-- ─── Back prop while your own /radio is playing ────────────────────────────

local myRadioId = ('radio:%s'):format(GetPlayerServerId(PlayerId()))
local backProp = nil

local function destroyBackProp()
    if backProp and DoesEntityExist(backProp) then DeleteObject(backProp) end
    backProp = nil
end

local function spawnBackProp()
    if backProp and DoesEntityExist(backProp) then return end

    local model = Config.BackModel
    if not LoadModel(model) then return end

    local ped = PlayerPedId()
    backProp = CreateObject(model, 0.0, 0.0, 0.0, true, true, false)
    local off, rot = Config.BackPropOffset, Config.BackPropRotation
    AttachEntityToEntity(
        backProp, ped, GetPedBoneIndex(ped, Config.BackPropBone),
        off.x, off.y, off.z, rot.x, rot.y, rot.z,
        true, true, false, true, 1, true
    )
    SetModelAsNoLongerNeeded(model)
end

local function updateBackProp(playing)
    if not Config.ShowBackProp then
        destroyBackProp()
        return
    end
    if playing then spawnBackProp() else destroyBackProp() end
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then destroyBackProp() end
end)

RegisterNetEvent('kariee_radio:broadcast:sync', function(payload)
    broadcasts = payload or {}
    SendNUIMessage({ action = 'broadcastSync', broadcasts = broadcasts })

    local mine = broadcasts[myRadioId]
    updateBackProp(mine ~= nil and mine.playing == true)
end)

---@return vector3|nil sourcePos, boolean muffled, boolean bypassFadeFullVolume, number range
local function resolve(b, myPed, myCoords)
    if b.kind == 'radio' then
        local targetPlayer = GetPlayerFromServerId(b.owner)
        if targetPlayer == -1 then return nil end
        local sourcePed = GetPlayerPed(targetPlayer)
        if sourcePed == 0 then return nil end
        local sourcePos = GetEntityCoords(sourcePed)
        local muffled = GetInteriorFromEntity(myPed) ~= GetInteriorFromEntity(sourcePed)
        return sourcePos, muffled, false, Config.MaxRange
    end

    if b.kind == 'dj' then
        local station = DjStations and DjStations[b.stationId]
        if not station then return nil end
        local sourcePos = vector3(station.pos_x, station.pos_y, station.pos_z)
        if station.interiorId == nil then
            station.interiorId = GetInteriorAtCoords(sourcePos.x, sourcePos.y, sourcePos.z)
        end

        if station.interiorId == 0 then
            -- Placed outdoors: no room to fill, but an open-air rig carries much further.
            return sourcePos, false, false, Config.DjOutdoorRange
        end

        -- Standing in the same room as the console: it fills the whole interior evenly, distance
        -- doesn't matter. Only once you leave that interior does range/muffle start counting.
        if GetInteriorFromEntity(myPed) == station.interiorId then
            return sourcePos, false, true, Config.MaxRange
        end

        local muffled = GetInteriorFromEntity(myPed) ~= station.interiorId
        return sourcePos, muffled, false, Config.MaxRange
    end

    if b.kind == 'radiocar' then
        local vehicle = NetworkGetEntityFromNetworkId(b.vehicleNetId)
        if vehicle == 0 or not DoesEntityExist(vehicle) then return nil end
        if GetVehiclePedIsIn(myPed, false) == vehicle then
            return myCoords, false, true, Config.MaxRange
        end
        local sourcePos = GetEntityCoords(vehicle)
        local sealed = true
        for i = 0, 5 do
            if GetVehicleDoorAngleRatio(vehicle, i) > Config.DoorOpenThreshold then
                sealed = false
                break
            end
        end
        return sourcePos, sealed, false, Config.MaxRange
    end

    return nil
end

CreateThread(function()
    while true do
        Wait(Config.TickInterval)

        local myPed = PlayerPedId()
        local myCoords = GetEntityCoords(myPed)
        local seen = {}

        for id, b in pairs(broadcasts) do
            seen[id] = true
            local volume = 0

            if b.playing then
                local sourcePos, muffled, bypass, range = resolve(b, myPed, myCoords)
                if sourcePos then
                    if bypass then
                        volume = b.volume / 100
                    else
                        range = range or Config.MaxRange
                        local distance = #(myCoords - sourcePos)
                        local fade = distance >= range and 0 or (1 - distance / range)
                        local muffle = muffled and Config.MuffleVolumeFactor or 1.0
                        volume = (b.volume / 100) * fade * muffle
                    end
                end
            end

            if lastVolume[id] == nil or math.abs(lastVolume[id] - volume) > 0.01 then
                lastVolume[id] = volume
                SendNUIMessage({ action = 'volume', id = id, volume = volume })
            end
        end

        for id in pairs(lastVolume) do
            if not seen[id] then
                lastVolume[id] = nil
                SendNUIMessage({ action = 'volume', id = id, volume = 0 })
            end
        end
    end
end)
