-- アカウント関連アクションハンドラー定義ファイル。
-- Actionsトーブルの deleteAccount ハンドラーを登録する。
local Server = WAY.Server
Server.ActionHandlers = Server.ActionHandlers or {}

local Actions = Server.ActionHandlers

-- AccountService はこのファイルより後にロードされるため、実行時に Server.Domain.* を参照する。

-- アカウントを退会する（全データ削除）。
Actions.deleteAccount = function(_, playerId)
    return Server.Domain.AccountService.deleteAccount(playerId)
end
