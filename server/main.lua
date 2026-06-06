W2F.ActiveShipments = {}
W2F.Cooldowns = {}
W2F.BribeCooldowns = {}

CreateThread(function()
    W2F.Debug('Initialising server...')
    W2F.Debug('Detected framework:', W2F.Framework.GetCoreName() or 'none')

    W2F.InitDatabase()
    W2F.RehydrateActiveShipments()

    W2F.Debug('Server ready. Foundation version', W2F.Version)
end)

local function syncContractorBlipForIdentifier(identifier)
    if not identifier then return end
    CreateThread(function()
        Wait(750)
        W2F.SyncContractorSuppliesBlip(identifier)
    end)
end

--- Re-sync contractor-supplies blip after restart (players already logged in).
AddEventHandler('onResourceStart', function(resource)
    if resource ~= W2F.Resource then return end

    CreateThread(function()
        Wait(1500)
        local players = W2F.GetOnlinePlayers()
        if not players then return end

        for _, player in pairs(players) do
            local identifier = W2F.GetPlayerIdentifier(player)
            if identifier then
                W2F.SyncContractorSuppliesBlip(identifier)
                -- Re-push any in-progress shipment lead rehydrated from the DB.
                W2F.ResyncShipmentForCitizen(identifier)
            end
        end
    end)
end)

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    syncContractorBlipForIdentifier(W2F.GetPlayerIdentifier(Player))
end)

RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    syncContractorBlipForIdentifier(W2F.GetCitizenId(source))
end)

AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
    syncContractorBlipForIdentifier(W2F.GetPlayerIdentifier(xPlayer))
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
