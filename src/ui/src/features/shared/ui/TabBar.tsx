/**
 * タブバーナビゲーションコンポーネント。
 * ボタンは SVG アイコンのみ表示する。
 */
import type { Tab } from '../types'

const TAB_IDS: Tab[] = ['map', 'timeline', 'friends', 'groups', 'settings']

type TabBarProps = {
    activeTab: Tab
    onChange: (tab: Tab) => void
}

const TAB_ICONS: Record<Tab, JSX.Element> = {
    map:      <i className="fa-solid fa-map-location-dot" aria-hidden="true" />,
    timeline: <i className="fa-solid fa-list"             aria-hidden="true" />,
    friends:  <i className="fa-solid fa-user"             aria-hidden="true" />,
    groups:   <i className="fa-solid fa-users"            aria-hidden="true" />,
    settings: <i className="fa-solid fa-gear"             aria-hidden="true" />,
}

export function TabBar({ activeTab, onChange }: TabBarProps) {
    return (
        <nav className="tabbar">
            <div className="tabbar-row">
                {TAB_IDS.map((id) => (
                    <button
                        key={id}
                        id={`tab-${id}`}
                        type="button"
                        className={activeTab === id ? 'active' : ''}
                        onClick={() => onChange(id)}
                    >
                        {TAB_ICONS[id]}
                    </button>
                ))}
            </div>
        </nav>
    )
}
