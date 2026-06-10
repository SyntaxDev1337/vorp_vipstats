-- ============================================================
--  vip_analytics  —  SQL Schema
--  Rulează în HeidiSQL / phpMyAdmin înainte să pornești resource-ul
-- ============================================================

CREATE TABLE IF NOT EXISTS `vip_weapons_analytics` (
    `id`           INT          NOT NULL AUTO_INCREMENT,
    `identifier`   VARCHAR(60)  NOT NULL,
    `charid`       INT          NOT NULL,
    `weapon_name`  VARCHAR(80)  NOT NULL,
    `arena_id`     TINYINT      NOT NULL DEFAULT 0,
    `total_kills`  INT          NOT NULL DEFAULT 0,
    `headshots`    INT          NOT NULL DEFAULT 0,
    `shots_fired`  INT          NOT NULL DEFAULT 0,
    `shots_hit`    INT          NOT NULL DEFAULT 0,
    `legs_hit`     INT          NOT NULL DEFAULT 0,
    `fav_zone`     VARCHAR(10)  NOT NULL DEFAULT 'Chest',
    `minutes_used` INT          NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_player_weapon_arena` (`identifier`, `charid`, `weapon_name`, `arena_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ──────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS `vip_arena_stats` (
    `id`           INT          NOT NULL AUTO_INCREMENT,
    `identifier`   VARCHAR(60)  NOT NULL,
    `charid`       INT          NOT NULL,
    `arena_id`     TINYINT      NOT NULL,
    `time_seconds` INT          NOT NULL DEFAULT 0,
    `kills`        INT          NOT NULL DEFAULT 0,
    `deaths`       INT          NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_player_arena` (`identifier`, `charid`, `arena_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ──────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS `vip_match_history` (
    `id`         INT          NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(60)  NOT NULL,
    `charid`     INT          NOT NULL,
    `arena_name` VARCHAR(80)  NOT NULL,
    `result`     VARCHAR(20)  NOT NULL DEFAULT 'Participant',
    `kills`      INT          NOT NULL DEFAULT 0,
    `deaths`     INT          NOT NULL DEFAULT 0,
    `date`       VARCHAR(20)  NOT NULL,
    PRIMARY KEY (`id`),
    INDEX `idx_player` (`identifier`, `charid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
