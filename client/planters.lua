-- ─────────────────────────────────────────────
-- w2f-weed | Client | Planters + Growth
--
-- Handles:
--   * Planter box placement preview (empty planter item; then NetEvent entry)
--   * Soil proxy ox_target zone above the soil surface
--   * Spawning planter props and switching empty <-> filled prop
--   * Spawning plant props at local offsets and stage transitions
--   * Free-placement preview for planting a seed inside the soil
--   * ox_target options on plants (Inspect, Harvest)
--   * Cleanup on resource stop
-- ─────────────────────────────────────────────

local Planters = W2FWeed.Planters
local Strains  = W2FWeed.Strains
local Growth   = W2FWeed.Growth
local DebugP   = Planters.DebugPrint

-- ─── State ────────────────────────────────────
-- Planter cache: id -> { ...payload, entity, soilZone }
local PlanterCache = {}
-- Plant cache: id -> { ...payload, entity, planterId }
local PlantCache   = {}
-- Map planterId -> { [plantId]=true, ... }
local PlantsOfPlanter = {}
local InteractionBusy = false

-- Active planter placement preview
local PlanterPlace = {
    active   = false,
    entity   = 0,
    item     = nil,
    slot     = nil,
    heading  = 0.0,
    valid    = true,
}

-- Active plant-in-soil placement preview
local PlantPlace = {
    active    = false,
    entity    = 0,
    planterId = nil,
    seedItem  = nil,
    slot      = nil,
    localX    = 0.0,
    localY    = 0.0,
    rotation  = 0.0,
    valid     = true,
}

local OUTLINE_VALID
local OUTLINE_INVALID

local function refreshOutlineColors()
    local pv = (Config.Planters and Config.Planters.Preview) or {}
    OUTLINE_VALID   = pv.OutlineColor   or { 110, 211, 243, 180 }
    OUTLINE_INVALID = pv.OutlineInvalid or { 230, 70, 70, 200 }
end

-- ─── Common helpers ──────────────────────────

local function notify(key, type)
    local message = Planters.GetMessage(key, key)
    lib.notify({
        title       = 'Planters',
        description = message,
        type        = type or 'info',
        position    = 'top',
    })
end

local function showHints(text)
    if not lib or not lib.showTextUI then return end
    lib.showTextUI(text, { position = 'top-center' })
end

local function hideHints()
    if lib and lib.hideTextUI then lib.hideTextUI() end
end

local function doProgress(label, duration, anim)
    return lib.progressBar({
        duration = duration,
        label = label,
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true,
        },
        anim = anim
    })
end

local function loadModel(modelName, longTimeout)
    local hash = type(modelName) == 'number' and modelName or joaat(modelName)
    local timeout = longTimeout and 15000 or 7500

    if not IsModelInCdimage(hash) then
        DebugP('model not in cdimage:', modelName)
        return nil
    end

    if lib and lib.requestModel then
        if lib.requestModel(hash, timeout) then return hash end
        return nil
    end

    RequestModel(hash)
    local deadline = GetGameTimer() + timeout
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(0) end
    if not HasModelLoaded(hash) then return nil end
    return hash
end

local function safeDeleteEntity(entity)
    if not entity or entity == 0 then return end
    if not DoesEntityExist(entity) then return end
    SetEntityAsMissionEntity(entity, true, true)
    DeleteEntity(entity)
end

-- ─────────────────────────────────────────────
-- Planter box placement preview (empty planter / plant_pot from inventory)
-- Order: ground snap → validation → cancel/confirm → main loop → NetEvent
-- ─────────────────────────────────────────────

local function getGroundCoords(x, y, z)
    if not Config.Planters.PlanterPreview.RequireGround then return vec3(x, y, z) end
    local ok, groundZ = GetGroundZFor_3dCoord(x, y, z + 2.0, false)
    if ok then return vec3(x, y, groundZ) end
    return vec3(x, y, z)
end

local function checkPlanterValid(coords)
    if Config.Planters.Security.BlockPlacementInWater then
        local hasWater = GetWaterHeight(coords.x, coords.y, coords.z)
        if hasWater then return false end
    end
    local minDist = (Config.Planters.Limits and Config.Planters.Limits.MinPlanterSpacing) or 1.5
    local minSq = minDist * minDist
    for _, planter in pairs(PlanterCache) do
        local p = planter.coords
        if p then
            local dx, dy, dz = (coords.x - p.x), (coords.y - p.y), (coords.z - p.z)
            if (dx * dx + dy * dy + dz * dz) < minSq then return false end
        end
    end
    return true
end

local function endPlanterPlacement(cancelled)
    PlanterPlace.active = false
    safeDeleteEntity(PlanterPlace.entity)
    PlanterPlace.entity  = 0
    PlanterPlace.item    = nil
    PlanterPlace.slot    = nil
    PlanterPlace.heading = 0.0
    PlanterPlace.valid   = true
    hideHints()
    if cancelled then notify('Cancelled', 'info') end
end

