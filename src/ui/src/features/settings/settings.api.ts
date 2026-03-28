import { callApi } from '../shared/api/callApi'
import type { AppSettings, BootstrapData } from '../shared/types'

export async function getBootstrap(): Promise<BootstrapData> {
    return callApi<BootstrapData>('getBootstrap', {}, {
        playerId: '',
        selfName: '',
        consentGiven: false,
        ghostMode: 'normal',
        friends: [],
        pendingRequests: [],
    })
}

export async function updateAppSettings(settings: AppSettings): Promise<{ settings: AppSettings }> {
    return callApi('updateAppSettings', settings, { settings })
}
