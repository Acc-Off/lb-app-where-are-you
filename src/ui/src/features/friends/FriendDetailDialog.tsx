/**
 * フレンド詳細ダイアログコンポーネント。
 * フレンドのゴーストモード・移動ステータスを表示し、ブロック・削除の確認ダイアログを含む。
 * 2つの dialog（詳細・確認）をラップするコンポーネント。
 */
import { ghostModeLabel, moveStatusLabel } from '../shared/presentation'
import { useT } from '../shared/locale'
import type { FriendDetail } from '../shared/types'

type ConfirmAction = { type: 'block' | 'remove'; friend: FriendDetail } | null

type FriendDetailDialogProps = {
    detailDialogRef: React.RefObject<HTMLDialogElement>
    confirmDialogRef: React.RefObject<HTMLDialogElement>
    selectedFriend: FriendDetail | null
    confirmAction: ConfirmAction
    onCloseDetail: () => void
    onOpenConfirmDialog: (type: 'block' | 'remove', friend: FriendDetail) => void
    onCloseConfirmDialog: () => void
    onExecuteConfirmAction: () => void
}

export function FriendDetailDialog({
    detailDialogRef,
    confirmDialogRef,
    selectedFriend,
    confirmAction,
    onCloseDetail,
    onOpenConfirmDialog,
    onCloseConfirmDialog,
    onExecuteConfirmAction,
}: FriendDetailDialogProps) {
    const t = useT()
    return (
        <>
            <dialog ref={detailDialogRef} className="app-dialog" onClick={(e) => { if (e.target === e.currentTarget) onCloseDetail() }}>
                {selectedFriend && (
                    <div className="dialog-body">
                        <h3>{selectedFriend.displayName}</h3>
                        <p>
                            {selectedFriend.isOnline ? t('common.online') : t('common.offline')}
                            {' / '}{ghostModeLabel(selectedFriend.ghostMode, t)}
                            {' / '}{moveStatusLabel(selectedFriend.moveStatus, t)}
                        </p>
                        <p className="muted">
                            {t('friend.detail.relation.label')}{' '}
                            {selectedFriend.isFriend !== false
                                ? t('friend.detail.relation.friend')
                                : selectedFriend.sharedGroupNames && selectedFriend.sharedGroupNames.length > 0
                                ? t('friend.detail.relation.group_named', { groups: selectedFriend.sharedGroupNames.join('・') })
                                : t('friend.detail.relation.group_member')}
                        </p>
                        {selectedFriend.isFriend !== false && (
                            <div className="dialog-actions">
                                <button type="button" className="dialog-btn danger-outline" onClick={() => onOpenConfirmDialog('remove', selectedFriend)}>
                                    {t('friend.detail.remove.btn')}
                                </button>
                                <button type="button" className="dialog-btn" onClick={() => onOpenConfirmDialog('block', selectedFriend)}>
                                    {t('friend.detail.block.btn')}
                                </button>
                            </div>
                        )}
                        <form method="dialog">
                            <button type="submit" className="dialog-btn close-btn">{t('btn.close')}</button>
                        </form>
                    </div>
                )}
            </dialog>

            <dialog ref={confirmDialogRef} className="app-dialog" onClick={(e) => { if (e.target === e.currentTarget) onCloseConfirmDialog() }}>
                {confirmAction && (
                    <div className="dialog-body">
                        <h3>
                            {confirmAction.type === 'block'
                                ? t('friend.detail.block.title', { name: confirmAction.friend.displayName })
                                : t('friend.detail.remove.title', { name: confirmAction.friend.displayName })}
                        </h3>
                        <p>
                            {confirmAction.type === 'block'
                                ? t('friend.detail.block.desc')
                                : t('friend.detail.remove.desc')}
                        </p>
                        <div className="dialog-actions confirm-row">
                            <button type="button" className="dialog-btn" onClick={onCloseConfirmDialog}>
                                {t('btn.cancel')}
                            </button>
                            <button type="button" className="dialog-btn danger" onClick={onExecuteConfirmAction}>
                                {confirmAction.type === 'block'
                                    ? t('friend.detail.block.confirm_btn')
                                    : t('friend.detail.remove.confirm_btn')}
                            </button>
                        </div>
                    </div>
                )}
            </dialog>
        </>
    )
}
