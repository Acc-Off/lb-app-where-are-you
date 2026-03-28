/**
 * フレンド追加モーダルコンポーネント。
 * 近距離候補一覧と ID/名前検索結果を表示し、フレンド申請・ブロック解除操作を提供する。
 */
import type { NearbyCandidate, SearchPlayer } from '../shared/types'
import { useT } from '../shared/locale'

type FriendAddModalProps = {
    isOpen: boolean
    nearbyCandidates: NearbyCandidate[]
    searchQuery: string
    searchResults: SearchPlayer[]
    onClose: () => void
    onSearchQueryChange: (value: string) => void
    onSearch: () => void
    onSendRequest: (serverId: number) => void
    onUnblockFriend: (playerId: string) => void
}

export function FriendAddModal({
    isOpen,
    nearbyCandidates,
    searchQuery,
    searchResults,
    onClose,
    onSearchQueryChange,
    onSearch,
    onSendRequest,
    onUnblockFriend,
}: FriendAddModalProps) {
    const t = useT()
    if (!isOpen) return null

    return (
        <section className="modal-overlay" onClick={onClose}>
            <article className="modal-card" onClick={(event) => event.stopPropagation()}>
                <h3>{t('friend.add.title')}</h3>

                <h4>{t('friend.add.nearby.title')}</h4>
                <div className="stack-list">
                    {nearbyCandidates.length === 0 && <p className="muted">{t('friend.add.nearby.empty')}</p>}
                    {nearbyCandidates.map((candidate) => (
                        <div key={candidate.playerId} className="inline-item">
                            <span>
                                {candidate.displayName} ({candidate.distance}m)
                            </span>
                            <button type="button" onClick={() => onSendRequest(candidate.serverId)}>
                                {t('friend.add.request_btn')}
                            </button>
                        </div>
                    ))}
                </div>

                <h4>{t('friend.add.search.title')}</h4>
                <div className="search-row">
                    <input value={searchQuery} onChange={(event) => onSearchQueryChange(event.target.value)} placeholder={t('friend.add.search.placeholder')} />
                    <button type="button" onClick={onSearch}>
                        {t('friend.add.search.btn')}
                    </button>
                </div>

                <div className="stack-list">
                    {searchResults.map((row) => (
                        <div key={row.playerId} className="inline-item">
                            <span>[{row.serverId}] {row.displayName}</span>
                            {row.relation === 'blocked' ? (
                                <button type="button" onClick={() => onUnblockFriend(row.playerId)}>
                                    {t('friend.add.unblock_btn')}
                                </button>
                            ) : row.relation === 'none' ? (
                                <button type="button" onClick={() => onSendRequest(row.serverId)}>
                                    {t('friend.add.request_btn')}
                                </button>
                            ) : null}
                            {row.relation === 'pending' && <span className="mini-tag">{t('friend.add.pending_tag')}</span>}
                            {row.relation === 'blocked' && <span className="mini-tag">{t('friend.add.blocked_tag')}</span>}
                        </div>
                    ))}
                </div>
            </article>
        </section>
    )
}
