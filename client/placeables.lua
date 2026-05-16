-- ─────────────────────────────────────────────
-- w2f-weed | Client | Placeables module
--
-- Handles:
--   - item-use placement preview (ghost prop)
--   - rotation, ground-snap, validity colouring
--   - confirm/cancel via configurable controls
--   - spawning/despawning placed objects
--   - ox_target pickup interaction
--   - cleanup on resource stop
-- ─────────────────────────────────────────────

local Placeables = W2FWeed.Placeables
local DebugPrint = Placeables.DebugPrint

-- objectId -> entity handle (spawned placeables)
local SpawnedEntities = {}
-- objectId -> payload snapshot
local SpawnedPayloads = {}
-- objectId -> ox_target sphere zone id fallback
local SpawnedTargetZones = {}

-- placement state
local PlacementActive   = false
local CurrentPreview    = 0
local CurrentItemName   = nil
local CurrentSlot       = nil
local CurrentHeading    = 0.0
local CurrentValid      = true

local OUTLINE_VALID   = { 90, 230, 140 }
local OUTLINE_INVALID = { 230, 70, 70 }

-- ─────────────────────────────────────────────
-- Notify helper
-- ─────────────────────────────────────────────

local function notify(msgKey, type)
    local message = Placeables.GetMessage(msgKey, msgKey)
    lib.notify({
        title       = 'Placeables',
        description = message,
        type        = type or 'info',
        position    = 'top',
    })
end

local function showHints(itemLabel)
    if not lib or not lib.showTextUI then return end
    lib.showTextUI(
        ('[E] Place  •  [Q / →] Rotate  •  [BACKSPACE] Cancel  —  %s'):format(itemLabel or 'Item'),
        { position = 'top-center' }
    )
end

local function hideHints()
    if lib and lib.hideTextUI then lib.hideTextUI() end
end

-- ─────────────────────────────────────────────
-- Model helpers
-- ─────────────────────────────────────────────

--- Load a model, with a longer timeout for custom-streamed props.
--- Returns the model hash on success, nil on failure.
---@param modelName string|number
---@param itemName? string Used to detect custom-prop items that need a longer load window
---@return number|nil
local function loadModel(modelName, itemName)
    local hash    = type(modelName) == 'number' and modelName or joaat(modelName)
    local custom  = itemName and Placeables.IsCustomProp(itemName) or false
    local timeout = custom and 15000 or 5000

    if not IsModelInCdimage(hash) then
        DebugPrint('model not in cdimage:', modelName, '(custom prop?', custom, ')')
        return nil
    end

    if lib and lib.requestModel then
        local ok = lib.requestModel(hash, timeout)
        if not ok then
            DebugPrint('lib.requestModel failed for', modelName)
            return nil
        end
    else
        RequestModel(hash)
        local deadline = GetGameTimer() + timeout
        while not HasModelLoaded(hash) and GetGameTimer() < deadline do
            Wait(0)
        end
        if not HasModelLoaded(hash) then
            DebugPrint('RequestModel timed out for', modelName)
            return nil
        end
    end
    return hash
end

local function safeDeleteEntity(entity)
    if not entity or entity == 0 then return end
    if not DoesEntityExist(entity) then return end
    SetEntityAsMissionEntity(entity, true, true)
    DeleteEntity(entity)
end

-- ─────────────────────────────────────────────
-- Spawn / despawn / sync
-- ─────────────────────────────────────────────

