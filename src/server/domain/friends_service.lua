local Server = WAY.Server
Server.Domain = Server.Domain or {}

local Utils = Server.Utils
local Runtime = Server.State
local RepoV2 = Server.RepositoryV2
local Const = Server.Const
local FriendsService = {}

local function ensureRelationEntry(playerId)
    Runtime.friendRelations[playerId] = Runtime.friendRelations[playerId] or {
        outgoing = {},
        incoming = {},
    }
    return Runtime.friendRelations[playerId]
end

local function removeDirectionalRelation(playerId, targetPlayerId)
    local mine = Runtime.friendRelations[playerId]
    if mine and mine.outgoing then
        mine.outgoing[targetPlayerId] = nil
    end

    local other = Runtime.friendRelations[targetPlayerId]
    if other and other.incoming then
        other.incoming[playerId] = nil
    end
end

local function removeAllRelationsForPlayer(playerId)
    local mine = Runtime.friendRelations[playerId]
    if not mine then
        return
    end

    for targetPlayerId, _ in pairs(mine.outgoing or {}) do
        local target = Runtime.friendRelations[targetPlayerId]
        if target and target.incoming then
            target.incoming[playerId] = nil
        end
    end

    for sourcePlayerId, _ in pairs(mine.incoming or {}) do
        local source = Runtime.friendRelations[sourcePlayerId]
        if source and source.outgoing then
            source.outgoing[playerId] = nil
        end
    end

    Runtime.friendRelations[playerId] = nil
end

-- NotificationsService はこのファイルより後最候にロードされるため、
-- トップレベルキャプチャを避け実行時に Server.Domain.* を参照する。

