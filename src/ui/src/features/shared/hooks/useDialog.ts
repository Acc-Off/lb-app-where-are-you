/**
 * `<dialog>` 要素の開閉を管理するカスタムフック。
 * ref、open、closeを返す。showModal()と close()をラップする。
 */
import { useCallback, useRef } from 'react'

export function useDialog<T extends HTMLDialogElement = HTMLDialogElement>() {
    const ref = useRef<T>(null)

    const open = useCallback(() => {
        ref.current?.showModal()
    }, [])

    const close = useCallback(() => {
        ref.current?.close()
    }, [])

    return { ref, open, close }
}
