local isAdmin = false

local function allowed()
    return isAdmin
end

local function toVector(coords)
    return vector3(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0)
end

local function enrich(item, origin)
    if type(item.coords) ~= 'table' then return end
    local coords = toVector(item.coords)
    local zone = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z))
    item.street = Utils:GetStreet(coords)
    item.zone = zone ~= 'NULL' and zone or nil
    item.distance = #(origin - coords)
    item.interior = GetInteriorAtCoords(coords.x, coords.y, coords.z) ~= 0
end

RegisterCommand(Config.AdminCommand, function()
    if not Utils:IsReady() then return Utils:Notify('not_ready') end
    isAdmin = Utils:Callback('admin:isAdmin') == true
    if not isAdmin then return Utils:Notify('no_permission') end
    OpenPlayerRadio('admin')
end, false)

RegisterNUICallback('adminGetData', function(_, cb)
    local data = Utils:Callback('admin:getData')
    isAdmin = type(data) == 'table'
    if not isAdmin then return cb(nil) end
    local origin = Utils:GetCoords()
    for _, broadcast in ipairs(data.broadcasts or {}) do enrich(broadcast, origin) end
    for _, station in ipairs(data.stations or {}) do enrich(station, origin) end
    data.me = Utils.serverId
    cb(data)
end)

Utils:BindCallback('adminStop', 'admin:stop', { 'id' }, allowed)
Utils:BindCallback('adminStopNear', 'admin:stopNear', { 'radius' }, allowed)
Utils:BindCallback('adminStopAll', 'admin:stopAll', {}, allowed)
Utils:BindCallback('adminRenameStation', 'admin:renameStation', { 'id', 'label' }, allowed)
Utils:BindCallback('adminRemoveStation', 'admin:removeStation', { 'id' }, allowed)
Utils:BindCallback('adminUnban', 'admin:unban', { 'identifier' }, allowed)

RegisterNUICallback('adminBan', function(data, cb)
    if not isAdmin then return cb({ ok = false, err = 'no_permission' }) end
    local ok, extra = Utils:Callback('admin:ban', data)
    cb({ ok = ok == true, err = not ok and extra or nil, stopped = ok and extra or 0 })
end)

RegisterNUICallback('adminWaypoint', function(data, cb)
    if not isAdmin or type(data.coords) ~= 'table' then return cb(false) end
    SetNewWaypoint(data.coords.x + 0.0, data.coords.y + 0.0)
    cb(true)
end)

RegisterNUICallback('adminTeleport', function(data, cb)
    if not isAdmin or type(data.coords) ~= 'table' then return cb(false) end
    local coords = toVector(data.coords)
    cb(true)
    CloseRadio()
    CreateThread(function()
        DoScreenFadeOut(250)
        while not IsScreenFadedOut() do Wait(0) end
        SetEntityCoords(Utils.ped, coords.x, coords.y, coords.z + 0.5, false, false, false, false)
        Wait(250)
        DoScreenFadeIn(350)
    end)
end)

RegisterNUICallback('adminEditStation', function(data, cb)
    local station = isAdmin and DjStations[tonumber(data.id)]
    if not station then return cb(false) end
    cb(true)
    CloseRadio()
    StartDjCreator(station)
end)

RegisterNUICallback('adminPlaceStation', function(_, cb)
    if not isAdmin then return cb(false) end
    cb(true)
    CloseRadio()
    StartDjCreator()
end)
