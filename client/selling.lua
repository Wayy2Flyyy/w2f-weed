-- ─────────────────────────────────────────────
-- w2f-weed | Client | Street selling
-- Toggle selling mode, approach nearby peds, ox_target sell/decline.
-- ─────────────────────────────────────────────

local sellingActive = false
local sellingOrigin = nil
local busyPed = nil
local currentOffer = nil
local approachedPeds = {}
local targetPedNetId = nil
local busyLocalPed = nil
-- Debounce so the "no drugs" message can never stack/spam when several peds are
-- scanned in quick succession.
local lastNoDrugsNotify = 0
local NO_DRUGS_NOTIFY_COOLDOWN = 5000

local function isSellingEnabled()
    return Config.Foundation
        and Config.Foundation.EnableSelling == true
        and Config.Selling
        and Config.Selling.Enabled == true
end

local function notify(key, nType)
    lib.notify({
        title = 'Street Selling',
        description = Locale(key),
        type = nType or 'info',
        position = 'top',
    })
end

--- Notify "you have no drugs" at most once per cooldown window (anti-spam).
local function notifyNoDrugs()
    local now = GetGameTimer()
    if (now - lastNoDrugsNotify) < NO_DRUGS_NOTIFY_COOLDOWN then return end
    lastNoDrugsNotify = now
    notify('selling_no_drugs', 'error')
end

local function clearPedTarget()
    if targetPedNetId then
        pcall(function()
            exports.ox_target:removeEntity(targetPedNetId, { 'w2f_weed_sell', 'w2f_weed_decline' })
        end)
        targetPedNetId = nil
    end
    if busyLocalPed and busyLocalPed ~= 0 then
        pcall(function()
            exports.ox_target:removeLocalEntity(busyLocalPed, { 'w2f_weed_sell', 'w2f_weed_decline' })
        end)
        busyLocalPed = nil
    end
    busyPed = nil
    currentOffer = nil
end

local function stopSelling(silent)
    sellingActive = false
    sellingOrigin = nil
    approachedPeds = {}
    clearPedTarget()
    if not silent then
        notify('selling_stopped', 'info')
    end
end

local function isValidBuyerPed(ped)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end
    if ped == cache.ped then return false end
    if IsPedAPlayer(ped) then return false end
    if IsPedDeadOrDying(ped, false) then return false end
    if IsPedInAnyVehicle(ped, false) then return false end
    if GetPedType(ped) == 28 then return false end -- animals
    if IsPedInAnyPoliceVehicle(ped) then return false end
    return true
end

local function markPedApproached(ped)
    approachedPeds[ped] = GetGameTimer()
end

local function canApproachPed(ped)
    local last = approachedPeds[ped]
    if not last then return true end
    local cooldown = (Config.Selling and Config.Selling.PedCooldownMs) or 45000
    return (GetGameTimer() - last) >= cooldown
end

local function attachOfferTarget(ped, offer)
    if not Config.Selling.UseTarget then return end

    -- Ambient peds are frequently NOT networked, which yields a netId of 0 and
    -- left the sell target unable to attach. Promote the ped to a networked
    -- entity (and take control) so ox_target:addEntity always has a valid id.
    if not NetworkGetEntityIsNetworked(ped) then
        NetworkRegisterEntityAsNetworked(ped)
    end
    local netId = NetworkGetNetworkIdFromEntity(ped)
    if not netId or netId == 0 then
        -- Fall back to a local entity target so the interaction still appears.
        targetPedNetId = nil
        exports.ox_target:addLocalEntity(ped, {
            {
                name = 'w2f_weed_sell',
                icon = Config.Selling.Target.SellIcon,
                label = Locale('selling_target_offer', offer.amount, offer.label, offer.total),
                distance = Config.Selling.Target.Distance,
                onSelect = function()
                    TriggerServerEvent('w2f-weed:server:completeStreetSale', offer.token)
                    markPedApproached(ped)
                    clearPedTarget()
                end,
            },
            {
                name = 'w2f_weed_decline',
                icon = Config.Selling.Target.DeclineIcon,
                label = Locale('selling_target_decline'),
                distance = Config.Selling.Target.Distance,
                onSelect = function()
                    notify('selling_offer_declined', 'error')
                    markPedApproached(ped)
                    clearPedTarget()
                end,
            },
        })
        busyLocalPed = ped
        return
    end

    targetPedNetId = netId
    local label = Locale('selling_target_offer', offer.amount, offer.label, offer.total)

    exports.ox_target:addEntity(netId, {
        {
            name = 'w2f_weed_sell',
            icon = Config.Selling.Target.SellIcon,
            label = label,
            distance = Config.Selling.Target.Distance,
            onSelect = function()
                TriggerServerEvent('w2f-weed:server:completeStreetSale', offer.token)
                markPedApproached(ped)
                clearPedTarget()
            end,
        },
        {
            name = 'w2f_weed_decline',
            icon = Config.Selling.Target.DeclineIcon,
            label = Locale('selling_target_decline'),
            distance = Config.Selling.Target.Distance,
            onSelect = function()
                notify('selling_offer_declined', 'error')
                markPedApproached(ped)
                clearPedTarget()
            end,
        },
    })
