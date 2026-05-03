/**
 * リアクション送信モーダルコンポーネント。
 * 絵文字スタンプ選択・ヒトコトテキスト入力・送信ボタンを提供する。
 */
import { useT } from '../shared/locale'
type ReactionModalProps = {
    isOpen: boolean
    reactionStamp: string
    reactionMessage: string
    onClose: () => void
    onPickStamp: () => void
    onMessageChange: (value: string) => void
    onSubmit: () => void
}

export function ReactionModal({
    isOpen,
    reactionStamp,
    reactionMessage,
    onClose,
    onPickStamp,
    onMessageChange,
    onSubmit,
}: ReactionModalProps) {
    const t = useT()
    if (!isOpen) return null

    return (
        <section className="modal-overlay" onClick={onClose}>
            <article className="modal-card" onClick={(event) => event.stopPropagation()}>
                <h3>{t('reaction.modal_title')}</h3>

                {/* スタンプボタンとひとこと入力を横並びに配置（B-3: 「絵文字を選択」ボタン廃止・スタンプ自体をクリック可能に） */}
                <div className="reaction-input-row">
                    <button
                        type="button"
                        className={`reaction-stamp-btn${reactionStamp === '' ? ' reaction-stamp-empty' : ''}`}
                        title={reactionStamp === '' ? t('reaction.stamp.select_title') : t('reaction.stamp.change_title')}
                        onClick={onPickStamp}
                    >
                        {reactionStamp === '' ? <i className="fa-solid fa-circle-minus" aria-hidden="true" /> : reactionStamp}
                    </button>
                    <input
                        value={reactionMessage}
                        onChange={(event) => onMessageChange(event.target.value)}
                        maxLength={120}
                        placeholder={t('reaction.message_placeholder')}
                    />
                </div>

                <div className="row-actions">
                    <button type="button" className="danger-ghost" onClick={onClose}>{t('btn.cancel')}</button>
                    <button type="button" className="primary" onClick={onSubmit}>{t('reaction.submit_btn')}</button>
                </div>
            </article>
        </section>
    )
}
