--- Calculate the tip price for a player based on their loyalty
---@param citizenid string
---@return number price
---@return string account
function W2F.GetTipPrice(citizenid)
    local loyalty = W2F.GetLoyalty(citizenid)
    local price = W2F.CalculateTipPrice(loyalty)
    return price, Config.Payment.Account
end

--- Process payment for a shipment tip
---@param src number
---@param citizenid string
---@return boolean success
function W2F.ProcessTipPayment(src, citizenid)
    local price = W2F.GetTipPrice(citizenid)

    if not W2F.ValidatePayment(src, price) then
        W2F.SecurityLog('Payment validation failed', { source = src, citizenid = citizenid, price = price })
        return false
    end

    local player = W2F.GetPlayer(src)
    if not player then return false end

    if Config.BlackMoneyMode == 'item' then
        local removed = exports.ox_inventory:RemoveItem(src, Config.Accounts.BlackMoney, price)
        return removed ~= nil
    end

    return player.Functions.RemoveMoney(Config.Payment.Account, price, 'w2f-weed shipment tip')
end

--- Process a bribe from a player
---@param src number
---@param citizenid string
---@param option string
---@return boolean success
---@return string|nil reason
function W2F.ProcessBribe(src, citizenid, option)
    if not Config.Bribes.Enabled then
        return false, 'disabled'
    end

    if not W2F.IsValidBribeOption(option) then
        W2F.SecurityLog('Invalid bribe option', { source = src, citizenid = citizenid, option = option })
        return false, 'invalid_option'
    end

    local bribeData = Config.Bribes.Options[option]
    local cooldownKey = citizenid .. ':bribe'

    local ready, remaining = W2F.ValidateCooldown(W2F.BribeCooldowns, cooldownKey, bribeData.cooldown)
    if not ready then
        return false, 'cooldown'
    end

    if not W2F.ValidateDistance(src, Config.Contact.Coords, Config.Contact.InteractionDistance + 2.0) then
        W2F.SecurityLog('Bribe distance check failed', { source = src, citizenid = citizenid })
        return false, 'distance'
    end

    if not W2F.ValidateItemCount(src, Config.Bribes.Item, bribeData.amount) then
        return false, 'no_items'
    end

    local removed = exports.ox_inventory:RemoveItem(src, Config.Bribes.Item, bribeData.amount)
    if not removed then
        return false, 'remove_failed'
    end

    local newLevel = W2F.AddLoyalty(citizenid, bribeData.loyaltyGain)
    W2F.IncrementBribesGiven(citizenid)
    W2F.BribeCooldowns[cooldownKey] = W2F.GetTimestamp()

    W2F.BribeLog(citizenid, option, bribeData.loyaltyGain)

    return true, nil
end
