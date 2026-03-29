local Client = WAY.Client
Client.Sync = Client.Sync or {}

local Sync = Client.Sync
local State = Client.State
local Bridge = Client.Bridge
---@diagnostic disable-next-line: undefined-global
local locale = locale

-- 定期同期スレッドを開始する。
-- 座標送信は規約に同意済みの場合のみ行い、表示中のみUIへ現在地を反映する。
function Sync.startLoop()
    CreateThread(function()
        while true do
            -- 規約未同意の場合はサーバーへ位置情報を送信しない。
            if State.consentGiven then
                local selfPosition = Bridge.getCurrentPosition()
                TriggerServerEvent('whereareyou:server:updatePosition', selfPosition)

                if State.appIsOpen then
                    Bridge.sendAppMessage('selfPosition', selfPosition)
                end
            end

            Wait(Config.PositionPushIntervalMs or 2000)
        end
    end)

    CreateThread(function()
        while true do
            local enabled = Config.NearbyNotifyEnabled == true
            local intervalMs = tonumber(Config.NearbyNotifyIntervalMs or 10000) or 10000
            if not enabled then
                Wait(intervalMs)
                goto continue
            end

            Bridge.callServer('getNearbyVisiblePlayers', {
                radius = tonumber(Config.NearbyRadiusDefault or 100.0),
            }, function(ok, data)
                if not ok or not data or type(data.players) ~= 'table' then
                    return
                end

                local now = GetGameTimer()
                local cooldownMs = tonumber(Config.NearbyNotifyCooldownMs or 60000) or 60000

                for i = 1, #data.players do
                    local row = data.players[i]
                    local key = tostring(row.playerId)
                    local lastAt = State.nearbyNotifyCooldowns[key] or 0
                    if now - lastAt >= cooldownMs then
                        State.nearbyNotifyCooldowns[key] = now
                        local relationText = (row.relation == 'friend')
                            and locale('notify.nearby.relation_friend')
                            or locale('notify.nearby.relation_group_member')
                        local content = locale(
                            'notify.nearby.content_with_relation_distance',
                            tostring(row.displayName or row.playerId or locale('notify.nearby.player_default')),
                            tostring(tonumber(row.distance or 0) or 0),
                            relationText
                        )
                        Bridge.notify(locale('notify.title'), content)
                    end
                end
            end)

            Wait(intervalMs)
            ::continue::
        end
    end)
end
