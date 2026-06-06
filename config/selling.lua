-- ─────────────────────────────────────────────
-- w2f-weed | Config | Street selling
-- ox_target offers on nearby ambient peds while selling mode is active.
-- ─────────────────────────────────────────────

Config = Config or {}

Config.Selling = {
    Enabled = true,
    UseTarget = true,

    --- In-resource toggle command so street selling does not depend solely on an
    --- external radial menu. Set to false/nil to disable the command. The
    --- `w2f-weed:client:toggleStreetSelling` event still works for radial/item hooks.
    Command = 'sellweed',
    CommandHelp = 'Toggle street weed selling (stay in the area).',

    --- Max horizontal distance from the spot where selling was started.
    AreaRadius = 12.0,

    --- How often the client scans for a new buyer ped (ms).
    ScanIntervalMs = 750,

    --- Cooldown before the same ped can be approached again (ms).
    PedCooldownMs = 45000,

    --- Minimum police on duty (0 = disabled).
    MinimumPolice = 0,

    --- Chance the buyer walks away without buying (0-100).
    DeclineChance = 35,

    --- Chance police are alerted after a successful sale (0-100).
    PoliceAlertChance = 12,

    --- Account paid on successful sale.
    PayoutAccount = 'cash',

    --- Sellable ox_inventory item names and payout ranges per unit.
    Items = {
        purple_runtz_bud = { min = 8, max = 22 },
        skunk_bud = { min = 8, max = 24 },
        hybrid_bud = { min = 8, max = 26 },
        purple_palm_tree_delight_bud = { min = 10, max = 30 },
        exotic_bud = { min = 10, max = 34 },
        joint = { min = 12, max = 28 },
        joint_purple_runtz = { min = 14, max = 32 },
        joint_skunk = { min = 14, max = 34 },
        joint_hybrid = { min = 15, max = 36 },
        joint_purple_palm_tree_delight = { min = 16, max = 40 },
        joint_exotic_weed = { min = 18, max = 44 },
        blunt_purple_runtz = { min = 22, max = 48 },
        blunt_skunk = { min = 22, max = 50 },
        blunt_hybrid = { min = 24, max = 52 },
        blunt_purple_palm_tree_delight = { min = 26, max = 56 },
        blunt_exotic_weed = { min = 28, max = 60 },
    },

    Target = {
        SellIcon = 'fa-solid fa-hand-holding-dollar',
        DeclineIcon = 'fa-solid fa-xmark',
        Distance = 2.5,
    },
}
