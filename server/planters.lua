-- ─────────────────────────────────────────────
-- w2f-weed | Server | Planters + Growth
--
-- Authoritative planter and plant lifecycle:
--   * Place an empty planter from inventory.
--   * Add soil to switch state empty -> filled.
--   * Plant seeds inside the soil at validated local offsets.
--   * Run a growth tick that progresses each plant by stage.
--   * Harvest mature plants for fictional bud rewards.
--   * Pick up an empty planter (no plants inside).
--
-- All client requests are revalidated server-side.
-- ─────────────────────────────────────────────

local Planters = W2FWeed.Planters
local Strains  = W2FWeed.Strains
local Growth   = W2FWeed.Growth
local DebugP   = Planters.DebugPrint

-- ─── In-memory authoritative state ──────────
-- Planters[planterId] = { id, owner, item, model, state, coords{x,y,z}, heading, createdAt }
-- Plants[plantId]     = { id, planterId, owner, strainId, seedItem, localX, localY, localZ,
--                         rotation, progress, stage, status, plantedAt, lastTick }
-- PlantsByPlanter[planterId] = { [plantId] = true, ... }
local Planters_Store      = {}
local Plants_Store        = {}
local PlantsByPlanter     = {}

-- per-source rate limit
local LastActionAt = {}
local ACTION_COOLDOWN_MS = 600

-- ─────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────

