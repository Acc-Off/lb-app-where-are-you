/**
 * ApiResponse<T>からデータを取り出すユーティリティ。
 * ok=false または data が null/undefined の場合は fallback を返す。
 */
import type { ApiResponse } from '../types'

export function pickOrFallback<T>(response: ApiResponse<T> | undefined, fallback: T): T {
    if (!response?.ok || response.data == null) {
        return fallback
    }

    return response.data
}
