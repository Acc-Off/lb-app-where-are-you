-- グループ関連アクションハンドラー定義ファイル。
-- Actionsトーブルにグループ参加・退出・一覧取得・ゴーストモード設定の各ハンドラーを登録する。
local Server = WAY.Server
Server.ActionHandlers = Server.ActionHandlers or {}

local Actions = Server.ActionHandlers

-- GroupsService はこのファイルより後にロードされるため、実行時に Server.Domain.* を参照する。

-- グループに参加する（鍵検証等を payload から取り出してサービスへ委譲）。
Actions.joinGroup = function(_, playerId, payload)
    local groupName = tostring(payload.groupName or '')
    local password = payload.password and tostring(payload.password) or nil

    if groupName == '' then
        return false, nil, 'invalid group name'
    end

    local success, result = Server.Domain.GroupsService.joinGroup(playerId, groupName, password)
    if not success then
        return false, nil, result
    end

    return true, result
end

-- グループから退出する。
Actions.leaveGroup = function(_, playerId, payload)
    local groupId = tonumber(payload.groupId)
    if not groupId then
        return false, nil, 'invalid group id'
    end

    local success, result = Server.Domain.GroupsService.leaveGroup(playerId, groupId)
    if not success then
        return false, nil, result
    end

    return true, result
end

-- 参加中のグループ一覧（メンバー情報付き）を取得する。
Actions.getMyGroups = function(_, playerId)
    return true, { groups = Server.Domain.GroupsService.getMyGroupsWithMembers(playerId) }
end

-- グループ内の自分のゴーストモードを変更する。
Actions.setGroupGhostMode = function(_, playerId, payload)
    local groupId = tonumber(payload.groupId)
    local mode = tostring(payload.mode or 'normal')
    local freezeCoords = payload.freezeCoords

    if not groupId then
        return false, nil, 'invalid group id'
    end

    local success, result = Server.Domain.GroupsService.setGroupGhostMode(playerId, groupId, mode, freezeCoords)
    if not success then
        return false, nil, result
    end

    return true, result
end
