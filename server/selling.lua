-- ─────────────────────────────────────────────
-- w2f-weed | Server | Street selling
-- ─────────────────────────────────────────────

local activeOffers = {}
local CurrentCops = 0

RegisterNetEvent('police:SetCopCount', function(amount)
    CurrentCops = tonumber(amount) or 0
end)

local function isSellingEnabled()
    return Config.Foundation
        and Config.Foundation.EnableSelling == true
        and Config.Selling
        and Config.Selling.Enabled == true
end

local function getSellableItems(src)
    local list = {}
    local prices = Config.Selling and Config.Selling.Items or {}

    for itemName, priceCfg in pairs(prices) do
        local count = exports.ox_inventory:GetItemCount(src, itemName) or 0
        if count > 0 then
            local itemData = exports.ox_inventory:Items()[itemName]
            list[#list + 1] = {
                item = itemName,
                count = count,
                label = (itemData and itemData.label) or itemName,
                min = priceCfg.min or 5,
                max = priceCfg.max or 15,
            }
        end
    end

    return list
end

local function hasSellableDrugs(src)
    return #getSellableItems(src) > 0
end

local function enoughPolice()
    local need = (Config.Selling and Config.Selling.MinimumPolice) or 0
    if need <= 0 then return true end
    return CurrentCops >= need
end

lib.callback.register('w2f-weed:server:canStartStreetSelling', function(source)
    if not isSellingEnabled() then return false, 'disabled' end
    if not enoughPolice() then return false, 'police' end
    if not hasSellableDrugs(source) then return false, 'no_drugs' end
    return true
end)

lib.callback.register('w2f-weed:server:hasSellableDrugs', function(source)
    return hasSellableDrugs(source)
end)

lib.callback.register('w2f-weed:server:createStreetOffer', function(source, pedNetId)
    if not isSellingEnabled() then return nil end
    if not enoughPolice() then return nil end

    local available = getSellableItems(source)
    if #available == 0 then return nil end

    local declineChance = (Config.Selling and Config.Selling.DeclineChance) or 35
    if math.random(1, 100) <= declineChance then
        return nil
    end

    local chosen = available[math.random(1, #available)]
    local amount = math.random(1, math.min(chosen.count, 5))
    local unitPrice = math.random(chosen.min, chosen.max)
    local total = unitPrice * amount
    local token = ('sell_%s_%s'):format(source, math.random(100000, 999999))

    activeOffers[token] = {
        src = source,
        item = chosen.item,
        amount = amount,
        total = total,
        pedNetId = pedNetId,
        expiresAt = W2F.GetTimestamp() + 45,
    }

    return {
        token = token,
        item = chosen.item,
        label = chosen.label,
        amount = amount,
        total = total,
    }
end)

RegisterNetEvent('w2f-weed:server:completeStreetSale', function(token)
    local src = source
    if type(token) ~= 'string' then return end

    local offer = activeOffers[token]
    activeOffers[token] = nil

    if not offer or offer.src ~= src then return end
    if W2F.HasExpired(offer.expiresAt) then
        TriggerClientEvent('w2f-weed:client:streetSaleResult', src, false, 'expired')
        return
    end

    if not W2F.ValidateItemCount(src, offer.item, offer.amount) then
        TriggerClientEvent('w2f-weed:client:streetSaleResult', src, false, 'no_items')
        return
    end

    if exports.ox_inventory:RemoveItem(src, offer.item, offer.amount) ~= true then
        TriggerClientEvent('w2f-weed:client:streetSaleResult', src, false, 'no_items')
        return
    end

    local player = W2F.GetPlayer(src)
    if not player then return end

    local account = (Config.Selling and Config.Selling.PayoutAccount) or 'cash'
    W2F.AddMoney(src, account, offer.total, 'w2f-weed-street-sale')

    TriggerClientEvent('w2f-weed:client:streetSaleResult', src, true)

    local alertChance = (Config.Selling and Config.Selling.PoliceAlertChance) or 0
    if alertChance > 0 and math.random(1, 100) <= alertChance then
        W2F.TriggerPoliceAlert(src, Locale('selling_police_alert'))
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    for token, offer in pairs(activeOffers) do
        if offer.src == src then
            activeOffers[token] = nil
        end
    end
end)
