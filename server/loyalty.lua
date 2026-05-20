--- Get the current loyalty level for a citizenid (from DB, cached for session)
---@param citizenid string
---@return number
function W2F.GetLoyalty(citizenid)
    local data = W2F.LoadLoyalty(citizenid)
    if not data then return Config.Loyalty.StartingLevel end
    return W2F.Clamp(data.loyalty, Config.Loyalty.StartingLevel, Config.Loyalty.MaxLevel)
end

--- Get full loyalty data including stats
---@param citizenid string
---@return table
function W2F.GetLoyaltyData(citizenid)
    local data = W2F.LoadLoyalty(citizenid)
    if not data then
        return {
            level = Config.Loyalty.StartingLevel,
            label = Config.Loyalty.Levels[Config.Loyalty.StartingLevel].label,
            successful = 0,
            failed = 0,
            bribes = 0
        }
    end

    local level = W2F.Clamp(data.loyalty, Config.Loyalty.StartingLevel, Config.Loyalty.MaxLevel)
    local levelData = Config.Loyalty.Levels[level]

    return {
        level = level,
        label = levelData and levelData.label or 'Unknown',
        successful = data.successful_runs or 0,
        failed = data.failed_runs or 0,
        bribes = data.bribes_given or 0
    }
end

--- Add loyalty points and save, clamped to max
---@param citizenid string
---@param amount number
---@return number newLevel
function W2F.AddLoyalty(citizenid, amount)
    if amount <= 0 then return W2F.GetLoyalty(citizenid) end

    local current = W2F.GetLoyalty(citizenid)
    local newLevel = W2F.Clamp(current + amount, Config.Loyalty.StartingLevel, Config.Loyalty.MaxLevel)

    W2F.SaveLoyalty(citizenid, newLevel)
    W2F.Debug('Loyalty updated for', citizenid, ':', current, '->', newLevel)
    W2F.SyncContractorSuppliesBlip(citizenid)

    return newLevel
end

--- Create or remove the contractor-supplies map blip for an online player (loyalty gate).
---@param citizenid string
function W2F.SyncContractorSuppliesBlip(citizenid)
    if not Config.Loyalty.Enabled then return end
    if not citizenid or citizenid == '' then return end

    local minLevel = Config.Loyalty.ContractorSuppliesMinLoyalty or 3
    local lvl = W2F.GetLoyalty(citizenid)
    local show = lvl >= minLevel

    local src = W2F.GetSourceByCitizenId(citizenid)
    if not src then return end

    TriggerClientEvent('w2f-weed:client:setContractorSuppliesBlip', src, show)
end
