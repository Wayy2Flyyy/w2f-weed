Config = Config or {}

Config.Loyalty = {
    Enabled = true,
    StartingLevel = 0,
    --- Highest key in `Levels` (clamp target for DB / API).
    MaxLevel = 5,

    --- ox_inventory shop `SmokeOnTheWaterContractor` (contractor stock).
    --- Player must have at least this loyalty level with the street contact.
    ContractorSuppliesMinLoyalty = 3,

    --- Map blip + parity with ox shop `locations` / `targets` (w2f-weed client + shops.lua).
    ContractorSupplies = {
        Coords = vec3(-1227.56, -1406.1, 3.18),
        Blip = {
            sprite = 478,
            colour = 2,
            scale = 0.7,
            label = 'Contractor supplies',
        },
    },

    Gain = {
        SuccessfulShipment = 1,
        FailedShipment = 0,
        SmallBribe = 1,
        MediumBribe = 2,
        LargeBribe = 3
    },

    Levels = {
        [0] = {
            label = 'Unknown',
            priceMultiplier = 1.75,
            hintQuality = 'poor',
            shipmentTier = 'basic',
            cooldownMultiplier = 1.25,
            rareChanceBonus = 0
        },

        [1] = {
            label = 'Recognised',
            priceMultiplier = 1.45,
            hintQuality = 'basic',
            shipmentTier = 'basic',
            cooldownMultiplier = 1.10,
            rareChanceBonus = 2
        },

        [2] = {
            label = 'Trusted',
            priceMultiplier = 1.20,
            hintQuality = 'better',
            shipmentTier = 'standard',
            cooldownMultiplier = 1.00,
            rareChanceBonus = 5
        },

        [3] = {
            label = 'Connected',
            priceMultiplier = 1.00,
            hintQuality = 'good',
            shipmentTier = 'improved',
            cooldownMultiplier = 0.85,
            rareChanceBonus = 8
        },

        [4] = {
            label = 'Inner Circle',
            priceMultiplier = 0.85,
            hintQuality = 'strong',
            shipmentTier = 'premium',
            cooldownMultiplier = 0.75,
            rareChanceBonus = 12
        },

        [5] = {
            label = 'Family',
            priceMultiplier = 0.70,
            hintQuality = 'best',
            shipmentTier = 'rare',
            cooldownMultiplier = 0.60,
            rareChanceBonus = 18
        }
    }
}
