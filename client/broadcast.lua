-- Mirrors the server's ActiveBroadcasts table and, every Config.TickInterval ms, works out how
-- loud (if at all) *this* client should hear each one. Distance/interior/vehicle-seal logic only
-- - the actual audio playback lives in the NUI (web/src/services/audioEngine.ts).

local broadcasts = {}
local lastVolume = {}
-- Whether we're inside each broadcast's hearing area (its interior, or within range), tracked
-- separately from volume so the nearby now-playing widget also works while it's paused or at 0%.
local lastNear = {}

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

-- GetGameTimer() when the last sync arrived, so the server's progress can be run forward locally.
local syncedAt = 0

RegisterNetEvent('kariee_radio:broadcast:sync', function(payload)
    broadcasts = payload or {}
    syncedAt = GetGameTimer()
    SendNUIMessage({ action = 'broadcastSync', broadcasts = broadcasts })

    local mine = broadcasts[myRadioId]
    updateBackProp(mine ~= nil and mine.playing == true)
end)

-- ─── Personal radio pauses indoors ─────────────────────────────────────────
-- The personal radio isn't allowed inside interiors, so one started outside pauses (for everyone)
-- as soon as you walk in and resumes when you step back out - the server keeps track of which
-- pause was ours, so a radio you paused yourself stays paused.

local reportedIndoors = nil

CreateThread(function()
    while true do
        Wait(500)
        local mine = broadcasts[myRadioId]
        if mine then
            local indoors = GetInteriorFromEntity(PlayerPedId()) ~= 0
            -- Re-sent while it's still playing in here, until the paused state syncs back.
            if indoors ~= reportedIndoors or (indoors and mine.playing) then
                reportedIndoors = indoors
                TriggerServerEvent('kariee_radio:broadcast:indoors', indoors)
            end
        end
    end
end)

---Whether a broadcast is currently playing / whether this client is inside its hearing area
---(used by client/lights.lua so disco lights only run while there's music to dance to).
function IsBroadcastPlaying(id)
    local b = broadcasts[id]
    return b ~= nil and b.playing == true
end

-- ─── Song clock for the disco lights ───────────────────────────────────────
-- The NUI reports where each DJ booth's YouTube player actually is twice a second; between
-- reports it's run forward on the game timer. That's what this client *hears*, so the lights stay
-- on the beat through seeks and buffering. The server's clock is the fallback.

local audioClock = {}

RegisterNUICallback('audioClock', function(data, cb)
    local now = GetGameTimer()
    for id, c in pairs(data.clocks or {}) do
        local t = tonumber(c.time)
        if t then
            local prev = audioClock[id]
            if prev and prev.videoId == c.videoId and prev.playing and c.playing then
                -- Small differences are report jitter: ease towards them so the beat doesn't twitch.
                local predicted = prev.time + (now - prev.at) / 1000.0
                if math.abs(t - predicted) < 0.25 then t = predicted + (t - predicted) * 0.3 end
            end
            audioClock[id] = { time = t, at = now, playing = c.playing == true, videoId = c.videoId }
        end
    end
    cb({})
end)

---Seconds into the current song of a broadcast, as heard here.
---@return number|nil
function BroadcastSongTime(id)
    local b = broadcasts[id]
    if not b or not b.song then return nil end
    local now = GetGameTimer()

    local c = audioClock[id]
    if c and c.videoId == b.song.videoId and now - c.at < 2500 then
        return c.playing and c.time + (now - c.at) / 1000.0 or c.time
    end

    local p = tonumber(b.progress) or 0.0
    if b.playing then p = p + (now - syncedAt) / 1000.0 end
    return p
end

---The beat grid set by tapping along in the NUI: { bpm, offset } or nil (use the default).
function BroadcastTempo(id)
    local b = broadcasts[id]
    return b and b.tempo or nil
end

function IsBroadcastNear(id)
    return lastNear[id] == true
end

---@return vector3|nil sourcePos, boolean muffled, boolean bypassFadeFullVolume, number range, number|nil distance
---`distance` overrides the straight-line distance to sourcePos (custom sound areas measure from
---the area's edge instead).
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
        local audio = DjAudioOf(station)

        -- Custom area drawn in the creator: full volume anywhere inside it, fading out over
        -- `fade` metres beyond its edge.
        if audio.type == 'area' then
            local inside, outside = DjAreaDistance(audio, myCoords)
            if inside then return sourcePos, false, true, audio.fade end
            return sourcePos, false, false, math.max(0.1, audio.fade), outside
        end

        if audio.type == 'interior' and station.interiorId ~= 0 then
            -- Standing in the same interior as the console: it fills the whole place evenly,
            -- distance doesn't matter. Outside it, it's heard muffled up to `muffled` metres.
            if GetInteriorFromEntity(myPed) == station.interiorId then
                return sourcePos, false, true, audio.muffled
            end
            return sourcePos, true, false, audio.muffled
        end

        -- Radius (outdoor default): an open-air rig carries much further than a personal radio.
        return sourcePos, false, false, audio.range or Config.DjOutdoorRange
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
            local near = false

            local sourcePos, muffled, bypass, range, distOverride = resolve(b, myPed, myCoords)
            if sourcePos then
                range = range or Config.MaxRange
                local distance = bypass and 0 or (distOverride or #(myCoords - sourcePos))
                near = bypass or distance < range

                if b.playing then
                    if bypass then
                        volume = b.volume / 100
                    else
                        local fade = distance >= range and 0 or (1 - distance / range)
                        local muffle = muffled and Config.MuffleVolumeFactor or 1.0
                        volume = (b.volume / 100) * fade * muffle
                    end
                end
            end

            if lastVolume[id] == nil or math.abs(lastVolume[id] - volume) > 0.01 or lastNear[id] ~= near then
                lastVolume[id] = volume
                lastNear[id] = near
                SendNUIMessage({ action = 'volume', id = id, volume = volume, near = near })
            end
        end

        for id in pairs(lastVolume) do
            if not seen[id] then
                lastVolume[id] = nil
                lastNear[id] = nil
                SendNUIMessage({ action = 'volume', id = id, volume = 0, near = false })
            end
        end
    end
end)
