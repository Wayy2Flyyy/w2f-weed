--- Debug log (only when Config.Debug is true)
---@param ... any
function W2F.DebugLog(...)
    W2F.Debug(...)
end

--- Security event log
---@param message string
---@param data table|nil
function W2F.SecurityLog(message, data)
    local parts = { W2F.Prefix, '[SECURITY]', message }

    if data then
        for k, v in pairs(data) do
            parts[#parts + 1] = ('%s=%s'):format(tostring(k), tostring(v))
        end
    end

    print(table.concat(parts, ' '))
end

--- Shipment event log
---@param action string
---@param citizenid string
---@param data table|nil
function W2F.ShipmentLog(action, citizenid, data)
    local parts = { W2F.Prefix, '[SHIPMENT]', action, 'citizen=' .. tostring(citizenid) }

    if data then
        for k, v in pairs(data) do
            parts[#parts + 1] = ('%s=%s'):format(tostring(k), tostring(v))
        end
    end

    print(table.concat(parts, ' '))
end

--- Bribe event log
---@param citizenid string
---@param option string
---@param loyaltyGain number
function W2F.BribeLog(citizenid, option, loyaltyGain)
    print(('%s [BRIBE] citizen=%s option=%s loyaltyGain=%d'):format(
        W2F.Prefix, tostring(citizenid), tostring(option), loyaltyGain
    ))
end

--- Reward event log
---@param citizenid string
---@param tier string
---@param items table
function W2F.RewardLog(citizenid, tier, items)
    local itemStr = {}
    for _, item in ipairs(items) do
        itemStr[#itemStr + 1] = ('%s x%d'):format(item.name, item.amount)
    end

    print(('%s [REWARD] citizen=%s tier=%s items=[%s]'):format(
        W2F.Prefix, tostring(citizenid), tostring(tier), table.concat(itemStr, ', ')
    ))
end
