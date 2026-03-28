/**
 * 地図タブコンポーネント。
 * Leaflet React-Leaflet で GTA5 Los SantosのカスタムCRSマップを表示する。
 * 自分マーカー・フレンドマーカー・ポストピンをMapMarkerLayerコンポーネントに委譲する。
 */
import { useEffect } from 'react'
import type L from 'leaflet'
import type { LatLngExpression } from 'leaflet'
import { ZoomControl, MapContainer, TileLayer, useMap } from 'react-leaflet'
import { mapCenter, mapMaxBounds, MAX_ZOOM, MIN_ZOOM } from '../../utils/map'
import type { FriendMapItem, GroupItem, ViewFilterType } from '../shared/types'
import { MapMarkerLayer } from './MapMarkerLayer'
import type { FocusedPostPin } from './map.types'
import { useT } from '../shared/locale'

function BindMapInstance({ onReady }: { onReady: (map: L.Map | null) => void }) {
    const map = useMap()

    useEffect(() => {
        onReady(map)

        return () => {
            onReady(null)
        }
    }, [map, onReady])

    return null
}

type MapTabProps = {
    /** タブが現在アクティブかどうか。false の場合は display:none で非表示にする（unmount しない） */
    isActive: boolean
    crs: L.CRS
    tileUrl: string
    markerLatLng: LatLngExpression
    ready: boolean
    viewFilter: ViewFilterType
    selectedGroupId: number | null
    groups: GroupItem[]
    filteredFriendsMap: FriendMapItem[]
    focusedPostPin: FocusedPostPin | null
    onMapReady: (map: L.Map | null) => void
    onApplyViewFilter: (value: string) => void
    onRecenterToSelf: () => void
    onFriendClick: (playerId: string) => void
}

export function MapTab({
    isActive,
    crs,
    tileUrl,
    markerLatLng,
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
    return (
        // isActive=false のとき display:none で隠す。unmount しないことで Leaflet インスタンスを保持し、
        // タブ切り替えによる地図位置リセットを防ぐ。
        <section className="map-card" style={{ display: isActive ? undefined : 'none' }}>
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

            <MapContainer
                center={[mapCenter.y, mapCenter.x]}
                zoom={4}
                minZoom={MIN_ZOOM}
                maxZoom={MAX_ZOOM}
                crs={crs}
                maxBounds={mapMaxBounds}
                maxBoundsViscosity={1.0}
                zoomControl={false}
                className="map"
                attributionControl={false}
            >
                <TileLayer
                    url={tileUrl}
                    noWrap={true}
                    bounds={mapMaxBounds}
                    keepBuffer={0}
                    updateWhenIdle={true}
                />
                {/* [B-7] ズームコントロールを右下に移動してフィルターバーとの重なりを解消 */}
                <ZoomControl position="bottomright" />
                <BindMapInstance onReady={onMapReady} />
                <MapMarkerLayer
                    markerLatLng={markerLatLng}
                    filteredFriendsMap={filteredFriendsMap}
                    focusedPostPin={focusedPostPin}
                    onFriendClick={onFriendClick}
                />
            </MapContainer>

            {ready && (
                <button type="button" className="gps-fab" onClick={onRecenterToSelf}>
                    {t('map.recenter_btn')}
                </button>
            )}
        </section>
    )
}
