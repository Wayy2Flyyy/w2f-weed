-- ─────────────────────────────────────────────
-- w2f-weed | Config | Growth
--
-- Growth tick timing and stage thresholds.
-- The server is the only authority on growth.
-- Stage props are custom-streamed assets in
-- resources/[w2f]/w2f-weed/stream/plant-progress/
-- mapped to the model names below via .ytyp.
-- ─────────────────────────────────────────────

Config = Config or {}

Config.Growth = {
    Enabled = true,

    -- Server tick interval in minutes (catch-up runs once on resource start)
    -- With ProgressPerTick at 6, plants reach the harvestable "Ready" stage
    -- at ~15 minutes because stage 4 begins at 90 progress.
    TickMinutes = 1,

    -- Per-tick progress increment range (0-100 progress scale).
    ProgressPerTick = {
        Min = 6,
        Max = 6,
    },

    -- Fertilizer is applied through ox_target on plant props.
    -- It fast-forwards a single plant by the equivalent amount of growth time.
    Fertilizers = {
        fertilizer_basic = {
            label = 'Basic Fertilizer',
            decreaseMinutes = 5,
        },
        fertilizer_premium = {
            label = 'Premium Fertilizer',
            decreaseMinutes = 7,
        },
    },

    -- Replace the plant prop only when the stage changes.
    ReplacePropOnStageChange = true,

    -- ─────────────────────────────────────────
    -- Plant lifecycle (water + nutrients)
    -- Both values are kept on a 0-100 scale and decay every growth tick.
    -- Plants stop growing while either resource is depleted, start wilting,
    -- and eventually die if the player never tops them up.
    -- ─────────────────────────────────────────
    Lifecycle = {
        Enabled = true,

        Water = {
            Start          = 100, -- water level when the seed is planted
            DecayPerTick   = 6,   -- subtracted each growth tick
            WiltThreshold  = 25,  -- below this the plant is "thirsty"
            HealthHitAt0   = 8,   -- health lost per tick while water is 0
            WateringCanGain = 60, -- water restored each time you use the watering can
        },

        Nutrients = {
            Start            = 100,
            DecayPerTick     = 4,
            WiltThreshold    = 25,
            HealthHitAt0     = 6, -- health lost per tick while nutrients are 0
            FertilizerBasic  = 35, -- nutrient gain from fertilizer_basic
            FertilizerPremium = 55,
        },

        Health = {
            Start      = 100,
            -- A small passive heal while both resources are healthy.
            RegenPerTick = 2,
            -- Below this the plant prop colour can fade (cosmetic hook for later).
            WiltAt     = 40,
            -- At 0 health the plant is dead and cannot recover.
            DeadAt     = 0,
        },

        -- When water OR nutrients reach 0 we hold the growth value still.
        PauseGrowthWhenDepleted = true,
    },

    -- Bud amount when harvesting a fully grown plant (uses strain `budItem` only).
    -- Bias `high` rolls twice in [Min, Max] and takes the max so larger yields are more common.
    HarvestBud = {
        Min = 12,
        Max = 28,
        Bias = 'high', -- 'high' | 'uniform'
    },

    -- Order matters: stage [n] must have minProgress <= stage [n+1] minProgress.
    -- The first stage where progress < maxProgress wins; final stage is used at 100.
    --
    -- The `prop` values below are the internal archetype names defined in the
    -- corresponding .ytyp files inside stream/plant-progress/. Filenames
    -- match the archetype names, which is how FiveM resolves the model hash.
    -- If you want different names (e.g. w2f_weed_stage_1) you must rename the
    -- archetype inside the .ytyp using CodeWalker, not just the file on disk.
    -- These now use the base-game GTA "biker" weed plant props (from the
    -- Bikers DLC, present on every client — no streaming required). They read as
    -- realistic cannabis plants and grow in size across the four stages.
    -- The old custom props (small-plant/med-plant/finish-plant/ready-plant) are
    -- still streamed by the resource; restore them here if you prefer them.
    Stages = {
        [1] = {
            label       = 'Seedling',
            minProgress = 0,
            maxProgress = 24,
            prop        = 'bkr_prop_weed_01_small_01a',
            zOffset     = 0.00,
            harvestable = false,
        },
        [2] = {
            label       = 'Small Plant',
            minProgress = 25,
            maxProgress = 49,
            prop        = 'bkr_prop_weed_med_01b',
            zOffset     = 0.00,
            harvestable = false,
        },
        [3] = {
            label       = 'Growing Plant',
            minProgress = 50,
            maxProgress = 89,
            prop        = 'bkr_prop_weed_lrg_01b',
            zOffset     = 0.00,
            harvestable = false,
        },
        [4] = {
            label       = 'Ready',
            minProgress = 90,
            maxProgress = 100,
            prop        = 'bkr_prop_weed_lrg_01b',
            zOffset     = 0.00,
            harvestable = true,
        },
    },
}
