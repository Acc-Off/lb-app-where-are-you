-- ============================================================================
-- settings_repo.lua
-- Settings RepositoryV2 — アプリ設定（近距離通知関連）の永続化
--
-- 設定は locshare_players テーブルの同一行に格納される。
-- Config に設定値がない場合は config.lua のデフォルト値を使用する。
-- ============================================================================
local Server = WAY.Server
Server.RepositoryV2 = Server.RepositoryV2 or {}

local Repo = Server.Repository
local Const = Server.Const
local SettingsRepo = {}

-- プレイヤーのアプリ設定を取得する。行がなければ config.lua のデフォルト値を返す。
function SettingsRepo.getAppSettings(playerId)
    local row = Repo.fetchOne([[
        SELECT nearby_notify_enabled, nearby_radius, nearby_interval_ms
        FROM locshare_players
        WHERE player_id = ?
    ]], { playerId })

    if not row then
        return {
            nearbyNotifyEnabled = Config.NearbyNotifyEnabled == true,
            nearbyRadius = tonumber(Config.NearbyRadiusDefault or 100.0) or 100.0,
            nearbyIntervalMs = tonumber(Config.NearbyNotifyIntervalMs or 10000) or 10000,
        }
    end

    return {
        nearbyNotifyEnabled = (tonumber(row.nearby_notify_enabled) or 0) == 1,
        nearbyRadius = tonumber(row.nearby_radius) or tonumber(Config.NearbyRadiusDefault or 100.0) or 100.0,
        nearbyIntervalMs = tonumber(row.nearby_interval_ms) or tonumber(Config.NearbyNotifyIntervalMs or 10000) or 10000,
    }
end

-- アプリ設定を保存する。行がなければ初期行を挿入する。
-- radius と intervalMs は有効範囲にクランプしてから保存する。
function SettingsRepo.upsertAppSettings(playerId, settings)
    settings = settings or {}
    local enabled = settings.nearbyNotifyEnabled == true and 1 or 0
    local radius = math.max(20.0, math.min(1000.0, tonumber(settings.nearbyRadius) or tonumber(Config.NearbyRadiusDefault or 100.0) or 100.0))
    local intervalMs = math.max(2000, math.min(600000, math.floor(tonumber(settings.nearbyIntervalMs) or tonumber(Config.NearbyNotifyIntervalMs or 10000) or 10000)))

    Repo.execute([[
        INSERT INTO locshare_players (player_id, nearby_notify_enabled, nearby_radius, nearby_interval_ms, x, y, z, heading, speed, ghost_mode, updated_at)
        VALUES (?, ?, ?, ?, 0, 0, 0, 0, 0, ?, CURRENT_TIMESTAMP)
        ON DUPLICATE KEY UPDATE
            nearby_notify_enabled = VALUES(nearby_notify_enabled),
            nearby_radius = VALUES(nearby_radius),
            nearby_interval_ms = VALUES(nearby_interval_ms),
            updated_at = CURRENT_TIMESTAMP
    ]], { playerId, enabled, radius, intervalMs, Const.GHOST_NORMAL })

    return {
        nearbyNotifyEnabled = enabled == 1,
        nearbyRadius = radius,
        nearbyIntervalMs = intervalMs,
    }
end

Server.RepositoryV2.SettingsRepo = SettingsRepo
