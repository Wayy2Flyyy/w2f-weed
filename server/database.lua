--- Initialise database tables on resource start
function W2F.InitDatabase()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS w2f_weed_loyalty (
            citizenid VARCHAR(80) NOT NULL PRIMARY KEY,
            loyalty INT NOT NULL DEFAULT 0,
            successful_runs INT NOT NULL DEFAULT 0,
            failed_runs INT NOT NULL DEFAULT 0,
            bribes_given INT NOT NULL DEFAULT 0,
            last_contact INT DEFAULT NULL,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        )
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS w2f_weed_shipments (
            id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
            citizenid VARCHAR(80) NOT NULL,
            shipment_id VARCHAR(64) NOT NULL,
            location_id VARCHAR(64) NOT NULL,
            tier VARCHAR(32) NOT NULL,
            status VARCHAR(32) NOT NULL DEFAULT 'active',
            created_at INT NOT NULL,
            expires_at INT NOT NULL,
            completed_at INT DEFAULT NULL
        )
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS w2f_weed_placeables (
            id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
            object_id VARCHAR(80) NOT NULL UNIQUE,
            citizenid VARCHAR(80) NOT NULL,
            item VARCHAR(80) NOT NULL,
            model VARCHAR(120) NOT NULL,
            label VARCHAR(120) DEFAULT NULL,
            category VARCHAR(64) DEFAULT NULL,
            x DOUBLE NOT NULL,
            y DOUBLE NOT NULL,
            z DOUBLE NOT NULL,
            heading DOUBLE NOT NULL DEFAULT 0,
            metadata LONGTEXT DEFAULT NULL,
            created_at INT NOT NULL,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX idx_owner (citizenid)
        )
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS w2f_weed_planters (
            id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
            planter_id VARCHAR(80) NOT NULL UNIQUE,
            citizenid VARCHAR(80) NOT NULL,
            item VARCHAR(80) NOT NULL,
            model VARCHAR(120) NOT NULL,
            state VARCHAR(16) NOT NULL DEFAULT 'empty',
            soil_count INT NOT NULL DEFAULT 0,
            x DOUBLE NOT NULL,
            y DOUBLE NOT NULL,
            z DOUBLE NOT NULL,
            heading DOUBLE NOT NULL DEFAULT 0,
            created_at INT NOT NULL,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX idx_planter_owner (citizenid),
            INDEX idx_planter_state (state)
        )
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS w2f_weed_plants (
            id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
            plant_id VARCHAR(80) NOT NULL UNIQUE,
            planter_id VARCHAR(80) NOT NULL,
            citizenid VARCHAR(80) NOT NULL,
            strain_id VARCHAR(64) NOT NULL,
            seed_item VARCHAR(80) NOT NULL,
            local_x DOUBLE NOT NULL DEFAULT 0,
            local_y DOUBLE NOT NULL DEFAULT 0,
            local_z DOUBLE NOT NULL DEFAULT 0,
            rotation DOUBLE NOT NULL DEFAULT 0,
            progress DOUBLE NOT NULL DEFAULT 0,
            stage INT NOT NULL DEFAULT 1,
            status VARCHAR(32) NOT NULL DEFAULT 'growing',
            water DOUBLE NOT NULL DEFAULT 100,
            nutrients DOUBLE NOT NULL DEFAULT 100,
            health DOUBLE NOT NULL DEFAULT 100,
            planted_at INT NOT NULL,
            last_tick INT NOT NULL,
            metadata LONGTEXT DEFAULT NULL,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX idx_plant_planter (planter_id),
            INDEX idx_plant_owner (citizenid),
            INDEX idx_plant_status (status)
        )
    ]])

    -- Backwards-compatible migrations for installs created before lifecycle/soil changes.
    local migrations = {
        "ALTER TABLE w2f_weed_planters ADD COLUMN IF NOT EXISTS soil_count INT NOT NULL DEFAULT 0",
        "ALTER TABLE w2f_weed_plants   ADD COLUMN IF NOT EXISTS water DOUBLE NOT NULL DEFAULT 100",
        "ALTER TABLE w2f_weed_plants   ADD COLUMN IF NOT EXISTS nutrients DOUBLE NOT NULL DEFAULT 100",
        "ALTER TABLE w2f_weed_plants   ADD COLUMN IF NOT EXISTS health DOUBLE NOT NULL DEFAULT 100",
        "ALTER TABLE w2f_weed_loyalty   MODIFY COLUMN citizenid VARCHAR(80) NOT NULL",
        "ALTER TABLE w2f_weed_shipments MODIFY COLUMN citizenid VARCHAR(80) NOT NULL",
        "ALTER TABLE w2f_weed_placeables MODIFY COLUMN citizenid VARCHAR(80) NOT NULL",
        "ALTER TABLE w2f_weed_planters   MODIFY COLUMN citizenid VARCHAR(80) NOT NULL",
        "ALTER TABLE w2f_weed_plants     MODIFY COLUMN citizenid VARCHAR(80) NOT NULL",
    }
    for _, sql in ipairs(migrations) do
        pcall(function() MySQL.query.await(sql) end)
    end

    W2F.Debug('Database tables verified.')
