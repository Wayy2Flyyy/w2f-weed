local QBCoreObject = nil
local ESXObject = nil

local function getQBCoreObject()
    if QBCoreObject then return QBCoreObject end

    if GetResourceState('qb-core') == 'started' then
        QBCoreObject = exports['qb-core']:GetCoreObject()
    end

    return QBCoreObject
end

local function getESXObject()
    if ESXObject then return ESXObject end

    if GetResourceState('es_extended') == 'started' then
        ESXObject = exports['es_extended']:getSharedObject()
    end

    return ESXObject
end

--- Map QB account names to ESX account names.
---@param account string|nil
---@return string
function W2F.NormalizeAccount(account)
    account = account or (Config.Accounts and Config.Accounts.Cash) or 'cash'

    if W2F.Framework.IsESX() then
        if account == 'cash' or account == 'money' then
            return 'money'
        end
    elseif W2F.Framework.IsQbFamily() then
        if account == 'money' then
            return 'cash'
        end
    end

    return account
end

function W2F.GetPlayer(src)
    if not src or src <= 0 then return nil end

    local core = W2F.Framework.GetCoreName()

    if core == 'qbx_core' then
        return exports.qbx_core:GetPlayer(src)
    end

    if core == 'qb-core' then
        local QBCore = getQBCoreObject()
        if not QBCore then return nil end

        return QBCore.Functions.GetPlayer(src)
    end

    if core == 'esx' then
        local ESX = getESXObject()
        if not ESX then return nil end

        return ESX.GetPlayerFromId(src)
    end

    W2F.Debug('No supported framework found for GetPlayer')
    return nil
end

--- Extract the persistent player identifier used for DB rows.
--- QB/Qbox: citizenid. ESX: identifier (stored in the same DB column).
---@param player table|nil
---@return string|nil
function W2F.GetPlayerIdentifier(player)
    if not player then return nil end

    if W2F.Framework.IsESX() then
        return player.identifier
    end

    if player.PlayerData and player.PlayerData.citizenid then
        return player.PlayerData.citizenid
    end

    return nil
end

function W2F.GetCitizenId(src)
    return W2F.GetPlayerIdentifier(W2F.GetPlayer(src))
end

function W2F.GetOnlinePlayers()
    local core = W2F.Framework.GetCoreName()

    if core == 'qbx_core' then
        return exports.qbx_core:GetQBPlayers() or {}
    end

    if core == 'qb-core' then
        local QBCore = getQBCoreObject()
        if not QBCore or not QBCore.Functions then
            return {}
        end
        return QBCore.Functions.GetQBPlayers() or {}
    end

    if core == 'esx' then
        local ESX = getESXObject()
        if not ESX then return {} end

        local out = {}
        if ESX.GetExtendedPlayers then
            for _, xPlayer in pairs(ESX.GetExtendedPlayers()) do
                if xPlayer and xPlayer.source then
                    out[xPlayer.source] = xPlayer
                end
            end
            return out
        end

        local ids = ESX.GetPlayers and ESX.GetPlayers() or {}
        for i = 1, #ids do
            local playerSrc = ids[i]
            local xPlayer = ESX.GetPlayerFromId(playerSrc)
            if xPlayer then
                out[playerSrc] = xPlayer
            end
        end
        return out
    end

    W2F.Debug('No supported framework found for GetOnlinePlayers')
    return {}
end

--- Find an online player's source by their persistent identifier.
---@param identifier string
---@return number|nil
function W2F.GetSourceByCitizenId(identifier)
    if not identifier then return nil end

    local players = W2F.GetOnlinePlayers()
    for src, player in pairs(players) do
        if W2F.GetPlayerIdentifier(player) == identifier then
            return src
        end
    end

    return nil
end

---@param src number
---@param account string|nil
---@return number
function W2F.GetMoney(src, account)
    local player = W2F.GetPlayer(src)
    if not player then return 0 end

    account = W2F.NormalizeAccount(account)

    if W2F.Framework.IsESX() then
        if account == 'money' then
            return player.getMoney and player.getMoney() or 0
        end
        local acc = player.getAccount and player.getAccount(account)
        return acc and acc.money or 0
    end

    if player.Functions and player.Functions.GetMoney then
        return player.Functions.GetMoney(account) or 0
    end

    return 0
end

