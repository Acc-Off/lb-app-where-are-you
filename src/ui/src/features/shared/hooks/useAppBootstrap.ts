/**
 * アプリ起動時のブートストラップデータを取得するフック。
 * マウント時に getBootstrap NUICallbackを呼び出し、
 * 完了時は onLoaded、失敗時は onError を呼び出す。
 * アンマウント時はイベントをキャンセルする。
 */
import { useEffect } from 'react'
import { callApi } from '../api/callApi'
import type { BootstrapData } from '../types'

type UseAppBootstrapParams = {
    onLoaded: (data: BootstrapData) => void
    onError?: () => void
}

export function useAppBootstrap({ onLoaded, onError }: UseAppBootstrapParams) {
    useEffect(() => {
        let mounted = true

        callApi<BootstrapData>('getBootstrap', {}, {
            playerId: '',
            selfName: '',
            consentGiven: false,
            ghostMode: 'normal',
            friends: [],
            pendingRequests: [],
        })
            .then((data) => {
                if (!mounted) return
                onLoaded(data)
            })
            .catch(() => {
                if (!mounted) return
                onError?.()
            })

        return () => {
            mounted = false
        }
    }, [onError, onLoaded])
}
