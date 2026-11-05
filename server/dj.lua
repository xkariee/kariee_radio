DjStations = {}

local MAX_ACCESS_RULES = 30
local LIGHT_TYPES = { spot = true, laser = true, ball = true, strobe = true }
local COLOR_NAMES = {}
local FIXTURE_MODELS = {}

for _, color in ipairs(Config.DiscoLights.colors) do COLOR_NAMES[color.name] = true end
for _, name in ipairs(Config.DiscoLights.fixtures or {}) do FIXTURE_MODELS[name] = true end

local function loadStations()
    DjStations = {}
    for _, row in ipairs(MySQL.query.await('SELECT * FROM radio_dj_stations') or {}) do
        row.settings = DecodeJson(row.settings)
        DjStations[row.id] = row
    end
end

local function hasDjPermission(source)
    return not Config.DjPermission or IsPlayerAceAllowed(source, Config.DjPermission)
end

local function num(value, min, max, default)
    value = tonumber(value)
    if not value or value ~= value then return default end
    return math.min(max, math.max(min, value))
end

local function near2d(x, y, pos, limit)
    return x and y and math.abs(x - pos.x) <= limit and math.abs(y - pos.y) <= limit
end

local function toPosition(pos)
    if type(pos) ~= 'table' then return nil end
    local x, y, z = tonumber(pos.x), tonumber(pos.y), tonumber(pos.z)
    if not (x and y and z) then return nil end
    return { x = x + 0.0, y = y + 0.0, z = z + 0.0 }
end

