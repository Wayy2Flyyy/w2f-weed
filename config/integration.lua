Config = Config or {}

Config.StoreIntegration = {
    Enabled = true,
    Resource = 'w2f-store',

    BuyableThroughStores = {
        'plant_pot',
        'soil_bag',
        'watering_can',
        'fertilizer_basic',
        'fertilizer_premium',
        -- 'grow_light', -- disabled until grow-light placement is ready
        'drying_rack',
        'trimming_scissors',
        'empty_baggies',
        'digital_scale'
    },

    SeedsBuyable = false,
    SeedsOnlyFromShipments = true,

    Notes = {
        'Seeds are only obtained from shipment runs.',
        'Tools and supplies should be handled by w2f-store and ox_inventory.',
        'w2f-weed should not duplicate the store system.'
    }
}
