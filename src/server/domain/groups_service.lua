-- グループ参加・退出・一覧取得・ゴーストモード設定を担当するサービス。
-- グループの虚空件聯やパスワード検証もこのサービス層で実行する。
local Server = WAY.Server
Server.Domain = Server.Domain or {}

local Runtime = Server.State
local Utils = Server.Utils
local RepoV2 = Server.RepositoryV2
local GroupsService = {}

-- グループに参加する。グループが存在しない場合は新規作成する。
-- 既存グループの場合はパスワードを検証する。
-- Runtime.playerGroups への追加も実行する。
function GroupsService.joinGroup(playerId, groupName, password)
    if not groupName or groupName == '' then
        return false, 'invalid group name'
    end

    local group = RepoV2.GroupsRepo.findByName(groupName)
    if not group then
        if not RepoV2.GroupsRepo.createGroup(groupName, password) then
            return false, 'failed to create group'
        end
        group = RepoV2.GroupsRepo.findByName(groupName)
        if not group then
            return false, 'group creation failed'
        end
    else
        if group.password and group.password ~= password then
            return false, 'incorrect password'
        end
    end

    RepoV2.GroupsRepo.addMember(group.id, playerId)

    Runtime.groups[group.id] = Runtime.groups[group.id] or {
        id = group.id,
        name = group.name,
        password = group.password,
        created_at = group.created_at,
        members = {},
    }

    Runtime.playerGroups[playerId] = Runtime.playerGroups[playerId] or {}
    for i = 1, #Runtime.playerGroups[playerId] do
        if Runtime.playerGroups[playerId][i].id == group.id then
            return true, { groupId = group.id, groupName = group.name }
        end
    end

    Runtime.playerGroups[playerId][#Runtime.playerGroups[playerId] + 1] = {
        id = group.id,
        name = group.name,
        ghost_mode = 'normal',
        frozen_x = nil,
        frozen_y = nil,
        frozen_z = nil,
        joined_at = os.date('!%Y-%m-%d %H:%M:%S'),
    }

    Runtime.groups[group.id].members = Runtime.groups[group.id].members or {}
    Runtime.groups[group.id].members[playerId] = {
        ghost_mode = 'normal',
        frozen_x = nil,
        frozen_y = nil,
        frozen_z = nil,
    }

    return true, { groupId = group.id, groupName = group.name }
end

-- グループから退出し、メンバーが 0人になった場合はグループを削除する。
-- Runtime.playerGroups からも对象グループを取り除く。
function GroupsService.leaveGroup(playerId, groupId)
    if not groupId then
        return false, 'invalid group id'
    end

    RepoV2.GroupsRepo.removeMember(groupId, playerId)

    local groups = Runtime.playerGroups[playerId]
    if groups then
        for i = #groups, 1, -1 do
            if groups[i].id == groupId then
                table.remove(groups, i)
                break
            end
        end
    end

    RepoV2.GroupsRepo.deleteGroupIfEmpty(groupId)

    if Runtime.groups[groupId] then
        Runtime.groups[groupId].members = Runtime.groups[groupId].members or {}
        Runtime.groups[groupId].members[playerId] = nil

        -- メンバーが空になったときのみグループ本体を削除する。
        if next(Runtime.groups[groupId].members) == nil then
            Runtime.groups[groupId] = nil
        end
    end

    return true, { leftGroupId = groupId }
end

-- ランタイムキャッシュから担当グループの簡易一覧を返す。
-- DBを参照しないため高速だが、メンバー情報は含まない。
function GroupsService.getMyGroups(playerId)
    return Runtime.playerGroups[playerId] or {}
end

-- 参加グループにメンバー一覧とオンライン人数を付けて返す。DBを参照するため情報が完全だが宛い。
-- アプリでグループ詳細を表示する際に使用する。
function GroupsService.getMyGroupsWithMembers(playerId)
    local myGroups = GroupsService.getMyGroups(playerId)
    local onlineMap = Utils.getOnlinePlayerMap()
    local out = {}

    for i = 1, #myGroups do
        local group = myGroups[i]
        local memberRows = RepoV2.GroupsRepo.listMemberRowsWithProfile(group.id)
        local members = {}
        local onlineCount = 0
        local offlineCount = 0

        for j = 1, #memberRows do
            local mr = memberRows[j]
            local isOnline = onlineMap[mr.player_id] ~= nil
            local displayName = (mr.display_name and mr.display_name ~= '') and mr.display_name
                or (Runtime.lastKnownNames[mr.player_id] or mr.player_id)

            members[#members + 1] = {
                playerId = mr.player_id,
                displayName = displayName,
                isOnline = isOnline,
            }

            if isOnline then
                onlineCount = onlineCount + 1
            else
                offlineCount = offlineCount + 1
            end
        end

        out[#out + 1] = {
            id = group.id,
            name = group.name,
            ghost_mode = group.ghost_mode,
            members = members,
            onlineCount = onlineCount,
            offlineCount = offlineCount,
        }
    end

    return out
end

-- 特定グループ内の自分のゴーストモードを変更する。
-- freezeモード時にフリーズ座標を指定できる。Runtime.playerGroups のキャッシュも更新する。
function GroupsService.setGroupGhostMode(playerId, groupId, mode, freezeCoords)
    if not groupId or not mode then
        return false, 'invalid params'
    end

    local validModes = { normal = true, freeze = true, blur = true }
    if not validModes[mode] then
        return false, 'invalid mode'
    end

    local fx = freezeCoords and freezeCoords.x or nil
    local fy = freezeCoords and freezeCoords.y or nil
    local fz = freezeCoords and freezeCoords.z or nil
    RepoV2.GroupsRepo.updateMemberGhostMode(groupId, playerId, mode, fx, fy, fz)

    local groups = Runtime.playerGroups[playerId]
    if groups then
        for i = 1, #groups do
            local grp = groups[i]
            if grp.id == groupId then
                grp.ghost_mode = mode
                if mode == 'freeze' and freezeCoords then
                    grp.frozen_x = freezeCoords.x
                    grp.frozen_y = freezeCoords.y
                    grp.frozen_z = freezeCoords.z
                else
                    grp.frozen_x = nil
                    grp.frozen_y = nil
                    grp.frozen_z = nil
                end
                break
            end
        end
    end

    if Runtime.groups[groupId] and Runtime.groups[groupId].members and Runtime.groups[groupId].members[playerId] then
        Runtime.groups[groupId].members[playerId].ghost_mode = mode
        if mode == 'freeze' and freezeCoords then
            Runtime.groups[groupId].members[playerId].frozen_x = freezeCoords.x
            Runtime.groups[groupId].members[playerId].frozen_y = freezeCoords.y
            Runtime.groups[groupId].members[playerId].frozen_z = freezeCoords.z
        else
            Runtime.groups[groupId].members[playerId].frozen_x = nil
            Runtime.groups[groupId].members[playerId].frozen_y = nil
            Runtime.groups[groupId].members[playerId].frozen_z = nil
        end
    end

    return true, { groupId = groupId, ghostMode = mode }
end

Server.Domain.GroupsService = GroupsService
