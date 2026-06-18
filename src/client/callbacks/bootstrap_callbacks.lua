local Client = WAY.Client
local State = Client.State
local Bridge = Client.Bridge
local App = Client.App
local Sync = Client.Sync
---@diagnostic disable-next-line: undefined-global
local locale = locale

local function applyAppSettings(settings)
    if not settings then
        return
    end

    if settings.nearbyNotifyEnabled ~= nil then
        Config.NearbyNotifyEnabled = settings.nearbyNotifyEnabled == true
    end

    if settings.nearbyRadius ~= nil then
        Config.NearbyRadiusDefault = tonumber(settings.nearbyRadius) or Config.NearbyRadiusDefault
    end

    if settings.nearbyIntervalMs ~= nil then
        Config.NearbyNotifyIntervalMs = tonumber(settings.nearbyIntervalMs) or Config.NearbyNotifyIntervalMs
    end
end

-- 初期起動: lb-phone 起動待ち後にアプリ登録する。
-- ループ開始前にサーバーから同意状態を取得する。
-- これにより、既同意ユーザーはアプリを開く前からログイン直後に位置情報の送信が始まる。
-- （consentGiven の既定値は false のため、取得前はループが回っても送信は行われない）
CreateThread(function()
    while GetResourceState('lb-phone') ~= 'started' do
        Wait(500)
    end

    Wait(1000)
    App.addCustomApp()
    Sync.startLoop()

    -- 同意状態をサーバーから取得して consentGiven を確定させる。
    -- 既同意ユーザーはここで true になり、以降のループから送信が開始される。
    Bridge.callServer('bootstrap', {}, function(ok, data)
        if ok and data then
            State.consentGiven = data.consentGiven == true
        end
    end)
end)

-- lb-phone 再起動時の再登録。
AddEventHandler('onResourceStart', function(resource)
    if resource == 'lb-phone' then
        App.addCustomApp()
    end
end)

-- サーバー応答の受け口。
RegisterNetEvent('whereareyou:client:response', function(serverRequestId, ok, data, err)
    Bridge.handleServerResponse(serverRequestId, ok, data, err)
end)

-- 新規申請通知。
RegisterNetEvent('whereareyou:client:friendRequestIncoming', function()
    Bridge.notify(locale('notify.title'), locale('notify.friend_request_incoming'))

    if State.appIsOpen then
        Bridge.callServer('getFriendsList', {}, function(ok, data)
            if ok and data then
                Bridge.sendAppMessage('friendsList', data)
            end
        end)
    end
end)

-- 自分の申請が受諾された通知。
RegisterNetEvent('whereareyou:client:friendRequestAccepted', function(payload)
    local fromName = payload and payload.fromName or locale('notify.defaults.other_party')
    Bridge.notify(locale('notify.title'), locale('notify.friend_request_accepted', fromName))
end)

-- 近距離フレンド通知。
RegisterNetEvent('whereareyou:client:friendNearby', function(payload)
    local displayName = payload and payload.displayName or locale('notify.nearby.friend_default')
    local distance = payload and payload.distance or nil
    local suffix = distance and locale('notify.nearby.distance_suffix', tostring(distance)) or ''
    Bridge.notify(locale('notify.title'), locale('notify.nearby.content', displayName, suffix))
end)

-- リアクション受信通知。
RegisterNetEvent('whereareyou:client:reactionReceived', function(payload)
    local fromName = payload and payload.fromName or locale('notify.defaults.someone')
    local stamp = payload and payload.stamp or ''
    local message = payload and payload.message or ''

    local content = locale('notify.reaction_received_default', fromName)
    if stamp ~= '' and message ~= '' then
        content = ('%s %s'):format(stamp, message)
    elseif stamp ~= '' then
        content = stamp
    elseif message ~= '' then
        content = message
    end

    Bridge.notify(locale('notify.title'), content)
end)

-- 関係状態変更時の再同期。
RegisterNetEvent('whereareyou:client:friendsStateChanged', function()
    if not State.appIsOpen then
        return
    end

    Bridge.callServer('getFriendsList', {}, function(ok, data)
        if ok and data then
            Bridge.sendAppMessage('friendsList', data)
        end
    end)

    Bridge.callServer('getFriendsMap', {}, function(ok, data)
        if ok and data then
            Bridge.sendAppMessage('friendsMap', data)
        end
    end)
end)

RegisterNUICallback('getSelfPosition', function(_, cb)
    cb(Bridge.getCurrentPosition())
end)

RegisterNUICallback('getBootstrap', function(_, cb)
    Bridge.callServer('bootstrap', {}, function(ok, data, err)
        if ok and data then
            State.consentGiven = data.consentGiven == true
            applyAppSettings(data.appSettings)
            -- ox_lib のロケールデータを UI に渡す（NUI テキストの多言語対応）。
            -- onUse の sendAppMessage('bootstrap') 経路（app.lua）と揃える。
            -- これが無いと UI 起動時の getBootstrap 経路では locale が空になり、
            -- 全テキストが翻訳キーのまま表示される。
            data.locales = lib.getLocales()
        end

        cb({ ok = ok, data = data, error = err })
    end)
end)

RegisterNUICallback('agreeConsent', function(_, cb)
    Bridge.callServer('agreeConsent', {}, function(ok, data, err)
        if ok then
            State.consentGiven = true
        end

        cb({ ok = ok, data = data, error = err })
    end)
end)

RegisterNUICallback('updateAppSettings', function(data, cb)
    Bridge.callServer('updateAppSettings', data or {}, function(ok, dataOut, err)
        if ok and dataOut and dataOut.settings then
            applyAppSettings(dataOut.settings)
        end

        cb({ ok = ok, data = dataOut, error = err })
    end)
end)

RegisterNUICallback('setGhostMode', function(data, cb)
    Bridge.callServer('setGhostMode', data or {}, function(ok, response, err)
        cb({ ok = ok, data = response, error = err })
    end)
end)
