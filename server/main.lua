---Right after a (re)connect, ESX's player object can take a moment to finish loading - without a
---retry here, that race would make getState/playlist/DJ-ownership checks silently fail forever
---for anyone whose first callback lands in that window.
---@param source number
---@return string|nil
function GetIdentifier(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then return xPlayer.identifier end

    for _ = 1, 20 do
        Wait(250)
        if GetPlayerName(source) == nil then return nil end -- they disconnected, stop waiting
        xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then return xPlayer.identifier end
    end

    return nil
end

---Resolves a display name for an identifier, online or offline, falling back to the raw
---identifier if the player has never logged in / the users table doesn't have a name for them.
---@param identifier string
---@return string
function GetDisplayName(identifier)
    if not identifier then return 'Unknown' end

    local playerId = GetPlayers()
    for _, pid in ipairs(playerId) do
        if GetIdentifier(tonumber(pid)) == identifier then
            return GetPlayerName(tonumber(pid)) or identifier
        end
    end

    local ok, row = pcall(MySQL.single.await, 'SELECT firstname, lastname FROM users WHERE identifier = ?', { identifier })
    if ok and row and (row.firstname or row.lastname) then
        local name = (('%s %s'):format(row.firstname or '', row.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
        if name ~= '' then return name end
    end

    return identifier
end

---Builds the "song row" shape shared by playlist tracks / favourites / recently played.
---@param song table
---@param extra table|nil
function SerializeSong(song, extra)
    local row = {
        songId = song.songId or song.id,
        title = tostring(song.title or 'Unknown'):sub(1, 150),
        artist = tostring(song.artist or ''):sub(1, 150),
        duration = tonumber(song.duration) or 0,
        videoId = tostring(song.videoId or ''):sub(1, 32),
        thumbnail = song.thumbnail,
        hue = tonumber(song.hue) or 0,
    }
    if extra then
        for k, v in pairs(extra) do row[k] = v end
    end
    return row
end

-- CreateThread(function()
    -- MySQL.ready(function()
        -- print(('[kariee_radio] database connection ready'))
    -- end)
-- end)
