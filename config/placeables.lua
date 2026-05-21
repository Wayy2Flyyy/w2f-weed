-- ─────────────────────────────────────────────
-- w2f-weed | Config | Placeables
--
-- Configuration for the placeable-prop module.
-- Each entry under Config.Placeables.Items maps an
-- ox_inventory item name to a GTA prop model and
-- the rules for placing/picking it up.
--
-- The whole module is intentionally generic so it
-- can later power the full weed growing/processing
-- system (plant pots become grow containers, drying
-- racks become processing stations, etc).
--
-- These are FICTIONAL GTA roleplay props ONLY.
-- ─────────────────────────────────────────────

Config = Config or {}

Config.Placeables = {
    Enabled = true,
    Debug   = false,

    Progress = {
        PlaceObject = 2500,
        PickupObject = 2500,
    },

    -- Allow /weed_placeables_clearall (DANGEROUS, off by default).
    AllowClearAll = false,

    -- ─── Controls ────────────────────────────
    -- Standard FiveM control IDs
    Controls = {
        Place        = 38,   -- E
        Cancel       = 177,  -- BACKSPACE
        RotateLeft   = 44,   -- Q
        RotateRight  = 175,  -- RIGHT ARROW
    },

    -- ─── Default placement rules (per-item override below) ─
    Placement = {
        DefaultDistance              = 1.8,
        DefaultHeightOffset          = 0.0,
        DefaultRotationSpeed         = 3.0,
        DefaultMaxDistanceFromPlayer = 4.0,
        RequireGround                = true,
        AllowInVehicle               = false,
        FreezePlacedObjects          = true,
        UseOutlinePreview            = true,
        PreviewAlpha                 = 165,
    },

    -- ─── Persistence ─────────────────────────
    Persistence = {
        Enabled            = true,
        SaveToDatabase     = true,
        LoadOnResourceStart = true,
        SyncOnPlayerJoin   = true,
    },

    -- ─── Limits ──────────────────────────────
    Limits = {
        Enabled                       = true,
        MaxObjectsPerPlayer           = 20,
        MaxObjectsGlobal              = 500,
        MinimumDistanceBetweenObjects = 1.5,
    },

    -- ─── Ownership ───────────────────────────
    Ownership = {
        UseQboxCitizenId  = true,
        OnlyOwnerCanPickup = true,
        AllowAdminPickup  = true,
        AllowPolicePickup = false,
    },

    -- ─── Security ────────────────────────────
    Security = {
        ValidateExactInventorySlot     = true,
        ValidateDistance               = true,
        ValidateItemWhitelist          = true,
        BlockPlacementInWater          = true,
        BlockPlacementInVehicle        = true,
        BlockBackpackOrContainerItems  = true,
        BlockInvalidModels             = true,
        ExploitAction                  = 'log',
    },

    -- ─── Items ───────────────────────────────
    -- Each key MUST match the ox_inventory item name.
    -- 'prop' is a model name joaat()-able.
    -- Per-item 'placement' overrides the defaults above.
    --
    -- NOTE: empty_planter_box / plant_pot / soil_bag are
    -- intentionally NOT in this list. They are owned by the planter
    -- growth system (see config/planters.lua) which handles their
    -- placement, soil-add, planting, growth, and harvest flows.
    Items = {
        watering_can = {
            label              = 'Watering Can',
            prop               = 'prop_wateringcan',
            removeItemOnPlace  = false,
            pickupEnabled      = true,
            giveItemOnPickup   = false,
            category           = 'tool',
            zOffset            = 0.0,

            placement = {
                distance              = 1.4,
                heightOffset          = 0.0,
                rotationSpeed         = 3.0,
                maxDistanceFromPlayer = 4.0,
            },
        },

        fertilizer_basic = {
            label              = 'Basic Fertilizer',
            prop               = 'prop_cs_fertilizer',
            removeItemOnPlace  = true,
            pickupEnabled      = true,
            giveItemOnPickup   = true,
            category           = 'supply',
            zOffset            = 0.0,
        },

        grow_light = {
            label              = 'Grow Light',
            prop               = 'prop_worklight_03b',
            removeItemOnPlace  = true,
            pickupEnabled      = true,
            giveItemOnPickup   = true,
            category           = 'equipment',
            zOffset            = 0.0,
        },

        drying_rack = {
            label              = 'Drying Rack',
            prop               = 'prop_rub_table_01',
            removeItemOnPlace  = true,
            pickupEnabled      = true,
            giveItemOnPickup   = true,
            category           = 'processing',
            zOffset            = 0.0,
        },

        weed_bench = {
            label              = 'Weed Work Bench',
            prop               = 'prop_tool_bench02',
            removeItemOnPlace  = true,
            pickupEnabled      = true,
            giveItemOnPickup   = true,
            category           = 'processing',
            zOffset            = 0.0,
        },
    },

    -- Seed planting is now owned by the planter growth system; see
    -- config/planters.lua and config/strains.lua.

    -- ─── Messages ────────────────────────────
    Messages = {
        NotPlaceable    = 'This item cannot be placed.',
        Cancelled       = 'Placement cancelled.',
        Placed          = 'Object placed.',
        TooFar          = 'You are too far away.',
        InvalidGround   = 'Could not find a valid ground position.',
        MissingItem     = 'You no longer have this item.',
        PickedUp        = 'Object picked up.',
        NotOwner        = 'You do not own this object.',
        LimitReached    = 'You have reached the placement limit.',
        TooClose        = 'Too close to another placed object.',
        Loaded          = 'Placeables loaded.',
        InVehicle       = 'You cannot place this from a vehicle.',
        InWater         = 'You cannot place this on water.',
        InventoryFull   = 'Your inventory is full.',
        InvalidModel    = 'Invalid prop model for this item.',
        ServerRejected  = 'Placement was rejected by the server.',
    },
}
