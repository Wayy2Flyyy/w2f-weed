local activeShipment = nil
local shipmentBlip = nil
local shipmentRadius = nil
local expiryThread = nil

--- Receive shipment area data from server and set up the client-side visuals
---@param data table { hint: string, area: vector3, radius: number, expiresAt: integer }
function W2F.SetActiveShipment(data)
    W2F.ClearShipmentVisuals()

    activeShipment = data

    if Config.Shipments.ShowAreaRadius and data.area then
        shipmentRadius = AddBlipForRadius(data.area.x, data.area.y, data.area.z, data.radius or Config.Shipments.AreaRadius)
        SetBlipHighDetail(shipmentRadius, true)
        SetBlipColour(shipmentRadius, 69)
        SetBlipAlpha(shipmentRadius, 80)

        shipmentBlip = AddBlipForCoord(data.area.x, data.area.y, data.area.z)
        SetBlipSprite(shipmentBlip, 478)
        SetBlipDisplay(shipmentBlip, 4)
        SetBlipScale(shipmentBlip, 0.9)
        SetBlipColour(shipmentBlip, 69)
        SetBlipAsShortRange(shipmentBlip, false)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(Locale('shipment_blip_label'))
        EndTextCommandSetBlipName(shipmentBlip)
    end

    lib.notify({ title = 'Shipment', description = Locale('shipment_started', data.hint), type = 'info', duration = 8000 })
    W2F.Debug('Shipment area set, hint:', data.hint)

    W2F.StartExpiryWatcher()
end

--- Begin searching the shipment location when close enough
function W2F.SearchShipment()
    if not activeShipment then
        lib.notify({ title = 'Shipment', description = Locale('no_active_shipment'), type = 'error' })
        return
    end

    local playerCoords = GetEntityCoords(cache.ped)
    local dist = #(playerCoords - activeShipment.coords)
    local areaR = activeShipment.radius or Config.Shipments.AreaRadius
    local maxDist = areaR + (Config.Shipments.SearchRadiusBuffer or 12.0)

    if dist > maxDist then
        lib.notify({ title = 'Shipment', description = Locale('shipment_too_far'), type = 'error' })
        return
    end

    local minSep = tonumber(Config.Shipments.MinSearchSpotSeparation) or 0.0
    if minSep > 0 and activeShipment.lastSearchSpot then
        if W2F.FlatDistance(playerCoords, activeShipment.lastSearchSpot) < minSep then
            lib.notify({ title = 'Shipment', description = Locale('shipment_search_same_spot'), type = 'error' })
            return
        end
    end

    local success = lib.progressBar({
        duration = 8000,
        label = Locale('searching_shipment'),
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'anim@gangops@facility@servers@bodysearch@', clip = 'player_search' }
    })

    if not success then
        lib.notify({ title = 'Shipment', description = Locale('search_cancelled'), type = 'error' })
        return
    end

    TriggerServerEvent('w2f-weed:server:completeShipment')
end

--- Clear all shipment visuals (blips, radius)
function W2F.ClearShipmentVisuals()
    if shipmentBlip then
        RemoveBlip(shipmentBlip)
        shipmentBlip = nil
    end

    if shipmentRadius then
        RemoveBlip(shipmentRadius)
        shipmentRadius = nil
    end

    activeShipment = nil

    W2F.Debug('Shipment visuals cleared.')
end

--- Clean up active shipment zone (alias for resource stop)
function W2F.CleanupShipmentZone()
    W2F.ClearShipmentVisuals()
    expiryThread = nil
end

--- Watch for shipment expiry and auto-clear
function W2F.StartExpiryWatcher()
    if expiryThread then return end

    expiryThread = true

    CreateThread(function()
        while activeShipment and expiryThread do
            if activeShipment.expiresAt and W2F.HasExpired(activeShipment.expiresAt) then
                lib.notify({ title = 'Shipment', description = Locale('shipment_expired'), type = 'error', duration = 6000 })
                W2F.ClearShipmentVisuals()
                break
            end
            Wait(5000)
        end
        expiryThread = nil
    end)
end

--- Check if the player has an active shipment on the client
---@return boolean
function W2F.HasActiveShipment()
    return activeShipment ~= nil
end

RegisterNetEvent('w2f-weed:client:shipmentSearchProgress', function(data)
    if not activeShipment or type(data) ~= 'table' then return end
    if data.lastSearchSpot then
        activeShipment.lastSearchSpot = data.lastSearchSpot
    end
    if data.searchesDone ~= nil then
        activeShipment.searchesDone = data.searchesDone
    end
    if data.searchesRequired ~= nil then
        activeShipment.searchesRequired = data.searchesRequired
    end
end)

RegisterNetEvent('w2f-weed:client:setShipment', function(data)
    if not data then return end
    W2F.SetActiveShipment(data)
end)

RegisterNetEvent('w2f-weed:client:clearShipment', function()
    W2F.ClearShipmentVisuals()
end)

RegisterNetEvent('w2f-weed:client:shipmentCompleted', function()
    lib.notify({ title = 'Shipment', description = Locale('shipment_completed'), type = 'success', duration = 6000 })
    W2F.ClearShipmentVisuals()
end)

CreateThread(function()
    while not W2F.IsClientReady() do
        Wait(200)
    end

    local existing = lib.callback.await('w2f-weed:server:getActiveShipment', false)
    if existing then
        W2F.SetActiveShipment(existing)
    end
end)
