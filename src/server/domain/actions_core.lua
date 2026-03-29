-- コアアクションハンドラー定義ファイル。
-- bootstrap / agreeConsent / setGhostMode / getFriendsMap / getFriendsList /
-- searchPlayers / getNearbyCandidates / getNearbyVisiblePlayers / updateAppSettings など、
-- 特定ドメインに属さない共通アクションをここに登録する。
local Server = WAY.Server
Server.ActionHandlers = Server.ActionHandlers or {}

local Actions = Server.ActionHandlers
local Const = Server.Const
local RepoV2 = Server.RepositoryV2

-- 各 DomainService はこのファイルより後にロードされるため、トップレベルでのキャプチャを行わず
-- 実行時に Server.Domain.* を参照する（前方参照 nil 防止）。

-- アプリ起動時の初期データを一括返却する。
-- プレイヤーがまだ登録されていない場合は最低限のデフォルト値を返す。
Actions.bootstrap = function(playerSource)
    local Helpers = Server.RequestHelpers
    local playerId, state = Helpers.ensureRuntimeState(playerSource)
    if not playerId then
        return true, {
            playerId = '',
            selfName = Server.Utils.safeName(playerSource),
            consentGiven = false,
            ghostMode = Const.GHOST_NORMAL,
            friends = {},
            pendingRequests = {},
            groups = {},
        }
    end

    Helpers.hydrateRuntimeState(state)
    local safeState = state or {}

    return true, {
        playerId = playerId,
        selfName = Server.Utils.safeName(playerSource),
        consentGiven = safeState.consent == true,
        ghostMode = safeState.ghostMode or Const.GHOST_NORMAL,
        friends = Server.Domain.FriendsService.buildFriendsList(playerId),
        pendingRequests = Server.Domain.FriendsService.buildPendingRequests(playerId),
        groups = Server.Domain.GroupsService.getMyGroups(playerId),
        ghostModeSettings = Server.Domain.SettingsService.buildGhostModeSettings(playerId, safeState),
        appSettings = Server.Domain.SettingsService.getBootstrapSettings(playerId),
    }
end

-- アプリのアンインストールを処理する。
-- クライアント側では onDelete コールバックで consentGiven が即 false になり送信が停止する。
-- サーバー側では agreed_at を NULL に戻すことで、再接続・再起動後も未同意状態を維持し、
-- 送信停止状態を永続化する。再インストール時は規約への再同意が必要になる。
Actions.uninstallApp = function(_, playerId)
    local Helpers = Server.RequestHelpers
    RepoV2.PlayersRepo.clearConsent(playerId)
    local _, state = Helpers.ensureRuntimeState(nil, playerId)
    if state then
        state.consentKnown = true
        state.consent = false
    end
    return true, { uninstalled = true }
end

-- 利用規約への同意を記録する。DB へ保存し、ランタイムキャッシュも即座に更新する。
Actions.agreeConsent = function(_, playerId)
    local Helpers = Server.RequestHelpers
    -- 同意フラグを DB に保存し、ランタイムキャッシュを更新する。
    RepoV2.PlayersRepo.setConsent(playerId)
    local _, state = Helpers.ensureRuntimeState(nil, playerId)
    if state then
        state.consentKnown = true
        state.consent = true
    end
    return true, { consentGiven = true }
end

