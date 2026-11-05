Utils = {
    ped = cache.ped,
    playerId = cache.playerId,
    serverId = cache.serverId,
    vehicle = cache.vehicle or nil,
    loaded = FRAMEWORK.IsPlayerLoaded(),
    IsReady = function(self)
        return self.loaded and NetworkIsPlayerActive(self.playerId)
    end,
    InVehicle = function(self)
        if not self.vehicle then return false end
        if DoesEntityExist(self.vehicle) then return true end
        self.vehicle = nil
        return false
    end,
    IsIndoors = function(self)
        return GetInteriorFromEntity(self.ped) ~= 0
    end,
    GetCoords = function(self)
        return GetEntityCoords(self.ped)
    end,
    RadioId = function(self)
        return ('radio:%s'):format(self.serverId)
    end,
    Notify = function(self, message)
        if message then FRAMEWORK.ShowNotification(Config.Messages[message] or message) end
    end,
    Callback = function(self, name, ...)
        return lib.callback.await(('kariee_radio:%s'):format(name), false, ...)
    end,
    Pick = function(self, data, keys)
        local values = {}
        for i, key in ipairs(keys) do values[i] = data and data[key] end
        return table.unpack(values, 1, #keys)
    end,
    BindCallback = function(self, name, remote, keys, allowed)
        RegisterNUICallback(name, function(data, cb)
            if allowed and not allowed() then return cb(false) end
            local result = self:Callback(remote, self:Pick(data, keys))
            cb(result)
        end)
    end,
    GetStreet = function(self, coords)
        local street = GetStreetNameFromHashKey(GetStreetNameAtCoord(coords.x, coords.y, coords.z))
        return street ~= '' and street or nil
    end,
    HeadingTo = function(self, from, to)
        return math.deg(math.atan(-(to.x - from.x), to.y - from.y))
    end,
    LoadModel = function(self, model, timeout)
        if HasModelLoaded(model) then return true end
        if not IsModelInCdimage(model) then return false end
        RequestModel(model)
        local deadline = GetGameTimer() + (timeout or 3000)
        while not HasModelLoaded(model) do
            if GetGameTimer() > deadline then return false end
            Wait(10)
        end
        return true
    end,
    SpawnProp = function(self, model, coords, alpha)
        if not self:LoadModel(model) then return nil end
        local obj = CreateObject(model, coords.x, coords.y, coords.z, false, false, false)
        FreezeEntityPosition(obj, true)
        if alpha then
            SetEntityAlpha(obj, alpha, false)
            SetEntityCollision(obj, false, false)
        end
        SetModelAsNoLongerNeeded(model)
        return obj
    end,
    DeleteProp = function(self, obj)
        if obj and DoesEntityExist(obj) then DeleteObject(obj) end
    end,
    DrawSphere = function(self, coords, size, r, g, b, a)
        DrawMarker(28, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, size, size, size, r, g, b, a or 220, false, false, 2, false, nil, nil, false)
    end,
}

lib.onCache('ped', function(ped)
    Utils.ped = ped
end)

lib.onCache('vehicle', function(vehicle)
    Utils.vehicle = vehicle or nil
end)

FRAMEWORK.OnPlayerLoaded(function()
    Utils.loaded = true
    Utils.ped = PlayerPedId()
    Utils.serverId = GetPlayerServerId(Utils.playerId)
end)

FRAMEWORK.OnPlayerLogout(function()
    Utils.loaded = false
end)
