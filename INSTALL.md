# w2f-weed installation

Qbox (`qbx_core`) + QBCore (`qb-core`) weed operation resource for contact shipments, loyalty, planters, placeables, optional shop hooks, and the rolling-station NUI.

## Quick Start

1. Put the folder in `resources/[w2f]/w2f-weed` and keep the resource name exactly `w2f-weed`.
2. Run `sql/install.sql` once in the same database used by `oxmysql`.
3. Paste the full `items.lua` block below inside `resources/[ox]/ox_inventory/data/items.lua` inside the `return { ... }` table.
4. Paste or merge the `shops.lua` snippets below inside `resources/[ox]/ox_inventory/data/shops.lua` inside the `return { ... }` table.
5. Start resources in this order:

```cfg
ensure oxmysql
ensure ox_lib
ensure ox_inventory
ensure ox_target
ensure qbx_core
ensure w2f-weed
```

QBCore startup order:

```cfg
ensure oxmysql
ensure ox_lib
ensure ox_inventory
ensure ox_target
ensure qb-core
ensure w2f-weed
```

After editing `items.lua` or `shops.lua`, run:

```cfg
restart ox_inventory
restart w2f-weed
```

## ox_inventory `items.lua`

Paste this whole block into `data/items.lua` inside the main `return { ... }` table.

Do not duplicate item keys that already exist. If your server already has `rolling_papers`, `joint`, or another shared item, keep one version only. The `rolling_tray` item must keep `client.event = 'w2f-weed:client:startRollingMinigameFromTray'`.

