-- ============================================================================
-- players_repo.lua
-- Players RepositoryV2 — locshare_players テーブルへの CRUD 操作
--
-- プレイヤーの同意・表示名・位置・ゴーストモード・アプリ設定を管理する。
-- 位置データはオンライン中はメモリキャッシュが主体で、
-- ログアウト時およびリソース停止時にのみ DB へ永続化される。
-- ============================================================================
local Server = WAY.Server
Server.RepositoryV2 = Server.RepositoryV2 or {}

local Repo = Server.Repository
local Const = Server.Const
local PlayersRepo = {}

-- 複数プレイヤーの全カラムを一括取得する（可視性解決・設定取得に使用）。
function PlayersRepo.getByPlayerIds(playerIds)
    if not playerIds or #playerIds == 0 then
        return {}
    end

    local placeholders = string.rep('?,', #playerIds):sub(1, -2)
    return Repo.fetchAll(([[ 
        SELECT player_id, display_name, x, y, z, heading, speed, ghost_mode,
               friend_ghost_mode, friend_frozen_x, friend_frozen_y, friend_frozen_z,
               nearby_notify_enabled, nearby_radius, nearby_interval_ms, agreed_at, updated_at
        FROM locshare_players
        WHERE player_id IN (%s)
    ]]):format(placeholders), playerIds)
end

-- 1 プレイヤーの全カラムを取得する（ゴーストモードの読み込みに使用）。
function PlayersRepo.getByPlayerId(playerId)
    return Repo.fetchOne([[
        SELECT player_id, display_name, x, y, z, heading, speed, ghost_mode,
               friend_ghost_mode, friend_frozen_x, friend_frozen_y, friend_frozen_z,
               nearby_notify_enabled, nearby_radius, nearby_interval_ms, agreed_at, updated_at
        FROM locshare_players
        WHERE player_id = ?
        LIMIT 1
    ]], { playerId })
end

-- 位置・表示名・ゴーストモードをまとめて UPSERT する汎用メソッド。
function PlayersRepo.upsertPlayerState(playerId, fields)
    fields = fields or {}
    local ghostMode = fields.ghost_mode or Const.GHOST_NORMAL
    Repo.execute([[
        INSERT INTO locshare_players (player_id, display_name, x, y, z, heading, speed, ghost_mode, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
        ON DUPLICATE KEY UPDATE
            display_name = COALESCE(VALUES(display_name), display_name),
            x = VALUES(x),
            y = VALUES(y),
            z = VALUES(z),
            heading = VALUES(heading),
            speed = VALUES(speed),
            ghost_mode = VALUES(ghost_mode),
            updated_at = CURRENT_TIMESTAMP
    ]], {
        playerId,
        fields.display_name,
        tonumber(fields.x or 0),
        tonumber(fields.y or 0),
        tonumber(fields.z or 0),
        tonumber(fields.heading or 0),
        tonumber(fields.speed or 0),
        ghostMode,
    })
end

-- 同意済みか判定する。agreed_at が NULL でなければ true を返す。
function PlayersRepo.hasConsent(playerId)
    local row = Repo.fetchOne([[
        SELECT player_id
        FROM locshare_players
        WHERE player_id = ? AND agreed_at IS NOT NULL
        LIMIT 1
    ]], { playerId })
    return row ~= nil
end

-- 同意フラグを記録する。行が存在しない場合は初期行を挿入する。
function PlayersRepo.setConsent(playerId, _agreedAt)
    Repo.execute([[
        INSERT INTO locshare_players (player_id, agreed_at, x, y, z, heading, speed, ghost_mode, updated_at)
        VALUES (?, CURRENT_TIMESTAMP, 0, 0, 0, 0, 0, ?, CURRENT_TIMESTAMP)
        ON DUPLICATE KEY UPDATE
            agreed_at = CURRENT_TIMESTAMP,
            updated_at = CURRENT_TIMESTAMP
    ]], { playerId, Const.GHOST_NORMAL })
end

-- 同意フラグを取り消す（アプリアンインストール時に使用）。
-- agreed_at を NULL に戻し、再インストール時に規約への再同意を求める。
function PlayersRepo.clearConsent(playerId)
    Repo.execute([[
        UPDATE locshare_players
        SET agreed_at = NULL, updated_at = CURRENT_TIMESTAMP
        WHERE player_id = ?
    ]], { playerId })
end

-- 複数プレイヤーの表示名を { [playerId] = displayName } マップで返す。
function PlayersRepo.getProfileNameMap(playerIds)
    local map = {}
    if not playerIds or #playerIds == 0 then
        return map
    end

    local placeholders = string.rep('?,', #playerIds):sub(1, -2)
    local rows = Repo.fetchAll(([[
        SELECT player_id, display_name
        FROM locshare_players
        WHERE player_id IN (%s)
    ]]):format(placeholders), playerIds)

    for i = 1, #rows do
        map[rows[i].player_id] = rows[i].display_name
    end

    return map
end

-- グローバルゴーストモードを保存する（normal / off のみ）。
function PlayersRepo.setGlobalGhostMode(playerId, mode)
    local Const = Server.Const
    local ghostMode = (mode == Const.GHOST_OFF) and Const.GHOST_OFF or Const.GHOST_NORMAL
    Repo.execute([[
        INSERT INTO locshare_players (player_id, ghost_mode, x, y, z, heading, speed, updated_at)
        VALUES (?, ?, 0, 0, 0, 0, 0, CURRENT_TIMESTAMP)
        ON DUPLICATE KEY UPDATE
            ghost_mode = VALUES(ghost_mode),
            updated_at = CURRENT_TIMESTAMP
    ]], { playerId, ghostMode })
    return ghostMode
end

-- フレンド向けゴーストモードを保存する（normal / freeze / blur）。
function PlayersRepo.setFriendGhostMode(playerId, mode, freezeCoords)
    local Const = Server.Const
    local ghostMode = (mode == Const.GHOST_FREEZE or mode == Const.GHOST_BLUR) and mode or Const.GHOST_NORMAL
    if ghostMode == Const.GHOST_FREEZE and freezeCoords then
        Repo.execute([[
            UPDATE locshare_players
            SET friend_ghost_mode = ?,
                friend_frozen_x = ?,
                friend_frozen_y = ?,
                friend_frozen_z = ?,
                updated_at = CURRENT_TIMESTAMP
            WHERE player_id = ?
        ]], {
            ghostMode,
            tonumber(freezeCoords.x or 0),
            tonumber(freezeCoords.y or 0),
            tonumber(freezeCoords.z or 0),
            playerId,
        })
    else
        Repo.execute([[
            UPDATE locshare_players
            SET friend_ghost_mode = ?,
                friend_frozen_x = NULL,
                friend_frozen_y = NULL,
                friend_frozen_z = NULL,
                updated_at = CURRENT_TIMESTAMP
            WHERE player_id = ?
        ]], { ghostMode, playerId })
    end
    return ghostMode
end

-- 表示名を永続化する（ライフサイクル用）。
function PlayersRepo.saveProfileName(playerId, displayName)
    if not playerId or not displayName or displayName == '' then
        return
    end
    Repo.execute([[INSERT INTO locshare_players (player_id, display_name, x, y, z, heading, speed, ghost_mode, updated_at) VALUES (?, ?, 0, 0, 0, 0, 0, ?, CURRENT_TIMESTAMP) ON DUPLICATE KEY UPDATE display_name = VALUES(display_name), updated_at = CURRENT_TIMESTAMP]], { playerId, tostring(displayName), Server.Const.GHOST_NORMAL })
end

-- 座標とゴーストモードを UPSERT する（ログアウト/フラッシュ用）。
function PlayersRepo.upsertPosition(playerId, position, ghostMode)
    Repo.execute([[INSERT INTO locshare_players (player_id, x, y, z, heading, speed, ghost_mode, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP) ON DUPLICATE KEY UPDATE x = VALUES(x), y = VALUES(y), z = VALUES(z), heading = VALUES(heading), speed = VALUES(speed), updated_at = CURRENT_TIMESTAMP]], {
        playerId,
        tonumber(position.x or 0),
        tonumber(position.y or 0),
        tonumber(position.z or 0),
        tonumber(position.heading or 0),
        tonumber(position.speed or 0),
        ghostMode,
    })
end

Server.RepositoryV2.PlayersRepo = PlayersRepo
