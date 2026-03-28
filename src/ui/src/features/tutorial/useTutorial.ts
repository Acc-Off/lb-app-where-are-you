/**
 * チュートリアルフック。
 * driver.js を使ってスポットライト付きのUIガイドを初回起動時に表示する。
 *
 * 動作仕様:
 * - localStorage の "whereareyou:tutorialDone" フラグで表示済み判定する。
 * - start() を呼び出すとチュートリアルが開始される。
 * - 完了またはスキップ時にフラグを立てて再表示しない。
 * - resetTutorial() でフラグをリセットして再表示できる（設定画面等から利用）。
 */
import { driver } from 'driver.js'
import 'driver.js/dist/driver.css'

const STORAGE_KEY = 'whereareyou:tutorialDone'

/** チュートリアル完了フラグを確認する */
export function hasDoneTutorial(): boolean {
    try {
        return window.localStorage.getItem(STORAGE_KEY) === '1'
    } catch {
        return false
    }
}

/** チュートリアル完了フラグをリセットする（再表示用） */
export function resetTutorial(): void {
    try {
        window.localStorage.removeItem(STORAGE_KEY)
    } catch {
        // ignore
    }
}

/** チュートリアルを開始する */
/**
 * チュートリアルを開始する。
 * @param localeData - BootstrapData から渡されるロケール辞書。未定義時はキー名を表示する。
 * @param onDone - 完了/スキップ時コールバック。
 */
export function startTutorial(localeData?: Record<string, unknown>, onDone?: () => void): void {
    // ロケールヘルパー: '_' 区切りキーをネスト辞書から解決し、未定義時はキー名を返す
    const t = (key: string): string => {
        if (!localeData) return key
        const direct = localeData[key]
        if (typeof direct === 'string') return direct

        const parts = key.split('.')
        let node: unknown = localeData
        for (const part of parts) {
            if (!node || typeof node !== 'object') return key
            node = (node as Record<string, unknown>)[part]
        }
        return typeof node === 'string' ? node : key
    }

    const markDone = () => {
        try {
            window.localStorage.setItem(STORAGE_KEY, '1')
        } catch {
            // ignore
        }
        onDone?.()
    }

    const driverObj = driver({
        // ドライバー全体の設定
        animate: true,
        showProgress: true,
        allowClose: true,
        overlayOpacity: 0.7,
        // ボタンラベルを日本語化
        nextBtnText: t('tutorial.next_btn'),
        prevBtnText: t('tutorial.prev_btn'),
        doneBtnText: t('tutorial.done_btn'),
        // スキップ・完了時にフラグを立てる
        onDestroyStarted: () => {
            markDone()
            driverObj.destroy()
        },

        steps: [
            {
                // ステップ1: アプリ概要（要素ハイライトなし）
                popover: {
                    title: t('tutorial.step1.title'),
                    description: t('tutorial.step1.desc'),
                    side: 'over',
                    align: 'center',
                },
            },
            {
                // ステップ2: ゴーストモードボタン
                element: '#tutorial-ghost-btn',
                popover: {
                    title: t('tutorial.step2.title'),
                    description: t('tutorial.step2.desc'),
                    side: 'bottom',
                    align: 'end',
                },
            },
            {
                // ステップ3: 地図タブ
                element: '#tab-map',
                popover: {
                    title: t('tutorial.step3.title'),
                    description: t('tutorial.step3.desc'),
                    side: 'top',
                    align: 'start',
                },
            },
            {
                // ステップ4: タイムラインタブ
                element: '#tab-timeline',
                popover: {
                    title: t('tutorial.step4.title'),
                    description: t('tutorial.step4.desc'),
                    side: 'top',
                    align: 'center',
                },
            },
            {
                // ステップ5: 友達タブ
                element: '#tab-friends',
                popover: {
                    title: t('tutorial.step5.title'),
                    description: t('tutorial.step5.desc'),
                    side: 'top',
                    align: 'start',
                },
            },
            {
                // ステップ6: グループタブ
                element: '#tab-groups',
                popover: {
                    title: t('tutorial.step6.title'),
                    description: t('tutorial.step6.desc'),
                    side: 'top',
                    align: 'center',
                },
            },
            {
                // ステップ7: 設定タブ
                element: '#tab-settings',
                popover: {
                    title: t('tutorial.step7.title'),
                    description: t('tutorial.step7.desc'),
                    side: 'top',
                    align: 'end',
                },
            },
        ],
    })

    driverObj.drive()
}
