-- フレンド関連アクションハンドラー定義ファイル。
-- Actionsトーブルにフレンド申請・応答・詳細取得・ブロック・解除・削除の各ハンドラーを登録する。
local Server = WAY.Server
Server.ActionHandlers = Server.ActionHandlers or {}

local Actions = Server.ActionHandlers

-- FriendsService はこのファイルより後にロードされるため、ローカル変数へのキャプチャを避け
-- 実行時に Server.Domain.* を参照する。

-- 指定プレイヤーへフレンド申請を送信する。
Actions.sendFriendRequest = function(playerSource, playerId, payload)
    return Server.Domain.FriendsService.sendFriendRequest(playerSource, playerId, payload)
end

-- 受信したフレンド申請に承認 / 辞退で応答する。
Actions.respondFriendRequest = function(_, playerId, payload)
    return Server.Domain.FriendsService.respondFriendRequest(playerId, payload)
end

-- 特定フレンドの詳細情報を取得する。
Actions.getFriendDetail = function(_, playerId, payload)
    local targetPlayerId = tostring(payload.playerId or '')
    if targetPlayerId == '' then
        return false, nil, 'invalid target'
    end
    return Server.Domain.FriendsService.getFriendDetail(playerId, targetPlayerId)
end

-- 指定プレイヤーをブロックする。
Actions.blockFriend = function(_, playerId, payload)
    return Server.Domain.FriendsService.blockFriend(playerId, payload)
end

-- ブロックを解除する。
Actions.unblockFriend = function(_, playerId, payload)
    return Server.Domain.FriendsService.unblockFriend(playerId, payload)
end

-- フレンドを削除する。
Actions.removeFriend = function(_, playerId, payload)
    return Server.Domain.FriendsService.removeFriend(playerId, payload)
end
