DjStations = {}
-- stationId -> { obj = entity } (prop booths) or { zone = ox_target zone id } (object/box booths)
local spawned = {}

---Opens the radio NUI bound to this station.
local function tryOpenDjStation(stationId)
    local station = DjStations[stationId]
    if not station then
        ESX.ShowNotification(Config.Messages.no_station_nearby)
        return
    end

    OpenRadio({ kind = 'dj', id = ('dj:%s'):format(stationId), stationId = stationId })
end

local function targetOptions(station)
    return {
        {
            name = 'kariee_radio_dj_' .. station.id,
            icon = 'fa-solid fa-music',
            label = 'Play Radio',
            distance = Config.Placement.targetDistance,
            onSelect = function() tryOpenDjStation(station.id) end,
        },
    }
end

local function teardownStation(stationId)
    local s = spawned[stationId]
    if not s then return end
    if s.obj and DoesEntityExist(s.obj) then
        exports.ox_target:removeLocalEntity(s.obj)
        DeleteObject(s.obj)
    end
    if s.zone then exports.ox_target:removeZone(s.zone) end
    spawned[stationId] = nil
end

---Spawns the console prop (or registers the interaction box) for a booth. Booths made before the
---creator existed have no settings and behave exactly as before: the default prop.
local function setupStation(station)
    teardownStation(station.id)
    station.interiorId = GetInteriorAtCoords(station.pos_x, station.pos_y, station.pos_z)

    local settings = station.settings or {}
    if (settings.mode == 'zone' or settings.mode == 'entity') and settings.zone then
        local z = settings.zone
        spawned[station.id] = {
            zone = exports.ox_target:addBoxZone({
                coords = vec3(z.x, z.y, z.z),
                size = vec3(z.sx, z.sy, z.sz),
                rotation = z.rot,
                debug = false,
                options = targetOptions(station),
            }),
        }
        return
    end

    local model = settings.model or Config.DjMixerModel
    if not IsModelInCdimage(model) then model = Config.DjMixerModel end
    if not LoadModel(model) then return end
    local obj = CreateObject(model, station.pos_x, station.pos_y, station.pos_z, false, false, false)
    SetEntityHeading(obj, station.heading or 0.0)
    FreezeEntityPosition(obj, true)
    SetEntityCollision(obj, true, true)
    SetModelAsNoLongerNeeded(model)
    spawned[station.id] = { obj = obj }
    exports.ox_target:addLocalEntity(obj, targetOptions(station))
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
    for k, v in pairs(changes) do station[k] = v end
    -- A rename only changes the label; a moved console / new setup needs re-spawning.
    if changes.settings or changes.pos_x then setupStation(station) end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for id in pairs(spawned) do teardownStation(id) end
end)

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(250) end
    local stations = lib.callback.await('kariee_radio:dj:getAll', false)
    for id, station in pairs(stations or {}) do
        DjStations[id] = station
        setupStation(station)
    end
end)

-- ─── Sound area helpers (used by client/broadcast.lua, lights and the creator) ─

---The booth's sound setup. Legacy booths (no settings): the whole interior if it's inside one,
---otherwise Config.DjOutdoorRange around it.
---@return table { type = 'interior'|'radius'|'area', range, muffled, points?, minZ?, maxZ?, fade }
function DjAudioOf(station)
    local audio = station.settings and station.settings.audio
    if audio then return audio end
    if station.interiorId == nil then
        station.interiorId = GetInteriorAtCoords(station.pos_x, station.pos_y, station.pos_z)
    end
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
        local pi, pj = points[i], points[j]
        if ((pi.y > y) ~= (pj.y > y)) and (x < (pj.x - pi.x) * (y - pi.y) / (pj.y - pi.y) + pi.x) then
            inside = not inside
        end
        j = i
    end
    return inside
end

local function segmentDistance(px, py, ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    local len2 = dx * dx + dy * dy
    local t = len2 > 0 and math.max(0, math.min(1, ((px - ax) * dx + (py - ay) * dy) / len2)) or 0
    local cx, cy = ax + t * dx - px, ay + t * dy - py
    return math.sqrt(cx * cx + cy * cy)
end

---For a custom sound area: are these coords inside it, and if not, how far outside?
---@return boolean inside, number distance metres outside the area (0 when inside)
function DjAreaDistance(audio, coords)
    local points = audio.points
    if not points or #points < 3 then return false, math.huge end
    local inside2d = pointInPolygon(coords.x, coords.y, points)
    local dz = 0.0
    if coords.z < audio.minZ then dz = audio.minZ - coords.z elseif coords.z > audio.maxZ then dz = coords.z - audio.maxZ end
    if inside2d and dz == 0.0 then return true, 0.0 end

    local edge = 0.0
    if not inside2d then
        edge = math.huge
        for i = 1, #points do
            local a, b = points[i], points[i % #points + 1]
            edge = math.min(edge, segmentDistance(coords.x, coords.y, a.x, a.y, b.x, b.y))
        end
    end
    return false, math.sqrt(edge * edge + dz * dz)
end

-- ─── Commands ──────────────────────────────────────────────────────────────

local function nearestStation()
    local coords = GetEntityCoords(PlayerPedId())
    local closestId, closestDist
    for id, station in pairs(DjStations) do
        local dist = #(coords - vector3(station.pos_x, station.pos_y, station.pos_z))
        if dist <= Config.Placement.interactRange and (not closestDist or dist < closestDist) then
            closestId, closestDist = id, dist
        end
    end
    return closestId
end

---Starts the booth creator for a new booth (used by /createdj and the admin panel).
function StartDjPlacement()
    StartDjCreator(nil)
end

RegisterCommand('createdj', function()
    StartDjCreator(nil)
end, false)

RegisterCommand('editdj', function()
    local id = nearestStation()
    if not id then
        ESX.ShowNotification(Config.Messages.no_station_nearby)
        return
    end
    if not lib.callback.await('kariee_radio:dj:canManage', false, id) then
        ESX.ShowNotification(Config.Messages.no_permission)
        return
    end
    StartDjCreator(DjStations[id])
end, false)

RegisterCommand('dj', function()
    local id = nearestStation()
    if not id then
        ESX.ShowNotification(Config.Messages.no_station_nearby)
        return
    end
    tryOpenDjStation(id)
end, false)

RegisterCommand('removedj', function()
    local id = nearestStation()
    if not id then
        ESX.ShowNotification(Config.Messages.no_station_nearby)
        return
    end
    local ok = lib.callback.await('kariee_radio:dj:remove', false, id)
    if ok then
        DjStations[id] = nil
        teardownStation(id)
    end
    ESX.ShowNotification(ok and Config.Messages.station_removed or Config.Messages.no_permission)
end, false)
