---@type table<number, table>
DjStations = {}

local function loadStations()
    local rows = MySQL.query.await('SELECT * FROM radio_dj_stations') or {}
    DjStations = {}
    for _, row in ipairs(rows) do
        DjStations[row.id] = row
    end
end

CreateThread(function()
    MySQL.ready(loadStations)
end)

local function hasDjPermission(source)
    -- if not Config.DjPermission then return true end
    -- return IsPlayerAceAllowed(source, Config.DjPermission)
    return true
end

lib.callback.register('kariee_radio:dj:getAll', function(_source)
    return DjStations
end)

lib.callback.register('kariee_radio:dj:create', function(source, pos, heading, label)
    if not hasDjPermission(source) and not IsRadioAdmin(source) then return nil, 'no_permission' end
    local ban = GetRadioBan(source, 'dj')
    if ban then
        NotifyRadioBan(source, ban)
        return nil, 'banned'
    end
    local identifier = GetIdentifier(source)
    if not identifier or type(pos) ~= 'table' then return nil end

    local id = MySQL.insert.await(
        'INSERT INTO radio_dj_stations (owner_identifier, label, pos_x, pos_y, pos_z, heading) VALUES (?, ?, ?, ?, ?, ?)',
        { identifier, tostring(label or 'DJ Station'):sub(1, 64), pos.x, pos.y, pos.z, tonumber(heading) or 0.0 }
    )

    local station = {
        id = id,
        owner_identifier = identifier,
        label = label or 'DJ Station',
        pos_x = pos.x,
        pos_y = pos.y,
        pos_z = pos.z,
        heading = tonumber(heading) or 0.0,
        created_at = os.time() * 1000, -- same ms-epoch shape oxmysql returns for TIMESTAMP columns
    }
    DjStations[id] = station

    TriggerClientEvent('kariee_radio:dj:created', -1, station)
    LogRadioActivity(source, 'booth_created', ('Placed booth #%d “%s”'):format(id, station.label))
    return station
end)

---Deletes a station everywhere (DB, every client's prop, its broadcast). Shared by /removedj and
---the admin panel.
---@param stationId number
---@param source number|nil who removed it, for the activity log
---@return boolean
function RemoveDjStation(stationId, source)
    local station = DjStations[stationId]
    if not station then return false end

    MySQL.update.await('DELETE FROM radio_dj_stations WHERE id = ?', { stationId })
    DjStations[stationId] = nil

    local activeId = ('dj:%s'):format(stationId)
    if ActiveBroadcasts[activeId] then
        ActiveBroadcasts[activeId] = nil
        SyncBroadcasts()
    end

    TriggerClientEvent('kariee_radio:dj:removed', -1, stationId)
    LogRadioActivity(source, 'booth_removed', ('Removed booth #%d “%s”'):format(stationId, station.label or 'DJ booth'))
    return true
end

lib.callback.register('kariee_radio:dj:remove', function(source, stationId)
    local identifier = GetIdentifier(source)
    local station = DjStations[stationId]
    if not identifier or not station then return false end
    if station.owner_identifier ~= identifier and not hasDjPermission(source) and not IsRadioAdmin(source) then
        return false
    end
    return RemoveDjStation(stationId, source)
end)
