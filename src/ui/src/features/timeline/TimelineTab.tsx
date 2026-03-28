/**
 * タイムラインタブコンポーネント。
 * フィルターセレクト / チェックイン投稿フォーム / 投稿一覧・リアクションを表示する。
 * 地図ジャンプボタン・リアクションポップアップ・ディレクト削除操作のコールバックも受け取る。
 */
import { relativeTime } from './timeline.time'
import { useT } from '../shared/locale'
import type { GroupItem, TimelinePost, ViewFilterType } from '../shared/types'

type TimelineTabProps = {
    viewFilter: ViewFilterType
    selectedGroupId: number | null
    groups: GroupItem[]
    checkinContent: string
    /** [B-8] チェックイン投稿失敗時のエラーメッセージ。null の場合は非表示。 */
    checkinError: string | null
    timelinePosts: TimelinePost[]
    selfPlayerId: string
    onApplyViewFilter: (value: string) => void
    onRefresh: () => void
    onCheckinContentChange: (value: string) => void
    onCreateCheckin: () => void
    onJumpToPost: (post: TimelinePost) => void
    onOpenReactionModal: (postId: number) => void
    onDeletePost: (postId: number) => void
    onDeleteReaction: (reactionId: number, postId: number) => void
}

export function TimelineTab({
    viewFilter,
    selectedGroupId,
    groups,
    checkinContent,
    checkinError,
    timelinePosts,
    selfPlayerId,
    onApplyViewFilter,
    onRefresh,
    onCheckinContentChange,
    onCreateCheckin,
    onJumpToPost,
    onOpenReactionModal,
    onDeletePost,
    onDeleteReaction,
}: TimelineTabProps) {
    const t = useT()
    return (
        <section className="friends-card">
            <div className="friends-header-row">
                <h2>{t('timeline.title')}</h2>
                <button type="button" onClick={onRefresh}>{t('timeline.refresh_btn')}</button>
            </div>

            <div className="timeline-filter-row">
                <label htmlFor="timeline-view-filter">{t('timeline.filter.label')}</label>
                <select
                    id="timeline-view-filter"
                    value={viewFilter === 'group' ? `group:${selectedGroupId ?? ''}` : viewFilter}
                    onChange={(event) => onApplyViewFilter(event.target.value)}
                >
                    <option value="all">{t('timeline.filter.all')}</option>
                    <option value="friends">{t('timeline.filter.friends')}</option>
                    {groups.map((group) => (
                        <option key={group.id} value={`group:${group.id}`}>
                            {t('timeline.filter.group_prefix')}{group.name}
                        </option>
                    ))}
                </select>
            </div>

            <div className="timeline-compose">
                <textarea
                    value={checkinContent}
                    onChange={(event) => onCheckinContentChange(event.target.value)}
                    maxLength={280}
                    placeholder={t('timeline.compose_placeholder')}
                />
                {/* [B-8] rate limited / 投稿エラーは UI 内に表示する */}
                {checkinError && <p className="checkin-error">{checkinError}</p>}
                <button type="button" className="primary" onClick={onCreateCheckin}>{t('timeline.post_btn')}</button>
            </div>

            <div className="timeline-list">
                {timelinePosts.length === 0 && <p className="muted">{t('timeline.empty')}</p>}
                {timelinePosts.map((post) => (
                    <article key={post.id} className="timeline-post">
                        <header className="timeline-post-header">
                            {/* 左側：名前 */}
                            <div className="timeline-post-title">
                                <strong>{post.displayName}</strong>
                            </div>
                            {/* 右側：時刻 + アクションアイコン群（順序: 時刻→削除→地図→返信） */}
                            <div className="timeline-post-actions">
                                <span className="timeline-time">{relativeTime(post.createdAt, t)}</span>
                                {post.playerId === selfPlayerId && (
                                    <button type="button" className="icon-btn danger" title={t('timeline.reaction_delete_btn')} onClick={() => onDeletePost(post.id)}>🗑️</button>
                                )}
                                <button type="button" className="icon-btn" title="地図で確認" onClick={() => onJumpToPost(post)}>📍</button>
                                <button type="button" className="icon-btn" title="リアクション" onClick={() => onOpenReactionModal(post.id)}>💬</button>
                            </div>
                        </header>
                        <p className="timeline-content">{post.content === '' ? t('timeline.no_text') : post.content}</p>

                        <div className="timeline-reactions">
                            {post.reactions.map((reaction) => (
                                <div key={reaction.id} className="reaction-row">
                                    <div className="reaction-text-wrap">
                                        <span className="reaction-author">{reaction.displayName ?? reaction.playerId}:</span>
                                        <span>
                                            {(reaction.stamp && reaction.stamp !== '') ? reaction.stamp : ''}
                                            {reaction.message ? ` ${reaction.message}` : ''}
                                        </span>
                                        <span className="reaction-time">{relativeTime(reaction.createdAt, t)}</span>
                                    </div>
                                    {reaction.playerId === selfPlayerId && (
                                        <button
                                            type="button"
                                            className="icon-btn-xs danger"
                                            title={t('timeline.reaction_delete_btn')}
                                            onClick={() => onDeleteReaction(reaction.id, post.id)}
                                        >
                                            {t('timeline.reaction_delete_btn')}
                                        </button>
                                    )}
                                </div>
                            ))}
                        </div>
                    </article>
                ))}
            </div>
        </section>
    )
}
