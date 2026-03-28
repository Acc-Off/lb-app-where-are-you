/**
 * 地図機能固有の型定義。
 * FocusedPostPin: タイムラインから地図へジャンプする際に使用する一時ピン情報。
 */
export type FocusedPostPin = {
    postId: number
    x: number
    y: number
    displayName: string
}
