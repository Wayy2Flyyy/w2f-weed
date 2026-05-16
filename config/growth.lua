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

    -- Server tick interval in minutes (catch-up runs once on resource start).
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
    Stages = {
        [1] = {
            label       = 'Seedling',
            minProgress = 0,
            maxProgress = 24,
            prop        = 'small-plant',
            zOffset     = 0.00,
            harvestable = false,
        },
        [2] = {
            label       = 'Small Plant',
            minProgress = 25,
            maxProgress = 49,
            prop        = 'med-plant',
            zOffset     = 0.02,
            harvestable = false,
        },
        [3] = {
            label       = 'Growing Plant',
            minProgress = 50,
            maxProgress = 89,
            prop        = 'finish-plant',
            zOffset     = 0.04,
            harvestable = false,
        },
        [4] = {
            label       = 'Ready',
            minProgress = 90,
            maxProgress = 100,
            prop        = 'ready-plant',
            zOffset     = 0.06,
            harvestable = true,
        },
    },
}
