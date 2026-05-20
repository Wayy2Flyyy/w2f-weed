W2F.ActiveShipments = {}
W2F.Cooldowns = {}
W2F.BribeCooldowns = {}


function W2F.GetOnlinePlayers()
    local core = W2F.Framework.GetCoreName()

    if core == 'qbx_core' then
        return exports.qbx_core:GetQBPlayers() or {}
    end

    if core == 'qb-core' then
        local QBCore = exports['qb-core']:GetCoreObject()
        if not QBCore or not QBCore.Functions then
            return {}
        end
        return QBCore.Functions.GetQBPlayers() or {}
    end

    W2F.Debug('No supported framework found for GetOnlinePlayers')
    return {}
end

CreateThread(function()
    W2F.Debug('Initialising server...')
    W2F.Debug('Detected framework:', W2F.Framework.GetCoreName() or 'none')

    W2F.InitDatabase()

    W2F.Debug('Server ready. Foundation version', W2F.Version)
end)

--- Re-sync contractor-supplies blip after restart (players already logged in).
AddEventHandler('onResourceStart', function(resource)
    if resource ~= W2F.Resource then return end

    CreateThread(function()
        Wait(1500)
        local players = W2F.GetOnlinePlayers()
        if not players then return end

        for _, qPlayer in pairs(players) do
            local cid = qPlayer and qPlayer.PlayerData and qPlayer.PlayerData.citizenid
            if cid then
                W2F.SyncContractorSuppliesBlip(cid)
            end
        end
    end)
end)

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    local cid = Player and Player.PlayerData and Player.PlayerData.citizenid
    if not cid then return end

    CreateThread(function()
        Wait(750)
        W2F.SyncContractorSuppliesBlip(cid)
    end)
end)


RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local src = source
    local citizenid = W2F.GetCitizenId(src)
    if not citizenid then return end

    CreateThread(function()
        Wait(750)
        W2F.SyncContractorSuppliesBlip(citizenid)
    end)
end)

--- Expiry checker: periodically checks active shipments and expires them
CreateThread(function()
    while true do
        Wait(30000)

        local now = W2F.GetTimestamp()

        for citizenid, shipment in pairs(W2F.ActiveShipments) do
            if shipment.expiresAt and now >= shipment.expiresAt then
                W2F.ExpireShipment(citizenid)
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= W2F.Resource then return end
    W2F.Debug('Server cleanup complete.')
end)

AddEventHandler('playerDropped', function()
    local src = source
    local citizenid = W2F.GetCitizenId(src)
    if not citizenid then return end

    if Config.Shipments.RemoveOnDisconnect and W2F.ActiveShipments[citizenid] then
        W2F.ActiveShipments[citizenid] = nil
        W2F.Debug('Cleared shipment for disconnected player', citizenid)
    end
end)
