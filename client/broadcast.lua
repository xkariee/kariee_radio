local broadcasts = {}
local lastVolume = {}
local lastNear = {}
local audioClock = {}
local syncedAt = 0
local backProp = nil
local reportedIndoors = nil

function IsBroadcastPlaying(id)
    local b = broadcasts[id]
    return b ~= nil and b.playing == true
end

function IsBroadcastNear(id)
    return lastNear[id] == true
end

function BroadcastTempo(id)
    local b = broadcasts[id]
    return b and b.tempo or nil
end

function BroadcastSongTime(id)
    local b = broadcasts[id]
    if not b or not b.song then return nil end
    local now = GetGameTimer()

    local clock = audioClock[id]
    if clock and clock.videoId == b.song.videoId and now - clock.at < 2500 then
        return clock.playing and clock.time + (now - clock.at) / 1000.0 or clock.time
    end

    local progress = tonumber(b.progress) or 0.0
    if b.playing then progress = progress + (now - syncedAt) / 1000.0 end
    return progress
end

local function updateBackProp(playing)
    if not (Config.ShowBackProp and playing) then
        Utils:DeleteProp(backProp)
        backProp = nil
        return
    end
    if backProp and DoesEntityExist(backProp) then return end

    local model = Config.BackModel
    if not Utils:LoadModel(model) then return end
    local offset, rotation = Config.BackPropOffset, Config.BackPropRotation
    backProp = CreateObject(model, 0.0, 0.0, 0.0, true, true, false)
    AttachEntityToEntity(
        backProp, Utils.ped, GetPedBoneIndex(Utils.ped, Config.BackPropBone),
        offset.x, offset.y, offset.z, rotation.x, rotation.y, rotation.z,
        true, true, false, true, 1, true
    )
    SetModelAsNoLongerNeeded(model)
end

local function resolve(b, coords)
    if b.kind == 'radio' then
        local player = GetPlayerFromServerId(b.owner)
        if player == -1 then return nil end
        local ped = GetPlayerPed(player)
        if ped == 0 then return nil end
        return GetEntityCoords(ped), GetInteriorFromEntity(Utils.ped) ~= GetInteriorFromEntity(ped), false, Config.MaxRange
    end

    if b.kind == 'dj' then
        local station = DjStations[b.stationId]
        if not station then return nil end
        local audio = DjAudioOf(station)

        if audio.type == 'area' then
            local inside, outside = DjAreaDistance(audio, coords)
            if inside then return station.coords, false, true, audio.fade end
            return station.coords, false, false, math.max(0.1, audio.fade), outside
        end

        if audio.type == 'interior' and station.interiorId ~= 0 then
            local inside = GetInteriorFromEntity(Utils.ped) == station.interiorId
            return station.coords, not inside, inside, audio.muffled
        end

        return station.coords, false, false, audio.range or Config.DjOutdoorRange
    end

    if b.kind == 'radiocar' then
        local vehicle = NetworkGetEntityFromNetworkId(b.vehicleNetId)
        if vehicle == 0 or not DoesEntityExist(vehicle) then return nil end
        if Utils.vehicle == vehicle then return coords, false, true, Config.MaxRange end

        local sealed = true
        for door = 0, 5 do
            if GetVehicleDoorAngleRatio(vehicle, door) > Config.DoorOpenThreshold then
                sealed = false
                break
            end
        end
        return GetEntityCoords(vehicle), sealed, false, Config.MaxRange
    end
end

RegisterNetEvent('kariee_radio:broadcast:sync', function(payload)
    broadcasts = payload or {}
    syncedAt = GetGameTimer()
    SendNUIMessage({ action = 'broadcastSync', broadcasts = broadcasts })
    updateBackProp(IsBroadcastPlaying(Utils:RadioId()))
end)

RegisterNUICallback('audioClock', function(data, cb)
    local now = GetGameTimer()
    for id, clock in pairs(data.clocks or {}) do
        local time = tonumber(clock.time)
        if time then
            local previous = audioClock[id]
            if previous and previous.videoId == clock.videoId and previous.playing and clock.playing then
                local predicted = previous.time + (now - previous.at) / 1000.0
                if math.abs(time - predicted) < 0.25 then time = predicted + (time - predicted) * 0.3 end
            end
            audioClock[id] = { time = time, at = now, playing = clock.playing == true, videoId = clock.videoId }
        end
    end
    cb({})
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then Utils:DeleteProp(backProp) end
end)

CreateThread(function()
    while true do
        Wait(500)
        local mine = broadcasts[Utils:RadioId()]
        if mine then
            local indoors = Utils:IsIndoors()
            if indoors ~= reportedIndoors or (indoors and mine.playing) then
                reportedIndoors = indoors
                TriggerServerEvent('kariee_radio:broadcast:indoors', indoors)
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(Config.TickInterval)
        local coords = Utils:GetCoords()
        local seen = {}

        for id, b in pairs(broadcasts) do
            seen[id] = true
            local volume, near = 0, false

            local origin, muffled, bypass, range, distance = resolve(b, coords)
            if origin then
                range = range or Config.MaxRange
                distance = bypass and 0 or distance or #(coords - origin)
                near = bypass or distance < range

                if b.playing then
                    volume = b.volume / 100
                    if not bypass then
                        local fade = distance >= range and 0 or 1 - distance / range
                        volume = volume * fade * (muffled and Config.MuffleVolumeFactor or 1.0)
                    end
                end
            end

            if lastVolume[id] == nil or math.abs(lastVolume[id] - volume) > 0.01 or lastNear[id] ~= near then
                lastVolume[id], lastNear[id] = volume, near
                SendNUIMessage({ action = 'volume', id = id, volume = volume, near = near })
            end
        end

        for id in pairs(lastVolume) do
            if not seen[id] then
                lastVolume[id], lastNear[id] = nil, nil
                SendNUIMessage({ action = 'volume', id = id, volume = 0, near = false })
            end
        end
    end
end)
