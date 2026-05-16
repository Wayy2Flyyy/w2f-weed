W2F.ActiveShipments = {}
W2F.Cooldowns = {}
W2F.BribeCooldowns = {}

CreateThread(function()
    W2F.Debug('Initialising server...')

    W2F.InitDatabase()

    W2F.Debug('Server ready. Foundation version', W2F.Version)
end)

--- Re-sync contractor-supplies blip after restart (players already logged in).
AddEventHandler('onResourceStart', function(resource)
    if resource ~= W2F.Resource then return end

    CreateThread(function()
        Wait(1500)
        local players = exports.qbx_core:GetQBPlayers()
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