function FriendsService.getAcceptedFriendIds(playerId)
    local out = {}
    local rel = Runtime.friendRelations[playerId]
    if not rel or not rel.outgoing then
        return out
    end

    for targetPlayerId, status in pairs(rel.outgoing) do
        if status == 'accepted' and rel.incoming and rel.incoming[targetPlayerId] == 'accepted' then
            out[#out + 1] = targetPlayerId
        end
    end

    return out
end

function FriendsService.getPairStatus(playerId, otherId)
    local Helpers = Server.RequestHelpers
    return Helpers.getDirectionalStatus(playerId, otherId)
end

function FriendsService.buildPendingRequests(playerId)
    local Helpers = Server.RequestHelpers
    local ownMap = Helpers.getOwnRelationMap(playerId)
    local rows = RepoV2.FriendsRepo.listPendingIncoming(playerId)

    local requesterIds = {}
    for i = 1, #rows do
        requesterIds[#requesterIds + 1] = rows[i].player_id
    end

    local profileNameMap = RepoV2.PlayersRepo.getProfileNameMap(requesterIds)
    local onlineMap = Utils.getOnlinePlayerMap()
    local requests = {}

    for i = 1, #rows do
        local row = rows[i]
        if ownMap[row.player_id] == 'blocked' then
            goto continue
        end

        local requester = onlineMap[row.player_id]
        requests[#requests + 1] = {
            requestId = row.id,
            fromPlayerId = row.player_id,
            fromName = requester and requester.name or Helpers.resolveDisplayName(row.player_id, profileNameMap),
            isOnline = requester ~= nil,
        }

        ::continue::
    end

    return requests
end

function FriendsService.buildFriendsList(playerId)
    local Helpers = Server.RequestHelpers
    local pairStatus = Helpers.getOwnRelationMap(playerId)
    local friendIds = {}

    for friendId, relation in pairs(pairStatus) do
        if relation == 'accepted' or relation == 'blocked' then
            friendIds[#friendIds + 1] = friendId
        end
    end

    local profileNameMap = RepoV2.PlayersRepo.getProfileNameMap(friendIds)
    local friends = {}

    for friendId, relation in pairs(pairStatus) do
        if relation == 'accepted' or relation == 'blocked' then
            local friendState = Runtime.players[friendId]
            local online = friendState and friendState.source ~= nil
            local speed = friendState and friendState.position and friendState.position.speed or 0
            local ghostMode = friendState and friendState.friendGhostMode or Const.GHOST_NORMAL

            friends[#friends + 1] = {
                playerId = friendId,
                displayName = Helpers.resolveDisplayName(friendId, profileNameMap),
                isOnline = online,
                ghostMode = ghostMode,
                speed = speed,
                moveStatus = Utils.classifyMoveStatus(speed),
                updatedAt = friendState and friendState.updatedAt or 0,
                relation = relation,
            }
        end
    end

    table.sort(friends, function(a, b)
        if a.relation ~= b.relation then
            return a.relation == 'accepted'
        end
        return a.displayName:lower() < b.displayName:lower()
    end)

    return friends
end

function FriendsService.getFriendsList(playerId)
    return {
        friends = FriendsService.buildFriendsList(playerId),
        pendingRequests = FriendsService.buildPendingRequests(playerId),
    }
end

function FriendsService.searchPlayers(playerSource, playerId, payload)
    local Helpers = Server.RequestHelpers
    local query = tostring(payload.query or ''):lower()
    local pairStatus = Helpers.getOwnRelationMap(playerId)

    local found = {}
    local players = GetPlayers()
    for i = 1, #players do
        local targetSource = tonumber(players[i])
        if targetSource and targetSource ~= playerSource then
            local targetId = Utils.getIdentifier(targetSource)
            local targetName = Utils.safeName(targetSource)
            local matchId = tostring(targetSource) == query
            local matchName = query ~= '' and targetName:lower():find(query, 1, true) ~= nil
            local matchIdentifier = query ~= '' and targetId:lower():find(query, 1, true) ~= nil

            if matchId or matchName or matchIdentifier then
                local status = pairStatus[targetId]
                if status ~= 'accepted' then
                    found[#found + 1] = {
                        serverId = targetSource,
                        playerId = targetId,
                        displayName = targetName,
                        relation = status or 'none',
                    }
                end
            end
        end
    end

    return { players = found }
end

function FriendsService.getFriendDetail(playerId, targetPlayerId)
    local Helpers = Server.RequestHelpers
    local myStatus = FriendsService.getPairStatus(playerId, targetPlayerId)
    local isFriend = myStatus == 'accepted'

    local sharedGroupNames = nil
    if not isFriend then
        local GroupsService = Server.Domain.GroupsService
        local myGroups = GroupsService.getMyGroups(playerId)
        local targetGroups = GroupsService.getMyGroups(targetPlayerId)
        sharedGroupNames = {}
        for i = 1, #myGroups do
            for j = 1, #targetGroups do
                if myGroups[i].id == targetGroups[j].id then
                    sharedGroupNames[#sharedGroupNames + 1] = myGroups[i].name
                    break
                end
            end
        end
        if #sharedGroupNames == 0 then
            return false, nil, 'not visible'
        end
    end

    local targetState = Runtime.players[targetPlayerId]
    local online = targetState and targetState.source ~= nil
    local speed = targetState and targetState.position and targetState.position.speed or 0
    local ghostMode = isFriend and (targetState and targetState.friendGhostMode or Const.GHOST_NORMAL) or Const.GHOST_NORMAL

    local displayName
    if isFriend then
        local profileNameMap = RepoV2.PlayersRepo.getProfileNameMap({ targetPlayerId })
        displayName = Helpers.resolveDisplayName(targetPlayerId, profileNameMap)
    else
        displayName = Helpers.resolveDisplayName(targetPlayerId, nil)
    end

    return true, {
        playerId = targetPlayerId,
        displayName = displayName,
        isOnline = online,
        ghostMode = ghostMode,
        speed = speed,
        moveStatus = Utils.classifyMoveStatus(speed),
        updatedAt = targetState and targetState.updatedAt or 0,
        isFriend = isFriend,
        sharedGroupNames = sharedGroupNames,
    }
end

function FriendsService.sendFriendRequest(playerSource, playerId, payload)
    local Helpers = Server.RequestHelpers
    local targetServerId = tonumber(payload.serverId)
    if not targetServerId then
        return false, nil, 'invalid target'
    end

    local targetPlayerId = Utils.getIdentifier(targetServerId)
    if not targetPlayerId then
        return false, nil, 'target not online'
    end

    if targetPlayerId == playerId then
        return false, nil, 'cannot request self'
    end

    local myStatus = FriendsService.getPairStatus(playerId, targetPlayerId)
    if myStatus == 'accepted' then return false, nil, 'already friends' end
    if myStatus == 'blocked' then return false, nil, 'blocked' end
    if myStatus == 'pending' then return false, nil, 'pending' end

    local targetStatus = FriendsService.getPairStatus(targetPlayerId, playerId)
    if targetStatus == 'blocked' then return false, nil, 'unavailable' end
    if targetStatus == 'pending' then return false, nil, 'pending' end

    ensureRelationEntry(playerId)
    ensureRelationEntry(targetPlayerId)
    Helpers.upsertDirectionalStatus(playerId, targetPlayerId, 'pending')

    Server.Domain.NotificationsService.notifyPendingRequest(targetPlayerId)
    Server.Domain.NotificationsService.notifyFriendsStateChanged(playerId)
    Server.Domain.NotificationsService.notifyFriendsStateChanged(targetPlayerId)
    return true, { sent = true }
end

function FriendsService.respondFriendRequest(playerId, payload)
    local Helpers = Server.RequestHelpers
    local requestId = tonumber(payload.requestId)
    local accept = payload.accept == true
    if not requestId then
        return false, nil, 'invalid request'
    end

    local row = RepoV2.FriendsRepo.findPendingRequestById(requestId, playerId)
    if not row then
        return false, nil, 'not found'
    end

    if accept then
        ensureRelationEntry(row.player_id)
        ensureRelationEntry(row.friend_id)
        Helpers.upsertDirectionalStatus(row.player_id, row.friend_id, 'accepted')
        Helpers.upsertDirectionalStatus(row.friend_id, row.player_id, 'accepted')
        Server.Domain.NotificationsService.notifyRequestAccepted(row.player_id, row.friend_id)
    else
        RepoV2.FriendsRepo.deletePendingById(requestId)
        removeDirectionalRelation(row.player_id, row.friend_id)
    end

    Server.Domain.NotificationsService.notifyFriendsStateChanged(row.player_id)
    Server.Domain.NotificationsService.notifyFriendsStateChanged(row.friend_id)
    return true, { accepted = accept }
end

function FriendsService.blockFriend(playerId, payload)
    local Helpers = Server.RequestHelpers
    local targetPlayerId = tostring(payload.playerId or '')
    if targetPlayerId == '' then
        return false, nil, 'invalid target'
    end

    ensureRelationEntry(playerId)
    ensureRelationEntry(targetPlayerId)
    Helpers.upsertDirectionalStatus(playerId, targetPlayerId, 'blocked')
    Server.Domain.NotificationsService.notifyFriendsStateChanged(playerId)
    Server.Domain.NotificationsService.notifyFriendsStateChanged(targetPlayerId)
    return true, { blocked = true }
end

function FriendsService.unblockFriend(playerId, payload)
    local Helpers = Server.RequestHelpers
    local targetPlayerId = tostring(payload.playerId or '')
    if targetPlayerId == '' then
        return false, nil, 'invalid target'
    end

    local targetStatus = FriendsService.getPairStatus(targetPlayerId, playerId)
    if targetStatus == 'accepted' or targetStatus == 'blocked' then
        ensureRelationEntry(playerId)
        ensureRelationEntry(targetPlayerId)
        Helpers.upsertDirectionalStatus(playerId, targetPlayerId, 'accepted')
    else
        RepoV2.FriendsRepo.deleteBlocked(playerId, targetPlayerId)
        removeDirectionalRelation(playerId, targetPlayerId)
    end

    Server.Domain.NotificationsService.notifyFriendsStateChanged(playerId)
    Server.Domain.NotificationsService.notifyFriendsStateChanged(targetPlayerId)
    return true, { unblocked = true }
end

function FriendsService.removeFriend(playerId, payload)
    local targetPlayerId = tostring(payload.playerId or '')
    if targetPlayerId == '' then
        return false, nil, 'invalid target'
    end

    local myStatus = FriendsService.getPairStatus(playerId, targetPlayerId)
    local targetStatus = FriendsService.getPairStatus(targetPlayerId, playerId)
    if myStatus ~= 'accepted' and targetStatus ~= 'accepted' then
        return false, nil, 'not friend'
    end

    RepoV2.FriendsRepo.deleteBothDirections(playerId, targetPlayerId)
    removeDirectionalRelation(playerId, targetPlayerId)
    removeDirectionalRelation(targetPlayerId, playerId)
    Server.Domain.NotificationsService.notifyFriendsStateChanged(playerId)
    Server.Domain.NotificationsService.notifyFriendsStateChanged(targetPlayerId)
    return true, { removed = true }
end

function FriendsService.clearRuntimeRelations(playerId)
    removeAllRelationsForPlayer(playerId)
end

Server.Domain.FriendsService = FriendsService