end

local function beginOfferOnPed(ped)
    if busyPed or not sellingActive then return end

    busyPed = ped
    local offer = lib.callback.await('w2f-weed:server:createStreetOffer', false, NetworkGetNetworkIdFromEntity(ped))
    if not offer then
        busyPed = nil
        local stillHas = lib.callback.await('w2f-weed:server:hasSellableDrugs', false)
        if not stillHas then
            stopSelling(true)
            notifyNoDrugs()
        else
            -- Buyer simply declined this approach (RNG); cool them down and move on.
            markPedApproached(ped)
        end
        return
    end

    currentOffer = offer
    SetEntityAsNoLongerNeeded(ped)
    ClearPedTasks(ped)

    -- Attach the sell/decline target IMMEDIATELY so the interaction is always
    -- available even if the buyer can't fully path to the player (stuck on
    -- geometry, player moving, etc). The walk below is purely cosmetic.
    attachOfferTarget(ped, offer)

    local playerCoords = GetEntityCoords(cache.ped)
    TaskGoStraightToCoord(ped, playerCoords.x, playerCoords.y, playerCoords.z, 1.2, -1, 0.0, 0.0)

    CreateThread(function()
        -- Window the buyer stays available for. The sell target is already
        -- attached; this only handles facing the player and freeing the buyer if
        -- the deal is never completed.
        local deadline = GetGameTimer() + 30000
        local faced = false
        while sellingActive and busyPed == ped and GetGameTimer() < deadline do
            if not DoesEntityExist(ped) or IsPedDeadOrDying(ped, false) then
                markPedApproached(ped)
                clearPedTarget()
                return
            end

            if not faced then
                local pCoords = GetEntityCoords(cache.ped)
                local pedCoords = GetEntityCoords(ped)
                if #(pCoords - pedCoords) <= 2.0 then
                    TaskTurnPedToFaceEntity(ped, cache.ped, 1000)
                    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_IMPATIENT_UPRIGHT', 0, false)
                    faced = true
                end
            end
            Wait(250)
        end

        -- Deal not completed in time (or selling stopped): free this buyer.
        if busyPed == ped then
            markPedApproached(ped)
            clearPedTarget()
        end
    end)
end

local function sellingLoop()
    while sellingActive do
        if sellingOrigin then
            local coords = GetEntityCoords(cache.ped)
            local radius = (Config.Selling and Config.Selling.AreaRadius) or 12.0
            if #(coords - sellingOrigin) > radius then
                notify('selling_too_far', 'error')
                stopSelling(true)
                break
            end
        end

        if not busyPed then
            local coords = GetEntityCoords(cache.ped)
            local ped = lib.getClosestPed(coords, 12.0)
            if isValidBuyerPed(ped) and canApproachPed(ped) then
                beginOfferOnPed(ped)
            end
        elseif currentOffer and targetPedNetId then
            local entity = NetworkGetEntityFromNetworkId(targetPedNetId)
            if not entity or entity == 0 or not DoesEntityExist(entity) then
                clearPedTarget()
            end
        end

        Wait((Config.Selling and Config.Selling.ScanIntervalMs) or 750)
    end
end

local function startSelling()
    if sellingActive then
        stopSelling(false)
        return
    end

    if not isSellingEnabled() then
        notify('feature_disabled', 'error')
        return
    end

    local ok, reason = lib.callback.await('w2f-weed:server:canStartStreetSelling', false)
    if not ok then
        if reason == 'no_drugs' then
            notify('selling_no_drugs', 'error')
        elseif reason == 'police' then
            notify('selling_not_enough_police', 'error')
        else
            notify('feature_disabled', 'error')
        end
        return
    end

    sellingActive = true
    sellingOrigin = GetEntityCoords(cache.ped)
    approachedPeds = {}
    notify('selling_started', 'success')
    CreateThread(sellingLoop)
end

RegisterNetEvent('w2f-weed:client:toggleStreetSelling', function()
    startSelling()
end)

--- In-resource toggle command (configurable), so selling works without an
--- external radial menu. Falls back gracefully if the feature is disabled.
if Config.Selling and Config.Selling.Command and Config.Selling.Command ~= '' then
    RegisterCommand(Config.Selling.Command, function()
        startSelling()
    end, false)
    if Config.Selling.CommandHelp then
        TriggerEvent('chat:addSuggestion', '/' .. Config.Selling.Command, Config.Selling.CommandHelp)
    end
end

RegisterNetEvent('w2f-weed:client:streetSaleResult', function(success, reason)
    if success then
        notify('selling_success', 'success')
        return
    end

    if reason == 'declined' then
        notify('selling_buyer_declined', 'error')
    elseif reason == 'no_items' then
        stopSelling(true)
        notifyNoDrugs()
    else
        notify('selling_failed', 'error')
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    stopSelling(true)
end)
