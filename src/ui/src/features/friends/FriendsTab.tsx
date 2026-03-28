/**
 * フレンド一覧タブコンポーネント。
 * 承認済みフレンド・ブロック中フレンド・未対応申請の3リストを表示する。
 * フレンド詳細ダイアログ / ブロック解除 / 申請承認辞退の操作もここから呼び出される。
 */
import { ghostModeLabel, moveStatusLabel } from '../shared/presentation'
import { useT } from '../shared/locale'
import type { FriendSummary, PendingRequest } from '../shared/types'

type FriendsTabProps = {
    friendsList: FriendSummary[]
    pendingRequests: PendingRequest[]
    onOpenAddFriend: () => void
    onOpenFriendDetail: (friendId: string) => void
    onUnblockFriend: (playerId: string) => void
    onRespondRequest: (requestId: number, accept: boolean) => void
}

export function FriendsTab({
    friendsList,
    pendingRequests,
    onOpenAddFriend,
    onOpenFriendDetail,
    onUnblockFriend,
    onRespondRequest,
}: FriendsTabProps) {
    const t = useT()
    return (
        <section className="friends-card">
            <div className="friends-header-row">
                <h2>{t('friends.title')}</h2>
                <button type="button" onClick={onOpenAddFriend}>
                    {t('friends.add_btn')}
                </button>
            </div>

            <div className="friends-list">
                {friendsList.length === 0 && <p className="muted">{t('friends.empty')}</p>}
                {friendsList.map((friend) => (
                    <div key={friend.playerId} className="friend-item">
                        <div className="friend-main">
                            <strong>{friend.displayName}</strong>
                            <span>
                                {friend.relation === 'blocked'
                                    ? t('friends.blocked_status')
                                    : `${friend.isOnline ? t('common.online') : t('common.offline')} / ${ghostModeLabel(friend.ghostMode, t)} / ${moveStatusLabel(friend.moveStatus, t)}`}
                            </span>
                        </div>

                        <div className="friend-item-actions">
                            {friend.relation === 'accepted' ? (
                                <button type="button" className="friend-mini-btn" onClick={() => onOpenFriendDetail(friend.playerId)}>
                                    {t('friends.detail_btn')}
                                </button>
                            ) : (
                                <button type="button" className="friend-mini-btn" onClick={() => onUnblockFriend(friend.playerId)}>
                                    {t('friends.unblock_btn')}
                                </button>
                            )}
                        </div>
                    </div>
                ))}
            </div>

            <div className="pending-wrap">
                <h3>{t('friends.pending.title')}</h3>
                {pendingRequests.length === 0 && <p className="muted">{t('friends.pending.empty')}</p>}
                {pendingRequests.map((req) => (
                    <div key={req.requestId} className="pending-item">
                        <div>
                            <strong>{req.fromName}</strong>
                            <span>{req.isOnline ? t('common.online') : t('common.offline')}</span>
                        </div>
                        <div className="row-actions">
                            <button type="button" onClick={() => onRespondRequest(req.requestId, true)}>
                                {t('friends.accept_btn')}
                            </button>
                            <button type="button" className="danger-ghost" onClick={() => onRespondRequest(req.requestId, false)}>
                                {t('friends.decline_btn')}
                            </button>
                        </div>
                    </div>
                ))}
            </div>
        </section>
    )
}
