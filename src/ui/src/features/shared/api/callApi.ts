/**
 * NUICallbackを呼び出して ApiResponse<T>型でレスポンスを取得する。
 * エラーまたは ok=false の場合は fallbackData を返す。
 */
import { fetchNuiCallback } from '../../../utils/nui'
import type { ApiResponse } from '../types'

export async function callApi<T>(event: string, data: unknown, fallbackData: T): Promise<T> {
    const fallback: ApiResponse<T> = { ok: true, data: fallbackData }
    const response = await fetchNuiCallback<ApiResponse<T>>(event, data, fallback)
    if (!response?.ok || !response.data) {
        return fallbackData
    }

    return response.data
}
