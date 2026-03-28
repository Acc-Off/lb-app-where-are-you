import { fetchNuiCallback } from '../../utils/nui'
import { callApi } from '../shared/api/callApi'
import type { ApiResponse, GhostMode, GroupItem } from '../shared/types'

export async function getMyGroups(): Promise<{ groups: GroupItem[] }> {
    return callApi<{ groups: GroupItem[] }>('getMyGroups', {}, { groups: [] })
}

export async function joinGroup(groupName: string, password?: string): Promise<ApiResponse<{ groupId: number; groupName: string }>> {
    const fallback: ApiResponse<{ groupId: number; groupName: string }> = { ok: true, data: { groupId: 0, groupName } }
    return fetchNuiCallback<ApiResponse<{ groupId: number; groupName: string }>>('joinGroup', { groupName, password: password || null }, fallback)
}

export async function leaveGroup(groupId: number): Promise<ApiResponse<{ leftGroupId: number }>> {
    const fallback: ApiResponse<{ leftGroupId: number }> = { ok: true, data: { leftGroupId: groupId } }
    return fetchNuiCallback<ApiResponse<{ leftGroupId: number }>>('leaveGroup', { groupId }, fallback)
}

export async function setGroupGhostMode(groupId: number, mode: GhostMode): Promise<{ updated: boolean }> {
    return callApi('setGroupGhostMode', { groupId, mode }, { updated: true })
}
