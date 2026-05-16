--- Roll a reward item from the configured reward pool for a tier
---@param tier string
---@param loyaltyLevel number
---@return string|nil itemName
function W2F.RollRewardItem(tier, loyaltyLevel)
    local rewardData = Config.SeedRewards[tier]
    if not rewardData then return nil end

    local pool = rewardData.pool
    if not pool or #pool == 0 then return nil end

    local level = Config.Loyalty.Levels[loyaltyLevel]
    local rareBonus = level and level.rareChanceBonus or 0

    local totalChance = 0
    local adjustedPool = {}

    for i, entry in ipairs(pool) do
        local chance = entry.chance
        if i == #pool and rareBonus > 0 then
            chance = chance + rareBonus
        end
        totalChance = totalChance + chance
        adjustedPool[#adjustedPool + 1] = { item = entry.item, chance = chance, cumulative = totalChance }
    end

    local roll = math.random(1, math.floor(totalChance))

    for _, entry in ipairs(adjustedPool) do
        if roll <= entry.cumulative then
            return entry.item
        end
    end

    return pool[1].item
end

--- Calculate the number of seeds to reward
---@param tier string
---@return number
function W2F.RollSeedAmount(tier)
    local rewardData = Config.SeedRewards[tier]
    if not rewardData then return 0 end
    return math.random(rewardData.minSeeds, rewardData.maxSeeds)
end

--- Grant seed rewards to a player after shipment completion
---@param src number
---@param citizenid string
---@param tier string
---@return boolean success
function W2F.GrantSeedReward(src, citizenid, tier)
    if not W2F.IsValidSeedTier(tier) then
        W2F.SecurityLog('Invalid reward tier', { citizenid = citizenid, tier = tier })
        return false
    end

    local loyalty = W2F.GetLoyalty(citizenid)
    local totalSeeds = W2F.RollSeedAmount(tier)
    if totalSeeds <= 0 then return false end

    local grantedItems = {}

    for _ = 1, totalSeeds do
        local itemName = W2F.RollRewardItem(tier, loyalty)

        if not itemName or not W2F.ValidateRewardItem(itemName) then
            W2F.SecurityLog('Invalid reward item rolled', { citizenid = citizenid, item = itemName })
            goto continue
        end

        if not exports.ox_inventory:CanCarryItem(src, itemName, 1) then
            W2F.Debug('Player cannot carry more items, stopping reward grant.')
            break
        end

        local success = exports.ox_inventory:AddItem(src, itemName, 1)
        if success then
            local found = false
            for _, entry in ipairs(grantedItems) do
                if entry.name == itemName then
                    entry.amount = entry.amount + 1
                    found = true
                    break
                end
            end
            if not found then
                grantedItems[#grantedItems + 1] = { name = itemName, amount = 1 }
            end
        end

        ::continue::
    end

    if #grantedItems > 0 then
        W2F.RewardLog(citizenid, tier, grantedItems)
    end

    return #grantedItems > 0
end
