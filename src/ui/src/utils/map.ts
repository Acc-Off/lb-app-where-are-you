/**
 * GTA5 Los Santos 座標系のユーティリティ。
 * 座標クランプ機能を提供する（Leaflet 依存を持たない）。
 */

export type MapPosition = {
    x: number
    y: number
    z: number
    heading: number
    speed: number
    updatedAt: number
}

export const MAP_BOUNDS = {
    topLeft: { x: -4140, y: 8400 },
    bottomRight: { x: 4860, y: -5100 },
}

/**
 * 座標をマップ境界内にクランプする。
 * MAP_BOUNDS 外側の座標を持つプレイヤーが地図外の位置に置かれないようにする。
 */
export function clampPosition(pos: MapPosition): MapPosition {
    return {
        ...pos,
        x: Math.max(MAP_BOUNDS.topLeft.x, Math.min(MAP_BOUNDS.bottomRight.x, pos.x)),
        y: Math.max(MAP_BOUNDS.bottomRight.y, Math.min(MAP_BOUNDS.topLeft.y, pos.y)),
    }
}
