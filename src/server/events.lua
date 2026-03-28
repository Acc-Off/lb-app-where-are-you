local Server = WAY.Server
local Const = Server.Const

-- 読み込み順の差異で Service が未初期化の場合に備え、都度参照する。
local function resolveService()
    local svc = WAY and WAY.Server and WAY.Server.Service
    if not svc then
        print('[whereareyou] Service is not initialized yet')
        return nil
    end
    return svc
end

-- UIからのRPC風リクエストを受け取り、レスポンスイベントで返す。
RegisterNetEvent('whereareyou:server:request', function(requestId, action, payload)
    local playerSource = source
    local Service = resolveService()
    if not Service or type(Service.handleRequest) ~= 'function' then
        TriggerClientEvent('whereareyou:client:response', playerSource, requestId, false, nil, 'service unavailable')
        return
    end
    local ok, data, err = Service.handleRequest(playerSource, action, payload)
    TriggerClientEvent('whereareyou:client:response', playerSource, requestId, ok, data, err)
end)

-- クライアントの定期座標送信をDBへ反映する。
RegisterNetEvent('whereareyou:server:updatePosition', function(position)
    local playerSource = source
    local Service = resolveService()
    if not Service or type(Service.handlePositionUpdate) ~= 'function' then
        return
    end
    Service.handlePositionUpdate(playerSource, position)
end)

-- プレイヤー離脱時に最終位置を永続化する。
AddEventHandler('playerDropped', function()
    local playerSource = source
    local Service = resolveService()
    if not Service or type(Service.handlePlayerDropped) ~= 'function' then
        return
    end
    Service.handlePlayerDropped(playerSource)
end)

-- リソース起動ログ。
AddEventHandler('onResourceStart', function(resource)
    if resource ~= Const.RESOURCE then
        return
    end

    local Service = resolveService()
    if not Service then
        print('[whereareyou] server started with missing Service')
        return
    end

    if type(Service.initializeRuntime) == 'function' then
        Service.initializeRuntime()
    end
    if type(Service.startNearbyNotifyLoop) == 'function' then
        Service.startNearbyNotifyLoop()
    end

    print('[whereareyou] server started')
end)

-- リソース停止時にキャッシュ中の最終位置を保存する。
AddEventHandler('onResourceStop', function(resource)
    if resource ~= Const.RESOURCE then
        return
    end

    local Service = resolveService()
    if not Service or type(Service.flushAllPositions) ~= 'function' then
        return
    end

    Service.flushAllPositions()
end)
