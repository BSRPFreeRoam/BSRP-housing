fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'bsrp-housing'
author 'BS Race'
description 'BSRP housing — locations from bsrpfreeroam houselocations (385 houses)'
version '1.0.0'

ui_page 'html/index.html'

shared_script 'config.lua'

client_script 'client/main.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'data/houselocations.json',
}

-- Soft framework: exports.bsrp when started (no hard dep)
dependencies {
    'oxmysql',
}
