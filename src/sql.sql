CREATE TABLE IF NOT EXISTS locshare_players (
    player_id         VARCHAR(64) PRIMARY KEY,
    x                 FLOAT NOT NULL DEFAULT 0,
    y                 FLOAT NOT NULL DEFAULT 0,
    z                 FLOAT NOT NULL DEFAULT 0,
    heading           FLOAT NOT NULL DEFAULT 0,
    speed             FLOAT NOT NULL DEFAULT 0,
    ghost_mode        ENUM('normal','off') NOT NULL DEFAULT 'normal',
    friend_ghost_mode ENUM('normal','freeze','blur') NOT NULL DEFAULT 'normal',
    friend_frozen_x   FLOAT NULL,
    friend_frozen_y   FLOAT NULL,
    friend_frozen_z   FLOAT NULL,
    nearby_notify_enabled TINYINT(1) NOT NULL DEFAULT 0,
    nearby_radius     FLOAT NOT NULL DEFAULT 100,
    nearby_interval_ms INT NOT NULL DEFAULT 10000,
    display_name      VARCHAR(128) NOT NULL DEFAULT '',
    agreed_at         TIMESTAMP NULL,
    updated_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS locshare_friends (
    id          INT PRIMARY KEY AUTO_INCREMENT,
    player_id   VARCHAR(64) NOT NULL,
    friend_id   VARCHAR(64) NOT NULL,
    status      ENUM('pending','accepted','blocked') NOT NULL DEFAULT 'pending',
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_pair (player_id, friend_id),
    INDEX idx_friend (friend_id),
    INDEX idx_status (status)
);

CREATE TABLE IF NOT EXISTS locshare_groups (
    id          INT PRIMARY KEY AUTO_INCREMENT,
    name        VARCHAR(50) NOT NULL,
    password    VARCHAR(100) NULL,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_name (name)
);

CREATE TABLE IF NOT EXISTS locshare_group_members (
    group_id    INT NOT NULL,
    player_id   VARCHAR(64) NOT NULL,
    ghost_mode  ENUM('normal','freeze','blur') NOT NULL DEFAULT 'normal',
    frozen_x    FLOAT NULL,
    frozen_y    FLOAT NULL,
    frozen_z    FLOAT NULL,
    joined_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (group_id, player_id),
    FOREIGN KEY (group_id) REFERENCES locshare_groups(id) ON DELETE CASCADE,
    INDEX idx_player (player_id)
);

CREATE TABLE IF NOT EXISTS locshare_posts (
    id          INT PRIMARY KEY AUTO_INCREMENT,
    player_id   VARCHAR(64) NOT NULL,
    x           FLOAT        NOT NULL,
    y           FLOAT        NOT NULL,
    z           FLOAT        NOT NULL,
    content     TEXT,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_player_created (player_id, created_at)
);

CREATE TABLE IF NOT EXISTS locshare_reactions (
    id          INT PRIMARY KEY AUTO_INCREMENT,
    post_id     INT          NOT NULL,
    player_id   VARCHAR(64) NOT NULL,
    stamp       VARCHAR(8)  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
    message     VARCHAR(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (post_id) REFERENCES locshare_posts(id) ON DELETE CASCADE
);