```lua
    -- ======================================================================
    -- W2F WEED - Rolling supplies
    -- ======================================================================

    ['rolling_papers'] = {
        label = 'Rolling Papers',
        weight = 5,
        stack = true,
        close = true,
        description = 'A pack of papers for rolling joints. Use with a rolling tray and bud.',
    },

    ['rolling_tray'] = {
        label = 'Rolling Tray',
        weight = 800,
        stack = false,
        close = true,
        consume = 0,
        description = 'A tray for breaking down bud and rolling. USE to open the rolling station.',
        client = {
            event = 'w2f-weed:client:startRollingMinigameFromTray',
        },
    },

    ['blunt_leafs'] = {
        label = 'Blunt Wraps',
        weight = 8,
        stack = true,
        close = true,
        description = 'Outer wraps for rolling blunt cannons.',
    },

    -- ======================================================================
    -- W2F WEED - Seeds
    -- ======================================================================

    ['purple_runtz_seed'] = {
        label = 'Purple Runtz Seed',
        weight = 10,
        stack = true,
        description = 'A common seed variety. Reliable but modest yields.',
    },

    ['skunk_seed'] = {
        label = 'Skunk Seed',
        weight = 10,
        stack = true,
        description = 'A pungent seed strain. Moderate quality.',
    },

    ['hybrid_seed'] = {
        label = 'Hybrid Seed',
        weight = 10,
        stack = true,
        description = 'A crossbred seed. Balanced traits.',
    },

    ['purple_palm_tree_delight_seed'] = {
        label = 'Purple Palm Tree Delight Seed',
        weight = 10,
        stack = true,
        description = 'A high-grade seed. Superior quality.',
    },

    ['exotic_seed'] = {
        label = 'Exotic Seed',
        weight = 10,
        stack = true,
        description = 'A rare seed variety. Exceptional traits.',
    },

    -- ======================================================================
    -- W2F WEED - Buds and bud batches
    -- ======================================================================

    ['purple_runtz_bud'] = {
        label = 'Purple Runtz Bud',
        weight = 50,
        stack = true,
        description = 'Purple Runtz processed bud.',
    },

    ['skunk_bud'] = {
        label = 'Skunk Bud',
        weight = 50,
        stack = true,
        description = 'Skunk processed bud.',
    },

    ['hybrid_bud'] = {
        label = 'Hybrid Bud',
        weight = 50,
        stack = true,
        description = 'Hybrid processed bud.',
    },

    ['purple_palm_tree_delight_bud'] = {
        label = 'Purple Palm Tree Delight Bud',
        weight = 50,
        stack = true,
        description = 'Purple Palm Tree Delight processed bud.',
    },

    ['exotic_bud'] = {
        label = 'Exotic Bud',
        weight = 50,
        stack = true,
        description = 'Exotic processed bud.',
    },

    ['batch_purple_runtz_bud'] = {
        label = 'Batch of Purple Runtz Buds',
        weight = 1000,
        stack = true,
        description = 'A batch of purple runtz processed buds.',
    },

    ['batch_skunk_bud'] = {
        label = 'Batch of Skunk Buds',
        weight = 1000,
        stack = true,
        description = 'A batch of skunk processed buds.',
    },

    ['batch_hybrid_bud'] = {
        label = 'Batch of Hybrid Buds',
        weight = 1000,
        stack = true,
        description = 'A batch of hybrid processed buds.',
    },

    ['batch_exotic_bud'] = {
        label = 'Batch of Exotic Buds',
        weight = 1000,
        stack = true,
        description = 'A batch of exotic processed buds.',
    },

    -- ======================================================================
    -- W2F WEED - Joints
    -- Used by config/rolling.lua -> Config.RollingMinigame.JointItems
    -- ======================================================================

    ['joint_exotic_weed'] = {
        label = 'Exotic Weed Joint',
        weight = 3,
        stack = true,
        close = true,
        description = 'A hand-rolled joint packed with exotic-grade weed.',
        client = {
            status = { stress = -120000 },
            anim = { dict = 'amb@world_human_aa_smoke@male@idle_a', clip = 'idle_c' },
            prop = {
                model = `p_cs_joint_02`,
                pos = vec3(0.015, 0.015, 0.0),
                rot = vec3(0.0, 0.0, 0.0),
            },
            usetime = 4500,
        },
    },

    ['joint_purple_palm_tree_delight'] = {
        label = 'Purple Palm Tree Delight Joint',
        weight = 3,
        stack = true,
        close = true,
        description = 'A smooth purple strain joint with a rich palm-tree sweetness.',
        client = {
            status = { stress = -140000 },
            anim = { dict = 'amb@world_human_aa_smoke@male@idle_a', clip = 'idle_c' },
            prop = {
                model = `p_cs_joint_02`,
                pos = vec3(0.015, 0.015, 0.0),
                rot = vec3(0.0, 0.0, 0.0),
            },
            usetime = 4500,
        },
    },

    ['joint_hybrid'] = {
        label = 'Hybrid Joint',
        weight = 3,
        stack = true,
        close = true,
        description = 'A balanced hybrid joint with a clean, steady smoke.',
        client = {
            status = { stress = -100000 },
            anim = { dict = 'amb@world_human_aa_smoke@male@idle_a', clip = 'idle_c' },
            prop = {
                model = `p_cs_joint_02`,
                pos = vec3(0.015, 0.015, 0.0),
                rot = vec3(0.0, 0.0, 0.0),
            },
            usetime = 4500,
        },
    },

    ['joint_skunk'] = {
        label = 'Skunk Joint',
        weight = 3,
        stack = true,
        close = true,
        description = 'A strong-smelling skunk joint with a heavy street-grade kick.',
        client = {
            status = { stress = -130000 },
            anim = { dict = 'amb@world_human_aa_smoke@male@idle_a', clip = 'idle_c' },
            prop = {
                model = `p_cs_joint_02`,
                pos = vec3(0.015, 0.015, 0.0),
                rot = vec3(0.0, 0.0, 0.0),
            },
            usetime = 4500,
        },
    },

    ['joint_purple_runtz'] = {
        label = 'Purple Runtz Joint',
        weight = 3,
        stack = true,
        close = true,
        description = 'A colourful Purple Runtz joint with a sweet candy-like aroma.',
        client = {
            status = { stress = -150000 },
            anim = { dict = 'amb@world_human_aa_smoke@male@idle_a', clip = 'idle_c' },
            prop = {
                model = `p_cs_joint_02`,
                pos = vec3(0.015, 0.015, 0.0),
                rot = vec3(0.0, 0.0, 0.0),
            },
            usetime = 4500,
        },
    },

    -- ======================================================================
    -- W2F WEED - Blunt cannons
    -- ======================================================================

    ['blunt_exotic_weed'] = {
        label = 'Exotic Weed Blunt Cannon',
        weight = 8,
        stack = true,
        close = true,
        description = 'A premium crest-leaf blunt cannon packed with exotic weed.',
        client = {
            status = { stress = -150000 },
            anim = { dict = 'amb@world_human_aa_smoke@male@idle_a', clip = 'idle_c' },
            prop = {
                model = `p_cs_joint_02`,
                pos = vec3(0.015, 0.015, 0.0),
                rot = vec3(0.0, 0.0, 0.0),
            },
            usetime = 5500,
        },
    },

    ['blunt_purple_palm_tree_delight'] = {
        label = 'Purple Palm Tree Delight Blunt Cannon',
        weight = 8,
        stack = true,
        close = true,
        description = 'A luxury crest-leaf blunt cannon with a smooth purple palm finish.',
        client = {
            status = { stress = -165000 },
            anim = { dict = 'amb@world_human_aa_smoke@male@idle_a', clip = 'idle_c' },
            prop = {
                model = `p_cs_joint_02`,
                pos = vec3(0.015, 0.015, 0.0),
                rot = vec3(0.0, 0.0, 0.0),
            },
            usetime = 5500,
        },
    },

    ['blunt_hybrid'] = {
        label = 'Hybrid Blunt Cannon',
        weight = 8,
        stack = true,
        close = true,
        description = 'A balanced crest-leaf blunt cannon rolled with premium hybrid flower.',
        client = {
            status = { stress = -135000 },
            anim = { dict = 'amb@world_human_aa_smoke@male@idle_a', clip = 'idle_c' },
            prop = {
                model = `p_cs_joint_02`,
                pos = vec3(0.015, 0.015, 0.0),
                rot = vec3(0.0, 0.0, 0.0),
            },
            usetime = 5500,
        },
    },

    ['blunt_skunk'] = {
        label = 'Skunk Blunt Cannon',
        weight = 8,
        stack = true,
        close = true,
        description = 'A loud crest-leaf blunt cannon rolled with heavy skunk flower.',
        client = {
            status = { stress = -145000 },
            anim = { dict = 'amb@world_human_aa_smoke@male@idle_a', clip = 'idle_c' },
            prop = {
                model = `p_cs_joint_02`,
                pos = vec3(0.015, 0.015, 0.0),
                rot = vec3(0.0, 0.0, 0.0),
            },
            usetime = 5500,
        },
    },

    ['blunt_purple_runtz'] = {
        label = 'Purple Runtz Blunt Cannon',
        weight = 8,
        stack = true,
        close = true,
        description = 'A sweet purple crest-leaf blunt cannon with premium Purple Runtz flower.',
        client = {
            status = { stress = -175000 },
            anim = { dict = 'amb@world_human_aa_smoke@male@idle_a', clip = 'idle_c' },
            prop = {
                model = `p_cs_joint_02`,
                pos = vec3(0.015, 0.015, 0.0),
                rot = vec3(0.0, 0.0, 0.0),
            },
            usetime = 5500,
        },
    },

    -- ======================================================================
    -- W2F WEED - Planters, supplies, tools, and placeables
    -- ======================================================================

    ['empty_planter_box'] = {
        label = 'Empty Planter Box',
        weight = 8000,
        stack = false,
        consume = 0,
        description = 'A wooden planter box. USE to deploy.',
        client = {
            event = 'w2f-weed:client:startPlanterPlacement',
        },
    },

    ['plant_pot'] = {
        label = 'Plant Pot',
        weight = 500,
        stack = true,
        consume = 0,
        description = 'A wooden plant pot. USE to deploy as a planter.',
        client = {
            event = 'w2f-weed:client:startPlanterPlacement',
        },
    },

    ['soil_bag'] = {
        label = 'Soil Bag',
        weight = 1000,
        stack = true,
        description = 'A bag of soil. Use the Add Soil interaction on an empty planter.',
    },

    ['watering_can'] = {
        label = 'Watering Can',
        weight = 750,
        stack = true,
        consume = 0,
        description = 'A watering can for plant care.',
        client = {
            event = 'w2f-weed:client:startPlaceablePlacement',
        },
    },

    ['fertilizer_basic'] = {
        label = 'Basic Fertilizer',
        weight = 2000,
        stack = true,
        consume = 0,
        description = 'Standard plant nutrients.',
        client = {
            event = 'w2f-weed:client:startPlaceablePlacement',
        },
    },

    ['fertilizer_premium'] = {
        label = 'Premium Fertilizer',
        weight = 2000,
        stack = true,
        description = 'Enhanced plant nutrients for faster growth.',
    },

    ['grow_light'] = {
        label = 'Grow Light',
        weight = 4000,
        stack = true,
        consume = 0,
        description = 'Artificial lighting for indoor growing.',
        client = {
            event = 'w2f-weed:client:startPlaceablePlacement',
        },
    },

    ['drying_rack'] = {
        label = 'Drying Rack',
        weight = 5000,
        stack = false,
        consume = 0,
        description = 'Used to dry harvested plants.',
        client = {
            event = 'w2f-weed:client:startPlaceablePlacement',
        },
    },

    ['weed_bench'] = {
        label = 'Weed Work Bench',
        weight = 12000,
        stack = false,
        consume = 0,
        description = 'A sturdy bench for trimming and processing. USE to place.',
        client = {
            event = 'w2f-weed:client:startPlaceablePlacement',
        },
    },

    ['trimming_scissors'] = {
        label = 'Trimming Scissors',
        weight = 300,
        stack = false,
        description = 'Required to harvest mature plants from planters. Also used to trim dried plants.',
    },

    ['empty_baggies'] = {
        label = 'Empty Baggies',
        weight = 10,
        stack = true,
        description = 'Packaging for processed product.',
    },

    ['digital_scale'] = {
        label = 'Digital Scale',
        weight = 500,
        stack = false,
        description = 'Used to weigh product.',
    },
```

