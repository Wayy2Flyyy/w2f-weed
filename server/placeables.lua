-- ─────────────────────────────────────────────
-- w2f-weed | Server | Placeables module
--
-- Authoritative placement, validation, and persistence
-- for placeable props. Clients only request actions;
-- the server is the single source of truth.
--
-- Events:
--   w2f-weed:server:placeObject
--   w2f-weed:server:pickupObject
--   w2f-weed:server:requestPlacedObjects
--
-- Broadcasts to clients:
--   w2f-weed:client:createPlacedObject
--   w2f-weed:client:removePlacedObject
--   w2f-weed:client:syncPlacedObjects
-- ─────────────────────────────────────────────

local Placeables = W2FWeed.Placeables
local DebugPrint = Placeables.DebugPrint
local GetMessage = Placeables.GetMessage

-- in-memory store of all live placed objects, keyed by object_id
local Placed = {}

-- per-source rate limit (ms timestamps)
local LastPlaceAt = {}

local PLACE_COOLDOWN_MS = 750

-- ─────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────

local function notify(src, msgKey, type)
    if not src or src == 0 then return end
    local message = GetMessage(msgKey, msgKey)
    lib.notify( src, {
        title       = 'Placeables',
        description = message,
        type        = type or 'info',
        position    = 'top',
    })
end

local function getPlayer(src)
    if not src or src <= 0 then return nil end
    return W2F.GetPlayer(src)
end

local function getCitizenId(src)
    return W2F.GetCitizenId(src)
end

local function isAdmin(src)
    if not Config.Placeables.Ownership.AllowAdminPickup then return false end
    local ok, isAdminFn = pcall(function()
        return IsPlayerAceAllowed(src, 'command') or IsPlayerAceAllowed(src, 'w2f.admin')
    end)
    return ok and isAdminFn == true
end

