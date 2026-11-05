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

---Bound to whichever command last opened the NUI; every control goes to it. `id` is the
---ActiveBroadcasts key on the server. nil when it was opened with no radio bound (inside an
---interior, where the personal radio isn't allowed) - then nothing can be changed, and a DJ
---booth / car radio used earlier is never controlled from somewhere else.
---@type table|nil
ActiveContext = nil

---Opens the radio NUI bound to the given context (called below, and by client/dj.lua and
---client/admin.lua).
---@param context table|nil { kind = 'radio'|'dj'|'radiocar', id = string, stationId?, vehicleNetId? }
---@param view string|nil view to land on ('admin' for /radioadmin)
---@param blocked string|nil with no context: the notice shown when the player tries to play
function OpenRadio(context, view, blocked)
    ActiveContext = context
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

    -- Indoors there's no radio to bind to: the panel still opens (playlists, search, settings),
    -- but anything that would play music is cancelled with this notice - same as /radioadmin.
    local context, reason = ResolveRadioContext()
    OpenRadio(context, nil, reason and Config.Messages[reason])
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

RegisterNUICallback('getState', cbHandler('kariee_radio:getState', function(_) return { ActiveContext } end))

-- Static settings the NUI asks for once on load (it can't read config.lua itself).
RegisterNUICallback('getConfig', function(_, cb)
    cb({
        widget = Config.NowPlayingWidget ~= false,
        widgetCommand = Config.WidgetCommand,
        serverId = GetPlayerServerId(PlayerId()),
        lights = Config.DiscoLights.enabled == true,
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

---Sends a control to the broadcast the panel is bound to - dropped when it isn't bound to any
---(opened inside an interior).
local function control(event, ...)
    if not ActiveContext then return end
    TriggerServerEvent(event, ActiveContext.id, ...)
end

RegisterNUICallback('play', function(data, cb)
    if ActiveContext then
        TriggerServerEvent('kariee_radio:broadcast:play', ActiveContext.kind, ActiveContext.stationId or ActiveContext.vehicleNetId, data.song, data.volume, data.queue)
    end
    cb({})
end)

RegisterNUICallback('togglePlay', function(_, cb)
    control('kariee_radio:broadcast:togglePlay')
    cb({})
end)

RegisterNUICallback('seek', function(data, cb)
    control('kariee_radio:broadcast:seek', data.seconds)
    cb({})
end)

-- Disco light beat grid (DJ booths) from the tap-tempo control; no bpm = back to the default.
RegisterNUICallback('setTempo', function(data, cb)
    control('kariee_radio:broadcast:setTempo', data.bpm, data.offset)
    cb({})
end)

RegisterNUICallback('setVolume', function(data, cb)
    control('kariee_radio:broadcast:setVolume', data.volume)
    cb({})
end)

RegisterNUICallback('stop', function(_, cb)
    control('kariee_radio:broadcast:stop')
    cb({})
end)

RegisterNUICallback('next', function(_, cb)
    control('kariee_radio:broadcast:next')
    cb({})
end)

RegisterNUICallback('enqueue', function(data, cb)
    control('kariee_radio:broadcast:enqueue', data.song)
    cb({})
end)

RegisterNUICallback('enqueueNext', function(data, cb)
    control('kariee_radio:broadcast:enqueueNext', data.song)
    cb({})
end)

RegisterNUICallback('removeFromQueue', function(data, cb)
    control('kariee_radio:broadcast:removeFromQueue', data.index)
    cb({})
end)

RegisterNUICallback('setQueue', function(data, cb)
    control('kariee_radio:broadcast:setQueue', data.queue)
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
