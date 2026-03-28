/**
 * 地図マーカーレイヤーコンポーネント。
 * 自分マーカー（オレンジ）・フレンド・グループメンバー（ゴーストモード色）・ポストピンを
 * Leaflet CircleMarker で描画する。フレンドクリック履年ランドラーも処理する。
 */
import { CircleMarker, Tooltip } from 'react-leaflet'
import type { LatLngExpression } from 'leaflet'
import { ghostModeBadge, markerColorByMode } from '../shared/presentation'
import { useT } from '../shared/locale'
import type { FriendMapItem } from '../shared/types'
import type { FocusedPostPin } from './map.types'

type MapMarkerLayerProps = {
    markerLatLng: LatLngExpression
    filteredFriendsMap: FriendMapItem[]
    focusedPostPin: FocusedPostPin | null
    onFriendClick: (playerId: string) => void
}

export function MapMarkerLayer({ markerLatLng, filteredFriendsMap, focusedPostPin, onFriendClick }: MapMarkerLayerProps) {
    const t = useT()
    return (
        <>
            <CircleMarker
                center={markerLatLng}
                radius={10}
                pathOptions={{
                    color: '#ffffff',
                    weight: 2,
                    fillColor: '#ff7f11',
                    fillOpacity: 1,
                }}
            >
                <Tooltip permanent direction="top" offset={[0, -8]}>
                    {t('map.self_label')}
                </Tooltip>
            </CircleMarker>

            {filteredFriendsMap.map((friend) => (
                <CircleMarker
                    key={friend.playerId}
                    center={[friend.y, friend.x]}
                    radius={8}
                    pathOptions={{
                        color: '#ffffff',
                        weight: 2,
                        fillColor: friend.isFriend === false ? '#0891b2' : markerColorByMode(friend.ghostMode),
                        fillOpacity: 1,
                    }}
                    eventHandlers={{ click: () => onFriendClick(friend.playerId) }}
                >
                    <Tooltip permanent direction="top" offset={[0, -8]}>
                        {friend.displayName} {friend.isFriend === false ? 'G' : ghostModeBadge(friend.ghostMode)}
                    </Tooltip>
                </CircleMarker>
            ))}

            {focusedPostPin && (
                <CircleMarker
                    center={[focusedPostPin.y, focusedPostPin.x]}
                    radius={11}
                    pathOptions={{
                        color: '#ffffff',
                        weight: 2,
                        fillColor: '#f43f5e',
                        fillOpacity: 1,
                    }}
                >
                    <Tooltip permanent direction="top" offset={[0, -8]}>
                        {t('map.post_pin_label', { name: focusedPostPin.displayName })}
                    </Tooltip>
                </CircleMarker>
            )}
        </>
    )
}