## ox_inventory `shops.lua`

Paste these shop entries into `data/shops.lua` inside the main `return { ... }` table.

If your server already has a `YouTool` shop, merge only the inventory/target lines you need. Do not register the same shop key twice.

### SmokeOnTheWater - Retail Shop

Open retail shop for rolling supplies, growing supplies, joints, and blunts.

```lua
    -- Vespucci - joints + blunt cannons (w2f-weed items).
    SmokeOnTheWater = {
        name = 'Smoke on the Water',
        blip = {
            id = 59, colour = 2, scale = 0.75,
        },
        inventory = {
            { name = 'rolling_papers', price = 12 },
            { name = 'rolling_tray', price = 78 },
            { name = 'blunt_leafs', price = 18 },
            { name = 'soil_bag', price = 2000 },
            { name = 'watering_can', price = 200 },
            { name = 'fertilizer_basic', price = 250 },
            { name = 'fertilizer_premium', price = 500 },
            { name = 'empty_baggies', price = 50 },
            { name = 'digital_scale', price = 300 },
            { name = 'trimming_scissors', price = 100 },
            { name = 'joint_hybrid', price = 28 },
            { name = 'joint_exotic_weed', price = 32 },
            { name = 'joint_skunk', price = 36 },
            { name = 'joint_purple_palm_tree_delight', price = 42 },
            { name = 'joint_purple_runtz', price = 48 },
            { name = 'blunt_hybrid', price = 65 },
            { name = 'blunt_skunk', price = 72 },
            { name = 'blunt_exotic_weed', price = 78 },
            { name = 'blunt_purple_palm_tree_delight', price = 88 },
            { name = 'blunt_purple_runtz', price = 95 },
        },
        locations = {
            vec3(-1172.18, -1571.77, 3.66),
        },
        targets = {
            { loc = vec3(-1172.18, -1571.77, 3.66), length = 0.65, width = 0.55, heading = 305.0, minZ = 3.48, maxZ = 4.18, distance = 1.85 },
        },
    },
```

