-- ============================================================================
-- friends_repo.lua
-- Friends RepositoryV2 — locshare_friends テーブルへの CRUD 操作
--
-- フレンド関係は「方向性あり」モデル:
--   player_id → friend_id の向きでレコードを管理する。
--   双方向 accepted の場合は A→B / B→A の 2 行が存在する。
-- ============================================================================
local Server = WAY.Server
Server.RepositoryV2 = Server.RepositoryV2 or {}

local Repo = Server.Repository
local FriendsRepo = {}

-- player_id → friend_id 方向のステータスを 1 件取得する。
-- 存在しない場合は nil を返す。
function FriendsRepo.getDirectionalStatus(playerId, targetPlayerId)
    local row = Repo.fetchOne([[
        SELECT status FROM locshare_friends WHERE player_id = ? AND friend_id = ? LIMIT 1
    ]], { playerId, targetPlayerId })
    return row and row.status or nil
end

-- player_id → friend_id 方向のレコードを INSERT または UPDATE する。
-- 既存レコードがあれば status と created_at を上書きする。
function FriendsRepo.upsertDirectionalStatus(playerId, friendId, status)
    Repo.execute([[
        INSERT INTO locshare_friends (player_id, friend_id, status, created_at)
        VALUES (?, ?, ?, CURRENT_TIMESTAMP)
        ON DUPLICATE KEY UPDATE status = VALUES(status), created_at = CURRENT_TIMESTAMP
    ]], { playerId, friendId, status })
end

-- A→B / B→A 両方向のレコードをまとめて削除する（フレンド解除用）。
function FriendsRepo.deleteBothDirections(playerId, friendId)
    Repo.execute([[
        DELETE FROM locshare_friends
        WHERE (player_id = ? AND friend_id = ?) OR (player_id = ? AND friend_id = ?)
    ]], { playerId, friendId, friendId, playerId })
end

-- 指定 ID の pending レコードを取得する（申請承認/辞退の検証用）。
-- friend_id が一致しない場合（他人の申請）は nil を返す。
function FriendsRepo.findPendingRequestById(requestId, friendId)
    return Repo.fetchOne([[
        SELECT id, player_id, friend_id, status
        FROM locshare_friends
        WHERE id = ? AND friend_id = ? AND status = 'pending'
        LIMIT 1
    ]], { requestId, friendId })
end

-- プレイヤーが関与する全フレンドレコードを取得する（双方向）。
-- フレンド一覧のステータス構築に使用する。
function FriendsRepo.listByPlayerId(playerId)
    return Repo.fetchAll([[
        SELECT id, player_id, friend_id, status, created_at
        FROM locshare_friends
        WHERE player_id = ? OR friend_id = ?
        ORDER BY created_at DESC
    ]], { playerId, playerId })
end

-- 全フレンドレコードを一括取得する（起動時のメモリ初期化用）。
function FriendsRepo.fetchAllForInit()
    return Repo.fetchAll([[
        SELECT player_id, friend_id, status
        FROM locshare_friends
    ]], {})
end

-- 自分から相手への方向の全レコードを取得する（getOwnRelationMap 用）。
function FriendsRepo.listOutgoingByPlayerId(playerId)
    return Repo.fetchAll([[SELECT friend_id, status FROM locshare_friends WHERE player_id = ?]], { playerId })
end

-- 自分宛の pending 申請を取得する（buildPendingRequests 用）。
function FriendsRepo.listPendingIncoming(playerId)
    return Repo.fetchAll([[SELECT id, player_id, created_at FROM locshare_friends WHERE friend_id = ? AND status = 'pending' ORDER BY created_at DESC]], { playerId })
end

-- pending レコードを ID で削除する（申請辞退用）。
function FriendsRepo.deletePendingById(requestId)
    Repo.execute([[DELETE FROM locshare_friends WHERE id = ?]], { requestId })
end

-- 自分→相手の blocked レコードを削除する（ブロック解除用）。
function FriendsRepo.deleteBlocked(playerId, targetPlayerId)
    Repo.execute([[DELETE FROM locshare_friends WHERE player_id = ? AND friend_id = ? AND status = 'blocked']], { playerId, targetPlayerId })
end

Server.RepositoryV2.FriendsRepo = FriendsRepo
