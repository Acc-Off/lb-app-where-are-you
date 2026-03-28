/**
 * 設定タブコンポーネント。
 * 近距離通知設定・判定半径・チェック間隔の変更、グループ設定ページへの移動、退会ボタンを表示する。
 */
import type { AppSettings } from '../shared/types'
import { useT } from '../shared/locale'
import { resetTutorial, startTutorial } from '../tutorial/useTutorial'

type SettingsTabProps = {
    appSettings: AppSettings
    onAppSettingsChange: (updater: (prev: AppSettings) => AppSettings) => void
    onSave: () => void
    onOpenDeleteAccount: () => void
    /** チュートリアル再表示（ロケールを渡すためコールバック化） */
    onRestartTutorial: () => void
}

export function SettingsTab({ appSettings, onAppSettingsChange, onSave, onOpenDeleteAccount, onRestartTutorial }: SettingsTabProps) {
    const t = useT()
    return (
        <section className="friends-card settings-card">
            <div className="friends-header-row">
                <h2>{t('settings.title')}</h2>
            </div>

            <div className="settings-list">
                <label className="settings-row">
                    <span>{t('settings.nearby.notify')}</span>
                    <input
                        type="checkbox"
                        checked={appSettings.nearbyNotifyEnabled}
                        onChange={(event) => {
                            onAppSettingsChange((prev) => ({ ...prev, nearbyNotifyEnabled: event.target.checked }))
                        }}
                    />
                </label>

                <label className="settings-row">
                    <span>{t('settings.nearby.radius')}</span>
                    <input
                        type="number"
                        min={20}
                        max={1000}
                        value={appSettings.nearbyRadius}
                        onChange={(event) => {
                            onAppSettingsChange((prev) => ({ ...prev, nearbyRadius: Number(event.target.value) }))
                        }}
                    />
                </label>

                <label className="settings-row">
                    <span>{t('settings.nearby.interval')}</span>
                    <input
                        type="number"
                        min={0.5}
                        max={10}
                        step={0.5}
                        value={Math.round(appSettings.nearbyIntervalMs / 600) / 100}
                        onChange={(event) => {
                            onAppSettingsChange((prev) => ({ ...prev, nearbyIntervalMs: Math.round(Number(event.target.value) * 60000) }))
                        }}
                    />
                </label>
            </div>

            <div className="row-actions">
                <button type="button" className="primary" onClick={onSave}>{t('settings.save_btn')}</button>
            </div>

            <div className="row-actions" style={{ marginTop: '1.5rem', borderTop: '1px solid var(--border-color, #333)', paddingTop: '1rem' }}>
                <button
                    type="button"
                    className="secondary"
                    onClick={onRestartTutorial}
                >
                    {t('settings.tutorial_btn')}
                </button>
            </div>

            <div className="row-actions" style={{ marginTop: '1.5rem', borderTop: '1px solid var(--border-color, #333)', paddingTop: '1rem' }}>
                <button type="button" className="danger" onClick={onOpenDeleteAccount}>{t('settings.delete_account_btn')}</button>
            </div>
        </section>
    )
}
