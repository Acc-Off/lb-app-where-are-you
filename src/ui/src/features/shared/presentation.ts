/**
 * 表示用ユーティリティ。
 * ゴーストモードラベル / 移動ステータスラベル / 相対時刻表示など、UI層で使用する文字列変換関数を提供する。
 * ghostModeLabel / moveStatusLabel / relativeTime はロケール対応のため t() コールバックを受け取る。
 */
import type { GhostMode } from './types'

/** 翻訳コールバックの型。useT() フックが返す関数と同じシグネチャ。 */
type TFn = (key: string) => string

/** 移動ステータスをラベルに変換する。t を渡すとロケールから取得する。 */
export function moveStatusLabel(status: 'idle' | 'walk' | 'vehicle', t?: TFn): string {
    if (status === 'vehicle') return t?.('move.vehicle') ?? 'move.vehicle'
    if (status === 'walk') return t?.('move.walk') ?? 'move.walk'
    return t?.('move.idle') ?? 'move.idle'
}

/** DBの日時文字列を「たった今」「3分前」等の相対時刻表示文字列に変換する。t を渡すとロケールから取得する。 */
export function relativeTime(dateStr: string, t?: TFn): string {
    const now = Date.now()
    const then = new Date(dateStr).getTime()
    if (isNaN(then)) return dateStr
    const diffMs = now - then
    const diffMin = Math.floor(diffMs / 60000)
    if (diffMin < 1) return t?.('time.just_now') ?? 'time.just_now'
    if (diffMin < 60) {
        const fmt = t?.('time.minutes_ago') ?? 'time.minutes_ago'
        return fmt.replace('{n}', String(diffMin))
    }
    const diffH = Math.floor(diffMin / 60)
    if (diffH < 24) {
        const fmt = t?.('time.hours_ago') ?? 'time.hours_ago'
        return fmt.replace('{n}', String(diffH))
    }
    const diffD = Math.floor(diffH / 24)
    const fmt = t?.('time.days_ago') ?? 'time.days_ago'
    return fmt.replace('{n}', String(diffD))
}

/** ゴーストモードをラベル文字列に変換する。t を使ってロケールから ghost.mode.{mode} を取得する。 */
export function ghostModeLabel(mode: GhostMode, t: TFn): string {
    return t(`ghost.mode.${mode}`)
}

/** ゴーストモードをアイコン文字列（絵文字・記号）に変換する。 */
export function ghostModeBadge(mode: GhostMode): string {
    if (mode === 'freeze') return '👻'
    if (mode === 'blur') return '〜'
    if (mode === 'off') return 'OFF'
    return '●'
}

/** ゴーストモードに応じたマーカー色コードを返す。地図上の CircleMarker の fillColor に使用する。 */
export function markerColorByMode(mode: GhostMode): string {
    if (mode === 'freeze') return '#6b7280'
    if (mode === 'blur') return '#0ea5e9'
    return '#16a34a'
}
