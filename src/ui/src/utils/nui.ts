/**
 * FiveM NUI との通信ユーティリティ。
 * - fetchNuiCallback: NUICallback（Luaの RegisterNUICallback）を呼び出す。
 *   デビューモード時は mockData をそのまま返す。
 * - useAppEvent: Lua→UI方向のイベントをリッスンする Reactフック。
 *   lb-phone環境では useNuiEvent、それ以外は window.message でリスンする。
 */
import { useEffect, useRef } from 'react'

const devMode = !window?.invokeNative

/**
 * モジュールレベルで appOpen/appClose を早期捕捉する。
 * lb-phone は React マウントより前に appOpen を送信するため、
 * useNuiEvent（useEffect 内登録）では初回を取り逃す。
 * ここで window.message を直接リスンして状態を保持する。
 */
// index.html のインラインスクリプトが JS バンドルロード前に appOpen/appClose を早期捕捉し
// window.__wayAppIsOpen に保持する。ここではその値を初期値として使いつつ、
// 以降の appOpen/appClose も継続して受け取る。
let _appIsOpen: boolean = typeof window !== 'undefined'
    ? Boolean((window as any).__wayAppIsOpen)
    : false
// lb-phone が appOpen を取りこぼしても初期化できるよう、componentsLoaded 受信済みかを保持する。
// index.html の early-capture が最速で __wayComponentsLoaded を立てるため、その値を初期値に使う。
let _componentsLoaded: boolean = typeof window !== 'undefined'
    ? Boolean((window as any).__wayComponentsLoaded)
    : false
if (typeof window !== 'undefined' && !devMode) {
    window.addEventListener('message', (e: MessageEvent) => {
        if (e.data === 'componentsLoaded') {
            _componentsLoaded = true
            ;(window as any).__wayComponentsLoaded = true
        }
        if (e.data && typeof e.data === 'object') {
            if (e.data.action === 'appOpen')  {
                _appIsOpen = true
                ;(window as any).__wayAppIsOpen = true
            }
            if (e.data.action === 'appClose') {
                _appIsOpen = false
                ;(window as any).__wayAppIsOpen = false
            }
        }
    })
}

export function getInitialAppOpenState(): boolean {
    return _appIsOpen
}

/**
 * componentsLoaded を既に受信済みかを返す。
 * lb-phone が appOpen を取りこぼしても、componentsLoaded（表示中 iframe には開くたびに届く）で
 * 初期化を成立させるために使う。
 */
export function getInitialComponentsLoaded(): boolean {
    return _componentsLoaded
}

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

    // window.fetchNui が未注入 = lb-phone のバグ。フォールバックせず即時エラーにする。
    const err = new Error('[WAY] fetchNui is not injected (lb-phone background restore bug)')
    console.error('[WAY] fetchNui is not injected (lb-phone background restore bug)')
    return Promise.reject(err)
}

/**
 * Lua側から送信されるイベントをリッスンする Reactフック。
 * lb-phone環境では window.useNuiEvent、それ以外は messageイベントリスナを使用する。
 * @param event イベント名。Lua側の exports["lb-phone"]:SendCustomAppMessage の actionと一致する。
 * @param callback イベント受信時に呼ばれるコールバック関数。
 */
export function useAppEvent(event: string, callback: (data: any) => void): void {
    // callback の参照変化で useEffect が再実行されないよう ref で保持する。
    // useNuiEvent は cleanup 不可のため、event が変わらない限り再登録しない。
    const callbackRef = useRef(callback)
    callbackRef.current = callback

    useEffect(() => {
        if (devMode) {
            return
        }

        if (typeof window.useNuiEvent === 'function') {
            window.useNuiEvent(event, (data: any) => {
                callbackRef.current(data)
            })
            return
        }

        const handler = (messageEvent: MessageEvent) => {
            const payload = messageEvent.data
            if (payload && payload.action === event) {
                callbackRef.current(payload.data)
            }
        }

        window.addEventListener('message', handler)
        return () => {
            window.removeEventListener('message', handler)
        }
    }, [event]) // callback は ref 経由なので依存不要
}
