-- ─────────────────────────────────────────────
-- w2f-weed | Shared | Planters helpers
--
-- Pure helper functions for the planter+plant
-- growth system. Used by both client and server.
-- These MUST NOT call any client- or server-only natives.
-- ─────────────────────────────────────────────

W2FWeed             = W2FWeed or {}
W2FWeed.Planters    = W2FWeed.Planters or {}
W2FWeed.Strains     = W2FWeed.Strains or {}
W2FWeed.Growth      = W2FWeed.Growth or {}

local PREFIX = '[w2f-weed][planters]'

-- ─────────────────────────────────────────────
-- Module enablement
-- ─────────────────────────────────────────────

function W2FWeed.Planters.IsEnabled()
    return Config and Config.Planters and Config.Planters.Enabled == true
end

function W2FWeed.Planters.IsGrowthEnabled()
    return Config and Config.Growth and Config.Growth.Enabled == true
end

function W2FWeed.Planters.IsDebug()
    return Config and Config.Planters and Config.Planters.Debug == true
end

function W2FWeed.Planters.DebugPrint(...)
    if W2FWeed.Planters.IsDebug() then
        print(PREFIX, ...)
    end
end

-- ─────────────────────────────────────────────
-- Item / state helpers
-- ─────────────────────────────────────────────

function W2FWeed.Planters.GetEmptyItem()
    return Config and Config.Planters and Config.Planters.Items and Config.Planters.Items.EmptyPlanter or 'empty_planter_box'
end

function W2FWeed.Planters.GetSoilItem()
    return Config and Config.Planters and Config.Planters.Items and Config.Planters.Items.SoilBag or 'soil_bag'
end

function W2FWeed.Planters.GetEmptyProp()
    return Config and Config.Planters and Config.Planters.Props and Config.Planters.Props.Empty or 'empty_planter_box'
end

function W2FWeed.Planters.GetFilledProp()
    return Config and Config.Planters and Config.Planters.Props and Config.Planters.Props.Filled or 'planter_box'
end

function W2FWeed.Planters.GetPropForState(state)
    if state == 'filled' then
        return W2FWeed.Planters.GetFilledProp()
    end
    return W2FWeed.Planters.GetEmptyProp()
end

function W2FWeed.Planters.IsValidState(state)
    return state == 'empty' or state == 'filled'
end

--- Returns true if the model name is the empty or filled planter prop.
function W2FWeed.Planters.IsValidPlanterModel(model)
    if not Config or not Config.Planters or not Config.Planters.Props then return false end
    if type(model) == 'number' then
        return model == joaat(Config.Planters.Props.Empty) or model == joaat(Config.Planters.Props.Filled)
    end
    if type(model) ~= 'string' then return false end
    return model == Config.Planters.Props.Empty or model == Config.Planters.Props.Filled
end

-- ─────────────────────────────────────────────
-- Strain helpers
-- ─────────────────────────────────────────────

function W2FWeed.Strains.GetCatalogue()
    return (Config and Config.Strains and Config.Strains.Catalogue) or {}
end

function W2FWeed.Strains.GetById(strainId)
    if type(strainId) ~= 'string' then return nil end
    local cat = W2FWeed.Strains.GetCatalogue()
    return cat[strainId]
end

function W2FWeed.Strains.GetBySeedItem(seedItem)
    if type(seedItem) ~= 'string' then return nil end
    for _, strain in pairs(W2FWeed.Strains.GetCatalogue()) do
        if strain.seedItem == seedItem then
            return strain
        end
    end
    return nil
end

function W2FWeed.Strains.IsSeedItem(itemName)
    return W2FWeed.Strains.GetBySeedItem(itemName) ~= nil
end

