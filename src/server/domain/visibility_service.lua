-- フレンド・グループ共有メンバーの位置可視性新して展開するサービス。
-- ゴーストモードの「最緩和ルール」適用や、freeze/blur♻査用座標もここで処理する。
local Server = WAY.Server
Server.Domain = Server.Domain or {}

local Utils = Server.Utils
local Const = Server.Const
local Runtime = Server.State
local VisibilityService = {}

-- 指定プレイヤーから見える全プレイヤー一覧を構築する。
-- フレンド経由とグループ共有経由の両方を統合し、重複の場合はより緩和なゴーストモードを適用する。
-- 結果配列の各エントリには ghostMode / isFriend / sharedGroupIds などが包まれる。
function VisibilityService.buildVisiblePlayers(viewerId)
    local Helpers = Server.RequestHelpers
    local viewerRelations = Runtime.friendRelations[viewerId] or { outgoing = {}, incoming = {} }
    local outgoing = viewerRelations.outgoing or {}
    local incoming = viewerRelations.incoming or {}
    local myGroups = Server.Domain.GroupsService.getMyGroups(viewerId)
    local visibleMap = {}
    local onlineMap = Utils.getOnlinePlayerMap()

    for friendId, myStatus in pairs(outgoing) do
        local targetStatus = incoming[friendId]
        if myStatus ~= 'blocked' and targetStatus ~= 'blocked' and myStatus == 'accepted' and targetStatus == 'accepted' then
            local friendState = Helpers.getActiveState(friendId)
            if friendState and (friendState.ghostMode or Const.GHOST_NORMAL) ~= Const.GHOST_OFF then
                visibleMap[friendId] = {
                    state = friendState,
                    isFriend = true,
                    sharedGroupIds = {},
                    ghostModes = { friend = friendState.friendGhostMode or Const.GHOST_NORMAL },
                    freezeCoords = friendState.friendFrozenPosition,
                }
            end
        end
    end

    for i = 1, #myGroups do
        local group = myGroups[i]
        local groupMembers = Runtime.groups[group.id] and Runtime.groups[group.id].members or {}

        for memberId, memberData in pairs(groupMembers) do
            if memberId == viewerId then
                goto continue_group_member
            end

            -- [B-6] Block が Group 経由で回避されるのを防ぐ。
            -- 双方向いずれかに blocked があれば、このグループスコープを完全スキップ。
            local myBlock = outgoing[memberId]
            local theirBlock = incoming[memberId]
            if myBlock == 'blocked' or theirBlock == 'blocked' then
                goto continue_group_member
            end

            if visibleMap[memberId] then
                -- [B-6] フレンド経由で既に追加済みの場合もブロック検査済みのためここでは追記のみ。
                table.insert(visibleMap[memberId].sharedGroupIds, group.id)
                visibleMap[memberId].ghostModes['group_' .. group.id] = memberData.ghost_mode or Const.GHOST_NORMAL
                if not visibleMap[memberId].freezeCoords
                    and memberData.ghost_mode == Const.GHOST_FREEZE
                    and memberData.frozen_x and memberData.frozen_y and memberData.frozen_z then
                    visibleMap[memberId].freezeCoords = {
                        x = tonumber(memberData.frozen_x),
                        y = tonumber(memberData.frozen_y),
                        z = tonumber(memberData.frozen_z),
                    }
                end
            else
                -- [B-1] getActiveState が nil（未同意・未位置送信）の場合は DB 最終既知座標でオフライン表示。
                -- player_ghost_mode が 'off' のメンバーは全スコープで非表示のままにする。
                local memberState = Helpers.getActiveState(memberId)
                local lastKnown = Runtime.playerLastKnown[memberId]

                if memberState and (memberState.ghostMode or Const.GHOST_NORMAL) == Const.GHOST_OFF then
                    goto continue_group_member
                end

                if memberState then
                    -- オンライン・同意済み・位置あり → 通常追加
                    visibleMap[memberId] = {
                        state = memberState,
                        isFriend = false,
                        sharedGroupIds = { group.id },
                        ghostModes = { ['group_' .. group.id] = memberData.ghost_mode or Const.GHOST_NORMAL },
                        freezeCoords = (memberData.ghost_mode == Const.GHOST_FREEZE and memberData.frozen_x and memberData.frozen_y and memberData.frozen_z) and {
                            x = tonumber(memberData.frozen_x),
                            y = tonumber(memberData.frozen_y),
                            z = tonumber(memberData.frozen_z),
                        } or nil,
                    }
                elseif lastKnown and lastKnown.ghostMode ~= Const.GHOST_OFF and lastKnown.x and lastKnown.y and lastKnown.z then
                    -- オフラインまたは位置未送信 → 最終既知座標で表示
                    local offlineState = {
                        playerId = memberId,
                        source = nil,   -- source なし = オフライン扱い
                        position = {
                            x = tonumber(lastKnown.x),
                            y = tonumber(lastKnown.y),
                            z = tonumber(lastKnown.z),
                            heading = 0,
                            speed = 0,
                        },
                        ghostMode = lastKnown.ghostMode or Const.GHOST_NORMAL,
                        friendGhostMode = Const.GHOST_NORMAL,
                        friendFrozenPosition = nil,
                        updatedAt = 0,
                    }
                    visibleMap[memberId] = {
                        state = offlineState,
                        isFriend = false,
                        sharedGroupIds = { group.id },
                        ghostModes = { ['group_' .. group.id] = memberData.ghost_mode or Const.GHOST_NORMAL },
                        freezeCoords = (memberData.ghost_mode == Const.GHOST_FREEZE and memberData.frozen_x and memberData.frozen_y and memberData.frozen_z) and {
                            x = tonumber(memberData.frozen_x),
                            y = tonumber(memberData.frozen_y),
                            z = tonumber(memberData.frozen_z),
                        } or nil,
                    }
                end
            end

            ::continue_group_member::
        end
    end

    local result = {}

    for playerId, entry in pairs(visibleMap) do
        local state = entry.state
        if not state then
            goto continue
        end

        local resolvedGhostMode = VisibilityService.resolveMostPermissive(entry.ghostModes).mode
        if resolvedGhostMode == Const.GHOST_OFF then
            goto continue
        end

        if not state.position then
            goto continue
        end

        local x = state.position.x
        local y = state.position.y
        local z = state.position.z

        if resolvedGhostMode == Const.GHOST_FREEZE then
            if entry.freezeCoords then
                x = entry.freezeCoords.x
                y = entry.freezeCoords.y
                z = entry.freezeCoords.z
            end
        elseif resolvedGhostMode == Const.GHOST_BLUR then
            x = Utils.blurCoord(x)
            y = Utils.blurCoord(y)
            z = Utils.blurCoord(z)
        end

        local online = onlineMap[playerId]
        result[#result + 1] = {
            playerId = playerId,
            displayName = online and online.name
                or (state.displayName and state.displayName ~= '' and state.displayName)
                or (Runtime.lastKnownNames[playerId] or playerId),
            isOnline = online ~= nil,
            x = x,
            y = y,
            z = z,
            heading = state.position.heading,
            speed = state.position.speed,
            updatedAt = state.updatedAt,
            ghostMode = resolvedGhostMode,
            moveStatus = Utils.classifyMoveStatus(state.position.speed),
            isFriend = entry.isFriend,
            sharedGroupIds = entry.sharedGroupIds,
        }

        ::continue::
    end

    return result
