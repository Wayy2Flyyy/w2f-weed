lib.callback.register('w2f-weed:server:getContactStatus', function(source)
    local src = source
    local citizenid = W2F.ValidateSource(src)
    if not citizenid then return nil end

    local hasActive = W2F.ActiveShipments[citizenid] ~= nil

    local contactCooldown = W2F.GetEffectiveCooldown(Config.Shipments.ContactCooldown, W2F.GetLoyalty(citizenid))
    local ready, remaining = W2F.ValidateCooldown(W2F.Cooldowns, citizenid, contactCooldown)

    return {
        hasActiveShipment = hasActive,
        onCooldown = not ready,
        cooldownRemaining = remaining,
        loyalty = W2F.GetLoyalty(citizenid)
    }
end)

lib.callback.register('w2f-weed:server:getActiveShipment', function(source)
    local src = source
    local citizenid = W2F.ValidateSource(src)
    if not citizenid then return nil end

    return W2F.GetActiveShipmentData(citizenid)
end)

lib.callback.register('w2f-weed:server:getLoyalty', function(source)
    local src = source
    local citizenid = W2F.ValidateSource(src)
    if not citizenid then return nil end

    return W2F.GetLoyaltyData(citizenid)
end)

lib.callback.register('w2f-weed:server:getTipPrice', function(source)
    local src = source
    local citizenid = W2F.ValidateSource(src)
    if not citizenid then return nil end

    local price, account = W2F.GetTipPrice(citizenid)
    return { price = price, account = account }
end)
