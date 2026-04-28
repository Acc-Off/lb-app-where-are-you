/**
 * タブバーに表示するタブ項目の定義。
 * id は Tab型の値。
 */
import type { Tab } from '../features/shared/types'

export const tabItems: Array<{ id: Tab }> = [
    { id: 'map' },
    { id: 'timeline' },
    { id: 'friends' },
    { id: 'groups' },
    { id: 'settings' },
]
