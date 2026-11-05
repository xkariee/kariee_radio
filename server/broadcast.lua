ActiveBroadcasts = {}

local MAX_QUEUE = 200

local advanceQueue

local function isSong(song)
    return type(song) == 'table' and type(song.videoId) == 'string' and song.videoId ~= ''
end

local function buildId(kind, ctxId, source)
    if kind == 'radio' then return ('radio:%s'):format(source) end
    if kind == 'dj' then return ('dj:%s'):format(ctxId) end
    if kind == 'radiocar' then return ('car:%s'):format(ctxId) end
end

local function tempoKey(videoId)
    return ('tempo:%s'):format(videoId)
end

local function savedTempo(videoId)
    if not videoId or videoId == '' then return nil end
    local tempo = DecodeJson(GetResourceKvpString(tempoKey(videoId)))
    local bpm = type(tempo) == 'table' and tonumber(tempo.bpm)
    local offset = type(tempo) == 'table' and tonumber(tempo.offset)
    if bpm and offset then return { bpm = bpm, offset = offset } end
end

local function serializeQueue(songs)
    local queue = {}
    for i, song in ipairs(type(songs) == 'table' and songs or {}) do
        if i > MAX_QUEUE then break end
        if isSong(song) then queue[#queue + 1] = SerializeSong(song) end
    end
    return queue
end

function BroadcastProgress(b)
    if not b.playing then return b.progressAt end
    return b.progressAt + (GetGameTimer() - b.updatedAt) / 1000.0
end

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
            progress = BroadcastProgress(b),
            tempo = b.tempo,
        }
    end
    TriggerClientEvent('kariee_radio:broadcast:sync', -1, payload)
end

function StopBroadcast(id)
    if not ActiveBroadcasts[id] then return false end
    ActiveBroadcasts[id] = nil
    return true
end

function GetBroadcastSnapshotFor(context)
    local b = context and context.id and ActiveBroadcasts[context.id]
    if not b then return nil end
    return {
        id = context.id,
        song = b.song,
        queue = b.queue,
        volume = b.volume,
        playing = b.playing,
        progress = BroadcastProgress(b),
        tempo = b.tempo,
    }
end

local function isOccupantOf(source, vehicleNetId)
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not vehicle or vehicle == 0 then return false end
    return GetVehiclePedIsIn(GetPlayerPed(source), false) == vehicle
end

local function isAtStation(source, station)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false end
    local pos = vector3(station.pos_x, station.pos_y, station.pos_z)
    return #(GetEntityCoords(ped) - pos) <= (Config.Placement.controlRange or 25.0)
end

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

local function scheduleEnd(id, b)
    local duration = b.song and tonumber(b.song.duration) or 0
    local remaining = duration - b.progressAt
    if not b.playing or remaining <= 0 then return end

    local gen = b.gen
    SetTimeout(math.floor(remaining * 1000) + 250, function()
        if ActiveBroadcasts[id] ~= b or b.gen ~= gen or not b.playing then return end
        if BroadcastProgress(b) + 0.5 < duration then return end
        advanceQueue(id, b)
    end)
end

local function restartClock(id, b)
    b.updatedAt = GetGameTimer()
    b.gen = b.gen + 1
    scheduleEnd(id, b)
end

local function setPlaying(id, b, playing)
    if not playing then b.progressAt = BroadcastProgress(b) end
    b.playing = playing
    restartClock(id, b)
end

advanceQueue = function(id, b)
    local nextSong = table.remove(b.queue, 1)
    if nextSong then
        b.song = nextSong
    elseif b.kind ~= 'dj' then
        StopBroadcast(id)
        return SyncBroadcasts()
    end
    if b.kind == 'dj' then b.tempo = savedTempo(b.song.videoId) end
    b.progressAt = 0
    restartClock(id, b)
    SyncBroadcasts()
end

local function onControl(name, handler)
    RegisterNetEvent(('kariee_radio:broadcast:%s'):format(name), function(id, ...)
        local source = source
        if canControl(source, id) then handler(id, ActiveBroadcasts[id], ...) end
    end)
end

local function onQueueControl(name, handler)
    onControl(name, function(id, b, ...)
        if b.kind ~= 'radio' then handler(id, b, ...) end
    end)
end