function W2FWeed.Strains.GetSeedItemList()
    local list = {}
    for _, strain in pairs(W2FWeed.Strains.GetCatalogue()) do
        list[#list + 1] = strain.seedItem
    end
    return list
end

-- ─────────────────────────────────────────────
-- Growth stage helpers
-- ─────────────────────────────────────────────

function W2FWeed.Growth.GetStages()
    return (Config and Config.Growth and Config.Growth.Stages) or {}
end

function W2FWeed.Growth.GetStageCount()
    local count = 0
    for _ in pairs(W2FWeed.Growth.GetStages()) do
        count = count + 1
    end
    return count
end

--- Resolve the stage table for a given progress value (0-100).
---@param progress number
---@return integer stageIndex
---@return table|nil stageData
function W2FWeed.Growth.GetStageForProgress(progress)
    local stages = W2FWeed.Growth.GetStages()
    if next(stages) == nil then return 1, nil end

    local p = tonumber(progress) or 0
    if p < 0 then p = 0 end
    if p > 100 then p = 100 end

    local lastIdx, lastStage
    for i = 1, #stages do
        local s = stages[i]
        if s then
            lastIdx, lastStage = i, s
            if p >= (s.minProgress or 0) and p <= (s.maxProgress or 100) then
                return i, s
            end
        end
    end
    return lastIdx or 1, lastStage
end

function W2FWeed.Growth.GetStageProp(stageIndex)
    local stages = W2FWeed.Growth.GetStages()
    local s = stages[stageIndex]
    return s and s.prop or nil
end

function W2FWeed.Growth.GetStageZOffset(stageIndex)
    local stages = W2FWeed.Growth.GetStages()
    local s = stages[stageIndex]
    return s and s.zOffset or 0.0
end

function W2FWeed.Growth.IsHarvestable(stageIndex)
    local stages = W2FWeed.Growth.GetStages()
    local s = stages[stageIndex]
    return s and s.harvestable == true or false
end

--- Returns true if the model name belongs to any growth stage prop.
function W2FWeed.Growth.IsValidStageModel(model)
    local stages = W2FWeed.Growth.GetStages()
    if type(model) == 'number' then
        for _, s in pairs(stages) do
            if s.prop and joaat(s.prop) == model then return true end
        end
        return false
    end
    if type(model) ~= 'string' then return false end
    for _, s in pairs(stages) do
        if s.prop == model then return true end
    end
    return false
end

-- ─────────────────────────────────────────────
-- Soil bounds + spacing helpers (local space)
-- ─────────────────────────────────────────────

function W2FWeed.Planters.GetSoilArea()
    return (Config and Config.Planters and Config.Planters.SoilArea) or {
        width = 1.20, length = 0.65, height = 0.20, zOffset = 0.22,
    }
end

--- Returns true if a local-space (x,y) offset lies inside the soil rectangle.
---@param localX number
---@param localY number
---@return boolean
function W2FWeed.Planters.IsInsideSoilArea(localX, localY)
    local area = W2FWeed.Planters.GetSoilArea()
    local hw = (area.width or 0) * 0.5
    local hl = (area.length or 0) * 0.5
    return math.abs(localX) <= hw and math.abs(localY) <= hl
end

--- Clamp a local-space offset to remain inside the soil rectangle.
function W2FWeed.Planters.ClampToSoilArea(localX, localY)
    local area = W2FWeed.Planters.GetSoilArea()
    local hw = (area.width or 0) * 0.5
    local hl = (area.length or 0) * 0.5
    if localX < -hw then localX = -hw elseif localX > hw then localX = hw end
    if localY < -hl then localY = -hl elseif localY > hl then localY = hl end
    return localX, localY
end

function W2FWeed.Planters.GetSoilSurfaceZ()
    local area = W2FWeed.Planters.GetSoilArea()
    return area.zOffset or 0.22
end

function W2FWeed.Planters.GetMinPlantSpacing()
    return (Config and Config.Planters and Config.Planters.Planting and Config.Planters.Planting.MinimumPlantSpacing) or 0.28
end

function W2FWeed.Planters.GetMaxPlantsPerPlanter()
    return (Config and Config.Planters and Config.Planters.Planting and Config.Planters.Planting.MaxPlantsPerPlanter) or 6
end

--- Distance² in local space (x,y only).
local function dist2_xy(ax, ay, bx, by)
    local dx, dy = ax - bx, ay - by
    return dx * dx + dy * dy
end

--- Returns true if newOffset is too close to any existing plant.
---@param newX number
---@param newY number
---@param plants table[] each {localX,localY,...} or {offsetX,offsetY,...}
---@return boolean
function W2FWeed.Planters.IsTooCloseToExistingPlant(newX, newY, plants)
    local minSpacing = W2FWeed.Planters.GetMinPlantSpacing()
    local minSq = minSpacing * minSpacing
    if type(plants) ~= 'table' then return false end
    for _, p in pairs(plants) do
        local px = p.localX or p.offsetX or p.x
        local py = p.localY or p.offsetY or p.y
        if px and py then
            if dist2_xy(newX, newY, px, py) < minSq then
                return true
            end
        end
    end
    return false
end

-- ─────────────────────────────────────────────
-- Coordinate transforms (local <-> world, in 2D)
-- We intentionally implement these without natives so they
-- can run on either side. Heading is in degrees; positive
-- heading rotates counter-clockwise on the XY plane to match
-- GTA's convention (heading = degrees north-of-east, inverted).
-- ─────────────────────────────────────────────

local function deg2rad(d) return d * math.pi / 180.0 end

--- Rotate a 2D point by a heading (GTA-style: heading 0 == +Y).
---@param x number
---@param y number
---@param heading number
---@return number, number
function W2FWeed.Planters.RotateLocalToWorld(x, y, heading)
    local h = deg2rad(heading or 0)
    local cosh, sinh = math.cos(h), math.sin(h)
    local wx = x * cosh - y * sinh
    local wy = x * sinh + y * cosh
    return wx, wy
end

function W2FWeed.Planters.RotateWorldToLocal(dx, dy, heading)
    local h = deg2rad(-(heading or 0))
    local cosh, sinh = math.cos(h), math.sin(h)
    local lx = dx * cosh - dy * sinh
    local ly = dx * sinh + dy * cosh
    return lx, ly
end

--- Translate a planter local offset to world coords given the planter root.
---@param planter table {coords={x,y,z}, heading}
---@param localX number
---@param localY number
---@param localZ number
---@return number x, number y, number z
function W2FWeed.Planters.LocalToWorld(planter, localX, localY, localZ)
    if not planter or not planter.coords then return 0,0,0 end
    local rx, ry = W2FWeed.Planters.RotateLocalToWorld(localX or 0, localY or 0, planter.heading or 0)
    return planter.coords.x + rx, planter.coords.y + ry, planter.coords.z + (localZ or 0)
end

-- ─────────────────────────────────────────────
-- ID generation
-- ─────────────────────────────────────────────

function W2FWeed.Planters.GeneratePlanterId()
    local rand = math.random(100000, 999999)
    local stamp = (os and os.time and os.time()) or GetGameTimer()
    return ('pln_%s_%s'):format(stamp, rand)
end

function W2FWeed.Planters.GeneratePlantId()
    local rand = math.random(100000, 999999)
    local stamp = (os and os.time and os.time()) or GetGameTimer()
    return ('plt_%s_%s'):format(stamp, rand)
end

-- ─────────────────────────────────────────────
-- Messages
-- ─────────────────────────────────────────────

function W2FWeed.Planters.GetMessage(key, fallback)
    if Config and Config.Planters and Config.Planters.Messages and Config.Planters.Messages[key] then
        return Config.Planters.Messages[key]
    end
    return fallback or key
end

-- ─────────────────────────────────────────────
-- Safe payload helpers
-- ─────────────────────────────────────────────

--- Return a defensively-copied planter table safe to broadcast.
function W2FWeed.Planters.SafePlanterPayload(p)
    if type(p) ~= 'table' then return nil end
    return {
        id       = p.id,
        owner    = p.owner,
        item     = p.item,
        model    = p.model,
        state    = p.state,
        coords   = p.coords and { x = p.coords.x, y = p.coords.y, z = p.coords.z } or nil,
        heading  = p.heading,
        createdAt = p.createdAt,
    }
end

--- Return a defensively-copied plant table safe to broadcast.
function W2FWeed.Planters.SafePlantPayload(plant)
    if type(plant) ~= 'table' then return nil end
    return {
        id          = plant.id,
        planterId   = plant.planterId,
        owner       = plant.owner,
        strainId    = plant.strainId,
        seedItem    = plant.seedItem,
        localX      = plant.localX,
        localY      = plant.localY,
        localZ      = plant.localZ,
        rotation    = plant.rotation,
        progress    = plant.progress,
        stage       = plant.stage,
        plantedAt   = plant.plantedAt,
        lastTick    = plant.lastTick,
        status      = plant.status,
    }
end
