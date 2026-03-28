/**
 * タブバーナビゲーションコンポーネント。
 * tabs.ts の tabItems に従ってタブボタンを並べ、アクティブタブに active クラスを付与する。
 * 行情報を使用して複数行レイアウトに対応。
 */
import { tabItems } from '../../../app/tabs'
import { useT } from '../locale'
import type { Tab } from '../types'

type TabBarProps = {
    activeTab: Tab
    onChange: (tab: Tab) => void
}

export function TabBar({ activeTab, onChange }: TabBarProps) {
    const t = useT()
    // 行ごとにタブをグループ化
    const tabsByRow = tabItems.reduce(
        (acc, tab) => {
            if (!acc[tab.row]) {
                acc[tab.row] = []
            }
            acc[tab.row].push(tab)
            return acc
        },
        {} as Record<number, typeof tabItems>
    )

    return (
        <nav className="tabbar">
            {Object.keys(tabsByRow)
                .sort((a, b) => Number(a) - Number(b))
                .map((row) => (
                    <div key={row} className="tabbar-row">
                        {tabsByRow[Number(row)].map((tab) => (
                            <button
                                key={tab.id}
                                id={`tab-${tab.id}`}
                                type="button"
                                className={activeTab === tab.id ? 'active' : ''}
                                onClick={() => onChange(tab.id)}
                            >
                                {/* tab_map / tab_friends 等のキーで取得する */}
                                {t(`tab.${tab.id}`)}
                            </button>
                        ))}
                    </div>
                ))}
        </nav>
    )
}
