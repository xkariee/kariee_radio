---@type table<number, table>
DjStations = {}

-- ─── Schema / loading ──────────────────────────────────────────────────────

-- Booths made with the creator store their setup (console mode, sound area, lights) as JSON.
-- Added on start so existing installs don't need to re-run the SQL file.
local function ensureSchema()
    local cols = MySQL.query.await("SHOW COLUMNS FROM radio_dj_stations LIKE 'settings'")
    if not cols or #cols == 0 then
        MySQL.query.await('ALTER TABLE radio_dj_stations ADD COLUMN settings LONGTEXT NULL')
    end
end

local function loadStations()
    ensureSchema()
    local rows = MySQL.query.await('SELECT * FROM radio_dj_stations') or {}
    DjStations = {}
    for _, row in ipairs(rows) do
        if type(row.settings) == 'string' and row.settings ~= '' then
            local ok, decoded = pcall(json.decode, row.settings)
            row.settings = ok and decoded or nil
        else
            row.settings = nil
        end
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

-- ─── Settings validation ───────────────────────────────────────────────────
-- Everything the creator sends is clamped/whitelisted here - a modified client can't create a
-- 10km sound area, hundreds of lights or junk types.

local function num(v, min, max, default)
    v = tonumber(v)
    if not v or v ~= v then return default end
    return math.min(max, math.max(min, v))
end

local function near2d(x, y, pos, limit)
    return x and y and math.abs(x - pos.x) <= limit and math.abs(y - pos.y) <= limit
end

local LIGHT_TYPES = { spot = true, laser = true, ball = true, strobe = true }
local COLOR_NAMES = {}
for _, c in ipairs(Config.DiscoLights.colors) do COLOR_NAMES[c.name] = true end

