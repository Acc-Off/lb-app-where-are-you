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
    })

    if not added then
        print('[whereareyou] Could not add app: ' .. tostring(errorMessage))
    end
end
