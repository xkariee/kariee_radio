fx_version 'cerulean'
game 'gta5'
author 'kariee'
lua54 'true'

dependency 'ox_target'

shared_scripts {
    '@es_extended/imports.lua',
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client/main.lua',
    'client/broadcast.lua',
    'client/dj.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/playlists.lua',
    'server/social.lua',
    'server/broadcast.lua',
    'server/dj.lua'
}

ui_page 'web/dist/index.html'

files {
    'web/dist/index.html',
    'web/dist/assets/*',
    'web/dist/favicon.svg',
    'web/dist/icons.svg'
}
