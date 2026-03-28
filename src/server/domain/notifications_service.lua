-- クライアントへのリアルタイム通知履行処理を担当するサービス。
-- フレンド申請 / 承認 / 状態変化 / リアクションを对象プレイヤーのクライアントに直接送信する。
local Server = WAY.Server
Server.Domain = Server.Domain or {}

local Utils = Server.Utils
local NotificationsService = {}

-- フレンド申請を受けたプレイヤーに通知する。
-- オンラインの場合のみクライアントイベントを発火する。
function NotificationsService.notifyPendingRequest(targetPlayerId)
    local target = Utils.getOnlinePlayerMap()[targetPlayerId]
    if target then
        TriggerClientEvent('whereareyou:client:friendRequestIncoming', target.source)
    end
end

-- 申請を承認したプレイヤー（承認元）に対して、承認した相手の名前付きで通知する。
function NotificationsService.notifyRequestAccepted(targetPlayerId, accepterPlayerId)
    local onlineMap = Utils.getOnlinePlayerMap()
    local target = onlineMap[targetPlayerId]
    local accepter = onlineMap[accepterPlayerId]

    if target then
        TriggerClientEvent('whereareyou:client:friendRequestAccepted', target.source, {
            fromName = accepter and accepter.name or accepterPlayerId,
        })
    end
end

-- フレンド一覧の変化（承認・削除等）をプレイヤーに通知し、メモリ最新化を促す。
function NotificationsService.notifyFriendsStateChanged(playerId)
    local target = Utils.getOnlinePlayerMap()[playerId]
    if target then
        TriggerClientEvent('whereareyou:client:friendsStateChanged', target.source)
    end
end

-- リアクションを購読する全プレイヤーに通知する。
-- 購読対象: 投稿者と成行済みリアクター全員（リアクター自身およびオフライン履年不要）。
function NotificationsService.notifyReactionSubscribers(postId, actorPlayerId, stamp, message)
    local RepoV2 = Server.RepositoryV2
    local PostsRepo = RepoV2.PostsRepo
    local ReactionsRepo = RepoV2.ReactionsRepo

    -- getPostOwner は存在しないため getById で投稿者 ID を取得する
    local postRow = PostsRepo.getById(postId)
    local ownerId = postRow and postRow.player_id
    if not ownerId then
        return
    end

    local onlineMap = Utils.getOnlinePlayerMap()
    local actor = onlineMap[actorPlayerId]
    local actorName = actor and actor.name or actorPlayerId

    local subscriberIds = { [ownerId] = true }
    local reactorIds = ReactionsRepo.listReactionPlayerIds(postId)
    for i = 1, #reactorIds do
        subscriberIds[reactorIds[i]] = true
    end
    subscriberIds[actorPlayerId] = nil

    for targetPlayerId, _ in pairs(subscriberIds) do
        local target = onlineMap[targetPlayerId]
        if target and target.source then
            TriggerClientEvent('whereareyou:client:reactionReceived', target.source, {
                fromName = actorName,
                stamp = stamp and tostring(stamp) or '',
                message = message and tostring(message) or '',
            })
        end
    end
end

Server.Domain.NotificationsService = NotificationsService
