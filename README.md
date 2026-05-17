# w2f-weed

Qbox (`qbx_core`) grow-op system: shipments, planter growth, loyalty, deployables, rolling-station minigame, and optional storefront hooks backed by oxmysql + ox_inventory + ox_target.

## Quick setup

1. Clone or download into `resources/w2f-weed` **using that exact folder name**.
2. Import `sql/install.sql` once on the DB your `oxmysql` resource connects to.
3. Follow **`INSTALL.md`** to paste the bundled ox_inventory snippets (items + shops).
4. Add `ensure w2f-weed` after `ensure oxmysql`, `ensure ox_lib`, `ensure ox_inventory`, `ensure ox_target`, and `ensure qbx_core`.
5. **`install_assets/`** — checklist of ox_inventory **`web/images`** PNG names for default item keys (`install_assets/README.md`).

Rolling behaviour, planters, strains, loyalty gates, etc. live under `config/`. Extend `locales/en.lua` for more languages using the same pattern as ox_lib locales.
