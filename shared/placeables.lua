-- ─────────────────────────────────────────────
-- w2f-weed | Shared | Placeables helpers
--
-- Pure helper functions used by both the client and
-- the server. They MUST NOT depend on client-only or
-- server-only natives.
-- ─────────────────────────────────────────────

W2FWeed             = W2FWeed or {}
W2FWeed.Placeables  = W2FWeed.Placeables or {}

local PREFIX = '[w2f-weed][placeables]'

--- Returns true if the placeables module is enabled.
---@return boolean
function W2FWeed.Placeables.IsEnabled()
    return Config and Config.Placeables and Config.Placeables.Enabled == true
end

--- Returns true if the given item name has a placeable definition.
---@param itemName string
---@return boolean
function W2FWeed.Placeables.IsPlaceableItem(itemName)
    if type(itemName) ~= 'string' then return false end
    if not Config or not Config.Placeables or not Config.Placeables.Items then
        return false
    end
    return Config.Placeables.Items[itemName] ~= nil
end

--- Returns the full config block for a placeable item, or nil.
---@param itemName string
---@return table|nil
function W2FWeed.Placeables.GetConfig(itemName)
    if not W2FWeed.Placeables.IsPlaceableItem(itemName) then return nil end
    return Config.Placeables.Items[itemName]
end

--- Returns a list of all configured placeable item names.
---@return string[]
function W2FWeed.Placeables.GetItemList()
    local list = {}
    if not Config or not Config.Placeables or not Config.Placeables.Items then
        return list
    end
    for itemName in pairs(Config.Placeables.Items) do
        list[#list + 1] = itemName
    end
    return list
end

--- Returns true if the model name is one of the whitelisted placeable props.
--- Used to ensure clients can never spawn arbitrary models server-side.
---@param model string|number
---@return boolean
function W2FWeed.Placeables.IsValidModel(model)
    if not Config or not Config.Placeables or not Config.Placeables.Items then
        return false
    end
    if type(model) == 'number' then
        for _, def in pairs(Config.Placeables.Items) do
            if def.prop and joaat(def.prop) == model then
                return true
            end
        end
        return false
    end
    if type(model) ~= 'string' then return false end
    for _, def in pairs(Config.Placeables.Items) do
        if def.prop == model then
            return true
        end
    end
    return false
end

--- Returns true if the item is configured as a custom-streamed prop.
--- Custom props live in resources/[w2f]/w2f-weed/stream/ and need
--- a longer model load timeout than built-in GTA props.
---@param itemName string
---@return boolean
function W2FWeed.Placeables.IsCustomProp(itemName)
    local cfg = W2FWeed.Placeables.GetConfig(itemName)
    return cfg ~= nil and cfg.isCustomProp == true
end

--- Resolves the placement parameters for an item, falling back to defaults.
---@param itemName string
---@return table placement Resolved placement settings
function W2FWeed.Placeables.GetPlacement(itemName)
    local cfg = W2FWeed.Placeables.GetConfig(itemName)
    local defaults = (Config and Config.Placeables and Config.Placeables.Placement) or {}
    local placement = (cfg and cfg.placement) or {}

    return {
        distance              = placement.distance              or defaults.DefaultDistance              or 1.8,
        heightOffset          = placement.heightOffset          or defaults.DefaultHeightOffset          or 0.0,
        rotationSpeed         = placement.rotationSpeed         or defaults.DefaultRotationSpeed         or 3.0,
        maxDistanceFromPlayer = placement.maxDistanceFromPlayer or defaults.DefaultMaxDistanceFromPlayer or 4.0,
    }
end

--- Clamps a heading to the [0, 360) range.
---@param heading number
---@return number
function W2FWeed.Placeables.ClampHeading(heading)
    if type(heading) ~= 'number' then return 0.0 end
    heading = heading % 360.0
    if heading < 0 then heading = heading + 360.0 end
    return heading
end

--- Distance squared between two vec3-like tables.
--- Cheaper than sqrt for comparisons.
---@param a table {x,y,z}
---@param b table {x,y,z}
---@return number
function W2FWeed.Placeables.DistanceSqr(a, b)
    if not a or not b then return math.huge end
    local dx = (a.x or 0) - (b.x or 0)
    local dy = (a.y or 0) - (b.y or 0)
    local dz = (a.z or 0) - (b.z or 0)
    return dx * dx + dy * dy + dz * dz
end

--- Generate a deterministic-but-unique object id (string).
---@return string
function W2FWeed.Placeables.GenerateObjectId()
    local rand = math.random(100000, 999999)
    local stamp = (os and os.time and os.time()) or GetGameTimer()
    return ('plc_%s_%s'):format(stamp, rand)
end

--- Returns a localised message from Config.Placeables.Messages, with fallback.
---@param key string
---@param fallback? string
---@return string
function W2FWeed.Placeables.GetMessage(key, fallback)
    if Config and Config.Placeables and Config.Placeables.Messages and Config.Placeables.Messages[key] then
        return Config.Placeables.Messages[key]
    end
    return fallback or key
end

--- Debug print, only fires when Config.Placeables.Debug is true.
function W2FWeed.Placeables.DebugPrint(...)
    if Config and Config.Placeables and Config.Placeables.Debug then
        print(PREFIX, ...)
    end
end
