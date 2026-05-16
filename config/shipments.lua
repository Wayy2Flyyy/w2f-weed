Config = Config or {}

Config.Shipments = {
    Enabled = true,

    OneActiveShipmentPerPlayer = true,

    UseInGameHours = true,
    MinInGameHours = 3,
    MaxInGameHours = 4,
    RealTimeFallbackMinutes = 20,

    RequirePaymentForTip = true,

    ShowAreaRadius = true,
    ShowExactBlip = false,
    AreaRadius = 120.0,
    SearchDistance = 4.0,
    --- Used with shipment location radius: extra meters allowed for latency / GPS fuzz
    SearchRadiusBuffer = 12.0,

    --- Each shipment needs this many successful search minigames (server-randomized).
    MinSearchAttempts = 1,
    MaxSearchAttempts = 12,

    RemoveOnTimeout = true,
    RemoveOnDisconnect = false,

    ContactCooldown = 10 * 60,
    CompletionCooldown = 15 * 60,

    RequirePoliceOnline = false,
    MinimumPolice = 0
}

Config.ShipmentLocations = {
    {
        id = 'vespucci_backlot',
        label = 'Vespucci Backlot',
        areaHint = 'Behind old shops near Vespucci.',
        coords = vector3(-1172.2, -1572.5, 4.3),
        radius = 120.0,
        risk = 'low',
        tiers = { 'basic', 'standard' },
        enabled = true
    },

    {
        id = 'sandy_airstrip_crates',
        label = 'Sandy Airstrip Crates',
        areaHint = 'Near the dusty airstrip up north.',
        coords = vector3(1735.3, 3294.8, 41.1),
        radius = 150.0,
        risk = 'medium',
        tiers = { 'standard', 'improved' },
        enabled = true
    },

    {
        id = 'elysian_dock_corner',
        label = 'Elysian Dock Corner',
        areaHint = 'Near the industrial docks where nobody asks questions.',
        coords = vector3(875.4, -2995.7, 5.9),
        radius = 160.0,
        risk = 'high',
        tiers = { 'improved', 'premium' },
        enabled = true
    },

    {
        id = 'paleto_forest_drop',
        label = 'Paleto Forest Drop',
        areaHint = 'Somewhere quiet in the trees north of the city.',
        coords = vector3(-558.7, 5389.1, 70.2),
        radius = 180.0,
        risk = 'medium',
        tiers = { 'standard', 'improved' },
        enabled = true
    },

    {
        id = 'la_mesa_storage_yard',
        label = 'La Mesa Storage Yard',
        areaHint = 'Near storage units and old industrial buildings.',
        coords = vector3(850.5, -2178.2, 30.3),
        radius = 120.0,
        risk = 'high',
        tiers = { 'premium', 'rare' },
        enabled = true
    }
}
