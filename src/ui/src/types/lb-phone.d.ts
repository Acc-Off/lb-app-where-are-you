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
    // ---------------------------------------------------------------------------
    // Leaflet 最小限型定義（@types/leaflet を使わずに gmap.L / gmap.map を型安全に扱う）
    // ---------------------------------------------------------------------------

    interface LeafletLayer {
        addTo(map: LeafletMap): this
        remove(): this
        setLatLng(latlng: [number, number]): this
        bindTooltip(content: string | HTMLElement, options?: object): this
        on(event: string, handler: (e: unknown) => void): this
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        [key: string]: any
    }
    interface LeafletCircleMarker extends LeafletLayer {}
    interface LeafletMarker extends LeafletLayer {}

    interface LeafletMap {
        setView(center: [number, number], zoom?: number): this
        setZoom(zoom: number): this
        getZoom(): number
        getMinZoom(): number
        getMaxZoom(): number
        hasLayer(layer: unknown): boolean
        removeLayer(layer: unknown): this
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        [key: string]: any
    }

    interface LeafletStatic {
        circleMarker(latlng: [number, number], options?: object): LeafletCircleMarker
        marker(latlng: [number, number], options?: object): LeafletMarker
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        [key: string]: any
    }

    // ---------------------------------------------------------------------------
    // lb-phone v2.7.0+ components.GameMap
    // ---------------------------------------------------------------------------

    interface GameMapOptions {
        allowMoving?: boolean
        center?: { x: number; y: number }
        defaultZoom?: number
        minZoom?: number
        maxZoom?: number
    }

    interface GameMapInstance {
        /** Leaflet ライブラリ本体。await ready 後に確定 */
        L: LeafletStatic | null
        /** L.Map インスタンス。await ready 後に確定 */
        map: LeafletMap | null
        /** 初期化完了を待つ Promise */
        ready: Promise<void>

        setPosition(coords: { x: number; y: number } | [number, number], zoom?: number): boolean
        setZoom(zoom: number): boolean
        getZoom(): number | null
        getMaps(): string[]
        setMap(mapId: string): boolean
        cycleMap(): string | null
        getStyles(): string[]
        setStyle(name: string): boolean
        cycleStyle(): string | null
        setShowSelf(visible: boolean): Promise<void>
        addLocation(data: { title?: string; image?: string; coords: { x: number; y: number } }): { id: number }
        removeLocation(id: number): boolean
        refreshLayout(): void
        destroy(): void
    }

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
            /**
             * lb-phone v2.7.0+ 純正マップコンポーネント。
             * components.js には含まれず lb-phone 本体から iframe に注入される。
             */
            GameMap?: new (container: HTMLElement, options?: GameMapOptions) => GameMapInstance
        }
        sendNotification?: (payload: { title: string; content: string }) => void
        /** lb-phone がカスタムアプリのリソース名を注入するプロパティ */
        resourceName?: string
    }

    function sendNotification(payload: { title: string; content: string }): void
}

export {}
