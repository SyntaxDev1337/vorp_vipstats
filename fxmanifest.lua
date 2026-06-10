fx_version 'cerulean'
games {'rdr3'}
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

author 'Vip'
description 'VORP Core VIP Advanced Analytics & UI System'
version '1.1.0'

dependencies {
    'vorp_core',
    'oxmysql'
}

server_scripts {
    'server.lua'
}

client_scripts {
    'client.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html'
}
