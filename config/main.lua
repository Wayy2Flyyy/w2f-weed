Config = Config or {}

Config.Debug = true

Config.Framework = {
    Core = 'qbx_core',
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
