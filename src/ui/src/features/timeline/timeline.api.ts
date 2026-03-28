/**
 * タイムライン機能の API 呼び出しをまとめたモジュール。
 * タイムライン取得 / チェックイン / リアクション付与 / 投稿・リアクション削除の各関数を提供する。
 */
import { callApi } from '../shared/api/callApi'
import type { TimelineData, ViewFilterType } from '../shared/types'

export async function getTimeline(viewFilter: ViewFilterType, groupId: number | null): Promise<TimelineData> {
    return callApi<TimelineData>('getTimeline', { filter: viewFilter, groupId, limit: 50 }, { posts: [] })
}

export async function createCheckin(content: string): Promise<{ posted: boolean }> {
    return callApi<{ posted: boolean }>('createCheckin', { content }, { posted: true })
}

export async function reactToPost(postId: number, stamp?: string, message?: string): Promise<{ reacted: boolean }> {
    return callApi<{ reacted: boolean }>('reactToPost', { postId, stamp: stamp ?? '', message: message ?? '' }, { reacted: true })
}

export async function deletePost(postId: number): Promise<{ deleted: boolean }> {
    return callApi('deletePost', { postId }, { deleted: true })
}

export async function deleteReaction(reactionId: number): Promise<{ deleted: boolean }> {
    return callApi('deleteReaction', { reactionId }, { deleted: true })
}