### SmokeOnTheWaterContractor - Loyalty Gated Shop

This shop key must stay `SmokeOnTheWaterContractor`. It is used by `server/ox_inventory_shop.lua`.

Players need loyalty >= `Config.Loyalty.ContractorSuppliesMinLoyalty` (default `3`) before contractor buys register.

Keep these coordinates aligned with `config/loyalty.lua` -> `Config.Loyalty.ContractorSupplies`.

```lua
    -- Requires w2f-weed contact loyalty >= Config.Loyalty.ContractorSuppliesMinLoyalty.
    SmokeOnTheWaterContractor = {
        name = 'Contractor supplies',
        icon = 'fa-solid fa-toolbox',
        inventory = {
            { name = 'empty_planter_box', price = 4200 },
            { name = 'weed_bench', price = 6200 },
        },
        locations = {
            vec3(-1227.56, -1406.1, 3.18),
        },
        targets = {
            -- ox_inventory spawns this ped and ox_target handles the shop interaction.
            {
                ped = `s_m_y_construct_01`,
                loc = vec3(-1227.56, -1406.1, 3.18),
                heading = 305.0,
                scenario = 'WORLD_HUMAN_CLIPBOARD',
                distance = 2.0,
            },
        },
    },
```

### YouTool - Optional W2F Weed Supply Lines

Use this if you want common `w2f-weed` grow supplies at YouTool too. Paste these lines into your existing `YouTool.inventory` list. Do not copy a full `YouTool = { ... }` entry unless you are replacing your whole shop.

```lua
            { name = 'soil_bag', price = 2000 },
            { name = 'watering_can', price = 200 },
            { name = 'fertilizer_basic', price = 250 },
            { name = 'fertilizer_premium', price = 500 },
            { name = 'empty_baggies', price = 50 },
            { name = 'digital_scale', price = 300 },
            { name = 'trimming_scissors', price = 100 },
```

## Item Categories At A Glance

Use this list to quickly check what the resource expects.

