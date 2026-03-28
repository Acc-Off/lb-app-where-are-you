local Client = WAY.Client
Client.Bridge = Client.Bridge or {}

local Bridge = Client.Bridge
local State = Client.State

-- 現在のプレイヤー座標を取得する。
function Bridge.getCurrentPosition()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    return {
        x = coords.x,
        y = coords.y,
        z = coords.z,
        heading = GetEntityHeading(ped),
        speed = GetEntitySpeed(ped),
        updatedAt = GetGameTimer(),
    }
end

-- LB Phone の custom app message を送る。
function Bridge.sendAppMessage(action, data)
    exports['lb-phone']:SendCustomAppMessage(Config.Identifier, {
        action = action,
        data = data,
    })
end

-- サーバーへ requestId 付きでリクエストを送る。
function Bridge.callServer(action, payload, callback)
    State.requestId = State.requestId + 1
    local id = State.requestId
    State.pendingRequests[id] = callback
    TriggerServerEvent('whereareyou:server:request', id, action, payload or {})
end

-- 可能な場合のみ lb-phone 通知を送信する。
function Bridge.notify(title, content)
    local payload = {
        title = title,
        content = content,
    }

    -- 参照実装と同様に exports 経由を最優先で試す。
    local ok = pcall(function()
        exports['lb-phone']:SendNotification(payload)
    end)

    if ok then
        return
    end

    -- 互換フォールバック。
    if type(sendNotification) == 'function' then
        sendNotification(payload)
        return
    end

    -- 旧イベント互換がある環境向け。
    TriggerEvent('phone:sendNotification', payload)
end

-- RPCレスポンスを requestId で対応づけてコールバックへ返す。
function Bridge.handleServerResponse(serverRequestId, ok, data, err)
    local callback = State.pendingRequests[serverRequestId]
    if callback then
        State.pendingRequests[serverRequestId] = nil
        callback(ok, data, err)
    end
 end