end

-- 複数スコープ（フレンド・各グループ）のゴーストモードから「最も緩和なモード」を導出する。
-- 緩和度の順: normal(0) > blur(1) > freeze(2) > off(3)。
-- 複数のスコープで可視なら、最も広いスコープを优先する。
function VisibilityService.resolveMostPermissive(scopeModes)
    local order = {
        [Const.GHOST_NORMAL] = 0,
        [Const.GHOST_BLUR] = 1,
        [Const.GHOST_FREEZE] = 2,
        [Const.GHOST_OFF] = 3,
    }

    local mode = Const.GHOST_OFF
    local maxPermissiveness = order[Const.GHOST_OFF]
    for _, v in pairs(scopeModes or {}) do
        local level = order[v] or -1
        if level < maxPermissiveness then
            mode = v
            maxPermissiveness = level
        end
    end

    return { mode = mode }
end

function VisibilityService.applyGhostPrecision(state, modeInfo)
    local x = state.x
    local y = state.y
    local z = state.z

    if modeInfo and modeInfo.mode == Const.GHOST_BLUR then
        x = Utils.blurCoord(x)
        y = Utils.blurCoord(y)
        z = Utils.blurCoord(z)
    end

    return x, y, z
end

Server.Domain.VisibilityService = VisibilityService
