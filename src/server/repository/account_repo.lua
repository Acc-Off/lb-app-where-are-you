-- ============================================================================
-- account_repo.lua
-- Account RepositoryV2 — 退会時の関連データ一括削除
--
-- プレイヤーに紐づく全テーブルのデータを削除するメソッドのみを提供する。
-- 削除順: リアクション（投稿経由）→ 投稿 → リアクション（直接）→ グループ参加 → フレンド関係 → プレイヤー行
-- ============================================================================
local Server = WAY.Server
Server.RepositoryV2 = Server.RepositoryV2 or {}

local Repo = Server.Repository
local AccountRepo = {}

-- プレイヤーに関連する全テーブルのデータを順序を守って一括削除する。
function AccountRepo.deleteAllByPlayerId(playerId)
    Repo.execute([[
        DELETE r FROM locshare_reactions r
        INNER JOIN locshare_posts p ON p.id = r.post_id
        WHERE p.player_id = ?
    ]], { playerId })
    Repo.execute([[DELETE FROM locshare_posts WHERE player_id = ?]], { playerId })
    Repo.execute([[DELETE FROM locshare_reactions WHERE player_id = ?]], { playerId })
    Repo.execute([[DELETE FROM locshare_group_members WHERE player_id = ?]], { playerId })
    Repo.execute([[DELETE FROM locshare_friends WHERE player_id = ? OR friend_id = ?]], { playerId, playerId })
    Repo.execute([[DELETE FROM locshare_players WHERE player_id = ?]], { playerId })
end

Server.RepositoryV2.AccountRepo = AccountRepo
