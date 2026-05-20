Config = Config or {}

Config.Debug = false

Config.Framework = {
    Core = 'auto', -- auto, qbx_core, qb-core
    Preferred = 'qbx_core', -- qbx_core is the main/default framework
    Lib = 'ox_lib',
    Inventory = 'ox_inventory',
    Target = 'ox_target',
    Database = 'oxmysql'
}

Config.Identifier = {
    Type = 'citizenid'
}

Config.Accounts = {
    Cash = 'cash',
    Bank = 'bank',
    BlackMoney = 'black_money'
}

Config.BlackMoneyMode = 'item'

Config.Security = {
    ValidateDistance = true,
    ValidateItems = true,
    ValidateMoney = true,
    ValidateCooldowns = true,
    FailClosed = true,
    ExploitAction = 'log'
}

Config.Foundation = {
    EnableContact = true,
    EnableShipments = true,
    EnableLoyalty = true,
    EnableBribes = true,
    EnableGrowing = false,
    EnableProcessing = false,
    EnableSelling = false
}