local function sanitizeAccess(rules)
    if type(rules) ~= 'table' then return nil end
    local known = {}
    for _, job in ipairs(FRAMEWORK.GetJobs()) do known[job.name] = true end
    local checkNames = next(known) ~= nil

    local out, seen = {}, {}
    for _, rule in ipairs(rules) do
        if #out >= MAX_ACCESS_RULES then break end
        local name = type(rule) == 'table' and type(rule.job) == 'string' and rule.job or nil
        local valid = name and (checkNames and known[name] or (not checkNames and name:match('^[%w_%-]+$')))
        if valid and not seen[name] then
            seen[name] = true
            out[#out + 1] = { job = name, grade = math.floor(num(rule.grade, 0, 1000, 0)) }
        end
    end
    return #out > 0 and out or nil
end

local function sanitizeZone(zone, pos)
    zone = type(zone) == 'table' and zone or {}
    local x, y = tonumber(zone.x), tonumber(zone.y)
    if not near2d(x, y, pos, 15.0) then x, y = pos.x, pos.y end
    return {
        x = x + 0.0,
        y = y + 0.0,
        z = num(zone.z, pos.z - 15.0, pos.z + 15.0, pos.z),
        sx = num(zone.sx, 0.3, 12.0, 1.5),
        sy = num(zone.sy, 0.3, 12.0, 1.5),
        sz = num(zone.sz, 0.3, 8.0, 1.5),
        rot = num(zone.rot, -360.0, 360.0, 0.0),
    }
end

local function sanitizeAudio(audio, pos)
    audio = type(audio) == 'table' and audio or {}
    local limits = Config.DjSound
    local out = {
        type = (audio.type == 'interior' or audio.type == 'area') and audio.type or 'radius',
        range = num(audio.range, limits.minRadius, limits.maxRadius, Config.DjOutdoorRange),
        muffled = num(audio.muffled, 0.0, limits.maxMuffled, limits.defaultMuffled),
        fade = num(audio.fade, 0.0, 100.0, limits.defaultAreaFade),
    }
    if out.type ~= 'area' then return out end

    local points = {}
    for i, point in ipairs(type(audio.points) == 'table' and audio.points or {}) do
        if i > limits.maxAreaPoints then break end
        if type(point) == 'table' and near2d(tonumber(point.x), tonumber(point.y), pos, limits.maxRadius) then
            points[#points + 1] = { x = tonumber(point.x) + 0.0, y = tonumber(point.y) + 0.0 }
        end
    end
    if #points < 3 then
        out.type = 'radius'
        return out
    end

    out.points = points
    out.minZ = num(audio.minZ, pos.z - 30.0, pos.z + 30.0, pos.z - 2.0)
    out.maxZ = num(audio.maxZ, out.minZ + 1.0, pos.z + 60.0, pos.z + limits.defaultAreaHeight)
    return out
end

local function sanitizeProp(prop, pos)
    prop = type(prop) == 'table' and prop or {}
    if not FIXTURE_MODELS[prop.model] or not near2d(tonumber(prop.x), tonumber(prop.y), pos, 60.0) then return nil end
    return {
        model = prop.model,
        x = tonumber(prop.x) + 0.0,
        y = tonumber(prop.y) + 0.0,
        z = num(prop.z, pos.z - 20.0, pos.z + 40.0, pos.z),
        h = num(prop.h, -360.0, 360.0, 0.0),
        flip = prop.flip == true,
    }
end

local function sanitizeLights(lights, pos)
    local out = {}
    for i, light in ipairs(type(lights) == 'table' and lights or {}) do
        if i > Config.DiscoLights.maxPerBooth then break end
        if type(light) == 'table' and LIGHT_TYPES[light.type] and near2d(tonumber(light.x), tonumber(light.y), pos, 60.0) then
            local fixture = (light.fixture == 'none' or light.fixture == 'prop') and light.fixture or 'glow'
            local prop = fixture == 'prop' and sanitizeProp(light.prop, pos) or nil
            if fixture == 'prop' and not prop then fixture = 'glow' end
            out[#out + 1] = {
                type = light.type,
                x = tonumber(light.x) + 0.0,
                y = tonumber(light.y) + 0.0,
                z = num(light.z, pos.z - 20.0, pos.z + 40.0, pos.z + 3.0),
                color = COLOR_NAMES[light.color] and light.color or 'Rainbow',
                speed = num(light.speed, 0.25, 3.0, 1.0),
                fixture = fixture,
                prop = prop,
            }
        end
    end
    return out
end

local function sanitizeSettings(settings, pos)
    settings = type(settings) == 'table' and settings or {}
    local mode = (settings.mode == 'entity' or settings.mode == 'zone') and settings.mode or 'prop'
    return {
        mode = mode,
        model = mode == 'prop' and (tonumber(settings.model) or Config.DjMixerModel) or nil,
        zone = mode ~= 'prop' and sanitizeZone(settings.zone, pos) or nil,
        audio = sanitizeAudio(settings.audio, pos),
        lights = sanitizeLights(settings.lights, pos),
        access = sanitizeAccess(settings.access),
    }
end

local function canManage(source, station)
    local identifier = GetIdentifier(source)
    if not identifier then return false end
    return station.owner_identifier == identifier or hasDjPermission(source) or IsRadioAdmin(source)
end

function SummarizeDjSetup(station)
    local settings = station.settings or {}
    local audio = settings.audio or {}
    local access
    if settings.access then
        access = {}
        for i, rule in ipairs(settings.access) do
            access[i] = rule.grade > 0 and ('%s (grade %d+)'):format(rule.job, rule.grade) or rule.job
        end
    end
    return {
        mode = settings.mode or 'prop',
        audio = audio.type or 'auto',
        range = audio.range,
        muffled = audio.muffled,
        areaPoints = audio.points and #audio.points or 0,
        lights = settings.lights and #settings.lights or 0,
        access = access,
    }
end

function CanUseDjStation(source, station)
    if not station then return false end
    local access = station.settings and station.settings.access
    if not access or #access == 0 then return true end
    if IsRadioAdmin(source) then return true end

    local player = FRAMEWORK.GetPlayerFromId(source)
    if not player then return false end
    for _, rule in ipairs(access) do
        if player.hasJob(rule.job, rule.grade) then return true end
    end
    return false
end

function RemoveDjStation(stationId, source)
    local station = DjStations[stationId]
    if not station then return false end

    MySQL.update.await('DELETE FROM radio_dj_stations WHERE id = ?', { stationId })
    DjStations[stationId] = nil
    if StopBroadcast(('dj:%s'):format(stationId)) then SyncBroadcasts() end

    TriggerClientEvent('kariee_radio:dj:removed', -1, stationId)
    LogRadioActivity(source, 'booth_removed', ('Removed booth #%d “%s”'):format(stationId, station.label or 'DJ booth'))
    return true
end

OnDatabaseReady(loadStations)

lib.callback.register('kariee_radio:dj:getAll', function()
    return DjStations
end)

lib.callback.register('kariee_radio:dj:getJobs', function()
    return FRAMEWORK.GetJobs()
end)

lib.callback.register('kariee_radio:dj:canManage', function(source, stationId)
    local station = DjStations[stationId]
    return station ~= nil and canManage(source, station)
end)

lib.callback.register('kariee_radio:dj:create', function(source, pos, heading, label, settings)
    if not hasDjPermission(source) and not IsRadioAdmin(source) then return nil, 'no_permission' end

    local ban = GetRadioBan(source, 'dj')
    if ban then
        NotifyRadioBan(source, ban)
        return nil, 'banned'
    end

    local identifier = GetIdentifier(source)
    pos = toPosition(pos)
    if not identifier or not pos then return nil end

    local station = {
        owner_identifier = identifier,
        label = tostring(label or 'DJ Station'):sub(1, 64),
        pos_x = pos.x,
        pos_y = pos.y,
        pos_z = pos.z,
        heading = tonumber(heading) or 0.0,
        settings = sanitizeSettings(settings, pos),
        created_at = os.time() * 1000,
    }
    station.id = MySQL.insert.await(
        'INSERT INTO radio_dj_stations (owner_identifier, label, pos_x, pos_y, pos_z, heading, settings) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { identifier, station.label, pos.x, pos.y, pos.z, station.heading, json.encode(station.settings) }
    )
    if not station.id then return nil end

    DjStations[station.id] = station
    TriggerClientEvent('kariee_radio:dj:created', -1, station)
    LogRadioActivity(source, 'booth_created', ('Placed booth #%d “%s”'):format(station.id, station.label))
    return station
end)

lib.callback.register('kariee_radio:dj:update', function(source, stationId, pos, heading, settings)
    local station = DjStations[stationId]
    if not station then return false, 'missing' end
    if not canManage(source, station) then return false, 'no_permission' end

    pos = toPosition(pos)
    if pos then
        station.pos_x, station.pos_y, station.pos_z = pos.x, pos.y, pos.z
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

    local lights = #station.settings.lights
    LogRadioActivity(source, 'booth_edited', ('Edited booth #%d “%s” (%d light%s)'):format(stationId, station.label or 'DJ booth', lights, lights == 1 and '' or 's'))
    return true
end)

lib.callback.register('kariee_radio:dj:remove', function(source, stationId)
    local station = DjStations[stationId]
    if not station or not canManage(source, station) then return false end
    return RemoveDjStation(stationId, source)
end)
