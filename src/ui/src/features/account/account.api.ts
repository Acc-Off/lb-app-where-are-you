import { fetchNuiCallback } from '../../utils/nui'
import type { ApiResponse } from '../shared/types'

export async function deleteAccount(): Promise<ApiResponse<{ deleted: boolean }>> {
    const fallback: ApiResponse<{ deleted: boolean }> = { ok: true, data: { deleted: true } }
    return fetchNuiCallback<ApiResponse<{ deleted: boolean }>>('deleteAccount', {}, fallback)
}