local function startPlanterPlacement(itemName, slot)
    if PlanterPlace.active then return end
    if not Planters.IsEnabled() then return end

    refreshOutlineColors()

    local ped = PlayerPedId()
    if Config.Planters.Security.BlockPlacementInVehicle then
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 then notify('InVehicle', 'error'); return end
    end

    local emptyProp = Planters.GetEmptyProp()
    local hash = loadModel(emptyProp, true)
    if not hash then notify('ServerRejected', 'error'); return end

    local pCoords = GetEntityCoords(ped)
    local entity  = CreateObjectNoOffset(hash, pCoords.x, pCoords.y, pCoords.z, false, false, false)
    if not entity or entity == 0 then SetModelAsNoLongerNeeded(hash); return end

    SetEntityCollision(entity, false, false)
    SetEntityAlpha(entity, Config.Planters.PlanterPreview.PreviewAlpha or 165, false)
    FreezeEntityPosition(entity, true)
    if Config.Planters.PlanterPreview.UseOutlinePreview then
        SetEntityDrawOutline(entity, true)
        SetEntityDrawOutlineColor(OUTLINE_VALID[1], OUTLINE_VALID[2], OUTLINE_VALID[3], 220)
    end
    SetModelAsNoLongerNeeded(hash)

    PlanterPlace.active  = true
    PlanterPlace.entity  = entity
    PlanterPlace.item    = itemName
    PlanterPlace.slot    = slot
    PlanterPlace.heading = GetEntityHeading(ped)
    PlanterPlace.valid   = true

    showHints('[E] Place  •  [Q / →] Rotate  •  [BACKSPACE] Cancel  —  Planter')

    local rotSpeed = Config.Planters.PlanterPreview.RotationSpeed or 3.0
    local placeDist = Config.Planters.PlanterPreview.DefaultDistance or 2.2

    CreateThread(function()
        while PlanterPlace.active and PlanterPlace.entity ~= 0 and DoesEntityExist(PlanterPlace.entity) do
            DisableControlAction(0, 38, true)  -- E
            DisableControlAction(0, 177, true) -- BACKSPACE
            DisableControlAction(0, 44, true)  -- Q
            DisableControlAction(0, 175, true) -- right arrow
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 24, true)

            local pPed = PlayerPedId()
            local fwd = GetOffsetFromEntityInWorldCoords(pPed, 0.0, placeDist, 0.0)
            local snapped = getGroundCoords(fwd.x, fwd.y, fwd.z)
            local finalCoords = vec3(snapped.x, snapped.y, snapped.z)

            SetEntityCoordsNoOffset(PlanterPlace.entity, finalCoords.x, finalCoords.y, finalCoords.z, false, false, false)
            SetEntityHeading(PlanterPlace.entity, PlanterPlace.heading)

            local valid = checkPlanterValid(finalCoords)
            if valid ~= PlanterPlace.valid then
                PlanterPlace.valid = valid
                if Config.Planters.PlanterPreview.UseOutlinePreview then
                    local c = valid and OUTLINE_VALID or OUTLINE_INVALID
                    SetEntityDrawOutlineColor(c[1], c[2], c[3], 220)
                end
            end

            if IsDisabledControlPressed(0, 44) then
                PlanterPlace.heading = (PlanterPlace.heading + rotSpeed) % 360
            elseif IsDisabledControlPressed(0, 175) then
                PlanterPlace.heading = (PlanterPlace.heading - rotSpeed + 360) % 360
            end

            if IsDisabledControlJustReleased(0, 177) then
                endPlanterPlacement(true)
                break
            end

            if IsDisabledControlJustReleased(0, 38) then
                if not PlanterPlace.valid then
                    notify('ServerRejected', 'error')
                else
                    local item    = PlanterPlace.item
                    local slotVal = PlanterPlace.slot
                    local heading = PlanterPlace.heading
                    local cx, cy, cz = finalCoords.x, finalCoords.y, finalCoords.z

                    endPlanterPlacement(false)
                    if InteractionBusy then break end
                    InteractionBusy = true
                    local ok = doProgress('Placing planter...', (Config.Planters.Progress and Config.Planters.Progress.PlacePlanter) or 3000, {
                        dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
                        clip = 'machinic_loop_mechandplayer'
                    })
                    InteractionBusy = false
                    if not ok then break end

                    TriggerServerEvent('w2f-weed:server:placePlanter', {
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

        if PlanterPlace.active then endPlanterPlacement(true) end
    end)
end

RegisterNetEvent('w2f-weed:client:startPlanterPlacement', function(data)
    if type(data) ~= 'table' then return end
    local itemName = data.name
    local slot     = tonumber(data.slot)
    if not itemName or not slot then return end

    if PlanterPlace.active then
        endPlanterPlacement(true)
        Wait(50)
    end
    startPlanterPlacement(itemName, slot)
end)

-- ─────────────────────────────────────────────
-- Soil proxy ox_target zone
-- ─────────────────────────────────────────────

local function harvestablePlantsCount(planterId)
    if not planterId or not PlantsOfPlanter[planterId] then return 0 end
    local n = 0
    for pid in pairs(PlantsOfPlanter[planterId]) do
        local pl = PlantCache[pid]
        if pl then
            local _, st = Growth.GetStageForProgress(pl.progress)
            if st and st.harvestable then n = n + 1 end
        end
    end
    return n
end

local function buildPlanterTargetOptions(planter)
    local opts = {}
    local soilState = planter.state == 'filled'

    -- Always available: pickup
    opts[#opts + 1] = {
        name     = 'w2f_pln_pickup_' .. planter.id,
        icon     = 'fa-solid fa-hand',
        label    = 'Pick Up Planter',
        distance = 2.5,
        onSelect = function()
            if InteractionBusy then return end
            InteractionBusy = true
            local ok = doProgress('Picking up planter...', (Config.Planters.Progress and Config.Planters.Progress.PickupPlanter) or 3000, {
                dict = 'pickup_object',
                clip = 'pickup_low'
            })
            InteractionBusy = false
            if not ok then return end
            TriggerServerEvent('w2f-weed:server:pickupPlanter', planter.id)
        end,
    }

    if not soilState then
        opts[#opts + 1] = {
            name     = 'w2f_pln_addsoil_' .. planter.id,
            icon     = 'fa-solid fa-fill-drip',
            label    = 'Add Soil',
            distance = 2.5,
            onSelect = function()
                if InteractionBusy then return end
                InteractionBusy = true
                local ok = doProgress('Adding soil...', (Config.Planters.Progress and Config.Planters.Progress.AddSoil) or 4500, {
                    dict = 'amb@world_human_gardener_plant@male@base',
                    clip = 'base'
                })
                InteractionBusy = false
                if not ok then return end
                TriggerServerEvent('w2f-weed:server:addSoilToPlanter', planter.id)
            end,
        }
    else
        opts[#opts + 1] = {
            name     = 'w2f_pln_plant_' .. planter.id,
            icon     = 'fa-solid fa-seedling',
            label    = 'Plant Seed',
            distance = 2.5,
            onSelect = function()
                StartPlantPlacement(planter.id)
            end,
        }

        opts[#opts + 1] = {
            name     = 'w2f_pln_inspect_' .. planter.id,
            icon     = 'fa-solid fa-magnifying-glass',
            label    = 'Inspect Planter',
            distance = 2.5,
            onSelect = function()
                InspectPlanter(planter.id)
            end,
        }

        opts[#opts + 1] = {
            name     = 'w2f_pln_harvest_ready_' .. planter.id,
            icon     = 'fa-solid fa-scissors',
            label    = 'Harvest mature plants (planter)',
            distance = 2.5,
            canInteract = function()
                return harvestablePlantsCount(planter.id) >= 1
            end,
            onSelect = function()
                if harvestablePlantsCount(planter.id) < 1 then return end
                local harvestCfg = Config.Planters.Harvest
                local requireTool = not harvestCfg or harvestCfg.RequireTrimmingScissors ~= false
                local tool = (Config.Planters.Items and Config.Planters.Items.TrimmingScissors) or 'trimming_scissors'
                local hasTool = not requireTool or (exports.ox_inventory:GetItemCount(tool) or 0) >= 1
                if requireTool and not hasTool then
                    notify('MissingTrimmingScissors', 'error')
                    return
                end
                if InteractionBusy then return end
                InteractionBusy = true
                local ok = doProgress('Harvesting mature plants...', (Config.Planters.Progress and Config.Planters.Progress.HarvestReadyPlants) or 8000, {
                    dict = 'amb@world_human_gardener_plant@male@base',
                    clip = 'base'
                })
                InteractionBusy = false
                if not ok then return end
                TriggerServerEvent('w2f-weed:server:harvestReadyPlantsOnPlanter', planter.id)
            end,
        }
    end

    return opts
end

local function attachPlanterTargets(planter)
    if not planter or not planter.id or not planter.coords then return end

    -- Detach previous (in case of state swap)
    if planter._zoneId then
        pcall(function() exports.ox_target:removeZone(planter._zoneId, true) end)
        planter._zoneId = nil
    end
    if planter._entityTargets and planter.entity and planter.entity ~= 0 then
        pcall(function() exports.ox_target:removeLocalEntity(planter.entity, planter._entityTargets) end)
    end

    local opts = buildPlanterTargetOptions(planter)
    local names = {}
    for _, o in ipairs(opts) do names[#names + 1] = o.name end

    -- Attach to entity (best ergonomics)
    if planter.entity and planter.entity ~= 0 and DoesEntityExist(planter.entity) then
        exports.ox_target:addLocalEntity(planter.entity, opts)
        planter._entityTargets = names
    end

    -- Sphere zone fallback (custom prop collision can be poor for ox_target)
    local soilArea = Planters.GetSoilArea()
    local zCenter = (planter.coords.z or 0) + (soilArea.zOffset or 0.22) + (soilArea.height or 0.2) * 0.5
    local zoneId = exports.ox_target:addSphereZone({
        name    = 'w2f_pln_zone_' .. planter.id,
        coords  = vec3(planter.coords.x, planter.coords.y, zCenter),
        radius  = math.max(soilArea.width or 1.0, soilArea.length or 0.8) * 0.85 + 0.25,
        debug   = false,
        options = opts,
    })
    planter._zoneId = zoneId
end

local function detachPlanterTargets(planter)
    if not planter then return end
    if planter._zoneId then
        pcall(function() exports.ox_target:removeZone(planter._zoneId, true) end)
        planter._zoneId = nil
    end
    if planter._entityTargets and planter.entity and planter.entity ~= 0 and DoesEntityExist(planter.entity) then
        pcall(function() exports.ox_target:removeLocalEntity(planter.entity, planter._entityTargets) end)
    end
    planter._entityTargets = nil
end

local function refreshPlanterTargets(planterId)
    local pl = planterId and PlanterCache[planterId]
    if not pl or not pl.entity or pl.entity == 0 or not DoesEntityExist(pl.entity) then return end
    detachPlanterTargets(pl)
    attachPlanterTargets(pl)
end

-- ─────────────────────────────────────────────
-- Plant prop spawn / target / replace
-- ─────────────────────────────────────────────

local function buildPlantTargetOptions(plant)
    local opts = {}
    opts[#opts + 1] = {
        name     = 'w2f_plt_inspect_' .. plant.id,
        icon     = 'fa-solid fa-magnifying-glass',
        label    = 'Inspect Plant',
        distance = 2.0,
        onSelect = function() InspectPlant(plant.id) end,
    }

    local _, stage = Growth.GetStageForProgress(plant.progress)
    if not (stage and stage.harvestable) then
        local fertilizers = (Config.Growth and Config.Growth.Fertilizers) or {}
        for itemName, fert in pairs(fertilizers) do
            opts[#opts + 1] = {
                name     = ('w2f_plt_fertilize_%s_%s'):format(itemName, plant.id),
                icon     = 'fa-solid fa-seedling',
                label    = ('Apply %s (-%d min)'):format(fert.label or itemName, fert.decreaseMinutes or 0),
                distance = 2.0,
                onSelect = function()
                    if InteractionBusy then return end
                    InteractionBusy = true
                    local ok = doProgress(('Applying %s...'):format(fert.label or itemName), (Config.Planters.Progress and Config.Planters.Progress.ApplyFertilizer) or 3500, {
                        dict = 'amb@world_human_gardener_plant@male@base',
                        clip = 'base'
                    })
                    InteractionBusy = false
                    if not ok then return end
                    TriggerServerEvent('w2f-weed:server:applyFertilizerToPlant', plant.id, itemName)
                end,
            }
        end
    end

    if stage and stage.harvestable then
        local harvestCfg = Config.Planters.Harvest
        local requireTool = not harvestCfg or harvestCfg.RequireTrimmingScissors ~= false
        local tool = (Config.Planters.Items and Config.Planters.Items.TrimmingScissors) or 'trimming_scissors'
        local hasTool = not requireTool or (exports.ox_inventory:GetItemCount(tool) or 0) >= 1

        opts[#opts + 1] = {
            name     = 'w2f_plt_harvest_' .. plant.id,
            icon     = 'fa-solid fa-cannabis',
            label    = hasTool and 'Harvest Plant' or 'Harvest Plant (need scissors)',
            distance = 2.0,
            onSelect = function()
                if requireTool and not hasTool then
                    notify('MissingTrimmingScissors', 'error')
                    return
                end
                if InteractionBusy then return end
                InteractionBusy = true
                local ok = doProgress('Harvesting plant...', (Config.Planters.Progress and Config.Planters.Progress.HarvestPlant) or 6000, {
                    dict = 'amb@world_human_gardener_plant@male@base',
                    clip = 'base'
                })
                InteractionBusy = false
                if not ok then return end
                TriggerServerEvent('w2f-weed:server:harvestPlant', plant.id)
            end,
        }
    end

    return opts
end

local function attachPlantTargets(plant)
    if not plant or not plant.entity or plant.entity == 0 then return end
    local opts = buildPlantTargetOptions(plant)
    local names = {}
    for _, o in ipairs(opts) do names[#names + 1] = o.name end
    if DoesEntityExist(plant.entity) then
        exports.ox_target:addLocalEntity(plant.entity, opts)
        plant._entityTargets = names
    end
end

local function detachPlantTargets(plant)
    if not plant then return end
    if plant._entityTargets and plant.entity and plant.entity ~= 0 and DoesEntityExist(plant.entity) then
        pcall(function() exports.ox_target:removeLocalEntity(plant.entity, plant._entityTargets) end)
    end
    plant._entityTargets = nil
end

-- ─────────────────────────────────────────────
-- Spawn / despawn / replace planter prop
-- ─────────────────────────────────────────────

local function spawnPlanterEntity(planter)
    if not planter or not planter.coords then return end
    if planter.entity and planter.entity ~= 0 and DoesEntityExist(planter.entity) then return end

    local hash = loadModel(planter.model or Planters.GetEmptyProp(), true)
    if not hash then DebugP('planter model load failed', planter.model); return end

    local x, y, z = planter.coords.x + 0.0, planter.coords.y + 0.0, planter.coords.z + 0.0
    local entity = CreateObject(hash, x, y, z, false, true, false)
    if not entity or entity == 0 then SetModelAsNoLongerNeeded(hash); return end

    SetEntityCoords(entity, x, y, z, false, false, false, false)
    SetEntityHeading(entity, planter.heading or 0.0)
    SetEntityCollision(entity, true, true)
    PlaceObjectOnGroundProperly(entity)
    FreezeEntityPosition(entity, true)
    SetEntityInvincible(entity, true)
    SetEntityAsMissionEntity(entity, true, true)
    SetModelAsNoLongerNeeded(hash)

    planter.entity = entity
    Wait(150) -- let the entity settle for ox_target raycast
    if not DoesEntityExist(entity) then planter.entity = 0; return end

    attachPlanterTargets(planter)
    DebugP('spawned planter', planter.id, 'entity', entity, 'state', planter.state)
end

local function despawnPlanterEntity(planter)
    if not planter then return end
    detachPlanterTargets(planter)
    if planter.entity and planter.entity ~= 0 then
        safeDeleteEntity(planter.entity)
        planter.entity = 0
    end
end

local function replacePlanterEntity(planter)
    -- Used when state changes (empty -> filled)
    despawnPlanterEntity(planter)
    -- Spawn the new prop in a thread so we don't block any caller
    CreateThread(function()
        spawnPlanterEntity(planter)
    end)
end

-- ─────────────────────────────────────────────
-- Spawn / despawn / replace plant prop
-- ─────────────────────────────────────────────

local function spawnPlantEntity(plant)
    if not plant or not plant.planterId then return end
    local planter = PlanterCache[plant.planterId]
    if not planter or not planter.coords then return end

    local stageIdx, stage = Growth.GetStageForProgress(plant.progress)
    plant.stage = stageIdx
    if not stage or not stage.prop then return end

    local hash = loadModel(stage.prop, true)
    if not hash then DebugP('plant model load failed', stage.prop); return end

    -- World position from local offset on planter
    local lx, ly = plant.localX or 0.0, plant.localY or 0.0
    local soilArea = Planters.GetSoilArea()
    local lz = (soilArea.zOffset or 0.22) + (stage.zOffset or 0.0)
    local wx, wy, wz = Planters.LocalToWorld(planter, lx, ly, lz)

    local entity = CreateObject(hash, wx, wy, wz, false, true, false)
    if not entity or entity == 0 then SetModelAsNoLongerNeeded(hash); return end

    SetEntityCoords(entity, wx, wy, wz, false, false, false, false)
    SetEntityHeading(entity, ((planter.heading or 0.0) + (plant.rotation or 0.0)) % 360.0)
    SetEntityCollision(entity, false, true)
    FreezeEntityPosition(entity, true)
    SetEntityInvincible(entity, true)
    SetEntityAsMissionEntity(entity, true, true)
    SetModelAsNoLongerNeeded(hash)

    plant.entity = entity
    Wait(120)
    if not DoesEntityExist(entity) then plant.entity = 0; return end

    attachPlantTargets(plant)
    DebugP('spawned plant', plant.id, 'stage', stageIdx, 'in', plant.planterId)
end

local function despawnPlantEntity(plant)
    if not plant then return end
    detachPlantTargets(plant)
    if plant.entity and plant.entity ~= 0 then
        safeDeleteEntity(plant.entity)
        plant.entity = 0
    end
end

local function replacePlantStage(plant, newStageIdx)
    plant.stage = newStageIdx
    despawnPlantEntity(plant)
    CreateThread(function() spawnPlantEntity(plant) end)
end

-- ─────────────────────────────────────────────
-- Cache add / remove
-- ─────────────────────────────────────────────

local function cachePlanter(payload)
    if not payload or not payload.id then return end
    if PlanterCache[payload.id] then
        -- Update mutable fields
        PlanterCache[payload.id].state = payload.state or PlanterCache[payload.id].state
        PlanterCache[payload.id].model = payload.model or PlanterCache[payload.id].model
        PlanterCache[payload.id].coords = payload.coords or PlanterCache[payload.id].coords
        PlanterCache[payload.id].heading = payload.heading or PlanterCache[payload.id].heading
        PlanterCache[payload.id].owner = payload.owner or PlanterCache[payload.id].owner
        return PlanterCache[payload.id]
    end
    local p = {
        id        = payload.id,
        owner     = payload.owner,
        item      = payload.item,
        model     = payload.model or Planters.GetEmptyProp(),
        state     = payload.state or 'empty',
        coords    = payload.coords,
        heading   = payload.heading or 0.0,
        createdAt = payload.createdAt,
        entity    = 0,
    }
    PlanterCache[payload.id] = p
    return p
end

local function cachePlant(payload)
    if not payload or not payload.id then return end
    if PlantCache[payload.id] then
        PlantCache[payload.id].progress = payload.progress or PlantCache[payload.id].progress
        PlantCache[payload.id].stage    = payload.stage    or PlantCache[payload.id].stage
        PlantCache[payload.id].status   = payload.status   or PlantCache[payload.id].status
        return PlantCache[payload.id]
    end
    local p = {
        id        = payload.id,
        planterId = payload.planterId,
        owner     = payload.owner,
        strainId  = payload.strainId,
        seedItem  = payload.seedItem,
        localX    = payload.localX or 0.0,
        localY    = payload.localY or 0.0,
        localZ    = payload.localZ or 0.0,
        rotation  = payload.rotation or 0.0,
        progress  = payload.progress or 0.0,
        stage     = payload.stage or 1,
        status    = payload.status or 'growing',
        plantedAt = payload.plantedAt,
        entity    = 0,
    }
    PlantCache[payload.id] = p
    PlantsOfPlanter[payload.planterId] = PlantsOfPlanter[payload.planterId] or {}
    PlantsOfPlanter[payload.planterId][payload.id] = true
    return p
end

local function uncachePlanter(planterId)
    local planter = PlanterCache[planterId]
    if planter then
        despawnPlanterEntity(planter)
        PlanterCache[planterId] = nil
    end
    if PlantsOfPlanter[planterId] then
        for plantId in pairs(PlantsOfPlanter[planterId]) do
            local plant = PlantCache[plantId]
            if plant then
                despawnPlantEntity(plant)
                PlantCache[plantId] = nil
            end
        end
        PlantsOfPlanter[planterId] = nil
    end
end

local function uncachePlant(plantId, planterId)
    local plant = PlantCache[plantId]
    if plant then
        despawnPlantEntity(plant)
        PlantCache[plantId] = nil
    end
    if planterId and PlantsOfPlanter[planterId] then
        PlantsOfPlanter[planterId][plantId] = nil
    end
    if planterId and PlanterCache[planterId] then
        refreshPlanterTargets(planterId)
    end
end

local function clearAllSpawned()
    for id in pairs(PlanterCache) do uncachePlanter(id) end
    PlanterCache = {}
    PlantCache   = {}
    PlantsOfPlanter = {}
end

-- ─────────────────────────────────────────────
-- Plant placement preview (free placement inside soil)
-- ─────────────────────────────────────────────

local function endPlantPlacement(cancelled)
    PlantPlace.active    = false
    safeDeleteEntity(PlantPlace.entity)
    PlantPlace.entity    = 0
    PlantPlace.planterId = nil
    PlantPlace.seedItem  = nil
    PlantPlace.slot      = nil
    PlantPlace.localX    = 0.0
    PlantPlace.localY    = 0.0
    PlantPlace.rotation  = 0.0
    PlantPlace.valid     = true
    hideHints()
    if cancelled then notify('Cancelled', 'info') end
end

local function checkPlantValid(planter, lx, ly)
    if not Planters.IsInsideSoilArea(lx, ly) then return false end
    -- Spacing check against existing plants
    local existing = {}
    if PlantsOfPlanter[planter.id] then
        for plantId in pairs(PlantsOfPlanter[planter.id]) do
            local plant = PlantCache[plantId]
            if plant then existing[#existing + 1] = plant end
        end
    end
    if Planters.IsTooCloseToExistingPlant(lx, ly, existing) then return false end
    return true
end

local function startPlantPlacementPreview(planterId, seedItem, slot, stageIdx, stageProp)
    if PlantPlace.active then return end
    refreshOutlineColors()

    local planter = PlanterCache[planterId]
    if not planter then return end

    local hash = loadModel(stageProp, true)
    if not hash then notify('ServerRejected', 'error'); return end

    local soilArea = Planters.GetSoilArea()
    local lz = (soilArea.zOffset or 0.22)
    local wx, wy, wz = Planters.LocalToWorld(planter, 0.0, 0.0, lz)

    local entity = CreateObject(hash, wx, wy, wz, false, false, false)
    if not entity or entity == 0 then SetModelAsNoLongerNeeded(hash); return end

    SetEntityCollision(entity, false, false)
    SetEntityAlpha(entity, Config.Planters.Preview.Alpha or 170, false)
    FreezeEntityPosition(entity, true)
    if Config.Planters.Preview.UseOutline then
        SetEntityDrawOutline(entity, true)
        SetEntityDrawOutlineColor(OUTLINE_VALID[1], OUTLINE_VALID[2], OUTLINE_VALID[3], 220)
    end
    SetModelAsNoLongerNeeded(hash)

    PlantPlace.active    = true
    PlantPlace.entity    = entity
    PlantPlace.planterId = planterId
    PlantPlace.seedItem  = seedItem
    PlantPlace.slot      = slot
    PlantPlace.localX    = Config.Planters.Preview.StartLocalX or 0.0
    PlantPlace.localY    = Config.Planters.Preview.StartLocalY or 0.0
    PlantPlace.rotation  = 0.0
    PlantPlace.valid     = true

    showHints('[WASD] Move  •  [E] Place  •  [Q / →] Rotate  •  [BACKSPACE] Cancel  —  Plant Seed')

    local moveSpeed = Config.Planters.Preview.MoveSpeed or 0.015
    local rotSpeed  = 4.0
    local confirm   = Config.Planters.Preview.ConfirmKey or 38
    local cancel    = Config.Planters.Preview.CancelKey or 177
    local rotL      = Config.Planters.Preview.RotateLeftKey or 44
    local rotR      = Config.Planters.Preview.RotateRightKey or 175

    CreateThread(function()
        while PlantPlace.active and PlantPlace.entity ~= 0 and DoesEntityExist(PlantPlace.entity) do
            DisableControlAction(0, confirm, true)
            DisableControlAction(0, cancel,  true)
            DisableControlAction(0, rotL,    true)
            DisableControlAction(0, rotR,    true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 24, true)

            -- WASD to nudge local offset (32=W,33=S,34=A,35=D)
            local lx, ly = PlantPlace.localX, PlantPlace.localY
            if IsControlPressed(0, 32) then ly = ly + moveSpeed end -- W: forward in local Y
            if IsControlPressed(0, 33) then ly = ly - moveSpeed end -- S
            if IsControlPressed(0, 34) then lx = lx - moveSpeed end -- A
            if IsControlPressed(0, 35) then lx = lx + moveSpeed end -- D

            -- Clamp soft-bounds to soil + a tiny slop
            lx, ly = Planters.ClampToSoilArea(lx, ly)
            PlantPlace.localX, PlantPlace.localY = lx, ly

            -- Rotation
            if IsDisabledControlPressed(0, rotL) then
                PlantPlace.rotation = (PlantPlace.rotation + rotSpeed) % 360
            elseif IsDisabledControlPressed(0, rotR) then
                PlantPlace.rotation = (PlantPlace.rotation - rotSpeed + 360) % 360
            end

            local p = PlanterCache[PlantPlace.planterId]
            if not p then endPlantPlacement(true); break end

            local soilArea2 = Planters.GetSoilArea()
            local lz2 = soilArea2.zOffset or 0.22
            local wx2, wy2, wz2 = Planters.LocalToWorld(p, lx, ly, lz2)

            SetEntityCoordsNoOffset(PlantPlace.entity, wx2, wy2, wz2, false, false, false)
            SetEntityHeading(PlantPlace.entity, ((p.heading or 0.0) + PlantPlace.rotation) % 360.0)

            local valid = checkPlantValid(p, lx, ly)
            if valid ~= PlantPlace.valid then
                PlantPlace.valid = valid
                if Config.Planters.Preview.UseOutline then
                    local c = valid and OUTLINE_VALID or OUTLINE_INVALID
                    SetEntityDrawOutlineColor(c[1], c[2], c[3], 220)
                end
            end

            if IsDisabledControlJustReleased(0, cancel) then
                endPlantPlacement(true); break
            end

            if IsDisabledControlJustReleased(0, confirm) then
                if not PlantPlace.valid then
                    if not Planters.IsInsideSoilArea(lx, ly) then
                        notify('OutsideSoil', 'error')
                    else
                        notify('TooClose', 'error')
                    end
                else
                    local payload = {
                        planterId = PlantPlace.planterId,
                        seedItem  = PlantPlace.seedItem,
                        slot      = PlantPlace.slot,
                        localX    = PlantPlace.localX,
                        localY    = PlantPlace.localY,
                        rotation  = PlantPlace.rotation,
                    }
                    endPlantPlacement(false)
                    if InteractionBusy then break end
                    InteractionBusy = true
                    local ok = doProgress('Planting seed...', (Config.Planters.Progress and Config.Planters.Progress.PlantSeed) or 5000, {
                        dict = 'amb@world_human_gardener_plant@male@base',
                        clip = 'base'
                    })
                    InteractionBusy = false
                    if not ok then break end
                    TriggerServerEvent('w2f-weed:server:plantSeedInPlanter', payload)
                    break
                end
            end

            Wait(0)
        end

        if PlantPlace.active then endPlantPlacement(true) end
    end)
end

-- Globally-callable function (used from ox_target onSelect closure)
function StartPlantPlacement(planterId)
    if not planterId then return end
    if PlantPlace.active then
        endPlantPlacement(true)
        Wait(50)
    end

    local planter = PlanterCache[planterId]
    if not planter then notify('ServerRejected', 'error'); return end
    if planter.state ~= 'filled' then notify('NotFilled', 'error'); return end

    -- Capacity gate: client-side hint (server is still authoritative)
    local count = 0
    if PlantsOfPlanter[planterId] then
        for _ in pairs(PlantsOfPlanter[planterId]) do count = count + 1 end
    end
    if count >= Planters.GetMaxPlantsPerPlanter() then
        notify('MaxPlantsReached', 'error'); return
    end

    -- Ask server for the seed list (so we always reflect server-trust truth)
    local seeds = lib.callback.await('w2f-weed:server:getAvailableSeeds', false)
    if type(seeds) ~= 'table' or #seeds == 0 then
        notify('NoSeeds', 'error'); return
    end

    local options = {}
    for _, seed in ipairs(seeds) do
        options[#options + 1] = {
            title       = seed.label or seed.strainId,
            description = ('You have %dx  •  %s'):format(seed.count or 1, seed.description or ''),
            icon        = 'seedling',
            iconColor   = '#56f39a',
            onSelect    = function()
                -- Find slot via inventory (just take any matching slot)
                local items = exports.ox_inventory:GetPlayerItems()
                local slot
                if items then
                    for _, it in pairs(items) do
                        if it.name == seed.seedItem and (it.count or 0) >= 1 then
                            slot = it.slot; break
                        end
                    end
                end
                if not slot then notify('NoSeeds', 'error'); return end

                -- Choose stage 1 prop for the preview ghost
                local _, stage = Growth.GetStageForProgress(0)
                if not stage or not stage.prop then notify('ServerRejected', 'error'); return end

                startPlantPlacementPreview(planterId, seed.seedItem, slot, 1, stage.prop)
            end,
        }
    end

    lib.registerContext({
        id      = 'w2f_planter_seeds_' .. planterId,
        title   = 'Plant Seed',
        options = options,
    })
    lib.showContext('w2f_planter_seeds_' .. planterId)
end

-- ─────────────────────────────────────────────
-- Inspect actions (purely informational)
-- ─────────────────────────────────────────────

function InspectPlanter(planterId)
    local p = PlanterCache[planterId]
    if not p then return end
    local count = 0
    if PlantsOfPlanter[planterId] then
        for _ in pairs(PlantsOfPlanter[planterId]) do count = count + 1 end
    end
    local maxN = Planters.GetMaxPlantsPerPlanter()
    lib.notify({
        title       = 'Planter',
        description = ('State: %s\nPlants: %d / %d'):format(p.state or 'empty', count, maxN),
        type        = 'info',
        position    = 'top',
        duration    = 4500,
    })
end

function InspectPlant(plantId)
    local plant = PlantCache[plantId]
    if not plant then return end
    local stageIdx, stage = Growth.GetStageForProgress(plant.progress)
    local strain = Strains.GetById(plant.strainId)
    local label = (strain and strain.label) or plant.strainId or '?'
    lib.notify({
        title       = 'Plant — ' .. label,
        description = ('Stage: %s (%d)\nProgress: %d%%\nStatus: %s'):format(
            (stage and stage.label) or '?', stageIdx, math.floor(plant.progress or 0), plant.status or '?'
        ),
        type        = 'info',
        position    = 'top',
        duration    = 4500,
    })
end

-- ─────────────────────────────────────────────
-- Server -> Client sync handlers
-- ─────────────────────────────────────────────

RegisterNetEvent('w2f-weed:client:createPlanter', function(payload)
    if type(payload) ~= 'table' or not payload.id then return end
    local p = cachePlanter(payload)
    CreateThread(function() spawnPlanterEntity(p) end)
end)

RegisterNetEvent('w2f-weed:client:updatePlanterState', function(planterId, state, model)
    local p = PlanterCache[planterId]
    if not p then return end
    p.state = state or p.state
    p.model = model or p.model
    replacePlanterEntity(p)
end)

RegisterNetEvent('w2f-weed:client:removePlanter', function(planterId)
    if type(planterId) ~= 'string' then return end
    uncachePlanter(planterId)
end)

RegisterNetEvent('w2f-weed:client:createPlant', function(payload)
    if type(payload) ~= 'table' or not payload.id then return end
    local plant = cachePlant(payload)
    CreateThread(function()
        spawnPlantEntity(plant)
        if plant.planterId then
            refreshPlanterTargets(plant.planterId)
        end
    end)
end)

RegisterNetEvent('w2f-weed:client:updatePlantStage', function(plantId, progress, stageIdx)
    local plant = PlantCache[plantId]
    if not plant then return end
    plant.progress = progress or plant.progress
    local prevStage = plant.stage
    plant.stage = stageIdx or plant.stage
    local pid = plant.planterId
    if plant.stage ~= prevStage then
        replacePlantStage(plant, plant.stage)
        CreateThread(function()
            Wait(400)
            if pid then refreshPlanterTargets(pid) end
        end)
    else
        -- Refresh harvest target if newly harvestable
        detachPlantTargets(plant)
        attachPlantTargets(plant)
        if pid then refreshPlanterTargets(pid) end
    end
end)

RegisterNetEvent('w2f-weed:client:removePlant', function(plantId, planterId)
    if type(plantId) ~= 'string' then return end
    uncachePlant(plantId, planterId)
end)

RegisterNetEvent('w2f-weed:client:syncPlanters', function(payload)
    if type(payload) ~= 'table' then return end

    local seenPlanters, seenPlants = {}, {}

    if type(payload.planters) == 'table' then
        for _, plr in ipairs(payload.planters) do
            if plr and plr.id then
                seenPlanters[plr.id] = true
                if not PlanterCache[plr.id] then
                    local p = cachePlanter(plr)
                    CreateThread(function() spawnPlanterEntity(p) end)
                else
                    -- update mutable fields if changed
                    cachePlanter(plr)
                end
            end
        end
    end

    if type(payload.plants) == 'table' then
        for _, plant in ipairs(payload.plants) do
            if plant and plant.id then
                seenPlants[plant.id] = true
                if not PlantCache[plant.id] then
                    local p = cachePlant(plant)
                    CreateThread(function() spawnPlantEntity(p) end)
                else
                    cachePlant(plant)
                end
            end
        end
    end

    -- Despawn orphans
    for id in pairs(PlanterCache) do
        if not seenPlanters[id] then uncachePlanter(id) end
    end
    for id, plant in pairs(PlantCache) do
        if not seenPlants[id] then uncachePlant(id, plant.planterId) end
    end
end)

-- ─────────────────────────────────────────────
-- Lifecycle
-- ─────────────────────────────────────────────

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(250) end
    Wait(1500)

    if Planters.IsEnabled() and Config.Planters.Persistence.SyncOnPlayerJoin then
        TriggerServerEvent('w2f-weed:server:requestPlanterSync')
        DebugP('requested initial planter sync')
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if PlantPlace.active   then endPlantPlacement(true)   end
    if PlanterPlace.active then endPlanterPlacement(true) end
    clearAllSpawned()
end)

-- ─────────────────────────────────────────────
-- Debug commands
-- ─────────────────────────────────────────────

CreateThread(function()
    if not Planters.IsDebug() then return end

    RegisterCommand('weed_planter_sync', function()
        TriggerServerEvent('w2f-weed:server:requestPlanterSync')
    end, false)

    RegisterCommand('weed_planter_count_local', function()
        local pn, ln = 0, 0
        for _ in pairs(PlanterCache) do pn = pn + 1 end
        for _ in pairs(PlantCache)   do ln = ln + 1 end
        print(('[w2f-weed][planters] cached: planters=%d plants=%d'):format(pn, ln))
    end, false)
end)
