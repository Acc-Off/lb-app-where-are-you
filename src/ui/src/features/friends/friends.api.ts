import { fetchNuiCallback } from '../../utils/nui'
import { callApi } from '../shared/api/callApi'
import type { ApiResponse, FriendDetail, FriendsListData, NearbyCandidate, SearchPlayer } from '../shared/types'

export async function getFriendsList(): Promise<FriendsListData> {
    return callApi<FriendsListData>('getFriendsList', {}, { friends: [], pendingRequests: [] })
}

export async function searchPlayers(query: string): Promise<{ players: SearchPlayer[] }> {
    return callApi<{ players: SearchPlayer[] }>('searchPlayers', { query }, { players: [] })
}

export async function getNearbyCandidates(): Promise<{ candidates: NearbyCandidate[] }> {
    return callApi<{ candidates: NearbyCandidate[] }>('getNearbyCandidates', {}, { candidates: [] })
}

export async function sendFriendRequest(serverId: number): Promise<ApiResponse<{ sent: boolean }>> {
    const fallback: ApiResponse<{ sent: boolean }> = { ok: true, data: { sent: true } }
    return fetchNuiCallback<ApiResponse<{ sent: boolean }>>('sendFriendRequest', { serverId }, fallback)
}

export async function respondFriendRequest(requestId: number, accept: boolean): Promise<{ accepted: boolean }> {
    return callApi('respondFriendRequest', { requestId, accept }, { accepted: accept })
}

export async function getFriendDetail(playerId: string): Promise<FriendDetail> {
    return callApi<FriendDetail>('getFriendDetail', { playerId }, {
        playerId,
        displayName: playerId,
        isOnline: false,
        ghostMode: 'normal',
        speed: 0,
        moveStatus: 'idle',
        updatedAt: Date.now(),
    })
}

export async function blockFriend(playerId: string): Promise<{ blocked: boolean }> {
    return callApi('blockFriend', { playerId }, { blocked: true })
}

export async function unblockFriend(playerId: string): Promise<ApiResponse<{ unblocked: boolean }>> {
    const fallback: ApiResponse<{ unblocked: boolean }> = { ok: true, data: { unblocked: true } }
    return fetchNuiCallback<ApiResponse<{ unblocked: boolean }>>('unblockFriend', { playerId }, fallback)
}

export async function removeFriend(playerId: string): Promise<ApiResponse<{ removed: boolean }>> {
    const fallback: ApiResponse<{ removed: boolean }> = { ok: true, data: { removed: true } }
    return fetchNuiCallback<ApiResponse<{ removed: boolean }>>('removeFriend', { playerId }, fallback)
}
