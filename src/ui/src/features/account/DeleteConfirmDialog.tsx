/**
 * 削除確認ダイアログコンポーネント。
 * 投稿 / リアクション / アカウント退会の3種類の削除確認を共有ダイアログで対応する。
 * deleteTarget の type に応じたメッセージを表示する。
 */
import { useT } from '../shared/locale'
type DeleteTarget =
    | { type: 'post'; postId: number }
    | { type: 'reaction'; reactionId: number; postId: number }
    | { type: 'account' }
    | null

type DeleteConfirmDialogProps = {
    deleteDialogRef: React.RefObject<HTMLDialogElement>
    deleteTarget: DeleteTarget
    onClose: () => void
    onExecute: () => void
}

export function DeleteConfirmDialog({ deleteDialogRef, deleteTarget, onClose, onExecute }: DeleteConfirmDialogProps) {
    const t = useT()
    return (
        <dialog
            ref={deleteDialogRef}
            className="app-dialog"
            onClick={(e) => { if (e.target === e.currentTarget) onClose() }}
        >
            {deleteTarget && (
                <div className="dialog-body">
                    <h3>
                        {deleteTarget.type === 'account'
                            ? t('delete.title.account')
                            : deleteTarget.type === 'post'
                            ? t('delete.title.post')
                            : t('delete.title.reaction')}
                    </h3>
                    <p>
                        {deleteTarget.type === 'account'
                            ? t('delete.desc.account')
                            : t('delete.desc.generic')}
                    </p>
                    <div className="dialog-actions confirm-row">
                        <button type="button" className="dialog-btn" onClick={onClose}>{t('btn.cancel')}</button>
                        <button type="button" className="dialog-btn danger" onClick={onExecute}>{t('delete.ok_btn')}</button>
                    </div>
                </div>
            )}
        </dialog>
    )
}
