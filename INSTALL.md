# w2f-weed — installation

[Qbox](https://docs.qbox.re/) (`qbx_core`) resource: contact shipments, loyalty, planters, placeables, optional store hooks, and a rolling-station NUI.

## Before you start

| Step | Action |
|------|--------|
| Database | Run `sql/install.sql` once (same DB as oxmysql). |
| Folder name | Keep the resource folder named `w2f-weed`. |
| ox_inventory | Add the item blocks below to `data/items.lua`, then add/merge shops in `data/shops.lua`. Optional icons: **`install_assets/README.md`**. |
| Restart order | After editing items or shops: `restart ox_inventory`, then `restart w2f-weed`. |

Dependency start order:

`ensure oxmysql` → `ensure ox_lib` → `ensure ox_inventory` → `ensure ox_target` → `ensure qbx_core` → `ensure w2f-weed`

Ensure player identifiers match your framework (`citizenid` is configured in `config/main.lua`).

---

## ox_inventory `items.lua`

Append the blocks below inside your `items.lua` export table (`return { … }`). Do not duplicate keys that already ship with your preset.

Rolling / tray consumables normally sit beside other smokables:

```lua
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
```

**`joint`** / **`rolling_papers`** may already exist — **do not duplicate keys**. **`rolling_tray`** must keep the **`client.event`** above exactly.

---

### `WEED OPERATION — Seeds (w2f-weed)`

```lua
    -- ──────────────────────────────────────────────────────────────────
    -- WEED OPERATION — Seeds  (w2f-weed)
    -- ──────────────────────────────────────────────────────────────────

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
```

---

### `WEED OPERATION — Buds — Joints (w2f-weed)` (buds & batches only)

```lua
    -- ──────────────────────────────────────────────────────────────────
    -- WEED OPERATION — Buds — Joints (w2f-weed)
    -- ──────────────────────────────────────────────────────────────────

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
```

There is **no** `batch_purple_palm_tree_delight_bud` in stock data — add your own batch key only if scripts reference it.

---

### `Weed Joints` (strain keyed joints · used by **`config/rolling.lua` → `JointItems`**)

```lua
-- Weed Joints

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
                rot = vec3(0.0, 0.0, 0.0)
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
                rot = vec3(0.0, 0.0, 0.0)
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
                rot = vec3(0.0, 0.0, 0.0)
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
                rot = vec3(0.0, 0.0, 0.0)
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
                rot = vec3(0.0, 0.0, 0.0)
            },
            usetime = 4500,
        },
    },
```

---

### Crest Leaf Blunt Cannon Joints

```lua
    -- Crest Leaf Blunt Cannon Joints

    ['blunt_exotic_weed'] = {
        label = 'Exotic Weed Blunt Cannon',
        weight = 8,
        stack = true,
        close = true,
        description = 'A premium crest-leaf blunt cannon packed with exotic weed.',
        client = {
            status = {
                stress = -150000,
            },
            anim = {
                dict = 'amb@world_human_aa_smoke@male@idle_a',
                clip = 'idle_c',
            },
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
            status = {
                stress = -165000,
            },
            anim = {
                dict = 'amb@world_human_aa_smoke@male@idle_a',
                clip = 'idle_c',
            },
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
            status = {
                stress = -135000,
            },
            anim = {
                dict = 'amb@world_human_aa_smoke@male@idle_a',
                clip = 'idle_c',
            },
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
            status = {
                stress = -145000,
            },
            anim = {
                dict = 'amb@world_human_aa_smoke@male@idle_a',
                clip = 'idle_c',
            },
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
            status = {
                stress = -175000,
            },
            anim = {
                dict = 'amb@world_human_aa_smoke@male@idle_a',
                clip = 'idle_c',
            },
            prop = {
                model = `p_cs_joint_02`,
                pos = vec3(0.015, 0.015, 0.0),
                rot = vec3(0.0, 0.0, 0.0),
            },
            usetime = 5500,
        },
    },
```

---

### `WEED OPERATION — Equipment (w2f-weed)`

Placeables (**`watering_can`**, **`fertilizer_basic`**, **`grow_light`**, **`drying_rack`**, **`weed_bench`**) **must** use **`w2f-weed:client:startPlaceablePlacement`**. Planters use **`startPlanterPlacement`**.

```lua
    -- ──────────────────────────────────────────────────────────────────
    -- WEED OPERATION — Equipment  (w2f-weed)
    -- ──────────────────────────────────────────────────────────────────

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
        description = 'A wooden plant pot. USE to deploy as a planter.',
        client = {
            event = 'w2f-weed:client:startPlanterPlacement',
        },
    },

    ['soil_bag'] = {
        label = 'Soil Bag',
        weight = 1000,
        stack = true,
        description = 'A bag of soil. Use the "Add Soil" interaction on an empty planter.',
    },

    ['watering_can'] = {
        label = 'Watering Can',
        weight = 750,
        stack = true,
        description = 'A watering can for plant care.',
        client = {
            event = 'w2f-weed:client:startPlaceablePlacement',
        },
    },

    ['fertilizer_basic'] = {
        label = 'Basic Fertilizer',
        weight = 2000,
        stack = true,
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
        description = 'Artificial lighting for indoor growing.',
        client = {
            event = 'w2f-weed:client:startPlaceablePlacement',
        },
    },

    ['drying_rack'] = {
        label = 'Drying Rack',
        weight = 5000,
        stack = false,
        description = 'Used to dry harvested plants.',
        client = {
            event = 'w2f-weed:client:startPlaceablePlacement',
        },
    },

    ['weed_bench'] = {
        label = 'Weed Work Bench',
        weight = 12000,
        stack = false,
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

---

## ox_inventory `shops.lua` (paste into the shops table)

## SmokeOnTheWater (retail — papers, tray, wraps, joints, blunts)

Example coords/targets:

- Location: `vec3(-1172.18, -1571.77, 3.66)`
- Target: `heading` 305°, `distance` ~1.85**

```lua
	--- Vespucci — joints + blunt cannons (w2f-weed items).
	SmokeOnTheWater = {
		name = 'Smoke on the Water',
		blip = {
			id = 59, colour = 2, scale = 0.75,
		},
		inventory = {
			{ name = 'rolling_papers',                     price = 12 },
			{ name = 'rolling_tray',                       price = 78 },
			{ name = 'blunt_leafs',                        price = 18 },
			{ name = 'soil_bag',                           price = 2000 },
			{ name = 'watering_can',                       price = 200 },
			{ name = 'fertilizer_basic',                   price = 250 },
			{ name = 'fertilizer_premium',                 price = 500 },
			{ name = 'empty_baggies',                      price = 50 },
			{ name = 'digital_scale',                      price = 300 },
			{ name = 'trimming_scissors',                  price = 100 },
			{ name = 'joint',                               price = 22 },
			{ name = 'joint_hybrid',                        price = 28 },
			{ name = 'joint_exotic_weed',                   price = 32 },
			{ name = 'joint_skunk',                         price = 36 },
			{ name = 'joint_purple_palm_tree_delight',      price = 42 },
			{ name = 'joint_purple_runtz',                  price = 48 },
			{ name = 'blunt_hybrid',                        price = 65 },
			{ name = 'blunt_skunk',                         price = 72 },
			{ name = 'blunt_exotic_weed',                   price = 78 },
			{ name = 'blunt_purple_palm_tree_delight',      price = 88 },
			{ name = 'blunt_purple_runtz',                  price = 95 },
		},
		locations = {
			vec3(-1172.18, -1571.77, 3.66),
		},
		targets = {
			{ loc = vec3(-1172.18, -1571.77, 3.66), length = 0.65, width = 0.55, heading = 305.0, minZ = 3.48, maxZ = 4.18, distance = 1.85 },
		},
	},
```

This shop stays open without loyalty gates. Selling `rolling_tray` here mirrors the snippet in `items.lua`: the tray must trigger `w2f-weed:client:startRollingMinigameFromTray`.


---

## SmokeOnTheWaterContractor (loyalty-gated planters + bench)

Keep this shop key as `SmokeOnTheWaterContractor` (used by `server/ox_inventory_shop.lua`). Align coordinates with `config/loyalty.lua` → `Config.Loyalty.ContractorSupplies`.

- Example centre: `vec3(-1227.56, -1406.1, 3.18)`

```lua
	--- Requires w2f-weed contact loyalty ≥ Config.Loyalty.ContractorSuppliesMinLoyalty.
	-- Align coords with `w2f-weed` Config.Loyalty.ContractorSupplies.Coords (blip + gate).
	SmokeOnTheWaterContractor = {
		name = 'Contractor supplies',
		icon = 'fa-solid fa-toolbox',
		inventory = {
			{ name = 'empty_planter_box', price = 4200 },
			{ name = 'weed_bench',         price = 6200 },
		},
		locations = {
			vec3(-1227.56, -1406.1, 3.18),
		},
		targets = {
			-- `ped`: ox_inventory spawns NPC + ox_target on entity (shop open still gated by w2f-weed loyalty hooks).
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

Players need loyalty ≥ `Config.Loyalty.ContractorSuppliesMinLoyalty` (default `3`) before buys register.

---

## YouTool — merge weed supply lines into your shop

Use the example below as a merged `inventory`/`targets` snippet; tweak coordinates when you customise your map packs.


```lua
	YouTool = {
		name = 'YouTool',
		blip = {
			id = 402, colour = 69, scale = 0.8
		}, inventory = {
			{ name = 'lockpick',             price = 75 },
			{ name = 'WEAPON_FLASHLIGHT',    price = 150 },
			{ name = 'repairkit',              price = 350 },
			{ name = 'screwdriverset',       price = 225 },
			{ name = 'small_backpack',       price = 5000 },
			{ name = 'medium_backpack',      price = 12000 },
			{ name = 'large_backpack',       price = 30000 },
			{ name = 'duffle_bag',           price = 40000 },
			{ name = 'soil_bag',             price = 2000 },
			{ name = 'watering_can',          price = 200 },
			{ name = 'fertilizer_basic',      price = 250 },
			{ name = 'fertilizer_premium',    price = 500 },
			{ name = 'empty_baggies',        price = 50 },
			{ name = 'digital_scale',        price = 300 },
			{ name = 'trimming_scissors',    price = 100 },
			{ name = 'shovel',               price = 700 },
			{ name = 'toolbox',              price = 450 },
			{ name = 'power_drill',           price = 1200 },
			{ name = 'pliers',                price = 85 },
			{ name = 'adjustable_wrench',     price = 120 },
			{ name = 'screwdriver',           price = 40 },
		}, locations = {
			vec3(2748.0, 3473.0, 55.67),
			vec3(342.99, -1298.26, 32.51)
		}, targets = {
			{ loc = vec3(2746.8, 3473.13, 55.67), length = 0.6, width = 3.0, heading = 65.0, minZ = 55.0, maxZ = 56.8, distance = 3.0 },
			{ loc = vec3(342.45, -1298.9, 32.52), length = 0.65, width = 0.55, heading = 320.0, minZ = 32.35, maxZ = 32.95, distance = 2.0 },
		}
	},
```

Merge the `inventory` lines into your existing `YouTool` entry if one already exists (never register `YouTool` twice).


---

## Resource checklist

1. Place `w2f-weed` in `resources/` (keep the folder name exactly `w2f-weed`).
2. Run `sql/install.sql` once.
3. Ensure `ensure w2f-weed` runs after oxmysql, ox_lib, ox_inventory, ox_target, and qbx_core.
4. Keep contractor coords aligned with `config/loyalty.lua` (`Config.Loyalty.ContractorSupplies`). The default bribe item (`Config.Bribes.Item`, commonly `purple_runtz_bud`) must exist in `items.lua`.
5. Tune `config/rolling.lua` (`OpenItemKey`, `PaperItem`, `JointItems`, `BudsPerJoint`). Only enable `/weed_roll` via `Config.RollingMinigame.DebugCommand` when debugging.
6. Register any packaged `.ytyp` files under `stream/` inside `fxmanifest.lua` (`data_file 'DLC_ITYP_REQUEST'`).
7. Use `locales/en.lua` as the template when adding more locales.

After editing `items.lua` or `shops.lua`, restart `ox_inventory`, then restart `w2f-weed` so `registerHook` in `server/ox_inventory_shop.lua` rebinds cleanly.

Retail `SmokeOnTheWater` has no loyalty gate; `SmokeOnTheWaterContractor` waits until loyalty meets `Config.Loyalty.ContractorSuppliesMinLoyalty` (defaults to `3`).



## Config map

| File | Purpose |
|------|---------|
| `main.lua` | Core settings, `citizenid`, debug toggles |
| `contact.lua`, `shipments.lua`, `loyalty.lua`, `rewards.lua` | Contacts, crates, payouts, tiers |
| `strains.lua` | Seeds/buds ↔ ox item names |
| `planters.lua`, `growth.lua` | Soil timers, fertilizers, scissors |
| `placeables.lua` | Deployables + ox events |
| `rolling.lua` | Tray, papers, joint recipes (`JointItems`) |
| `integration.lua` | Optional external catalog bridges |

## Troubleshooting

| Issue | Likely fix |
|-------|------------|
| USE items never fire | Item keys vs configs; commas in Lua; `restart ox_inventory` |
| Contractor interaction fails | Loyalty vs `ContractorSuppliesMinLoyalty`; keep `SmokeOnTheWaterContractor` in sync with Lua |
| Shop hooks silently stop | `restart ox_inventory`, then `restart w2f-weed` |
| Rolling Station missing art | Confirm `files { ... }` in `fxmanifest.lua` publishes the whole `nui/` folder |

