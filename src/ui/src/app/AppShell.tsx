import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { fetchNuiCallback, getInitialAppOpenState, getInitialComponentsLoaded, useAppEvent } from '../utils/nui'
import {
    clampPosition,
    MAP_BOUNDS,
} from '../utils/map'
import { callApi } from '../features/shared/api/callApi'
import type {
    ApiResponse,
    AppSettings,
    BootstrapData,
    EmojiPickerResult,
    FriendDetail,
    FriendMapItem,
    FriendSummary,
    FriendsListData,
    FriendsMapData,
    GhostMode,
    GhostModeSettings,
    GroupItem,
    GroupsData,
    NearbyCandidate,
    PendingRequest,
    PositionPayload,
    SearchPlayer,
    Tab,
    TimelineData,
    TimelinePost,
    ViewFilterType,
} from '../features/shared/types'
import { Header } from '../features/shared/ui/Header'
import { TabBar } from '../features/shared/ui/TabBar'
import { LocaleContext } from '../features/shared/locale'
import type { LocaleData } from '../features/shared/locale'
import { MapTab } from '../features/map/MapTab'
import { FriendsTab } from '../features/friends/FriendsTab'
import { GroupsTab } from '../features/groups/GroupsTab'
import { TimelineTab } from '../features/timeline/TimelineTab'
import { SettingsTab } from '../features/settings/SettingsTab'
import { FriendAddModal } from '../features/friends/FriendAddModal'
import { FriendDetailDialog } from '../features/friends/FriendDetailDialog'
import { ReactionModal } from '../features/timeline/ReactionModal'
import { GroupJoinModal } from '../features/groups/GroupJoinModal'
import { DeleteConfirmDialog } from '../features/account/DeleteConfirmDialog'
import type { FocusedPostPin } from '../features/map/map.types'
import { hasDoneTutorial, startTutorial, resetTutorial } from '../features/tutorial/useTutorial'
import { createT } from '../features/shared/locale'

const defaultPosition: PositionPayload = {
    x: (MAP_BOUNDS.topLeft.x + MAP_BOUNDS.bottomRight.x) / 2,
    y: (MAP_BOUNDS.topLeft.y + MAP_BOUNDS.bottomRight.y) / 2,
    z: 0,
    heading: 0,
    speed: 0,
    updatedAt: 0,
}

const FILTER_STORAGE_KEY = 'whereareyou:viewFilter'

type DeleteTarget =
    | { type: 'post'; postId: number }
    | { type: 'reaction'; reactionId: number; postId: number }
    | { type: 'account' }
    | null

