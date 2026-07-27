fx_version 'cerulean'
game 'rdr3'

rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

lua54 'yes'

author 'NODE7 Development Studios'
description 'ACE-protected administrator coordinate copier using NODE7 Menu Base.'
version '1.2.0'

shared_script 'config.lua'

client_scripts {
    'client/preload.lua',
    'client/main.lua'
}

server_scripts {
    'server/preload.lua',
    'server/main.lua'
}

ui_page 'html/clipboard.html'

files {
    'html/clipboard.html',
    'html/clipboard.js'
}


dependencies {
    'node7-core',
    'node7-menu-base'
}
