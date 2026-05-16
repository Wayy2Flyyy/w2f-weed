local function OpenContactMenu()
    local status = lib.callback.await('w2f-weed:server:getContactStatus', false)

    if not status then
        lib.notify({ title = 'Contact', description = Locale('contact_unavailable'), type = 'error' })
        return
    end

    local options = {}

    options[#options + 1] = {
        title = Locale('menu_ask_shipment'),
        description = Locale('menu_ask_shipment_desc', W2F.FormatTime(status.cooldownRemaining or 0)),
        icon = 'fa-solid fa-truck',
        disabled = status.hasActiveShipment or status.onCooldown,
        onSelect = function()
            W2F.RequestShipmentTip()
        end
    }

    options[#options + 1] = {
        title = Locale('menu_check_loyalty'),
        description = Locale('menu_check_loyalty_desc'),
        icon = 'fa-solid fa-handshake',
        onSelect = function()
            W2F.CheckLoyalty()
        end
    }

    if Config.Bribes.Enabled then
        options[#options + 1] = {
            title = Locale('menu_bribe_contact'),
            description = Locale('menu_bribe_contact_desc'),
            icon = 'fa-solid fa-gift',
            onSelect = function()
                W2F.OpenBribeMenu()
            end
        }
    end

    if status.hasActiveShipment then
        options[#options + 1] = {
            title = Locale('menu_cancel_shipment'),
            description = Locale('menu_cancel_shipment_desc'),
            icon = 'fa-solid fa-ban',
            onSelect = function()
                W2F.CancelShipment()
            end
        }
    end

    lib.registerContext({
        id = 'w2f_weed_contact',
        title = Config.Contact.Name,
        options = options
    })

    lib.showContext('w2f_weed_contact')
end

function W2F.RequestShipmentTip()
    local priceData = lib.callback.await('w2f-weed:server:getTipPrice', false)

    if not priceData then
        lib.notify({ title = 'Contact', description = Locale('tip_unavailable'), type = 'error' })
        return
    end

    local confirmed = lib.alertDialog({
        header = Locale('confirm_tip_header'),
        content = Locale('confirm_tip_content', priceData.price, priceData.account),
        centered = true,
        cancel = true
    })

    if confirmed ~= 'confirm' then return end

    TriggerServerEvent('w2f-weed:server:requestShipmentTip')
end

function W2F.CheckLoyalty()
    local data = lib.callback.await('w2f-weed:server:getLoyalty', false)

    if not data then
        lib.notify({ title = 'Contact', description = Locale('loyalty_unavailable'), type = 'error' })
        return
    end

    local content = Locale('loyalty_content', data.level, data.label, data.successful, data.failed)
    local need = (Config.Loyalty and Config.Loyalty.ContractorSuppliesMinLoyalty) or 3
    if type(data.level) == 'number' and data.level >= need then
        content = content .. '\n\n' .. Locale('loyalty_runner_smoke_tip')
    end

    lib.alertDialog({
        header = Locale('loyalty_header'),
        content = content,
        centered = true
    })
end

function W2F.OpenBribeMenu()
    local options = {}

    for key, bribe in pairs(Config.Bribes.Options) do
        options[#options + 1] = {
            title = bribe.label,
            description = Locale('bribe_option_desc', bribe.amount, Config.Bribes.Item),
            icon = 'fa-solid fa-cannabis',
            onSelect = function()
                TriggerServerEvent('w2f-weed:server:bribeContact', key)
            end
        }
    end

    lib.registerContext({
        id = 'w2f_weed_bribe',
        title = Locale('bribe_menu_title'),
        menu = 'w2f_weed_contact',
        options = options
    })

    lib.showContext('w2f_weed_bribe')
end

function W2F.CancelShipment()
    local confirmed = lib.alertDialog({
        header = Locale('cancel_shipment_header'),
        content = Locale('cancel_shipment_content'),
        centered = true,
        cancel = true
    })

    if confirmed ~= 'confirm' then return end

    TriggerServerEvent('w2f-weed:server:cancelShipment')
end

CreateThread(function()
    while not W2F.IsClientReady() do
        Wait(200)
    end

    if not Config.Contact.Enabled or not Config.Contact.UseTarget then return end

    while not W2F.GetContactPed() do
        Wait(500)
    end

    local ped = W2F.GetContactPed()
    if not ped then return end

    exports.ox_target:addLocalEntity(ped, {
        {
            name = 'w2f_weed_contact',
            icon = Config.Contact.Target.Icon,
            label = Config.Contact.Target.Label,
            distance = Config.Contact.Target.Distance,
            onSelect = function()
                OpenContactMenu()
            end
        }
    })

    W2F.Debug('ox_target added to contact ped.')
end)
