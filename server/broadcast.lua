-- Shared playback engine for /radio, DJ stations and /radiocar.
-- One in-memory table of "active broadcasts"; every connected client independently figures out
-- how loud (if at all) it should hear each one - see client/broadcast.lua.
--
-- /radio is single-user (only its owner can control it, no shared queue). DJ stations and car
-- radios are collaborative: anyone who can legitimately reach them (proximity-gated client-side
-- via ox_target/commands for DJ, "actually inside the vehicle" for cars) can change the current
-- song or add to a shared queue, and everyone watching that same broadcast sees the same thing.

---@type table<string, table>
ActiveBroadcasts = {}

local function buildId(kind, ctxId, source)
    if kind == 'radio' then return ('radio:%s'):format(source) end
    if kind == 'dj' then return ('dj:%s'):format(ctxId) end
    if kind == 'radiocar' then return ('car:%s'):format(ctxId) end
    return nil
end

local function elapsedSeconds(b)
    if not b.playing then return b.progressAt end
    return b.progressAt + (GetGameTimer() - b.updatedAt) / 1000.0
end

function SyncBroadcasts()
    local payload = {}
    for id, b in pairs(ActiveBroadcasts) do
        payload[id] = {
            id = id,
            kind = b.kind,
            owner = b.owner,
            stationId = b.stationId,
            vehicleNetId = b.vehicleNetId,
            song = b.song,
            queue = b.queue,
            volume = b.volume,
            playing = b.playing,
            progress = elapsedSeconds(b),
        }
    end
    TriggerClientEvent('kariee_radio:broadcast:sync', -1, payload)
end
local syncAll = SyncBroadcasts

---Used by server/social.lua's getState callback to hydrate a reopening NUI. `context.id` is
---already the exact ActiveBroadcasts key (client/main.lua builds it the same way buildId() would).
---@param context table|nil { kind = 'radio'|'dj'|'radiocar', id, stationId, vehicleNetId }
function GetBroadcastSnapshotFor(context)
    if not context or not context.id then return nil end
    local b = ActiveBroadcasts[context.id]
    if not b then return nil end
    return {
        id = context.id,
        song = b.song,
        queue = b.queue,
        volume = b.volume,
        playing = b.playing,
        progress = elapsedSeconds(b),
    }
end

local function isOccupantOf(source, vehicleNetId)
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not vehicle or vehicle == 0 then return false end
    local ped = GetPlayerPed(source)
    return GetVehiclePedIsIn(ped, false) == vehicle
end

---Personal radio stays single-user; DJ stations and car radios are collaborative - anyone who
---got hold of the id through the normal, proximity-gated flow (ox_target/commands) may control
---them, except car radios still require actually being inside that specific vehicle right now.
local function canControl(source, id)
    local b = ActiveBroadcasts[id]
    if not b then return false end
    if b.kind == 'radio' then return b.owner == source end
    if b.kind == 'dj' then return true end
    if b.kind == 'radiocar' then return isOccupantOf(source, b.vehicleNetId) end
    return false
end

local scheduleEnd
local advanceQueue

scheduleEnd = function(id, gen, duration)
    if not duration or duration <= 0 then return end
    SetTimeout(math.floor(duration * 1000) + 250, function()
        local b = ActiveBroadcasts[id]
        if not b or b.gen ~= gen or not b.playing then return end
        if elapsedSeconds(b) + 0.5 < duration then return end -- was seeked, not actually finished
        advanceQueue(id, b)
    end)
end

---Pops the next queued song into `song`, or (for DJ stations) loops the current one so the room
---keeps going even if nobody's actively curating it, or otherwise just stops.
advanceQueue = function(id, b)
    local nextSong = table.remove(b.queue, 1)
    if nextSong then
        b.song = nextSong
    elseif b.kind ~= 'dj' then
        ActiveBroadcasts[id] = nil
        syncAll()
        return
    end
    b.progressAt = 0
    b.updatedAt = GetGameTimer()
    b.gen = b.gen + 1
    syncAll()
    scheduleEnd(id, b.gen, b.song.duration)
end

