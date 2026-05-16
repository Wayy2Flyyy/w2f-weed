local activeZone = nil

--- Create an ox_lib sphere zone for shipment searching
---@param coords vector3
---@param radius number
function W2F.CreateSearchZone(coords, radius)
    W2F.RemoveSearchZone()

    activeZone = lib.zones.sphere({
        coords = coords,
        radius = radius or Config.Shipments.AreaRadius,
        debug = Config.Debug,
        onEnter = function()
            lib.notify({ title = 'Shipment', description = Locale('zone_entered'), type = 'info' })
        end,
        inside = function()
            if IsControlJustPressed(0, 38) then -- E key
                W2F.SearchShipment()
            end
        end,
        onExit = function()
            lib.notify({ title = 'Shipment', description = Locale('zone_exited'), type = 'info' })
        end
    })

    W2F.Debug('Search zone created at', coords)
end

--- Remove the active search zone
function W2F.RemoveSearchZone()
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