```text
Rolling supplies:
rolling_papers, rolling_tray, blunt_leafs

Seeds:
purple_runtz_seed, skunk_seed, hybrid_seed, purple_palm_tree_delight_seed, exotic_seed

Buds:
purple_runtz_bud, skunk_bud, hybrid_bud, purple_palm_tree_delight_bud, exotic_bud

Bud batches:
batch_purple_runtz_bud, batch_skunk_bud, batch_hybrid_bud, batch_exotic_bud

Joints:
joint_exotic_weed, joint_purple_palm_tree_delight, joint_hybrid, joint_skunk, joint_purple_runtz

Blunt cannons:
blunt_exotic_weed, blunt_purple_palm_tree_delight, blunt_hybrid, blunt_skunk, blunt_purple_runtz

Planters, placeables, supplies:
empty_planter_box, plant_pot, soil_bag, watering_can, fertilizer_basic, fertilizer_premium, grow_light, drying_rack, weed_bench, trimming_scissors, empty_baggies, digital_scale
```

Notes:

- `batch_purple_palm_tree_delight_bud` is not used by the stock config.
- `install_assets/README.md` lists optional PNG names for ox_inventory item icons.

## Resource Checklist

1. Import `sql/install.sql`.
2. Add the `items.lua` block.
3. Add or merge the `shops.lua` blocks.
4. Keep `SmokeOnTheWaterContractor` aligned with `config/loyalty.lua`.
5. Keep `Config.RollingMinigame.OpenItemKey = 'rolling_tray'` unless you also rename the item.
6. Keep `Config.RollingMinigame.PaperItem = 'rolling_papers'` unless you also rename the item.
7. Register any packaged streamed `.ytyp` files already listed in `fxmanifest.lua`.
8. Restart `ox_inventory`, then restart `w2f-weed`.

## Config Map

| File | Purpose |
| ------ | --------- |
| `config/main.lua` | Core settings, identifier mode, validation, debug toggles |
| `config/contact.lua` | Contact NPC/mission settings |
| `config/shipments.lua` | Shipment tiers and drop locations |
| `config/loyalty.lua` | Loyalty levels and contractor shop gate |
| `config/rewards.lua` | Contact/shipment rewards |
| `config/strains.lua` | Seed item -> bud item mapping |
| `config/planters.lua` | Planter placement, soil, planting, and harvest settings |
| `config/growth.lua` | Growth timing, fertilizer effects, harvest amount |
| `config/placeables.lua` | Placeable props and pickup rules |
| `config/rolling.lua` | Rolling tray, papers, bud cost, joint mapping, minimum quality, bonus joint |
| `config/selling.lua` | Street selling prices, area, decline chance, and toggle command |
| `config/integration.lua` | Optional external catalog bridges |

## Feature flags

`config/main.lua` -> `Config.Foundation` is the single master switch for each subsystem (`EnableContact`, `EnableShipments`, `EnableLoyalty`, `EnableBribes`, `EnableGrowing`, `EnableProcessing`, `EnableSelling`). A feature is active only when **both** its master flag here and its own module `Enabled` (e.g. `Config.Planters.Enabled`) are true. Growing and processing ship enabled by default.

## Street selling

Street selling is toggled by `/sellweed` (configurable via `Config.Selling.Command`; set it to `false` to remove the command). The `w2f-weed:client:toggleStreetSelling` event still exists for radial-menu or item hooks. Stay within `Config.Selling.AreaRadius` of where you started.

## Troubleshooting

| Issue | Fix |
| ------- | ----- |
| USE on `rolling_tray` does nothing | Check the item has `client.event = 'w2f-weed:client:startRollingMinigameFromTray'`, then restart `ox_inventory`. |
| Planter item does not deploy | Check `empty_planter_box` or `plant_pot` has `client.event = 'w2f-weed:client:startPlanterPlacement'`. |
| Placeable items do not deploy | Check the item is listed in `config/placeables.lua` and has `client.event = 'w2f-weed:client:startPlaceablePlacement'`. |
| Contractor shop opens but buys fail | Check player loyalty and `Config.Loyalty.ContractorSuppliesMinLoyalty`. |
| Shop hooks stop working after edits | Restart `ox_inventory`, then restart `w2f-weed`. |
| Rolling station art missing | Make sure the full `nui/` folder is included by `fxmanifest.lua`. |
| Growing or rolling won't start | Confirm the matching `Config.Foundation` master flag (`EnableGrowing` / `EnableProcessing`) is true as well as the module's own `Enabled`. |
| `/sellweed` does nothing | Confirm `Config.Foundation.EnableSelling` and `Config.Selling.Enabled` are true, and that you're carrying sellable product. |


## Framework support

Supported:
- Qbox + ox_inventory
- QBCore + ox_inventory

Not supported:
- qb-inventory
