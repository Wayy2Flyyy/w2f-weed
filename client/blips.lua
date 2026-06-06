local contactBlip = nil
local contractorSuppliesBlip = nil

--- Create a blip for the contact if configured
function W2F.CreateContactBlip()
    if not Config.Contact.UseBlip then return end
    if contactBlip then return end

    local coords = Config.Contact.Coords
    contactBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(contactBlip, 140)
    SetBlipDisplay(contactBlip, 4)
    SetBlipScale(contactBlip, 0.7)
    SetBlipColour(contactBlip, 2)
    SetBlipAsShortRange(contactBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(Config.Contact.Name)
    EndTextCommandSetBlipName(contactBlip)

    W2F.Debug('Contact blip created.')
end

--- Remove the contact blip
function W2F.RemoveContactBlip()
    if contactBlip then
        RemoveBlip(contactBlip)
        contactBlip = nil
        W2F.Debug('Contact blip removed.')
    end
end

--- Loyalty-unlocked contractor supplies location (ox shop target).
---@param show boolean
function W2F.SetContractorSuppliesBlip(show)
    local had = contractorSuppliesBlip ~= nil
    if contractorSuppliesBlip then
        RemoveBlip(contractorSuppliesBlip)
        contractorSuppliesBlip = nil
    end

    if not show then
        if had then
            W2F.Debug('Contractor supplies blip hidden.')
        end
        return
    end

    local cfg = Config.Loyalty and Config.Loyalty.ContractorSupplies
    if not cfg or not cfg.Coords then return end

    local b = cfg.Blip or {}
    local c = cfg.Coords

    contractorSuppliesBlip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(contractorSuppliesBlip, b.sprite or 478)
    SetBlipDisplay(contractorSuppliesBlip, 4)
    SetBlipScale(contractorSuppliesBlip, b.scale or 0.7)
    SetBlipColour(contractorSuppliesBlip, b.colour or 2)
    SetBlipAsShortRange(contractorSuppliesBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(b.label or 'Contractor supplies')
    EndTextCommandSetBlipName(contractorSuppliesBlip)

    W2F.Debug('Contractor supplies blip created.')
end

RegisterNetEvent('w2f-weed:client:setContractorSuppliesBlip', function(show)
    W2F.SetContractorSuppliesBlip(show and true or false)
end)

--- Cleanup all managed blips
function W2F.CleanupBlips()
    W2F.RemoveContactBlip()
    W2F.SetContractorSuppliesBlip(false)
end

CreateThread(function()
    while not W2F.IsClientReady() do
        Wait(200)
    end

    W2F.CreateContactBlip()
end)