RegisterNetEvent('kariee_radio:broadcast:play', function(kind, ctxId, song, volume, queue)
    local source = source
    if not isSong(song) then return end

    if kind == 'dj' then
        local station = DjStations[ctxId]
        if not station or not isAtStation(source, station) then return end
        if not CanUseDjStation(source, station) then
            return TriggerClientEvent('kariee_radio:notify', source, 'dj_no_access')
        end
    elseif kind == 'radiocar' then
        if not isOccupantOf(source, ctxId) then return end
    elseif kind ~= 'radio' then
        return
    end

    local ban = GetRadioBan(source, kind)
    if ban then return NotifyRadioBan(source, ban) end

    local id = buildId(kind, ctxId, source)
    local existing = ActiveBroadcasts[id]
    local b = {
        kind = kind,
        owner = source,
        stationId = kind == 'dj' and ctxId or nil,
        vehicleNetId = kind == 'radiocar' and ctxId or nil,
        song = SerializeSong(song),
        queue = serializeQueue(queue),
        volume = math.min(100, math.max(0, tonumber(volume) or 68)),
        playing = true,
        progressAt = 0,
        updatedAt = GetGameTimer(),
        startedAt = os.time(),
        gen = (existing and existing.gen or 0) + 1,
    }
    if kind == 'dj' then b.tempo = savedTempo(b.song.videoId) end

    ActiveBroadcasts[id] = b
    SyncBroadcasts()
    scheduleEnd(id, b)

    LogRadioActivity(source, 'play', ('“%s” by %s'):format(b.song.title, b.song.artist), {
        kind = kind,
        label = BroadcastLabel(b),
        videoId = b.song.videoId,
    })

    local identifier = GetIdentifier(source)
    if identifier then RecordRecentlyPlayed(identifier, song) end
end)

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
    SyncBroadcasts()
end)

onControl('togglePlay', function(id, b)
    b.pausedIndoors = nil
    setPlaying(id, b, not b.playing)
    SyncBroadcasts()
end)

onControl('seek', function(id, b, seconds)
    b.progressAt = math.max(0, tonumber(seconds) or 0)
    restartClock(id, b)
    SyncBroadcasts()
end)

onControl('setTempo', function(_, b, bpm, offset)
    local videoId = b.song and b.song.videoId
    if b.kind ~= 'dj' or not videoId or videoId == '' then return end

    bpm, offset = tonumber(bpm), tonumber(offset)
    if bpm and offset and bpm >= 60 and bpm <= 200 then
        b.tempo = { bpm = bpm, offset = offset % (4 * 60.0 / bpm) }
        SetResourceKvp(tempoKey(videoId), json.encode(b.tempo))
    else
        b.tempo = nil
        DeleteResourceKvp(tempoKey(videoId))
    end
    SyncBroadcasts()
end)

onControl('setVolume', function(_, b, volume)
    b.volume = math.min(100, math.max(0, tonumber(volume) or 0))
    SyncBroadcasts()
end)

onControl('stop', function(id)
    StopBroadcast(id)
    SyncBroadcasts()
end)

onQueueControl('next', function(id, b)
    advanceQueue(id, b)
end)

onQueueControl('enqueue', function(_, b, song)
    if not isSong(song) or #b.queue >= MAX_QUEUE then return end
    b.queue[#b.queue + 1] = SerializeSong(song)
    SyncBroadcasts()
end)

onQueueControl('enqueueNext', function(_, b, song)
    if not isSong(song) or #b.queue >= MAX_QUEUE then return end
    table.insert(b.queue, 1, SerializeSong(song))
    SyncBroadcasts()
end)

onQueueControl('removeFromQueue', function(_, b, index)
    index = tonumber(index)
    if not index or not b.queue[index + 1] then return end
    table.remove(b.queue, index + 1)
    SyncBroadcasts()
end)

onQueueControl('setQueue', function(_, b, songs)
    if type(songs) ~= 'table' then return end
    b.queue = serializeQueue(songs)
    SyncBroadcasts()
end)

AddEventHandler('playerDropped', function()
    if StopBroadcast(buildId('radio', nil, source)) then SyncBroadcasts() end
end)

AddEventHandler('entityRemoved', function(entity)
    if GetEntityType(entity) ~= 2 then return end
    local netId = NetworkGetNetworkIdFromEntity(entity)
    if netId and netId ~= 0 and StopBroadcast(('car:%s'):format(netId)) then SyncBroadcasts() end
end)
