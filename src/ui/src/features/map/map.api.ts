/**
 * 地図機能の API 呼び出しをまとめたモジュール。
 * getFriendsMap: 地図表示用のフレンド位置一覧を取得する。
 * getSelfPosition: 自分の位置情報を取得する（デビュー時は defaultPosition を返す）。
 */
import { fetchNuiCallback } from '../../utils/nui'
import { callApi } from '../shared/api/callApi'
import type { FriendsMapData, PositionPayload } from '../shared/types'

export async function getFriendsMap(): Promise<FriendsMapData> {
    return callApi<FriendsMapData>('getFriendsMap', {}, { friends: [] })
}

export async function getSelfPosition(defaultPosition: PositionPayload): Promise<PositionPayload> {
    return fetchNuiCallback<PositionPayload>('getSelfPosition', {}, defaultPosition)
}
