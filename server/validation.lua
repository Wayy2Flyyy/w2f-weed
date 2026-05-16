--- Get a Qbox player object safely
---@param src number
---@return table|nil
function W2F.GetPlayer(src)
    if not src or src <= 0 then return nil end
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return nil end
    return player
end

--- Get citizenid from a source safely
---@param src number
---@return string|nil
function W2F.GetCitizenId(src)
    local player = W2F.GetPlayer(src)
    if not player or not player.PlayerData then return nil end
    return player.PlayerData.citizenid
end

--- Validate that a player is within a certain distance of coordinates
---@param src number
---@param target vector3|vector4
---@param maxDist number
---@return boolean
function W2F.ValidateDistance(src, target, maxDist)
    if not Config.Security.ValidateDistance then return true end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end

    local coords = GetEntityCoords(ped)
    local targetVec = vector3(target.x, target.y, target.z)
    local dist = #(coords - targetVec)

    return dist <= maxDist
end

--- Validate that a player has enough of a specific item
---@param src number
---@param itemName string
---@param amount number
---@return boolean
function W2F.ValidateItemCount(src, itemName, amount)
    if not Config.Security.ValidateItems then return true end
    if not itemName or amount <= 0 then return false end

    local count = exports.ox_inventory:GetItemCount(src, itemName)
    return count and count >= amount
end

--- Validate that a player can pay with the configured account
---@param src number
---@param amount number
---@return boolean
function W2F.ValidatePayment(src, amount)
    if not Config.Security.ValidateMoney then return true end
    if amount <= 0 then return false end

    local player = W2F.GetPlayer(src)
    if not player then return false end

    if Config.BlackMoneyMode == 'item' then
        return W2F.ValidateItemCount(src, Config.Accounts.BlackMoney, amount)
    end

    local account = Config.Payment.Account
    local balance = player.Functions.GetMoney(account)
    return balance and balance >= amount
end

--- Validate that a cooldown has passed for a given key
---@param cooldownTable table
---@param key string
---@param cooldownSeconds number
---@return boolean isReady
---@return number remainingSeconds
function W2F.ValidateCooldown(cooldownTable, key, cooldownSeconds)
    if not Config.Security.ValidateCooldowns then return true, 0 end

    local lastUsed = cooldownTable[key]
    if not lastUsed then return true, 0 end

    local elapsed = W2F.GetTimestamp() - lastUsed
    local remaining = cooldownSeconds - elapsed

    if remaining > 0 then
        return false, remaining
    end

    return true, 0
end

--- Validate that a shipment has not already been completed
---@param citizenid string
---@return boolean
function W2F.ValidateShipmentActive(citizenid)
    local shipment = W2F.ActiveShipments[citizenid]
    if not shipment then return false end
    if shipment.status ~= W2F.ShipmentStatus.Active then return false end
    if W2F.HasExpired(shipment.expiresAt) then return false end
    return true
end

--- Validate that there is no duplicate active shipment
---@param citizenid string
---@return boolean hasDuplicate
function W2F.ValidateNoDuplicateShipment(citizenid)
    if not Config.Shipments.OneActiveShipmentPerPlayer then return false end
    return W2F.ActiveShipments[citizenid] ~= nil
end

--- Validate that a reward item is in the configured seed items whitelist
---@param itemName string
---@return boolean
function W2F.ValidateRewardItem(itemName)
    return W2F.IsValidSeedItem(itemName)
end

--- Full validation for source: player exists, citizenid exists
---@param src number
---@return string|nil citizenid
function W2F.ValidateSource(src)
    if not src or src <= 0 then
        W2F.SecurityLog('Invalid source', { source = src })
        return nil
    end

    local citizenid = W2F.GetCitizenId(src)
    if not citizenid then
        W2F.SecurityLog('No citizenid for source', { source = src })
        return nil
    end

    return citizenid
end
