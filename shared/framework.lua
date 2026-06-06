W2F.Framework = W2F.Framework or {}

local function resourceStarted(name)
    return GetResourceState(name) == 'started' or GetResourceState(name) == 'starting'
end

local function normalizeCoreName(name)
    if type(name) ~= 'string' then return 'auto' end
    name = string.lower(name)
    if name == 'qbx' or name == 'qbox' then return 'qbx_core' end
    if name == 'qb' or name == 'qbcore' then return 'qb-core' end
    if name == 'esx' or name == 'es_extended' then return 'esx' end
    return name
end

function W2F.Framework.GetCoreName()
    local configured = normalizeCoreName(Config.Framework and Config.Framework.Core or 'auto')

    if configured ~= 'auto' then
        if configured == 'qbx_core' and resourceStarted('qbx_core') then return 'qbx_core' end
        if configured == 'qb-core' and resourceStarted('qb-core') then return 'qb-core' end
        if configured == 'esx' and resourceStarted('es_extended') then return 'esx' end
        if configured == 'qbx_core' or configured == 'qb-core' or configured == 'esx' then
            return configured
        end
        return configured
    end

    if resourceStarted('qbx_core') then
        return 'qbx_core'
    end

    if resourceStarted('qb-core') then
        return 'qb-core'
    end

    if resourceStarted('es_extended') then
        return 'esx'
    end

    return nil
end

function W2F.Framework.IsQbox()
    return W2F.Framework.GetCoreName() == 'qbx_core'
end

function W2F.Framework.IsQBCore()
    return W2F.Framework.GetCoreName() == 'qb-core'
end

function W2F.Framework.IsESX()
    return W2F.Framework.GetCoreName() == 'esx'
end

function W2F.Framework.IsQbFamily()
    local core = W2F.Framework.GetCoreName()
    return core == 'qbx_core' or core == 'qb-core'
end
