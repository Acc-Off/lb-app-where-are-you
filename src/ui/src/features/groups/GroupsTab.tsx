/**
 * グループ一覧タブコンポーネント。
 * 参加中グループの一覧、メンバー数、退出ボタンを表示する。
 */
import type { GroupItem } from '../shared/types'
import { useT } from '../shared/locale'

type GroupsTabProps = {
    groups: GroupItem[]
    onRefresh: () => void
    onOpenAddGroup: () => void
    onLeaveGroup: (groupId: number) => void
}

export function GroupsTab({ groups, onRefresh, onOpenAddGroup, onLeaveGroup }: GroupsTabProps) {
    const t = useT()
    return (
        <section className="friends-card">
            <div className="friends-header-row">
                <h2>{t('groups.title')}</h2>
                <div className="header-actions">
                    <button type="button" onClick={onRefresh}>{t('groups.refresh_btn')}</button>
                    <button type="button" className="primary" onClick={onOpenAddGroup}>{t('groups.add_btn')}</button>
                </div>
            </div>

            <div className="friends-list">
                {groups.length === 0 && <p className="muted">{t('groups.empty')}</p>}
                {groups.map((group) => (
                    <div key={group.id} className="friend-item">
                        <div className="friend-main">
                            <strong>{group.name}</strong>
                            <span className="group-member-summary">
                                {t('groups.online_label')} {group.onlineCount ?? 0}{t('groups.people_unit')} {' / '} {t('groups.offline_label')} {group.offlineCount ?? 0}{t('groups.people_unit')}
                                {group.members && group.members.length > 0 && <>　{group.members.map((m) => m.displayName).join('・')}</>}
                            </span>
                        </div>
                        <div className="friend-item-actions">
                            <button type="button" className="friend-mini-btn" onClick={() => onLeaveGroup(group.id)}>{t('groups.leave_btn')}</button>
                        </div>
                    </div>
                ))}
            </div>
        </section>
    )
}
