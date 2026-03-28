-- フレンド関連 NUIコールバック
-- UIからのフレンド操作リクエストを受け取り、Bridge.callServer 経由でサーバーへ中継する。
-- 登録コールバック: getFriendsList / searchPlayers / getNearbyCandidates /
--   sendFriendRequest / respondFriendRequest / getFriendDetail /
--   blockFriend / unblockFriend / removeFriend
local Client = WAY.Client
local Bridge = Client.Bridge

-- 受理済みフレンド一覧を取得する。
RegisterNUICallback('getFriendsList', function(_, cb)
    Bridge.callServer('getFriendsList', {}, function(ok, data, err)
        cb({ ok = ok, data = data, error = err })
    end)
end)

-- プレイヤー名・IDでフレンド候補を検索する。
RegisterNUICallback('searchPlayers', function(data, cb)
    Bridge.callServer('searchPlayers', data or {}, function(ok, dataOut, err)
        cb({ ok = ok, data = dataOut, error = err })
    end)
end)

-- 指定半径内にいる未フレンドのプレイヤー候補を取得する。
RegisterNUICallback('getNearbyCandidates', function(data, cb)
    Bridge.callServer('getNearbyCandidates', data or {}, function(ok, dataOut, err)
        cb({ ok = ok, data = dataOut, error = err })
    end)
end)

-- 指定プレイヤーにフレンド申請を送信する。
RegisterNUICallback('sendFriendRequest', function(data, cb)
    Bridge.callServer('sendFriendRequest', data or {}, function(ok, dataOut, err)
        cb({ ok = ok, data = dataOut, error = err })
    end)
end)

-- 受信したフレンド申請に承認 or 辞退で応答する。
RegisterNUICallback('respondFriendRequest', function(data, cb)
    Bridge.callServer('respondFriendRequest', data or {}, function(ok, dataOut, err)
        cb({ ok = ok, data = dataOut, error = err })
    end)
end)

-- 特定フレンドの詳細情報（位置・ゴーストモード等）を取得する。
RegisterNUICallback('getFriendDetail', function(data, cb)
    Bridge.callServer('getFriendDetail', data or {}, function(ok, dataOut, err)
        cb({ ok = ok, data = dataOut, error = err })
    end)
end)

-- 指定プレイヤーをブロックする（互いの位置情報が非表示になる）。
RegisterNUICallback('blockFriend', function(data, cb)
    Bridge.callServer('blockFriend', data or {}, function(ok, dataOut, err)
        cb({ ok = ok, data = dataOut, error = err })
    end)
end)

-- ブロックを解除してフレンド関係を復元する。
RegisterNUICallback('unblockFriend', function(data, cb)
    Bridge.callServer('unblockFriend', data or {}, function(ok, dataOut, err)
        cb({ ok = ok, data = dataOut, error = err })
    end)
end)

-- フレンドを削除する（双方の関係が解除される）。
RegisterNUICallback('removeFriend', function(data, cb)
    Bridge.callServer('removeFriend', data or {}, function(ok, dataOut, err)
        cb({ ok = ok, data = dataOut, error = err })
    end)
end)
