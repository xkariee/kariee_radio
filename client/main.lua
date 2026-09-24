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

---Opens the radio NUI bound to the given context (called below, and by client/dj.lua).
---@param context table { kind = 'radio'|'dj'|'radiocar', id = string, stationId?, vehicleNetId? }
function OpenRadio(context)
    ActiveContext = context
    nuiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', context = context })
end

function CloseRadio()
    nuiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

-- Opens your personal radio, or the car radio if you're in a vehicle (collaborative - any
-- occupant), toggling closed if the panel is already open.
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

    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle ~= 0 then
        local netId = NetworkGetNetworkIdFromEntity(vehicle)
        OpenRadio({ kind = 'radiocar', id = ('car:%s'):format(netId), vehicleNetId = netId })
        return
    end

    if GetInteriorFromEntity(ped) ~= 0 then
        ESX.ShowNotification(Config.Messages.radio_forbidden_interior)
        return
    end

    OpenRadio({ kind = 'radio', id = ('radio:%s'):format(GetPlayerServerId(PlayerId())) })
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

-- ─── Live push events from the server ──────────────────────────────────────

RegisterNetEvent('kariee_radio:invite:received', function(invite)
    SendNUIMessage({ action = 'inviteReceived', invite = invite })
end)
