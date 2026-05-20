fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'wayy2flyyy'
description 'Qbox/QBCore + ox foundation for w2f-weed (seeds, contact, shipments, placeables, planter growth).'
version '0.2.0'

shared_scripts {
    '@ox_lib/init.lua',

    -- Config (load order matters)
    'config/main.lua',
    'config/contact.lua',
    'config/shipments.lua',
    'config/loyalty.lua',
    'config/rewards.lua',
    'config/integration.lua',
    'config/placeables.lua',
    'config/planters.lua',
    'config/growth.lua',
    'config/strains.lua',
    'config/rolling.lua',

    -- Shared
    'shared/constants.lua',
    'shared/helpers.lua',
    'shared/framework.lua',
    'shared/validation.lua',
    'shared/placeables.lua',
    'shared/planters.lua',

    -- Locale
    'locales/en.lua'
}

client_scripts {
    'client/main.lua',
    'client/peds.lua',
    'client/blips.lua',
    'client/zones.lua',
    'client/contact.lua',
    'client/shipments.lua',
    'client/placeables.lua',
    'client/planters.lua',
    'client/minigame.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',

    'server/main.lua',
    'server/database.lua',
    'server/logging.lua',
    'server/validation.lua',
    'server/loyalty.lua',
    'server/rewards.lua',
    'server/shipments.lua',
    'server/contact.lua',
    'server/callbacks.lua',
    'server/events.lua',
    'server/placeables.lua',
    'server/planters.lua',
    'server/ox_inventory_shop.lua',
    'server/rolling.lua'
}

ui_page 'nui/index.html'

-- ─────────────────────────────────────────────
-- Custom prop streaming
--
-- Drop the matching .ydr / .ybn / .ytyp into stream/.
-- FiveM auto-streams everything in stream/ to every client.
-- The .ytyp files MUST be declared via DLC_ITYP_REQUEST so
-- the archetype definitions register at game-load time.
-- ─────────────────────────────────────────────
files {
    'nui/index.html',
    'nui/style.css',
    'nui/script.js',
    'nui/assets/full_grinder.svg',
    'nui/assets/grinded_weed.svg',
    'nui/assets/rolling_tray.svg',
    'nui/assets/rolling_papers.svg',
    'nui/assets/purple_runtz.svg',
    'nui/assets/purple_runtz_bud.svg',
    'nui/assets/exotic.svg',
    'nui/assets/exotic_bud.svg',
    'nui/assets/hybrid.svg',
    'nui/assets/hybrid_bud.svg',
    'nui/assets/purple_palm_tree_delight.svg',
    'nui/assets/purple_palm_tree_delight_bud.svg',
    'nui/assets/skunk.svg',
    'nui/assets/skunk_bud.svg',
    'stream/empty_planter_box.ytyp',
    'stream/planter_box.ytyp',
    'stream/plant-progress/small-plant.ytyp',
    'stream/plant-progress/med-plant.ytyp',
    'stream/plant-progress/finish-plant.ytyp',
    'stream/plant-progress/ready-plant.ytyp',
}

data_file 'DLC_ITYP_REQUEST' 'stream/empty_planter_box.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/planter_box.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/plant-progress/small-plant.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/plant-progress/med-plant.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/plant-progress/finish-plant.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/plant-progress/ready-plant.ytyp'

dependencies {
    'ox_lib',
    'ox_inventory',
    'ox_target',
    'oxmysql'
}