end

--- Load loyalty data for a citizenid
---@param citizenid string
---@return table|nil
function W2F.LoadLoyalty(citizenid)
    local result = MySQL.single.await('SELECT * FROM w2f_weed_loyalty WHERE citizenid = ?', { citizenid })
    return result
end

--- Save or update loyalty data for a citizenid
---@param citizenid string
---@param loyalty number
function W2F.SaveLoyalty(citizenid, loyalty)
    MySQL.insert.await([[
        INSERT INTO w2f_weed_loyalty (citizenid, loyalty) VALUES (?, ?)
        ON DUPLICATE KEY UPDATE loyalty = ?, updated_at = CURRENT_TIMESTAMP
    ]], { citizenid, loyalty, loyalty })
end

--- Increment successful runs counter
---@param citizenid string
function W2F.IncrementSuccessfulRuns(citizenid)
    MySQL.update.await([[
        INSERT INTO w2f_weed_loyalty (citizenid, successful_runs) VALUES (?, 1)
        ON DUPLICATE KEY UPDATE successful_runs = successful_runs + 1, updated_at = CURRENT_TIMESTAMP
    ]], { citizenid })
end

--- Increment failed runs counter
---@param citizenid string
function W2F.IncrementFailedRuns(citizenid)
    MySQL.update.await([[
        INSERT INTO w2f_weed_loyalty (citizenid, failed_runs) VALUES (?, 1)
        ON DUPLICATE KEY UPDATE failed_runs = failed_runs + 1, updated_at = CURRENT_TIMESTAMP
    ]], { citizenid })
end

--- Increment bribes given counter
---@param citizenid string
function W2F.IncrementBribesGiven(citizenid)
    MySQL.update.await([[
        INSERT INTO w2f_weed_loyalty (citizenid, bribes_given) VALUES (?, 1)
        ON DUPLICATE KEY UPDATE bribes_given = bribes_given + 1, updated_at = CURRENT_TIMESTAMP
    ]], { citizenid })
end

--- Update last contact timestamp
---@param citizenid string
function W2F.UpdateLastContact(citizenid)
    MySQL.update.await([[
        INSERT INTO w2f_weed_loyalty (citizenid, last_contact) VALUES (?, ?)
        ON DUPLICATE KEY UPDATE last_contact = ?, updated_at = CURRENT_TIMESTAMP
    ]], { citizenid, W2F.GetTimestamp(), W2F.GetTimestamp() })
end

--- Insert a shipment record into history
---@param data table
function W2F.InsertShipmentRecord(data)
    MySQL.insert.await([[
        INSERT INTO w2f_weed_shipments (citizenid, shipment_id, location_id, tier, status, created_at, expires_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], {
        data.citizenid,
        data.shipmentId,
        data.locationId,
        data.tier,
        data.status or W2F.ShipmentStatus.Active,
        data.createdAt,
        data.expiresAt
    })
end

--- Load every shipment row still flagged active (used to rehydrate memory after
--- a resource/server restart so in-progress runs are not silently lost).
---@return table[]
function W2F.LoadActiveShipments()
    local rows = MySQL.query.await([[
        SELECT citizenid, shipment_id, location_id, tier, created_at, expires_at
        FROM w2f_weed_shipments WHERE status = ?
    ]], { W2F.ShipmentStatus.Active })
    return rows or {}
end

--- Update shipment status in the database
---@param shipmentId string
---@param status string
function W2F.UpdateShipmentStatus(shipmentId, status)
    local completedAt = nil
    if status == W2F.ShipmentStatus.Completed then
        completedAt = W2F.GetTimestamp()
    end

    MySQL.update.await([[
        UPDATE w2f_weed_shipments SET status = ?, completed_at = ? WHERE shipment_id = ?
    ]], { status, completedAt, shipmentId })
end
