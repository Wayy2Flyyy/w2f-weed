local contactPed = nil

--- Spawn the contact ped at the configured location
function W2F.SpawnContactPed()
    if not Config.Contact.Enabled or not Config.Contact.UsePed then return end
    if contactPed and DoesEntityExist(contactPed) then return end

    local cfg = Config.Contact
    local model = joaat(cfg.Ped.Model)

    lib.requestModel(model)

    contactPed = CreatePed(4, model, cfg.Coords.x, cfg.Coords.y, cfg.Coords.z - 1.0, cfg.Coords.w, false, true)

    if cfg.Ped.Frozen then
        FreezeEntityPosition(contactPed, true)
    end

    if cfg.Ped.Invincible then
        SetEntityInvincible(contactPed, true)
    end

    if cfg.Ped.BlockingEvents then
        SetBlockingOfNonTemporaryEvents(contactPed, true)
    end

    if cfg.Ped.Scenario then
        TaskStartScenarioInPlace(contactPed, cfg.Ped.Scenario, 0, true)
    end

    SetEntityAsMissionEntity(contactPed, true, true)
    SetModelAsNoLongerNeeded(model)

    W2F.Debug('Contact ped spawned at', cfg.Coords)
end

--- Remove the contact ped from the world
function W2F.CleanupContactPed()
    if contactPed and DoesEntityExist(contactPed) then
        DeleteEntity(contactPed)
        W2F.Debug('Contact ped removed.')
    end
    contactPed = nil
end

--- Get the contact ped entity handle
---@return integer|nil
function W2F.GetContactPed()
    return contactPed
end

CreateThread(function()
    while not W2F.IsClientReady() do
        Wait(200)
    end

    W2F.SpawnContactPed()
end)
