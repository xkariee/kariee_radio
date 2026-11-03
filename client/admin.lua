-- Client side of the admin panel: opens it, adds what only the client can work out (street
-- names, distance from you, interior or not) and runs local actions (waypoint, teleport,
-- placement tool). Everything that changes server state is re-checked server-side.

local isAdmin = false

local function refreshAdmin()
    isAdmin = lib.callback.await('kariee_radio:admin:isAdmin', false) == true
    return isAdmin
end

RegisterCommand(Config.AdminCommand, function()
    if not NetworkIsPlayerActive(PlayerId()) or not PlayerLoaded then
        ESX.ShowNotification(Config.Messages.not_ready)
        return
    end
    if not refreshAdmin() then
        ESX.ShowNotification(Config.Messages.no_permission)
        return
    end
    -- Bound to your radio when you could open one here; otherwise just the admin panel.
    OpenRadio(ResolveRadioContext(), 'admin')
end, false)

local function locationOf(coords)
    local street = GetStreetNameFromHashKey(GetStreetNameAtCoord(coords.x, coords.y, coords.z))
    local zone = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z))
    if zone == 'NULL' then zone = nil end
    return street ~= '' and street or nil, zone
end

local function enrich(item, myCoords)
    if type(item.coords) ~= 'table' then return end
    local c = vector3(item.coords.x + 0.0, item.coords.y + 0.0, item.coords.z + 0.0)
    item.street, item.zone = locationOf(c)
    item.distance = #(myCoords - c)
    item.interior = GetInteriorAtCoords(c.x, c.y, c.z) ~= 0
end

RegisterNUICallback('adminGetData', function(_, cb)
    local data = lib.callback.await('kariee_radio:admin:getData', false)
    if not data then
        isAdmin = false
        cb(nil)
        return
    end
    isAdmin = true
    local myCoords = GetEntityCoords(PlayerPedId())
    for _, b in ipairs(data.broadcasts or {}) do enrich(b, myCoords) end
    for _, s in ipairs(data.stations or {}) do enrich(s, myCoords) end
    data.me = GetPlayerServerId(PlayerId())
    cb(data)
end)

local function forward(name, remote, argsOf)
    RegisterNUICallback(name, function(d, cb)
        if not isAdmin then
            cb(false)
            return
        end
        cb(lib.callback.await(remote, false, table.unpack(argsOf(d or {}))))
    end)
end

forward('adminStop', 'kariee_radio:admin:stop', function(d) return { d.id } end)
forward('adminStopNear', 'kariee_radio:admin:stopNear', function(d) return { d.radius } end)
forward('adminStopAll', 'kariee_radio:admin:stopAll', function() return {} end)
forward('adminRenameStation', 'kariee_radio:admin:renameStation', function(d) return { d.id, d.label } end)
forward('adminRemoveStation', 'kariee_radio:admin:removeStation', function(d) return { d.id } end)
forward('adminUnban', 'kariee_radio:admin:unban', function(d) return { d.identifier } end)

RegisterNUICallback('adminBan', function(d, cb)
    if not isAdmin then
        cb({ ok = false, err = 'no_permission' })
        return
    end
    local ok, extra = lib.callback.await('kariee_radio:admin:ban', false, d)
    cb({ ok = ok == true, err = not ok and extra or nil, stopped = ok and extra or 0 })
end)

RegisterNUICallback('adminWaypoint', function(d, cb)
    if not isAdmin or type(d.coords) ~= 'table' then
        cb(false)
        return
    end
    SetNewWaypoint(d.coords.x + 0.0, d.coords.y + 0.0)
    cb(true)
end)

RegisterNUICallback('adminTeleport', function(d, cb)
    if not isAdmin or type(d.coords) ~= 'table' then
        cb(false)
        return
    end
    cb(true)
    CloseRadio()
    CreateThread(function()
        local ped = PlayerPedId()
        DoScreenFadeOut(250)
        while not IsScreenFadedOut() do Wait(0) end
        SetEntityCoords(ped, d.coords.x + 0.0, d.coords.y + 0.0, d.coords.z + 0.5, false, false, false, false)
        Wait(250)
        DoScreenFadeIn(350)
    end)
end)

RegisterNUICallback('adminEditStation', function(d, cb)
    local station = isAdmin and DjStations[tonumber(d.id)]
    if not station then
        cb(false)
        return
    end
    cb(true)
    CloseRadio()
    StartDjCreator(station)
end)

RegisterNUICallback('adminPlaceStation', function(_, cb)
    if not isAdmin then
        cb(false)
        return
    end
    cb(true)
    CloseRadio()
    StartDjPlacement()
end)