--- Build and register all ox_target options for a placed entity.
---@param entity number
---@param payload table
local function attachTarget(entity, payload)
    if not entity or entity == 0 then
        DebugPrint('attachTarget: entity is nil/0')
        return
    end

    if not DoesEntityExist(entity) then
        DebugPrint('attachTarget: entity', entity, 'does not exist')
        return
    end

    local options = {}

    -- Pickup option
    if payload.pickupEnabled ~= false then
        options[#options + 1] = {
            name     = 'w2f_weed_pickup_' .. payload.id,
            icon     = 'fa-solid fa-hand',
            label    = 'Pick Up ' .. (payload.label or payload.item),
            distance = 2.5,
            onSelect = function()
                TriggerServerEvent('w2f-weed:server:pickupObject', payload.id)
            end,
        }
    end

    if #options == 0 then return end

    DebugPrint('attachTarget: registering', #options, 'options on entity', entity, '(exists:', DoesEntityExist(entity), ')')

    exports.ox_target:addLocalEntity(entity, options)

    -- Custom props can register successfully but still fail raycast if their
    -- collision is poor. Add a small sphere zone fallback at the object coords.
    if payload.coords and not SpawnedTargetZones[payload.id] then
        local zoneId = exports.ox_target:addSphereZone({
            name = 'w2f_weed_placeable_zone_' .. payload.id,
            coords = vec3(payload.coords.x, payload.coords.y, payload.coords.z + 0.35),
            radius = 1.35,
            debug = false,
            options = options,
        })

        SpawnedTargetZones[payload.id] = zoneId
        DebugPrint('attachTarget: sphere fallback zone', zoneId, 'registered for', payload.id)
    end

    DebugPrint('attachTarget: SUCCESS for', payload.id)
end

--- Remove all registered ox_target options from an entity.
---@param entity number
---@param objectId string
local function detachTarget(entity, objectId)
    local names = {
        'w2f_weed_pickup_' .. objectId,
    }

    if entity and entity ~= 0 and DoesEntityExist(entity) then
        pcall(function()
            exports.ox_target:removeLocalEntity(entity, names)
        end)
    end

    local zoneId = SpawnedTargetZones[objectId]
    if zoneId then
        pcall(function()
            exports.ox_target:removeZone(zoneId, true)
        end)
        SpawnedTargetZones[objectId] = nil
    end
end

local function spawnPlaced(payload)
    if not payload or not payload.id then return end
    if SpawnedEntities[payload.id] then return end -- already spawned

    local hash = loadModel(payload.model, payload.item)
    if not hash then
        DebugPrint('cannot spawn, model load failed', payload.model, '(item:', payload.item, ')')
        return
    end

    local coords = payload.coords
    local zOff   = payload.zOffset or 0.0
    local x, y, z = coords.x + 0.0, coords.y + 0.0, (coords.z + zOff) + 0.0

    local entity = CreateObject(hash, x, y, z, false, true, false)
    if not entity or entity == 0 then
        DebugPrint('CreateObject returned nil/0 for', payload.model)
        SetModelAsNoLongerNeeded(hash)
        return
    end

    DebugPrint('created entity', entity, 'at', x, y, z, 'model', payload.model)

    SetEntityCoords(entity, x, y, z, false, false, false, false)
    SetEntityHeading(entity, payload.heading or 0.0)
    SetEntityCollision(entity, true, true)
    PlaceObjectOnGroundProperly(entity)
    FreezeEntityPosition(entity, true)
    SetEntityInvincible(entity, true)
    SetEntityAsMissionEntity(entity, true, true)
    SetModelAsNoLongerNeeded(hash)

    SpawnedEntities[payload.id] = entity
    SpawnedPayloads[payload.id] = payload

    -- Give the entity a tick to fully settle before ox_target registration
    Wait(200)

    if not DoesEntityExist(entity) then
        DebugPrint('entity vanished before target attach for', payload.id)
        SpawnedEntities[payload.id] = nil
        SpawnedPayloads[payload.id] = nil
        return
    end

    attachTarget(entity, payload)

    DebugPrint('spawned', payload.id, 'as entity', entity, 'handle valid:', DoesEntityExist(entity))
end

local function despawnPlaced(objectId)
    local entity = SpawnedEntities[objectId]
    if entity then
        detachTarget(entity, objectId)
        safeDeleteEntity(entity)
    end
    SpawnedEntities[objectId] = nil
    SpawnedPayloads[objectId] = nil
    SpawnedTargetZones[objectId] = nil
end

local function clearAllSpawned()
    for id in pairs(SpawnedEntities) do
        despawnPlaced(id)
    end
end

-- ─────────────────────────────────────────────
-- Validity check (water / surface)
-- ─────────────────────────────────────────────

local function checkValid(coords)
    if Config.Placeables.Security.BlockPlacementInWater then
        local hasWater, _ = GetWaterHeight(coords.x, coords.y, coords.z)
        if hasWater then return false end
    end
    if Config.Placeables.Limits.Enabled then
        local minDist = Config.Placeables.Limits.MinimumDistanceBetweenObjects or 1.5
        local minSqr  = minDist * minDist
        for _, payload in pairs(SpawnedPayloads) do
            local p = payload.coords
            local dx, dy, dz = (coords.x - p.x), (coords.y - p.y), (coords.z - p.z)
            if (dx * dx + dy * dy + dz * dz) < minSqr then
                return false
            end
        end
    end
    return true
end

local function getGroundCoords(x, y, z)
    if not Config.Placeables.Placement.RequireGround then
        return vec3(x, y, z)
    end
    local ok, groundZ = GetGroundZFor_3dCoord(x, y, z + 2.0, false)
    if ok then
        return vec3(x, y, groundZ)
    end
    return vec3(x, y, z)
end

-- ─────────────────────────────────────────────
-- Placement loop
-- ─────────────────────────────────────────────

local function endPlacement(cancelled)
    PlacementActive = false
    hideHints()
    safeDeleteEntity(CurrentPreview)
    CurrentPreview  = 0
    CurrentItemName = nil
    CurrentSlot     = nil
    CurrentHeading  = 0.0
    CurrentValid    = true
    if cancelled then notify('Cancelled', 'info') end
end

local function startPlacement(itemName, slot)
    if PlacementActive then return end
    if not Placeables.IsEnabled() then return end
    if not Placeables.IsPlaceableItem(itemName) then
        notify('NotPlaceable', 'error')
        return
    end

    local cfg = Placeables.GetConfig(itemName)
    local placement = Placeables.GetPlacement(itemName)

    -- Block from inside vehicles
    local ped = PlayerPedId()
    if Config.Placeables.Security.BlockPlacementInVehicle then
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 then
            notify('InVehicle', 'error')
            return
        end
    end

    local hash = loadModel(cfg.prop, itemName)
    if not hash then
        notify('InvalidModel', 'error')
        return
    end

    local pCoords = GetEntityCoords(ped)
    local entity = CreateObjectNoOffset(hash, pCoords.x, pCoords.y, pCoords.z, false, false, false)
    if not entity or entity == 0 then
        SetModelAsNoLongerNeeded(hash)
        notify('InvalidModel', 'error')
        return
    end

    SetEntityCollision(entity, false, false)
    SetEntityAlpha(entity, Config.Placeables.Placement.PreviewAlpha or 165, false)
    FreezeEntityPosition(entity, true)
    if Config.Placeables.Placement.UseOutlinePreview then
        SetEntityDrawOutline(entity, true)
        SetEntityDrawOutlineColor(OUTLINE_VALID[1], OUTLINE_VALID[2], OUTLINE_VALID[3], 200)
    end
    SetModelAsNoLongerNeeded(hash)

    PlacementActive = true
    CurrentPreview  = entity
    CurrentItemName = itemName
    CurrentSlot     = slot
    CurrentHeading  = GetEntityHeading(ped)
    CurrentValid    = true

    showHints(cfg.label or itemName)

    local controls = Config.Placeables.Controls
    local rotSpeed = placement.rotationSpeed or 3.0
    local placeDist = placement.distance or 1.8

    CreateThread(function()
        while PlacementActive and CurrentPreview ~= 0 and DoesEntityExist(CurrentPreview) do
            -- Disable conflicting controls
            DisableControlAction(0, controls.Place,       true)
            DisableControlAction(0, controls.Cancel,      true)
            DisableControlAction(0, controls.RotateLeft,  true)
            DisableControlAction(0, controls.RotateRight, true)
            DisableControlAction(0, 25,  true) -- aim
            DisableControlAction(0, 24,  true) -- attack
            DisableControlAction(0, 142, true) -- melee

            local pPed = PlayerPedId()
            local fwd = GetOffsetFromEntityInWorldCoords(pPed, 0.0, placeDist, 0.0)
            local snapped = getGroundCoords(fwd.x, fwd.y, fwd.z)
            local finalCoords = vec3(snapped.x, snapped.y, snapped.z + (cfg.zOffset or 0.0) + (placement.heightOffset or 0.0))

            SetEntityCoordsNoOffset(CurrentPreview, finalCoords.x, finalCoords.y, finalCoords.z, false, false, false)
            SetEntityHeading(CurrentPreview, CurrentHeading)

            local valid = checkValid(finalCoords)
            if valid ~= CurrentValid then
                CurrentValid = valid
                if Config.Placeables.Placement.UseOutlinePreview then
                    local c = valid and OUTLINE_VALID or OUTLINE_INVALID
                    SetEntityDrawOutlineColor(c[1], c[2], c[3], 220)
                end
            end

            -- Rotation
            if IsDisabledControlPressed(0, controls.RotateLeft) then
                CurrentHeading = Placeables.ClampHeading(CurrentHeading + rotSpeed)
            elseif IsDisabledControlPressed(0, controls.RotateRight) then
                CurrentHeading = Placeables.ClampHeading(CurrentHeading - rotSpeed)
            end

            -- Cancel
            if IsDisabledControlJustReleased(0, controls.Cancel) then
                endPlacement(true)
                break
            end

            -- Confirm
            if IsDisabledControlJustReleased(0, controls.Place) then
                if not CurrentValid then
                    notify('InvalidGround', 'error')
                else
                    -- Snapshot then end placement BEFORE the network round trip
                    local item    = CurrentItemName
                    local slotVal = CurrentSlot
                    local heading = CurrentHeading
                    local cx, cy, cz = finalCoords.x, finalCoords.y, finalCoords.z

                    endPlacement(false)

                    TriggerServerEvent('w2f-weed:server:placeObject', {
                        item    = item,
                        slot    = slotVal,
                        coords  = { x = cx, y = cy, z = cz },
                        heading = heading,
                    })
                    break
                end
            end

            Wait(0)
        end

        -- Loop ended without cancel/confirm (eg resource stop) -> cleanup
        if PlacementActive then
            endPlacement(true)
        end
    end)
end

-- ─────────────────────────────────────────────
-- Item use entry-point (ox_inventory client.event)
-- ─────────────────────────────────────────────

RegisterNetEvent('w2f-weed:client:startPlaceablePlacement', function(data)
    DebugPrint('startPlaceablePlacement', json.encode(data or {}))

    if type(data) ~= 'table' then return end
    local itemName = data.name
    local slot     = tonumber(data.slot)

    if not itemName or not slot then
        notify('NotPlaceable', 'error')
        return
    end

    if PlacementActive then
        notify('Cancelled', 'info')
        endPlacement(true)
        Wait(50)
    end

    startPlacement(itemName, slot)
end)

-- ─────────────────────────────────────────────
-- Sync handlers from server
-- ─────────────────────────────────────────────

RegisterNetEvent('w2f-weed:client:createPlacedObject', function(payload)
    if type(payload) ~= 'table' or not payload.id then return end
    CreateThread(function()
        spawnPlaced(payload)
    end)
end)

RegisterNetEvent('w2f-weed:client:removePlacedObject', function(objectId)
    if type(objectId) ~= 'string' then return end
    despawnPlaced(objectId)
end)

RegisterNetEvent('w2f-weed:client:syncPlacedObjects', function(list)
    if type(list) ~= 'table' then return end

    -- track ids that are still valid
    local seen = {}
    for _, payload in ipairs(list) do
        if payload and payload.id then
            seen[payload.id] = true
            if not SpawnedEntities[payload.id] then
                CreateThread(function()
                    spawnPlaced(payload)
                end)
            end
        end
    end

    -- despawn anything no longer present
    for id in pairs(SpawnedEntities) do
        if not seen[id] then despawnPlaced(id) end
    end
end)

-- ─────────────────────────────────────────────
-- Lifecycle: request initial sync once everything's loaded
-- ─────────────────────────────────────────────

CreateThread(function()
    -- Wait until the player is loaded into the world
    while not NetworkIsPlayerActive(PlayerId()) do Wait(250) end
    Wait(1000)

    if Placeables.IsEnabled() and Config.Placeables.Persistence.SyncOnPlayerJoin then
        TriggerServerEvent('w2f-weed:server:requestPlacedObjects')
        DebugPrint('requested initial placeable sync')
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if PlacementActive then endPlacement(true) end
    clearAllSpawned()
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    -- noop; the join thread above handles the initial sync
end)

-- ─────────────────────────────────────────────
-- Debug commands (client side mirror, only when Debug)
-- ─────────────────────────────────────────────

CreateThread(function()
    if not Config.Placeables or not Config.Placeables.Debug then return end

    RegisterCommand('weed_placeables_refresh', function()
        TriggerServerEvent('w2f-weed:server:requestPlacedObjects')
    end, false)
end)
