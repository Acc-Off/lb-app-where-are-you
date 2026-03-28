-- ============================================================================
-- reactions_repo.lua
-- Reactions RepositoryV2 — locshare_reactions テーブルへの CRUD 操作
--
-- 投稿へのリアクション管理を1ファイルに集約する。
-- リアクション删除は「リアクション者または投稿者」のどちらでも権限あり。
-- ============================================================================
local Server = WAY.Server
Server.RepositoryV2 = Server.RepositoryV2 or {}

local Repo = Server.Repository
local ReactionsRepo = {}

-- リアクションを作成する。stamp ・ message は任意。
function ReactionsRepo.createReaction(postId, playerId, stamp, message)
    return Repo.execute([[
        INSERT INTO locshare_reactions (post_id, player_id, stamp, message, created_at)
        VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)
    ]], {
        tonumber(postId),
        playerId,
        stamp and tostring(stamp) or nil,
        message and tostring(message) or nil,
    })
end

-- 指定投稿 ID 一覧のリアクションを表示名付きで取得する。
function ReactionsRepo.listReactionsByPostIds(postIds)
    if not postIds or #postIds == 0 then
        return {}
    end

    local placeholders = string.rep('?,', #postIds):sub(1, -2)
    return Repo.fetchAll(([[
        SELECT r.id, r.post_id, r.player_id, r.stamp, r.message, r.created_at, p.display_name
        FROM locshare_reactions r
        LEFT JOIN locshare_players p ON p.player_id = r.player_id
        WHERE r.post_id IN (%s)
        ORDER BY r.created_at ASC
    ]]):format(placeholders), postIds)
end

-- 山値のリアクション者 playerId 一覧を配列で返す（通知対象者の中複排除に使用）。
function ReactionsRepo.listReactionPlayerIds(postId)
    local rows = Repo.fetchAll([[SELECT DISTINCT player_id FROM locshare_reactions WHERE post_id = ?]], { tonumber(postId) })
    local ids = {}
    for i = 1, #rows do
        ids[#ids + 1] = rows[i].player_id
    end
    return ids
end

-- リアクションを削除する。
-- リアクション者（r.player_id）または投稿者（p.player_id）のどちらかなら削除可能。
function ReactionsRepo.deleteReactionByOwnerOrPostOwner(reactionId, playerId)
    return Repo.execute([[
        DELETE r FROM locshare_reactions r
        LEFT JOIN locshare_posts p ON p.id = r.post_id
        WHERE r.id = ? AND (r.player_id = ? OR p.player_id = ?)
    ]], { tonumber(reactionId), playerId, playerId })
end

Server.RepositoryV2.ReactionsRepo = ReactionsRepo
