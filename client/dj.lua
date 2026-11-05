DjStations = {}
DjEditingStationId = nil

local spawned = {}

function OpenDjStation(stationId)
    OpenRadio({ kind = 'dj', id = ('dj:%s'):format(stationId), stationId = stationId })
end

local function useStation(stationId)
    if not DjStations[stationId] then return Utils:Notify('no_station_nearby') end
    OpenDjStation(stationId)
end

local function targetOptions(station)
    return {
        {
            name = ('kariee_radio_dj_%s'):format(station.id),
            icon = 'fa-solid fa-music',
            label = 'Play Radio',
            distance = Config.Placement.targetDistance,
            onSelect = function() useStation(station.id) end,
        },
    }
end

local function teardownStation(stationId)
    local entry = spawned[stationId]
    if not entry then return end
    if entry.obj and DoesEntityExist(entry.obj) then
        exports.ox_target:removeLocalEntity(entry.obj)
        DeleteObject(entry.obj)
    end
    if entry.zone then exports.ox_target:removeZone(entry.zone) end
    spawned[stationId] = nil
end

local function setupStation(station)
    teardownStation(station.id)
    station.coords = vector3(station.pos_x, station.pos_y, station.pos_z)
    station.interiorId = GetInteriorAtCoords(station.coords.x, station.coords.y, station.coords.z)

    local settings = station.settings or {}
    local zone = settings.zone
    if zone and (settings.mode == 'zone' or settings.mode == 'entity') then
        spawned[station.id] = {
            zone = exports.ox_target:addBoxZone({
                coords = vec3(zone.x, zone.y, zone.z),
                size = vec3(zone.sx, zone.sy, zone.sz),
                rotation = zone.rot,
                debug = false,
                options = targetOptions(station),
            }),
        }
        return
    end

    local model = settings.model or Config.DjMixerModel
    if not IsModelInCdimage(model) then model = Config.DjMixerModel end
    local obj = Utils:SpawnProp(model, station.coords)
    if not obj then return end
    SetEntityHeading(obj, station.heading or 0.0)
    spawned[station.id] = { obj = obj }
    exports.ox_target:addLocalEntity(obj, targetOptions(station))
end

function DjAudioOf(station)
    local audio = station.settings and station.settings.audio
    if audio then return audio end
    return {
        type = station.interiorId ~= 0 and 'interior' or 'radius',
        range = Config.DjOutdoorRange,
        muffled = Config.MaxRange,
        fade = Config.DjSound.defaultAreaFade,
    }
end

local function pointInPolygon(x, y, points)
    local inside = false
    local j = #points
    for i = 1, #points do
        local a, b = points[i], points[j]
        if ((a.y > y) ~= (b.y > y)) and (x < (b.x - a.x) * (y - a.y) / (b.y - a.y) + a.x) then
            inside = not inside
        end
        j = i
    end
    return inside
end

local function segmentDistance(px, py, ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    local length = dx * dx + dy * dy
    local t = length > 0 and math.max(0, math.min(1, ((px - ax) * dx + (py - ay) * dy) / length)) or 0
    local cx, cy = ax + t * dx - px, ay + t * dy - py
    return math.sqrt(cx * cx + cy * cy)
end

function DjAreaDistance(audio, coords)
    local points = audio.points
    if not points or #points < 3 then return false, math.huge end

    local inside = pointInPolygon(coords.x, coords.y, points)
    local dz = 0.0
    if coords.z < audio.minZ then
        dz = audio.minZ - coords.z
    elseif coords.z > audio.maxZ then
        dz = coords.z - audio.maxZ
    end
    if inside and dz == 0.0 then return true, 0.0 end

    local edge = 0.0
    if not inside then
        edge = math.huge
        for i = 1, #points do
            local a, b = points[i], points[i % #points + 1]
            edge = math.min(edge, segmentDistance(coords.x, coords.y, a.x, a.y, b.x, b.y))
        end
    end
    return false, math.sqrt(edge * edge + dz * dz)
end

local function nearestStation()
    local coords = Utils:GetCoords()
    local nearestId, nearestDist = nil, Config.Placement.interactRange
    for id, station in pairs(DjStations) do
        local dist = #(coords - station.coords)
        if dist <= nearestDist then nearestId, nearestDist = id, dist end
    end
    if not nearestId then Utils:Notify('no_station_nearby') end
    return nearestId
end

RegisterNetEvent('kariee_radio:dj:created', function(station)
    DjStations[station.id] = station
    setupStation(station)
end)

RegisterNetEvent('kariee_radio:dj:removed', function(stationId)
    DjStations[stationId] = nil
    teardownStation(stationId)
end)

RegisterNetEvent('kariee_radio:dj:updated', function(stationId, changes)
    local station = DjStations[stationId]
    if not station or type(changes) ~= 'table' then return end
    for key, value in pairs(changes) do station[key] = value end
    if changes.settings or changes.pos_x then setupStation(station) end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for id in pairs(spawned) do teardownStation(id) end
end)

CreateThread(function()
    while not NetworkIsPlayerActive(Utils.playerId) do Wait(250) end
    for id, station in pairs(Utils:Callback('dj:getAll') or {}) do
        DjStations[id] = station
        setupStation(station)
    end
end)

RegisterCommand('createdj', function()
    StartDjCreator()
end, false)

RegisterCommand('editdj', function()
    local id = nearestStation()
    if not id then return end
    if not Utils:Callback('dj:canManage', id) then return Utils:Notify('no_permission') end
    StartDjCreator(DjStations[id])
end, false)

RegisterCommand('dj', function()
    local id = nearestStation()
    if id then OpenDjStation(id) end
end, false)

RegisterCommand('removedj', function()
    local id = nearestStation()
    if not id then return end
    local ok = Utils:Callback('dj:remove', id)
    if ok then
        DjStations[id] = nil
        teardownStation(id)
    end
    Utils:Notify(ok and 'station_removed' or 'no_permission')
end, false)
