RegisterNetEvent('w2f-weed:server:requestShipmentTip', function()
    local src = source
    local citizenid = W2F.ValidateSource(src)
    if not citizenid then return end

    if not Config.Foundation.EnableShipments then
        lib.notify(src, { title = 'Contact', description = Locale('feature_disabled'), type = 'error' })
        return
    end

    if not W2F.ValidateDistance(src, Config.Contact.Coords, Config.Contact.InteractionDistance + 2.0) then
        W2F.SecurityLog('Shipment request distance check failed', { source = src, citizenid = citizenid })
        return
    end

    if W2F.ValidateNoDuplicateShipment(citizenid) then
        lib.notify(src, { title = 'Contact', description = Locale('already_has_shipment'), type = 'error' })
        return
    end

    local contactCooldown = W2F.GetEffectiveCooldown(Config.Shipments.ContactCooldown, W2F.GetLoyalty(citizenid))
    local ready, remaining = W2F.ValidateCooldown(W2F.Cooldowns, citizenid, contactCooldown)
    if not ready then
        lib.notify(src, { title = 'Contact', description = Locale('contact_cooldown', W2F.FormatTime(remaining)), type = 'error' })
        return
    end

    if Config.Shipments.RequirePaymentForTip then
        local paid = W2F.ProcessTipPayment(src, citizenid)
        if not paid then
            lib.notify(src, { title = 'Contact', description = Locale('payment_failed'), type = 'error' })
            return
        end
    end

    local success, reason = W2F.CreateShipment(src, citizenid)
    if not success then
        lib.notify(src, { title = 'Contact', description = Locale('shipment_create_failed'), type = 'error' })
        W2F.Debug('Shipment creation failed:', reason)
    end
end)

RegisterNetEvent('w2f-weed:server:completeShipment', function()
    local src = source
    local citizenid = W2F.ValidateSource(src)
    if not citizenid then return end

    local success, reason = W2F.CompleteShipment(src, citizenid)
    if not success then
        if reason == 'distance' then
            W2F.SecurityLog('Completion exploit attempt', { source = src, citizenid = citizenid })
        end
        lib.notify(src, { title = 'Shipment', description = Locale('shipment_complete_failed'), type = 'error' })
    elseif reason == 'progress' then
        -- Progress notify is sent from CompleteShipment; nothing else to do
    end
end)

RegisterNetEvent('w2f-weed:server:bribeContact', function(option)
    local src = source
    local citizenid = W2F.ValidateSource(src)
    if not citizenid then return end

    if not Config.Foundation.EnableBribes then
        lib.notify(src, { title = 'Contact', description = Locale('feature_disabled'), type = 'error' })
        return
    end

    if type(option) ~= 'string' then
        W2F.SecurityLog('Invalid bribe option type', { source = src, citizenid = citizenid })
        return
    end

    local success, reason = W2F.ProcessBribe(src, citizenid, option)

    if success then
        lib.notify(src, { title = 'Contact', description = Locale('bribe_success'), type = 'success' })
    else
        local msg = Locale('bribe_failed')
        if reason == 'cooldown' then msg = Locale('bribe_cooldown') end
        if reason == 'no_items' then msg = Locale('bribe_no_items') end
        if reason == 'distance' then msg = Locale('bribe_distance') end
        lib.notify(src, { title = 'Contact', description = msg, type = 'error' })
    end
end)

RegisterNetEvent('w2f-weed:server:cancelShipment', function()
    local src = source
    local citizenid = W2F.ValidateSource(src)
    if not citizenid then return end

    local cancelled = W2F.CancelShipment(src, citizenid)
    if cancelled then
        lib.notify(src, { title = 'Contact', description = Locale('shipment_cancelled'), type = 'info' })
    else
        lib.notify(src, { title = 'Contact', description = Locale('no_active_shipment'), type = 'error' })
    end
end)
