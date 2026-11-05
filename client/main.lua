local nuiOpen = false
local activeContext = nil

local REQUESTS = {
    createPlaylist = { 'name', 'cover' },
    renamePlaylist = { 'id', 'name' },
    deletePlaylist = { 'id' },
    setPlaylistCover = { 'id', 'cover' },
    addTrack = { 'playlistId', 'song' },
    removeTrack = { 'playlistId', 'songId' },
    toggleFavorite = { 'song' },
    invite = { 'playlistId', 'targetId' },
    removeCollaborator = { 'playlistId', 'identifier' },
    acceptInvite = { 'playlistId' },
    declineInvite = { 'playlistId' },
    searchPlayers = { 'query' },
}

local CONTROLS = {
    togglePlay = {},
    seek = { 'seconds' },
    setTempo = { 'bpm', 'offset' },
    setVolume = { 'volume' },
    stop = {},
    next = {},
    enqueue = { 'song' },
    enqueueNext = { 'song' },
    removeFromQueue = { 'index' },
    setQueue = { 'queue' },
}

function OpenRadio(context, view, blocked)
    activeContext = context
    nuiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', context = context, view = view, blocked = blocked })
end

function CloseRadio()
    nuiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

function IsRadioOpen()
    return nuiOpen
end

local function resolveContext()
    if Utils:InVehicle() then
        local netId = NetworkGetNetworkIdFromEntity(Utils.vehicle)
        return { kind = 'radiocar', id = ('car:%s'):format(netId), vehicleNetId = netId }
    end
    if Utils:IsIndoors() then return nil, 'radio_forbidden_interior' end
    return { kind = 'radio', id = Utils:RadioId() }
end

function OpenPlayerRadio(view)
    local context, reason = resolveContext()
    OpenRadio(context, view, reason and Config.Messages[reason])
end

RegisterCommand('kradio', function()
    if nuiOpen then return CloseRadio() end
    if not Utils:IsReady() then return Utils:Notify('not_ready') end
    OpenPlayerRadio()
end, false)

RegisterKeyMapping('kradio', 'Open/close the radio', 'keyboard', Config.OpenKey)

if Config.NowPlayingWidget ~= false and Config.WidgetCommand then
    RegisterCommand(Config.WidgetCommand, function()
        SendNUIMessage({ action = 'widgetToggle' })
    end, false)
end

RegisterNUICallback('close', function(_, cb)
    CloseRadio()
    cb({})
end)

RegisterNUICallback('getConfig', function(_, cb)
    cb({
        widget = Config.NowPlayingWidget ~= false,
        widgetCommand = Config.WidgetCommand,
        serverId = Utils.serverId,
        lights = Config.DiscoLights.enabled == true,
    })
end)

RegisterNUICallback('getState', function(_, cb)
    local state = Utils:Callback('getState', activeContext)
    cb(state)
end)

for name, keys in pairs(REQUESTS) do
    Utils:BindCallback(name, name, keys)
end

RegisterNUICallback('play', function(data, cb)
    if activeContext then
        TriggerServerEvent('kariee_radio:broadcast:play', activeContext.kind, activeContext.stationId or activeContext.vehicleNetId, data.song, data.volume, data.queue)
    end
    cb({})
end)

for name, keys in pairs(CONTROLS) do
    RegisterNUICallback(name, function(data, cb)
        if activeContext then
            TriggerServerEvent(('kariee_radio:broadcast:%s'):format(name), activeContext.id, Utils:Pick(data, keys))
        end
        cb({})
    end)
end

RegisterNUICallback('widgetToggled', function(data, cb)
    Utils:Notify(data.enabled and 'widget_on' or 'widget_off')
    cb({})
end)

RegisterNetEvent('kariee_radio:invite:received', function(invite)
    SendNUIMessage({ action = 'inviteReceived', invite = invite })
end)

RegisterNetEvent('kariee_radio:notify', function(message)
    Utils:Notify(message)
end)

RegisterNetEvent('kariee_radio:banned', function(ban)
    SendNUIMessage({ action = 'banned', ban = ban })
    if not ban then return end
    local text = ban.scope == 'all' and Config.Messages.banned_all or Config.Messages.banned_dj
    if ban.reason and ban.reason ~= '' then text = ('%s Reason: %s'):format(text, ban.reason) end
    Utils:Notify(text)
end)
