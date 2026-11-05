-- Shared playback engine for /radio, DJ stations and /radiocar.
-- One in-memory table of "active broadcasts"; every connected client independently figures out
-- how loud (if at all) it should hear each one - see client/broadcast.lua.
--
-- /radio is single-user (only its owner can control it, no shared queue). DJ stations and car
-- radios are collaborative: anyone who can legitimately reach them (standing at the booth for DJ,
-- "actually inside the vehicle" for cars - both re-checked here) can change the current
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
BroadcastProgress = elapsedSeconds

-- Disco light beat grid a DJ tapped in for a song: { bpm, offset }, offset being the song
-- position (seconds) of a downbeat. Kept per video in the resource KVP store, so that song is in
-- sync again the next time anyone plays it, at any booth, even after a restart.
local function tempoKey(videoId)
    return ('tempo:%s'):format(videoId)
end

local function savedTempo(videoId)
    if not videoId or videoId == '' then return nil end
    local raw = GetResourceKvpString(tempoKey(videoId))
    if not raw then return nil end
    local ok, t = pcall(json.decode, raw)
    if ok and type(t) == 'table' and tonumber(t.bpm) and tonumber(t.offset) then
        return { bpm = tonumber(t.bpm), offset = tonumber(t.offset) }
    end
    return nil
end

---Display name for a broadcast - the booth's label for DJ stations (shown in the nearby
---now-playing widget and the admin panel).
---@param b table
---@return string
function BroadcastLabel(b)
    if b.kind == 'dj' then
        local station = DjStations[b.stationId]
        return station and station.label or 'DJ booth'
    end
    if b.kind == 'radiocar' then return 'Car radio' end
    return 'Personal radio'
end

function SyncBroadcasts()
    local payload = {}
    for id, b in pairs(ActiveBroadcasts) do
        payload[id] = {
            id = id,
            kind = b.kind,
            label = BroadcastLabel(b),
            owner = b.owner,
            stationId = b.stationId,
            vehicleNetId = b.vehicleNetId,
            song = b.song,
            queue = b.queue,
            volume = b.volume,
            playing = b.playing,
            progress = elapsedSeconds(b),
            tempo = b.tempo,
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
        tempo = b.tempo,
    }
end

local function isOccupantOf(source, vehicleNetId)
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not vehicle or vehicle == 0 then return false end
    local ped = GetPlayerPed(source)
    return GetVehiclePedIsIn(ped, false) == vehicle
end

---DJ booths are only run from the booth itself: whoever changes its music has to be standing at
---it right now, not just have opened it at some point.
local function isAtStation(source, station)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false end
    local pos = vector3(station.pos_x, station.pos_y, station.pos_z)
    return #(GetEntityCoords(ped) - pos) <= (Config.Placement.controlRange or 25.0)
end

---Personal radio stays single-user; DJ stations and car radios are collaborative - anyone at the
---booth (and with the job, on job-restricted ones) or inside that specific vehicle right now may
---control them.
local function canControl(source, id)
    local b = ActiveBroadcasts[id]
    if not b then return false end
    local ban = GetRadioBan(source, b.kind)
    if ban then
        NotifyRadioBan(source, ban)
        return false
    end
    if b.kind == 'radio' then return b.owner == source end
    if b.kind == 'dj' then
        local station = DjStations[b.stationId]
        return station ~= nil and isAtStation(source, station) and CanUseDjStation(source, station)
    end
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
    if b.kind == 'dj' then b.tempo = savedTempo(b.song.videoId) end
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
        if not DjStations[ctxId] or not isAtStation(source, DjStations[ctxId]) then return end
        if not CanUseDjStation(source, DjStations[ctxId]) then
            TriggerClientEvent('kariee_radio:notify', source, Config.Messages.dj_no_access)
            return
        end
    elseif kind == 'radiocar' then
        if not isOccupantOf(source, ctxId) then return end
    elseif kind ~= 'radio' then
        return
    end

    local ban = GetRadioBan(source, kind)
    if ban then
        NotifyRadioBan(source, ban)
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
        startedAt = os.time(),
        gen = gen,
    }
    if kind == 'dj' then ActiveBroadcasts[id].tempo = savedTempo(ActiveBroadcasts[id].song.videoId) end

    local identifier = GetIdentifier(source)
    if identifier then RecordRecentlyPlayed(identifier, song) end

    local played = ActiveBroadcasts[id].song
    LogRadioActivity(source, 'play', ('“%s” by %s'):format(played.title, played.artist), {
        kind = kind,
        label = BroadcastLabel(ActiveBroadcasts[id]),
        videoId = played.videoId,
    })

    syncAll()
    scheduleEnd(id, gen, ActiveBroadcasts[id].song.duration)
