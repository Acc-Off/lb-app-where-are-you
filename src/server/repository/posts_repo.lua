-- ============================================================================
-- posts_repo.lua
-- Posts RepositoryV2 — locshare_posts テーブルへの CRUD 操作
--
-- タイムラインの投稿管理、可視プレイヤー一覧取得を提供する。
-- ============================================================================
local Server = WAY.Server
Server.RepositoryV2 = Server.RepositoryV2 or {}

local Repo = Server.Repository
local PostsRepo = {}

-- 新規投稿を作成する。INSERT の lastInsertId を返す。
function PostsRepo.createPost(playerId, x, y, z, content)
    return Repo.execute([[
        INSERT INTO locshare_posts (player_id, x, y, z, content, created_at)
        VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
    ]], {
        playerId,
        tonumber(x or 0),
        tonumber(y or 0),
        tonumber(z or 0),
        tostring(content or ''),
    })
end

-- 指定プレイヤー ID 一覧の投稿を表示名付きで取得する。
-- limit は最大 100 件にクランプされる。
function PostsRepo.listPostsByPlayerIds(playerIds, limit, _offset)
    if not playerIds or #playerIds == 0 then
        return {}
    end

    local safeLimit = math.max(1, math.min(100, tonumber(limit) or 30))
    local placeholders = string.rep('?,', #playerIds):sub(1, -2)
    local params = {}
    for i = 1, #playerIds do
        params[#params + 1] = playerIds[i]
    end
    params[#params + 1] = safeLimit

    return Repo.fetchAll(([[
        SELECT p.id, p.player_id, p.x, p.y, p.z, p.content, p.created_at, pl.display_name
        FROM locshare_posts p
        LEFT JOIN locshare_players pl ON pl.player_id = p.player_id
        WHERE p.player_id IN (%s)
        ORDER BY p.created_at DESC
        LIMIT ?
    ]]):format(placeholders), params)
end

-- 投稿を期所有者が削除する（player_id 条件による所有者検証付き）。
function PostsRepo.deletePostByOwner(postId, playerId)
    return Repo.execute([[DELETE FROM locshare_posts WHERE id = ? AND player_id = ?]], {
        tonumber(postId),
        playerId,
    })
end

-- 投稿を ID で 1 件取得する（リアクション時の投稿者取得に使用）。
function PostsRepo.getById(postId)
    return Repo.fetchOne([[
        SELECT id, player_id, x, y, z, content, created_at
        FROM locshare_posts
        WHERE id = ?
        LIMIT 1
    ]], { tonumber(postId) })
end

Server.RepositoryV2.PostsRepo = PostsRepo
