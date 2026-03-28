/**
 * lb-phone（Loaf Scripts）がインジェクトするグローバル API の型定義。
 * window.オブジェクトにインジェクトされる関数（fetchNui / useNuiEvent 等）を TypeScript に認識させる。
 * 実際の実装は lb-phone が注入するため、このファイルは型情報のみを提供する。
 */
declare function fetchNui<T = any>(event: string, data?: any, mockData?: T): Promise<T>
declare function useNuiEvent(event: string, callback: (data: any) => void): void

/** lb-phone の setPopUp に渡すダイアログ設定 */
type LbPopUp = {
    title: string
    description?: string
    vertical?: boolean
    buttons: {
        title: string
        cb?: () => void
        disabled?: boolean
        bold?: boolean
        color?: 'red' | 'blue'
    }[]
}

declare global {
    interface Window {
        fetchNui: <T = any>(event: string, data?: any, mockData?: T) => Promise<T>
        useNuiEvent: (event: string, callback: (data: any) => void) => void
        GetParentResourceName: () => string
        invokeNative: any
        components?: {
            setEmojiPickerVisible?: {
                (visible: false): void
                (options: {
                    onSelect?: (emoji: { emoji?: string } | string) => void
                    onClose?: () => void
                }): void
            }
            /** lb-phone アプリ内ポップアップダイアログを表示する */
            setPopUp?: (data: LbPopUp) => void
        }
        sendNotification?: (payload: { title: string; content: string }) => void
    }

    function sendNotification(payload: { title: string; content: string }): void
}

export {}
