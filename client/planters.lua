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
    ped      = 0,
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

--- Build a styled placement hint string (HTML/markdown-ish) for ox_lib's TextUI.
---@param title string  e.g. 'Place Planter'
---@param lines string[] each line printed under the title (keys + actions)
local function buildPlacementHint(title, lines)
    local out = { ('**%s**'):format(title) }
    for i = 1, #lines do out[#out + 1] = lines[i] end
    return table.concat(out, '  \n')
end

local function showHints(text, icon)
    if not lib or not lib.showTextUI then return end
    lib.showTextUI(text, {
        position  = 'top-center',
        icon      = icon or 'seedling',
        iconColor = '#7adb7a',
        style = {
            borderRadius = '6px',
            backgroundColor = 'rgba(20, 25, 32, 0.85)',
            color          = '#f1f5f9',
        },
    })
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
-- Action animations
--
-- Wraps doProgress so the player visibly holds the right tool while gardening:
-- a watering can while watering, a fertilizer bottle while feeding, etc. The
-- prop is attached to the right hand for the duration of the progress bar and
-- removed afterwards. `prop` is optional — pass nil for a plain animation.
-- ─────────────────────────────────────────────

local HAND_BONE = 28422 -- SKEL_R_Hand

local function attachHandProp(model, pos, rot)
    local hash = loadModel(model)
    if not hash then return nil end
    local ped = cache and cache.ped or PlayerPedId()
    local coords = GetEntityCoords(ped)
    local obj = CreateObject(hash, coords.x, coords.y, coords.z, true, true, false)
    if not obj or obj == 0 then SetModelAsNoLongerNeeded(hash); return nil end
    AttachEntityToEntity(obj, ped, GetPedBoneIndex(ped, HAND_BONE),
        pos.x, pos.y, pos.z, rot.x, rot.y, rot.z,
        true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(hash)
    return obj
end

--- doProgress + an optional tool prop in the player's hand.
---@param label string
---@param duration integer
---@param anim table {dict=, clip=}
---@param tool? table {model=, pos=vec3, rot=vec3}
local function doActionProgress(label, duration, anim, tool)
    local prop
    if tool and tool.model then
        prop = attachHandProp(tool.model, tool.pos or vec3(0.0, 0.0, 0.0), tool.rot or vec3(0.0, 0.0, 0.0))
    end
    local ok = doProgress(label, duration, anim)
    if prop and DoesEntityExist(prop) then
        DeleteEntity(prop)
    end
    return ok
end

-- Tool prop presets (hand-bone offsets are approximate but read correctly).
local WATERING_CAN_TOOL = { model = 'prop_wateringcan', pos = vec3(0.12, 0.02, -0.02), rot = vec3(-90.0, 0.0, 0.0) }
local FERTILIZER_TOOL   = { model = 'prop_cs_fertilizer', pos = vec3(0.10, 0.0, -0.04), rot = vec3(0.0, 0.0, 0.0) }

-- ─────────────────────────────────────────────
-- Planter box placement preview (empty planter / plant_pot from inventory)
-- Order: ground snap → validation → cancel/confirm → main loop → NetEvent
-- ─────────────────────────────────────────────

local function getGroundCoords(x, y, z)
    return W2FWeed.PlacementCursor.SnapToGround(x, y, z, Config.Planters.PlanterPreview.RequireGround)
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
    if PlanterPlace.ped and PlanterPlace.ped ~= 0 and DoesEntityExist(PlanterPlace.ped) then
        FreezeEntityPosition(PlanterPlace.ped, false)
    end
    safeDeleteEntity(PlanterPlace.entity)
    PlanterPlace.entity  = 0
    PlanterPlace.ped     = 0
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
    local initialSnapped = getGroundCoords(pCoords.x, pCoords.y, pCoords.z)
    local entity  = CreateObjectNoOffset(hash, initialSnapped.x, initialSnapped.y, initialSnapped.z, false, false, false)
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
    PlanterPlace.ped     = ped
    PlanterPlace.item    = itemName
    PlanterPlace.slot    = slot
    PlanterPlace.heading = GetEntityHeading(ped)
    PlanterPlace.valid   = true
    -- NOTE: the player is intentionally left free to walk around while aiming the
    -- planter with the cursor (same as seed placement). Freezing here was the
    -- cause of the "can't move while placing the planter box" bug.

    showHints(buildPlacementHint(Locale('planter_hint_title'), {
        Locale('hint_aim_planter'),
        Locale('hint_confirm_place'),
        Locale('hint_rotate'),
        Locale('hint_cancel'),
    }), 'fa-solid fa-fill-drip')

    local rotSpeed = Config.Planters.PlanterPreview.RotationSpeed or 3.0
    local rayDist = (Config.Planters.PlanterPreview and Config.Planters.PlanterPreview.CursorRayDistance) or 8.0
    local smoothing = Config.Planters.PlanterPreview.Smoothing or 0.35
    local previewCoords = vec3(initialSnapped.x, initialSnapped.y, initialSnapped.z)
    local targetCoords = previewCoords

    CreateThread(function()
        while PlanterPlace.active and PlanterPlace.entity ~= 0 and DoesEntityExist(PlanterPlace.entity) do
            DisableControlAction(0, 38, true)  -- E
            DisableControlAction(0, 177, true) -- BACKSPACE
            DisableControlAction(0, 44, true)  -- Q
            DisableControlAction(0, 175, true) -- right arrow
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 24, true)

            local hit, hitCoords = W2FWeed.PlacementCursor.FromCamera(rayDist, PlanterPlace.entity)
            if hit and hitCoords then
                local snapped = getGroundCoords(hitCoords.x, hitCoords.y, hitCoords.z)
                targetCoords = vec3(snapped.x, snapped.y, snapped.z)
            end

            previewCoords = vec3(
                previewCoords.x + ((targetCoords.x - previewCoords.x) * smoothing),
                previewCoords.y + ((targetCoords.y - previewCoords.y) * smoothing),
                previewCoords.z + ((targetCoords.z - previewCoords.z) * smoothing)
            )

            SetEntityCoordsNoOffset(PlanterPlace.entity, previewCoords.x, previewCoords.y, previewCoords.z, false, false, false)
            SetEntityHeading(PlanterPlace.entity, PlanterPlace.heading)

            local valid = checkPlanterValid(previewCoords)
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
                    local cx, cy, cz = previewCoords.x, previewCoords.y, previewCoords.z

                    endPlanterPlacement(false)
                    if InteractionBusy then break end
                    InteractionBusy = true
                    local ok = doProgress(Locale('progress_place_planter'), (Config.Planters.Progress and Config.Planters.Progress.PlacePlanter) or 3000, {
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

local function playerHasTrimmingScissors()
    local harvestCfg = Config.Planters.Harvest
    local requireTool = not harvestCfg or harvestCfg.RequireTrimmingScissors ~= false
    if not requireTool then return true end
    local tool = (Config.Planters.Items and Config.Planters.Items.TrimmingScissors) or 'trimming_scissors'
    return (exports.ox_inventory:GetItemCount(tool) or 0) >= 1
end

local function playerHasWateringCan()
    return (exports.ox_inventory:GetItemCount(Planters.GetWateringCanItem()) or 0) >= 1
end

local function playerHasSoilBag()
    return (exports.ox_inventory:GetItemCount(Planters.GetSoilItem()) or 0) >= 1
end

local function playerHasFertilizer(itemName)
    if not itemName then return false end
    return (exports.ox_inventory:GetItemCount(itemName) or 0) >= 1
end

--- True if the player carries at least one of any plantable seed item.
local function playerHasAnySeed()
    for _, seedItem in ipairs(Strains.GetSeedItemList()) do
        if (exports.ox_inventory:GetItemCount(seedItem) or 0) >= 1 then
            return true
        end
    end
    return false
end

--- Total plants (alive OR dead) tracked for a planter.
local function totalPlantsCount(planterId)
    if not planterId or not PlantsOfPlanter[planterId] then return 0 end
    local n = 0
    for pid in pairs(PlantsOfPlanter[planterId]) do
        if PlantCache[pid] then n = n + 1 end
    end
    return n
end

--- Count plants in this planter that are currently alive and still growing.
local function livingPlantsCount(planterId)
    if not planterId or not PlantsOfPlanter[planterId] then return 0 end
    local n = 0
    for pid in pairs(PlantsOfPlanter[planterId]) do
        local pl = PlantCache[pid]
        if pl and pl.status ~= 'dead' and (pl.health or 100) > 0 then
            n = n + 1
        end
    end
    return n
end

local function buildPlanterTargetOptions(planter)
    local opts = {}
    local soilState = planter.state == 'filled'

    -- Pickup — only when the planter is empty of plants (you must clear it first).
    opts[#opts + 1] = {
        name     = 'w2f_pln_pickup_' .. planter.id,
        icon     = 'fa-solid fa-hand',
        label    = Locale('target_planter_pickup'),
        distance = 2.5,
        canInteract = function()
            return totalPlantsCount(planter.id) == 0
        end,
        onSelect = function()
            if InteractionBusy then return end
            InteractionBusy = true
            local ok = doProgress(Locale('progress_pickup_planter'), (Config.Planters.Progress and Config.Planters.Progress.PickupPlanter) or 3000, {
                dict = 'pickup_object',
                clip = 'pickup_low'
            })
            InteractionBusy = false
            if not ok then return end
            TriggerServerEvent('w2f-weed:server:pickupPlanter', planter.id)
        end,
    }

    if not soilState then
        local needed = planter.soilNeeded or Planters.GetSoilBagsRequired()
        local current = planter.soilCount or 0
        opts[#opts + 1] = {
            name     = 'w2f_pln_addsoil_' .. planter.id,
            icon     = 'fa-solid fa-fill-drip',
            label    = Locale('target_planter_addsoil', current, needed),
            distance = 2.5,
            -- Only offered while the player actually has a soil bag to add.
            canInteract = function()
                return playerHasSoilBag()
            end,
            onSelect = function()
                if not playerHasSoilBag() then
                    notify('NoSoilBag', 'error'); return
                end
                if InteractionBusy then return end
                InteractionBusy = true
                local ok = doProgress(Locale('progress_add_soil'), (Config.Planters.Progress and Config.Planters.Progress.AddSoil) or 4500, {
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
            label    = Locale('target_planter_plant'),
            distance = 2.5,
            -- Only offered when the player is carrying seeds and there is room.
            canInteract = function()
                if not playerHasAnySeed() then return false end
                return totalPlantsCount(planter.id) < Planters.GetMaxPlantsPerPlanter()
            end,
            onSelect = function()
                StartPlantPlacement(planter.id)
            end,
        }

        opts[#opts + 1] = {
            name     = 'w2f_pln_inspect_' .. planter.id,
            icon     = 'fa-solid fa-magnifying-glass',
            label    = Locale('target_planter_inspect'),
            distance = 2.5,
            onSelect = function()
                InspectPlanter(planter.id)
            end,
        }

        opts[#opts + 1] = {
            name     = 'w2f_pln_water_' .. planter.id,
            icon     = 'fa-solid fa-droplet',
            label    = Locale('target_planter_water'),
            distance = 2.5,
            -- Needs a living plant AND a watering can in the inventory.
            canInteract = function()
                return livingPlantsCount(planter.id) >= 1 and playerHasWateringCan()
            end,
            onSelect = function()
                if not playerHasWateringCan() then
                    notify('MissingWateringCan', 'error'); return
                end
                if livingPlantsCount(planter.id) < 1 then
                    notify('NoPlantsToWater', 'error'); return
                end
                if InteractionBusy then return end
                InteractionBusy = true
                local ok = doActionProgress(Locale('progress_water_plants'), (Config.Planters.Progress and Config.Planters.Progress.WaterPlants) or 3500, {
                    dict = 'amb@world_human_gardener_plant@male@base',
                    clip = 'base'
                }, WATERING_CAN_TOOL)
                InteractionBusy = false
                if not ok then return end
                TriggerServerEvent('w2f-weed:server:waterPlanter', planter.id)
            end,
        }

        opts[#opts + 1] = {
            name     = 'w2f_pln_harvest_ready_' .. planter.id,
            icon     = 'fa-solid fa-scissors',
            label    = Locale('target_planter_harvest'),
            distance = 2.5,
            -- Needs a mature plant AND trimming scissors (when required).
            canInteract = function()
                if harvestablePlantsCount(planter.id) < 1 then return false end
                local harvestCfg = Config.Planters.Harvest
                local requireTool = not harvestCfg or harvestCfg.RequireTrimmingScissors ~= false
                if requireTool and not playerHasTrimmingScissors() then return false end
                return true
            end,
            onSelect = function()
                if harvestablePlantsCount(planter.id) < 1 then return end
                local harvestCfg = Config.Planters.Harvest
                local requireTool = not harvestCfg or harvestCfg.RequireTrimmingScissors ~= false
                if requireTool and not playerHasTrimmingScissors() then
                    notify('MissingTrimmingScissors', 'error')
                    return
                end
                if InteractionBusy then return end
                InteractionBusy = true
                local ok = doProgress(Locale('progress_harvest_planter'), (Config.Planters.Progress and Config.Planters.Progress.HarvestReadyPlants) or 8000, {
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

    -- Single sphere zone only. Custom prop collision is unreliable for entity
    -- raycasts, and registering BOTH an entity target and an overlapping zone
    -- produced duplicate menu entries when the raycast hit the prop.
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

--- Short upkeep word baked into target labels so a plant's needs are visible
--- without opening the inspect menu. Targets are re-attached when the status
--- category flips (see updatePlantLifecycle), keeping this fresh.
local function plantStatusWord(plant)
    local kind = Planters.PlantHealthStatus(plant)
    if kind == 'ready'    then return Locale('plant_word_ready')    end
    if kind == 'dead'     then return Locale('plant_word_dead')     end
    if kind == 'wilting'  then return Locale('plant_word_wilting')  end
    if kind == 'starving' then return Locale('plant_word_starving') end
    if kind == 'thirsty'  then return Locale('plant_word_thirsty')  end
    return Locale('plant_word_healthy')
end

local function buildPlantTargetOptions(plant)
    local opts = {}
    opts[#opts + 1] = {
        name     = 'w2f_plt_inspect_' .. plant.id,
        icon     = 'fa-solid fa-magnifying-glass',
        label    = Locale('target_plant_inspect', plantStatusWord(plant)),
        distance = 2.0,
        onSelect = function() InspectPlant(plant.id) end,
    }

    local isDead = plant.status == 'dead' or (plant.health or 100) <= 0

    if isDead then
        opts[#opts + 1] = {
            name     = 'w2f_plt_remove_' .. plant.id,
            icon     = 'fa-solid fa-trash-can',
            label    = Locale('target_plant_remove'),
            distance = 2.0,
            onSelect = function()
                if InteractionBusy then return end
                InteractionBusy = true
                local ok = doProgress(Locale('progress_clear_planter'), 3000, {
                    dict = 'amb@world_human_gardener_plant@male@base',
                    clip = 'base'
                })
                InteractionBusy = false
                if not ok then return end
                TriggerServerEvent('w2f-weed:server:removeDeadPlant', plant.id)
            end,
        }
        return opts
    end

    local _, stage = Growth.GetStageForProgress(plant.progress)
    if not (stage and stage.harvestable) then
        local fertilizers = (Config.Growth and Config.Growth.Fertilizers) or {}
        for itemName, fert in pairs(fertilizers) do
            opts[#opts + 1] = {
                name     = ('w2f_plt_fertilize_%s_%s'):format(itemName, plant.id),
                icon     = 'fa-solid fa-bottle-droplet',
                label    = Locale('target_plant_fertilize', fert.label or itemName, math.floor(plant.nutrients or 100)),
                distance = 2.0,
                -- Only show a fertilizer option for fertilizers the player carries.
                canInteract = function()
                    return playerHasFertilizer(itemName)
                end,
                onSelect = function()
                    if not playerHasFertilizer(itemName) then
                        notify('MissingFertilizer', 'error'); return
                    end
                    if InteractionBusy then return end
                    InteractionBusy = true
                    local ok = doActionProgress(Locale('progress_apply_fertilizer', fert.label or itemName), (Config.Planters.Progress and Config.Planters.Progress.ApplyFertilizer) or 3500, {
                        dict = 'amb@world_human_gardener_plant@male@base',
                        clip = 'base'
                    }, FERTILIZER_TOOL)
                    InteractionBusy = false
                    if not ok then return end
                    TriggerServerEvent('w2f-weed:server:applyFertilizerToPlant', plant.id, itemName)
                end,
            }
        end

        opts[#opts + 1] = {
            name     = 'w2f_plt_water_' .. plant.id,
            icon     = 'fa-solid fa-droplet',
            label    = Locale('target_plant_water', math.floor(plant.water or 100)),
            distance = 2.0,
            -- Only when a watering can is carried.
            canInteract = function()
                return playerHasWateringCan()
            end,
            onSelect = function()
                if not playerHasWateringCan() then
                    notify('MissingWateringCan', 'error'); return
                end
                if InteractionBusy then return end
                InteractionBusy = true
                local ok = doActionProgress(Locale('progress_water_plant'), (Config.Planters.Progress and Config.Planters.Progress.WaterPlants) or 3500, {
                    dict = 'amb@world_human_gardener_plant@male@base',
                    clip = 'base'
                }, WATERING_CAN_TOOL)
                InteractionBusy = false
                if not ok then return end
                TriggerServerEvent('w2f-weed:server:waterPlanter', plant.planterId)
            end,
        }
    end

    if stage and stage.harvestable then
        opts[#opts + 1] = {
            name     = 'w2f_plt_harvest_' .. plant.id,
            icon     = 'fa-solid fa-scissors',
            label    = Locale('target_plant_harvest'),
            distance = 2.0,
            -- Only when trimming scissors are carried (when required).
            canInteract = function()
                local harvestCfg = Config.Planters.Harvest
                local requireTool = not harvestCfg or harvestCfg.RequireTrimmingScissors ~= false
                if requireTool and not playerHasTrimmingScissors() then return false end
                return true
            end,
            onSelect = function()
                local harvestCfg = Config.Planters.Harvest
                local requireTool = not harvestCfg or harvestCfg.RequireTrimmingScissors ~= false
                if requireTool and not playerHasTrimmingScissors() then
                    notify('MissingTrimmingScissors', 'error')
                    return
                end
                if InteractionBusy then return end
                InteractionBusy = true
                local ok = doProgress(Locale('progress_harvest_plant'), (Config.Planters.Progress and Config.Planters.Progress.HarvestPlant) or 6000, {
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
    if not plant then return end
    local opts = buildPlantTargetOptions(plant)

    -- Single sphere zone at the plant position. Small plant props frequently miss
    -- entity raycasts, and registering BOTH an entity target and an overlapping
    -- zone produced duplicate menu entries.
    local planter = plant.planterId and PlanterCache[plant.planterId]
    if planter and planter.coords then
        local lx, ly = plant.localX or 0.0, plant.localY or 0.0
        local soilArea = Planters.GetSoilArea()
        local lz = (soilArea.zOffset or 0.22)
        local wx, wy, wz = Planters.LocalToWorld(planter, lx, ly, lz)
        local zoneId = exports.ox_target:addSphereZone({
            name    = 'w2f_plt_zone_' .. plant.id,
            coords  = vec3(wx, wy, wz + 0.35),
            radius  = 0.65,
            debug   = false,
            options = opts,
        })
        plant._zoneId = zoneId
    end
end

local function detachPlantTargets(plant)
    if not plant then return end
    if plant._zoneId then
        pcall(function() exports.ox_target:removeZone(plant._zoneId, true) end)
        plant._zoneId = nil
    end
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
        local existing = PlanterCache[payload.id]
        existing.state       = payload.state or existing.state
        existing.model       = payload.model or existing.model
        existing.coords      = payload.coords or existing.coords
        existing.heading     = payload.heading or existing.heading
        existing.owner       = payload.owner or existing.owner
        existing.soilCount   = payload.soilCount or existing.soilCount or 0
        existing.soilNeeded  = payload.soilNeeded or existing.soilNeeded or Planters.GetSoilBagsRequired()
        return existing
    end
    local p = {
        id          = payload.id,
        owner       = payload.owner,
        item        = payload.item,
        model       = payload.model or Planters.GetEmptyProp(),
        state       = payload.state or 'empty',
        coords      = payload.coords,
        heading     = payload.heading or 0.0,
        createdAt   = payload.createdAt,
        soilCount   = payload.soilCount or 0,
        soilNeeded  = payload.soilNeeded or Planters.GetSoilBagsRequired(),
        entity      = 0,
    }
    PlanterCache[payload.id] = p
    return p
end

local function cachePlant(payload)
    if not payload or not payload.id then return end
    if PlantCache[payload.id] then
        local existing = PlantCache[payload.id]
        existing.progress  = payload.progress  or existing.progress
        existing.stage     = payload.stage     or existing.stage
        existing.status    = payload.status    or existing.status
        existing.water     = payload.water     or existing.water
        existing.nutrients = payload.nutrients or existing.nutrients
        existing.health    = payload.health    or existing.health
        return existing
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
        water     = payload.water     or 100,
        nutrients = payload.nutrients or 100,
        health    = payload.health    or 100,
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

    showHints(buildPlacementHint(Locale('plant_hint_title'), {
        Locale('hint_aim_soil'),
        Locale('hint_confirm_plant'),
        Locale('hint_rotate'),
        Locale('hint_cancel'),
    }), 'fa-solid fa-seedling')

    local rotSpeed  = 4.0
    local rayDist   = (Config.Planters.Preview and Config.Planters.Preview.CursorRayDistance) or 8.0
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

            local lx, ly = PlantPlace.localX, PlantPlace.localY
            local hit, hitCoords = W2FWeed.PlacementCursor.FromCamera(rayDist, PlantPlace.entity)
            if hit and hitCoords then
                local localX, localY = Planters.WorldToLocal(planter, hitCoords)
                lx, ly = Planters.ClampToSoilArea(localX, localY)
                PlantPlace.localX, PlantPlace.localY = lx, ly
            end

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
                    local ok = doProgress(Locale('progress_plant_seed'), (Config.Planters.Progress and Config.Planters.Progress.PlantSeed) or 5000, {
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

--- Pretty status label + colour scheme for the inspect menu.
local function statusDisplay(plant)
    local kind = Planters.PlantHealthStatus(plant)
    if kind == 'ready'    then return 'Ready to harvest', 'green'  end
    if kind == 'dead'     then return 'Dead',             'red'    end
    if kind == 'wilting'  then return 'Wilting',          'red'    end
    if kind == 'starving' then return 'Starving',         'red'    end
    if kind == 'thirsty'  then return 'Thirsty',          'yellow' end
    return 'Growing healthy', 'green'
end

local function progressColour(value)
    value = value or 0
    if value <= 20 then return 'red'    end
    if value <= 50 then return 'yellow' end
    return 'green'
end

function InspectPlanter(planterId)
    local p = PlanterCache[planterId]
    if not p then return end

    local count = 0
    if PlantsOfPlanter[planterId] then
        for _ in pairs(PlantsOfPlanter[planterId]) do count = count + 1 end
    end
    local maxN = Planters.GetMaxPlantsPerPlanter()

    local opts = {
        {
            title       = 'Soil',
            description = (p.state == 'filled')
                and ('Filled — ready for seeds (%d / %d bags used)'):format(p.soilCount or 0, p.soilNeeded or Planters.GetSoilBagsRequired())
                or  ('Needs more soil (%d / %d bags)'):format(p.soilCount or 0, p.soilNeeded or Planters.GetSoilBagsRequired()),
            icon        = 'fa-solid fa-fill-drip',
            readOnly    = true,
            progress    = math.floor(((p.soilCount or 0) / math.max(1, p.soilNeeded or 1)) * 100),
            colorScheme = (p.state == 'filled') and 'green' or 'yellow',
        },
        {
            title       = ('Plants: %d / %d'):format(count, maxN),
            description = 'Plants growing in this planter.',
            icon        = 'fa-solid fa-leaf',
            readOnly    = true,
        },
    }

    if PlantsOfPlanter[planterId] then
        for pid in pairs(PlantsOfPlanter[planterId]) do
            local plant = PlantCache[pid]
            if plant then
                local strain = Strains.GetById(plant.strainId)
                local label  = (strain and strain.label) or plant.strainId or 'Plant'
                local statusLabel, scheme = statusDisplay(plant)
                opts[#opts + 1] = {
                    title       = label,
                    description = ('%s  •  Growth %d%%'):format(statusLabel, math.floor(plant.progress or 0)),
                    icon        = 'fa-solid fa-seedling',
                    progress    = math.floor(plant.progress or 0),
                    colorScheme = scheme,
                    onSelect    = function() InspectPlant(plant.id) end,
                }
            end
        end
    end

    lib.registerContext({
        id      = 'w2f_planter_inspect_' .. planterId,
        title   = 'Planter inspection',
        options = opts,
    })
    lib.showContext('w2f_planter_inspect_' .. planterId)
end

function InspectPlant(plantId)
    local plant = PlantCache[plantId]
    if not plant then return end

    local stageIdx, stage = Growth.GetStageForProgress(plant.progress)
    local strain = Strains.GetById(plant.strainId)
    local label = (strain and strain.label) or plant.strainId or '?'
    local statusLabel, statusScheme = statusDisplay(plant)
    local stages = Growth.GetStages()
    local totalStages = #stages

    local water     = math.floor(plant.water or 0)
    local nutrients = math.floor(plant.nutrients or 0)
    local health    = math.floor(plant.health or 0)
    local progress  = math.floor(plant.progress or 0)

    local options = {
        {
            title       = ('Stage: %s'):format((stage and stage.label) or '?'),
            description = ('%d / %d'):format(stageIdx or 1, totalStages),
            icon        = 'fa-solid fa-leaf',
            readOnly    = true,
        },
        {
            title       = 'Growth',
            description = ('%d%%'):format(progress),
            icon        = 'fa-solid fa-arrow-trend-up',
            progress    = progress,
            colorScheme = progressColour(progress),
            readOnly    = true,
        },
        {
            title       = 'Water',
            description = ('%d%%'):format(water),
            icon        = 'fa-solid fa-droplet',
            progress    = water,
            colorScheme = progressColour(water),
            readOnly    = true,
        },
        {
            title       = 'Nutrients',
            description = ('%d%%'):format(nutrients),
            icon        = 'fa-solid fa-bottle-droplet',
            progress    = nutrients,
            colorScheme = progressColour(nutrients),
            readOnly    = true,
        },
        {
            title       = 'Health',
            description = ('%d%%'):format(health),
            icon        = 'fa-solid fa-heart-pulse',
            progress    = health,
            colorScheme = progressColour(health),
            readOnly    = true,
        },
        {
            title       = 'Status',
            description = statusLabel,
            icon        = 'fa-solid fa-circle-info',
            colorScheme = statusScheme,
            readOnly    = true,
        },
    }

    lib.registerContext({
        id      = 'w2f_plant_inspect_' .. plantId,
        title   = 'Plant — ' .. label,
        options = options,
    })
    lib.showContext('w2f_plant_inspect_' .. plantId)
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

RegisterNetEvent('w2f-weed:client:updatePlantLifecycle', function(plantId, payload)
    if type(plantId) ~= 'string' or type(payload) ~= 'table' then return end
    local plant = PlantCache[plantId]
    if not plant then return end

    -- Capture the upkeep category before mutating so we can detect a flip.
    local prevKind = Planters.PlantHealthStatus(plant)

    if payload.water     ~= nil then plant.water     = payload.water     end
    if payload.nutrients ~= nil then plant.nutrients = payload.nutrients end
    if payload.health    ~= nil then plant.health    = payload.health    end
    if payload.progress  ~= nil then plant.progress  = payload.progress  end
    if payload.stage     ~= nil then plant.stage     = payload.stage     end

    local prevStatus = plant.status
    if payload.status ~= nil then plant.status = payload.status end

    -- If the plant just died, swap its target options to "Remove Dead Plant".
    if plant.status == 'dead' and prevStatus ~= 'dead' then
        detachPlantTargets(plant)
        attachPlantTargets(plant)
        if plant.planterId then refreshPlanterTargets(plant.planterId) end
    elseif Planters.PlantHealthStatus(plant) ~= prevKind then
        -- Upkeep category flipped (e.g. Healthy -> Thirsty): refresh target labels.
        detachPlantTargets(plant)
        attachPlantTargets(plant)
        if plant.planterId then refreshPlanterTargets(plant.planterId) end
    end
end)

RegisterNetEvent('w2f-weed:client:updatePlanterSoil', function(planterId, soilCount, soilNeeded)
    local pl = PlanterCache[planterId]
    if not pl then return end
    pl.soilCount  = soilCount  or pl.soilCount or 0
    pl.soilNeeded = soilNeeded or pl.soilNeeded or Planters.GetSoilBagsRequired()
    refreshPlanterTargets(planterId)
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