---@param s table|nil raw settings from the client
---@param pos table station position { x, y, z }
---@return table
local function sanitizeSettings(s, pos)
    s = type(s) == 'table' and s or {}
    local out = {}

    out.mode = (s.mode == 'entity' or s.mode == 'zone') and s.mode or 'prop'
    if out.mode == 'prop' then
        out.model = tonumber(s.model) or Config.DjMixerModel
    else
        local z = type(s.zone) == 'table' and s.zone or {}
        local zx, zy = tonumber(z.x), tonumber(z.y)
        -- A box that isn't at the console snaps back onto it (keeping its size/rotation).
        if not near2d(zx, zy, pos, 15.0) then zx, zy = pos.x, pos.y end
        out.zone = {
            x = zx + 0.0,
            y = zy + 0.0,
            z = num(z.z, pos.z - 15.0, pos.z + 15.0, pos.z),
            sx = num(z.sx, 0.3, 12.0, 1.5),
            sy = num(z.sy, 0.3, 12.0, 1.5),
            sz = num(z.sz, 0.3, 8.0, 1.5),
            rot = num(z.rot, -360.0, 360.0, 0.0),
        }
    end

    local snd = Config.DjSound
    local a = type(s.audio) == 'table' and s.audio or {}
    local audio = {
        type = (a.type == 'interior' or a.type == 'area') and a.type or 'radius',
        range = num(a.range, snd.minRadius, snd.maxRadius, Config.DjOutdoorRange),
        muffled = num(a.muffled, 0.0, snd.maxMuffled, snd.defaultMuffled),
        fade = num(a.fade, 0.0, 100.0, snd.defaultAreaFade),
    }
    if audio.type == 'area' then
        local points = {}
        for i, p in ipairs(type(a.points) == 'table' and a.points or {}) do
            if i > snd.maxAreaPoints then break end
            if type(p) == 'table' and near2d(tonumber(p.x), tonumber(p.y), pos, snd.maxRadius) then
                points[#points + 1] = { x = tonumber(p.x) + 0.0, y = tonumber(p.y) + 0.0 }
            end
        end
        if #points < 3 then
            audio.type = 'radius'
        else
            audio.points = points
            audio.minZ = num(a.minZ, pos.z - 30.0, pos.z + 30.0, pos.z - 2.0)
            audio.maxZ = num(a.maxZ, audio.minZ + 1.0, pos.z + 60.0, pos.z + snd.defaultAreaHeight)
        end
    end
    out.audio = audio

    local lights = {}
    for i, l in ipairs(type(s.lights) == 'table' and s.lights or {}) do
        if i > Config.DiscoLights.maxPerBooth then break end
        if type(l) == 'table' and LIGHT_TYPES[l.type] and near2d(tonumber(l.x), tonumber(l.y), pos, 60.0) then
            lights[#lights + 1] = {
                type = l.type,
                x = tonumber(l.x) + 0.0,
                y = tonumber(l.y) + 0.0,
                z = num(l.z, pos.z - 20.0, pos.z + 40.0, pos.z + 3.0),
                color = COLOR_NAMES[l.color] and l.color or 'Rainbow',
                speed = num(l.speed, 0.25, 3.0, 1.0),
            }
        end
    end
    out.lights = lights

    return out
end

---Short description of a booth's setup, for the admin panel.
function SummarizeDjSetup(station)
    local s = station.settings or {}
    local audio = s.audio or {}
    return {
        mode = s.mode or 'prop',
        audio = audio.type or 'auto',
        range = audio.range,
        muffled = audio.muffled,
        areaPoints = audio.points and #audio.points or 0,
        lights = s.lights and #s.lights or 0,
    }
end

local function canManage(source, station)
    local identifier = GetIdentifier(source)
    return identifier and (station.owner_identifier == identifier or hasDjPermission(source) or IsRadioAdmin(source))
end

-- ─── Callbacks ─────────────────────────────────────────────────────────────

lib.callback.register('kariee_radio:dj:getAll', function(_source)
    return DjStations
end)

lib.callback.register('kariee_radio:dj:create', function(source, pos, heading, label, settings)
    if not hasDjPermission(source) and not IsRadioAdmin(source) then return nil, 'no_permission' end
    local ban = GetRadioBan(source, 'dj')
    if ban then
        NotifyRadioBan(source, ban)
        return nil, 'banned'
    end
    local identifier = GetIdentifier(source)
    if not identifier or type(pos) ~= 'table' then return nil end
    pos = { x = tonumber(pos.x) + 0.0, y = tonumber(pos.y) + 0.0, z = tonumber(pos.z) + 0.0 }

    local clean = sanitizeSettings(settings, pos)
    local id = MySQL.insert.await(
        'INSERT INTO radio_dj_stations (owner_identifier, label, pos_x, pos_y, pos_z, heading, settings) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { identifier, tostring(label or 'DJ Station'):sub(1, 64), pos.x, pos.y, pos.z, tonumber(heading) or 0.0, json.encode(clean) }
    )

    local station = {
        id = id,
        owner_identifier = identifier,
        label = tostring(label or 'DJ Station'):sub(1, 64),
        pos_x = pos.x,
        pos_y = pos.y,
        pos_z = pos.z,
        heading = tonumber(heading) or 0.0,
        settings = clean,
        created_at = os.time() * 1000, -- same ms-epoch shape oxmysql returns for TIMESTAMP columns
    }
    DjStations[id] = station

    TriggerClientEvent('kariee_radio:dj:created', -1, station)
    LogRadioActivity(source, 'booth_created', ('Placed booth #%d “%s”'):format(id, station.label))
    return station
end)

---Re-runs the creator on an existing booth (move it, change its sound area, lights...).
lib.callback.register('kariee_radio:dj:update', function(source, stationId, pos, heading, settings)
    local station = DjStations[stationId]
    if not station then return false, 'missing' end
    if not canManage(source, station) then return false, 'no_permission' end

    if type(pos) == 'table' and tonumber(pos.x) and tonumber(pos.y) and tonumber(pos.z) then
        station.pos_x, station.pos_y, station.pos_z = tonumber(pos.x) + 0.0, tonumber(pos.y) + 0.0, tonumber(pos.z) + 0.0
        station.heading = tonumber(heading) or station.heading
    end
    station.settings = sanitizeSettings(settings, { x = station.pos_x, y = station.pos_y, z = station.pos_z })

    MySQL.update.await(
        'UPDATE radio_dj_stations SET pos_x = ?, pos_y = ?, pos_z = ?, heading = ?, settings = ? WHERE id = ?',
        { station.pos_x, station.pos_y, station.pos_z, station.heading, json.encode(station.settings), stationId }
    )

    TriggerClientEvent('kariee_radio:dj:updated', -1, stationId, {
        pos_x = station.pos_x,
        pos_y = station.pos_y,
        pos_z = station.pos_z,
        heading = station.heading,
        settings = station.settings,
    })
    LogRadioActivity(source, 'booth_edited', ('Edited booth #%d “%s” (%d light%s)'):format(
        stationId, station.label or 'DJ booth', #station.settings.lights, #station.settings.lights == 1 and '' or 's'
    ))
    return true
end)

lib.callback.register('kariee_radio:dj:canManage', function(source, stationId)
    local station = DjStations[stationId]
    return station ~= nil and canManage(source, station) == true
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
    local station = DjStations[stationId]
    if not station or not canManage(source, station) then return false end
    return RemoveDjStation(stationId, source)
end)
