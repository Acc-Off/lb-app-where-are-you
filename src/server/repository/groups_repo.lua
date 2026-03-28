-- ============================================================================
-- groups_repo.lua
-- Groups RepositoryV2 — locshare_groups / locshare_group_members テーブルへの CRUD 操作
--
-- グループ本体と参加情報（ゴーストモード含む）を管理する。
-- グループ内のゴーストモードはメンバー単位で設定可能。
-- ============================================================================
local Server = WAY.Server
Server.RepositoryV2 = Server.RepositoryV2 or {}

local Repo = Server.Repository
local GroupsRepo = {}

-- グループ名で 1 件検索する（参加/作成前の重複チェックに使用）。
function GroupsRepo.findByName(groupName)
    return Repo.fetchOne([[
        SELECT id, name, password, created_at
        FROM locshare_groups
        WHERE name = ?
        LIMIT 1
    ]], { groupName })
end

-- グループを新規作成する。INSERT の lastInsertId を返す。
function GroupsRepo.createGroup(groupName, password)
    return Repo.execute([[
        INSERT INTO locshare_groups (name, password, created_at)
        VALUES (?, ?, CURRENT_TIMESTAMP)
    ]], { groupName, password })
end

-- メンバーを追加する。すでに参加済みの場合は joined_at を更新して再参加扱いにする。
function GroupsRepo.addMember(groupId, playerId)
    Repo.execute([[
        INSERT INTO locshare_group_members (group_id, player_id, ghost_mode, joined_at)
        VALUES (?, ?, 'normal', CURRENT_TIMESTAMP)
        ON DUPLICATE KEY UPDATE joined_at = CURRENT_TIMESTAMP
    ]], { groupId, playerId })
end

-- メンバーを削除する（退出処理）。
function GroupsRepo.removeMember(groupId, playerId)
    Repo.execute([[
        DELETE FROM locshare_group_members
        WHERE group_id = ? AND player_id = ?
    ]], { groupId, playerId })
end

-- プレイヤーが参加している全グループをゴーストモード情報付きで取得する。
function GroupsRepo.listGroupsByPlayerId(playerId)
    return Repo.fetchAll([[
        SELECT g.id, g.name, g.password, gm.ghost_mode, gm.frozen_x, gm.frozen_y, gm.frozen_z, gm.joined_at
        FROM locshare_groups g
        INNER JOIN locshare_group_members gm ON g.id = gm.group_id
        WHERE gm.player_id = ?
        ORDER BY gm.joined_at DESC
    ]], { playerId })
end

-- グループの全メンバー行を取得する（ゴーストモード・座標含む）。
function GroupsRepo.listMemberRows(groupId)
    return Repo.fetchAll([[
        SELECT player_id, ghost_mode, frozen_x, frozen_y, frozen_z, joined_at
        FROM locshare_group_members
        WHERE group_id = ?
        ORDER BY joined_at ASC
    ]], { groupId })
end

-- メンバーのグループ内ゴーストモードを更新する。
-- freeze の場合は現在座標も併せて保存し、それ以外は座標列を NULL にリセットする。
function GroupsRepo.updateMemberGhostMode(groupId, playerId, mode, frozenX, frozenY, frozenZ)
    if mode == 'freeze' then
        Repo.execute([[
            UPDATE locshare_group_members
            SET ghost_mode = ?, frozen_x = ?, frozen_y = ?, frozen_z = ?
            WHERE group_id = ? AND player_id = ?
        ]], { mode, frozenX, frozenY, frozenZ, groupId, playerId })
        return
    end

    Repo.execute([[
        UPDATE locshare_group_members
        SET ghost_mode = ?, frozen_x = NULL, frozen_y = NULL, frozen_z = NULL
        WHERE group_id = ? AND player_id = ?
    ]], { mode or 'normal', groupId, playerId })
end

-- メンバーが 0 人になった場合にグループ本体を削除する（退出後の後処理）。
function GroupsRepo.deleteGroupIfEmpty(groupId)
    local row = Repo.fetchOne([[
        SELECT COUNT(*) AS count
        FROM locshare_group_members
        WHERE group_id = ?
    ]], { groupId })

    if (row and tonumber(row.count) or 0) == 0 then
        Repo.execute([[
            DELETE FROM locshare_groups
            WHERE id = ?
        ]], { groupId })
    end
end

-- メンバー行をプレイヤー情報（表示名・位置）と JOIN して取得する
-- （グループ詳細表示・可視性解決に使用）。
function GroupsRepo.listMemberRowsWithProfile(groupId)
    return Repo.fetchAll([[
        SELECT gm.player_id, gm.ghost_mode, gm.frozen_x, gm.frozen_y, gm.frozen_z, gm.joined_at,
               p.display_name, p.ghost_mode AS player_ghost_mode, p.x, p.y, p.z
        FROM locshare_group_members gm
        LEFT JOIN locshare_players p ON p.player_id = gm.player_id
        WHERE gm.group_id = ?
        ORDER BY gm.joined_at ASC
    ]], { groupId })
end

-- 全グループを一括取得する（起動時メモリ初期化用）。
function GroupsRepo.fetchAllGroupsForInit()
    return Repo.fetchAll([[SELECT id, name, password, created_at FROM locshare_groups]], {})
end

-- 全グループ参加情報をグループ名付きで一括取得する（起動時メモリ初期化用）。
function GroupsRepo.fetchAllMemberGroupsForInit()
    return Repo.fetchAll([[
        SELECT gm.player_id, g.id, g.name, gm.ghost_mode,
               gm.frozen_x, gm.frozen_y, gm.frozen_z, gm.joined_at
        FROM locshare_group_members gm
        INNER JOIN locshare_groups g ON gm.group_id = g.id
    ]], {})
end

Server.RepositoryV2.GroupsRepo = GroupsRepo
