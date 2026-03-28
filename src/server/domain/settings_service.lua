local Server = WAY.Server
Server.Domain = Server.Domain or {}

local RepoV2 = Server.RepositoryV2
local SettingsService = {}

function SettingsService.updateAppSettings(playerId, payload)
    local settings = RepoV2.SettingsRepo.upsertAppSettings(playerId, payload or {})
    return true, { settings = settings }
end

function SettingsService.getBootstrapSettings(playerId)
    return RepoV2.SettingsRepo.getAppSettings(playerId)
end

-- ゴーストモード設定をまとめて返す（グローバル・フレンド・グループ別）。
-- state を渡すとキャッシュ値を優先し、nil の場合は DB から取得する。
function SettingsService.buildGhostModeSettings(playerId, state)
    local Const = Server.Const
    local Runtime = Server.State
    local row = RepoV2.PlayersRepo.getByPlayerId(playerId)

    local globalMode
    local friendMode
    if state then
        globalMode = state.ghostMode or Const.GHOST_NORMAL
        friendMode = state.friendGhostMode or Const.GHOST_NORMAL
    elseif row then
        globalMode = (row.ghost_mode == Const.GHOST_OFF) and Const.GHOST_OFF or Const.GHOST_NORMAL
        friendMode = (row.friend_ghost_mode == Const.GHOST_FREEZE or row.friend_ghost_mode == Const.GHOST_BLUR) and row.friend_ghost_mode or Const.GHOST_NORMAL
    else
        globalMode = Const.GHOST_NORMAL
        friendMode = Const.GHOST_NORMAL
    end

    local groupSettings = {}
    local groups = Server.Domain.GroupsService.getMyGroups(playerId)
    for i = 1, #groups do
        local group = groups[i]
        groupSettings[#groupSettings + 1] = {
            groupId = group.id,
            groupName = group.name,
            mode = group.ghost_mode or Const.GHOST_NORMAL,
        }
    end

    return {
        global = globalMode,
        friend = friendMode,
        groups = groupSettings,
    }
end

Server.Domain.SettingsService = SettingsService
