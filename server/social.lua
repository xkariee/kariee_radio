-- Favourites, recently played, and the combined NUI hydration payload.

---@param identifier string
function GetFavoritesForPlayer(identifier)
    return MySQL.query.await('SELECT * FROM radio_favorites WHERE identifier = ? ORDER BY created_at DESC', { identifier }) or {}
end

---@param identifier string
function GetRecentForPlayer(identifier)
    return MySQL.query.await('SELECT * FROM radio_recent WHERE identifier = ? ORDER BY played_at DESC LIMIT ?', { identifier, Config.MaxRecentlyPlayed }) or {}
end

lib.callback.register('kariee_radio:toggleFavorite', function(source, song)
    local identifier = GetIdentifier(source)
    if not identifier or type(song) ~= 'table' then return nil end

    local songId = song.songId or song.id
    local existing = MySQL.single.await('SELECT id FROM radio_favorites WHERE identifier = ? AND song_id = ?', { identifier, songId })

    if existing then
        MySQL.update.await('DELETE FROM radio_favorites WHERE id = ?', { existing.id })
        return false
    end

    local row = SerializeSong(song)
    MySQL.insert.await([[
        INSERT INTO radio_favorites (identifier, song_id, title, artist, duration, video_id, thumbnail, hue)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ]], { identifier, row.songId, row.title, row.artist, row.duration, row.videoId, row.thumbnail, row.hue })
    return true
end)

---Records a play and prunes anything past Config.MaxRecentlyPlayed for that player.
---@param identifier string
---@param song table
function RecordRecentlyPlayed(identifier, song)
    if not identifier or type(song) ~= 'table' then return end
    local row = SerializeSong(song)

    MySQL.query.await('DELETE FROM radio_recent WHERE identifier = ? AND song_id = ?', { identifier, row.songId })
    MySQL.insert.await([[
        INSERT INTO radio_recent (identifier, song_id, title, artist, duration, video_id, thumbnail, hue)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ]], { identifier, row.songId, row.title, row.artist, row.duration, row.videoId, row.thumbnail, row.hue })

    MySQL.query.await([[
        DELETE FROM radio_recent WHERE identifier = ? AND id NOT IN (
            SELECT id FROM (SELECT id FROM radio_recent WHERE identifier = ? ORDER BY played_at DESC LIMIT ?) t
        )
    ]], { identifier, identifier, Config.MaxRecentlyPlayed })
end

lib.callback.register('kariee_radio:getState', function(source, context)
    local identifier = GetIdentifier(source)
    if not identifier then return nil end

    return {
        identifier = identifier,
        name = GetDisplayName(identifier),
        playlists = GetPlaylistsForPlayer(identifier),
        favorites = GetFavoritesForPlayer(identifier),
        recent = GetRecentForPlayer(identifier),
        invites = GetInvitesForPlayer(identifier),
        broadcast = GetBroadcastSnapshotFor(context),
    }
end)
