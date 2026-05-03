/**
 * アプリヘッダーコンポーネント。
 * ゴーストモードバッジ・ラベルの表示と
 * ゴーストシートを開くボタンを提供する。
 */
import { ghostModeIconClass, ghostModeLabel } from '../presentation'
import { useT } from '../locale'
import type { GhostMode } from '../types'

type HeaderProps = {
    consentGiven: boolean
    ghostMode: GhostMode
    onOpenGhostSheet: () => void
}

export function Header({ consentGiven, ghostMode, onOpenGhostSheet }: HeaderProps) {
    const t = useT()
    return (
        <header className="header">
            <div className="title-wrap">
                <h1>WhereAreYou?</h1>
                <p>{consentGiven ? t('header.subtitle_active') : t('header.subtitle_consent')}</p>
            </div>
            <button id="tutorial-ghost-btn" className="status-pill" type="button" onClick={onOpenGhostSheet}>
                <i className={ghostModeIconClass(ghostMode)} aria-hidden="true" />{' '}{ghostModeLabel(ghostMode, t)}
            </button>
        </header>
    )
}
