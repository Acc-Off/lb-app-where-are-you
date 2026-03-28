-- アカウント関連 NUIコールバック
-- UIからのアカウント操作リクエストを受け取り、Bridge.callServer 経由でサーバーへ中継する。
-- 登録コールバック: deleteAccount
local Client = WAY.Client
local Bridge = Client.Bridge

-- アカウントを退会する（全投稿・フレンド・グループが削除される）。
RegisterNUICallback('deleteAccount', function(_, cb)
    Bridge.callServer('deleteAccount', {}, function(ok, dataOut, err)
        cb({ ok = ok, data = dataOut, error = err })
    end)
end)
