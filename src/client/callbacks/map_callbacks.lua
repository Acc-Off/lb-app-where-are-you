-- マップ関連 NUIコールバック
-- UIからの地図データ取得リクエストを受け取り、Bridge.callServer 経由でサーバーへ中継する。
-- 登録コールバック: getFriendsMap / getNearbyVisiblePlayers
local Client = WAY.Client
local Bridge = Client.Bridge

-- 地図に表示するフレンド・グループメンバーの位置情報一覧を取得する。
RegisterNUICallback('getFriendsMap', function(_, cb)
    Bridge.callServer('getFriendsMap', {}, function(ok, data, err)
        cb({ ok = ok, data = data, error = err })
    end)
end)

-- 指定半径内にいる可視プレイヤー（フレンド・グループ共有メンバー）を取得する。
RegisterNUICallback('getNearbyVisiblePlayers', function(data, cb)
    Bridge.callServer('getNearbyVisiblePlayers', data or {}, function(ok, dataOut, err)
        cb({ ok = ok, data = dataOut, error = err })
    end)
end)
