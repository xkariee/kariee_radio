-- Admin panel backend (/radioadmin): live view of every broadcast and DJ booth, radio bans and an
-- activity log. Every callback re-checks IsRadioAdmin server-side - the NUI is never trusted.

---@type table<string, table> identifier -> { identifier, name, scope, reason, banned_by, expires_at }
local Bans = {}
---@type table[] newest last, capped at Config.ActivityLogSize
local Activity = {}
---@type table<string, string> identifier -> display name (offline lookups hit the DB, so cache)
local nameCache = {}

-- ─── Permissions ───────────────────────────────────────────────────────────

---ACE permission or one of Config.AdminGroups (ESX group), whichever the server uses.
---@param source number
---@return boolean
function IsRadioAdmin(source)
    if not source or source <= 0 then return false end
    if Config.AdminAce and IsPlayerAceAllowed(source, Config.AdminAce) then return true end
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer and xPlayer.getGroup and Config.AdminGroups then
        local group = xPlayer.getGroup()
        for _, allowed in ipairs(Config.AdminGroups) do
            if allowed == group then return true end
        end
    end
    return false
end

local function identifierOf(source)
    local xPlayer = source and ESX.GetPlayerFromId(source)
    return xPlayer and xPlayer.identifier or nil
end

local function cachedName(identifier)
    if not identifier then return 'Unknown' end
    if not nameCache[identifier] then nameCache[identifier] = GetDisplayName(identifier) end
    return nameCache[identifier]
end

local function notify(source, message)
    if source then TriggerClientEvent('kariee_radio:notify', source, message) end
end

-- ─── Activity log ──────────────────────────────────────────────────────────

