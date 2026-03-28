/**
 * GTA5 Los Santos座標系と Leaflet CRS の変換ユーティリティ。
 * ニャップ・座標クランプ・パスカスタムCRS作成機能を提供する。
 */
import L from 'leaflet'

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

// ローカル minimap 6枚(3072x3072)を 2列 x 3行で合成した実寸。
// ここがタイル生成時の前提と一致していないと、ピン位置が地図とズレる。
const IMAGE_WIDTH = 6144
const IMAGE_HEIGHT = 9216
// 6144x9216 から計算される実用ズーム上限は 6。
export const MAX_ZOOM = 6
export const MIN_ZOOM = 2

export const mapMaxBounds = L.latLngBounds(
    [MAP_BOUNDS.bottomRight.y, MAP_BOUNDS.topLeft.x],
    [MAP_BOUNDS.topLeft.y, MAP_BOUNDS.bottomRight.x]
)

export const mapCenter = {
    x: (MAP_BOUNDS.topLeft.x + MAP_BOUNDS.bottomRight.x) / 2,
    y: (MAP_BOUNDS.topLeft.y + MAP_BOUNDS.bottomRight.y) / 2,
}

/**
 * Los Santos座標系に対応するカスタム Leaflet CRS を生成する。
 * GTA5ワールド座標の范囲とタイル画像解像度からスケールファクタを計算し、
 * ピンが正確な座標に置かれるように変換行列を設定する。
 */
export function createLosSantosCrs(): L.CRS {
    const worldWidth = MAP_BOUNDS.bottomRight.x - MAP_BOUNDS.topLeft.x
    const worldHeight = MAP_BOUNDS.bottomRight.y - MAP_BOUNDS.topLeft.y
    const scale = 2 ** MAX_ZOOM

    const u = IMAGE_WIDTH / (worldWidth * scale)
    const d = IMAGE_HEIGHT / (worldHeight * scale)

    return L.extend({}, L.CRS.Simple, {
        projection: L.Projection.LonLat,
        transformation: new L.Transformation(
            u,
            -u * MAP_BOUNDS.topLeft.x,
            d,
            -d * MAP_BOUNDS.topLeft.y
        ),
        scale: (zoom: number) => 2 ** zoom,
        zoom: (scaleValue: number) => Math.log(scaleValue) / Math.LN2,
        wrapLng: [MAP_BOUNDS.topLeft.x, MAP_BOUNDS.bottomRight.x],
        wrapLat: [MAP_BOUNDS.bottomRight.y, MAP_BOUNDS.topLeft.y],
        infinite: false,
    }) as L.CRS
}

/**
 * 座標をマップ隣境内にクランプする。
 * MAP_BOUNDS外側の座標を持つプレイヤーが地図外の位置に置かれないようにする。
 */
export function clampPosition(pos: MapPosition): MapPosition {
    return {
        ...pos,
        x: Math.max(MAP_BOUNDS.topLeft.x, Math.min(MAP_BOUNDS.bottomRight.x, pos.x)),
        y: Math.max(MAP_BOUNDS.bottomRight.y, Math.min(MAP_BOUNDS.topLeft.y, pos.y)),
    }
}
