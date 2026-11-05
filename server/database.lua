local PREFIX = ('[^5%s^0]'):format(GetCurrentResourceName():upper())

local TABLES = {
    [[
        CREATE TABLE IF NOT EXISTS `radio_playlists` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `owner_identifier` VARCHAR(64) NOT NULL,
            `name` VARCHAR(100) NOT NULL,
            `cover` TEXT NULL,
            `hue` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
            `is_default` TINYINT(1) NOT NULL DEFAULT 0,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `idx_owner` (`owner_identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
    [[
        CREATE TABLE IF NOT EXISTS `radio_playlist_tracks` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `playlist_id` INT UNSIGNED NOT NULL,
            `song_id` VARCHAR(64) NOT NULL,
            `title` VARCHAR(150) NOT NULL,
            `artist` VARCHAR(150) NOT NULL DEFAULT '',
            `duration` INT UNSIGNED NOT NULL DEFAULT 0,
            `video_id` VARCHAR(32) NOT NULL,
            `thumbnail` TEXT NULL,
            `hue` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
            `position` INT UNSIGNED NOT NULL DEFAULT 0,
            `added_by` VARCHAR(64) NOT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `uq_playlist_song` (`playlist_id`, `song_id`),
            KEY `idx_playlist` (`playlist_id`),
            CONSTRAINT `fk_track_playlist` FOREIGN KEY (`playlist_id`) REFERENCES `radio_playlists` (`id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
    [[
        CREATE TABLE IF NOT EXISTS `radio_playlist_members` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `playlist_id` INT UNSIGNED NOT NULL,
            `identifier` VARCHAR(64) NOT NULL,
            `status` ENUM('pending', 'accepted') NOT NULL DEFAULT 'pending',
            `invited_by` VARCHAR(64) NOT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `uq_playlist_member` (`playlist_id`, `identifier`),
            KEY `idx_identifier_status` (`identifier`, `status`),
            CONSTRAINT `fk_member_playlist` FOREIGN KEY (`playlist_id`) REFERENCES `radio_playlists` (`id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
    [[
        CREATE TABLE IF NOT EXISTS `radio_favorites` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `identifier` VARCHAR(64) NOT NULL,
            `song_id` VARCHAR(64) NOT NULL,
            `title` VARCHAR(150) NOT NULL,
            `artist` VARCHAR(150) NOT NULL DEFAULT '',
            `duration` INT UNSIGNED NOT NULL DEFAULT 0,
            `video_id` VARCHAR(32) NOT NULL,
            `thumbnail` TEXT NULL,
            `hue` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `uq_identifier_song` (`identifier`, `song_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
    [[
        CREATE TABLE IF NOT EXISTS `radio_recent` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `identifier` VARCHAR(64) NOT NULL,
            `song_id` VARCHAR(64) NOT NULL,
            `title` VARCHAR(150) NOT NULL,
            `artist` VARCHAR(150) NOT NULL DEFAULT '',
            `duration` INT UNSIGNED NOT NULL DEFAULT 0,
            `video_id` VARCHAR(32) NOT NULL,
            `thumbnail` TEXT NULL,
            `hue` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
            `played_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `idx_identifier_played` (`identifier`, `played_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
    [[
        CREATE TABLE IF NOT EXISTS `radio_dj_stations` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `owner_identifier` VARCHAR(64) NOT NULL,
            `label` VARCHAR(64) NOT NULL DEFAULT 'DJ Station',
            `pos_x` FLOAT NOT NULL,
            `pos_y` FLOAT NOT NULL,
            `pos_z` FLOAT NOT NULL,
            `heading` FLOAT NOT NULL DEFAULT 0,
            `settings` LONGTEXT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `idx_owner` (`owner_identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
    [[
        CREATE TABLE IF NOT EXISTS `radio_bans` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `identifier` VARCHAR(64) NOT NULL,
            `name` VARCHAR(100) NOT NULL DEFAULT '',
            `scope` ENUM('dj', 'all') NOT NULL DEFAULT 'dj',
            `reason` VARCHAR(255) NOT NULL DEFAULT '',
            `banned_by` VARCHAR(100) NOT NULL DEFAULT '',
            `expires_at` INT UNSIGNED NULL DEFAULT NULL,
            `created_at` INT UNSIGNED NOT NULL,
            PRIMARY KEY (`id`),
            UNIQUE KEY `uq_identifier` (`identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
}

local COLUMNS = {
    { table = 'radio_dj_stations', column = 'settings', definition = 'LONGTEXT NULL' },
}

local ready = false
local queue = {}

local function ensureColumn(column)
    local rows = MySQL.query.await(("SHOW COLUMNS FROM `%s` LIKE '%s'"):format(column.table, column.column))
    if rows and #rows > 0 then return end
    MySQL.query.await(('ALTER TABLE `%s` ADD COLUMN `%s` %s'):format(column.table, column.column, column.definition))
end

function OnDatabaseReady(cb)
    if ready then return CreateThread(cb) end
    queue[#queue + 1] = cb
end

MySQL.ready(function()
    for i, query in ipairs(TABLES) do
        local ok, err = pcall(MySQL.query.await, query)
        if ok then
            -- print(('^2[INFO]^0 %s SQL table %d of %d has been checked/created.'):format(PREFIX, i, #TABLES))
        else
            print(('^1[ERROR]^0 %s SQL table %d of %d failed: %s'):format(PREFIX, i, #TABLES, err))
        end
    end

    for _, column in ipairs(COLUMNS) do
        local ok, err = pcall(ensureColumn, column)
        if not ok then print(('^1[ERROR]^0 %s Could not add %s.%s: %s'):format(PREFIX, column.table, column.column, err)) end
    end

    ready = true
    for _, cb in ipairs(queue) do CreateThread(cb) end
    queue = {}
end)
