author 'AxieeStore'
version '1.0.0'
description 'A radio system for FiveM servers with a web interface and advanced features.'

fx_version 'cerulean'
game 'gta5'
lua54 'true'
dependency 'ox_target'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
    'shared/framework.lua'
}

client_scripts {
    'client/utils.lua',
    'client/main.lua',
    'client/broadcast.lua',
    'client/dj.lua',
    'client/lights.lua',
    'client/creator.lua',
    'client/admin.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/database.lua',
    'server/main.lua',
    'server/playlists.lua',
    'server/social.lua',
    'server/broadcast.lua',
    'server/dj.lua',
    'server/admin.lua',
    'server/version.lua'
}

ui_page 'web/dist/index.html'

files {
    'web/dist/index.html',
    'web/dist/assets/*',
    'web/dist/favicon.svg',
}


escrow_ignore {
    'shared/*.lua'
}