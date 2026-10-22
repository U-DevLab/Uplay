fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'uplay'
author 'UDevLab'
description 'U-Play: car music with built-in YouTube search'
version '1.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/fonts/*.woff2',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'locales.lua',
}

client_scripts {
    'client.lua',
}

server_scripts {
    'server_config.lua',
    'server.lua',
}

dependencies {
    'ox_lib',
    'xsound',
}
