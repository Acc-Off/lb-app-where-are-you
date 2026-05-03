/**
 * 地図タブコンポーネント。
 * lb-phone v2.7.0+ の components.GameMap を使って Los Santos マップを表示する。
 * 自分マーカー（setShowSelf）・フレンドマーカー・ポストピンを gmap.L / gmap.map で直接描画する。
 */
import { useCallback, useEffect, useRef, useState } from 'react'
import { ghostModeBadge, markerColorByMode } from '../shared/presentation'
import type { FriendMapItem, GroupItem, ViewFilterType } from '../shared/types'
import type { FocusedPostPin } from './map.types'
import { useT } from '../shared/locale'

const STORAGE_MAP   = 'wau:map'
const STORAGE_STYLE = 'wau:style'
const STORAGE_ZOOM  = 'wau:zoom'

type MapTabProps = {
    /** lb-phone の onUse/onClose と連動するアプリ開閉状態。false の場合は GameMap 初期化をスキップする。 */
    isAppOpen: boolean
    /** タブが現在アクティブかどうか。false の場合は display:none で非表示にする（unmount しない） */
    isActive: boolean
    selfX: number
    selfY: number
    ready: boolean
    viewFilter: ViewFilterType
    selectedGroupId: number | null
    groups: GroupItem[]
    filteredFriendsMap: FriendMapItem[]
    focusedPostPin: FocusedPostPin | null
    onMapReady: (gmap: GameMapInstance | null) => void
    onApplyViewFilter: (value: string) => void
    onRecenterToSelf: () => void
    onFriendClick: (playerId: string) => void
}

