/**
 * ローカライズ（多言語対応）モジュール。
 * ox_lib の getLocales() で取得したロケールデータを React Context 経由で
 * 全コンポーネントに提供する。
 *
 * 使い方:
 *   const t = useT()
 *   t('tab.map')                           // → "地図"
 *   t('consent.item_3', { mode: 'オフ' }) // → "オフで即時停止できます"
 */
import { createContext, useContext, useMemo } from 'react'

/** ロケールデータの型。文字列またはネストした辞書を許可する。 */
export interface LocaleData {
    [key: string]: string | LocaleData
}

/** '_' 区切りキー（例: tab_map）をネスト辞書から解決する。 */
function resolveLocaleValue(locale: LocaleData, key: string): string | undefined {
    // 念のため、フラットキー形式（tab_map）が直接入っている場合にも対応する
    const direct = locale[key]
    if (typeof direct === 'string') return direct

    const parts = key.split('.')
    let node: string | LocaleData | undefined = locale
    for (const part of parts) {
        if (!node || typeof node === 'string') return undefined
        node = node[part]
    }
    return typeof node === 'string' ? node : undefined
}

/**
 * ロケールデータのコンテキスト。
 * AppShell が bootstrap 受信後に値を注入する。
 * 起動直後（bootstrap 前）は空オブジェクトのため t() はキー名をそのまま返す。
 */
export const LocaleContext = createContext<LocaleData>({})

/** 翻訳関数の型。 */
export type TFn = (key: string, variables?: Record<string, string>) => string

/**
 * ロケールデータから翻訳関数を生成する。
 * AppShell のように Provider を自身で定義するコンポーネントが、
 * Context 経由ではなく state を直接使って t を得る際に使用する。
 */
export function createT(locale: LocaleData): TFn {
    return (key: string, variables?: Record<string, string>): string => {
        let value = resolveLocaleValue(locale, key) ?? key
        if (variables) {
            for (const [k, v] of Object.entries(variables)) {
                value = value.replace(`{${k}}`, v)
            }
        }
        return value
    }
}

/**
 * 翻訳関数 t() を返すフック。
 * Context 内の子コンポーネントから使用する（AppShell 自身は createT を使うこと）。
 *
 * @returns t(key, variables?) - ロケール文字列を返す関数
 *   - key: locales/ja.json 等のキー名
 *   - variables: '{name}' 形式のプレースホルダーを置換するマップ
 */
export function useT(): TFn {
    const locale = useContext(LocaleContext)
    return useMemo(() => createT(locale), [locale])
}
