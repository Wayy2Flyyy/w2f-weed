-- ─────────────────────────────────────────────
-- w2f-weed | Config | Strains
--
-- Fictional GTA roleplay strain definitions.
-- Each strain links a seed item to its bud item; harvest *amount* is Config.Growth.HarvestBud.
-- `yield` on each strain is unused by harvest (kept for reference / future).
-- ─────────────────────────────────────────────

Config = Config or {}

Config.Strains = {
    Enabled = true,

    -- Default strain id used when seed is unknown (kept disabled by default).
    DefaultStrainId = nil,

    -- ─── Strain catalogue ────────────────────
    -- key = strain id (string)
    -- seedItem must exist in ox_inventory items.lua
    -- budItem  must exist in ox_inventory items.lua
    Catalogue = {
        purple_runtz = {
            id              = 'purple_runtz',
            label           = 'Purple Runtz',
            seedItem        = 'purple_runtz_seed',
            budItem         = 'purple_runtz_bud',
            growthMultiplier = 1.00,
            yield = {
                min = 2,
                max = 4,
            },
            quality = {
                min = 30,
                max = 60,
            },
            description = 'Common cultivar with reliable, modest yields.',
        },

        skunk = {
            id              = 'skunk',
            label           = 'Skunk',
            seedItem        = 'skunk_seed',
            budItem         = 'skunk_bud',
            growthMultiplier = 1.05,
            yield = {
                min = 2,
                max = 5,
            },
            quality = {
                min = 35,
                max = 65,
            },
            description = 'Pungent cultivar with moderate yield and quality.',
        },

        hybrid = {
            id              = 'hybrid',
            label           = 'Hybrid',
            seedItem        = 'hybrid_seed',
            budItem         = 'hybrid_bud',
            growthMultiplier = 1.10,
            yield = {
                min = 3,
                max = 6,
            },
            quality = {
                min = 45,
                max = 75,
            },
            description = 'Balanced crossbreed with steady output.',
        },

        purple_palm_tree_delight = {
            id              = 'purple_palm_tree_delight',
            label           = 'Purple Palm Tree Delight',
            seedItem        = 'purple_palm_tree_delight_seed',
            budItem         = 'purple_palm_tree_delight_bud',
            growthMultiplier = 0.95,
            yield = {
                min = 3,
                max = 7,
            },
            quality = {
                min = 55,
                max = 85,
            },
            description = 'Premium cultivar with superior quality.',
        },

        exotic = {
            id              = 'exotic',
            label           = 'Exotic',
            seedItem        = 'exotic_seed',
            budItem         = 'exotic_bud',
            growthMultiplier = 0.90,
            yield = {
                min = 4,
                max = 8,
            },
            quality = {
                min = 70,
                max = 95,
            },
            description = 'Rare cultivar with exceptional traits.',
        },
    },
}
