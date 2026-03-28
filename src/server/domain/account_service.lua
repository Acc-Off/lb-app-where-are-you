-- アカウントが卸会する際のデータ削除処理を担当するサービス。
-- ランタイムキャッシュのクリーンアップ + DB重複削除を一括実行する。
local Server = WAY.Server
Server.Domain = Server.Domain or {}

local RepoV2 = Server.RepositoryV2
local Runtime = Server.State
local AccountService = {}

-- プレイヤーの全データを削除して退会処理を完了する。
-- ランタイムキャッシュ（players / lastKnownNames / postCooldowns / playerGroups）をクリアし、
-- DB内のフレンド・グループ・投稿・リアクションを全て削除する。
function AccountService.deleteAccount(playerId)
    local state = Runtime.players[playerId]
    if state and state.source then
        Runtime.sourceToPlayerId[state.source] = nil
    end

    -- 参加グループの逆引きインデックスから対象プレイヤーを除外する。
    local groups = Runtime.playerGroups[playerId]
    if groups then
        for i = 1, #groups do
            local groupId = groups[i].id
            if Runtime.groups[groupId] then
                Runtime.groups[groupId].members = Runtime.groups[groupId].members or {}
                Runtime.groups[groupId].members[playerId] = nil
                if next(Runtime.groups[groupId].members) == nil then
                    Runtime.groups[groupId] = nil
                end
            end
        end
    end

    -- フレンド関係の双方向キャッシュをクリアする。
    if Server.Domain.FriendsService and type(Server.Domain.FriendsService.clearRuntimeRelations) == 'function' then
        Server.Domain.FriendsService.clearRuntimeRelations(playerId)
    else
        Runtime.friendRelations[playerId] = nil
    end

    Runtime.players[playerId] = nil
    Runtime.playerLastKnown[playerId] = nil
    Runtime.lastKnownNames[playerId] = nil
    Runtime.nearbyCooldowns[playerId] = nil
    Runtime.postCooldowns[playerId] = nil
    Runtime.playerGroups[playerId] = nil

    RepoV2.AccountRepo.deleteAllByPlayerId(playerId)
    return true, { deleted = true }
end

Server.Domain.AccountService = AccountService
