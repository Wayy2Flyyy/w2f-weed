--- Create a new shipment for a player
---@param src number
---@param citizenid string
---@return boolean success
---@return string|nil reason
function W2F.CreateShipment(src, citizenid)
    if W2F.ValidateNoDuplicateShipment(citizenid) then
        return false, 'already_active'
    end

    local loyalty = W2F.GetLoyalty(citizenid)
    local tier = W2F.GetShipmentTier(loyalty)
    local locations = W2F.GetLocationsForTier(tier)

    if #locations == 0 then
        locations = W2F.GetEnabledLocations()
    end

    if #locations == 0 then
        W2F.SecurityLog('No shipment locations available', { citizenid = citizenid, tier = tier })
        return false, 'no_locations'
    end

    local location = locations[math.random(#locations)]

    local duration
    if Config.Shipments.UseInGameHours then
        local minSec = Config.Shipments.MinInGameHours * 120
        local maxSec = Config.Shipments.MaxInGameHours * 120
        duration = math.random(minSec, maxSec)
    else
        duration = Config.Shipments.RealTimeFallbackMinutes * 60
    end

    local effectiveCooldown = W2F.GetEffectiveCooldown(duration, loyalty)
    local now = W2F.GetTimestamp()
    local shipmentId = W2F.GenerateShipmentId()

    local shipment = {
        shipmentId = shipmentId,
        citizenid = citizenid,
        locationId = location.id,
        coords = location.coords,
        hint = location.areaHint,
        radius = location.radius,
        tier = tier,
        risk = location.risk,
        status = W2F.ShipmentStatus.Active,
        createdAt = now,
        expiresAt = now + duration,
        searchesDone = 0,
        searchesRequired = (function()
            local smin = math.max(1, Config.Shipments.MinSearchAttempts or 1)
            local smax = math.max(smin, Config.Shipments.MaxSearchAttempts or 12)
            return math.random(smin, smax)
        end)(),
    }

    W2F.ActiveShipments[citizenid] = shipment

    W2F.InsertShipmentRecord({
        citizenid = citizenid,
        shipmentId = shipmentId,
        locationId = location.id,
        tier = tier,
        status = W2F.ShipmentStatus.Active,
        createdAt = now,
        expiresAt = now + duration
    })

    W2F.UpdateLastContact(citizenid)
    W2F.Cooldowns[citizenid] = now

    -- Offset area center for the hint so exact location is not revealed
    local offsetX = math.random(-50, 50)
    local offsetY = math.random(-50, 50)
    local areaCenter = vector3(
        location.coords.x + offsetX,
        location.coords.y + offsetY,
        location.coords.z
    )

    local clientData = {
        hint = location.areaHint,
        area = areaCenter,
        coords = location.coords,
        radius = location.radius,
        expiresAt = shipment.expiresAt,
        searchesDone = 0,
        searchesRequired = shipment.searchesRequired,
    }

    TriggerClientEvent('w2f-weed:client:setShipment', src, clientData)

    W2F.ShipmentLog('CREATED', citizenid, {
        shipmentId = shipmentId,
        location = location.id,
        tier = tier,
        risk = location.risk,
        duration = duration
    })

    return true, nil
end

--- Complete a player's active shipment
---@param src number
---@param citizenid string
---@return boolean success
---@return string|nil reason
function W2F.CompleteShipment(src, citizenid)
    if not W2F.ValidateShipmentActive(citizenid) then
        return false, 'no_active'
    end

    local shipment = W2F.ActiveShipments[citizenid]

    local areaRadius = shipment.radius or Config.Shipments.AreaRadius
    local maxDist = areaRadius + (Config.Shipments.SearchRadiusBuffer or 12.0)

    if not W2F.ValidateDistance(src, shipment.coords, maxDist) then
        W2F.SecurityLog('Shipment completion distance check failed', {
            source = src,
            citizenid = citizenid,
            shipmentId = shipment.shipmentId
        })
        return false, 'distance'
    end

    shipment.searchesDone = (shipment.searchesDone or 0) + 1
    local required = math.max(1, shipment.searchesRequired or 1)

    if shipment.searchesDone < required then
        lib.notify(src, {
            title = 'Shipment',
            description = Locale('shipment_search_progress', shipment.searchesDone, required),
            type = 'inform'
        })
        return true, 'progress'
    end

    -- Final successful completion
    shipment.status = W2F.ShipmentStatus.Completed
    W2F.UpdateShipmentStatus(shipment.shipmentId, W2F.ShipmentStatus.Completed)

    local rewardSuccess = W2F.GrantSeedReward(src, citizenid, shipment.tier)

    W2F.AddLoyalty(citizenid, Config.Loyalty.Gain.SuccessfulShipment)
    W2F.IncrementSuccessfulRuns(citizenid)
    W2F.Cooldowns[citizenid] = W2F.GetTimestamp()

    W2F.ActiveShipments[citizenid] = nil

    TriggerClientEvent('w2f-weed:client:shipmentCompleted', src)

    W2F.ShipmentLog('COMPLETED', citizenid, {
        shipmentId = shipment.shipmentId,
        tier = shipment.tier,
        rewarded = rewardSuccess
    })

    return true, nil
end

--- Expire a player's active shipment
---@param citizenid string
function W2F.ExpireShipment(citizenid)
    local shipment = W2F.ActiveShipments[citizenid]
    if not shipment then return end

    shipment.status = W2F.ShipmentStatus.Expired
    W2F.UpdateShipmentStatus(shipment.shipmentId, W2F.ShipmentStatus.Expired)
    W2F.IncrementFailedRuns(citizenid)

    W2F.ActiveShipments[citizenid] = nil

    local src = W2F.GetSourceByCitizenId(citizenid)
    if src then
        TriggerClientEvent('w2f-weed:client:clearShipment', src)
    end

    W2F.ShipmentLog('EXPIRED', citizenid, { shipmentId = shipment.shipmentId })
end

--- Cancel a player's active shipment
---@param src number
---@param citizenid string
---@return boolean
function W2F.CancelShipment(src, citizenid)
    local shipment = W2F.ActiveShipments[citizenid]
    if not shipment then return false end

    shipment.status = W2F.ShipmentStatus.Cancelled
    W2F.UpdateShipmentStatus(shipment.shipmentId, W2F.ShipmentStatus.Cancelled)

    W2F.ActiveShipments[citizenid] = nil

    TriggerClientEvent('w2f-weed:client:clearShipment', src)

    W2F.ShipmentLog('CANCELLED', citizenid, { shipmentId = shipment.shipmentId })

    return true
end

--- Get client-safe data for an active shipment
---@param citizenid string
---@return table|nil
function W2F.GetActiveShipmentData(citizenid)
    local shipment = W2F.ActiveShipments[citizenid]
    if not shipment then return nil end
    if shipment.status ~= W2F.ShipmentStatus.Active then return nil end
    if W2F.HasExpired(shipment.expiresAt) then return nil end

    local location = W2F.GetLocationById(shipment.locationId)
    local offsetX = math.random(-50, 50)
    local offsetY = math.random(-50, 50)

    return {
        hint = shipment.hint,
        area = vector3(shipment.coords.x + offsetX, shipment.coords.y + offsetY, shipment.coords.z),
        coords = shipment.coords,
        radius = location and location.radius or Config.Shipments.AreaRadius,
        expiresAt = shipment.expiresAt,
        searchesDone = shipment.searchesDone or 0,
        searchesRequired = shipment.searchesRequired or 1,
    }
end

--- Find a player's source by citizenid (online players only)
---@param citizenid string
---@return number|nil
function W2F.GetSourceByCitizenId(citizenid)
    local players = exports.qbx_core:GetQBPlayers()
    for src, player in pairs(players) do
        if player and player.PlayerData and player.PlayerData.citizenid == citizenid then
            return src
        end
    end
    return nil
end
