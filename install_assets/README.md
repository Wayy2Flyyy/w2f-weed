# ox_inventory item images (w2f-weed)

Every item row you paste from **`INSTALL.md`** should have a matching **`{item_key}.png`** for ox_inventory’s web UI unless you deliberately rely on a default/placeholder elsewhere.

## Install path (ox_inventory)

Copy PNGs into:

`resources/[ox]/ox_inventory/web/images/`

Restart **`ox_inventory`** after changes.

Use `install_assets/items/` locally as a staging folder, then bulk-copy into ox_inventory.

## Default keys (matching `INSTALL.md`)

### Rolling / smoke

- `rolling_papers.png`
- `rolling_tray.png`
- `blunt_leafs.png`
- `joint.png` *(optional—only if you keep a standalone `joint` shop row)*

### Seeds

- `purple_runtz_seed.png`, `skunk_seed.png`, `hybrid_seed.png`, `purple_palm_tree_delight_seed.png`, `exotic_seed.png`

### Buds & batches

- `purple_runtz_bud.png`, `skunk_bud.png`, `hybrid_bud.png`, `purple_palm_tree_delight_bud.png`, `exotic_bud.png`
- `batch_purple_runtz_bud.png`, `batch_skunk_bud.png`, `batch_hybrid_bud.png`, `batch_exotic_bud.png`

### Joints (`JointItems`)

- `joint_exotic_weed.png`, `joint_purple_palm_tree_delight.png`, `joint_hybrid.png`, `joint_skunk.png`, `joint_purple_runtz.png`

### Blunts

- `blunt_exotic_weed.png`, `blunt_purple_palm_tree_delight.png`, `blunt_hybrid.png`, `blunt_skunk.png`, `blunt_purple_runtz.png`

### Planters & gear

- `empty_planter_box.png`, `plant_pot.png`, `soil_bag.png`, `watering_can.png`, `fertilizer_basic.png`, `fertilizer_premium.png`
- `grow_light.png`, `drying_rack.png`, `weed_bench.png`, `trimming_scissors.png`, `empty_baggies.png`, `digital_scale.png`

If `config/` adds new strains or rename keys, rename the PNGs to match whatever you put in **`items.lua`**.

No sprites ship with **w2f-weed**.
