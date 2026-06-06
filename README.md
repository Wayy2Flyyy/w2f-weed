# w2f-weed

Qbox (`qbx_core`) + QBCore (`qb-core`) grow-op system: shipments, planter growth, loyalty, deployables, rolling-station minigame, and optional storefront hooks backed by oxmysql + ox_inventory + ox_target.

w2f-weed the most advanced weed script on FiveM street contact shipments, loyalty, planters + growth, placeables, optional store integration.

### Currently this script is fully operational. I do update all my scripts weekly until I think theyre perfect, expect updates for refinement and better experience!

## What's new in 0.5.0

- **One master switch per system** — `Config.Foundation` flags (`EnableGrowing`, `EnableProcessing`, `EnableContact`, `EnableLoyalty`, …) are now authoritative instead of dead config. Growing and processing default to on.
- **Strain & care actually matter** — harvest yields scale with the strain's `yield` and the plant's health; neglected plants pay out less.
- **Skill-rewarding rolling** — roll quality is validated server-side and a clean roll can pack a bonus joint.
- **Smoother grow-op UX** — drop zones use a progress-aware `[E] Search (x/y)` prompt (no more notify spam), shipments tell you exactly which seeds you found, and plant targets show upkeep (Thirsty / Needs Water + Feed! / Wilting!) with live water/feed levels.
- **Restart-safe shipments** — in-progress leads survive a resource/server restart.
- **Self-contained selling** — `/sellweed` toggles street selling without needing an external radial menu.
- Fixed duplicate planter/plant target menus and resource version drift.

## Quick setup

1. Clone or download into `resources/w2f-weed` **using that exact folder name**.
2. Import `sql/install.sql` once on the DB your `oxmysql` resource connects to.
3. Follow **`INSTALL.md`** to paste the bundled ox_inventory snippets (items + shops).
4. Add `ensure w2f-weed` after `ensure oxmysql`, `ensure ox_lib`, `ensure ox_inventory`, `ensure ox_target`, and either `ensure qbx_core` (preferred) or `ensure qb-core`.
5. **`install_assets/`** — checklist of ox_inventory **`web/images`** PNG names for default item keys (`install_assets/README.md`).

Rolling behaviour, planters, strains, loyalty gates, etc. live under `config/`. Extend `locales/en.lua` for more languages using the same pattern as ox_lib locales.

<img width="720" height="299" alt="image" src="https://github.com/user-attachments/assets/be01fcc4-134f-4835-85a2-3446447c8a82" />
<img width="1415" height="830" alt="image" src="https://github.com/user-attachments/assets/7abb8561-5dbb-41cb-95f9-96e441b65758" />
<img width="1382" height="838" alt="image" src="https://github.com/user-attachments/assets/09683c09-b5f1-4647-9556-1216701f9542" />
<img width="263" height="264" alt="image" src="https://github.com/user-attachments/assets/598e7e6e-9272-4a52-b924-1307244ec3f3" />
<img width="314" height="211" alt="image" src="https://github.com/user-attachments/assets/7faded18-3a33-4e34-87c2-231b3aeb815a" />
<img width="1484" height="837" alt="image" src="https://github.com/user-attachments/assets/dd33c638-e677-453c-a3f4-d80056db4b70" />
<img width="1482" height="839" alt="image" src="https://github.com/user-attachments/assets/3cf6393c-6ff6-475e-9dd7-201d6857223b" />
[Watch Rolling Weed Preview](https://cdn.discordapp.com/attachments/1505282321610313861/1505709963811754096/RollingWeed.mp4?ex=6a0b9d2e&is=6a0a4bae&hm=eee4e896bf9742ab0db43581c91609eed7daba1855d2d18f93610aba895349bf&)





## Framework support

Supported:
- Qbox + ox_inventory
- QBCore + ox_inventory

Not supported:
- qb-inventory
