-- ============================================================================
-- service_core.lua
-- WhereAreYou サーバーライフサイクル管理
--
-- 責務: リソース開始/停止・プレイヤー接続/切断・位置更新のみ。
-- ビジネスロジックは server/domain/*_service.lua へ移行済み。
-- ============================================================================
local Server = WAY.Server
Server.Service = Server.Service or {}

local Service = Server.Service
local Utils = Server.Utils
local Const = Server.Const
local Runtime = Server.State
local RepoV2 = Server.RepositoryV2

-- ============================================================================
-- プライベートヘルパー（ライフサイクル関数専用）
-- ============================================================================

-- playerId/source からランタイム状態を取得または新規作成する。
local function ensurePlayerState(playerSource, playerId)
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

-- 同意状態とゴーストモードをランタイムキャッシュへ読み込む。
local function hydrateState(state)
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
    state.friendGhostMode = (row.friend_ghost_mode == Const.GHOST_FREEZE or row.friend_ghost_mode == Const.GHOST_BLUR)
        and row.friend_ghost_mode or Const.GHOST_NORMAL

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

-- ============================================================================
-- ライフサイクルハンドラ
-- ============================================================================

-- クライアントから定期的に送られる座標を受け付け、ランタイムキャッシュを更新する。
function Service.handlePositionUpdate(playerSource, position)
    local playerId, state = ensurePlayerState(playerSource)
    if not playerId or not state then
        return
    end

    hydrateState(state)
    if not state.consent then
        return
    end

    position = position or {}
    state.position = {
        x = tonumber(position.x or 0),
        y = tonumber(position.y or 0),
        z = tonumber(position.z or 0),
        heading = tonumber(position.heading or 0),
        speed = tonumber(position.speed or 0),
    }
    state.updatedAt = Utils.nowMs()
end

-- プレイヤー切断時に最終位置を DB へ永続化し、ランタイムキャッシュを解放する。
function Service.handlePlayerDropped(playerSource)
    local playerId = Runtime.sourceToPlayerId[playerSource] or Utils.getIdentifier(playerSource)
    if not playerId then
        return
    end

    local state = Runtime.players[playerId]
    if state then
        hydrateState(state)

        -- 表示名キャッシュを更新し、DB に保存する。
        local displayName = state.displayName
        if displayName and displayName ~= '' then
            Runtime.lastKnownNames[playerId] = displayName
            RepoV2.PlayersRepo.saveProfileName(playerId, displayName)
        end

        -- 切断前の最終既知状態をメモリキャッシュに保存する（オフライン表示で参照）。
        if state.position then
            Runtime.playerLastKnown[playerId] = {
                ghostMode = state.ghostMode or Const.GHOST_NORMAL,
                x = state.position.x,
                y = state.position.y,
                z = state.position.z,
            }
        end

        -- 最終位置を DB へフラッシュする。
        if state.consent and state.position then
            RepoV2.PlayersRepo.upsertPosition(playerId, state.position, state.ghostMode or Const.GHOST_NORMAL)
        end
    end

    Runtime.sourceToPlayerId[playerSource] = nil
    Runtime.players[playerId] = nil
end

-- リソース起動時にオンラインプレイヤーの状態キャッシュを初期化し、
-- グループデータをメモリへ一括ロードする。
function Service.initializeRuntime()
    -- 起動時にすでにオンラインのプレイヤーを初期化する。
    local players = GetPlayers()
    for i = 1, #players do
        local playerSource = tonumber(players[i])
        if playerSource then
            local playerId, state = ensurePlayerState(playerSource)
            hydrateState(state)

            if playerId and state and state.displayName then
                Runtime.lastKnownNames[playerId] = state.displayName
                RepoV2.PlayersRepo.saveProfileName(playerId, state.displayName)
            end
        end
    end

    -- 再起動時の重複を防ぐため、起動時一括ロード対象キャッシュを初期化する。
    Runtime.groups = {}
    Runtime.playerGroups = {}
    Runtime.friendRelations = {}
    Runtime.playerLastKnown = {}

    -- グループデータをメモリロードする。
    local groups = RepoV2.GroupsRepo.fetchAllGroupsForInit()

    for i = 1, #groups do
        local group = groups[i]
        Runtime.groups[group.id] = {
            id = group.id,
            name = group.name,
            password = group.password,
            created_at = group.created_at,
            members = {},
        }
    end

    -- プレイヤーごとのグループ情報をロードする。
    local allPlayerGroups = RepoV2.GroupsRepo.fetchAllMemberGroupsForInit()

    for i = 1, #allPlayerGroups do
        local row = allPlayerGroups[i]
        if not Runtime.playerGroups[row.player_id] then
            Runtime.playerGroups[row.player_id] = {}
        end
        table.insert(Runtime.playerGroups[row.player_id], {
            id = row.id,
            name = row.name,
            ghost_mode = row.ghost_mode,
            frozen_x = row.frozen_x,
            frozen_y = row.frozen_y,
            frozen_z = row.frozen_z,
            joined_at = row.joined_at,
        })

        if Runtime.groups[row.id] then
            Runtime.groups[row.id].members = Runtime.groups[row.id].members or {}
            Runtime.groups[row.id].members[row.player_id] = {
                ghost_mode = row.ghost_mode,
                frozen_x = row.frozen_x,
                frozen_y = row.frozen_y,
                frozen_z = row.frozen_z,
            }
        end
    end

    -- オフライン表示で使う最終既知状態を起動時に一括ロードする。
    local allMemberIds = {}
    local seenMemberIds = {}
    for i = 1, #allPlayerGroups do
        local pid = allPlayerGroups[i].player_id
        if not seenMemberIds[pid] then
            seenMemberIds[pid] = true
            allMemberIds[#allMemberIds + 1] = pid
        end
    end

    local playerRows = RepoV2.PlayersRepo.getByPlayerIds(allMemberIds)
    for i = 1, #playerRows do
        local row = playerRows[i]
        Runtime.playerLastKnown[row.player_id] = {
            ghostMode = row.ghost_mode or Const.GHOST_NORMAL,
            x = row.x,
            y = row.y,
            z = row.z,
        }
        -- オフライン時の表示名に市民IDが使われないよう、起動時に lastKnownNames を一緒にロードする。
        if row.display_name and row.display_name ~= '' then
            Runtime.lastKnownNames[row.player_id] = row.display_name
        end
    end

    -- フレンド関係を起動時に一括ロードして双方向マップを構築する。
    local allFriendRows = RepoV2.FriendsRepo.fetchAllForInit()
    for i = 1, #allFriendRows do
        local row = allFriendRows[i]
        Runtime.friendRelations[row.player_id] = Runtime.friendRelations[row.player_id] or {
            outgoing = {},
            incoming = {},
        }
        Runtime.friendRelations[row.player_id].outgoing[row.friend_id] = row.status

        Runtime.friendRelations[row.friend_id] = Runtime.friendRelations[row.friend_id] or {
            outgoing = {},
            incoming = {},
        }
        Runtime.friendRelations[row.friend_id].incoming[row.player_id] = row.status
    end
end

-- 近距離通知ループを起動する。実処理は NearbyService へ委譲する。
function Service.startNearbyNotifyLoop()
    -- NearbyService は service_core より後にロードされる可能性があるため遅延参照する。
    local ns = Server.Domain and Server.Domain.NearbyService
    if ns and type(ns.startNearbyNotifyLoop) == 'function' then
        ns.startNearbyNotifyLoop()
    end
end

-- リソース停止時にオンライン中プレイヤーの最終位置を一括保存する。
function Service.flushAllPositions()
    for playerId, state in pairs(Runtime.players) do
        if state and state.consent and state.position then
            RepoV2.PlayersRepo.upsertPosition(playerId, state.position, state.ghostMode or Const.GHOST_NORMAL)
        end
    end
end
