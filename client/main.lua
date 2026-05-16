local isReady = false

CreateThread(function()
    W2F.Debug('Initialising client...')

    while not NetworkIsSessionStarted() do
        Wait(100)
    end

    isReady = true
    W2F.Debug('Client ready.')
end)

--- Check if the client is fully initialised
---@return boolean
function W2F.IsClientReady()
    return isReady
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= W2F.Resource then return end

    W2F.Debug('Client cleanup starting...')
    W2F.CleanupContactPed()
    W2F.CleanupBlips()
    W2F.CleanupShipmentZone()
    W2F.CloseRollingMinigame()
    W2F.Debug('Client cleanup complete.')
end)
