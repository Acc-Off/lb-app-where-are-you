/**
 * グループ参加・作成モーダルコンポーネント。
 * グループ名とパスワードを入力し、参加 or 新規作成を実行する。
 */
import { useT } from '../shared/locale'

type GroupJoinModalProps = {
    isOpen: boolean
    groupNameInput: string
    groupPasswordInput: string
    /** 参加/作成失敗時のエラーメッセージ（親コンポーネントから注入） */
    errorMessage?: string
    onClose: () => void
    onGroupNameChange: (value: string) => void
    onGroupPasswordChange: (value: string) => void
    onSubmit: () => void
}

export function GroupJoinModal({
    isOpen,
    groupNameInput,
    groupPasswordInput,
    errorMessage,
    onClose,
    onGroupNameChange,
    onGroupPasswordChange,
    onSubmit,
}: GroupJoinModalProps) {
    const t = useT()
    if (!isOpen) return null

    return (
        <section className="modal-overlay" onClick={onClose}>
            <article className="modal-card" onClick={(event) => event.stopPropagation()}>
                <h3>{t('group.modal.title')}</h3>
                <div className="group-join-form">
                    <input value={groupNameInput} onChange={(event) => onGroupNameChange(event.target.value)} placeholder={t('group.modal.name_placeholder')} />
                    <input value={groupPasswordInput} onChange={(event) => onGroupPasswordChange(event.target.value)} placeholder={t('group.modal.password_placeholder')} />
                </div>
                {/* エラーメッセージ表示エリア（参加失敗・名前未入力など） */}
                {errorMessage && <p className="error-text">{errorMessage}</p>}
                <div className="row-actions">
                    <button type="button" onClick={onClose}>{t('btn.cancel')}</button>
                    <button type="button" className="primary" onClick={onSubmit}>{t('group.modal.submit_btn')}</button>
                </div>
            </article>
        </section>
    )
}