---@param src number
---@param account string|nil
---@param amount number
---@param reason string|nil
---@return boolean
function W2F.AddMoney(src, account, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false end

    local player = W2F.GetPlayer(src)
    if not player then return false end

    account = W2F.NormalizeAccount(account)
    reason = reason or 'w2f-weed'

    if W2F.Framework.IsESX() then
        if account == 'money' then
            if player.addMoney then player.addMoney(amount) return true end
        elseif player.addAccountMoney then
            player.addAccountMoney(account, amount, reason)
            return true
        end
        return false
    end

    if player.Functions and player.Functions.AddMoney then
        return player.Functions.AddMoney(account, amount, reason) == true
    end

    return false
end

---@param src number
---@param account string|nil
---@param amount number
---@param reason string|nil
---@return boolean
function W2F.RemoveMoney(src, account, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false end

    local player = W2F.GetPlayer(src)
    if not player then return false end

    account = W2F.NormalizeAccount(account)
    reason = reason or 'w2f-weed'

    if W2F.Framework.IsESX() then
        if account == 'money' then
            if player.removeMoney then
                player.removeMoney(amount, reason)
                return true
            end
        elseif player.removeAccountMoney then
            player.removeAccountMoney(account, amount, reason)
            return true
        end
        return false
    end

    if player.Functions and player.Functions.RemoveMoney then
        return player.Functions.RemoveMoney(account, amount, reason) == true
    end

    return false
end

--- Notify on-duty police of a street sale (framework-aware).
---@param src number
---@param message string
function W2F.TriggerPoliceAlert(src, message)
    message = message or 'Possible drug dealing reported nearby.'

    local cfg = Config.PoliceAlert or {}
    local core = W2F.Framework.GetCoreName()

    if core == 'esx' then
        if type(cfg.EsxEvent) == 'string' and cfg.EsxEvent ~= '' then
            TriggerEvent(cfg.EsxEvent, src, message)
            return
        end

        local ESX = getESXObject()
        if not ESX then return end

        local coords = GetEntityCoords(GetPlayerPed(src))
        local policeJob = cfg.EsxPoliceJob or 'police'

        if ESX.GetExtendedPlayers then
            for _, xPlayer in pairs(ESX.GetExtendedPlayers('job', policeJob)) do
                lib.notify(xPlayer.source, {
                    title       = 'Dispatch',
                    description = message,
                    type        = 'error',
                    position    = 'top',
                })
            end
            return
        end

        local ids = ESX.GetPlayers and ESX.GetPlayers() or {}
        for i = 1, #ids do
            local xPlayer = ESX.GetPlayerFromId(ids[i])
            if xPlayer and xPlayer.job and xPlayer.job.name == policeJob then
                lib.notify(xPlayer.source, {
                    title       = 'Dispatch',
                    description = message,
                    type        = 'error',
                    position    = 'top',
                })
            end
        end
        return
    end

    local qbEvent = cfg.QbEvent or 'police:server:policeAlert'
    TriggerEvent(qbEvent, message, nil, src)
end

--- Validate that a player is within a certain distance of coordinates
---@param src number
---@param target vector3|vector4
---@param maxDist number
---@return boolean
function W2F.ValidateDistance(src, target, maxDist)
    if not Config.Security.ValidateDistance then return true end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end

    local coords = GetEntityCoords(ped)
    local targetVec = vector3(target.x, target.y, target.z)
    local dist = #(coords - targetVec)

    return dist <= maxDist
end

--- Validate that a player has enough of a specific item
---@param src number
---@param itemName string
---@param amount number
---@return boolean
function W2F.ValidateItemCount(src, itemName, amount)
    if not Config.Security.ValidateItems then return true end
    if not itemName or amount <= 0 then return false end

    local count = exports.ox_inventory:GetItemCount(src, itemName)
    return count and count >= amount
end

--- Validate that a player can pay with the configured account
---@param src number
---@param amount number
---@return boolean
function W2F.ValidatePayment(src, amount)
    if not Config.Security.ValidateMoney then return true end
    if amount <= 0 then return false end

    if Config.BlackMoneyMode == 'item' then
        return W2F.ValidateItemCount(src, Config.Accounts.BlackMoney, amount)
    end

    local account = Config.Payment.Account
    return W2F.GetMoney(src, account) >= amount
end

--- Validate that a cooldown has passed for a given key
---@param cooldownTable table
---@param key string
---@param cooldownSeconds number
---@return boolean isReady
---@return number remainingSeconds
function W2F.ValidateCooldown(cooldownTable, key, cooldownSeconds)
    if not Config.Security.ValidateCooldowns then return true, 0 end

    local lastUsed = cooldownTable[key]
    if not lastUsed then return true, 0 end

    local elapsed = W2F.GetTimestamp() - lastUsed
    local remaining = cooldownSeconds - elapsed

    if remaining > 0 then
        return false, remaining
    end

    return true, 0
end

--- Validate that a shipment has not already been completed
---@param citizenid string
---@return boolean
function W2F.ValidateShipmentActive(citizenid)
    local shipment = W2F.ActiveShipments[citizenid]
    if not shipment then return false end
    if shipment.status ~= W2F.ShipmentStatus.Active then return false end
    if W2F.HasExpired(shipment.expiresAt) then return false end
    return true
end

--- Validate that there is no duplicate active shipment
---@param citizenid string
---@return boolean hasDuplicate
function W2F.ValidateNoDuplicateShipment(citizenid)
    if not Config.Shipments.OneActiveShipmentPerPlayer then return false end
    return W2F.ActiveShipments[citizenid] ~= nil
end

--- Validate that a reward item is in the configured seed items whitelist
---@param itemName string
---@return boolean
function W2F.ValidateRewardItem(itemName)
    return W2F.IsValidSeedItem(itemName)
end

--- Full validation for source: player exists, citizenid exists
---@param src number
---@return string|nil citizenid
function W2F.ValidateSource(src)
    if not src or src <= 0 then
        W2F.SecurityLog('Invalid source', { source = src })
        return nil
    end

    local citizenid = W2F.GetCitizenId(src)
    if not citizenid then
        W2F.SecurityLog('No citizenid for source', { source = src })
        return nil
    end

    return citizenid
end
