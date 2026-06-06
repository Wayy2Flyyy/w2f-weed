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
    AreaRadius = 14.0,
    SearchDistance = 4.0,
    --- Used with shipment location radius: extra meters allowed for latency / GPS fuzz
    SearchRadiusBuffer = 1.5,

    --- Minimum horizontal distance (m) from your last successful search in this drop before
    --- you can search again — stops spamming the same spot inside the zone.
    MinSearchSpotSeparation = 5.0,

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
        radius = 14.0,
        risk = 'low',
        tiers = { 'basic', 'standard' },
        enabled = true
    },

    {
        id = 'sandy_airstrip_crates',
        label = 'Sandy Airstrip Crates',
        areaHint = 'Near the dusty airstrip up north.',
        coords = vector3(1735.3, 3294.8, 41.1),
        radius = 17.5,
        risk = 'medium',
        tiers = { 'standard', 'improved' },
        enabled = true
    },

    {
        id = 'elysian_dock_corner',
        label = 'Elysian Dock Corner',
        areaHint = 'Near the industrial docks where nobody asks questions.',
        coords = vector3(875.4, -2995.7, 5.9),
        radius = 19.0,
        risk = 'high',
        tiers = { 'improved', 'premium' },
        enabled = true
    },

    {
        id = 'paleto_forest_drop',
        label = 'Paleto Forest Drop',
        areaHint = 'Somewhere quiet in the trees north of the city.',
        coords = vector3(-558.7, 5389.1, 70.2),
        radius = 17.5,
        risk = 'medium',
        tiers = { 'standard', 'improved' },
        enabled = true
    },

    {
        id = 'la_mesa_storage_yard',
        label = 'La Mesa Storage Yard',
        areaHint = 'Near storage units and old industrial buildings.',
        coords = vector3(850.5, -2178.2, 30.3),
        radius = 14.0,
        risk = 'high',
        tiers = { 'premium', 'rare' },
        enabled = true
    },

    { id = 'grapeseed_farmtrack', label = 'Grapeseed Farm Track', areaHint = 'Dirt roads past the vineyards.', coords = vector3(2441.8, 4978.6, 46.8), radius = 14.0, risk = 'low', tiers = { 'basic', 'standard' }, enabled = true },
    { id = 'harmony_trailer_park', label = 'Harmony Trailers', areaHint = 'Shabby trailers off the freeway.', coords = vector3(612.4, 2747.9, 42.0), radius = 14.0, risk = 'low', tiers = { 'basic', 'standard' }, enabled = true },
    { id = 'stab_city_scrap', label = 'Stab City', areaHint = 'Desert bikers and burned RVs.', coords = vector3(67.3, 3693.3, 39.7), radius = 14.0, risk = 'medium', tiers = { 'standard', 'improved' }, enabled = true },
    { id = 'lsia_cargo_fence', label = 'LSIA Cargo', areaHint = 'Fenced cargo pads by the runways.', coords = vector3(-1032.4, -2735.6, 13.8), radius = 17.5, risk = 'medium', tiers = { 'standard', 'improved' }, enabled = true },
    { id = 'terminal_island_warehouses', label = 'Terminal Warehouses', areaHint = 'Low docks south of the port.', coords = vector3(-296.1, -2761.4, 6.0), radius = 17.5, risk = 'high', tiers = { 'improved', 'premium' }, enabled = true },
    { id = 'banning_recycle_yard', label = 'Banning Scrap', areaHint = 'Recycling yards under the overpass.', coords = vector3(-329.5, -1334.2, 31.3), radius = 14.0, risk = 'medium', tiers = { 'standard', 'improved' }, enabled = true },
    { id = 'strawberry_alley', label = 'Strawberry Alley', areaHint = 'Back alleys off the boulevard.', coords = vector3(264.9, -1261.8, 29.2), radius = 14.0, risk = 'medium', tiers = { 'standard', 'improved' }, enabled = true },
    { id = 'davis_grove_st', label = 'Davis Streets', areaHint = 'Southside residential sprawl.', coords = vector3(198.5, -1852.0, 27.2), radius = 14.0, risk = 'medium', tiers = { 'standard', 'improved' }, enabled = true },
    { id = 'el_burro_docks', label = 'El Burro Heights', areaHint = 'Warehouses facing the ocean.', coords = vector3(1196.6, -3257.5, 7.1), radius = 17.5, risk = 'high', tiers = { 'improved', 'premium' }, enabled = true },
    { id = 'murrieta_oil_pumps', label = 'Murrieta Oil Field', areaHint = 'Pumpjacks and dirt berms.', coords = vector3(1535.9, -2094.2, 77.1), radius = 17.5, risk = 'medium', tiers = { 'standard', 'improved' }, enabled = true },
    { id = 'grand_senora_chiliad_foot', label = 'Chiliad Foothills', areaHint = 'Sparse shrubs where the air is thin.', coords = vector3(2488.1, 4136.2, 38.2), radius = 14.0, risk = 'low', tiers = { 'basic', 'standard' }, enabled = true },
    { id = 'senora_highway_yard', label = 'Senora Desert Yard', areaHint = 'Dusty lot beside the highway.', coords = vector3(2660.2, 3272.1, 55.5), radius = 14.0, risk = 'low', tiers = { 'basic', 'standard' }, enabled = true },
    { id = 'sandy_liquor_alley', label = 'Sandy Storefront', areaHint = 'Main drag but not the nice part.', coords = vector3(1392.8, 3605.2, 34.9), radius = 14.0, risk = 'low', tiers = { 'basic', 'standard' }, enabled = true },
    { id = 'alamo_sea_south', label = 'Alamo Mud Flats', areaHint = 'Shoreline east of the shallow lake.', coords = vector3(1320.2, 4228.1, 33.2), radius = 14.0, risk = 'low', tiers = { 'basic', 'standard' }, enabled = true },
    { id = 'zancudo_river_mouth', label = 'Zancudo River', areaHint = 'Brush by the widening river.', coords = vector3(-543.2, 4421.8, 35.1), radius = 14.0, risk = 'medium', tiers = { 'standard', 'improved' }, enabled = true },
    { id = 'route68_diner_ruin', label = 'Route 68 Stop', areaHint = 'Lonely roadstop in the desert.', coords = vector3(-1115.2, 2682.1, 18.6), radius = 14.0, risk = 'low', tiers = { 'basic', 'standard' }, enabled = true },
    { id = 'great_chaparral_woods', label = 'Great Chaparral', areaHint = 'Scrub oaks and hiking paths.', coords = vector3(-1590.3, 4512.8, 18.9), radius = 14.0, risk = 'low', tiers = { 'basic', 'standard' }, enabled = true },
    { id = 'north_chumash_trail', label = 'North Chumash', areaHint = 'Cliff roads above the beach.', coords = vector3(-2554.2, 2302.5, 33.2), radius = 17.5, risk = 'medium', tiers = { 'standard', 'improved' }, enabled = true },
    { id = 'banham_canyon_view', label = 'Banham Canyon', areaHint = 'Wealthy hills, quiet switchbacks.', coords = vector3(-3044.2, 596.0, 7.4), radius = 17.5, risk = 'high', tiers = { 'premium', 'rare' }, enabled = true },
    { id = 'chumash_stripmall', label = 'Chumash Strip', areaHint = 'Small shops by the coastal road.', coords = vector3(-3190.2, 1101.5, 20.8), radius = 14.0, risk = 'medium', tiers = { 'standard', 'improved' }, enabled = true },
    { id = 'pacific_bluffs_lookout', label = 'Pacific Bluffs', areaHint = 'Windy bluff above the water.', coords = vector3(-3022.4, 59.2, 14.4), radius = 17.5, risk = 'high', tiers = { 'improved', 'premium' }, enabled = true },
    { id = 'richman_glen_estate', label = 'Richman Glen', areaHint = 'Secluded mansions and long drives.', coords = vector3(-1520.8, 851.2, 181.6), radius = 17.5, risk = 'high', tiers = { 'premium', 'rare' }, enabled = true },
    { id = 'mirror_park_canal', label = 'Mirror Park Canal', areaHint = 'Pretty houses, ugly errands.', coords = vector3(1098.4, -786.2, 57.3), radius = 14.0, risk = 'medium', tiers = { 'standard', 'improved' }, enabled = true },
    { id = 'east_vinewood_hills', label = 'East Vinewood', areaHint = 'Hillside roads by the sign.', coords = vector3(872.3, -234.1, 69.7), radius = 14.0, risk = 'medium', tiers = { 'standard', 'improved' }, enabled = true },
    { id = 'legion_parking_garage', label = 'Legion Square', areaHint = 'Downtown foot traffic cover.', coords = vector3(195.2, -933.1, 30.7), radius = 14.0, risk = 'medium', tiers = { 'standard', 'improved' }, enabled = true },
    { id = 'pillbox_rooftops', label = 'Pillbox Rooftops', areaHint = 'Medical district service levels.', coords = vector3(-23.5, -706.3, 32.7), radius = 14.0, risk = 'high', tiers = { 'improved', 'premium' }, enabled = true },
    { id = 'little_seoul_market', label = 'Little Seoul', areaHint = 'Busy streets, easy to vanish.', coords = vector3(-579.2, -857.1, 25.7), radius = 14.0, risk = 'medium', tiers = { 'standard', 'improved' }, enabled = true },
    { id = 'vespucci_canal_bridge', label = 'Vespucci Canals', areaHint = 'Waterways and foot bridges.', coords = vector3(-1022.3, -998.1, 2.2), radius = 14.0, risk = 'low', tiers = { 'basic', 'standard' }, enabled = true },
    { id = 'del_perro_pier_north', label = 'Del Perro Beach', areaHint = 'Tourist sand north of the pier.', coords = vector3(-1580.2, -1012.3, 13.0), radius = 14.0, risk = 'medium', tiers = { 'standard', 'improved' }, enabled = true },
    { id = 'maze_bank_arena_lot', label = 'Arena Lot', areaHint = 'Parking chaos near the arena.', coords = vector3(-324.2, -1968.1, 22.4), radius = 14.0, risk = 'medium', tiers = { 'standard', 'improved' }, enabled = true },
    { id = 'la_puerta_freeway', label = 'La Puerta', areaHint = 'Industrial wedge by the freeway.', coords = vector3(-1037.2, -1391.2, 5.5), radius = 17.5, risk = 'high', tiers = { 'improved', 'premium' }, enabled = true },
    { id = 'cypress_flats_tracks', label = 'Cypress Flats', areaHint = 'Rail sidings and metal shops.', coords = vector3(945.2, -2487.1, 28.4), radius = 17.5, risk = 'high', tiers = { 'improved', 'premium' }, enabled = true },
    { id = 'harmony_lumber_yard', label = 'Harmony Lumber', areaHint = 'Stacked timber and chain-link.', coords = vector3(1162.3, 2727.8, 38.0), radius = 14.0, risk = 'low', tiers = { 'basic', 'standard' }, enabled = true },
    { id = 'tataviam_fossil', label = 'Tataviam Mountains', areaHint = 'Ridge roads east of the city.', coords = vector3(2590.2, 616.1, 95.2), radius = 14.0, risk = 'medium', tiers = { 'standard', 'improved' }, enabled = true },
    { id = 'vinewood_racetrack_lot', label = 'Vinewood Racetrack', areaHint = 'Empty tarmac when no events run.', coords = vector3(1021.5, -2464.2, 28.6), radius = 14.0, risk = 'medium', tiers = { 'standard', 'improved' }, enabled = true },
    { id = 'metro_tunnel_portal', label = 'LS Metro Access', areaHint = 'Concrete canyon downtown.', coords = vector3(-532.1, -1267.8, 26.9), radius = 14.0, risk = 'high', tiers = { 'improved', 'premium' }, enabled = true },
    { id = 'vinewood_cemetery', label = 'Vinewood Cemetery', areaHint = 'Quiet stones, bad company.', coords = vector3(-165.2, -130.4, 42.5), radius = 14.0, risk = 'medium', tiers = { 'standard', 'improved' }, enabled = true },
    { id = 'rockford_hills_backlot', label = 'Rockford Hills', areaHint = 'Alley service for fancy stores.', coords = vector3(-819.2, -133.1, 37.5), radius = 17.5, risk = 'high', tiers = { 'premium', 'rare' }, enabled = true },
    { id = 'hawick_garage_row', label = 'Hawick', areaHint = 'Garage fronts and tint shops.', coords = vector3(309.2, -236.1, 54.0), radius = 14.0, risk = 'medium', tiers = { 'standard', 'improved' }, enabled = true },
    { id = 'textile_city_skid', label = 'Textile City', areaHint = 'Cheap hotels and graffiti.', coords = vector3(419.2, -807.1, 29.5), radius = 14.0, risk = 'medium', tiers = { 'standard', 'improved' }, enabled = true },
    { id = 'mission_row_pd_back', label = 'Mission Row', areaHint = 'Bold drop near the badge.', coords = vector3(455.2, -1029.1, 28.4), radius = 19.0, risk = 'high', tiers = { 'premium', 'rare' }, enabled = true },
    { id = 'rancho_projects', label = 'Rancho', areaHint = 'Warm nights, thin walls.', coords = vector3(361.2, -2049.1, 22.2), radius = 14.0, risk = 'medium', tiers = { 'standard', 'improved' }, enabled = true },
    { id = 'chamberlain_hills', label = 'Chamberlain Hills', areaHint = 'Low rises and loud parties.', coords = vector3(-156.2, -1622.1, 33.6), radius = 14.0, risk = 'medium', tiers = { 'standard', 'improved' }, enabled = true },
    { id = 'west_eclipse_bungalow', label = 'West Eclipse', areaHint = 'Beach bungalows, dim porches.', coords = vector3(-1524.2, -434.1, 35.4), radius = 14.0, risk = 'medium', tiers = { 'standard', 'improved' }, enabled = true },
    { id = 'vespucci_beach_walk', label = 'Vespucci Boardwalk', areaHint = 'Neon and foot traffic.', coords = vector3(-1205.2, -1498.1, 4.4), radius = 14.0, risk = 'low', tiers = { 'basic', 'standard' }, enabled = true },
    { id = 'la_mesa_garage_row', label = 'La Mesa Garages', areaHint = 'Auto bays behind fences.', coords = vector3(862.2, -2121.4, 30.5), radius = 14.0, risk = 'high', tiers = { 'improved', 'premium' }, enabled = true },
    { id = 'el_rancho_boulevard', label = 'El Rancho', areaHint = 'Strip mall shadows.', coords = vector3(1134.2, -789.1, 57.6), radius = 14.0, risk = 'medium', tiers = { 'standard', 'improved' }, enabled = true },
    { id = 'burton_construction', label = 'Burton Construction', areaHint = 'Orange cones and plywood.', coords = vector3(-153.2, -257.1, 43.6), radius = 14.0, risk = 'medium', tiers = { 'standard', 'improved' }, enabled = true },
    { id = 'alta_street_loft', label = 'Alta Street', areaHint = 'High-rise loading docks.', coords = vector3(269.2, -83.1, 70.1), radius = 14.0, risk = 'high', tiers = { 'improved', 'premium' }, enabled = true },
    { id = 'morningwood_clinic_block', label = 'Morningwood', areaHint = 'Clinic block side streets.', coords = vector3(-1318.2, -394.1, 36.6), radius = 14.0, risk = 'medium', tiers = { 'standard', 'improved' }, enabled = true },
    { id = 'koreatown_noodle', label = 'Koreatown', areaHint = 'Neon signs, steam vents.', coords = vector3(-628.2, -1174.1, 14.1), radius = 14.0, risk = 'medium', tiers = { 'standard', 'improved' }, enabled = true },
    { id = 'del_perro_offices', label = 'Del Perro Offices', areaHint = 'Glass towers, hidden dumpsters.', coords = vector3(-1447.2, -537.1, 34.7), radius = 17.5, risk = 'high', tiers = { 'premium', 'rare' }, enabled = true },
    { id = 'vespucci_marina_tools', label = 'Vespucci Marina', areaHint = 'Slip roads and boat trailers.', coords = vector3(-807.2, -1494.1, 2.2), radius = 14.0, risk = 'low', tiers = { 'basic', 'standard' }, enabled = true },
    { id = 'observatory_service', label = 'Galileo Observatory', areaHint = 'Service roads behind the dome.', coords = vector3(-428.2, 1123.1, 325.9), radius = 14.0, risk = 'medium', tiers = { 'standard', 'improved' }, enabled = true },
    { id = 'vinewood_winery_cellar', label = 'Marlowe Vineyard', areaHint = 'Grape bins and cellar doors.', coords = vector3(-1866.2, 2062.1, 140.9), radius = 17.5, risk = 'high', tiers = { 'improved', 'premium' }, enabled = true },
    { id = 'ron_alternates_wind', label = 'Ron Alternates', areaHint = 'Turbine access roads.', coords = vector3(2414.2, 1644.1, 38.2), radius = 14.0, risk = 'low', tiers = { 'basic', 'standard' }, enabled = true },
    { id = 'davis_quartz_pit', label = 'Davis Quartz', areaHint = 'Gravel pit dust clouds.', coords = vector3(2954.2, 2786.1, 41.4), radius = 14.0, risk = 'low', tiers = { 'basic', 'standard' }, enabled = true },
    { id = 'sandy_beaches_north', label = 'Sandy Shores North', areaHint = 'Dried lakebed shacks.', coords = vector3(1926.2, 3734.1, 32.7), radius = 14.0, risk = 'low', tiers = { 'basic', 'standard' }, enabled = true },
    { id = 'paleto_bay_industrial', label = 'Paleto Industrial', areaHint = 'Back lots behind lumber.', coords = vector3(-195.2, 6260.1, 31.5), radius = 14.0, risk = 'low', tiers = { 'basic', 'standard' }, enabled = true },
    { id = 'paleto_cove_boats', label = 'Paleto Cove', areaHint = 'Hidden cove east of town.', coords = vector3(-1590.2, 5200.1, 14.0), radius = 17.5, risk = 'medium', tiers = { 'standard', 'improved' }, enabled = true },
    { id = 'procopio_promenade', label = 'Procopio Beach', areaHint = 'Tourist cabins, empty lots.', coords = vector3(-115.2, 6636.1, 11.0), radius = 14.0, risk = 'low', tiers = { 'basic', 'standard' }, enabled = true },
    { id = 'braddock_tunnel_west', label = 'Braddock Pass', areaHint = 'Tunnel mouth in the pines.', coords = vector3(2488.2, 4962.1, 44.8), radius = 14.0, risk = 'medium', tiers = { 'standard', 'improved' }, enabled = true },
    { id = 'lago_zancudo_wetlands', label = 'Lago Zancudo', areaHint = 'Marsh grass and reeds.', coords = vector3(-2177.2, 2599.1, 3.1), radius = 17.5, risk = 'medium', tiers = { 'standard', 'improved' }, enabled = true },
    { id = 'fort_zancudo_fence_line', label = 'Zancudo Fence Line', areaHint = 'Watching planes without going in.', coords = vector3(-2301.2, 3418.1, 32.8), radius = 19.0, risk = 'high', tiers = { 'premium', 'rare' }, enabled = true },
    { id = 'banning_freight_yard', label = 'Banning Freight', areaHint = 'Container stacks at dusk.', coords = vector3(-445.2, -2851.1, 6.0), radius = 17.5, risk = 'high', tiers = { 'improved', 'premium' }, enabled = true },
    { id = 'popular_st_garage', label = 'Popular Street', areaHint = 'Low warehouses by the river.', coords = vector3(832.2, -2144.1, 29.5), radius = 14.0, risk = 'medium', tiers = { 'standard', 'improved' }, enabled = true },
    { id = 'grove_st_deadend', label = 'Grove Street', areaHint = 'Iconic cul-de-sac energy.', coords = vector3(29.2, -1854.1, 23.2), radius = 14.0, risk = 'medium', tiers = { 'standard', 'improved' }, enabled = true },
    { id = 'downtown_construction_crane', label = 'Downtown Crane Lot', areaHint = 'Skeleton tower and gravel.', coords = vector3(-147.2, -590.1, 32.0), radius = 14.0, risk = 'high', tiers = { 'improved', 'premium' }, enabled = true },
    { id = 'power_st_substation', label = 'Power Street', areaHint = 'Hum from transformers.', coords = vector3(283.2, -1599.1, 31.4), radius = 14.0, risk = 'medium', tiers = { 'standard', 'improved' }, enabled = true },
    { id = 'innocence_blvd_motel', label = 'Innocence Motel Strip', areaHint = 'Neon vacancy signs.', coords = vector3(312.2, -1317.1, 31.9), radius = 14.0, risk = 'medium', tiers = { 'standard', 'improved' }, enabled = true }
}

