local nuiOpen = false

---True once ESX has finished loading this player's character. Right after a fresh connect
---there's a window where ESX.PlayerData/identifier isn't ready yet - opening the radio during
---that window is what silently broke everything until a resource restart fixed it for whoever
---was already connected. Shared (global) so client/dj.lua can gate on it too.
---@type boolean
PlayerLoaded = ESX.IsPlayerLoaded and ESX.IsPlayerLoaded() or false

RegisterNetEvent('esx:playerLoaded', function()
    PlayerLoaded = true
end)

---Requests a model with a bounded wait, so a bad/not-yet-streamed model hash can never hang
---the calling thread forever (used by client/dj.lua and client/broadcast.lua too).
---@return boolean
function LoadModel(model, timeoutMs)
    if HasModelLoaded(model) then return true end
    RequestModel(model)
    local start = GetGameTimer()
    while not HasModelLoaded(model) do
        Wait(10)
        if GetGameTimer() - start > (timeoutMs or 3000) then return false end
    end
    return true
end

---Bound to whichever command opened the NUI. `id` is the ActiveBroadcasts key on the server.
---@type table
ActiveContext = { kind = 'radio', id = ('radio:%s'):format(GetPlayerServerId(PlayerId())) }

---The context the NUI is open with right now - nil when only the admin panel is open (e.g. an
---admin used /radioadmin inside an interior, where the personal radio isn't allowed).
---@type table|nil
OpenContext = nil

---Opens the radio NUI bound to the given context (called below, and by client/dj.lua and
---client/admin.lua).
---@param context table|nil { kind = 'radio'|'dj'|'radiocar', id = string, stationId?, vehicleNetId? }
---@param view string|nil view to land on ('admin' for /radioadmin)
function OpenRadio(context, view)
    if context then ActiveContext = context end
    OpenContext = context
    nuiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', context = context, view = view })
end

function CloseRadio()
    nuiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

function IsRadioOpen()
    return nuiOpen
end

---Personal radio, or the car radio if you're in a vehicle (collaborative - any occupant).
---@return table|nil context, string|nil reason message key when there is none
function ResolveRadioContext()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle ~= 0 then
        local netId = NetworkGetNetworkIdFromEntity(vehicle)
        return { kind = 'radiocar', id = ('car:%s'):format(netId), vehicleNetId = netId }
    end

    if GetInteriorFromEntity(ped) ~= 0 then return nil, 'radio_forbidden_interior' end

    return { kind = 'radio', id = ('radio:%s'):format(GetPlayerServerId(PlayerId())) }
end

-- Toggles the panel open (bound to your radio / car radio) or closed.
local function toggleRadio()
    if nuiOpen then
        CloseRadio()
        return
    end

    -- Right after connecting, the network id / ESX character can briefly still not be ready;
    -- opening on that would silently break every control (play/pause/etc) for the rest of the
    -- session, only fixable with a resource restart.
    if not NetworkIsPlayerActive(PlayerId()) or not PlayerLoaded then
        ESX.ShowNotification(Config.Messages.not_ready)
        return
    end

    local context, reason = ResolveRadioContext()
    if not context then
        ESX.ShowNotification(Config.Messages[reason])
        return
    end
    OpenRadio(context)
end

RegisterKeyMapping('kradio', 'Open/close the radio', 'keyboard', Config.OpenKey)
RegisterCommand('kradio', toggleRadio, false)

-- ─── Generic request/response bridge ───────────────────────────────────────

local function cbHandler(remoteName, extraTransform)
    return function(data, cb)
        local args = extraTransform and extraTransform(data) or { data }
        local result = lib.callback.await(remoteName, false, table.unpack(args))
        cb(result)
    end
end

RegisterNUICallback('close', function(_, cb)
    CloseRadio()
    cb({})
end)

RegisterNUICallback('getState', cbHandler('kariee_radio:getState', function(_) return { OpenContext } end))

-- Static settings the NUI asks for once on load (it can't read config.lua itself).
RegisterNUICallback('getConfig', function(_, cb)
    cb({
        widget = Config.NowPlayingWidget ~= false,
        widgetCommand = Config.WidgetCommand,
        serverId = GetPlayerServerId(PlayerId()),
    })
end)
RegisterNUICallback('createPlaylist', cbHandler('kariee_radio:createPlaylist', function(d) return { d.name, d.cover } end))
RegisterNUICallback('renamePlaylist', cbHandler('kariee_radio:renamePlaylist', function(d) return { d.id, d.name } end))
RegisterNUICallback('deletePlaylist', cbHandler('kariee_radio:deletePlaylist', function(d) return { d.id } end))
RegisterNUICallback('setPlaylistCover', cbHandler('kariee_radio:setPlaylistCover', function(d) return { d.id, d.cover } end))
RegisterNUICallback('addTrack', cbHandler('kariee_radio:addTrack', function(d) return { d.playlistId, d.song } end))
RegisterNUICallback('removeTrack', cbHandler('kariee_radio:removeTrack', function(d) return { d.playlistId, d.songId } end))
RegisterNUICallback('toggleFavorite', cbHandler('kariee_radio:toggleFavorite', function(d) return { d.song } end))
RegisterNUICallback('invite', cbHandler('kariee_radio:invite', function(d) return { d.playlistId, d.targetId } end))
RegisterNUICallback('removeCollaborator', cbHandler('kariee_radio:removeCollaborator', function(d) return { d.playlistId, d.identifier } end))
RegisterNUICallback('acceptInvite', cbHandler('kariee_radio:acceptInvite', function(d) return { d.playlistId } end))
RegisterNUICallback('declineInvite', cbHandler('kariee_radio:declineInvite', function(d) return { d.playlistId } end))
RegisterNUICallback('searchPlayers', cbHandler('kariee_radio:searchPlayers', function(d) return { d.query } end))

-- ─── Playback (fire-and-forget, synced back via kariee_radio:broadcast:sync) ──

RegisterNUICallback('play', function(data, cb)
    TriggerServerEvent('kariee_radio:broadcast:play', ActiveContext.kind, ActiveContext.stationId or ActiveContext.vehicleNetId, data.song, data.volume, data.queue)
    cb({})
end)

RegisterNUICallback('togglePlay', function(_, cb)
    TriggerServerEvent('kariee_radio:broadcast:togglePlay', ActiveContext.id)
    cb({})
end)

RegisterNUICallback('seek', function(data, cb)
    TriggerServerEvent('kariee_radio:broadcast:seek', ActiveContext.id, data.seconds)
    cb({})
end)

RegisterNUICallback('setVolume', function(data, cb)
    TriggerServerEvent('kariee_radio:broadcast:setVolume', ActiveContext.id, data.volume)
    cb({})
end)

RegisterNUICallback('stop', function(_, cb)
    TriggerServerEvent('kariee_radio:broadcast:stop', ActiveContext.id)
    cb({})
end)

RegisterNUICallback('next', function(_, cb)
    TriggerServerEvent('kariee_radio:broadcast:next', ActiveContext.id)
    cb({})
end)

RegisterNUICallback('enqueue', function(data, cb)
    TriggerServerEvent('kariee_radio:broadcast:enqueue', ActiveContext.id, data.song)
    cb({})
end)

RegisterNUICallback('enqueueNext', function(data, cb)
    TriggerServerEvent('kariee_radio:broadcast:enqueueNext', ActiveContext.id, data.song)
    cb({})
end)

RegisterNUICallback('removeFromQueue', function(data, cb)
    TriggerServerEvent('kariee_radio:broadcast:removeFromQueue', ActiveContext.id, data.index)
    cb({})
end)

RegisterNUICallback('setQueue', function(data, cb)
    TriggerServerEvent('kariee_radio:broadcast:setQueue', ActiveContext.id, data.queue)
    cb({})
end)

-- ─── Live push events from the server ──────────────────────────────────────

RegisterNetEvent('kariee_radio:invite:received', function(invite)
    SendNUIMessage({ action = 'inviteReceived', invite = invite })
end)

RegisterNetEvent('kariee_radio:notify', function(message)
    if message then ESX.ShowNotification(message) end
end)

---Sent when a banned player tries a radio action, when an admin bans them, and (with nil) when
---the ban is lifted - keeps the NUI's ban banner in sync.
RegisterNetEvent('kariee_radio:banned', function(ban)
    SendNUIMessage({ action = 'banned', ban = ban })
    if not ban then return end
    local text = ban.scope == 'all' and Config.Messages.banned_all or Config.Messages.banned_dj
    if ban.reason and ban.reason ~= '' then text = ('%s Reason: %s'):format(text, ban.reason) end
    ESX.ShowNotification(text)
end)

-- ─── Nearby now-playing widget ─────────────────────────────────────────────

if Config.NowPlayingWidget ~= false and Config.WidgetCommand then
    RegisterCommand(Config.WidgetCommand, function()
        SendNUIMessage({ action = 'widgetToggle' })
    end, false)
end

RegisterNUICallback('widgetToggled', function(data, cb)
    ESX.ShowNotification(data.enabled and Config.Messages.widget_on or Config.Messages.widget_off)
    cb({})
end)
