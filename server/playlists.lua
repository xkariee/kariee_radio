-- Playlist CRUD, tracks, collaborators/invites.

---@param identifier string
function GetPlaylistsForPlayer(identifier)
    local owned = MySQL.query.await('SELECT * FROM radio_playlists WHERE owner_identifier = ?', { identifier })
    local shared = MySQL.query.await([[
        SELECT p.* FROM radio_playlists p
        INNER JOIN radio_playlist_members m ON m.playlist_id = p.id
        WHERE m.identifier = ? AND m.status = 'accepted'
    ]], { identifier })

    local playlists = {}
    local seen = {}
    for _, row in ipairs(owned or {}) do
        if not seen[row.id] then
            seen[row.id] = true
            playlists[#playlists + 1] = row
        end
    end
    for _, row in ipairs(shared or {}) do
        if not seen[row.id] then
            seen[row.id] = true
            playlists[#playlists + 1] = row
        end
    end

    for _, pl in ipairs(playlists) do
        local tracks = MySQL.query.await('SELECT * FROM radio_playlist_tracks WHERE playlist_id = ? ORDER BY position ASC, id ASC', { pl.id })
        local members = MySQL.query.await([[SELECT identifier, status, invited_by FROM radio_playlist_members WHERE playlist_id = ? AND status = 'accepted']], { pl.id })
        pl.tracks = tracks or {}
        pl.collaborators = members or {}
        pl.owner_name = GetDisplayName(pl.owner_identifier)
        for _, m in ipairs(pl.collaborators) do
            m.name = GetDisplayName(m.identifier)
        end
    end

    return playlists
end

---@param identifier string
function GetInvitesForPlayer(identifier)
    local rows = MySQL.query.await([[
        SELECT m.playlist_id, p.name, p.hue, m.invited_by
        FROM radio_playlist_members m
        INNER JOIN radio_playlists p ON p.id = m.playlist_id
        WHERE m.identifier = ? AND m.status = 'pending'
    ]], { identifier }) or {}

    for _, row in ipairs(rows) do
        row.invited_by_name = GetDisplayName(row.invited_by)
    end

    return rows
end

local function isOwner(playlistId, identifier)
    local row = MySQL.single.await('SELECT id FROM radio_playlists WHERE id = ? AND owner_identifier = ?', { playlistId, identifier })
    return row ~= nil
end

local function hasAccess(playlistId, identifier)
    if isOwner(playlistId, identifier) then return true end
    local row = MySQL.single.await([[SELECT id FROM radio_playlist_members WHERE playlist_id = ? AND identifier = ? AND status = 'accepted']], { playlistId, identifier })
    return row ~= nil
end

lib.callback.register('kariee_radio:createPlaylist', function(source, name, cover)
    local identifier = GetIdentifier(source)
    if not identifier then return nil end

    local cleanName = tostring(name or ''):sub(1, 100)
    if cleanName == '' then cleanName = 'Untitled Playlist' end
    local hue = math.random(0, 359)

    local id = MySQL.insert.await(
        'INSERT INTO radio_playlists (owner_identifier, name, cover, hue) VALUES (?, ?, ?, ?)',
        { identifier, cleanName, cover, hue }
    )

    return {
        id = id,
        owner_identifier = identifier,
        owner_name = GetDisplayName(identifier),
        name = cleanName,
        cover = cover,
        hue = hue,
        is_default = 0,
        tracks = {},
        collaborators = {},
    }
end)

lib.callback.register('kariee_radio:renamePlaylist', function(source, playlistId, name)
    local identifier = GetIdentifier(source)
    if not identifier or not isOwner(playlistId, identifier) then return false end
    local cleanName = tostring(name or ''):sub(1, 100)
    if cleanName == '' then return false end
    MySQL.update.await('UPDATE radio_playlists SET name = ? WHERE id = ?', { cleanName, playlistId })
    return true
end)

lib.callback.register('kariee_radio:setPlaylistCover', function(source, playlistId, cover)
    local identifier = GetIdentifier(source)
    if not identifier or not isOwner(playlistId, identifier) then return false end
    MySQL.update.await('UPDATE radio_playlists SET cover = ? WHERE id = ?', { cover, playlistId })
    return true
end)

lib.callback.register('kariee_radio:deletePlaylist', function(source, playlistId)
    local identifier = GetIdentifier(source)
    if not identifier or not isOwner(playlistId, identifier) then return false end
    MySQL.update.await('DELETE FROM radio_playlists WHERE id = ?', { playlistId })
    return true
end)

lib.callback.register('kariee_radio:addTrack', function(source, playlistId, song)
    local identifier = GetIdentifier(source)
    if not identifier or not hasAccess(playlistId, identifier) or type(song) ~= 'table' then return false end

    local row = SerializeSong(song)
    local posRow = MySQL.single.await('SELECT COALESCE(MAX(position), -1) + 1 AS nextPos FROM radio_playlist_tracks WHERE playlist_id = ?', { playlistId })

    MySQL.insert.await([[
        INSERT INTO radio_playlist_tracks (playlist_id, song_id, title, artist, duration, video_id, thumbnail, hue, position, added_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE title = VALUES(title)
    ]], {
        playlistId, row.songId, row.title, row.artist, row.duration, row.videoId, row.thumbnail, row.hue,
        posRow and posRow.nextPos or 0, identifier,
    })

    return true
end)

lib.callback.register('kariee_radio:removeTrack', function(source, playlistId, songId)
    local identifier = GetIdentifier(source)
    if not identifier or not hasAccess(playlistId, identifier) then return false end
    MySQL.update.await('DELETE FROM radio_playlist_tracks WHERE playlist_id = ? AND song_id = ?', { playlistId, songId })
    return true
end)

lib.callback.register('kariee_radio:invite', function(source, playlistId, targetServerId)
    local identifier = GetIdentifier(source)
    if not identifier or not isOwner(playlistId, identifier) then return false, 'no_permission' end

    local targetIdentifier = GetIdentifier(tonumber(targetServerId))
    if not targetIdentifier or targetIdentifier == identifier then return false, 'invalid_target' end

    MySQL.insert.await([[
        INSERT INTO radio_playlist_members (playlist_id, identifier, status, invited_by)
        VALUES (?, ?, 'pending', ?)
        ON DUPLICATE KEY UPDATE status = status
    ]], { playlistId, targetIdentifier, identifier })

    local playlist = MySQL.single.await('SELECT name, hue FROM radio_playlists WHERE id = ?', { playlistId })
    TriggerClientEvent('kariee_radio:invite:received', tonumber(targetServerId), {
        playlistId = playlistId,
        name = playlist and playlist.name or 'Playlist',
        hue = playlist and playlist.hue or 0,
        invitedBy = identifier,
        invitedByName = GetDisplayName(identifier),
    })

    return true
end)

lib.callback.register('kariee_radio:removeCollaborator', function(source, playlistId, targetIdentifier)
    local identifier = GetIdentifier(source)
    if not identifier then return false end
    -- owner can remove anyone; a collaborator can remove themself (leave playlist)
    if not isOwner(playlistId, identifier) and identifier ~= targetIdentifier then return false end
    MySQL.update.await('DELETE FROM radio_playlist_members WHERE playlist_id = ? AND identifier = ?', { playlistId, targetIdentifier })
    return true
end)

lib.callback.register('kariee_radio:acceptInvite', function(source, playlistId)
    local identifier = GetIdentifier(source)
    if not identifier then return nil end
    MySQL.update.await([[UPDATE radio_playlist_members SET status = 'accepted' WHERE playlist_id = ? AND identifier = ? AND status = 'pending']], { playlistId, identifier })
    local pl = MySQL.single.await('SELECT * FROM radio_playlists WHERE id = ?', { playlistId })
    if not pl then return nil end
    pl.tracks = MySQL.query.await('SELECT * FROM radio_playlist_tracks WHERE playlist_id = ? ORDER BY position ASC, id ASC', { playlistId }) or {}
    pl.collaborators = MySQL.query.await([[SELECT identifier, status, invited_by FROM radio_playlist_members WHERE playlist_id = ? AND status = 'accepted']], { playlistId }) or {}
    pl.owner_name = GetDisplayName(pl.owner_identifier)
    for _, m in ipairs(pl.collaborators) do
        m.name = GetDisplayName(m.identifier)
    end
    return pl
end)

lib.callback.register('kariee_radio:declineInvite', function(source, playlistId)
    local identifier = GetIdentifier(source)
    if not identifier then return false end
    MySQL.update.await([[DELETE FROM radio_playlist_members WHERE playlist_id = ? AND identifier = ? AND status = 'pending']], { playlistId, identifier })
    return true
end)

lib.callback.register('kariee_radio:searchPlayers', function(source, query)
    local q = tostring(query or ''):lower()
    local results = {}
    for _, playerId in ipairs(GetPlayers()) do
        local pid = tonumber(playerId)
        if pid ~= source then
            local xPlayer = ESX.GetPlayerFromId(pid)
            if xPlayer then
                local name = GetPlayerName(pid) or ('Player ' .. pid)
                if q == '' or name:lower():find(q, 1, true) then
                    results[#results + 1] = { id = pid, name = name }
                end
            end
        end
    end
    return results
end)
