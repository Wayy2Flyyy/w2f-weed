--- Generate a unique shipment ID using timestamp and random suffix
---@return string
function W2F.GenerateShipmentId()
    return ('SHIP_%s_%s'):format(W2F.GetTimestamp(), math.random(1000, 9999))
end

--- Round a number to the nearest multiple
---@param value number
---@param nearest number
---@return number
function W2F.RoundToNearest(value, nearest)
    if nearest <= 0 then return value end
    return math.floor((value / nearest) + 0.5) * nearest
end

--- Clamp a value between min and max
---@param value number
---@param min number
---@param max number
---@return number
function W2F.Clamp(value, min, max)
    local v = tonumber(value)
    local lo = tonumber(min)
    local hi = tonumber(max)
    if lo == nil or hi == nil then
        return v or lo or hi or 0
    end
    if lo > hi then lo, hi = hi, lo end
    if v == nil then v = lo end
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

--- Horizontal distance between two points (ignores Z).
---@param a vector3|{ x: number, y: number }
---@param b vector3|{ x: number, y: number }
---@return number
function W2F.FlatDistance(a, b)
    if not a or not b then return math.huge end
    local dx = a.x - b.x
    local dy = a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

--- Check if a value exists in a table
---@param tbl table
---@param value any
---@return boolean
function W2F.TableContains(tbl, value)
    for _, v in pairs(tbl) do
        if v == value then return true end
    end
    return false
end

--- Returns true if a Config.Foundation master feature flag is enabled.
--- Missing flags (or a missing Foundation table) default to ENABLED so a
--- partial config never silently hard-disables a feature. This is the single
--- source of truth for the high-level toggles in config/main.lua.
---@param flag string
---@return boolean
function W2F.Foundation(flag)
    if not Config or not Config.Foundation then return true end
    return Config.Foundation[flag] ~= false
end

--- Debug print wrapper, only prints when Config.Debug is true
---@param ... any
function W2F.Debug(...)
    if not Config.Debug then return end
    local args = { ... }
    local parts = {}
    for i = 1, #args do
        parts[#parts + 1] = tostring(args[i])
    end
    print(('%s [DEBUG] %s'):format(W2F.Prefix, table.concat(parts, ' ')))
end

--- Calculate the effective cooldown for a player loyalty level
---@param baseCooldown number
---@param loyaltyLevel number
---@return number
function W2F.GetEffectiveCooldown(baseCooldown, loyaltyLevel)
    local level = Config.Loyalty.Levels[loyaltyLevel]
    if not level then return baseCooldown end
    return math.floor(baseCooldown * level.cooldownMultiplier)
end

--- Calculate the tip price based on loyalty level
---@param loyaltyLevel number
---@return number
function W2F.CalculateTipPrice(loyaltyLevel)
    local level = Config.Loyalty.Levels[loyaltyLevel]
    if not level then
        level = Config.Loyalty.Levels[0]
    end

    local price = Config.Payment.BaseTipPrice * level.priceMultiplier
    price = W2F.RoundToNearest(price, Config.Payment.PriceRoundsToNearest)
    return math.max(price, Config.Payment.MinTipPrice)
end

--- Get the shipment tier for a loyalty level
---@param loyaltyLevel number
---@return string
function W2F.GetShipmentTier(loyaltyLevel)
    local level = Config.Loyalty.Levels[loyaltyLevel]
    if not level then return 'basic' end
    return level.shipmentTier
end

--- Get the current unix timestamp (server: os.time; client: no os lib — use cloud time).
---@return integer
function W2F.GetTimestamp()
    if os and os.time then
        return os.time()
    end
    return GetCloudTimeAsInt()
end

--- Check if a timestamp has expired
---@param expiresAt integer
---@return boolean
function W2F.HasExpired(expiresAt)
    return W2F.GetTimestamp() >= expiresAt
end

--- Calculate remaining seconds from an expiry timestamp
---@param expiresAt integer
---@return integer
function W2F.GetTimeRemaining(expiresAt)
    local remaining = expiresAt - W2F.GetTimestamp()
    return remaining > 0 and remaining or 0
end

--- Format seconds into a readable string (e.g. "5m 30s")
---@param seconds integer
---@return string
function W2F.FormatTime(seconds)
    if seconds <= 0 then return '0s' end
    local m = math.floor(seconds / 60)
    local s = seconds % 60
    if m > 0 then
        return ('%dm %ds'):format(m, s)
    end
    return ('%ds'):format(s)
end
