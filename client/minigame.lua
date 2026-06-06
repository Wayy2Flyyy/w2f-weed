--- Rolling Station NUI (install_weed_minigame)

local nuiOpen = false

--- Rolling station is active only when both the processing master flag and the
--- module flag are on.
local function rollingEnabled()
    if not (Config.RollingMinigame and Config.RollingMinigame.Enabled) then return false end
    return W2F.Foundation('EnableProcessing')
end

local function describeContextFail(reason)
    local key = ({
        disabled = 'rolling_err_disabled',
        no_buds = 'rolling_err_no_buds',
        no_papers = 'rolling_err_no_papers',
        config = 'rolling_err_config',
        player = 'rolling_err_generic',
    })[reason or ''] or 'rolling_err_generic'
    return Locale(key)
end

local function describeRewardFail(reason)
    local key = ({
        disabled = 'rolling_err_disabled',
        quality = 'rolling_err_quality',
        no_buds = 'rolling_err_no_buds',
        no_papers = 'rolling_err_no_papers',
        carry = 'rolling_err_carry',
        strain = 'rolling_err_strain',
        joint_config = 'rolling_err_config',
        give_failed = 'rolling_err_config',
    })[reason or ''] or 'rolling_err_generic'
    return Locale(key)
end

function W2F.CloseRollingMinigame()
    nuiOpen = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'closeRolling' })
end

--- Practice: all catalogue strains, no reward.
function W2F.OpenRollingPractice()
    if not rollingEnabled() then
        lib.notify({
            title = Locale('rolling_menu_title'),
            description = Locale('rolling_err_disabled'),
            type = 'error',
            position = 'top',
        })
        return
    end
    if nuiOpen then return end
    nuiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openRolling', mode = 'practice' })
end

--- Craft: only strains the player currently has buds for; papers required per server config.
function W2F.OpenRollingCraft()
    if not rollingEnabled() then
        lib.notify({
            title = Locale('rolling_menu_title'),
            description = Locale('rolling_err_disabled'),
            type = 'error',
            position = 'top',
        })
        return
    end
    if nuiOpen then return end

    lib.callback('w2f-weed:server:rollingMinigameContext', false, function(ctx)
        if not ctx or not ctx.ok then
            lib.notify({
                title = Locale('rolling_menu_title'),
                description = describeContextFail(ctx and ctx.reason),
                type = 'error',
                position = 'top',
            })
            return
        end
        nuiOpen = true
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'openRolling',
            mode = 'craft',
            strains = ctx.strains,
            budsPerJoint = ctx.budsPerJoint,
            hasRollingPaper = ctx.hasRollingPaper,
            hasRollingPaperFlag = ctx.hasRollingPaperFlag,
            openHintNoPaper = ctx.openHintNoPaper,
        })
    end)
end

RegisterNUICallback('rollingExit', function(_, cb)
    W2F.CloseRollingMinigame()
    if cb then cb({ ok = true }) end
end)

RegisterNUICallback('rollingComplete', function(data, cb)
    lib.callback('w2f-weed:server:rollingMinigameReward', false, function(result)
        if result and result.ok then
            W2F.CloseRollingMinigame()
            local desc = string.format(
                Locale('rolling_success_fmt'),
                Config.RollingMinigame.BudsPerJoint or 3,
                Config.RollingMinigame.PapersPerJoint or 1
            )
            if result.bonus then
                desc = desc .. ' ' .. Locale('rolling_bonus_joint')
            end
            lib.notify({
                title = Locale('rolling_menu_title'),
                description = desc,
                type = 'success',
                position = 'top',
            })
        else
            lib.notify({
                title = Locale('rolling_menu_title'),
                description = describeRewardFail(result and result.reason),
                type = 'error',
                position = 'top',
            })
        end
        if cb then cb(result or { ok = false }) end
    end, data or {})
end)

--- Fired from ox_inventory USE on `rolling_tray` item.
RegisterNetEvent('w2f-weed:client:startRollingMinigameFromTray', function()
    W2F.OpenRollingCraft()
end)

if Config.RollingMinigame and Config.RollingMinigame.DebugCommand then
    RegisterCommand('weed_roll', function()
        W2F.OpenRollingPractice()
    end, false)
end
