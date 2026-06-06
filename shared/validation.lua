--- Validate that a bribe option key is valid
---@param option string
---@return boolean
function W2F.IsValidBribeOption(option)
    return Config.Bribes.Options[option] ~= nil
end

--- Validate that a seed tier key exists in config
---@param tier string
---@return boolean
function W2F.IsValidSeedTier(tier)
    return Config.SeedRewards[tier] ~= nil
end

--- Validate that an item name is in the known seed items list
---@param itemName string
---@return boolean
function W2F.IsValidSeedItem(itemName)
    return W2F.TableContains(W2F.SeedItems, itemName)
end

--- Validate that a loyalty level is within bounds
---@param level number
---@return boolean
function W2F.IsValidLoyaltyLevel(level)
    if type(level) ~= 'number' then return false end
    return level >= Config.Loyalty.StartingLevel and level <= Config.Loyalty.MaxLevel
end

--- Validate a shipment status string
---@param status string
---@return boolean
function W2F.IsValidShipmentStatus(status)
    for _, v in pairs(W2F.ShipmentStatus) do
        if v == status then return true end
    end
    return false
end

--- Validate a location ID exists in the configured shipment locations
---@param locationId string
---@return boolean
function W2F.IsValidLocationId(locationId)
    for _, loc in ipairs(Config.ShipmentLocations) do
        if loc.id == locationId then return true end
    end
    return false
end

--- Get a shipment location config by ID
---@param locationId string
---@return table|nil
function W2F.GetLocationById(locationId)
    for _, loc in ipairs(Config.ShipmentLocations) do
        if loc.id == locationId then return loc end
    end
    return nil
end

--- Get only enabled shipment locations
---@return table
function W2F.GetEnabledLocations()
    local enabled = {}
    for _, loc in ipairs(Config.ShipmentLocations) do
        if loc.enabled then
            enabled[#enabled + 1] = loc
        end
    end
    return enabled
end

--- Filter enabled locations by tier availability
---@param tier string
---@return table
function W2F.GetLocationsForTier(tier)
    local locations = {}
    for _, loc in ipairs(Config.ShipmentLocations) do
        if loc.enabled and W2F.TableContains(loc.tiers, tier) then
            locations[#locations + 1] = loc
        end
    end
    return locations
end
