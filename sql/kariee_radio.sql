-- kariee_radio database schema
-- Run once against your ESX database (e.g. via oxmysql / HeidiSQL / phpMyAdmin).

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `radio_dj_stations` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `owner_identifier` VARCHAR(64) NOT NULL,
  `label` VARCHAR(64) NOT NULL DEFAULT 'DJ Station',
  `pos_x` FLOAT NOT NULL,
  `pos_y` FLOAT NOT NULL,
  `pos_z` FLOAT NOT NULL,
  `heading` FLOAT NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_owner` (`owner_identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