-- ゴーストモードを変更する。
-- scope: 'global'（全体）/ 'friend'（フレンド向け）/ 'group'（グループ向け）の3種類。
-- freeze 時は freezeCoords を受け取り、偽装座標として保存する。
Actions.setGhostMode = function(playerSource, playerId, payload)
    local Helpers = Server.RequestHelpers
    local scope = tostring(payload.scope or 'global')
    local mode = tostring(payload.mode or Const.GHOST_NORMAL)
    local _, state = Helpers.ensureRuntimeState(playerSource, playerId)

    if scope == 'global' then
        -- グローバルゴーストモードを DB に保存し、キャッシュを更新する。
        local ghostMode = RepoV2.PlayersRepo.setGlobalGhostMode(playerId, mode)
        if state then
            state.ghostMode = ghostMode
        end
        return true, {
            ghostMode = ghostMode,
            ghostModeSettings = Server.Domain.SettingsService.buildGhostModeSettings(playerId, state),
        }
    end

    if scope == 'friend' then
        -- フレンド向けゴーストモードを DB に保存し、キャッシュを更新する。
        local friendMode = RepoV2.PlayersRepo.setFriendGhostMode(playerId, mode, payload.freezeCoords)
        if state then
            state.friendGhostMode = friendMode
            if friendMode == Const.GHOST_FREEZE and payload.freezeCoords then
                state.friendFrozenPosition = {
                    x = tonumber(payload.freezeCoords.x or 0),
                    y = tonumber(payload.freezeCoords.y or 0),
                    z = tonumber(payload.freezeCoords.z or 0),
                }
            else
                state.friendFrozenPosition = nil
            end
        end

        return true, {
            ghostMode = state and state.ghostMode or Const.GHOST_NORMAL,
            ghostModeSettings = Server.Domain.SettingsService.buildGhostModeSettings(playerId, state),
        }
    end

    if scope == 'group' then
        -- グループゴーストモードは GroupsService へ委譲する。
        local groupId = tonumber(payload.groupId)
        if not groupId then
            return false, nil, 'invalid group id'
        end

        local ok, _ = Server.Domain.GroupsService.setGroupGhostMode(playerId, groupId, mode, payload.freezeCoords)
        if not ok then
            return false, nil, 'invalid group mode'
        end

        return true, {
            ghostMode = state and state.ghostMode or Const.GHOST_NORMAL,
            ghostModeSettings = Server.Domain.SettingsService.buildGhostModeSettings(playerId, state),
        }
    end

    return false, nil, 'invalid scope'
end

-- 現在のゴーストモード設定（全スコープ）を返す。UI の設定画面表示に使用する。
Actions.getGhostModeSettings = function(_, playerId)
    return true, Server.Domain.SettingsService.buildGhostModeSettings(playerId, nil)
end

-- 地図タブ用に可視プレイヤー一覧（フレンド・グループメンバー）を返す。
Actions.getFriendsMap = function(_, playerId)
    return true, { friends = Server.Domain.VisibilityService.buildVisiblePlayers(playerId) }
end

-- フレンドタブ用にフレンド一覧（承認済み・ブロック中・申請待ち）を返す。
Actions.getFriendsList = function(_, playerId)
    return true, Server.Domain.FriendsService.getFriendsList(playerId)
end

-- 名前または ID でプレイヤーを検索する。フレンド申請画面の ID/名前検索欄に使用する。
Actions.searchPlayers = function(playerSource, playerId, payload)
    return true, Server.Domain.FriendsService.searchPlayers(playerSource, playerId, payload)
end

-- 指定半径内にいる未フレンドプレイヤー候補を返す。フレンド申請モーダルの「近くのプレイヤー」に使用する。
Actions.getNearbyCandidates = function(playerSource, playerId, payload)
    return true, Server.Domain.NearbyService.getNearbyCandidates(playerSource, playerId, payload)
end

-- 指定半径内にいる可視プレイヤー（フレンド・グループメンバー）を返す。地図の近距離フィルタに使用する。
Actions.getNearbyVisiblePlayers = function(_, playerId, payload)
    return true, Server.Domain.NearbyService.getNearbyVisiblePlayers(nil, playerId, payload)
end

-- 近距離通知の有効/無効・半径・チェック間隔などのアプリ設定を更新して DB に保存する。
Actions.updateAppSettings = function(_, playerId, payload)
    return Server.Domain.SettingsService.updateAppSettings(playerId, payload)
end