export function MapTab({
    isAppOpen,
    isActive,
    selfX,
    selfY,
    ready,
    viewFilter,
    selectedGroupId,
    groups,
    filteredFriendsMap,
    focusedPostPin,
    onMapReady,
    onApplyViewFilter,
    onRecenterToSelf,
    onFriendClick,
}: MapTabProps) {
    const t = useT()
    const containerRef = useRef<HTMLDivElement>(null)
    const gameMapRef = useRef<GameMapInstance | null>(null)
    const friendMarkersRef = useRef<LeafletCircleMarker[]>([])
    const postPinMarkerRef = useRef<LeafletCircleMarker | null>(null)
    const mapReadyRef = useRef(false)
    /** 現在のマップにスタイル選択肢が複数あるかどうか */
    const [hasStyles, setHasStyles] = useState(false)
    /** lb-phone が window.components を注入しなかった（バックグラウンド復帰時） */
    const [mapUnavailable, setMapUnavailable] = useState(false)

    // 最新の props 値を gmap.ready クロージャ内で参照するための ref
    const selfXRef = useRef(selfX)
    const selfYRef = useRef(selfY)
    const readyRef = useRef(ready)
    /**
     * gmap.ready が ready より先に解決した場合に「センタリング待ち」のズームレベルを保持する。
     * null = センタリング不要 / 数値 = そのズームレベルでセンタリング待ち
     */
    const pendingCenterZoomRef = useRef<number | null>(null)

    useEffect(() => { selfXRef.current = selfX }, [selfX])
    useEffect(() => { selfYRef.current = selfY }, [selfY])

    // getSelfPosition の完了（ready=true）が gmap.ready より遅れた場合のセンタリング。
    // pendingCenterZoomRef に値がセットされているとき（gmap.ready 側でセットする）のみ実行する。
    // selfX/selfY の ref 更新は同一 commit 内でこの effect より先に実行されるため、
    // selfXRef.current は最新の座標を指している。
    useEffect(() => {
        readyRef.current = ready
        if (!ready) return
        const zoom = pendingCenterZoomRef.current
        if (zoom === null) return
        pendingCenterZoomRef.current = null
        gameMapRef.current?.refreshLayout()
        gameMapRef.current?.setPosition({ x: selfXRef.current, y: selfYRef.current }, zoom)
    }, [ready])

    // GameMap インスタンスを初期化する
    // isAppOpen=true になった時（appOpen 受信後）に実行する。
    // TODO(lb-phone-bug-workaround): deps に isAppOpen を含めているのは lb-phone バグ回避処理。修正後に削除すること。
    // 【バグ内容】バックグラウンド復帰時に lb-phone が window.components （GameMap を含む）を注入しない。
    // 【削除方法】lb-phone がバックグラウンド復帰時にも window.components を注入するようになったら、
    //   deps を [] に戻し、setMapUnavailable の分岐と mapUnavailable の JSX を削除する。
    useEffect(() => {
        if (!isAppOpen) return
        if (!containerRef.current || !window.components?.GameMap) {
            // TODO(lb-phone-bug-workaround): lb-phone バグ回避処理。修正後に削除すること。
            // 【バグ内容】バックグラウンド復帰時に window.components が未注入のため GameMap が使えない。
            // 【削除方法】この if ブロック（setMapUnavailable(true) の分岐）を削除する。
            setMapUnavailable(true)
            return
        }
        setMapUnavailable(false)
        const gmap = new window.components.GameMap(containerRef.current, {
            allowMoving: true,
            defaultZoom: 3,
        })
        gameMapRef.current = gmap

        void gmap.ready.then(async () => {
            mapReadyRef.current = true

            // ①マップ・スタイルを先に復元（setShowSelf/センタリングより前に行わないと
            //   ズームアニメーション中に setMap が来て Leaflet がクラッシュする）
            const savedMap = localStorage.getItem(STORAGE_MAP)
            if (savedMap) gmap.setMap(savedMap)
            const savedStyle = localStorage.getItem(STORAGE_STYLE)
            if (savedStyle) gmap.setStyle(savedStyle)
            const savedZoom = localStorage.getItem(STORAGE_ZOOM)
            setHasStyles(gmap.getStyles().length > 1)

            // マウスホイール・ピンチ等によるズーム変更を localStorage に保存する
            gmap.map?.on('zoomend', () => {
                const zoom = gmap.getZoom()
                if (zoom != null) localStorage.setItem(STORAGE_ZOOM, String(zoom))
            })

            // ② setShowSelf の完了を待つ。
            //    lb-phone は内部でプレイヤー座標を取得してマップをパンするため、
            //    await せずに setPosition を呼ぶとそのパンに上書きされる。
            const selfTimeout = new Promise<void>(resolve => window.setTimeout(resolve, 2000))
            await Promise.race([gmap.setShowSelf(true), selfTimeout])

            if (!mapReadyRef.current) return

            // ③センタリング
            //   savedZoom がある場合はそれを使う（setZoom を別途呼ばない）
            const zoomLevel = savedZoom != null ? Number(savedZoom) : 4
            gmap.refreshLayout()
            if (readyRef.current) {
                gmap.setPosition({ x: selfXRef.current, y: selfYRef.current }, zoomLevel)
            } else {
                // getSelfPosition がまだ完了していない → ready useEffect に委譲
                pendingCenterZoomRef.current = zoomLevel
            }

            onMapReady(gmap)
        })

        return () => {
            mapReadyRef.current = false
            pendingCenterZoomRef.current = null
            friendMarkersRef.current = []
            postPinMarkerRef.current = null
            gmap.destroy()
            gameMapRef.current = null
            onMapReady(null)
        }
    // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [isAppOpen])

    // isActive が false → true に変わったとき Leaflet にサイズを再計算させる
    useEffect(() => {
        if (!isActive) return
        gameMapRef.current?.refreshLayout()
    }, [isActive])

    // フレンド・グループメンバーマーカーの更新
    useEffect(() => {
        const gmap = gameMapRef.current
        if (!gmap?.map || !gmap?.L || !mapReadyRef.current) return
        const { L, map } = gmap

        // 既存マーカーを全削除
        friendMarkersRef.current.forEach((m) => m.remove())
        friendMarkersRef.current = []

        for (const friend of filteredFriendsMap) {
            const color = friend.isFriend === false ? '#0891b2' : markerColorByMode(friend.ghostMode)
            const label = `${friend.displayName} ${friend.isFriend === false ? 'G' : ghostModeBadge(friend.ghostMode)}`
            const marker = L.circleMarker([friend.y, friend.x], {
                radius: 8,
                fillColor: color,
                color: '#ffffff',
                weight: 2,
                fillOpacity: 1,
            })
                .bindTooltip(label, { permanent: true, direction: 'top', offset: [0, -8] })
                .on('click', () => onFriendClick(friend.playerId))
                .addTo(map)

            friendMarkersRef.current.push(marker)
        }
    }, [filteredFriendsMap, onFriendClick])

    // ポストピンマーカーの更新
    useEffect(() => {
        const gmap = gameMapRef.current
        if (!gmap?.map || !gmap?.L || !mapReadyRef.current) return
        const { L, map } = gmap

        postPinMarkerRef.current?.remove()
        postPinMarkerRef.current = null

        if (!focusedPostPin) return

        postPinMarkerRef.current = L.circleMarker([focusedPostPin.y, focusedPostPin.x], {
            radius: 11,
            fillColor: '#f43f5e',
            color: '#ffffff',
            weight: 2,
            fillOpacity: 1,
        })
            .bindTooltip(t('map.post_pin_label', { name: focusedPostPin.displayName }), {
                permanent: true,
                direction: 'top',
                offset: [0, -8],
            })
            .addTo(map)
    }, [focusedPostPin, t])

    // onFriendClick は useCallback で安定させる必要があるため、
    // AppShell 側で安定した参照を渡してもらうことを前提とする。
    // ここでは ref を使って最新の callback を参照する回避策は行わない（props の安定性に依存）。

    const handleRecenter = useCallback(() => {
        onRecenterToSelf()
    }, [onRecenterToSelf])

    const handleCycleMap = useCallback(() => {
        const gmap = gameMapRef.current
        if (!gmap) return
        const newMap = gmap.cycleMap()
        if (newMap != null) localStorage.setItem(STORAGE_MAP, newMap)
        // マップが変わるとスタイル選択肢も変わるため保存値をクリア
        localStorage.removeItem(STORAGE_STYLE)
        setHasStyles(gmap.getStyles().length > 1)
    }, [])

    const handleCycleStyle = useCallback(() => {
        const gmap = gameMapRef.current
        if (!gmap) return
        const newStyle = gmap.cycleStyle()
        if (newStyle != null) localStorage.setItem(STORAGE_STYLE, newStyle)
    }, [])

    const handleZoomIn = useCallback(() => {
        const gmap = gameMapRef.current
        if (!gmap) return
        const current = gmap.getZoom()
        if (current == null) return
        const max = gmap.map?.getMaxZoom() ?? 8
        const next = Math.min(current + 1, max)
        gmap.setZoom(next)
        localStorage.setItem(STORAGE_ZOOM, String(next))
    }, [])

    const handleZoomOut = useCallback(() => {
        const gmap = gameMapRef.current
        if (!gmap) return
        const current = gmap.getZoom()
        if (current == null) return
        const min = gmap.map?.getMinZoom() ?? 0
        const next = Math.max(current - 1, min)
        gmap.setZoom(next)
        localStorage.setItem(STORAGE_ZOOM, String(next))
    }, [])

    return (
        // isActive=false のとき display:none で隠す。unmount しないことで GameMap インスタンスを保持し、
        // タブ切り替えによる地図位置リセットを防ぐ。
        <section className="map-card" style={{ display: isActive ? undefined : 'none' }}>
            {mapUnavailable ? (
                // TODO(lb-phone-bug-workaround): lb-phone バグ回避処理。修正後に削除すること。
                // 【バグ内容】バックグラウンド復帰時に window.components が未注入で GameMap が初期化できない。
                // 【削除方法】この三項演算全体（mapUnavailable ブロックと <> ブロック）を <> ブロックの内容だけに戴ける。
                <div className="map map--unavailable">
                    <p>{t('map.unavailable')}</p>
                </div>
            ) : (
                <>
                    <div className="map-controls">
                        <div className="filter-bar">
                            <label htmlFor="view-filter">{t('timeline.filter.label')}</label>
                            <select
                                id="view-filter"
                                value={viewFilter === 'group' ? `group:${selectedGroupId ?? ''}` : viewFilter}
                                onChange={(event) => onApplyViewFilter(event.target.value)}
                            >
                                <option value="all">{t('timeline.filter.all')}</option>
                                <option value="friends">{t('timeline.filter.friends')}</option>
                                {groups.map((group) => (
                                    <option key={group.id} value={`group:${group.id}`}>
                                        {t('timeline.filter.group_prefix')}{group.name}
                                    </option>
                                ))}
                            </select>
                        </div>
                    </div>

            {/* lb-phone GameMap のマウントポイント */}
                    <div ref={containerRef} className="map" />

                    {/* components.GameMap が利用できない開発環境向けプレースホルダー */}
                    {typeof window !== 'undefined' && !window.components?.GameMap && (
                        <div className="map map--placeholder">
                            <span>Map (dev mode)</span>
                        </div>
                    )}

                    {/* マップ・スタイル切り替え・現在地ボタン（右下） */}
                    <div className="map-fab-group">
                {hasStyles && (
                    <button type="button" className="map-fab" onClick={handleCycleStyle}>
                        <i className="fa-solid fa-layer-group" aria-hidden="true" />
                    </button>
                )}
                <button type="button" className="map-fab" onClick={handleCycleMap}>
                    <i className="fa-solid fa-globe" aria-hidden="true" />
                </button>
                {/* ズームボタン */}
                <button type="button" className="map-fab" onClick={handleZoomIn}>
                    <i className="fa-solid fa-plus" aria-hidden="true" />
                </button>
                <button type="button" className="map-fab" onClick={handleZoomOut}>
                    <i className="fa-solid fa-minus" aria-hidden="true" />
                </button>
                {ready && (
                    <button type="button" className="map-fab" onClick={handleRecenter}>
                        <i className="fa-solid fa-location-crosshairs" aria-hidden="true" />
                    </button>
                )}
            </div>
                </>
            )}
        </section>
    )
}
