local Server = WAY.Server
Server.Utils = Server.Utils or {}

local Utils = Server.Utils

local qbCoreObject = nil
local esxObject = nil

-- qb-core の CoreObject を遅延取得してキャッシュする。
local function getQBCore()
    if qbCoreObject ~= nil then
        return qbCoreObject
    end

    if GetResourceState('qb-core') ~= 'started' then
        return nil
    end

    local ok, core = pcall(function()
        return exports['qb-core']:GetCoreObject()
    end)

    if ok then
        qbCoreObject = core
        return qbCoreObject
    end

    return nil
end

-- es_extended の shared object を遅延取得してキャッシュする。
local function getESX()
    if esxObject ~= nil then
        return esxObject
    end

    if GetResourceState('es_extended') ~= 'started' then
        return nil
    end

    local ok, esx = pcall(function()
        return exports['es_extended']:getSharedObject()
    end)

    if ok then
        esxObject = esx
        return esxObject
    end

    return nil
end

-- プレイヤーの永続識別子を取得する。
-- 優先順: citizenid(QBCore/Qbox) -> ESX identifier -> license。
function Utils.getIdentifier(playerSource)
    local sourceNumber = tonumber(playerSource)
    if not sourceNumber then
        return nil
    end

    -- Qbox は citizenid を内部IDとして利用する。
    if GetResourceState('qbx_core') == 'started' then
        local ok, player = pcall(function()
            return exports.qbx_core:GetPlayer(sourceNumber)
        end)

        local citizenId = ok and player and player.PlayerData and player.PlayerData.citizenid or nil
        if citizenId and citizenId ~= '' then
            return citizenId
        end
    end

    -- qb-core も citizenid を内部IDとして利用する。
    local qb = getQBCore()
    if qb and qb.Functions and qb.Functions.GetPlayer then
        local player = qb.Functions.GetPlayer(sourceNumber)
        local citizenId = player and player.PlayerData and player.PlayerData.citizenid or nil
        if citizenId and citizenId ~= '' then
            return citizenId
        end
    end

    -- ESX は identifier を利用する。
    local esx = getESX()
    if esx and esx.GetPlayerFromId then
        local xPlayer = esx.GetPlayerFromId(sourceNumber)
        local identifier = xPlayer and xPlayer.identifier or nil
        if identifier and identifier ~= '' then
            return identifier
        end
    end

    -- 最後のフォールバックとして FiveM の識別子配列を使う。
    local identifiers = GetPlayerIdentifiers(sourceNumber)
    for i = 1, #identifiers do
        local identifier = identifiers[i]
        if identifier:find('license:', 1, true) == 1 then
            return identifier
        end
    end

    return identifiers[1]
end

-- UI向けにミリ秒タイムスタンプを返す。
function Utils.nowMs()
    return os.time() * 1000
end

-- プレイヤー名取得の失敗時にフォールバック名を返す。
function Utils.safeName(playerSource)
    return GetPlayerName(playerSource) or ('Player ' .. tostring(playerSource))
end

-- あいまいモード用の座標丸めを行う。
-- グリッドサイズは Config で調整可能にしている。
function Utils.blurCoord(value)
    local grid = Config.BlurGridSize or 80.0
    return math.floor((value / grid) + 0.5) * grid
end

-- 速度から移動ステータスを判定する。
-- UIはこの文字列をそのまま表示ロジックに利用する。
function Utils.classifyMoveStatus(speed)
    if speed >= (Config.VehicleSpeedThreshold or 8.0) then
        return 'vehicle'
    end

    if speed >= (Config.WalkSpeedThreshold or 1.2) then
        return 'walk'
    end

    return 'idle'
end

-- プレイヤーIDの組み合わせを順序不問で同一キー化する。
function Utils.getPairKey(a, b)
    if a < b then
        return a .. '|' .. b
    end

    return b .. '|' .. a
end

-- 現在オンラインのプレイヤーを識別子キーで引ける辞書に変換する。
function Utils.getOnlinePlayerMap()
    local players = GetPlayers()
    local byIdentifier = {}

    for i = 1, #players do
        local playerSource = tonumber(players[i])
        local identifier = playerSource and Utils.getIdentifier(playerSource)

        if identifier then
            byIdentifier[identifier] = {
                source = playerSource,
                name = Utils.safeName(playerSource),
            }
        end
    end

    return byIdentifier
end
