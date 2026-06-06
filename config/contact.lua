Config = Config or {}

Config.Contact = {
    Enabled = true,
    Name = 'Street Contact',
    Description = 'A hidden contact who knows about seed shipments.',
    Coords = vector4(-11.42, -1438.62, 31.10, 180.0),

    UsePed = true,
    UseTarget = true,
    UseBlip = false,

    InteractionDistance = 2.0,

    Ped = {
        Model = 'g_m_y_mexgoon_02',
        Scenario = 'WORLD_HUMAN_SMOKING',
        Invincible = true,
        Frozen = true,
        BlockingEvents = true
    },

    Target = {
        Icon = 'fa-solid fa-seedling',
        Label = 'Speak to Contact',
        Distance = 2.0
    }
}

Config.Payment = {
    Enabled = true,
    Account = 'black_money',
    BaseTipPrice = 15000,
    MinTipPrice = 3500,
    PriceRoundsToNearest = 100,

    AllowCash = false,
    AllowBank = false,
    AllowBlackMoney = true
}

Config.Bribes = {
    Enabled = true,
    Item = 'purple_runtz_bud',

    Options = {
        small = {
            label = 'Small Bribe',
            amount = 5,
            loyaltyGain = 1,
            cooldown = 15 * 60
        },

        medium = {
            label = 'Medium Bribe',
            amount = 15,
            loyaltyGain = 2,
            cooldown = 30 * 60
        },

        large = {
            label = 'Large Bribe',
            amount = 30,
            loyaltyGain = 3,
            cooldown = 60 * 60
        }
    }
}
