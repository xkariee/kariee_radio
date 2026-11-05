local function playlistName(name)
    return tostring(name or ''):sub(1, 100)
end

local function hydrate(playlist)
    playlist.tracks = MySQL.query.await('SELECT * FROM radio_playlist_tracks WHERE playlist_id = ? ORDER BY position ASC, id ASC', { playlist.id }) or {}
    playlist.collaborators = MySQL.query.await("SELECT identifier, status, invited_by FROM radio_playlist_members WHERE playlist_id = ? AND status = 'accepted'", { playlist.id }) or {}
    playlist.owner_name = GetDisplayName(playlist.owner_identifier)
    for _, member in ipairs(playlist.collaborators) do member.name = GetDisplayName(member.identifier) end
    return playlist
end

local function isOwner(playlistId, identifier)
    return MySQL.single.await('SELECT id FROM radio_playlists WHERE id = ? AND owner_identifier = ?', { playlistId, identifier }) ~= nil
end

local function hasAccess(playlistId, identifier)
    if isOwner(playlistId, identifier) then return true end
    return MySQL.single.await("SELECT id FROM radio_playlist_members WHERE playlist_id = ? AND identifier = ? AND status = 'accepted'", { playlistId, identifier }) ~= nil
end

function GetPlaylistsForPlayer(identifier)
    local owned = MySQL.query.await('SELECT * FROM radio_playlists WHERE owner_identifier = ?', { identifier }) or {}
    local shared = MySQL.query.await([[
        SELECT p.* FROM radio_playlists p
        INNER JOIN radio_playlist_members m ON m.playlist_id = p.id
        WHERE m.identifier = ? AND m.status = 'accepted'
    ]], { identifier }) or {}

    local playlists, seen = {}, {}
    for _, rows in ipairs({ owned, shared }) do
        for _, row in ipairs(rows) do
            if not seen[row.id] then
                seen[row.id] = true
                playlists[#playlists + 1] = hydrate(row)
            end
        end
    end
    return playlists
end

function GetInvitesForPlayer(identifier)
    local rows = MySQL.query.await([[
        SELECT m.playlist_id, p.name, p.hue, m.invited_by
        FROM radio_playlist_members m
        INNER JOIN radio_playlists p ON p.id = m.playlist_id
        WHERE m.identifier = ? AND m.status = 'pending'
    ]], { identifier }) or {}

    for _, row in ipairs(rows) do row.invited_by_name = GetDisplayName(row.invited_by) end
    return rows
end

lib.callback.register('kariee_radio:createPlaylist', function(source, name, cover)
    local identifier = GetIdentifier(source)
    if not identifier then return nil end

    local cleanName = playlistName(name)
    local playlist = {
        owner_identifier = identifier,
        owner_name = GetDisplayName(identifier),
        name = cleanName ~= '' and cleanName or 'Untitled Playlist',
        cover = cover,
        hue = math.random(0, 359),
        is_default = 0,
        tracks = {},
        collaborators = {},
    }
    playlist.id = MySQL.insert.await(
        'INSERT INTO radio_playlists (owner_identifier, name, cover, hue) VALUES (?, ?, ?, ?)',
        { identifier, playlist.name, cover, playlist.hue }
    )
    return playlist
end)

lib.callback.register('kariee_radio:renamePlaylist', function(source, playlistId, name)
    local identifier = GetIdentifier(source)
    if not identifier or not isOwner(playlistId, identifier) then return false end
    name = playlistName(name)
    if name == '' then return false end
    MySQL.update.await('UPDATE radio_playlists SET name = ? WHERE id = ?', { name, playlistId })
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
    if not identifier or type(song) ~= 'table' or not hasAccess(playlistId, identifier) then return false end

    local row = SerializeSong(song)
    local position = MySQL.single.await('SELECT COALESCE(MAX(position), -1) + 1 AS nextPos FROM radio_playlist_tracks WHERE playlist_id = ?', { playlistId })
    MySQL.insert.await([[
        INSERT INTO radio_playlist_tracks (playlist_id, song_id, title, artist, duration, video_id, thumbnail, hue, position, added_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE title = VALUES(title)
    ]], {
        playlistId, row.songId, row.title, row.artist, row.duration, row.videoId, row.thumbnail, row.hue,
        position and position.nextPos or 0, identifier,
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

    local targetId = tonumber(targetServerId)
    local targetIdentifier = GetIdentifier(targetId)
    if not targetIdentifier or targetIdentifier == identifier then return false, 'invalid_target' end

    MySQL.insert.await([[
        INSERT INTO radio_playlist_members (playlist_id, identifier, status, invited_by)
        VALUES (?, ?, 'pending', ?)
        ON DUPLICATE KEY UPDATE status = status
    ]], { playlistId, targetIdentifier, identifier })

    local playlist = MySQL.single.await('SELECT name, hue FROM radio_playlists WHERE id = ?', { playlistId })
    TriggerClientEvent('kariee_radio:invite:received', targetId, {
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
    if identifier ~= targetIdentifier and not isOwner(playlistId, identifier) then return false end
    MySQL.update.await('DELETE FROM radio_playlist_members WHERE playlist_id = ? AND identifier = ?', { playlistId, targetIdentifier })
    return true
end)

lib.callback.register('kariee_radio:acceptInvite', function(source, playlistId)
    local identifier = GetIdentifier(source)
    if not identifier then return nil end
    MySQL.update.await("UPDATE radio_playlist_members SET status = 'accepted' WHERE playlist_id = ? AND identifier = ? AND status = 'pending'", { playlistId, identifier })
    local playlist = MySQL.single.await('SELECT * FROM radio_playlists WHERE id = ?', { playlistId })
    return playlist and hydrate(playlist) or nil
end)

lib.callback.register('kariee_radio:declineInvite', function(source, playlistId)
    local identifier = GetIdentifier(source)
    if not identifier then return false end
    MySQL.update.await("DELETE FROM radio_playlist_members WHERE playlist_id = ? AND identifier = ? AND status = 'pending'", { playlistId, identifier })
    return true
end)

lib.callback.register('kariee_radio:searchPlayers', function(source, query)
    local search = tostring(query or ''):lower()
    local results = {}
    for _, playerId in ipairs(GetPlayers()) do
        local id = tonumber(playerId)
        if id ~= source and FRAMEWORK.GetPlayerFromId(id) then
            local name = GetPlayerName(id) or ('Player %d'):format(id)
            if search == '' or name:lower():find(search, 1, true) then
                results[#results + 1] = { id = id, name = name }
            end
        end
    end
    return results
end)