local function notify(src, key, type)
    if not src or src <= 0 then return end
    local message = Planters.GetMessage(key, key)
    lib.notify( src, {
        title       = 'Planters',
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
    if not Config.Planters.Security.AllowAdminPickup then return false end
    local ok, allowed = pcall(function()
        return IsPlayerAceAllowed(src, 'command') or IsPlayerAceAllowed(src, 'w2f.admin')
    end)
    return ok and allowed == true
end

local function distSqr(a, b)
    if not a or not b then return math.huge end
    local dx = (a.x or 0) - (b.x or 0)
    local dy = (a.y or 0) - (b.y or 0)
    local dz = (a.z or 0) - (b.z or 0)
    return dx * dx + dy * dy + dz * dz
end

local function rateLimit(src)
    local now = GetGameTimer()
    if LastActionAt[src] and (now - LastActionAt[src]) < ACTION_COOLDOWN_MS then
        return false
    end
    LastActionAt[src] = now
    return true
end

local function countPlantersByOwner(citizenid)
    local n = 0
    for _, p in pairs(Planters_Store) do
        if p.owner == citizenid then n = n + 1 end
    end
    return n
end

local function countAllPlanters()
    local n = 0
    for _ in pairs(Planters_Store) do n = n + 1 end
    return n
end

local function tooCloseToOtherPlanter(coords, ignoreId)
    local minDist = (Config.Planters.Limits and Config.Planters.Limits.MinPlanterSpacing) or 1.5
    local minSq = minDist * minDist
    for id, p in pairs(Planters_Store) do
        if id ~= ignoreId then
            if distSqr(coords, p.coords) < minSq then return true end
        end
    end
    return false
end

--- Roll bud count for a harvest.
--- The global Config.Growth.HarvestBud range defines the economy band; the
--- strain's `yield` biases WHERE in that band the plant lands (premium strains
--- trend toward the top), and plant health scales the final amount so neglected
--- plants pay out less. This makes both strain choice and upkeep matter instead
--- of a flat global roll that ignored the per-strain config entirely.
---@param strain table|nil resolved strain definition (may carry a `yield` range)
---@param plant table|nil the plant being harvested (carries `health`)
---@return integer
local function rollHarvestBudCountFor(strain, plant)
    local hb = Config.Growth and Config.Growth.HarvestBud
    local lo = math.floor((hb and tonumber(hb.Min)) or 12)
    local hi = math.floor((hb and tonumber(hb.Max)) or 28)
    if hi < lo then lo, hi = hi, lo end

    -- Where this strain sits relative to the catalogue (~2..8 yield span -> 0..1).
    local strainFactor = 0.5
    if strain and type(strain.yield) == 'table' then
        local mid = ((tonumber(strain.yield.min) or 2) + (tonumber(strain.yield.max) or 8)) * 0.5
        strainFactor = W2F.Clamp((mid - 2) / (8 - 2), 0.0, 1.0)
    end

    -- Top of the rollable band rises with strain tier; floor stays open so even
    -- low strains can occasionally roll small-to-mid.
    local span = hi - lo
    local bandLo = lo
    local bandHi = math.floor(lo + span * (0.45 + 0.55 * strainFactor))
    if bandHi < bandLo then bandHi = bandLo end

    local bias = (hb and hb.Bias) or 'high'
    local roll
    if bias == 'uniform' then
        roll = math.random(bandLo, bandHi)
    else
        -- max-of-two uniform: favours the upper part of the band
        roll = math.max(math.random(bandLo, bandHi), math.random(bandLo, bandHi))
    end

    -- Health scales output (neglected plants pay out less, healthy ones full).
    local healthFactor = 1.0
    if plant and plant.health ~= nil then
        healthFactor = W2F.Clamp((tonumber(plant.health) or 100) / 100, 0.45, 1.0)
    end

    roll = math.floor(roll * healthFactor + 0.5)
    if roll < 1 then roll = 1 end
    return roll
end

local function plantsForPlanter(planterId)
    local out = {}
    local map = PlantsByPlanter[planterId]
    if not map then return out end
    for plantId in pairs(map) do
        local plant = Plants_Store[plantId]
        if plant then out[#out + 1] = plant end
    end
    return out
end

local function plantCountInPlanter(planterId)
    local map = PlantsByPlanter[planterId]
    if not map then return 0 end
    local n = 0
    for _ in pairs(map) do n = n + 1 end
    return n
end

-- ─────────────────────────────────────────────
-- Database (CRUD)
-- ─────────────────────────────────────────────

function W2F.SavePlanter(p)
    if not Config.Planters.Persistence.SaveToDatabase then return end
    MySQL.insert.await([[
        INSERT INTO w2f_weed_planters
            (planter_id, citizenid, item, model, state, soil_count, x, y, z, heading, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            citizenid  = VALUES(citizenid),
            item       = VALUES(item),
            model      = VALUES(model),
            state      = VALUES(state),
            soil_count = VALUES(soil_count),
            x = VALUES(x), y = VALUES(y), z = VALUES(z),
            heading    = VALUES(heading)
    ]], {
        p.id, p.owner, p.item, p.model, p.state, p.soilCount or 0,
        p.coords.x, p.coords.y, p.coords.z, p.heading or 0.0,
        p.createdAt or W2F.GetTimestamp(),
    })
end

function W2F.DeletePlanter(planterId)
    if not Config.Planters.Persistence.SaveToDatabase then return end
    MySQL.query.await('DELETE FROM w2f_weed_planters WHERE planter_id = ?', { planterId })
    MySQL.query.await('DELETE FROM w2f_weed_plants   WHERE planter_id = ?', { planterId })
end

function W2F.SavePlant(plant)
    if not Config.Planters.Persistence.SaveToDatabase then return end
    MySQL.insert.await([[
        INSERT INTO w2f_weed_plants
            (plant_id, planter_id, citizenid, strain_id, seed_item,
             local_x, local_y, local_z, rotation, progress, stage, status,
             water, nutrients, health,
             planted_at, last_tick)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            progress  = VALUES(progress),
            stage     = VALUES(stage),
            status    = VALUES(status),
            water     = VALUES(water),
            nutrients = VALUES(nutrients),
            health    = VALUES(health),
            last_tick = VALUES(last_tick)
    ]], {
        plant.id, plant.planterId, plant.owner, plant.strainId, plant.seedItem,
        plant.localX or 0.0, plant.localY or 0.0, plant.localZ or 0.0,
        plant.rotation or 0.0, plant.progress or 0.0, plant.stage or 1, plant.status or 'growing',
        plant.water or 100, plant.nutrients or 100, plant.health or 100,
        plant.plantedAt or W2F.GetTimestamp(),
        plant.lastTick or W2F.GetTimestamp(),
    })
end

function W2F.UpdatePlantProgress(plant)
    if not Config.Planters.Persistence.SaveToDatabase then return end
    MySQL.update.await([[
        UPDATE w2f_weed_plants
            SET progress = ?, stage = ?, status = ?,
                water = ?, nutrients = ?, health = ?,
                last_tick = ?
            WHERE plant_id = ?
    ]], {
        plant.progress, plant.stage, plant.status or 'growing',
        plant.water or 100, plant.nutrients or 100, plant.health or 100,
        plant.lastTick or W2F.GetTimestamp(),
        plant.id,
    })
end

function W2F.DeletePlant(plantId)
    if not Config.Planters.Persistence.SaveToDatabase then return end
    MySQL.query.await('DELETE FROM w2f_weed_plants WHERE plant_id = ?', { plantId })
end

function W2F.LoadPlanters()
    if not Config.Planters.Persistence.LoadOnResourceStart then return 0, 0 end

    local pCount, plCount = 0, 0
    local rows = MySQL.query.await('SELECT * FROM w2f_weed_planters') or {}
    for _, r in ipairs(rows) do
        Planters_Store[r.planter_id] = {
            id        = r.planter_id,
            owner     = r.citizenid,
            item      = r.item,
            model     = r.model,
            state     = r.state or 'empty',
            soilCount = r.soil_count or (r.state == 'filled' and Planters.GetSoilBagsRequired() or 0),
            coords    = { x = r.x, y = r.y, z = r.z },
            heading   = r.heading or 0.0,
            createdAt = r.created_at,
        }
        pCount = pCount + 1
    end

    local rows2 = MySQL.query.await('SELECT * FROM w2f_weed_plants') or {}
    for _, r in ipairs(rows2) do
        if Planters_Store[r.planter_id] then
            local plant = {
                id        = r.plant_id,
                planterId = r.planter_id,
                owner     = r.citizenid,
                strainId  = r.strain_id,
                seedItem  = r.seed_item,
                localX    = r.local_x or 0.0,
                localY    = r.local_y or 0.0,
                localZ    = r.local_z or 0.0,
                rotation  = r.rotation or 0.0,
                progress  = r.progress or 0.0,
                stage     = r.stage or 1,
                status    = r.status or 'growing',
                water     = r.water     or 100,
                nutrients = r.nutrients or 100,
                health    = r.health    or 100,
                plantedAt = r.planted_at,
                lastTick  = r.last_tick,
            }
            Plants_Store[r.plant_id] = plant
            PlantsByPlanter[r.planter_id] = PlantsByPlanter[r.planter_id] or {}
            PlantsByPlanter[r.planter_id][r.plant_id] = true
            plCount = plCount + 1
        end
    end
    return pCount, plCount
end

-- ─────────────────────────────────────────────
-- Snapshots / sync
-- ─────────────────────────────────────────────

local function planterPayload(p)
    return Planters.SafePlanterPayload(p)
end

local function plantPayload(plant)
    return Planters.SafePlantPayload(plant)
end

local function buildSyncSnapshot()
    local plantersList = {}
    for _, p in pairs(Planters_Store) do
        plantersList[#plantersList + 1] = planterPayload(p)
    end
    local plantsList = {}
    for _, plant in pairs(Plants_Store) do
        plantsList[#plantsList + 1] = plantPayload(plant)
    end
    return { planters = plantersList, plants = plantsList }
end

local function broadcastCreatePlanter(p)
    TriggerClientEvent('w2f-weed:client:createPlanter', -1, planterPayload(p))
end

local function broadcastUpdatePlanterState(p)
    TriggerClientEvent('w2f-weed:client:updatePlanterState', -1, p.id, p.state, p.model)
end

local function broadcastRemovePlanter(planterId)
    TriggerClientEvent('w2f-weed:client:removePlanter', -1, planterId)
end

local function broadcastCreatePlant(plant)
    TriggerClientEvent('w2f-weed:client:createPlant', -1, plantPayload(plant))
end

local function broadcastUpdatePlant(plant)
    TriggerClientEvent('w2f-weed:client:updatePlantStage', -1, plant.id, plant.progress, plant.stage)
    TriggerClientEvent('w2f-weed:client:updatePlantLifecycle', -1, plant.id, {
        water     = plant.water,
        nutrients = plant.nutrients,
        health    = plant.health,
        status    = plant.status,
        progress  = plant.progress,
        stage     = plant.stage,
    })
end

local function broadcastPlantLifecycle(plant)
    TriggerClientEvent('w2f-weed:client:updatePlantLifecycle', -1, plant.id, {
        water     = plant.water,
        nutrients = plant.nutrients,
        health    = plant.health,
        status    = plant.status,
        progress  = plant.progress,
        stage     = plant.stage,
    })
end

local function broadcastRemovePlant(plantId, planterId)
    TriggerClientEvent('w2f-weed:client:removePlant', -1, plantId, planterId)
end

local function syncTo(src)
    TriggerClientEvent('w2f-weed:client:syncPlanters', src, buildSyncSnapshot())
end

-- ─────────────────────────────────────────────
-- Validation helpers
-- ─────────────────────────────────────────────

local function isInteractDistanceOk(src, coords)
    if not Config.Planters.Security.ValidateDistance then return true end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local pCoords = GetEntityCoords(ped)
    local max = (Config.Planters.Security.MaxInteractionDistance or 3.0) + 1.0
    return distSqr({ x = pCoords.x, y = pCoords.y, z = pCoords.z }, coords) <= (max * max)
end

local function isPlayerInVehicle(src)
    if not Config.Planters.Security.BlockPlacementInVehicle then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local veh = GetVehiclePedIsIn(ped, false)
    return veh and veh ~= 0
end

local function ownsOrAdmin(src, ownerCid)
    local cid = getCitizenId(src)
    if cid and cid == ownerCid then return true end
    return isAdmin(src)
end

-- ─────────────────────────────────────────────
-- Place a planter (from item-use)
-- ─────────────────────────────────────────────

RegisterNetEvent('w2f-weed:server:placePlanter', function(payload)
    local src = source
    if not src or src <= 0 then return end
    if not Planters.IsEnabled() then return end
    if not rateLimit(src) then return end

    if type(payload) ~= 'table' then return end
    local item    = payload.item
    local slot    = tonumber(payload.slot)
    local heading = tonumber(payload.heading) or 0.0
    local coords  = payload.coords

    if type(item) ~= 'string' or not slot or type(coords) ~= 'table' then
        notify(src, 'ServerRejected', 'error'); return
    end

    -- Only the empty planter / plant_pot triggers planter placement.
    local emptyItem = Planters.GetEmptyItem()
    if item ~= emptyItem and item ~= 'plant_pot' then
        notify(src, 'ServerRejected', 'error'); return
    end

    local cid = getCitizenId(src)
    if not cid then return end

    if isPlayerInVehicle(src) then
        notify(src, 'InVehicle', 'error'); return
    end

    -- Distance check (player <-> requested coords)
    local ped = GetPlayerPed(src)
    local pCoords = GetEntityCoords(ped)
    local maxDist = (Config.Planters.PlanterPreview.DefaultMaxDistanceFromPlayer or 4.5) + 1.5
    if distSqr({ x = pCoords.x, y = pCoords.y, z = pCoords.z }, coords) > (maxDist * maxDist) then
        notify(src, 'TooFar', 'error'); return
    end

    -- Limits
    local maxPer = Config.Planters.Limits.MaxPlantersPerPlayer or 0
    if maxPer > 0 and countPlantersByOwner(cid) >= maxPer then
        notify(src, 'ServerRejected', 'error'); return
    end
    local maxAll = Config.Planters.Limits.MaxPlantersGlobal or 0
    if maxAll > 0 and countAllPlanters() >= maxAll then
        notify(src, 'ServerRejected', 'error'); return
    end
    if tooCloseToOtherPlanter(coords) then
        notify(src, 'ServerRejected', 'error'); return
    end

    -- Inventory slot validation
    if Config.Planters.Security.ValidateInventorySlot then
        local slotData = exports.ox_inventory:GetSlot(src, slot)
        if not slotData or slotData.name ~= item or (slotData.count or 0) < 1 then
            notify(src, 'ServerRejected', 'error'); return
        end
    end

    -- Remove the item before insert (rollback if save fails)
    local removed = exports.ox_inventory:RemoveItem(src, item, 1, nil, slot) == true
    if not removed then
        notify(src, 'ServerRejected', 'error'); return
    end

    local planter = {
        id        = Planters.GeneratePlanterId(),
        owner     = cid,
        item      = emptyItem,
        model     = Planters.GetEmptyProp(),
        state     = 'empty',
        soilCount = 0,
        coords    = { x = coords.x + 0.0, y = coords.y + 0.0, z = coords.z + 0.0 },
        heading   = heading % 360,
        createdAt = W2F.GetTimestamp(),
    }

    local saveOk = pcall(function() W2F.SavePlanter(planter) end)
    if not saveOk then
        exports.ox_inventory:AddItem(src, item, 1)
        notify(src, 'ServerRejected', 'error'); return
    end

    Planters_Store[planter.id] = planter
    broadcastCreatePlanter(planter)
    DebugP('placed planter', planter.id, 'by', cid)
    notify(src, 'PlanterPlaced', 'success')
end)

-- ─────────────────────────────────────────────
-- Add soil to a planter (empty -> filled)
-- ─────────────────────────────────────────────

RegisterNetEvent('w2f-weed:server:addSoilToPlanter', function(planterId)
    local src = source
    if not src or src <= 0 then return end
    if not rateLimit(src) then return end
    if type(planterId) ~= 'string' then return end

    local p = Planters_Store[planterId]
    if not p then notify(src, 'ServerRejected', 'error'); return end

    if Config.Planters.Security.OnlyOwnerCanUse and not ownsOrAdmin(src, p.owner) then
        notify(src, 'NotOwner', 'error'); return
    end

    if p.state ~= 'empty' then notify(src, 'AlreadyFilled', 'error'); return end
    if not isInteractDistanceOk(src, p.coords) then notify(src, 'TooFar', 'error'); return end

    local soilItem = Planters.GetSoilItem()
    local count = exports.ox_inventory:GetItemCount(src, soilItem) or 0
    if count < 1 then notify(src, 'NoSoilBag', 'error'); return end

    local removed = exports.ox_inventory:RemoveItem(src, soilItem, 1) == true
    if not removed then notify(src, 'NoSoilBag', 'error'); return end

    -- Partial-fill: count up to BagsRequired before flipping to 'filled'.
    local required = Planters.GetSoilBagsRequired()
    p.soilCount = (p.soilCount or 0) + 1

    if p.soilCount >= required then
        p.soilCount = required
        p.state = 'filled'
        p.model = Planters.GetFilledProp()
        pcall(function() W2F.SavePlanter(p) end)
        broadcastUpdatePlanterState(p)
        TriggerClientEvent('w2f-weed:client:updatePlanterSoil', -1, p.id, p.soilCount, required)
        DebugP('soil filled', planterId, p.soilCount, '/', required)
        notify(src, 'SoilFilled', 'success')
    else
        pcall(function() W2F.SavePlanter(p) end)
        TriggerClientEvent('w2f-weed:client:updatePlanterSoil', -1, p.id, p.soilCount, required)
        DebugP('soil progress', planterId, p.soilCount, '/', required)
        -- Format progress message client-side via a custom notify (uses Messages).
        local tmpl = Planters.GetMessage('SoilProgress', 'Added a bag of soil (%d / %d).')
        local msg = (string.format(tmpl, p.soilCount, required))
        lib.notify(src, { title = 'Planters', description = msg, type = 'inform', position = 'top' })
    end
end)

-- ─────────────────────────────────────────────
-- Plant a seed at a local offset inside a filled planter
-- ─────────────────────────────────────────────

RegisterNetEvent('w2f-weed:server:plantSeedInPlanter', function(payload)
    local src = source
    if not src or src <= 0 then return end
    if not rateLimit(src) then return end

    if type(payload) ~= 'table' then return end
    local planterId = payload.planterId
    local seedItem  = payload.seedItem
    local slot      = tonumber(payload.slot)
    local localX    = tonumber(payload.localX) or 0.0
    local localY    = tonumber(payload.localY) or 0.0
    local rotation  = tonumber(payload.rotation) or 0.0

    if type(planterId) ~= 'string' or type(seedItem) ~= 'string' or not slot then return end

    local p = Planters_Store[planterId]
    if not p then notify(src, 'ServerRejected', 'error'); return end

    if Config.Planters.Security.OnlyOwnerCanUse and not ownsOrAdmin(src, p.owner) then
        notify(src, 'NotOwner', 'error'); return
    end

    -- Soil/state check
    if Config.Planters.Planting.RequireSoil and p.state ~= 'filled' then
        notify(src, 'NotFilled', 'error'); return
    end

    -- Distance check
    if not isInteractDistanceOk(src, p.coords) then
        notify(src, 'TooFar', 'error'); return
    end

    -- Strain validation
    local strain = Strains.GetBySeedItem(seedItem)
    if not strain then
        notify(src, 'InvalidStrain', 'error'); return
    end

    -- Capacity check
    local existing = plantsForPlanter(planterId)
    if #existing >= Planters.GetMaxPlantsPerPlanter() then
        notify(src, 'MaxPlantsReached', 'error'); return
    end

    -- Soil bounds + spacing
    if Config.Planters.Security.ValidateSoilBounds and not Planters.IsInsideSoilArea(localX, localY) then
        notify(src, 'OutsideSoil', 'error'); return
    end
    if Config.Planters.Security.ValidatePlantSpacing and Planters.IsTooCloseToExistingPlant(localX, localY, existing) then
        notify(src, 'TooClose', 'error'); return
    end

    -- Inventory slot validation
    if Config.Planters.Security.ValidateInventorySlot then
        local slotData = exports.ox_inventory:GetSlot(src, slot)
        if not slotData or slotData.name ~= seedItem or (slotData.count or 0) < 1 then
            notify(src, 'ServerRejected', 'error'); return
        end
    end

    -- Remove seed
    local removed = exports.ox_inventory:RemoveItem(src, seedItem, 1, nil, slot) == true
    if not removed then notify(src, 'ServerRejected', 'error'); return end

    local cid = getCitizenId(src)
    local now = W2F.GetTimestamp()
    local lc  = Planters.GetLifecycleConfig()
    local plant = {
        id        = Planters.GeneratePlantId(),
        planterId = planterId,
        owner     = cid,
        strainId  = strain.id,
        seedItem  = seedItem,
        localX    = localX,
        localY    = localY,
        localZ    = Planters.GetSoilSurfaceZ(),
        rotation  = rotation % 360,
        progress  = 0.0,
        stage     = 1,
        status    = 'growing',
        water     = (lc.Water and lc.Water.Start) or 100,
        nutrients = (lc.Nutrients and lc.Nutrients.Start) or 100,
        health    = (lc.Health and lc.Health.Start) or 100,
        plantedAt = now,
        lastTick  = now,
    }

    local saveOk = pcall(function() W2F.SavePlant(plant) end)
    if not saveOk then
        exports.ox_inventory:AddItem(src, seedItem, 1)
        notify(src, 'ServerRejected', 'error'); return
    end

    Plants_Store[plant.id] = plant
    PlantsByPlanter[planterId] = PlantsByPlanter[planterId] or {}
    PlantsByPlanter[planterId][plant.id] = true

    broadcastCreatePlant(plant)
    DebugP('planted', strain.id, 'in', planterId, '@', localX, localY)
    notify(src, 'SeedRemoved', 'success')
end)

-- ─────────────────────────────────────────────
-- Harvest a ready plant
-- ─────────────────────────────────────────────

RegisterNetEvent('w2f-weed:server:harvestPlant', function(plantId)
    local src = source
    if not src or src <= 0 then return end
    if not rateLimit(src) then return end
    if type(plantId) ~= 'string' then return end

    local plant = Plants_Store[plantId]
    if not plant then notify(src, 'ServerRejected', 'error'); return end

    local p = Planters_Store[plant.planterId]
    if not p then notify(src, 'ServerRejected', 'error'); return end

    if Config.Planters.Security.OnlyOwnerCanHarvest and not ownsOrAdmin(src, plant.owner) then
        notify(src, 'NotOwner', 'error'); return
    end

    if not isInteractDistanceOk(src, p.coords) then
        notify(src, 'TooFar', 'error'); return
    end

    local _, stage = Growth.GetStageForProgress(plant.progress)
    if not stage or not stage.harvestable then
        notify(src, 'HarvestNotReady', 'error'); return
    end

    local strain = Strains.GetById(plant.strainId)
    if not strain or not strain.budItem then
        notify(src, 'InvalidStrain', 'error'); return
    end

    local harvestCfg = Config.Planters.Harvest
    --- Default: require tool unless Harvest.RequireTrimmingScissors is explicitly false.
    local requireTool = not harvestCfg or harvestCfg.RequireTrimmingScissors ~= false
    if requireTool then
        local tool = (Config.Planters.Items and Config.Planters.Items.TrimmingScissors) or 'trimming_scissors'
        local have = exports.ox_inventory:GetItemCount(src, tool) or 0
        if have < 1 then
            notify(src, 'MissingTrimmingScissors', 'error'); return
        end
        if harvestCfg and harvestCfg.ConsumeTrimmingScissors then
            if exports.ox_inventory:RemoveItem(src, tool, 1) ~= true then
                notify(src, 'MissingTrimmingScissors', 'error'); return
            end
        end
    end

    local count = rollHarvestBudCountFor(strain, plant)

    local can = exports.ox_inventory:CanCarryItem(src, strain.budItem, count)
    if not can then notify(src, 'InventoryFull', 'error'); return end

    local added = exports.ox_inventory:AddItem(src, strain.budItem, count)
    if not added then notify(src, 'InventoryFull', 'error'); return end

    -- Remove plant
    Plants_Store[plantId] = nil
    if PlantsByPlanter[plant.planterId] then
        PlantsByPlanter[plant.planterId][plantId] = nil
    end
    pcall(function() W2F.DeletePlant(plantId) end)
    broadcastRemovePlant(plantId, plant.planterId)

    DebugP('harvested', plantId, '->', count, strain.budItem)
    notify(src, 'HarvestComplete', 'success')
end)

-- ─────────────────────────────────────────────
-- Harvest all mature plants on a planter (ox_target on planter box)
-- ─────────────────────────────────────────────

RegisterNetEvent('w2f-weed:server:harvestReadyPlantsOnPlanter', function(planterId)
    local src = source
    if not src or src <= 0 then return end
    if not rateLimit(src) then return end
    if type(planterId) ~= 'string' then return end

    local p = Planters_Store[planterId]
    if not p then notify(src, 'ServerRejected', 'error'); return end

    if Config.Planters.Security.OnlyOwnerCanHarvest and not ownsOrAdmin(src, p.owner) then
        notify(src, 'NotOwner', 'error'); return
    end

    if not isInteractDistanceOk(src, p.coords) then
        notify(src, 'TooFar', 'error'); return
    end

    if p.state ~= 'filled' then
        notify(src, 'NotFilled', 'error'); return
    end

    local map = PlantsByPlanter[planterId]
    if not map then notify(src, 'HarvestNotReady', 'error'); return end

    local toHarvest = {}
    for plantId in pairs(map) do
        local plant = Plants_Store[plantId]
        if plant then
            local _, stage = Growth.GetStageForProgress(plant.progress)
            if stage and stage.harvestable then
                local strain = Strains.GetById(plant.strainId)
                if strain and strain.budItem then
                    toHarvest[#toHarvest + 1] = plant
                end
            end
        end
    end

    if #toHarvest == 0 then
        notify(src, 'HarvestNotReady', 'error'); return
    end

    local harvestCfg = Config.Planters.Harvest
    local requireTool = not harvestCfg or harvestCfg.RequireTrimmingScissors ~= false
    if requireTool then
        local tool = (Config.Planters.Items and Config.Planters.Items.TrimmingScissors) or 'trimming_scissors'
        local have = exports.ox_inventory:GetItemCount(src, tool) or 0
        if have < 1 then
            notify(src, 'MissingTrimmingScissors', 'error'); return
        end
        if harvestCfg and harvestCfg.ConsumeTrimmingScissors then
            if exports.ox_inventory:RemoveItem(src, tool, 1) ~= true then
                notify(src, 'MissingTrimmingScissors', 'error'); return
            end
        end
    end

    local grants = {}
    for i = 1, #toHarvest do
        local plant = toHarvest[i]
        local strain = Strains.GetById(plant.strainId)
        local count = rollHarvestBudCountFor(strain, plant)
        local item = strain.budItem
        grants[item] = (grants[item] or 0) + count
    end

    for budItem, count in pairs(grants) do
        if not exports.ox_inventory:CanCarryItem(src, budItem, count) then
            notify(src, 'InventoryFull', 'error'); return
        end
    end

    for budItem, count in pairs(grants) do
        if not exports.ox_inventory:AddItem(src, budItem, count) then
            notify(src, 'InventoryFull', 'error'); return
        end
    end

    for i = 1, #toHarvest do
        local plant = toHarvest[i]
        local pid = plant.id
        Plants_Store[pid] = nil
        if PlantsByPlanter[planterId] then
            PlantsByPlanter[planterId][pid] = nil
        end
        pcall(function() W2F.DeletePlant(pid) end)
        broadcastRemovePlant(pid, planterId)
        DebugP('batch harvested', pid, planterId)
    end

    notify(src, 'HarvestedPlanterBatch', 'success')
end)

-- ─────────────────────────────────────────────
-- Apply fertilizer to fast-forward one plant
-- ─────────────────────────────────────────────

RegisterNetEvent('w2f-weed:server:applyFertilizerToPlant', function(plantId, fertilizerItem)
    local src = source
    if not src or src <= 0 then return end
    if not rateLimit(src) then return end
    if type(plantId) ~= 'string' or type(fertilizerItem) ~= 'string' then return end

    local fertCfg = Config.Growth and Config.Growth.Fertilizers and Config.Growth.Fertilizers[fertilizerItem]
    if not fertCfg then
        notify(src, 'ServerRejected', 'error')
        return
    end

    local plant = Plants_Store[plantId]
    if not plant then notify(src, 'ServerRejected', 'error'); return end

    local p = Planters_Store[plant.planterId]
    if not p then notify(src, 'ServerRejected', 'error'); return end

    if Config.Planters.Security.OnlyOwnerCanUse and not ownsOrAdmin(src, plant.owner) then
        notify(src, 'NotOwner', 'error'); return
    end

    if not isInteractDistanceOk(src, p.coords) then
        notify(src, 'TooFar', 'error'); return
    end

    if plant.status == 'dead' or (plant.health or 100) <= 0 then
        notify(src, 'PlantDead', 'error')
        return
    end

    local _, currentStage = Growth.GetStageForProgress(plant.progress)
    if currentStage and currentStage.harvestable then
        notify(src, 'PlantAlreadyReady', 'error')
        return
    end

    local count = exports.ox_inventory:GetItemCount(src, fertilizerItem) or 0
    if count < 1 then
        notify(src, 'MissingFertilizer', 'error')
        return
    end

    local removed = exports.ox_inventory:RemoveItem(src, fertilizerItem, 1) == true
    if not removed then
        notify(src, 'MissingFertilizer', 'error')
        return
    end

    local strain = Strains.GetById(plant.strainId)
    local mult = (strain and strain.growthMultiplier) or 1.0
    local tickMinutes = (Config.Growth and Config.Growth.TickMinutes) or 1
    local minP = (Config.Growth and Config.Growth.ProgressPerTick and Config.Growth.ProgressPerTick.Min) or 6
    local maxP = (Config.Growth and Config.Growth.ProgressPerTick and Config.Growth.ProgressPerTick.Max) or 6
    local avg = (minP + maxP) * 0.5
    local minutes = fertCfg.decreaseMinutes or 0
    local gain = (avg / tickMinutes) * minutes * mult

    plant.progress = math.min(100, math.max(plant.progress or 0, (plant.progress or 0) + gain))

    -- Also top up the nutrient bar — fertilizer is what gives the plant minerals.
    local lc = Planters.GetLifecycleConfig()
    local nutrientGain
    if fertilizerItem == 'fertilizer_basic' then
        nutrientGain = (lc.Nutrients and lc.Nutrients.FertilizerBasic) or 35
    elseif fertilizerItem == 'fertilizer_premium' then
        nutrientGain = (lc.Nutrients and lc.Nutrients.FertilizerPremium) or 55
    else
        nutrientGain = (lc.Nutrients and lc.Nutrients.FertilizerBasic) or 35
    end
    plant.nutrients = math.min(100, (plant.nutrients or 0) + nutrientGain)

    local newStage, stageData = Growth.GetStageForProgress(plant.progress)
    plant.stage = newStage
    plant.lastTick = W2F.GetTimestamp()
    if stageData and stageData.harvestable then
        plant.progress = 100
        plant.status = 'ready'
    end

    pcall(function() W2F.UpdatePlantProgress(plant) end)
    broadcastUpdatePlant(plant)

    DebugP('fertilizer applied', fertilizerItem, 'to', plantId, '+', gain, 'progress, +', nutrientGain, 'nutrients')
    notify(src, 'FertilizerApplied', 'success')
end)

-- ─────────────────────────────────────────────
-- Water all (living) plants in a planter
-- ─────────────────────────────────────────────

RegisterNetEvent('w2f-weed:server:waterPlanter', function(planterId)
    local src = source
    if not src or src <= 0 then return end
    if not rateLimit(src) then return end
    if type(planterId) ~= 'string' then return end

    local p = Planters_Store[planterId]
    if not p then notify(src, 'ServerRejected', 'error'); return end

    if Config.Planters.Security.OnlyOwnerCanUse and not ownsOrAdmin(src, p.owner) then
        notify(src, 'NotOwner', 'error'); return
    end

    if not isInteractDistanceOk(src, p.coords) then
        notify(src, 'TooFar', 'error'); return
    end

    local wateringCan = Planters.GetWateringCanItem()
    local have = exports.ox_inventory:GetItemCount(src, wateringCan) or 0
    if have < 1 then
        notify(src, 'MissingWateringCan', 'error'); return
    end

    local plants = plantsForPlanter(planterId)
    local watered = 0
    local lc = Planters.GetLifecycleConfig()
    local gain = (lc.Water and lc.Water.WateringCanGain) or 60
    for _, plant in ipairs(plants) do
        if plant.status ~= 'dead' and (plant.health or 100) > 0 then
            plant.water = math.min(100, (plant.water or 0) + gain)
            plant.lastTick = W2F.GetTimestamp()
            pcall(function() W2F.UpdatePlantProgress(plant) end)
            broadcastPlantLifecycle(plant)
            watered = watered + 1
        end
    end

    if watered == 0 then
        notify(src, 'NoPlantsToWater', 'error'); return
    end

    DebugP('watered', watered, 'plants in', planterId)
    notify(src, 'Watered', 'success')
end)

-- ─────────────────────────────────────────────
-- Remove a dead plant (no rewards, just cleanup)
-- ─────────────────────────────────────────────

RegisterNetEvent('w2f-weed:server:removeDeadPlant', function(plantId)
    local src = source
    if not src or src <= 0 then return end
    if not rateLimit(src) then return end
    if type(plantId) ~= 'string' then return end

    local plant = Plants_Store[plantId]
    if not plant then notify(src, 'ServerRejected', 'error'); return end

    local p = Planters_Store[plant.planterId]
    if not p then notify(src, 'ServerRejected', 'error'); return end

    if Config.Planters.Security.OnlyOwnerCanUse and not ownsOrAdmin(src, plant.owner) then
        notify(src, 'NotOwner', 'error'); return
    end

    if not isInteractDistanceOk(src, p.coords) then
        notify(src, 'TooFar', 'error'); return
    end

    if plant.status ~= 'dead' and (plant.health or 100) > 0 then
        notify(src, 'ServerRejected', 'error'); return
    end

    Plants_Store[plantId] = nil
    if PlantsByPlanter[plant.planterId] then
        PlantsByPlanter[plant.planterId][plantId] = nil
    end
    pcall(function() W2F.DeletePlant(plantId) end)
    broadcastRemovePlant(plantId, plant.planterId)
    DebugP('removed dead plant', plantId)
    notify(src, 'PlantRemoved', 'success')
end)

-- ─────────────────────────────────────────────
-- Pickup a planter (only when empty of plants)
-- ─────────────────────────────────────────────

RegisterNetEvent('w2f-weed:server:pickupPlanter', function(planterId)
    local src = source
    if not src or src <= 0 then return end
    if not rateLimit(src) then return end
    if type(planterId) ~= 'string' then return end

    local p = Planters_Store[planterId]
    if not p then return end

    if Config.Planters.Security.OnlyOwnerCanUse and not ownsOrAdmin(src, p.owner) then
        notify(src, 'NotOwner', 'error'); return
    end

    if not isInteractDistanceOk(src, p.coords) then
        notify(src, 'TooFar', 'error'); return
    end

    if not Config.Planters.Security.AllowPickupWithPlants then
        if plantCountInPlanter(planterId) > 0 then
            notify(src, 'PlanterHasPlants', 'error'); return
        end
    end

    -- Give the empty planter back
    local giveItem = Planters.GetEmptyItem()
    local can = exports.ox_inventory:CanCarryItem(src, giveItem, 1)
    if not can then notify(src, 'InventoryFull', 'error'); return end
    if not exports.ox_inventory:AddItem(src, giveItem, 1) then
        notify(src, 'InventoryFull', 'error'); return
    end

    -- Cleanup any leftover plants in case of force-pickup
    local plants = plantsForPlanter(planterId)
    for _, plant in ipairs(plants) do
        Plants_Store[plant.id] = nil
        broadcastRemovePlant(plant.id, planterId)
    end
    PlantsByPlanter[planterId] = nil

    Planters_Store[planterId] = nil
    pcall(function() W2F.DeletePlanter(planterId) end)

    broadcastRemovePlanter(planterId)
    DebugP('pickup planter', planterId)
    notify(src, 'PlanterPickedUp', 'success')
end)

-- ─────────────────────────────────────────────
-- Sync requests / queries
-- ─────────────────────────────────────────────

RegisterNetEvent('w2f-weed:server:requestPlanterSync', function()
    local src = source
    if not src or src <= 0 then return end
    syncTo(src)
end)

lib.callback.register('w2f-weed:server:getAvailableSeeds', function(src)
    if not src or src <= 0 then return {} end
    local list = {}
    for _, strain in pairs(Strains.GetCatalogue()) do
        local count = exports.ox_inventory:GetItemCount(src, strain.seedItem) or 0
        if count > 0 then
            list[#list + 1] = {
                strainId    = strain.id,
                seedItem    = strain.seedItem,
                label       = strain.label,
                count       = count,
                description = strain.description,
            }
        end
    end
    return list
end)

lib.callback.register('w2f-weed:server:getPlanterPlants', function(src, planterId)
    if type(planterId) ~= 'string' then return {} end
    local out = {}
    for _, plant in ipairs(plantsForPlanter(planterId)) do
        out[#out + 1] = plantPayload(plant)
    end
    return out
end)

lib.callback.register('w2f-weed:server:getPlanterData', function(src, planterId)
    local p = Planters_Store[planterId]
    if not p then return nil end
    return planterPayload(p)
end)

-- ─────────────────────────────────────────────
-- Growth tick
-- ─────────────────────────────────────────────

local function applyGrowthDelta(plant, deltaSeconds)
    if not plant then return end
    if plant.status == 'dead' then return end

    local lc = Planters.GetLifecycleConfig()
    local lifecycleOn = Planters.IsLifecycleEnabled()
    local tickMinutes = (Config.Growth and Config.Growth.TickMinutes) or 5
    local fraction = deltaSeconds / (tickMinutes * 60)
    if fraction <= 0 then return end

    -- ─── Lifecycle decay: water & nutrients drain per tick ──
    local prevStatus = plant.status
    local prevHealth = plant.health or 100
    if lifecycleOn then
        local waterDecay     = (lc.Water and lc.Water.DecayPerTick) or 6
        local nutrientDecay  = (lc.Nutrients and lc.Nutrients.DecayPerTick) or 4
        plant.water     = math.max(0, (plant.water or 100) - waterDecay * fraction)
        plant.nutrients = math.max(0, (plant.nutrients or 100) - nutrientDecay * fraction)

        -- Health damage when either resource is empty.
        local damage = 0
        if plant.water <= 0 then
            damage = damage + ((lc.Water and lc.Water.HealthHitAt0) or 8)
        end
        if plant.nutrients <= 0 then
            damage = damage + ((lc.Nutrients and lc.Nutrients.HealthHitAt0) or 6)
        end
        if damage > 0 then
            plant.health = math.max(0, (plant.health or 100) - damage * fraction)
        else
            -- Healthy plant: small regen.
            local regen = (lc.Health and lc.Health.RegenPerTick) or 2
            plant.health = math.min(100, (plant.health or 100) + regen * fraction)
        end

        if plant.health <= ((lc.Health and lc.Health.DeadAt) or 0) and plant.status ~= 'ready' then
            plant.health = 0
            plant.status = 'dead'
            plant.lastTick = W2F.GetTimestamp()
            pcall(function() W2F.UpdatePlantProgress(plant) end)
            broadcastUpdatePlant(plant)
            return
        end
    end

    -- Growth is paused while the plant is wilted/dry/starved (configurable).
    local pauseGrowth = lifecycleOn and (lc.PauseGrowthWhenDepleted ~= false)
        and ((plant.water or 0) <= 0 or (plant.nutrients or 0) <= 0)

    local progressGained = false
    if plant.status == 'growing' and (plant.progress or 0) < 100 and not pauseGrowth then
        local strain = Strains.GetById(plant.strainId)
        local mult = (strain and strain.growthMultiplier) or 1.0
        local minP = (Config.Growth and Config.Growth.ProgressPerTick and Config.Growth.ProgressPerTick.Min) or 4
        local maxP = (Config.Growth and Config.Growth.ProgressPerTick and Config.Growth.ProgressPerTick.Max) or 8
        local avg  = (minP + maxP) * 0.5

        local gain = avg * mult * fraction
        if deltaSeconds <= (tickMinutes * 60 * 1.2) then
            local jitter = math.random() * (maxP - minP) - (maxP - minP) * 0.5
            gain = gain + jitter * fraction
        end

        plant.progress = math.min(100, math.max(plant.progress or 0, (plant.progress or 0) + gain))
        progressGained = gain > 0
    end

    local newStage, stageData = Growth.GetStageForProgress(plant.progress)
    local stageChanged = (newStage ~= plant.stage)
    plant.stage = newStage
    plant.lastTick = W2F.GetTimestamp()

    if stageData and stageData.harvestable then
        plant.progress = 100
        plant.status = 'ready'
    end

    pcall(function() W2F.UpdatePlantProgress(plant) end)

    if stageChanged or plant.status ~= prevStatus then
        broadcastUpdatePlant(plant)
    else
        -- Push lifecycle stats so inspect menus stay current.
        broadcastPlantLifecycle(plant)
    end
end

local function runGrowthTickFor(plant)
    local now = W2F.GetTimestamp()
    local last = plant.lastTick or plant.plantedAt or now
    local delta = math.max(0, now - last)
    applyGrowthDelta(plant, delta)
end

local function runGrowthTickAll()
    for _, plant in pairs(Plants_Store) do
        runGrowthTickFor(plant)
    end
end

-- Initial catch-up on resource start, then periodic ticks.
CreateThread(function()
    Wait(2000)
    if not Planters.IsEnabled() then DebugP('module disabled'); return end

    local pCount, plCount = W2F.LoadPlanters()
    DebugP(('loaded %d planters / %d plants'):format(pCount, plCount))

    -- Catch up offline progress once
    if Planters.IsGrowthEnabled() then
        runGrowthTickAll()
    end

    -- Periodic growth tick
    while true do
        local minutes = (Config.Growth and Config.Growth.TickMinutes) or 5
        Wait(minutes * 60 * 1000)
        if Planters.IsGrowthEnabled() then
            runGrowthTickAll()
        end
    end
end)

-- ─────────────────────────────────────────────
-- Cleanup
-- ─────────────────────────────────────────────

AddEventHandler('playerDropped', function()
    LastActionAt[source] = nil
end)

-- ─────────────────────────────────────────────
-- Debug commands
-- ─────────────────────────────────────────────

CreateThread(function()
    if not Planters.IsDebug() then return end

    RegisterCommand('weed_planter_count', function(src)
        local total = countAllPlanters()
        local plantTotal = 0
        for _ in pairs(Plants_Store) do plantTotal = plantTotal + 1 end
        local msg = ('[w2f-weed][planters] planters=%d plants=%d'):format(total, plantTotal)
        if src == 0 then print(msg) else
            TriggerClientEvent('chat:addMessage', src, { args = { '^2[w2f-weed]', msg } })
        end
    end, false)

    RegisterCommand('weed_planter_grow', function(src)
        if src ~= 0 and not isAdmin(src) then return end
        for _, plant in pairs(Plants_Store) do
            plant.progress = math.min(100, (plant.progress or 0) + 25)
            local newStage = Growth.GetStageForProgress(plant.progress)
            plant.stage = newStage
            plant.lastTick = W2F.GetTimestamp()
            pcall(function() W2F.UpdatePlantProgress(plant) end)
            broadcastUpdatePlant(plant)
        end
        local msg = ('[w2f-weed] forced +25 progress on %d plants'):format((function()
            local n = 0; for _ in pairs(Plants_Store) do n = n + 1 end; return n
        end)())
        if src == 0 then print(msg) else
            TriggerClientEvent('chat:addMessage', src, { args = { '^2[w2f-weed]', msg } })
        end
    end, true)

    RegisterCommand('weed_planter_sync', function(src)
        if src == 0 then return end
        syncTo(src)
    end, false)
end)
