-- WhereAreYou クライアント実装の状態を初期化する。
WAY = WAY or {}
WAY.Client = WAY.Client or {}

local Client = WAY.Client

-- 状態管理: 各モジュールから共有する実行時ステート。
Client.State = {
    appIsOpen = false,
    pendingRequests = {},
    requestId = 0,
    consentGiven = false,
    nearbyNotifyCooldowns = {},
    uiUrl = GetResourceMetadata(GetCurrentResourceName(), 'ui_page', 0),
}
