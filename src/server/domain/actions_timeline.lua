-- タイムライン・リアクション関連アクションハンドラー定義ファイル。
-- Actionsトーブルにタイムライン取得・チェックイン・リアクション・削除の各ハンドラーを登録する。
local Server = WAY.Server
Server.ActionHandlers = Server.ActionHandlers or {}

local Actions = Server.ActionHandlers

-- TimelineService / ReactionsService はこのファイルより後にロードされるため、実行時に Server.Domain.* を参照する。

-- タイムライン投稿一覧をフィルタ付きで取得する。
Actions.getTimeline = function(_, playerId, payload)
    return true, Server.Domain.TimelineService.buildTimeline(playerId, payload)
end

-- 現在地チェックインを投稿する。
Actions.createCheckin = function(_, playerId, payload)
    return Server.Domain.TimelineService.createCheckin(playerId, payload)
end

-- 投稿にリアクションを付ける。
Actions.reactToPost = function(_, playerId, payload)
    return Server.Domain.ReactionsService.reactToPost(playerId, payload)
end

-- 自分の投稿を削除する。
Actions.deletePost = function(_, playerId, payload)
    return Server.Domain.TimelineService.deletePost(playerId, payload)
end

-- リアクションを削除する。
Actions.deleteReaction = function(_, playerId, payload)
    return Server.Domain.ReactionsService.deleteReaction(playerId, payload)
end
