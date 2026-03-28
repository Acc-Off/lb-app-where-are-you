fx_version 'cerulean'
game 'gta5'
lua54 'yes'

title 'WhereAreYou'
description 'Location sharing app for LB Phone'
author 'Acc-Off'

ox_libs {
    'locale',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/bootstrap.lua',
    'client/bridge.lua',
    'client/app.lua',
    'client/sync.lua',
    'client/callbacks/*.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/bootstrap.lua',
    'server/utils.lua',
    'server/repository/*.lua',
    'server/domain/*.lua',
    'server/events.lua',
}

files {
    'ui/dist/**',
    'locales/*.json',
}

ui_page 'ui/dist/index.html'
