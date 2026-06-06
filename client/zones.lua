local activeZone = nil
local insideZone = false

--- Build the persistent search prompt, showing live progress when known.
local function searchLabel()
    if W2F.GetShipmentProgress then
        local done, required = W2F.GetShipmentProgress()
        if required and required > 0 then
            return Locale('zone_search_textui', done or 0, required)
        end
    end
    return Locale('zone_entered')
end

--- Re-render the search TextUI in place (called when progress changes).
function W2F.RefreshSearchTextUI()
    if insideZone then
        lib.showTextUI(searchLabel(), { position = 'top-center' })
    end
end

--- Create an ox_lib sphere zone for shipment searching.
--- Uses a persistent TextUI prompt instead of enter/exit toast spam.
---@param coords vector3
---@param radius number
function W2F.CreateSearchZone(coords, radius)
    W2F.RemoveSearchZone()

    activeZone = lib.zones.sphere({
        coords = coords,
        radius = radius or Config.Shipments.AreaRadius,
        debug = Config.Debug,
        onEnter = function()
            insideZone = true
            lib.showTextUI(searchLabel(), { position = 'top-center' })
        end,
        inside = function()
            if IsControlJustPressed(0, 38) then -- E key
                W2F.SearchShipment()
            end
        end,
        onExit = function()
            insideZone = false
            lib.hideTextUI()
        end
    })

    W2F.Debug('Search zone created at', coords)
end

--- Remove the active search zone
function W2F.RemoveSearchZone()
    if insideZone then
        lib.hideTextUI()
    end
    insideZone = false
    if activeZone then
        activeZone:remove()
        activeZone = nil
        W2F.Debug('Search zone removed.')
    end
end

RegisterNetEvent('w2f-weed:client:setShipment', function(data)
    if not data or not data.coords then return end
    W2F.CreateSearchZone(data.coords, data.radius or Config.Shipments.AreaRadius)
end)

RegisterNetEvent('w2f-weed:client:clearShipment', function()
    W2F.RemoveSearchZone()
end)

RegisterNetEvent('w2f-weed:client:shipmentCompleted', function()
    W2F.RemoveSearchZone()
end)
