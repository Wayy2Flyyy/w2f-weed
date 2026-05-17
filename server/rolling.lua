--- Rolling minigame: server validation + rewards (ox_inventory).

---@param src number
---@param itemName string
---@return integer
local function countItem(src, itemName)
    if not itemName or itemName == '' then return 0 end
    local n = exports.ox_inventory:GetItemCount(src, itemName) or 0
    if n > 0 then return n end
    local viaSearch = exports.ox_inventory:Search(src, 'count', itemName)
    if type(viaSearch) == 'number' then return viaSearch end
    --- Search returns the count directly when one item name is passed.
    return n
end

local function jointItemForStrain(strainId)
    local map = Config.RollingMinigame and Config.RollingMinigame.JointItems
    if not map or not strainId then return nil end
    return map[strainId]
end

---@param src number
---@return table|nil
local function craftContext(src)
    if not Config.RollingMinigame or not Config.RollingMinigame.Enabled then
        return { ok = false, reason = 'disabled' }
    end

    local cat = Config.Strains and Config.Strains.Catalogue
    if not cat then
        return { ok = false, reason = 'config' }
    end

    local needBuds = tonumber(Config.RollingMinigame.BudsPerJoint) or 3
    if needBuds < 1 then needBuds = 1 end

    local paperItem = Config.RollingMinigame.PaperItem
    local needPaper = Config.RollingMinigame.RequirePaper == true
    local paperCount = (not needPaper or not paperItem) and 999
        or countItem(src, paperItem)
    local papersPer = tonumber(Config.RollingMinigame.PapersPerJoint) or 1
    if papersPer < 1 then papersPer = 1 end
    local hasPaper = not needPaper or paperCount >= papersPer

    local strains = {}
    for id, def in pairs(cat) do
        local budKey = def.budItem
        local n = budKey and countItem(src, budKey) or 0
        --- UI: only grey out when not enough bud — papers are checked again at craft time.
        local selectable = n >= needBuds
        local blockedHint
        if n < needBuds then
            blockedHint = string.format(Locale('rolling_blocked_need_buds'), needBuds, n)
        elseif needPaper and not hasPaper then
            blockedHint = Locale('rolling_blocked_need_papers')
        end
        strains[#strains + 1] = {
            id = id,
            label = def.label or id,
            budCount = n,
            selectable = selectable,
            --- 1/0 so NUI always parses availability (some JSON paths mishandle booleans).
            selectableFlag = selectable and 1 or 0,
            canFinishRoll = hasPaper and selectable,
            canFinishFlag = (hasPaper and selectable) and 1 or 0,
            blockedHint = blockedHint,
        }
    end

    table.sort(strains, function(a, b)
        return (a.label or '') < (b.label or '')
    end)

    return {
        ok = true,
        strains = strains,
        requirePaper = needPaper,
        budsPerJoint = needBuds,
        papersPerJoint = papersPer,
        hasRollingPaper = hasPaper,
        hasRollingPaperFlag = hasPaper and 1 or 0,
        openHintNoPaper = Locale('rolling_open_need_papers'),
    }
end

lib.callback.register('w2f-weed:server:rollingMinigameContext', function(source)
    local src = source
    if not W2F.ValidateSource(src) then
        return { ok = false, reason = 'player' }
    end
    return craftContext(src)
end)

lib.callback.register('w2f-weed:server:rollingMinigameReward', function(source, payload)
    local src = source
    if not W2F.ValidateSource(src) then
        return { ok = false, reason = 'player' }
    end

    if not Config.RollingMinigame or not Config.RollingMinigame.Enabled then
        return { ok = false, reason = 'disabled' }
    end

    local strainId = payload and payload.strainId
    if type(strainId) ~= 'string' then
        return { ok = false, reason = 'strain' }
    end

    local strainCfg = Config.Strains.Catalogue[strainId]
    if not strainCfg then
        return { ok = false, reason = 'strain' }
    end

    local jointItem = jointItemForStrain(strainId)
    if not jointItem then
        W2F.SecurityLog('Rolling minigame: no joint mapped for strain', { strainId = strainId })
        return { ok = false, reason = 'joint_config' }
    end

    local quality = tonumber(payload.quality)
    local minQ = tonumber(Config.RollingMinigame.MinimumQuality) or 0
    if quality == nil or quality < minQ then
        return { ok = false, reason = 'quality' }
    end

    local ctx = craftContext(src)
    if not ctx.ok then
        return { ok = false, reason = ctx.reason }
    end

    local needBuds = tonumber(ctx.budsPerJoint) or tonumber(Config.RollingMinigame.BudsPerJoint) or 3
    if needBuds < 1 then needBuds = 1 end

    local rowMatch
    for _, row in ipairs(ctx.strains or {}) do
        if row.id == strainId then
            rowMatch = row
            break
        end
    end
    if not rowMatch or (rowMatch.budCount or 0) < needBuds then
        return { ok = false, reason = 'no_buds' }
    end

    local budItem = strainCfg.budItem
    if countItem(src, budItem) < needBuds then
        return { ok = false, reason = 'no_buds' }
    end

    local paperItem = Config.RollingMinigame.PaperItem
    local papersPer = tonumber(ctx.papersPerJoint) or tonumber(Config.RollingMinigame.PapersPerJoint) or 1
    if papersPer < 1 then papersPer = 1 end

    if Config.RollingMinigame.RequirePaper and paperItem then
        if countItem(src, paperItem) < papersPer then
            return { ok = false, reason = 'no_papers' }
        end
    end

    if not exports.ox_inventory:CanCarryItem(src, jointItem, 1) then
        return { ok = false, reason = 'carry' }
    end

    if exports.ox_inventory:RemoveItem(src, budItem, needBuds) ~= true then
        return { ok = false, reason = 'bud_remove' }
    end

    if Config.RollingMinigame.RequirePaper and paperItem then
        if exports.ox_inventory:RemoveItem(src, paperItem, papersPer) ~= true then
            exports.ox_inventory:AddItem(src, budItem, needBuds)
            return { ok = false, reason = 'paper_remove' }
        end
    end

    if exports.ox_inventory:AddItem(src, jointItem, 1) ~= true then
        exports.ox_inventory:AddItem(src, budItem, needBuds)
        if Config.RollingMinigame.RequirePaper and paperItem then
            exports.ox_inventory:AddItem(src, paperItem, papersPer)
        end
        return { ok = false, reason = 'give_failed' }
    end

    return { ok = true, joint = jointItem }
end)
