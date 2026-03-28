-- 近距離プレイヤーの検索・退出・定期通知ループを担当するサービス。
-- フレンド申請画面で展示する候補や、地図りフィルタの近距離环境内絞り込みも行う。
local Server = WAY.Server
Server.Domain = Server.Domain or {}

local Utils = Server.Utils
local Runtime = Server.State
local RepoV2 = Server.RepositoryV2
local NearbyService = {}

-- 当該プレイヤーの周囲にいる未フレンド・非グループ共有者の候補情報を返す。
-- 山同意プレイヤーのみ候補に含める。距離順にソートする。
function NearbyService.getNearbyCandidates(playerSource, playerId, payload)
    local radius = tonumber(payload.radius or Config.NearbyRadiusDefault or 100.0)
    local existing = Server.RequestHelpers.getOwnRelationMap(playerId)

    local ped = GetPlayerPed(playerSource)
    local myCoords = GetEntityCoords(ped)
    local candidates = {}
    local players = GetPlayers()

    for i = 1, #players do
        local targetSource = tonumber(players[i])
        if targetSource and targetSource ~= playerSource then
            local targetId = Utils.getIdentifier(targetSource)
            if not existing[targetId] then
                local tState = Runtime.players[targetId]
                local consented
                if tState and tState.consentKnown then
                    consented = tState.consent
                else
                    consented = RepoV2.PlayersRepo.hasConsent(targetId)
                    if tState then
                        tState.consent = consented
                        tState.consentKnown = true
                    end
                end

                if not consented then
                    goto continue_candidate
                end

                local targetPed = GetPlayerPed(targetSource)
                local coords = GetEntityCoords(targetPed)
                local distance = #(myCoords - coords)

                if distance <= radius then
                    candidates[#candidates + 1] = {
                        serverId = targetSource,
                        playerId = targetId,
                        displayName = Utils.safeName(targetSource),
                        distance = math.floor(distance),
                    }
                end

                ::continue_candidate::
            end
        end
    end

    table.sort(candidates, function(a, b) return a.distance < b.distance end)
    return { candidates = candidates }
end

-- 己の周囲の可視プレイヤー（フレンド・グループ共有メンバー）を返す。
-- 位置情報は visibility_service 経由で取得し、距離で絞り込みの上返す。
function NearbyService.getNearbyVisiblePlayers(playerSource, playerId, payload)
    local _ = playerSource
    local radius = tonumber((payload and payload.radius) or Config.NearbyRadiusDefault or 100.0)
    local myState = Server.RequestHelpers.getActiveState(playerId)
    if not myState or not myState.position then
        return { players = {} }
    end

    local visible = Server.Domain.VisibilityService.buildVisiblePlayers(playerId)
    local players = {}

    for i = 1, #visible do
        local row = visible[i]
        local targetState = Runtime.players[row.playerId]
        if targetState and targetState.source and row.x and row.y and row.z then
            local dx = (tonumber(myState.position.x) or 0) - (tonumber(row.x) or 0)
            local dy = (tonumber(myState.position.y) or 0) - (tonumber(row.y) or 0)
            local dz = (tonumber(myState.position.z) or 0) - (tonumber(row.z) or 0)
            local distance = math.sqrt((dx * dx) + (dy * dy) + (dz * dz))

            if distance <= radius then
                players[#players + 1] = {
                    playerId = row.playerId,
                    displayName = row.displayName,
                    distance = math.floor(distance),
                    relation = row.isFriend and 'friend' or 'group',
                }
            end
        end
    end

    table.sort(players, function(a, b) return a.distance < b.distance end)
    return { players = players }
end

-- フレンドまたはグループメンバーが指定半径内にいる場合、クールダウンを考慮してクライアントイベントで通知する単滎チック。
function NearbyService.runNearbyNotifyTick()
    if not Config.NearbyNotifyEnabled then
        return
    end

    local radius = tonumber(Config.NearbyRadiusDefault or 100.0)
    local cooldownMs = tonumber(Config.NearbyNotifyCooldownMs or 60000)
    local now = Utils.nowMs()

    for playerId, state in pairs(Runtime.players) do
        if state and state.source and state.consent and state.position then
            local friends = Server.Domain.FriendsService.getAcceptedFriendIds(playerId)
            for i = 1, #friends do
                local friendId = friends[i]
                local friendState = Runtime.players[friendId]

                if friendState and friendState.source and friendState.consent and friendState.position then
                    local myStatus = RepoV2.FriendsRepo.getDirectionalStatus(playerId, friendId)
                    local targetStatus = RepoV2.FriendsRepo.getDirectionalStatus(friendId, playerId)

                    if myStatus == 'accepted' and targetStatus == 'accepted' and myStatus ~= 'blocked' and targetStatus ~= 'blocked' then
                        local dx = state.position.x - friendState.position.x
                        local dy = state.position.y - friendState.position.y
                        local dz = state.position.z - friendState.position.z
                        local distance = math.sqrt((dx * dx) + (dy * dy) + (dz * dz))

                        if distance <= radius then
                            local key = playerId .. '|' .. friendId
                            local lastAt = Runtime.nearbyCooldowns[key] or 0
                            if now - lastAt >= cooldownMs then
                                Runtime.nearbyCooldowns[key] = now
                                TriggerClientEvent('whereareyou:client:friendNearby', state.source, {
                                    displayName = Utils.safeName(friendState.source),
                                    distance = math.floor(distance),
                                })
                            end
                        end
                    end
                end
            end
        end
    end
end

function NearbyService.startNearbyNotifyLoop()
    if Runtime.nearbyLoopStarted then
        return
    end

    Runtime.nearbyLoopStarted = true
    CreateThread(function()
        local intervalMs = tonumber(Config.NearbyNotifyIntervalMs or 10000) or 10000
        while true do
            NearbyService.runNearbyNotifyTick()
            Wait(intervalMs)
        end
    end)
end

Server.Domain.NearbyService = NearbyService
