-- リクエストディスパッチャ。
-- NUI から届いたアクション文字列をもとに Actionsテーブルの嫸応するハンドラーを呼び出し、
-- 結果をクライアントへ返す。
local Server = WAY.Server
Server.ActionHandlers = Server.ActionHandlers or {}

local Service = Server.Service
local Utils = Server.Utils
local Handlers = Server.ActionHandlers

-- ドメイン単位で登録されたハンドラへ振り分ける。
function Service.handleRequest(playerSource, action, payload)
    local playerId = Utils.getIdentifier(playerSource)
    payload = payload or {}

    if not playerId then
        return false, nil, 'invalid player'
    end

    local handler = Handlers[action]
    if not handler then
        return false, nil, 'unknown action'
    end

    return handler(playerSource, playerId, payload)
end
