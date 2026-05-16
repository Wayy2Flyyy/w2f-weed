--- ox_inventory: gate `SmokeOnTheWaterContractor` on street-contact loyalty (w2f-weed DB).

local function contractorSuppliesMin()
    return (Config.Loyalty and Config.Loyalty.ContractorSuppliesMinLoyalty) or 3
end

local function contractorShopAllowed(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player or not player.PlayerData or not player.PlayerData.citizenid then return false end
    return W2F.GetLoyalty(player.PlayerData.citizenid) >= contractorSuppliesMin()
end

local function notifyContractorLocked(src)
    local need = contractorSuppliesMin()
    local tier = Config.Loyalty and Config.Loyalty.Levels and Config.Loyalty.Levels[need]
    local label = tier and tier.label or ('Level %d'):format(need)
    lib.notify(src, {
        title = 'Contractor supplies',
        description = ('Requires contact loyalty %d+ (%s with the contractor).'):format(need, label),
        type = 'error',
        position = 'top',
    })
end

CreateThread(function()
    local deadlineGet = GetGameTimer() + 30000
    while GetResourceState('ox_inventory') ~= 'started' and GetGameTimer() < deadlineGet do
        Wait(200)
    end
    if GetResourceState('ox_inventory') ~= 'started' then return end

    exports.ox_inventory:registerHook('openShop', function(payload)
        if payload.shopType ~= 'SmokeOnTheWaterContractor' then return end
        if contractorShopAllowed(payload.source) then return end
        notifyContractorLocked(payload.source)
        return false
    end)

    exports.ox_inventory:registerHook('buyItem', function(payload)
        if payload.shopType ~= 'SmokeOnTheWaterContractor' then return end
        if contractorShopAllowed(payload.source) then return end
        return false
    end)
end)
