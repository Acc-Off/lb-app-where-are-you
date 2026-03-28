/**
 * タブバーに表示するタブ項目の定義。
 * id は Tab型の値、row はグリッド行番号。
 */
import type { Tab } from '../features/shared/types'

export const tabItems: Array<{ id: Tab; row: number }> = [
    { id: 'map', row: 1 },
    { id: 'timeline', row: 1 },
    { id: 'friends', row: 2 },
    { id: 'groups', row: 2 },
    { id: 'settings', row: 2 },
]
