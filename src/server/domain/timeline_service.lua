-- タイムライン投稿の取得・作成・削除を担当するサービス。
-- 密度フィルタ（全員 / フレンドのみ / グループ限定）や投稿クールダウンもここで制御する。
local Server = WAY.Server
Server.Domain = Server.Domain or {}

local Runtime = Server.State
local Utils = Server.Utils
local RepoV2 = Server.RepositoryV2
local TimelineService = {}

-- タイムライン表示対象プレイヤーの ID 一覧を構築する。
-- filter: 'all' | 'friends' | 'group'、表示可能なプレイヤーを制御する。
-- 常に視聴者自身(viewerId)は結果に含まれる。
function TimelineService.buildTimelineSourceIds(viewerId, filter, groupId)
    local sourceMap = { [viewerId] = true }
    local relation = Runtime.friendRelations[viewerId] or { outgoing = {}, incoming = {} }
    local outgoing = relation.outgoing or {}
    local incoming = relation.incoming or {}

    -- チェックイン投稿は「その時点の位置スナップショット」のため、
    -- リアルタイム位置共有で使う blocked 判定はここでは適用しない。
    local function includeFriendsIgnoreBlock()
        for targetId, myStatus in pairs(outgoing) do
            local theirStatus = incoming[targetId]
            local meLinked = myStatus == 'accepted' or myStatus == 'blocked'
            local theyLinked = theirStatus == 'accepted' or theirStatus == 'blocked'
            if meLinked or theyLinked then
                sourceMap[targetId] = true
            end
        end
    end

    local function includeGroupMembers(targetGroupId)
        if not targetGroupId then
            return
        end

        local group = Runtime.groups[targetGroupId]
        local members = group and group.members or {}
        for memberId, _ in pairs(members) do
            sourceMap[memberId] = true
        end
    end

    local function includeAllMyGroups()
        local myGroups = Server.Domain.GroupsService.getMyGroups(viewerId)
        for i = 1, #myGroups do
            includeGroupMembers(myGroups[i].id)
        end
    end

    if filter == 'friends' then
        includeFriendsIgnoreBlock()
    elseif filter == 'group' then
        includeGroupMembers(groupId)
    else
        includeFriendsIgnoreBlock()
        includeAllMyGroups()
    end

    local ids = {}
    for id, _ in pairs(sourceMap) do
        ids[#ids + 1] = id
    end
    return ids
end

-- フィルタとリアクション情報を包含したタイムラインを構築する。
-- buildTimelineSourceIds で結果を絞り込み、投稿 + リアクションを JOIN して UI 形式に変換する。
function TimelineService.buildTimeline(viewerId, payload)
    local filter = tostring((payload and payload.filter) or 'all')
    local groupId = tonumber(payload and payload.groupId)
    local limit = tonumber(payload and payload.limit) or 30

    local sourceIds = TimelineService.buildTimelineSourceIds(viewerId, filter, groupId)
    local posts = RepoV2.PostsRepo.listPostsByPlayerIds(sourceIds, limit)
    if #posts == 0 then
        return { posts = {} }
    end

    local postIds = {}
    for i = 1, #posts do
        postIds[#postIds + 1] = posts[i].id
    end

    local reactions = RepoV2.ReactionsRepo.listReactionsByPostIds(postIds)
    local reactionMap = {}
    for i = 1, #reactions do
        local row = reactions[i]
        reactionMap[row.post_id] = reactionMap[row.post_id] or {}
        reactionMap[row.post_id][#reactionMap[row.post_id] + 1] = {
            id = row.id,
            playerId = row.player_id,
            displayName = (row.display_name and row.display_name ~= '') and row.display_name
                or (Runtime.lastKnownNames[row.player_id] or row.player_id),
            stamp = row.stamp,
            message = row.message,
            createdAt = row.created_at,
        }
    end

    local out = {}
    for i = 1, #posts do
        local row = posts[i]
        out[#out + 1] = {
            id = row.id,
            playerId = row.player_id,
            -- [B-2] display_name が NULL（初回位置保存前）の場合は lastKnownNames にフォールバックし、
            -- それも存在しない場合のみ player_id（市民ID）を表示する。
            displayName = (row.display_name ~= nil and row.display_name ~= '')
                and row.display_name
                or (Runtime.lastKnownNames[row.player_id] or row.player_id),
            x = tonumber(row.x) or 0,
            y = tonumber(row.y) or 0,
            z = tonumber(row.z) or 0,
            content = row.content or '',
            createdAt = row.created_at,
            reactions = reactionMap[row.id] or {},
        }
    end

    return { posts = out }
end

-- 現在地チェックインの投稿を作成する。
-- 座標共有同意とクールダウン（Config.PostCooldownMs）をチェックし、违反時はレートリミットエラーを返す。
function TimelineService.createCheckin(playerId, payload)
    local state = Runtime.players[playerId]
    if not state or not state.consent or not state.position then
        return false, nil, 'position unavailable'
    end

    local now = Utils.nowMs()
    local cooldownMs = tonumber(Config.PostCooldownMs or 30000) or 30000
    local lastAt = Runtime.postCooldowns[playerId] or 0
    if now - lastAt < cooldownMs then
        return false, nil, 'rate limited'
    end

    local content = tostring((payload and payload.content) or ''):sub(1, 280)
    local pos = state.position
    RepoV2.PostsRepo.createPost(playerId, pos.x, pos.y, pos.z, content)
    Runtime.postCooldowns[playerId] = now

    return true, { posted = true }
end

-- 投稿を削除する。自分の投稿のみ削除可能。
function TimelineService.deletePost(playerId, payload)
    local postId = tonumber(payload and payload.postId)
    if not postId then
        return false, nil, 'invalid post id'
    end

    RepoV2.PostsRepo.deletePostByOwner(postId, playerId)
    return true, { deleted = true }
end

Server.Domain.TimelineService = TimelineService
