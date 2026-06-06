Config = Config or {}

Config.SeedRewards = {
    basic = {
        minSeeds = 2,
        maxSeeds = 4,
        pool = {
            { item = 'purple_runtz_seed', chance = 100 }
        }
    },

    standard = {
        minSeeds = 3,
        maxSeeds = 6,
        pool = {
            { item = 'purple_runtz_seed', chance = 70 },
            { item = 'skunk_seed', chance = 30 }
        }
    },

    improved = {
        minSeeds = 4,
        maxSeeds = 8,
        pool = {
            { item = 'skunk_seed', chance = 55 },
            { item = 'hybrid_seed', chance = 45 }
        }
    },

    premium = {
        minSeeds = 5,
        maxSeeds = 10,
        pool = {
            { item = 'hybrid_seed', chance = 60 },
            { item = 'purple_palm_tree_delight_seed', chance = 40 }
        }
    },

    rare = {
        minSeeds = 6,
        maxSeeds = 12,
        pool = {
            { item = 'purple_palm_tree_delight_seed', chance = 70 },
            { item = 'exotic_seed', chance = 30 }
        }
    }
}
