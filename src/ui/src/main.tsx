/**
 * エントリーポイント。
 * FiveMインゲーム内では lb-phone が 'componentsLoaded' イベントを発火するまで待機してから
 * Reactアプリを描画する。デビューモード（Vite dev server）では即時描画する。
 * 重複描画防止のため rendered フラグと setTimeout(300ms)フォールバックを使用。
 */
import React from 'react'
import ReactDOM from 'react-dom/client'
import 'leaflet/dist/leaflet.css'
import App from './App'
import './styles.css'

const devMode = !window?.invokeNative
const root = ReactDOM.createRoot(document.getElementById('root')!)

const renderApp = () => {
    root.render(
        <React.StrictMode>
            <App />
        </React.StrictMode>
    )
}

if (window.name === '' || devMode) {
    if (devMode) {
        renderApp()
    } else {
        let rendered = false
        const doRender = () => {
            if (!rendered) {
                rendered = true
                renderApp()
            }
        }

        window.addEventListener('message', (event) => {
            if (event.data === 'componentsLoaded') {
                doRender()
            }
        })

        setTimeout(doRender, 300)
    }
}
