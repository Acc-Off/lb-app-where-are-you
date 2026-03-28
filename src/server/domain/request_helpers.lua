-- ============================================================================
-- request_helpers.lua
-- リクエスト共通ヘルパー
--
-- Action ハンドラ全体で共有される補助関数群。
-- DB アクセスの薄いラッパ・ランタイムキャッシュ操作・名前解決などを提供する。
-- ============================================================================
local Server = WAY.Server
Server.ActionHandlers = Server.ActionHandlers or {}
Server.RequestHelpers = Server.RequestHelpers or {}

local Helpers = Server.RequestHelpers
local RepoV2 = Server.RepositoryV2
local Runtime = Server.State
local Utils = Server.Utils
local Const = Server.Const

local function ensureRelationEntry(playerId)
    Runtime.friendRelations[playerId] = Runtime.friendRelations[playerId] or {
        outgoing = {},
        incoming = {},
    }
    return Runtime.friendRelations[playerId]
end

-- player_id → friend_id 方向のステータスを 1 件取得するラッパ。
function Helpers.getDirectionalStatus(playerId, friendId)
    local rel = Runtime.friendRelations[playerId]
    if rel and rel.outgoing and rel.outgoing[friendId] ~= nil then
        return rel.outgoing[friendId]
    end

    local status = RepoV2.FriendsRepo.getDirectionalStatus(playerId, friendId)
    if status ~= nil then
        local mine = ensureRelationEntry(playerId)
        local other = ensureRelationEntry(friendId)
        mine.outgoing[friendId] = status
        other.incoming[playerId] = status
    end

    return status
end

-- player_id → friend_id 方向のレコードを INSERT/UPDATE するラッパ。
function Helpers.upsertDirectionalStatus(playerId, friendId, status)
    local mine = ensureRelationEntry(playerId)
    local other = ensureRelationEntry(friendId)
    mine.outgoing[friendId] = status
    other.incoming[playerId] = status

    RepoV2.FriendsRepo.upsertDirectionalStatus(playerId, friendId, status)
end

-- 自分が起点の全フレンドレコードを { [friend_id] = status } マップで返す。
-- フレンドステータスの判定・フィルタリングに広く使用する。
function Helpers.getOwnRelationMap(playerId)
    local map = {}

    local rel = Runtime.friendRelations[playerId]
    if rel and rel.outgoing then
        for friendId, status in pairs(rel.outgoing) do
            map[friendId] = status
        end
        return map
    end

    local rows = RepoV2.FriendsRepo.listOutgoingByPlayerId(playerId)
    for i = 1, #rows do
        local row = rows[i]
        map[row.friend_id] = row.status

        local mine = ensureRelationEntry(playerId)
        local other = ensureRelationEntry(row.friend_id)
        mine.outgoing[row.friend_id] = row.status
        other.incoming[playerId] = row.status
    end

    return map
end

-- プレイヤーの表示名を優先順位に従って解決する。
-- 優先順: リアルタイム名（オンライン） > メモリキャッシュ > DB 取得名 > playerId フォールバック
function Helpers.resolveDisplayName(playerId, profileNameMap)
    local state = Runtime.players[playerId]
    if state and state.source and state.displayName and state.displayName ~= '' then
        return state.displayName
    end

    local cached = Runtime.lastKnownNames[playerId]
    if cached and cached ~= '' then
        return cached
    end

    if profileNameMap and profileNameMap[playerId] and profileNameMap[playerId] ~= '' then
        return profileNameMap[playerId]
    end

    return playerId
end

-- source / playerId からランタイム状態を取得または初期化する。
-- 初回接続時は空の状態テーブルを作成し、メモリキャッシュに登録する。
function Helpers.ensureRuntimeState(playerSource, playerId)
    local resolvedPlayerId = playerId or Utils.getIdentifier(playerSource)
    if not resolvedPlayerId then
        return nil, nil
    end

    local state = Runtime.players[resolvedPlayerId]
    if not state then
        state = {
            playerId = resolvedPlayerId,
            source = playerSource,
            displayName = playerSource and Utils.safeName(playerSource) or nil,
            consentKnown = false,
            consent = false,
            ghostMode = Const.GHOST_NORMAL,
            friendGhostMode = Const.GHOST_NORMAL,
            friendFrozenPosition = nil,
            position = nil,
            updatedAt = 0,
        }
        Runtime.players[resolvedPlayerId] = state
    end

    if playerSource then
        state.source = playerSource
        state.displayName = Utils.safeName(playerSource)
        Runtime.lastKnownNames[resolvedPlayerId] = state.displayName
        Runtime.sourceToPlayerId[playerSource] = resolvedPlayerId
    end

    return resolvedPlayerId, state
end

-- ランタイム状態に同意フラグ・ゴーストモードを DB から読み込む。
-- 一度取得済みの項目は再取得しない（consentKnown フラグで管理）。
function Helpers.hydrateRuntimeState(state)
    if not state then
        return
    end

    if not state.consentKnown then
        state.consent = RepoV2.PlayersRepo.hasConsent(state.playerId)
        state.consentKnown = true
    end

    if state.ghostMode and state.friendGhostMode then
        return
    end

    local row = RepoV2.PlayersRepo.getByPlayerId(state.playerId)
    if not row then
        state.ghostMode = state.ghostMode or Const.GHOST_NORMAL
        state.friendGhostMode = state.friendGhostMode or Const.GHOST_NORMAL
        return
    end

    state.ghostMode = (row.ghost_mode == Const.GHOST_OFF) and Const.GHOST_OFF or Const.GHOST_NORMAL
    state.friendGhostMode = (row.friend_ghost_mode == Const.GHOST_FREEZE or row.friend_ghost_mode == Const.GHOST_BLUR) and row.friend_ghost_mode or Const.GHOST_NORMAL

    if row.friend_frozen_x and row.friend_frozen_y and row.friend_frozen_z then
        state.friendFrozenPosition = {
            x = tonumber(row.friend_frozen_x),
            y = tonumber(row.friend_frozen_y),
            z = tonumber(row.friend_frozen_z),
        }
    else
        state.friendFrozenPosition = nil
    end
end

-- オンライン中かつ同意済み・位置あり のランタイム状態を返す。
-- 条件を満たさない場合は nil を返す（可視性計算・位置取得の事前検証に使用）。
function Helpers.getActiveState(playerId)
    local state = Runtime.players[playerId]
    if not state or not state.source then
        return nil
    end

    Helpers.hydrateRuntimeState(state)
    if not state.consent or not state.position then
        return nil
    end

    return state
end
