--- Random map offset for the area blip (keeps the true coords inside the circle).
---@param radius number|nil
---@return integer, integer
local function randomAreaOffset(radius)
    local r = radius or Config.Shipments.AreaRadius or 14.0
    local maxOff = math.max(2, math.floor(r * 0.30))
    return math.random(-maxOff, maxOff), math.random(-maxOff, maxOff)
end

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
    local offsetX, offsetY = randomAreaOffset(location.radius)
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
        lastSearchSpot = nil,
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

    local minSep = tonumber(Config.Shipments.MinSearchSpotSeparation) or 0.0
    if minSep > 0 and shipment.lastSearchSpot then
        local ped = GetPlayerPed(src)
        if ped and ped ~= 0 then
            local pcoords = GetEntityCoords(ped)
            if W2F.FlatDistance(pcoords, shipment.lastSearchSpot) < minSep then
                return false, 'same_spot'
            end
        end
    end

    shipment.searchesDone = (shipment.searchesDone or 0) + 1
    local required = math.max(1, shipment.searchesRequired or 1)

    if shipment.searchesDone < required then
        local ped = GetPlayerPed(src)
        if ped and ped ~= 0 then
            local pcoords = GetEntityCoords(ped)
            shipment.lastSearchSpot = vector3(pcoords.x, pcoords.y, pcoords.z)
        end
        lib.notify(src, {
            title = 'Shipment',
            description = Locale('shipment_search_progress', shipment.searchesDone, required),
            type = 'inform'
        })
        TriggerClientEvent('w2f-weed:client:shipmentSearchProgress', src, {
            lastSearchSpot = shipment.lastSearchSpot,
            searchesDone = shipment.searchesDone,
            searchesRequired = required,
        })
        return true, 'progress'
    end

    -- Final successful completion
    shipment.status = W2F.ShipmentStatus.Completed
    W2F.UpdateShipmentStatus(shipment.shipmentId, W2F.ShipmentStatus.Completed)

    local rewardSuccess, grantedItems = W2F.GrantSeedReward(src, citizenid, shipment.tier)

    W2F.AddLoyalty(citizenid, Config.Loyalty.Gain.SuccessfulShipment)
    W2F.IncrementSuccessfulRuns(citizenid)
    W2F.Cooldowns[citizenid] = W2F.GetTimestamp()

    W2F.ActiveShipments[citizenid] = nil

    TriggerClientEvent('w2f-weed:client:shipmentCompleted', src, W2F.FormatGrantedItems(grantedItems))

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

--- Rebuild in-memory active shipments from the database after a restart.
--- Location-derived fields (coords/hint/radius/risk) come from config; the
--- search counters are not persisted, so a fresh required-count is rolled and
--- progress resets (the lead itself, blip and expiry are preserved). Stale rows
--- past expiry, or rows whose location no longer exists, are marked expired.
function W2F.RehydrateActiveShipments()
    if not W2F.Foundation('EnableShipments') then return end

    local rows = W2F.LoadActiveShipments()
    local now = W2F.GetTimestamp()
    local restored, expired = 0, 0

    for _, row in ipairs(rows) do
        local cid = row.citizenid
        if cid and not W2F.ActiveShipments[cid] then
            local location = W2F.GetLocationById(row.location_id)
            if not location or (row.expires_at and now >= row.expires_at) then
                W2F.UpdateShipmentStatus(row.shipment_id, W2F.ShipmentStatus.Expired)
                expired = expired + 1
            else
                local smin = math.max(1, Config.Shipments.MinSearchAttempts or 1)
                local smax = math.max(smin, Config.Shipments.MaxSearchAttempts or 12)
                W2F.ActiveShipments[cid] = {
                    shipmentId       = row.shipment_id,
                    citizenid        = cid,
                    locationId       = row.location_id,
                    coords           = location.coords,
                    hint             = location.areaHint,
                    radius           = location.radius,
                    tier             = row.tier,
                    risk             = location.risk,
                    status           = W2F.ShipmentStatus.Active,
                    createdAt        = row.created_at,
                    expiresAt        = row.expires_at,
                    searchesDone     = 0,
                    searchesRequired = math.random(smin, smax),
                    lastSearchSpot   = nil,
                }
                restored = restored + 1
            end
        end
    end

    W2F.Debug(('Rehydrated %d active shipment(s); expired %d stale.'):format(restored, expired))
end

--- Re-push an active shipment's visuals to its owner if they are online (used
--- after a live resource restart where the player never disconnected).
---@param citizenid string
function W2F.ResyncShipmentForCitizen(citizenid)
    local data = W2F.GetActiveShipmentData(citizenid)
    if not data then return end
    local src = W2F.GetSourceByCitizenId(citizenid)
    if not src then return end
    TriggerClientEvent('w2f-weed:client:setShipment', src, data)
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
    local r = location and location.radius or shipment.radius or Config.Shipments.AreaRadius
    local offsetX, offsetY = randomAreaOffset(r)

    return {
        hint = shipment.hint,
        area = vector3(shipment.coords.x + offsetX, shipment.coords.y + offsetY, shipment.coords.z),
        coords = shipment.coords,
        radius = r,
        expiresAt = shipment.expiresAt,
        searchesDone = shipment.searchesDone or 0,
        searchesRequired = shipment.searchesRequired or 1,
        lastSearchSpot = shipment.lastSearchSpot,
    }
end
