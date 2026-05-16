-- ─────────────────────────────────────────────
-- w2f-weed | Config | Planters
--
-- Configuration for the planter+plant growth system.
-- A planter is the world container; plants are
-- separate child objects placed at local offsets
-- on the planter's soil surface.
--
-- This is FICTIONAL GTA roleplay only.
-- ─────────────────────────────────────────────

Config = Config or {}

Config.Planters = {
    Enabled = true,
    Debug   = true,

    -- ─── Items ───────────────────────────────
    -- ox_inventory item names that map to planters / supplies.
    Items = {
        EmptyPlanter      = 'empty_planter_box',
        FilledMarker      = 'full_planter_box',  -- legacy item id; not required to use
        SoilBag           = 'soil_bag',
        TrimmingScissors  = 'trimming_scissors',
    },

    -- ─── Props ───────────────────────────────
    Props = {
        Empty  = 'empty_planter_box', -- custom streamed prop, see stream/
        Filled = 'planter_box',       -- custom streamed prop, see stream/
    },

    -- ─── Soil area (local space, relative to planter entity) ─
    -- Plants are placed on the x/y plane within these bounds.
    -- z is the height the plant prop sits above the planter base.
    SoilArea = {
        width   = 1.20,   -- total local x range
        length  = 0.65,   -- total local y range
        height  = 0.20,   -- visual proxy height (used for the soil zone)
        zOffset = 0.22,   -- vertical lift of the soil surface above planter origin
    },

    -- ─── Planting rules ──────────────────────
    Planting = {
        MaxPlantsPerPlanter = 6,
        MinimumPlantSpacing = 0.28,
        RequireSoil         = true,
        RequireSeed         = true,
        FreePlacement       = true,
        AllowRotation       = true,
    },

    -- ─── Harvest ───────────────────────────────
    Harvest = {
        --- Player must have ox_inventory item TrimmingScissors in inventory.
        RequireTrimmingScissors = true,
        --- If true, one pair is removed each harvest (usually keep false).
        ConsumeTrimmingScissors = false,
    },

    -- ─── Placement preview (planter itself) ─
    -- Used when the player USE's a plant_pot/empty_planter_box.
    PlanterPreview = {
        DefaultDistance              = 2.2,
        DefaultMaxDistanceFromPlayer = 4.5,
        RotationSpeed                = 3.0,
        RequireGround                = true,
        FreezePlacedObjects          = true,
        UseOutlinePreview            = true,
        PreviewAlpha                 = 165,
    },

    -- ─── Plant placement preview (inside soil) ─
    Preview = {
        Enabled       = true,
        Alpha         = 170,
        UseOutline    = true,
        OutlineColor  = { 110, 211, 243, 180 },
        OutlineInvalid = { 230, 70, 70, 200 },
        MoveSpeed     = 0.015,
        ConfirmKey    = 38,   -- E
        CancelKey     = 177,  -- BACKSPACE
        RotateLeftKey = 44,   -- Q
        RotateRightKey = 175, -- RIGHT ARROW
        -- Ghost local offset starts at the planter origin
        StartLocalX   = 0.0,
        StartLocalY   = 0.0,
    },

    -- ─── Security ────────────────────────────
    Security = {
        OnlyOwnerCanUse        = true,
        OnlyOwnerCanHarvest    = true,
        ValidateDistance       = true,
        MaxInteractionDistance = 3.0,
        ValidateSoilBounds     = true,
        ValidatePlantSpacing   = true,
        ValidateInventorySlot  = true,
        BlockPlacementInWater  = true,
        BlockPlacementInVehicle = true,
        AllowAdminPickup       = true,
        AllowPickupWithPlants  = false, -- pickup blocked while plants exist
    },

    -- ─── Limits ──────────────────────────────
    Limits = {
        MaxPlantersPerPlayer = 12,
        MaxPlantersGlobal    = 600,
        MinPlanterSpacing    = 1.5, -- min metres between two planters
    },

    -- ─── Persistence ─────────────────────────
    Persistence = {
        Enabled            = true,
        SaveToDatabase     = true,
        LoadOnResourceStart = true,
        SyncOnPlayerJoin   = true,
    },

    -- ─── Notifications ───────────────────────
    Messages = {
        PlanterPlaced      = 'Planter placed.',
        PlanterPickedUp    = 'Planter picked up.',
        PlanterHasPlants   = 'You must harvest or remove all plants first.',
        SoilAdded          = 'Soil added to planter.',
        NoSoilBag          = 'You do not have a soil bag.',
        AlreadyFilled      = 'This planter is already filled.',
        NotFilled          = 'This planter has no soil yet.',
        NoSeeds            = 'You do not have any seeds.',
        SeedRemoved        = 'Seed planted!',
        OutsideSoil        = 'Plant placement is outside the soil area.',
        TooClose           = 'Too close to another plant.',
        MaxPlantsReached   = 'This planter is full.',
        TooFar             = 'You are too far away.',
        InVehicle          = 'You cannot do that from a vehicle.',
        InWater            = 'You cannot place this on water.',
        NotOwner           = 'You do not own this planter.',
        InventoryFull      = 'Your inventory is full.',
        HarvestNotReady         = 'This plant is not ready yet.',
        MissingTrimmingScissors = 'You need trimming scissors to harvest.',
        HarvestComplete         = 'Plant harvested.',
        HarvestedPlanterBatch   = 'Harvested all mature plants from the planter.',
        FertilizerApplied  = 'Fertilizer applied.',
        MissingFertilizer  = 'You do not have that fertilizer.',
        PlantAlreadyReady  = 'This plant is already ready.',
        PlantRemoved       = 'Plant removed.',
        InvalidStrain      = 'Invalid seed.',
        ServerRejected     = 'Action rejected by the server.',
        Loaded             = 'Planters loaded.',
    },
}