local function distSqr(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    local dz = a.z - b.z
    return dx * dx + dy * dy + dz * dz
end

local function countByCitizen(citizenid)
    local n = 0
    for _, obj in pairs(Placed) do
        if obj.citizenid == citizenid then n = n + 1 end
    end
    return n
end

local function countAll()
    local n = 0
    for _ in pairs(Placed) do n = n + 1 end
    return n
end

local function findNearestTo(coords, maxDistance)
    local maxSqr = maxDistance * maxDistance
    local bestId, bestDistSqr
    for id, obj in pairs(Placed) do
        local d = distSqr(coords, { x = obj.x, y = obj.y, z = obj.z })
        if d <= maxSqr and (not bestDistSqr or d < bestDistSqr) then
            bestId, bestDistSqr = id, d
        end
    end
    return bestId, bestDistSqr
end

local function tooCloseToOther(coords, ignoreId)
    if not Config.Placeables.Limits.Enabled then return false end
    local minDist = Config.Placeables.Limits.MinimumDistanceBetweenObjects or 1.5
    local minSqr = minDist * minDist
    for id, obj in pairs(Placed) do
        if id ~= ignoreId then
            if distSqr(coords, { x = obj.x, y = obj.y, z = obj.z }) < minSqr then
                return true
            end
        end
    end
    return false
end

-- ─────────────────────────────────────────────
-- Database (CRUD)
-- ─────────────────────────────────────────────

--- Save a single placeable to the database.
---@param obj table
function W2F.SavePlaceableObject(obj)
    if not Config.Placeables.Persistence.SaveToDatabase then return end
    local metadataJson = nil
    if obj.metadata and next(obj.metadata) ~= nil then
        local ok, encoded = pcall(json.encode, obj.metadata)
        if ok then metadataJson = encoded end
    end

    MySQL.insert.await([[
        INSERT INTO w2f_weed_placeables
            (object_id, citizenid, item, model, label, category, x, y, z, heading, metadata, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            citizenid = VALUES(citizenid),
            item      = VALUES(item),
            model     = VALUES(model),
            label     = VALUES(label),
            category  = VALUES(category),
            x         = VALUES(x),
            y         = VALUES(y),
            z         = VALUES(z),
            heading   = VALUES(heading),
            metadata  = VALUES(metadata)
    ]], {
        obj.id,
        obj.citizenid,
        obj.item,
        obj.model,
        obj.label,
        obj.category,
        obj.x, obj.y, obj.z,
        obj.heading or 0.0,
        metadataJson,
        obj.created_at or W2F.GetTimestamp(),
    })
end

--- Delete a placeable from the database.
---@param objectId string
function W2F.DeletePlaceableObject(objectId)
    if not Config.Placeables.Persistence.SaveToDatabase then return end
    MySQL.query.await('DELETE FROM w2f_weed_placeables WHERE object_id = ?', { objectId })
end

--- Load all placeables from the database into memory.
---@return number count
function W2F.LoadPlaceableObjects()
    if not Config.Placeables.Persistence.LoadOnResourceStart then return 0 end

    local rows = MySQL.query.await('SELECT * FROM w2f_weed_placeables') or {}
    local n, skipped = 0, 0
    for _, row in ipairs(rows) do
        -- Skip legacy rows whose item is no longer registered in this module
        -- (e.g. planter boxes/plant_pot/soil_bag now belong to the planter system).
        if not Placeables.IsPlaceableItem(row.item) then
            skipped = skipped + 1
        else
            local metadata = nil
            if row.metadata and row.metadata ~= '' then
                local ok, decoded = pcall(json.decode, row.metadata)
                if ok then metadata = decoded end
            end

            Placed[row.object_id] = {
                id         = row.object_id,
                citizenid  = row.citizenid,
                item       = row.item,
                model      = row.model,
                label      = row.label,
                category   = row.category,
                x          = row.x,
                y          = row.y,
                z          = row.z,
                heading    = row.heading or 0.0,
                metadata   = metadata or {},
                created_at = row.created_at,
            }
            n = n + 1
        end
    end
    if skipped > 0 then
        DebugPrint(('skipped %d legacy rows (items moved to planter system)'):format(skipped))
    end
    return n
end

--- Count placeables owned by a citizenid (memory only).
---@param citizenid string
---@return number
function W2F.CountPlayerPlaceables(citizenid)
    return countByCitizen(citizenid)
end

-- ─────────────────────────────────────────────
-- Snapshot helpers
-- ─────────────────────────────────────────────

local function buildPayload(obj)
    local cfg = Placeables.GetConfig(obj.item) or {}
    return {
        id            = obj.id,
        owner         = obj.citizenid,
        item          = obj.item,
        model         = obj.model,
        label         = obj.label or cfg.label or obj.item,
        category      = obj.category or cfg.category,
        coords        = vec3(obj.x, obj.y, obj.z),
        heading       = obj.heading or 0.0,
        pickupEnabled = cfg.pickupEnabled ~= false,
        zOffset       = cfg.zOffset or 0.0,
        metadata      = obj.metadata or {},
    }
end

local function broadcastCreate(obj)
    TriggerClientEvent('w2f-weed:client:createPlacedObject', -1, buildPayload(obj))
end

local function broadcastRemove(objectId)
    TriggerClientEvent('w2f-weed:client:removePlacedObject', -1, objectId)
end

local function syncTo(src)
    local list = {}
    for _, obj in pairs(Placed) do
        list[#list + 1] = buildPayload(obj)
    end
    TriggerClientEvent('w2f-weed:client:syncPlacedObjects', src, list)
end

-- ─────────────────────────────────────────────
-- Validation
-- ─────────────────────────────────────────────

local function validatePlaceRequest(src, data)
    if not Placeables.IsEnabled() then
        return false, 'Placeables disabled.'
    end
    if type(data) ~= 'table' then return false, 'Bad payload.' end

    local item    = data.item
    local slot    = tonumber(data.slot)
    local heading = tonumber(data.heading) or 0.0
    local coords  = data.coords

    if type(item) ~= 'string' or not slot or type(coords) ~= 'table' then
        return false, 'Malformed request.'
    end

    if Config.Placeables.Security.ValidateItemWhitelist and not Placeables.IsPlaceableItem(item) then
        return false, 'NotPlaceable'
    end

    local cfg = Placeables.GetConfig(item)
    if not cfg then return false, 'NotPlaceable' end

    if Config.Placeables.Security.BlockInvalidModels and not Placeables.IsValidModel(cfg.prop) then
        return false, 'InvalidModel'
    end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false, 'No ped.' end

    if Config.Placeables.Security.BlockPlacementInVehicle then
        local veh = GetVehiclePedIsIn(ped, false)
        if veh and veh ~= 0 then
            return false, 'InVehicle'
        end
    end

    -- Distance check between player and placement coords
    local pCoords = GetEntityCoords(ped)
    local placement = Placeables.GetPlacement(item)
    local maxDist = (placement.maxDistanceFromPlayer or 4.0) + 1.5 -- small slack
    local d2 = distSqr(
        { x = pCoords.x, y = pCoords.y, z = pCoords.z },
        { x = coords.x, y = coords.y, z = coords.z }
    )
    if Config.Placeables.Security.ValidateDistance and d2 > (maxDist * maxDist) then
        return false, 'TooFar'
    end

    -- Inventory slot check
    if Config.Placeables.Security.ValidateExactInventorySlot then
        local slotData = exports.ox_inventory:GetSlot(src, slot)
        if not slotData or slotData.name ~= item or (slotData.count or 0) < 1 then
            return false, 'MissingItem'
        end
    end

    -- Limits
    if Config.Placeables.Limits.Enabled then
        local citizenid = getCitizenId(src)
        if not citizenid then return false, 'No citizenid.' end

        local perPlayer = Config.Placeables.Limits.MaxObjectsPerPlayer or 0
        if perPlayer > 0 and countByCitizen(citizenid) >= perPlayer then
            return false, 'LimitReached'
        end

        local global = Config.Placeables.Limits.MaxObjectsGlobal or 0
        if global > 0 and countAll() >= global then
            return false, 'LimitReached'
        end

        if tooCloseToOther({ x = coords.x, y = coords.y, z = coords.z }) then
            return false, 'TooClose'
        end
    end

    return true, {
        item     = item,
        slot     = slot,
        heading  = Placeables.ClampHeading(heading),
        coords   = { x = coords.x + 0.0, y = coords.y + 0.0, z = coords.z + 0.0 },
        cfg      = cfg,
    }
end

-- ─────────────────────────────────────────────
-- Events
-- ─────────────────────────────────────────────

RegisterNetEvent('w2f-weed:server:placeObject', function(payload)
    local src = source
    if not src or src <= 0 then return end

    -- Rate limit
    local now = GetGameTimer()
    if LastPlaceAt[src] and (now - LastPlaceAt[src]) < PLACE_COOLDOWN_MS then
        return
    end
    LastPlaceAt[src] = now

    local citizenid = getCitizenId(src)
    if not citizenid then return end

    local ok, resultOrReason = validatePlaceRequest(src, payload)
    if not ok then
        DebugPrint('placeObject rejected for', src, '->', resultOrReason)
        notify(src, resultOrReason or 'ServerRejected', 'error')
        return
    end

    local r   = resultOrReason
    local cfg = r.cfg

    -- Optionally remove the item before insert (rollback insert if remove fails)
    local removed = true
    if cfg.removeItemOnPlace then
        local rmOk = exports.ox_inventory:RemoveItem(src, r.item, 1, nil, r.slot)
        removed = rmOk == true
        if not removed then
            DebugPrint('RemoveItem failed for', src, r.item, 'slot', r.slot)
            notify(src, 'MissingItem', 'error')
            return
        end
    end

    local obj = {
        id         = Placeables.GenerateObjectId(),
        citizenid  = citizenid,
        item       = r.item,
        model      = cfg.prop,
        label      = cfg.label,
        category   = cfg.category,
        x          = r.coords.x,
        y          = r.coords.y,
        z          = r.coords.z,
        heading    = r.heading,
        metadata   = {},
        created_at = W2F.GetTimestamp(),
    }

    -- Save to DB
    local saveOk = pcall(function() W2F.SavePlaceableObject(obj) end)
    if not saveOk then
        -- rollback: give the item back if we removed it
        if cfg.removeItemOnPlace then
            exports.ox_inventory:AddItem(src, r.item, 1)
        end
        DebugPrint('DB save failed for', obj.id)
        notify(src, 'ServerRejected', 'error')
        return
    end

    Placed[obj.id] = obj
    broadcastCreate(obj)

    DebugPrint('placed', obj.id, 'by', citizenid, 'item', obj.item)
    notify(src, 'Placed', 'success')
end)

RegisterNetEvent('w2f-weed:server:pickupObject', function(objectId)
    local src = source
    if not src or src <= 0 then return end
    if type(objectId) ~= 'string' then return end

    local obj = Placed[objectId]
    if not obj then return end

    local cfg = Placeables.GetConfig(obj.item)
    if not cfg or cfg.pickupEnabled == false then
        notify(src, 'NotPlaceable', 'error')
        return
    end

    local citizenid = getCitizenId(src)
    if not citizenid then return end

    local owns = (obj.citizenid == citizenid)

    if Config.Placeables.Ownership.OnlyOwnerCanPickup and not owns then
        if not isAdmin(src) then
            notify(src, 'NotOwner', 'error')
            return
        end
    end

    -- Distance check
    local ped = GetPlayerPed(src)
    if ped and ped ~= 0 then
        local pCoords = GetEntityCoords(ped)
        local d2 = distSqr({ x = pCoords.x, y = pCoords.y, z = pCoords.z }, { x = obj.x, y = obj.y, z = obj.z })
        if d2 > (5.0 * 5.0) then
            notify(src, 'TooFar', 'error')
            return
        end
    end

    -- Give item back if configured
    if cfg.giveItemOnPickup then
        local can = exports.ox_inventory:CanCarryItem(src, obj.item, 1)
        if not can then
            notify(src, 'InventoryFull', 'error')
            return
        end
        local addOk = exports.ox_inventory:AddItem(src, obj.item, 1)
        if not addOk then
            notify(src, 'InventoryFull', 'error')
            return
        end
    end

    Placed[objectId] = nil
    pcall(function() W2F.DeletePlaceableObject(objectId) end)
    broadcastRemove(objectId)

    DebugPrint('picked up', objectId, 'by', citizenid)
    notify(src, 'PickedUp', 'success')
end)

-- NOTE: Planter-specific events (`fillPlanter`, `plantSeed`) used to live
-- here for the legacy `empty_planter_box` flow. They have been moved to
-- the dedicated planter growth system in `server/planters.lua`.

RegisterNetEvent('w2f-weed:server:requestPlacedObjects', function()
    local src = source
    if not src or src <= 0 then return end
    syncTo(src)
end)

-- ─────────────────────────────────────────────
-- Lifecycle
-- ─────────────────────────────────────────────

CreateThread(function()
    -- Wait briefly for the rest of the resource to come up.
    Wait(500)
    if not Placeables.IsEnabled() then
        DebugPrint('module disabled')
        return
    end

    local n = W2F.LoadPlaceableObjects()
    DebugPrint(('loaded %d placeables from DB'):format(n))
end)

AddEventHandler('playerDropped', function()
    LastPlaceAt[source] = nil
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= W2F.Resource then return end
    -- Memory clears naturally on stop; DB stays intact if persistence enabled.
end)

-- Optional: sync on player join shortly after spawn
if Config.Placeables.Persistence.SyncOnPlayerJoin then
    AddEventHandler('playerJoining', function() end) -- placeholder; client requests on its own
end

-- ─────────────────────────────────────────────
-- Debug / admin commands (only when Debug is true)
-- ─────────────────────────────────────────────

CreateThread(function()
    if not Config.Placeables.Debug then return end

    RegisterCommand('weed_placeables_count', function(src)
        local total = countAll()
        local msg = ('[w2f-weed] active placeables: %d (your: %d)'):format(total, src ~= 0 and countByCitizen(getCitizenId(src) or '') or 0)
        if src == 0 then
            print(msg)
        else
            TriggerClientEvent('chat:addMessage', src, { args = { '^2[w2f-weed]', msg } })
        end
    end, false)

    RegisterCommand('weed_placeables_refresh', function(src)
        if src == 0 then return end
        syncTo(src)
        notify(src, 'Loaded', 'info')
    end, false)

    RegisterCommand('weed_placeables_clearnear', function(src, args)
        if src == 0 then return end
        if not isAdmin(src) then
            notify(src, 'NotOwner', 'error')
            return
        end
        local ped = GetPlayerPed(src)
        if not ped or ped == 0 then return end
        local pCoords = GetEntityCoords(ped)
        local id = findNearestTo({ x = pCoords.x, y = pCoords.y, z = pCoords.z }, 3.0)
        if not id then
            TriggerClientEvent('chat:addMessage', src, { args = { '^3[w2f-weed]', 'No placeable within 3m.' } })
            return
        end
        Placed[id] = nil
        pcall(function() W2F.DeletePlaceableObject(id) end)
        broadcastRemove(id)
        TriggerClientEvent('chat:addMessage', src, { args = { '^2[w2f-weed]', 'Cleared placeable ' .. id } })
    end, true)

    RegisterCommand('weed_placeables_clearall', function(src)
        if not Config.Placeables.AllowClearAll then
            if src ~= 0 then
                TriggerClientEvent('chat:addMessage', src, { args = { '^1[w2f-weed]', 'clearall is disabled.' } })
            else
                print('[w2f-weed] clearall is disabled.')
            end
            return
        end
        if src ~= 0 and not isAdmin(src) then return end

        local toRemove = {}
        for id in pairs(Placed) do toRemove[#toRemove + 1] = id end
        for _, id in ipairs(toRemove) do
            Placed[id] = nil
            pcall(function() W2F.DeletePlaceableObject(id) end)
            broadcastRemove(id)
        end
        local msg = ('[w2f-weed] cleared %d placeables'):format(#toRemove)
        if src == 0 then print(msg) else TriggerClientEvent('chat:addMessage', src, { args = { '^2[w2f-weed]', msg } }) end
    end, true)
end)
