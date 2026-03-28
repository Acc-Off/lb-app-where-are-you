-- グループ関連 NUIコールバック
-- UIからのグループ操作リクエストを受け取り、Bridge.callServer 経由でサーバーへ中継する。
-- 登録コールバック: joinGroup / leaveGroup / getMyGroups / setGroupGhostMode
local Client = WAY.Client
local Bridge = Client.Bridge

-- グループに参加する（存在しない場合は新規作成）。
RegisterNUICallback('joinGroup', function(data, cb)
    Bridge.callServer('joinGroup', data or {}, function(ok, dataOut, err)
        cb({ ok = ok, data = dataOut, error = err })
    end)
end)

-- グループから退出する（最後のメンバーが退出するとグループは削除される）。
RegisterNUICallback('leaveGroup', function(data, cb)
    Bridge.callServer('leaveGroup', data or {}, function(ok, dataOut, err)
        cb({ ok = ok, data = dataOut, error = err })
    end)
end)

-- 自分が参加中のグループ一覧（メンバー情報付き）を取得する。
RegisterNUICallback('getMyGroups', function(_, cb)
    Bridge.callServer('getMyGroups', {}, function(ok, data, err)
        cb({ ok = ok, data = data, error = err })
    end)
end)

-- 特定グループ内での自分のゴーストモードを設定する。
RegisterNUICallback('setGroupGhostMode', function(data, cb)
    Bridge.callServer('setGroupGhostMode', data or {}, function(ok, dataOut, err)
        cb({ ok = ok, data = dataOut, error = err })
    end)
end)
