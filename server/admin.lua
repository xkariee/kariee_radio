local Bans = {}
local Activity = {}
local nameCache = {}
local lastBanNotice = {}

local function identifierOf(source)
    local player = source and FRAMEWORK.GetPlayerFromId(source)
    return player and player.identifier or nil
end

local function playerOf(identifier)
    local player = FRAMEWORK.GetPlayerFromIdentifier(identifier)
    return player and player.source or nil
end

local function playerName(source)
    return GetPlayerName(source) or ('Player %s'):format(source)
end

local function cachedName(identifier)
    if not identifier then return 'Unknown' end
    if not nameCache[identifier] then nameCache[identifier] = GetDisplayName(identifier) end
    return nameCache[identifier]
end

local function notify(source, message)
    if source then TriggerClientEvent('kariee_radio:notify', source, message) end
end

local function formatDuration(minutes)
    if not minutes then return 'permanently' end
    local m = math.floor(minutes)
    if m < 60 then return ('%d min'):format(m) end
    if m < 1440 then return ('%d h'):format(math.floor(m / 60)) end
    local days = math.floor(m / 1440)
    return ('%d day%s'):format(days, days == 1 and '' or 's')
end

local function loadBans()
    Bans = {}
    for _, row in ipairs(MySQL.query.await('SELECT * FROM radio_bans') or {}) do Bans[row.identifier] = row end
end

local function expireIfNeeded(identifier)
    local ban = Bans[identifier]
    if ban and ban.expires_at and ban.expires_at <= os.time() then
        Bans[identifier] = nil
        MySQL.update('DELETE FROM radio_bans WHERE identifier = ?', { identifier })
        return nil
    end
    return ban
end

local function broadcastCoords(b)
    if b.kind == 'dj' then
        local station = DjStations[b.stationId]
        if station then return vector3(station.pos_x, station.pos_y, station.pos_z) end
    elseif b.kind == 'radio' then
        local ped = GetPlayerPed(b.owner)
        if ped and ped ~= 0 then return GetEntityCoords(ped) end
    elseif b.kind == 'radiocar' then
        local vehicle = NetworkGetEntityFromNetworkId(b.vehicleNetId)
        if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then return GetEntityCoords(vehicle) end
    end
end

local function playersNear(coords, radius)
    local count = 0
    for _, playerId in ipairs(GetPlayers()) do
        local ped = GetPlayerPed(playerId)
        if ped ~= 0 and #(GetEntityCoords(ped) - coords) <= radius then count = count + 1 end
    end
    return count
end

local function toTable(coords)
    return coords and { x = coords.x, y = coords.y, z = coords.z } or nil
end

local function stopByAdmin(admin, id, b)
    StopBroadcast(id)
    if b.owner and b.owner ~= admin then notify(b.owner, 'admin_stopped') end
end

function IsRadioAdmin(source)
    if not source or source <= 0 then return false end
    if Config.AdminAce and IsPlayerAceAllowed(source, Config.AdminAce) then return true end

    local player = FRAMEWORK.GetPlayerFromId(source)
    if not player then return false end
    for _, group in ipairs(Config.AdminGroups or {}) do
        if player.hasGroup(group) then return true end
    end
    return false
end

