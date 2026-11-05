local function insertSong(tableName, identifier, row)
    MySQL.insert.await(
        ('INSERT INTO %s (identifier, song_id, title, artist, duration, video_id, thumbnail, hue) VALUES (?, ?, ?, ?, ?, ?, ?, ?)'):format(tableName),
        { identifier, row.songId, row.title, row.artist, row.duration, row.videoId, row.thumbnail, row.hue }
    )
end

function GetFavoritesForPlayer(identifier)
    return MySQL.query.await('SELECT * FROM radio_favorites WHERE identifier = ? ORDER BY created_at DESC', { identifier }) or {}
end

function GetRecentForPlayer(identifier)
    return MySQL.query.await('SELECT * FROM radio_recent WHERE identifier = ? ORDER BY played_at DESC LIMIT ?', { identifier, Config.MaxRecentlyPlayed }) or {}
end

function RecordRecentlyPlayed(identifier, song)
    if not identifier or type(song) ~= 'table' then return end
    local row = SerializeSong(song)

    MySQL.query.await('DELETE FROM radio_recent WHERE identifier = ? AND song_id = ?', { identifier, row.songId })
    insertSong('radio_recent', identifier, row)
    MySQL.query.await([[
        DELETE FROM radio_recent WHERE identifier = ? AND id NOT IN (
            SELECT id FROM (SELECT id FROM radio_recent WHERE identifier = ? ORDER BY played_at DESC LIMIT ?) t
        )
    ]], { identifier, identifier, Config.MaxRecentlyPlayed })
end

lib.callback.register('kariee_radio:toggleFavorite', function(source, song)
    local identifier = GetIdentifier(source)
    if not identifier or type(song) ~= 'table' then return nil end

    local row = SerializeSong(song)
    local existing = MySQL.single.await('SELECT id FROM radio_favorites WHERE identifier = ? AND song_id = ?', { identifier, row.songId })
    if existing then
        MySQL.update.await('DELETE FROM radio_favorites WHERE id = ?', { existing.id })
        return false
    end

    insertSong('radio_favorites', identifier, row)
    return true
end)

lib.callback.register('kariee_radio:getState', function(source, context)
    local identifier = GetIdentifier(source)
    if not identifier then return nil end

    local djLocked = type(context) == 'table' and context.kind == 'dj'
        and not CanUseDjStation(source, DjStations[tonumber(context.stationId)])

    return {
        identifier = identifier,
        name = GetDisplayName(identifier),
        playlists = GetPlaylistsForPlayer(identifier),
        favorites = GetFavoritesForPlayer(identifier),
        recent = GetRecentForPlayer(identifier),
        invites = GetInvitesForPlayer(identifier),
        broadcast = GetBroadcastSnapshotFor(context),
        isAdmin = IsRadioAdmin(source),
        ban = SerializeRadioBan(GetRadioBan(source)),
        djLocked = djLocked or false,
    }
end)
