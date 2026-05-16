CREATE TABLE IF NOT EXISTS w2f_weed_loyalty (
    citizenid VARCHAR(64) NOT NULL PRIMARY KEY,
    loyalty INT NOT NULL DEFAULT 0,
    successful_runs INT NOT NULL DEFAULT 0,
    failed_runs INT NOT NULL DEFAULT 0,
    bribes_given INT NOT NULL DEFAULT 0,
    last_contact INT DEFAULT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS w2f_weed_shipments (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    citizenid VARCHAR(64) NOT NULL,
    shipment_id VARCHAR(64) NOT NULL,
    location_id VARCHAR(64) NOT NULL,
    tier VARCHAR(32) NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'active',
    created_at INT NOT NULL,
    expires_at INT NOT NULL,
    completed_at INT DEFAULT NULL
);

CREATE TABLE IF NOT EXISTS w2f_weed_placeables (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    object_id VARCHAR(80) NOT NULL UNIQUE,
    citizenid VARCHAR(64) NOT NULL,
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
);

CREATE TABLE IF NOT EXISTS w2f_weed_planters (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    planter_id VARCHAR(80) NOT NULL UNIQUE,
    citizenid VARCHAR(64) NOT NULL,
    item VARCHAR(80) NOT NULL,
    model VARCHAR(120) NOT NULL,
    state VARCHAR(16) NOT NULL DEFAULT 'empty',
    x DOUBLE NOT NULL,
    y DOUBLE NOT NULL,
    z DOUBLE NOT NULL,
    heading DOUBLE NOT NULL DEFAULT 0,
    created_at INT NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_planter_owner (citizenid),
    INDEX idx_planter_state (state)
);

CREATE TABLE IF NOT EXISTS w2f_weed_plants (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    plant_id VARCHAR(80) NOT NULL UNIQUE,
    planter_id VARCHAR(80) NOT NULL,
    citizenid VARCHAR(64) NOT NULL,
    strain_id VARCHAR(64) NOT NULL,
    seed_item VARCHAR(80) NOT NULL,
    local_x DOUBLE NOT NULL DEFAULT 0,
    local_y DOUBLE NOT NULL DEFAULT 0,
    local_z DOUBLE NOT NULL DEFAULT 0,
    rotation DOUBLE NOT NULL DEFAULT 0,
    progress DOUBLE NOT NULL DEFAULT 0,
    stage INT NOT NULL DEFAULT 1,
    status VARCHAR(32) NOT NULL DEFAULT 'growing',
    planted_at INT NOT NULL,
    last_tick INT NOT NULL,
    metadata LONGTEXT DEFAULT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_plant_planter (planter_id),
    INDEX idx_plant_owner (citizenid),
    INDEX idx_plant_status (status)
);
