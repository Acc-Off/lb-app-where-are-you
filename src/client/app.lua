local Client = WAY.Client
Client.App = Client.App or {}

local App = Client.App
local Bridge = Client.Bridge
local State = Client.State

-- lb-phone へのアプリ登録を行う。
function App.addCustomApp()
    local url = State.uiUrl

    local added, errorMessage = exports['lb-phone']:AddCustomApp({
        identifier = Config.Identifier,
        name = Config.Name,
        description = Config.Description,
        developer = Config.Developer,
        defaultApp = Config.DefaultApp,
        size = 2048,

        ui = url:find('http') and url or (GetCurrentResourceName() .. '/' .. url),
        icon = url:find('http')
            and (url .. '/public/icon.svg')
            or ('https://cfx-nui-' .. GetCurrentResourceName() .. '/ui/dist/icon.svg'),

        fixBlur = true,

        -- アプリを開いたときに初期データを同期する。
        onUse = function()
            State.appIsOpen = true
            Bridge.sendAppMessage('selfPosition', Bridge.getCurrentPosition())

            Bridge.callServer('bootstrap', {}, function(ok, data)
                if not ok or not data then
                    return
                end

                State.consentGiven = data.consentGiven == true
                -- ox_lib のロケールデータを UI に渡す（NUI テキストの多言語対応）
                data.locales = lib.getLocales()
                Bridge.sendAppMessage('bootstrap', data)
            end)
        end,

        -- 閉じたらループ側で送信を止める。
        onClose = function()
            State.appIsOpen = false
        end,

        -- アンインストール時に同意フラグをリセットし、位置情報送信を即時停止する。
        -- あわせてサーバーへ uninstallApp を送信し、DB の agreed_at を NULL に戻す。
        -- これによりサーバー再起動・プレイヤー再接続後も未同意状態が維持され、
        -- 送信停止状態が永続化される。再インストール時は規約への再同意が必要になる。
        onDelete = function()
            State.consentGiven = false
            Bridge.callServer('uninstallApp', {})
        end,
    })

    if not added then
        print('[whereareyou] Could not add app: ' .. tostring(errorMessage))
    end
end