export function AppShell() {
    const [selfPosition, setSelfPosition] = useState<PositionPayload>(defaultPosition)
    const [ready, setReady] = useState(false)
    const [bootstrapped, setBootstrapped] = useState(false)
    const [consentGiven, setConsentGiven] = useState(false)
    const [ghostMode, setGhostMode] = useState<GhostMode>('normal')
    const [activeTab, setActiveTab] = useState<Tab>('map')
    const [isGhostSheetOpen, setGhostSheetOpen] = useState(false)
    const [friendsMap, setFriendsMap] = useState<FriendMapItem[]>([])
    const [friendsList, setFriendsList] = useState<FriendSummary[]>([])
    const [pendingRequests, setPendingRequests] = useState<PendingRequest[]>([])
    const [isAddFriendOpen, setAddFriendOpen] = useState(false)
    const [searchQuery, setSearchQuery] = useState('')
    const [searchResults, setSearchResults] = useState<SearchPlayer[]>([])
    const [nearbyCandidates, setNearbyCandidates] = useState<NearbyCandidate[]>([])
    const [selectedFriend, setSelectedFriend] = useState<FriendDetail | null>(null)
    const [confirmAction, setConfirmAction] = useState<{ type: 'block' | 'remove'; friend: FriendDetail } | null>(null)
    const [mapInstance, setMapInstance] = useState<GameMapInstance | null>(null)
    const [groups, setGroups] = useState<GroupItem[]>([])
    const [groupNameInput, setGroupNameInput] = useState('')
    const [groupPasswordInput, setGroupPasswordInput] = useState('')
    const [viewFilter, setViewFilter] = useState<ViewFilterType>('all')
    const [selectedGroupId, setSelectedGroupId] = useState<number | null>(null)
    const [friendGhostMode, setFriendGhostMode] = useState<'normal' | 'freeze' | 'blur'>('normal')
    const [groupGhostModes, setGroupGhostModes] = useState<Record<number, 'normal' | 'freeze' | 'blur'>>({})
    const [timelinePosts, setTimelinePosts] = useState<TimelinePost[]>([])
    const [checkinContent, setCheckinContent] = useState('')
    const [checkinError, setCheckinError] = useState<string | null>(null)
    const [reactionTargetPostId, setReactionTargetPostId] = useState<number | null>(null)
    const [reactionStamp, setReactionStamp] = useState('')
    const [reactionMessage, setReactionMessage] = useState('')
    const [focusedPostPin, setFocusedPostPin] = useState<FocusedPostPin | null>(null)
    const [selfPlayerId, setSelfPlayerId] = useState('')
    const [isAddGroupOpen, setAddGroupOpen] = useState(false)
    const [groupJoinError, setGroupJoinError] = useState<string | null>(null)
    const [deleteTarget, setDeleteTarget] = useState<DeleteTarget>(null)
    const [appSettings, setAppSettings] = useState<AppSettings>({
        nearbyNotifyEnabled: false,
        nearbyRadius: 100,
        nearbyIntervalMs: 10000,
    })
    // ロケールデータ: bootstrap イベントで ox_lib の getLocales() 結果を受け取る
    const [localeData, setLocaleData] = useState<LocaleData>({})
    // lb-phone の onUse/onClose に連動してポーリングを制御する
    // モジュールレベルで捕捉した appOpen/appClose を初期値として使う。
    // lb-phone は React マウントより前に appOpen を送信するため、
    // nui.ts の早期リスナで受け取った状態を初期値に設定する。
    // appOpen を取りこぼしても、componentsLoaded 受信済みなら初期化を走らせる（マウント前の取りこぼし対策）。
    const [isAppOpen, setIsAppOpen] = useState(() => getInitialAppOpenState() || getInitialComponentsLoaded())

    const detailDialogRef = useRef<HTMLDialogElement>(null)
    const confirmDialogRef = useRef<HTMLDialogElement>(null)
    const deleteDialogRef = useRef<HTMLDialogElement>(null)

    // AppShell 自身は LocaleContext.Provider を定義する側なので、
    // useT()（Context 経由）ではなく localeData state を直接使う createT を使用する。
    const t = useMemo(() => createT(localeData), [localeData])

    const applyGhostModeSettings = useCallback((settings?: GhostModeSettings) => {
        if (!settings) return
        setGhostMode(settings.global)
        setFriendGhostMode(settings.friend)
        const next: Record<number, 'normal' | 'freeze' | 'blur'> = {}
        for (let i = 0; i < settings.groups.length; i += 1) {
            const row = settings.groups[i]
            next[row.groupId] = row.mode
        }
        setGroupGhostModes(next)
    }, [])

    useEffect(() => {
        try {
            const raw = window.localStorage.getItem(FILTER_STORAGE_KEY)
            if (!raw) return
            const parsed = JSON.parse(raw) as { filter: ViewFilterType; groupId: number | null }
            if (parsed.filter === 'all' || parsed.filter === 'friends' || parsed.filter === 'group') {
                setViewFilter(parsed.filter)
                setSelectedGroupId(parsed.groupId)
            }
        } catch (_error) {
            // ignore
        }
    }, [])

    useEffect(() => {
        try {
            window.localStorage.setItem(
                FILTER_STORAGE_KEY,
                JSON.stringify({ filter: viewFilter, groupId: selectedGroupId })
            )
        } catch (_error) {
            // ignore
        }
    }, [viewFilter, selectedGroupId])

    const refreshFriendsList = useCallback(async () => {
        const data = await callApi<FriendsListData>('getFriendsList', {}, { friends: [], pendingRequests: [] })
        setFriendsList(data.friends)
        setPendingRequests(data.pendingRequests)
    }, [])

    const refreshFriendsMap = useCallback(async () => {
        const data = await callApi<FriendsMapData>('getFriendsMap', {}, { friends: [] })
        setFriendsMap(data.friends.map((friend) => ({ ...friend, x: clampPosition(friend).x, y: clampPosition(friend).y })))
    }, [])

    const refreshMyGroups = useCallback(async () => {
        const data = await callApi<GroupsData>('getMyGroups', {}, { groups: [] })
        setGroups(data.groups ?? [])
    }, [])

    const refreshTimeline = useCallback(async () => {
        const data = await callApi<TimelineData>('getTimeline', { filter: viewFilter, groupId: selectedGroupId, limit: 50 }, { posts: [] })
        setTimelinePosts(data.posts ?? [])
    }, [selectedGroupId, viewFilter])

    useEffect(() => {
        // プリロード時（別アプリ表示中）は lb-phone の fetchNui がまだ注入されていないためスキップする
        if (!isAppOpen) return

        let mounted = true

        fetchNuiCallback<PositionPayload>('getSelfPosition', {}, defaultPosition)
            .then((position) => {
                if (!mounted || !position) return
                setSelfPosition(clampPosition(position))
                setReady(true)
            })
            .catch(() => {
                if (!mounted) return
                setReady(true)
            })

        callApi<BootstrapData>('getBootstrap', {}, {
            playerId: '',
            selfName: '',
            consentGiven: false,
            ghostMode: 'normal',
            friends: [],
            pendingRequests: [],
        })
            .then((data) => {
                if (!mounted) return
                setSelfPlayerId(data.playerId ?? '')
                setConsentGiven(data.consentGiven)
                setGhostMode(data.ghostMode)
                setFriendsList(data.friends)
                setPendingRequests(data.pendingRequests)
                setGroups(data.groups ?? [])
                applyGhostModeSettings(data.ghostModeSettings)
                if (data.appSettings) {
                    setAppSettings(data.appSettings)
                }
                // ロケールデータを反映する
                if (data.locales) {
                    setLocaleData(data.locales)
                }
                setBootstrapped(true)
            })
            .catch(() => {
                if (!mounted) return
                setBootstrapped(true)
            })

        return () => {
            mounted = false
        }
    }, [isAppOpen, applyGhostModeSettings])

    useAppEvent('appOpen', () => {
        // NOTE(lb-phone-defensive): lb-phone v2.8.2 で本体側のバグは修正済みだが、
        //   将来の再発（componentsLoaded 未送信など）に備えて防御的に残す。削除しないこと。
        // 【バグ内容】バックグラウンド復帰時に lb-phone が componentsLoaded を送信しないと、
        //   body が visibility:hidden のまま画面が真っ暗になる。
        // 【効果】appOpen 受信時に body を明示的に visible にすることで、
        //   componentsLoaded が来なくても画面が表示される保険となる。
        document.body.style.visibility = 'visible'
        setIsAppOpen(true)
    })
    useAppEvent('appClose', () => { setIsAppOpen(false) })

    // NOTE(lb-phone-workaround): lb-phone は高負荷時などに appOpen を送らないことがある
    //   （注入と componentsLoaded は届くが appOpen だけ取りこぼす。詳細は docs/plan/other_memo/appOpenメモ.md）。
    //   appOpen 受信だけを初期化トリガにすると isAppOpen が false のままで getBootstrap を pull せず、
    //   locale が空（キー表示）・地図未初期化になる。
    //   componentsLoaded は表示中の本物 iframe には開くたびに必ず届く（プリロード用 iframe には届かない）ため、
    //   これも初期化トリガに使い、appOpen 非依存で初期データ取得を成立させる。
    //   componentsLoaded は React マウント前（t≈400ms）に届くため、初回ぶんは isAppOpen の初期値
    //   （getInitialComponentsLoaded）で拾う。このリスナはマウント後に届く分の保険。
    //   componentsLoaded は action プロパティを持たない文字列メッセージのため useAppEvent では拾えず、
    //   直接 message を購読する。
    useEffect(() => {
        const handler = (event: MessageEvent) => {
            if (event.data === 'componentsLoaded') {
                document.body.style.visibility = 'visible'
                setIsAppOpen(true)
            }
        }
        window.addEventListener('message', handler)
        return () => window.removeEventListener('message', handler)
    }, [])

    useAppEvent('selfPosition', (position: PositionPayload) => {
        if (!position) return
        setSelfPosition(clampPosition(position))
    })

    useAppEvent('bootstrap', (data: BootstrapData) => {
        if (!data) return
        setSelfPlayerId(data.playerId ?? '')
        setConsentGiven(data.consentGiven)
        setGhostMode(data.ghostMode)
        setFriendsList(data.friends)
        setPendingRequests(data.pendingRequests)
        setGroups(data.groups ?? [])
        applyGhostModeSettings(data.ghostModeSettings)
        if (data.appSettings) {
            setAppSettings(data.appSettings)
        }
        if (data.locales) {
            setLocaleData(data.locales)
        }
        setBootstrapped(true)
    })

    useAppEvent('friendsMap', (data: FriendsMapData) => {
        if (!data || !Array.isArray(data.friends)) return
        setFriendsMap(data.friends.map((friend) => ({ ...friend, x: clampPosition(friend).x, y: clampPosition(friend).y })))
    })

    useAppEvent('friendsList', (data: FriendsListData) => {
        if (!data) return
        setFriendsList(data.friends ?? [])
        setPendingRequests(data.pendingRequests ?? [])
    })

    const filteredFriendsMap = useMemo(() => {
        if (viewFilter === 'friends') return friendsMap.filter((friend) => friend.isFriend === true)
        if (viewFilter === 'group' && selectedGroupId) return friendsMap.filter((friend) => (friend.sharedGroupIds ?? []).includes(selectedGroupId))
        return friendsMap
    }, [friendsMap, selectedGroupId, viewFilter])

    useEffect(() => {
        // プリロード時（別アプリ表示中）はデータ取得をスキップする
        if (!isAppOpen) return

        // [B-5] マップタブ以外に切り替えた時、チェックインマーカーをクリアする。
        if (activeTab !== 'map') {
            setFocusedPostPin(null)
        }

        if (activeTab === 'friends') {
            void refreshFriendsList()
            return
        }

        if (activeTab === 'groups') {
            void refreshMyGroups()
            return
        }

        if (activeTab === 'timeline') {
            void refreshTimeline()
            return
        }

        void refreshFriendsMap()
    }, [isAppOpen, activeTab, refreshFriendsList, refreshFriendsMap, refreshMyGroups, refreshTimeline])

    useEffect(() => {
        if (activeTab !== 'map' || !isAppOpen) return
        const timer = window.setInterval(() => { void refreshFriendsMap() }, 2000)
        return () => { window.clearInterval(timer) }
    }, [activeTab, isAppOpen, refreshFriendsMap])

    useEffect(() => {
        if (activeTab !== 'timeline' || !isAppOpen) return
        const timer = window.setInterval(() => { void refreshTimeline() }, 5000)
        return () => { window.clearInterval(timer) }
    }, [activeTab, isAppOpen, refreshTimeline])

    // focusedPostPin が変わったとき地図をその位置に移動する
    useEffect(() => {
        if (!mapInstance || activeTab !== 'map' || !focusedPostPin) return
        mapInstance.setPosition({ x: focusedPostPin.x, y: focusedPostPin.y }, 4)
    }, [activeTab, focusedPostPin, mapInstance])

    // 同意済みで tutorialDone フラグが未設定の場合にチュートリアルを起動する。
    // 既存ユーザーがアップデート後に初めて開いた場合にも対応する。
    useEffect(() => {
        if (!bootstrapped || !consentGiven) return
        if (hasDoneTutorial()) return
        // UI が描画されてから少し待ってから起動する
        const timer = window.setTimeout(() => { startTutorial(localeData) }, 600)
        return () => { window.clearTimeout(timer) }
    }, [bootstrapped, consentGiven])

    const recenterToSelf = useCallback(() => {
        if (!mapInstance) return
        mapInstance.setPosition({ x: selfPosition.x, y: selfPosition.y })
    }, [mapInstance, selfPosition.x, selfPosition.y])

    const applyViewFilter = (value: string) => {
        if (value === 'all' || value === 'friends') {
            setViewFilter(value)
            setSelectedGroupId(null)
            return
        }

        if (value.startsWith('group:')) {
            const groupId = Number(value.slice(6))
            if (!Number.isNaN(groupId)) {
                setViewFilter('group')
                setSelectedGroupId(groupId)
            }
        }
    }

    const handleAgreeConsent = async () => {
        await callApi('agreeConsent', {}, { consentGiven: true })
        setConsentGiven(true)
        // 初回同意後にチュートリアルを起動する（少し遅延させてUIが描画されてから実行）
        window.setTimeout(() => { startTutorial(localeData) }, 400)
    }

    const handleGlobalGhostModeChange = async (mode: 'normal' | 'off') => {
        const data = await callApi<{ ghostMode: GhostMode; ghostModeSettings?: GhostModeSettings }>('setGhostMode', { scope: 'global', mode }, { ghostMode: mode })
        setGhostMode(data.ghostMode)
        applyGhostModeSettings(data.ghostModeSettings)
        // [B-10] 統合シートではシートを閉じず、そのまま他の設定も操作できる状態を維持する。
        void refreshFriendsMap()
        void refreshFriendsList()
    }

    const handleFriendGhostModeChange = async (mode: 'normal' | 'freeze' | 'blur') => {
        const freezeCoords = mode === 'freeze' ? selfPosition : undefined
        const data = await callApi<{ ghostMode: GhostMode; ghostModeSettings?: GhostModeSettings }>('setGhostMode', { scope: 'friend', mode, freezeCoords }, { ghostMode })
        applyGhostModeSettings(data.ghostModeSettings)
        void refreshFriendsMap()
        void refreshFriendsList()
    }

    const handleGroupGhostModeChange = async (groupId: number, mode: 'normal' | 'freeze' | 'blur') => {
        const freezeCoords = mode === 'freeze' ? selfPosition : undefined
        const data = await callApi<{ ghostMode: GhostMode; ghostModeSettings?: GhostModeSettings }>('setGhostMode', { scope: 'group', groupId, mode, freezeCoords }, { ghostMode })
        applyGhostModeSettings(data.ghostModeSettings)
        void refreshFriendsMap()
    }

    const openAddFriend = () => {
        setAddFriendOpen(true)
        setSearchQuery('')
        setSearchResults([])
        callApi<{ candidates: NearbyCandidate[] }>('getNearbyCandidates', {}, { candidates: [] }).then((data) => {
            setNearbyCandidates(data.candidates)
        })
    }

    const handleJoinGroup = async () => {
        const trimmed = groupNameInput.trim()
        if (trimmed === '') {
            // [B-9] 自己操作エラーは lb-phone 通知ではなく UI 内表示にする。
            setGroupJoinError(t('error.group.name_required'))
            return
        }

        const fallback: ApiResponse<{ groupId: number; groupName: string }> = { ok: true, data: { groupId: 0, groupName: trimmed } }
        const res = await fetchNuiCallback<ApiResponse<{ groupId: number; groupName: string }>>('joinGroup', { groupName: trimmed, password: groupPasswordInput || null }, fallback)

        if (!res?.ok) {
            // [B-9] エラーを UI 内に表示。sendNotification は使わない。
            const msg = res?.error === 'incorrect password'
                ? t('error.group.password_wrong')
                : t('error.group.join_failed')
            setGroupJoinError(msg)
            return
        }

        setGroupJoinError(null)
        setGroupNameInput('')
        setGroupPasswordInput('')
        setAddGroupOpen(false)
        await refreshMyGroups()
        await refreshFriendsMap()
    }

    const handleLeaveGroup = async (groupId: number) => {
        const fallback: ApiResponse<{ leftGroupId: number }> = { ok: true, data: { leftGroupId: groupId } }
        const res = await fetchNuiCallback<ApiResponse<{ leftGroupId: number }>>('leaveGroup', { groupId }, fallback)

        if (!res?.ok) {
            // [B-9] 自己操作エラーはポップアップダイアログで表示する。
            window.components?.setPopUp?.({
                title: t('error.group.leave.title'),
                description: t('error.group.leave.desc'),
                buttons: [{ title: t('error.group.leave.close'), cb: () => undefined }],
            })
            return
        }

        if (selectedGroupId === groupId) {
            setViewFilter('all')
            setSelectedGroupId(null)
        }

        await refreshMyGroups()
        await refreshFriendsMap()
        await refreshTimeline()
    }

    const handleCreateCheckin = async () => {
        // [B-8] callApi はエラー時に fallback を返すため、ok/error を直接確認できる fetchNuiCallback を使う。
        const fallback: ApiResponse<{ posted: boolean }> = { ok: false, data: { posted: false } }
        const res = await fetchNuiCallback<ApiResponse<{ posted: boolean }>>('createCheckin', { content: checkinContent }, fallback)

        if (!res?.ok) {
            // [B-8] rate limited / 失敗は UI 内に表示する。
            const msg = res?.error === 'rate limited'
                ? t('error.checkin.rate_limited')
                : t('error.checkin.failed')
            setCheckinError(msg)
            return
        }

        setCheckinError(null)
        setCheckinContent('')
        await refreshTimeline()
    }

    const pickReactionEmoji = async (): Promise<string> => {
        const picker = window.components?.setEmojiPickerVisible
        if (!picker) return window.prompt(t('prompt.stamp_msg'), '👍')?.trim() ?? ''

        return new Promise((resolve) => {
            let settled = false
            const finish = (value: string) => {
                if (settled) return
                settled = true
                picker(false)
                resolve(value.trim())
            }

            picker({
                onSelect: (item: EmojiPickerResult | string) => {
                    const value = typeof item === 'string' ? item : item?.emoji ?? ''
                    finish(value)
                },
                onClose: () => {
                    finish('')
                },
            })
        })
    }

    const openReactionModal = (postId: number) => {
        setReactionTargetPostId(postId)
        setReactionStamp('')
        setReactionMessage('')
    }

    const closeReactionModal = () => {
        setReactionTargetPostId(null)
        setReactionStamp('')
        setReactionMessage('')
    }

    const handlePickReactionStamp = async () => {
        const stamp = await pickReactionEmoji()
        if (stamp !== '') {
            setReactionStamp(stamp)
        }
    }

    const submitReaction = async () => {
        if (!reactionTargetPostId) return

        const stamp = reactionStamp.trim()
        const message = reactionMessage.trim()

        if (stamp === '' && message === '') {
            window.sendNotification?.({ title: t('notify.title'), content: t('notify.reaction.empty') })
            return
        }

        const res = await callApi<{ reacted: boolean }>('reactToPost', { postId: reactionTargetPostId, stamp, message }, { reacted: true })
        if (!res.reacted) {
            window.sendNotification?.({ title: t('notify.title'), content: t('notify.reaction.failed') })
            return
        }

        closeReactionModal()
        await refreshTimeline()
    }

    const jumpToPost = (post: TimelinePost) => {
        setFocusedPostPin({ postId: post.id, x: post.x, y: post.y, displayName: post.displayName })
        setActiveTab('map')
    }

    const openDeleteDialog = (target: DeleteTarget) => {
        setDeleteTarget(target)
        deleteDialogRef.current?.showModal()
    }

    const closeDeleteDialog = () => {
        deleteDialogRef.current?.close()
        setDeleteTarget(null)
    }

    const executeDelete = async () => {
        if (!deleteTarget) return

        if (deleteTarget.type === 'post') {
            await callApi('deletePost', { postId: deleteTarget.postId }, { deleted: true })
            closeDeleteDialog()
            await refreshTimeline()
        } else if (deleteTarget.type === 'reaction') {
            await callApi('deleteReaction', { reactionId: deleteTarget.reactionId }, { deleted: true })
            closeDeleteDialog()
            await refreshTimeline()
        } else if (deleteTarget.type === 'account') {
            const fallback: ApiResponse<{ deleted: boolean }> = { ok: true, data: { deleted: true } }
            const res = await fetchNuiCallback<ApiResponse<{ deleted: boolean }>>('deleteAccount', {}, fallback)
            closeDeleteDialog()
            if (res?.ok) {
                setConsentGiven(false)
                setFriendsList([])
                setFriendsMap([])
                setGroups([])
                setTimelinePosts([])
                setBootstrapped(false)
                window.sendNotification?.({ title: t('notify.title'), content: t('notify.account_deleted') })
            }
        }
    }

    const handleSaveSettings = async () => {
        const normalized: AppSettings = {
            nearbyNotifyEnabled: appSettings.nearbyNotifyEnabled,
            nearbyRadius: Math.max(20, Math.min(1000, Number(appSettings.nearbyRadius) || 100)),
            nearbyIntervalMs: Math.max(30000, Math.min(600000, Math.round(Number(appSettings.nearbyIntervalMs) || 60000))),
        }

        const data = await callApi<{ settings: AppSettings }>('updateAppSettings', normalized, { settings: normalized })
        setAppSettings(data.settings)
        window.sendNotification?.({ title: t('notify.title'), content: t('notify.settings_saved') })
    }

    const runSearch = async () => {
        const data = await callApi<{ players: SearchPlayer[] }>('searchPlayers', { query: searchQuery }, { players: [] })
        setSearchResults(data.players.filter((row) => row.relation !== 'accepted'))
    }

    const sendFriendRequest = async (serverId: number) => {
        const fallback: ApiResponse<{ sent: boolean }> = { ok: true, data: { sent: true } }
        const res = await fetchNuiCallback<ApiResponse<{ sent: boolean }>>('sendFriendRequest', { serverId }, fallback)

        if (!res?.ok) {
            const msgMap: Record<string, string> = {
                'target not online': t('error.friend.request.target_not_online'),
                'already friends': t('error.friend.request.already_friends'),
                pending: t('error.friend.request.pending'),
                blocked: t('error.friend.request.blocked'),
                unavailable: t('error.friend.request.unavailable'),
                'cannot request self': t('error.friend.request.cannot_self'),
                'invalid target': t('error.friend.request.invalid'),
            }
            const msg = (res?.error && msgMap[res.error]) ?? t('error.friend.request.failed')
            window.sendNotification?.({ title: t('notify.title'), content: msg })
            return
        }

        await refreshFriendsList()
        await runSearch()
        const nearby = await callApi<{ candidates: NearbyCandidate[] }>('getNearbyCandidates', {}, { candidates: [] })
        setNearbyCandidates(nearby.candidates)
    }

    const unblockFriend = async (playerId: string) => {
        const fallback: ApiResponse<{ unblocked: boolean }> = { ok: true, data: { unblocked: true } }
        const res = await fetchNuiCallback<ApiResponse<{ unblocked: boolean }>>('unblockFriend', { playerId }, fallback)

        if (!res?.ok) {
            window.sendNotification?.({ title: t('notify.title'), content: t('notify.unblock_failed') })
            return
        }

        await refreshFriendsList()
        await runSearch()
        const nearby = await callApi<{ candidates: NearbyCandidate[] }>('getNearbyCandidates', {}, { candidates: [] })
        setNearbyCandidates(nearby.candidates)
    }

    const respondRequest = async (requestId: number, accept: boolean) => {
        await callApi('respondFriendRequest', { requestId, accept }, { accepted: accept })
        await refreshFriendsList()
        await refreshFriendsMap()
    }

    const openFriendDetail = async (friendId: string) => {
        const detail = await callApi<FriendDetail>('getFriendDetail', { playerId: friendId }, {
            playerId: friendId,
            displayName: friendId,
            isOnline: false,
            ghostMode: 'normal',
            speed: 0,
            moveStatus: 'idle',
            updatedAt: Date.now(),
        })
        setSelectedFriend(detail)
        detailDialogRef.current?.showModal()
    }

    const closeDetailDialog = () => {
        detailDialogRef.current?.close()
        setSelectedFriend(null)
    }

    const openConfirmDialog = (type: 'block' | 'remove', friend: FriendDetail) => {
        detailDialogRef.current?.close()
        setConfirmAction({ type, friend })
        confirmDialogRef.current?.showModal()
    }

    const closeConfirmDialog = () => {
        confirmDialogRef.current?.close()
        setConfirmAction(null)
    }

    const executeConfirmAction = async () => {
        if (!confirmAction) return
        const { type, friend } = confirmAction

        if (type === 'block') {
            await callApi('blockFriend', { playerId: friend.playerId }, { blocked: true })
        } else {
            const fallback: ApiResponse<{ removed: boolean }> = { ok: true, data: { removed: true } }
            const res = await fetchNuiCallback<ApiResponse<{ removed: boolean }>>('removeFriend', { playerId: friend.playerId }, fallback)
            if (!res?.ok) {
                window.sendNotification?.({ title: t('notify.title'), content: t('notify.friend_remove_failed') })
                closeConfirmDialog()
                return
            }
        }

        closeConfirmDialog()
        setSelectedFriend(null)
        await refreshFriendsList()
        await refreshFriendsMap()
    }

    return (
        // bootstrap 受信後にロケールデータを LocaleContext 経由で全子コンポーネントに提供する
        <LocaleContext.Provider value={localeData}>
        <main className="app">
            <Header consentGiven={consentGiven} ghostMode={ghostMode} onOpenGhostSheet={() => setGhostSheetOpen(true)} />

            {/* MapTab は常時マウント（display:none で隠す）。unmount するとGameMapインスタンスが破棄され、
                タブ復帰のたびに地図の状態がリセットされるため。 */}
            <MapTab
                isAppOpen={isAppOpen}
                isActive={activeTab === 'map'}
                selfX={selfPosition.x}
                selfY={selfPosition.y}
                ready={ready}
                viewFilter={viewFilter}
                selectedGroupId={selectedGroupId}
                groups={groups}
                filteredFriendsMap={filteredFriendsMap}
                focusedPostPin={focusedPostPin}
                onMapReady={setMapInstance}
                onApplyViewFilter={applyViewFilter}
                onRecenterToSelf={recenterToSelf}
                onFriendClick={(friendId) => { void openFriendDetail(friendId) }}
            />

            {activeTab === 'friends' && (
                <FriendsTab
                    friendsList={friendsList}
                    pendingRequests={pendingRequests}
                    onOpenAddFriend={openAddFriend}
                    onOpenFriendDetail={(friendId) => { void openFriendDetail(friendId) }}
                    onUnblockFriend={(playerId) => { void unblockFriend(playerId) }}
                    onRespondRequest={(requestId, accept) => { void respondRequest(requestId, accept) }}
                />
            )}

            {activeTab === 'groups' && (
                <GroupsTab
                    groups={groups}
                    onRefresh={() => { void refreshMyGroups() }}
                    onOpenAddGroup={() => setAddGroupOpen(true)}
                    onLeaveGroup={(groupId) => { void handleLeaveGroup(groupId) }}
                />
            )}

            {activeTab === 'timeline' && (
                <TimelineTab
                    viewFilter={viewFilter}
                    selectedGroupId={selectedGroupId}
                    groups={groups}
                    checkinContent={checkinContent}
                    checkinError={checkinError}
                    timelinePosts={timelinePosts}
                    selfPlayerId={selfPlayerId}
                    onApplyViewFilter={applyViewFilter}
                    onRefresh={() => { void refreshTimeline() }}
                    onCheckinContentChange={(v) => { setCheckinContent(v); setCheckinError(null) }}
                    onCreateCheckin={() => { void handleCreateCheckin() }}
                    onJumpToPost={jumpToPost}
                    onOpenReactionModal={openReactionModal}
                    onDeletePost={(postId) => openDeleteDialog({ type: 'post', postId })}
                    onDeleteReaction={(reactionId, postId) => openDeleteDialog({ type: 'reaction', reactionId, postId })}
                />
            )}

            {activeTab === 'settings' && (
                <SettingsTab
                    appSettings={appSettings}
                    onAppSettingsChange={setAppSettings}
                    onSave={() => { void handleSaveSettings() }}
                    onOpenDeleteAccount={() => openDeleteDialog({ type: 'account' })}
                    onRestartTutorial={() => {
                        // ロケールデータを useTutorial に渡して多言語対応の チュートリアルを起動する
                        resetTutorial()
                        startTutorial(localeData)
                    }}
                />
            )}

            <TabBar activeTab={activeTab} onChange={setActiveTab} />

            {bootstrapped && !consentGiven && (
                <section className="modal-overlay">
                    <article className="modal-card consent-card">
                        <h2>{t('consent.title')}</h2>
                        <p>{t('consent.body')}</p>
                        <ul>
                            <li>{t('consent.item_1')}</li>
                            <li>{t('consent.item_2')}</li>
                            <li>{t('consent.item_3', { mode: t('ghost.mode.off') })}</li>
                        </ul>
                        <button type="button" className="primary" onClick={() => { void handleAgreeConsent() }}>
                            {t('consent.agree_btn')}
                        </button>
                    </article>
                </section>
            )}

            {isGhostSheetOpen && (
                // [B-10] 緊急オフシートとゴーストモード詳細を1つのシートに統合。
                <section className="modal-overlay" onClick={() => setGhostSheetOpen(false)}>
                    <article className="modal-card sheet" onClick={(event) => event.stopPropagation()}>
                        <h3>{t('ghost.sheet_title')}</h3>

                        {/* 全体：通常 / 自閉 */}
                        <h4 className="ghost-section-label">{t('ghost.section_global')}</h4>
                        <div className="mode-grid mode-grid-inline">
                            <button
                                type="button"
                                className={ghostMode !== 'off' ? 'active' : ''}
                                onClick={() => { void handleGlobalGhostModeChange('normal') }}
                            >
                                {t('ghost.mode.normal')}
                            </button>
                            <button
                                type="button"
                                className={ghostMode === 'off' ? 'active' : ''}
                                onClick={() => { void handleGlobalGhostModeChange('off') }}
                            >
                                {t('ghost.mode.off')}
                            </button>
                        </div>

                        {/* フレンド向け */}
                        <h4 className="ghost-section-label">{t('ghost.section_friends')}</h4>
                        <div className="group-ghost-row">
                            <strong>{t('ghost.all_friends')}</strong>
                            <select
                                value={friendGhostMode}
                                onChange={(event) => { void handleFriendGhostModeChange(event.target.value as 'normal' | 'freeze' | 'blur') }}
                            >
                                <option value="normal">{t('ghost.mode.normal')}</option>
                                <option value="freeze">{t('ghost.mode.freeze')}</option>
                                <option value="blur">{t('ghost.mode.blur')}</option>
                            </select>
                        </div>

                        {/* グループ向け */}
                        {groups.length > 0 && (
                            <>
                                <h4 className="ghost-section-label">{t('ghost.section_groups')}</h4>
                                <div className="stack-list">
                                    {groups.map((group) => (
                                        <div key={group.id} className="group-ghost-row">
                                            <strong>{group.name}</strong>
                                            <select
                                                value={groupGhostModes[group.id] ?? 'normal'}
                                                onChange={(event) => { void handleGroupGhostModeChange(group.id, event.target.value as 'normal' | 'freeze' | 'blur') }}
                                            >
                                                <option value="normal">{t('ghost.mode.normal')}</option>
                                                <option value="freeze">{t('ghost.mode.freeze')}</option>
                                                <option value="blur">{t('ghost.mode.blur')}</option>
                                            </select>
                                        </div>
                                    ))}
                                </div>
                            </>
                        )}

                        <button type="button" className="primary" onClick={() => setGhostSheetOpen(false)}>
                            {t('btn.close')}
                        </button>
                    </article>
                </section>
            )}

            <FriendAddModal
                isOpen={isAddFriendOpen}
                nearbyCandidates={nearbyCandidates}
                searchQuery={searchQuery}
                searchResults={searchResults}
                onClose={() => setAddFriendOpen(false)}
                onSearchQueryChange={setSearchQuery}
                onSearch={() => { void runSearch() }}
                onSendRequest={(serverId) => { void sendFriendRequest(serverId) }}
                onUnblockFriend={(playerId) => { void unblockFriend(playerId) }}
            />

            <ReactionModal
                isOpen={reactionTargetPostId !== null}
                reactionStamp={reactionStamp}
                reactionMessage={reactionMessage}
                onClose={closeReactionModal}
                onPickStamp={() => { void handlePickReactionStamp() }}
                onMessageChange={setReactionMessage}
                onSubmit={() => { void submitReaction() }}
            />

            <FriendDetailDialog
                detailDialogRef={detailDialogRef}
                confirmDialogRef={confirmDialogRef}
                selectedFriend={selectedFriend}
                confirmAction={confirmAction}
                onCloseDetail={closeDetailDialog}
                onOpenConfirmDialog={openConfirmDialog}
                onCloseConfirmDialog={closeConfirmDialog}
                onExecuteConfirmAction={() => { void executeConfirmAction() }}
            />

            <DeleteConfirmDialog
                deleteDialogRef={deleteDialogRef}
                deleteTarget={deleteTarget}
                onClose={closeDeleteDialog}
                onExecute={() => { void executeDelete() }}
            />

            <GroupJoinModal
                isOpen={isAddGroupOpen}
                groupNameInput={groupNameInput}
                groupPasswordInput={groupPasswordInput}
                errorMessage={groupJoinError ?? undefined}
                onClose={() => { setAddGroupOpen(false); setGroupJoinError(null) }}
                onGroupNameChange={(v) => { setGroupNameInput(v); setGroupJoinError(null) }}
                onGroupPasswordChange={setGroupPasswordInput}
                onSubmit={() => { void handleJoinGroup() }}
            />
        </main>
        </LocaleContext.Provider>
    )
}
