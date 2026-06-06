Config = Config or {}

Config.Debug = false

Config.Framework = {
    Core = 'auto', -- auto, qbx_core, qb-core, esx
    Preferred = 'qbx_core', -- qbx_core is the main/default framework
    Lib = 'ox_lib',
    Inventory = 'ox_inventory',
    Target = 'ox_target',
    Database = 'oxmysql'
}

Config.Identifier = {
    -- QB/Qbox stores citizenid; ESX stores identifier in the same DB columns.
    Type = 'auto', -- auto, citizenid, identifier
}

Config.PoliceAlert = {
    QbEvent = 'police:server:policeAlert',
    EsxEvent = '', -- leave empty to notify online ESX police via ox_lib
    EsxPoliceJob = 'police',
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

-- ─────────────────────────────────────────────
-- Master feature switches (read via W2F.Foundation('Flag')).
-- Each flag is the authoritative on/off for a whole subsystem. A feature is
-- only active when BOTH its master flag here AND its own module `Enabled`
-- (e.g. Config.Planters.Enabled) are true, so operators get one obvious knob.
-- ─────────────────────────────────────────────
Config.Foundation = {
    EnableContact = true,    -- street contact ped + dealer interactions
    EnableShipments = true,  -- seed shipment runs
    EnableLoyalty = true,    -- loyalty tiers, contractor supply blip
    EnableBribes = true,     -- bribing the contact for loyalty
    EnableGrowing = true,    -- planters, soil, growth, harvest
    EnableProcessing = true, -- rolling station (buds -> joints)
    EnableSelling = true     -- street selling to ambient peds
}