---@param source number|nil acting player (nil = console/system)
---@param action string play | admin_stop | admin_stop_all | admin_stop_near | booth_created | booth_removed | booth_renamed | ban | unban
---@param detail string human-readable summary shown in the panel
---@param extra table|nil any extra fields (kind, label, target, targetIdentifier...)
function LogRadioActivity(source, action, detail, extra)
    local entry = {
        t = os.time(),
        action = action,
        detail = detail,
        actorId = source,
        actor = source and (GetPlayerName(source) or ('Player ' .. source)) or 'Console',
        identifier = identifierOf(source),
    }
    if extra then
        for k, v in pairs(extra) do entry[k] = v end
    end
    Activity[#Activity + 1] = entry
    local overflow = #Activity - (Config.ActivityLogSize or 150)
    for _ = 1, overflow do table.remove(Activity, 1) end
end

-- ─── Bans ──────────────────────────────────────────────────────────────────

local function loadBans()
    -- Created here too so servers that only ran the original SQL file keep working.
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `radio_bans` (
          `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
          `identifier` VARCHAR(64) NOT NULL,
          `name` VARCHAR(100) NOT NULL DEFAULT '',
          `scope` ENUM('dj', 'all') NOT NULL DEFAULT 'dj',
          `reason` VARCHAR(255) NOT NULL DEFAULT '',
          `banned_by` VARCHAR(100) NOT NULL DEFAULT '',
          `expires_at` INT UNSIGNED NULL DEFAULT NULL,
          `created_at` INT UNSIGNED NOT NULL,
          PRIMARY KEY (`id`),
          UNIQUE KEY `uq_identifier` (`identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    local rows = MySQL.query.await('SELECT * FROM radio_bans') or {}
    Bans = {}
    for _, row in ipairs(rows) do Bans[row.identifier] = row end
end

CreateThread(function()
    MySQL.ready(loadBans)
end)

local function expireIfNeeded(identifier)
    local ban = Bans[identifier]
    if ban and ban.expires_at and ban.expires_at <= os.time() then
        Bans[identifier] = nil
        MySQL.update('DELETE FROM radio_bans WHERE identifier = ?', { identifier })
        return nil
    end
    return ban
end

---Active ban for this player that covers `kind`, or any active ban when `kind` is nil.
---'dj' bans only cover DJ booths; 'all' bans cover personal, car and DJ radios.
---@param source number
---@param kind string|nil 'radio' | 'radiocar' | 'dj'
---@return table|nil
function GetRadioBan(source, kind)
    local identifier = identifierOf(source)
    if not identifier then return nil end
    local ban = expireIfNeeded(identifier)
    if not ban then return nil end
    if ban.scope == 'all' then return ban end
    if ban.scope == 'dj' and (kind == nil or kind == 'dj') then return ban end
    return nil
end

local function publicBan(ban)
    return ban and { scope = ban.scope, reason = ban.reason, expires_at = ban.expires_at } or nil
end

function SerializeRadioBan(ban)
    return publicBan(ban)
end

local lastBanNotice = {}
---Tells a banned player why their action did nothing (throttled - controls can fire rapidly).
function NotifyRadioBan(source, ban)
    if lastBanNotice[source] and os.time() - lastBanNotice[source] < 4 then return end
    lastBanNotice[source] = os.time()
    TriggerClientEvent('kariee_radio:banned', source, publicBan(ban))
end

AddEventHandler('playerDropped', function()
    lastBanNotice[source] = nil
end)

-- ─── Helpers over ActiveBroadcasts ─────────────────────────────────────────

local function broadcastCoords(b)
    if b.kind == 'dj' then
        local s = DjStations[b.stationId]
        if s then return vector3(s.pos_x, s.pos_y, s.pos_z) end
    elseif b.kind == 'radio' then
        local ped = GetPlayerPed(b.owner)
        if ped and ped ~= 0 then return GetEntityCoords(ped) end
    elseif b.kind == 'radiocar' then
        local vehicle = NetworkGetEntityFromNetworkId(b.vehicleNetId)
        if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then return GetEntityCoords(vehicle) end
    end
    return nil
end

local function playersNear(coords, radius)
    local count = 0
    for _, pid in ipairs(GetPlayers()) do
        local ped = GetPlayerPed(pid)
        if ped ~= 0 and #(GetEntityCoords(ped) - coords) <= radius then count = count + 1 end
    end
    return count
end

local function toTable(v)
    return v and { x = v.x, y = v.y, z = v.z } or nil
end

local function stopBroadcast(id)
    if not ActiveBroadcasts[id] then return false end
    ActiveBroadcasts[id] = nil
    return true
end

-- ─── Callbacks ─────────────────────────────────────────────────────────────

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
    for id, s in pairs(DjStations) do
        local active = ActiveBroadcasts[('dj:%s'):format(id)]
        stations[#stations + 1] = {
            id = id,
            label = s.label,
            ownerIdentifier = s.owner_identifier,
            ownerName = cachedName(s.owner_identifier),
            coords = { x = s.pos_x, y = s.pos_y, z = s.pos_z },
            createdAt = s.created_at,
            broadcastId = ('dj:%s'):format(id),
            playing = active and active.playing or false,
            song = active and active.song or nil,
            setup = SummarizeDjSetup(s),
        }
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
                online = false,
            }
        end
    end

    local players = {}
    for _, pid in ipairs(GetPlayers()) do
        local id = tonumber(pid)
        local identifier = identifierOf(id)
        if identifier then
            players[#players + 1] = { id = id, name = GetPlayerName(id) or ('Player ' .. id), identifier = identifier }
            for _, ban in ipairs(bans) do
                if ban.identifier == identifier then ban.online = true end
            end
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
    local title = b.song and b.song.title or 'a song'
    stopBroadcast(id)
    SyncBroadcasts()
    if b.owner and b.owner ~= source then notify(b.owner, Config.Messages.admin_stopped) end
    LogRadioActivity(source, 'admin_stop', ('Stopped “%s” on %s'):format(title, BroadcastLabel(b)), {
        kind = b.kind,
        target = b.owner and GetPlayerName(b.owner) or nil,
        targetIdentifier = identifierOf(b.owner),
    })
    return true
end)

lib.callback.register('kariee_radio:admin:stopNear', function(source, radius)
    if not IsRadioAdmin(source) then return 0 end
    radius = math.min(500.0, math.max(5.0, tonumber(radius) or 50.0))
    local myPed = GetPlayerPed(source)
    if myPed == 0 then return 0 end
    local myCoords = GetEntityCoords(myPed)
    local stopped = 0
    for id, b in pairs(ActiveBroadcasts) do
        local coords = broadcastCoords(b)
        if coords and #(coords - myCoords) <= radius then
            stopBroadcast(id)
            if b.owner and b.owner ~= source then notify(b.owner, Config.Messages.admin_stopped) end
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
        stopBroadcast(id)
        if b.owner and b.owner ~= source then notify(b.owner, Config.Messages.admin_stopped) end
        stopped = stopped + 1
    end
    if stopped > 0 then SyncBroadcasts() end
    LogRadioActivity(source, 'admin_stop_all', ('Stopped all music (%d radio(s))'):format(stopped))
    return stopped
end)

lib.callback.register('kariee_radio:admin:renameStation', function(source, stationId, label)
    if not IsRadioAdmin(source) then return false end
    local station = DjStations[stationId]
    label = tostring(label or ''):gsub('^%s+', ''):gsub('%s+$', ''):sub(1, 64)
    if not station or label == '' then return false end
    local old = station.label
    station.label = label
    MySQL.update.await('UPDATE radio_dj_stations SET label = ? WHERE id = ?', { label, stationId })
    TriggerClientEvent('kariee_radio:dj:updated', -1, stationId, { label = label })
    SyncBroadcasts()
    LogRadioActivity(source, 'booth_renamed', ('Renamed booth #%d “%s” → “%s”'):format(stationId, old or '', label))
    return true
end)

lib.callback.register('kariee_radio:admin:removeStation', function(source, stationId)
    if not IsRadioAdmin(source) then return false end
    return RemoveDjStation(stationId, source)
end)

---@param payload table { targetId?, identifier?, name?, scope, minutes?, reason?, stopNow? }
lib.callback.register('kariee_radio:admin:ban', function(source, payload)
    if not IsRadioAdmin(source) or type(payload) ~= 'table' then return false, 'invalid' end

    local targetId = tonumber(payload.targetId)
    local identifier = targetId and identifierOf(targetId) or (payload.identifier and tostring(payload.identifier))
    if not identifier or identifier == '' then return false, 'no_player' end
    if targetId and targetId == source then return false, 'self' end

    local scope = payload.scope == 'all' and 'all' or 'dj'
    local minutes = tonumber(payload.minutes)
    local expires = (minutes and minutes > 0) and (os.time() + math.floor(minutes * 60)) or nil
    local name = targetId and GetPlayerName(targetId) or tostring(payload.name or cachedName(identifier))
    local reason = tostring(payload.reason or ''):sub(1, 255)
    local by = GetPlayerName(source) or 'Admin'

    MySQL.query.await([[
        INSERT INTO radio_bans (identifier, name, scope, reason, banned_by, expires_at, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE name = VALUES(name), scope = VALUES(scope), reason = VALUES(reason),
          banned_by = VALUES(banned_by), expires_at = VALUES(expires_at), created_at = VALUES(created_at)
    ]], { identifier, name, scope, reason, by, expires, os.time() })

    Bans[identifier] = {
        identifier = identifier,
        name = name,
        scope = scope,
        reason = reason,
        banned_by = by,
        expires_at = expires,
        created_at = os.time(),
    }

    -- Find them online (by identifier, so an offline-entered ban still applies if they're on).
    local online = targetId
    if not online then
        for _, pid in ipairs(GetPlayers()) do
            if identifierOf(tonumber(pid)) == identifier then online = tonumber(pid) break end
        end
    end

    local stopped = 0
    if online and payload.stopNow ~= false then
        for id, b in pairs(ActiveBroadcasts) do
            if b.owner == online and (scope == 'all' or b.kind == 'dj') then
                stopBroadcast(id)
                stopped = stopped + 1
            end
        end
        if stopped > 0 then SyncBroadcasts() end
    end
    if online then TriggerClientEvent('kariee_radio:banned', online, publicBan(Bans[identifier])) end

    local length = 'permanently'
    if expires then
        local m = math.floor(minutes)
        if m < 60 then length = ('%d min'):format(m)
        elseif m < 1440 then length = ('%d h'):format(math.floor(m / 60))
        else
            local days = math.floor(m / 1440)
            length = ('%d day%s'):format(days, days == 1 and '' or 's')
        end
    end
    LogRadioActivity(source, 'ban', ('Banned %s from %s (%s)%s'):format(
        name, scope == 'all' and 'all radios' or 'DJ booths', length, reason ~= '' and (': ' .. reason) or ''
    ), { target = name, targetIdentifier = identifier })
    return true, stopped
end)

lib.callback.register('kariee_radio:admin:unban', function(source, identifier)
    if not IsRadioAdmin(source) or not Bans[identifier] then return false end
    local ban = Bans[identifier]
    Bans[identifier] = nil
    MySQL.update.await('DELETE FROM radio_bans WHERE identifier = ?', { identifier })
    for _, pid in ipairs(GetPlayers()) do
        if identifierOf(tonumber(pid)) == identifier then
            TriggerClientEvent('kariee_radio:banned', tonumber(pid), nil)
            notify(tonumber(pid), Config.Messages.unbanned)
        end
    end
    LogRadioActivity(source, 'unban', ('Unbanned %s'):format(ban.name ~= '' and ban.name or identifier), {
        target = ban.name,
        targetIdentifier = identifier,
    })
    return true
end)