end)

---Pauses / resumes a broadcast, keeping its clock and end-of-song timer right.
local function setPlaying(id, b, playing)
    if playing then
        b.playing = true
        b.updatedAt = GetGameTimer()
        b.gen = b.gen + 1
        scheduleEnd(id, b.gen, b.song.duration - b.progressAt)
    else
        b.progressAt = elapsedSeconds(b)
        b.playing = false
    end
    b.updatedAt = GetGameTimer()
end

RegisterNetEvent('kariee_radio:broadcast:togglePlay', function(id)
    local source = source
    if not canControl(source, id) then return end
    local b = ActiveBroadcasts[id]
    b.pausedIndoors = nil
    setPlaying(id, b, not b.playing)
    syncAll()
end)

-- The personal radio isn't allowed inside interiors: one started outside pauses when its owner
-- walks in and picks up again when they step back out (client/broadcast.lua reports it). Only the
-- sender's own radio, so there's nothing here worth abusing.
RegisterNetEvent('kariee_radio:broadcast:indoors', function(indoors)
    local source = source
    local id = buildId('radio', nil, source)
    local b = ActiveBroadcasts[id]
    if not b then return end
    if indoors == true then
        if not b.playing then return end
        setPlaying(id, b, false)
        b.pausedIndoors = true
    elseif b.pausedIndoors then
        b.pausedIndoors = nil
        if b.playing then return end
        setPlaying(id, b, true)
    else
        return
    end
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

-- Tap tempo from the NUI (DJ booths only - that's where the lights are). No bpm clears it.
RegisterNetEvent('kariee_radio:broadcast:setTempo', function(id, bpm, offset)
    local source = source
    if not canControl(source, id) then return end
    local b = ActiveBroadcasts[id]
    local videoId = b.song and b.song.videoId
    if b.kind ~= 'dj' or not videoId or videoId == '' then return end

    bpm, offset = tonumber(bpm), tonumber(offset)
    if bpm and offset and bpm >= 60 and bpm <= 200 then
        -- Any downbeat will do; keep the first one in the song so the number stays small.
        b.tempo = { bpm = bpm, offset = offset % (4 * 60.0 / bpm) }
        SetResourceKvp(tempoKey(videoId), json.encode(b.tempo))
    else
        b.tempo = nil
        DeleteResourceKvp(tempoKey(videoId))
    end
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

---Replaces the whole shared "up next" list in one go - used for drag-to-reorder, shuffling and
---clearing the queue on DJ stations / car radios. Songs go through the same SerializeSong
---validation as enqueue, and the list is capped so a client can't push an unbounded table.
RegisterNetEvent('kariee_radio:broadcast:setQueue', function(id, songs)
    local source = source
    if not canControl(source, id) then return end
    local b = ActiveBroadcasts[id]
    if b.kind == 'radio' then return end
    if type(songs) ~= 'table' then return end
    local capped = {}
    for i = 1, math.min(#songs, 200) do capped[i] = songs[i] end
    b.queue = serializeQueue(capped)
    syncAll()
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
