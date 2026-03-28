/**
 * アプリ共通型定義。
 * Lua側のデータ構造と一対一対応しているので、
 * サーバー側のアクション層の戻り値とここの型は常に同期すること。
 */
import type { MapPosition } from '../../utils/map'

/** ゴーストモードの列挙型。normal=GPS / freeze=氷結座標 / blur=粗ドット / off=位置非共有。 */
export type GhostMode = 'normal' | 'freeze' | 'blur' | 'off'
/** アプリ内タブの列挙型。 */
export type Tab = 'map' | 'friends' | 'groups' | 'timeline' | 'settings'
/** タイムライン・マップの表示フィルタ型。 */
export type ViewFilterType = 'all' | 'friends' | 'group'

/** NUICallbackの共通レスポンス型。孤琧時は fallbackData を利用する。 */
export type ApiResponse<T> = {
    ok: boolean
    data?: T
    error?: string
}

/** 地図かードのプレイヤーマーカー情報。ゴーストモード・移動ステータスを含む。 */
export type FriendMapItem = {
    playerId: string
    displayName: string
    isOnline: boolean
    x: number
    y: number
    z: number
    heading: number
    speed: number
    updatedAt: number
    ghostMode: GhostMode
    moveStatus: 'idle' | 'walk' | 'vehicle'
    isFriend?: boolean
    sharedGroupIds?: number[]
}

/** グループ情報。メンバー一覧とオンライン人数を包む。 */
export type GroupItem = {
    id: number
    name: string
    ghost_mode?: 'normal' | 'freeze' | 'blur'
    members?: { playerId: string; displayName: string; isOnline: boolean }[]
    onlineCount?: number
    offlineCount?: number
}

/** フレンド一覧の簡易表示用情報。ゴーストモード・オンライン状態・移動ステータスを含む。 */
export type FriendSummary = {
    playerId: string
    displayName: string
    isOnline: boolean
    relation: 'accepted' | 'blocked'
    ghostMode: GhostMode
    speed: number
    moveStatus: 'idle' | 'walk' | 'vehicle'
    updatedAt: number
}

/** 未対応のフレンド申請情報。 */
export type PendingRequest = {
    requestId: number
    fromPlayerId: string
    fromName: string
    isOnline: boolean
}


export type LocaleTree = {
    [key: string]: string | LocaleTree
}

export type BootstrapData = {
    playerId: string
    selfName: string
    consentGiven: boolean
    ghostMode: GhostMode
    friends: FriendSummary[]
    pendingRequests: PendingRequest[]
    groups?: GroupItem[]
    ghostModeSettings?: GhostModeSettings
    appSettings?: AppSettings
    /** ox_lib の getLocales() で取得した UI テキスト辞書。'_' 区切りキーをネストした構造を許可する。 */
    locales?: LocaleTree
}

export type AppSettings = {
    nearbyNotifyEnabled: boolean
    nearbyRadius: number
    nearbyIntervalMs: number
}

export type GhostModeSettings = {
    global: 'normal' | 'off'
    friend: 'normal' | 'freeze' | 'blur'
    groups: Array<{
        groupId: number
        groupName: string
        mode: 'normal' | 'freeze' | 'blur'
    }>
}

export type FriendsListData = {
    friends: FriendSummary[]
    pendingRequests: PendingRequest[]
}

export type FriendsMapData = {
    friends: FriendMapItem[]
}

export type GroupsData = {
    groups: GroupItem[]
}

export type SearchPlayer = {
    serverId: number
    playerId: string
    displayName: string
    relation: string
}

export type NearbyCandidate = {
    serverId: number
    playerId: string
    displayName: string
    distance: number
}

export type FriendDetail = {
    playerId: string
    displayName: string
    isOnline: boolean
    ghostMode: GhostMode
    speed: number
    moveStatus: 'idle' | 'walk' | 'vehicle'
    updatedAt: number
    isFriend?: boolean
    sharedGroupNames?: string[]
}

export type TimelineReaction = {
    id: number
    playerId: string
    displayName?: string
    stamp?: string
    message?: string
    createdAt: string
}

export type TimelinePost = {
    id: number
    playerId: string
    displayName: string
    x: number
    y: number
    z: number
    content: string
    createdAt: string
    reactions: TimelineReaction[]
}

export type TimelineData = {
    posts: TimelinePost[]
}

export type EmojiPickerResult = {
    emoji?: string
}

export type PositionPayload = MapPosition
