/**
 * NUIクライアントの再エクスポート。
 * features 層から utils/nui.ts への直接依存を避けるための中継モジュール。
 */
import { fetchNuiCallback } from '../../../utils/nui'

export { fetchNuiCallback }
