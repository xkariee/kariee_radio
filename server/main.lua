function GetIdentifier(source)
    if not source then return nil end
    local player = FRAMEWORK.GetPlayerFromId(source)
    for _ = 1, 20 do
        if player or not GetPlayerName(source) then break end
        Wait(250)
        player = FRAMEWORK.GetPlayerFromId(source)
    end
    return player and player.identifier or nil
end

function GetDisplayName(identifier)
    if not identifier then return 'Unknown' end
    local player = FRAMEWORK.GetPlayerFromIdentifier(identifier)
    if player then return GetPlayerName(player.source) or identifier end
    return FRAMEWORK.GetOfflineName(identifier) or identifier
end

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
    for key, value in pairs(extra or {}) do row[key] = value end
    return row
end

function Trim(value)
    return tostring(value or ''):match('^%s*(.-)%s*$')
end

function DecodeJson(raw)
    if type(raw) ~= 'string' or raw == '' then return nil end
    local ok, value = pcall(json.decode, raw)
    return ok and value or nil
end
