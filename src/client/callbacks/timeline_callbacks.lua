-- タイムライン関連 NUIコールバック
-- UIからのタイムライン操作リクエストを受け取り、Bridge.callServer 経由でサーバーへ中継する。
-- 登録コールバック: getTimeline / createCheckin / reactToPost / deletePost / deleteReaction
local Client = WAY.Client
local Bridge = Client.Bridge

-- タイムライン投稿一覧をフィルタ条件付きで取得する。
RegisterNUICallback('getTimeline', function(data, cb)
    Bridge.callServer('getTimeline', data or {}, function(ok, dataOut, err)
        cb({ ok = ok, data = dataOut, error = err })
    end)
end)

-- 現在地チェックインを投稿する。
RegisterNUICallback('createCheckin', function(data, cb)
    Bridge.callServer('createCheckin', data or {}, function(ok, dataOut, err)
        cb({ ok = ok, data = dataOut, error = err })
    end)
end)

-- 投稿にスタンプ・ひとことリアクションを付ける。
RegisterNUICallback('reactToPost', function(data, cb)
    Bridge.callServer('reactToPost', data or {}, function(ok, dataOut, err)
        cb({ ok = ok, data = dataOut, error = err })
    end)
end)

-- 自分の投稿を削除する。
RegisterNUICallback('deletePost', function(data, cb)
    Bridge.callServer('deletePost', data or {}, function(ok, dataOut, err)
        cb({ ok = ok, data = dataOut, error = err })
    end)
end)

-- 自分のリアクション（または自分の投稿へのリアクション）を削除する。
RegisterNUICallback('deleteReaction', function(data, cb)
    Bridge.callServer('deleteReaction', data or {}, function(ok, dataOut, err)
        cb({ ok = ok, data = dataOut, error = err })
    end)
end)
