-- 投稿へのリアクション作成・削除処理を担当するサービス。
-- 可視性チェック（投稿が宛ろに表示されるプレイヤーかどうか）もここで実行する。
local Server = WAY.Server
Server.Domain = Server.Domain or {}

local RepoV2 = Server.RepositoryV2
-- NotificationsService はこのファイルより後にロードされるため、実行時に Server.Domain.* を参照する。
local ReactionsService = {}

-- 投稿にリアクションを付ける。
-- 可視性検証（視聴者が投稿を参照できるか）を3の後、リアクションを保存して投稿購読者へ通知する。
function ReactionsService.reactToPost(playerId, payload)
    local postId = tonumber(payload and payload.postId)
    if not postId then
        return false, nil, 'invalid post id'
    end

    local postRow = RepoV2.PostsRepo.getById(postId)
    if not postRow then
        return false, nil, 'post not found'
    end
    local ownerId = postRow.player_id

    local visibleSourceIds = Server.Domain.TimelineService.buildTimelineSourceIds(playerId, 'all', nil)
    local canSeePost = false
    for i = 1, #visibleSourceIds do
        if visibleSourceIds[i] == ownerId then
            canSeePost = true
            break
        end
    end

    if not canSeePost then
        return false, nil, 'post not visible'
    end

    local stamp = payload and payload.stamp
    local message = payload and payload.message
    if (not stamp or tostring(stamp) == '') and (not message or tostring(message) == '') then
        return false, nil, 'empty reaction'
    end

    RepoV2.ReactionsRepo.createReaction(postId, playerId, stamp, message)
    Server.Domain.NotificationsService.notifyReactionSubscribers(postId, playerId, stamp, message)
    return true, { reacted = true }
end

-- リアクションを削除する。
-- 自分のリアクション、または自分の投稿への他人のリアクションのみ削除可能（DB側で權限制御）。
function ReactionsService.deleteReaction(playerId, payload)
    local reactionId = tonumber(payload and payload.reactionId)
    if not reactionId then
        return false, nil, 'invalid reaction id'
    end

    RepoV2.ReactionsRepo.deleteReactionByOwnerOrPostOwner(reactionId, playerId)
    return true, { deleted = true }
end

Server.Domain.ReactionsService = ReactionsService