local function serializeQueue(songs)
    local queue = {}
    if type(songs) == 'table' then
        for _, s in ipairs(songs) do
            if type(s) == 'table' and s.videoId then queue[#queue + 1] = SerializeSong(s) end
        end
    end
    return queue
end

RegisterNetEvent('kariee_radio:broadcast:play', function(kind, ctxId, song, volume, queueSongs)
    local source = source
    if type(song) ~= 'table' or not song.videoId then return end

    if kind == 'dj' then
        if not DjStations[ctxId] then return end
    elseif kind == 'radiocar' then
        if not isOccupantOf(source, ctxId) then return end
    elseif kind ~= 'radio' then
        return
    end

    local id = buildId(kind, ctxId, source)
    if not id then return end

    local existing = ActiveBroadcasts[id]
    local gen = (existing and existing.gen or 0) + 1

    ActiveBroadcasts[id] = {
        kind = kind,
        owner = source,
        stationId = kind == 'dj' and ctxId or nil,
        vehicleNetId = kind == 'radiocar' and ctxId or nil,
        song = SerializeSong(song),
        queue = serializeQueue(queueSongs),
        volume = tonumber(volume) or 68,
        playing = true,
        progressAt = 0,
        updatedAt = GetGameTimer(),
        gen = gen,
    }

    local identifier = GetIdentifier(source)
    if identifier then RecordRecentlyPlayed(identifier, song) end

    syncAll()
    scheduleEnd(id, gen, ActiveBroadcasts[id].song.duration)
end)

RegisterNetEvent('kariee_radio:broadcast:togglePlay', function(id)
    local source = source
    if not canControl(source, id) then return end
    local b = ActiveBroadcasts[id]
    if b.playing then
        b.progressAt = elapsedSeconds(b)
        b.playing = false
    else
        b.playing = true
        b.updatedAt = GetGameTimer()
        b.gen = b.gen + 1
        scheduleEnd(id, b.gen, b.song.duration - b.progressAt)
    end
    b.updatedAt = GetGameTimer()
    syncAll()
end)

RegisterNetEvent('kariee_radio:broadcast:seek', function(id, seconds)
    local source = source
    if not canControl(source, id) then return end
    local b = ActiveBroadcasts[id]
    b.progressAt = math.max(0, tonumber(seconds) or 0)
    b.updatedAt = GetGameTimer()
    b.gen = b.gen + 1
    if b.playing then scheduleEnd(id, b.gen, b.song.duration - b.progressAt) end
    syncAll()
end)

RegisterNetEvent('kariee_radio:broadcast:setVolume', function(id, volume)
    local source = source
    if not canControl(source, id) then return end
    ActiveBroadcasts[id].volume = math.min(100, math.max(0, tonumber(volume) or 0))
    syncAll()
end)

RegisterNetEvent('kariee_radio:broadcast:stop', function(id)
    local source = source
    if not canControl(source, id) then return end
    ActiveBroadcasts[id] = nil
    syncAll()
end)

RegisterNetEvent('kariee_radio:broadcast:next', function(id)
    local source = source
    if not canControl(source, id) then return end
    local b = ActiveBroadcasts[id]
    if b.kind == 'radio' then return end -- personal radio queue is client-local
    advanceQueue(id, b)
end)

RegisterNetEvent('kariee_radio:broadcast:enqueue', function(id, song)
    local source = source
    if not canControl(source, id) then return end
    if type(song) ~= 'table' or not song.videoId then return end
    local b = ActiveBroadcasts[id]
    if b.kind == 'radio' then return end
    b.queue[#b.queue + 1] = SerializeSong(song)
    syncAll()
end)

RegisterNetEvent('kariee_radio:broadcast:enqueueNext', function(id, song)
    local source = source
    if not canControl(source, id) then return end
    if type(song) ~= 'table' or not song.videoId then return end
    local b = ActiveBroadcasts[id]
    if b.kind == 'radio' then return end
    table.insert(b.queue, 1, SerializeSong(song))
    syncAll()
end)

RegisterNetEvent('kariee_radio:broadcast:removeFromQueue', function(id, index)
    local source = source
    if not canControl(source, id) then return end
    local b = ActiveBroadcasts[id]
    if b.kind == 'radio' then return end
    index = tonumber(index)
    if index and b.queue[index + 1] then -- client sends a 0-based index
        table.remove(b.queue, index + 1)
        syncAll()
    end
end)

AddEventHandler('playerDropped', function()
    local source = source
    local id = buildId('radio', nil, source)
    if ActiveBroadcasts[id] then
        ActiveBroadcasts[id] = nil
        syncAll()
    end
end)

-- Car radios are keyed by the vehicle's network id, which FiveM *can* reassign to a brand new
-- vehicle once the original is deleted (garaged, despawned, ...). Without this, a stale broadcast
-- would silently keep "existing" and start playing again in whatever car next gets that id.
-- Event-driven (not polled) so it fires the instant the vehicle is actually removed, and never
-- calls NetworkGetEntityFromNetworkId on an id that's already gone (that's what was spamming the
-- "no object by ID" engine warning).
AddEventHandler('entityRemoved', function(entity)
    if GetEntityType(entity) ~= 2 then return end -- 2 = vehicle
    local netId = NetworkGetNetworkIdFromEntity(entity)
    if not netId or netId == 0 then return end
    local id = ('car:%s'):format(netId)
    if ActiveBroadcasts[id] then
        ActiveBroadcasts[id] = nil
        syncAll()
    end
end)
