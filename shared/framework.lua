W2F.Framework = W2F.Framework or {}

local function resourceStarted(name)
    return GetResourceState(name) == 'started' or GetResourceState(name) == 'starting'
end

function W2F.Framework.GetCoreName()
    local configured = Config.Framework and Config.Framework.Core or 'auto'

    if configured ~= 'auto' then
        return configured
    end

    -- Prefer Qbox first
    if resourceStarted('qbx_core') then
        return 'qbx_core'
    end

    if resourceStarted('qb-core') then
        return 'qb-core'
    end

    return nil
end

function W2F.Framework.IsQbox()
    return W2F.Framework.GetCoreName() == 'qbx_core'
end

function W2F.Framework.IsQBCore()
    return W2F.Framework.GetCoreName() == 'qb-core'
end
