/**
 * FiveM NUI との通信ユーティリティ。
 * - fetchNuiCallback: NUICallback（Luaの RegisterNUICallback）を呼び出す。
 *   デビューモード時は mockData をそのまま返す。
 * - useAppEvent: Lua→UI方向のイベントをリッスンする Reactフック。
 *   lb-phone環境では useNuiEvent、それ以外は window.message でリスンする。
 */
import { useEffect } from 'react'

const devMode = !window?.invokeNative

/**
 * NUICallbackを呼び出してレスポンスを取得する。
 * @param event コールバック名。Lua側の RegisterNUICallback の名前と一致する。
 * @param data コールバックに渡すペイロード。
 * @param mockData デビューモード時に代わりに返すダミーデータ。
 */
export function fetchNuiCallback<T = any>(event: string, data?: any, mockData?: T): Promise<T> {
    if (devMode) {
        return Promise.resolve((mockData ?? {}) as T)
    }

    if (typeof window.fetchNui === 'function') {
        return window.fetchNui<T>(event, data)
    }

    return fetch(`https://${window.GetParentResourceName?.()}/${event}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data ?? {}),
    }).then((res) => res.json()) as Promise<T>
}

/**
 * Lua側から送信されるイベントをリッスンする Reactフック。
 * lb-phone環境では window.useNuiEvent、それ以外は messageイベントリスナを使用する。
 * @param event イベント名。Lua側の exports["lb-phone"]:SendCustomAppMessage の actionと一致する。
 * @param callback イベント受信時に呼ばれるコールバック関数。
 */
export function useAppEvent(event: string, callback: (data: any) => void): void {
    useEffect(() => {
        if (devMode) {
            return
        }

        if (typeof window.useNuiEvent === 'function') {
            window.useNuiEvent(event, callback)
            return
        }

        const handler = (messageEvent: MessageEvent) => {
            const payload = messageEvent.data
            if (payload && payload.action === event) {
                callback(payload.data)
            }
        }

        window.addEventListener('message', handler)
        return () => {
            window.removeEventListener('message', handler)
        }
    }, [event, callback])
}