function LogRadioActivity(source, action, detail, extra)
    local entry = {
        t = os.time(),
        action = action,
        detail = detail,
        actorId = source,
        actor = source and playerName(source) or 'Console',
        identifier = identifierOf(source),
    }
    for key, value in pairs(extra or {}) do entry[key] = value end

    Activity[#Activity + 1] = entry
    for _ = 1, #Activity - (Config.ActivityLogSize or 150) do table.remove(Activity, 1) end
end

function GetRadioBan(source, kind)
    local ban = expireIfNeeded(identifierOf(source))
    if not ban then return nil end
    if ban.scope == 'all' then return ban end
    if ban.scope == 'dj' and (kind == nil or kind == 'dj') then return ban end
end

function SerializeRadioBan(ban)
    return ban and { scope = ban.scope, reason = ban.reason, expires_at = ban.expires_at } or nil
end

function NotifyRadioBan(source, ban)
    local now = os.time()
    if lastBanNotice[source] and now - lastBanNotice[source] < 4 then return end
    lastBanNotice[source] = now
    TriggerClientEvent('kariee_radio:banned', source, SerializeRadioBan(ban))
end

OnDatabaseReady(loadBans)

AddEventHandler('playerDropped', function()
    lastBanNotice[source] = nil
end)

lib.callback.register('kariee_radio:admin:isAdmin', function(source)
    return IsRadioAdmin(source)
end)

lib.callback.register('kariee_radio:admin:getData', function(source)
    if not IsRadioAdmin(source) then return nil end
    local radius = Config.AdminNearbyRadius or 50.0

    local broadcasts = {}
    for id, b in pairs(ActiveBroadcasts) do
        local coords = broadcastCoords(b)
        broadcasts[#broadcasts + 1] = {
            id = id,
            kind = b.kind,
            label = BroadcastLabel(b),
            stationId = b.stationId,
            playing = b.playing,
            volume = b.volume,
            progress = BroadcastProgress(b),
            song = b.song,
            queueLength = #(b.queue or {}),
            ownerId = b.owner,
            ownerName = b.owner and GetPlayerName(b.owner) or 'Unknown',
            ownerIdentifier = identifierOf(b.owner),
            startedAt = b.startedAt,
            coords = toTable(coords),
            nearbyPlayers = coords and playersNear(coords, radius) or 0,
        }
    end

    local stations = {}
    for id, station in pairs(DjStations) do
        local broadcastId = ('dj:%s'):format(id)
        local active = ActiveBroadcasts[broadcastId]
        stations[#stations + 1] = {
            id = id,
            label = station.label,
            ownerIdentifier = station.owner_identifier,
            ownerName = cachedName(station.owner_identifier),
            coords = { x = station.pos_x, y = station.pos_y, z = station.pos_z },
            createdAt = station.created_at,
            broadcastId = broadcastId,
            playing = active and active.playing or false,
            song = active and active.song or nil,
            setup = SummarizeDjSetup(station),
        }
    end

    local players, online = {}, {}
    for _, playerId in ipairs(GetPlayers()) do
        local id = tonumber(playerId)
        local identifier = identifierOf(id)
        if identifier then
            online[identifier] = true
            players[#players + 1] = { id = id, name = playerName(id), identifier = identifier }
        end
    end

    local bans = {}
    for identifier in pairs(Bans) do
        local ban = expireIfNeeded(identifier)
        if ban then
            bans[#bans + 1] = {
                identifier = ban.identifier,
                name = ban.name,
                scope = ban.scope,
                reason = ban.reason,
                bannedBy = ban.banned_by,
                expiresAt = ban.expires_at,
                createdAt = ban.created_at,
                online = online[ban.identifier] == true,
            }
        end
    end

    local activity = {}
    for i = #Activity, 1, -1 do activity[#activity + 1] = Activity[i] end

    return {
        now = os.time(),
        nearbyRadius = radius,
        broadcasts = broadcasts,
        stations = stations,
        bans = bans,
        players = players,
        activity = activity,
    }
end)

lib.callback.register('kariee_radio:admin:stop', function(source, id)
    if not IsRadioAdmin(source) then return false end
    local b = ActiveBroadcasts[id]
    if not b then return false end

    stopByAdmin(source, id, b)
    SyncBroadcasts()
    LogRadioActivity(source, 'admin_stop', ('Stopped “%s” on %s'):format(b.song and b.song.title or 'a song', BroadcastLabel(b)), {
        kind = b.kind,
        target = b.owner and GetPlayerName(b.owner) or nil,
        targetIdentifier = identifierOf(b.owner),
    })
    return true
end)

lib.callback.register('kariee_radio:admin:stopNear', function(source, radius)
    if not IsRadioAdmin(source) then return 0 end
    radius = math.min(500.0, math.max(5.0, tonumber(radius) or 50.0))
    local ped = GetPlayerPed(source)
    if ped == 0 then return 0 end

    local origin = GetEntityCoords(ped)
    local stopped = 0
    for id, b in pairs(ActiveBroadcasts) do
        local coords = broadcastCoords(b)
        if coords and #(coords - origin) <= radius then
            stopByAdmin(source, id, b)
            stopped = stopped + 1
        end
    end
    if stopped > 0 then SyncBroadcasts() end
    LogRadioActivity(source, 'admin_stop_near', ('Stopped %d radio(s) within %dm'):format(stopped, math.floor(radius)))
    return stopped
end)

lib.callback.register('kariee_radio:admin:stopAll', function(source)
    if not IsRadioAdmin(source) then return 0 end
    local stopped = 0
    for id, b in pairs(ActiveBroadcasts) do
        stopByAdmin(source, id, b)
        stopped = stopped + 1
    end
    if stopped > 0 then SyncBroadcasts() end
    LogRadioActivity(source, 'admin_stop_all', ('Stopped all music (%d radio(s))'):format(stopped))
    return stopped
end)

lib.callback.register('kariee_radio:admin:renameStation', function(source, stationId, label)
    if not IsRadioAdmin(source) then return false end
    local station = DjStations[stationId]
    label = Trim(label):sub(1, 64)
    if not station or label == '' then return false end

    local previous = station.label
    station.label = label
    MySQL.update.await('UPDATE radio_dj_stations SET label = ? WHERE id = ?', { label, stationId })
    TriggerClientEvent('kariee_radio:dj:updated', -1, stationId, { label = label })
    SyncBroadcasts()
    LogRadioActivity(source, 'booth_renamed', ('Renamed booth #%d “%s” → “%s”'):format(stationId, previous or '', label))
    return true
end)

lib.callback.register('kariee_radio:admin:removeStation', function(source, stationId)
    if not IsRadioAdmin(source) then return false end
    return RemoveDjStation(stationId, source)
end)

lib.callback.register('kariee_radio:admin:ban', function(source, payload)
    if not IsRadioAdmin(source) or type(payload) ~= 'table' then return false, 'invalid' end

    local targetId = tonumber(payload.targetId)
    local identifier = targetId and identifierOf(targetId) or (payload.identifier and tostring(payload.identifier))
    if not identifier or identifier == '' then return false, 'no_player' end
    if targetId == source then return false, 'self' end

    local now = os.time()
    local scope = payload.scope == 'all' and 'all' or 'dj'
    local minutes = tonumber(payload.minutes)
    local expires = minutes and minutes > 0 and now + math.floor(minutes * 60) or nil
    local name = targetId and GetPlayerName(targetId) or tostring(payload.name or cachedName(identifier))
    local reason = tostring(payload.reason or ''):sub(1, 255)
    local bannedBy = GetPlayerName(source) or 'Admin'

    MySQL.query.await([[
        INSERT INTO radio_bans (identifier, name, scope, reason, banned_by, expires_at, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE name = VALUES(name), scope = VALUES(scope), reason = VALUES(reason),
          banned_by = VALUES(banned_by), expires_at = VALUES(expires_at), created_at = VALUES(created_at)
    ]], { identifier, name, scope, reason, bannedBy, expires, now })

    Bans[identifier] = {
        identifier = identifier,
        name = name,
        scope = scope,
        reason = reason,
        banned_by = bannedBy,
        expires_at = expires,
        created_at = now,
    }

    local target = playerOf(identifier)
    local stopped = 0
    if target and payload.stopNow ~= false then
        for id, b in pairs(ActiveBroadcasts) do
            if b.owner == target and (scope == 'all' or b.kind == 'dj') then
                StopBroadcast(id)
                stopped = stopped + 1
            end
        end
        if stopped > 0 then SyncBroadcasts() end
    end
    if target then TriggerClientEvent('kariee_radio:banned', target, SerializeRadioBan(Bans[identifier])) end

    LogRadioActivity(source, 'ban', ('Banned %s from %s (%s)%s'):format(
        name, scope == 'all' and 'all radios' or 'DJ booths', formatDuration(expires and minutes), reason ~= '' and (': ' .. reason) or ''
    ), { target = name, targetIdentifier = identifier })
    return true, stopped
end)

lib.callback.register('kariee_radio:admin:unban', function(source, identifier)
    local ban = identifier and Bans[identifier]
    if not IsRadioAdmin(source) or not ban then return false end

    Bans[identifier] = nil
    MySQL.update.await('DELETE FROM radio_bans WHERE identifier = ?', { identifier })

    local target = playerOf(identifier)
    if target then
        TriggerClientEvent('kariee_radio:banned', target, nil)
        notify(target, 'unbanned')
    end

    LogRadioActivity(source, 'unban', ('Unbanned %s'):format(ban.name ~= '' and ban.name or identifier), {
        target = ban.name,
        targetIdentifier = identifier,
    })
    return true
end)
