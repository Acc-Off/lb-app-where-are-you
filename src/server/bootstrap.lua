-- WhereAreYou サーバー実装の名前空間を初期化する。
-- ファイル分割時にグローバル汚染を避けるため、専用テーブルに集約する。
WAY = WAY or {}
WAY.Server = WAY.Server or {}

local Server = WAY.Server
Server.Service = Server.Service or {}
Server.Repository = Server.Repository or {}
Server.RepositoryV2 = Server.RepositoryV2 or {}
Server.Domain = Server.Domain or {}

-- ゴーストモードの定数を一元管理する。
Server.Const = {
    RESOURCE = GetCurrentResourceName(),
    GHOST_NORMAL = 'normal',
    GHOST_FREEZE = 'freeze',
    GHOST_BLUR = 'blur',
    GHOST_OFF = 'off',
}

-- モード入力値のバリデーション用テーブル。
Server.Const.VALID_GHOST_MODES = {
    [Server.Const.GHOST_NORMAL] = true,
    [Server.Const.GHOST_FREEZE] = true,
    [Server.Const.GHOST_BLUR] = true,
    [Server.Const.GHOST_OFF] = true,
}

-- DB負荷削減のため、オンライン中の可変状態はメモリに保持する。
Server.State = Server.State or {
    players = {},
    sourceToPlayerId = {},
    lastKnownNames = {},
    nearbyCooldowns = {},
    postCooldowns = {},
    nearbyLoopStarted = false,
    groups = {},           -- group_id -> { id, name, password, created_at, members={} }
    playerGroups = {},     -- player_id -> [{ id, name, ghost_mode, frozen_x, frozen_y, frozen_z, joined_at }]
    friendRelations = {},  -- player_id -> { outgoing={[target]=status}, incoming={[source]=status} }
    playerLastKnown = {},  -- player_id -> { ghostMode, x, y, z }
}
