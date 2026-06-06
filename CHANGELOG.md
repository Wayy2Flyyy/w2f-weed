# Changelog

## [0.5.0] - 2026-06-06

### Functions & processes
- `Config.Foundation` master switches are now authoritative. `EnableGrowing`, `EnableProcessing`, `EnableContact`, and `EnableLoyalty` were previously dead flags; they now gate their subsystems (a feature needs both its master flag **and** its module `Enabled`). Growing and processing now default to **on**.
- Harvest yields are now strain- and health-aware: per-strain `yield` biases where a plant lands in the global harvest band, and low plant health reduces the payout (caring for plants matters).
- Rolling quality is sanitised server-side (clamped 0–100) instead of being trusted blindly, and a high-quality roll now has a configurable chance to pack a **bonus joint** (`Config.RollingMinigame.BonusJoint`), so the minigame skill finally pays off.
- Active shipments are rehydrated from the database on resource/server restart, and re-pushed to online players, so in-progress leads are no longer lost on restart.

### Experience
- Shipment drop zones now use a persistent, progress-aware TextUI prompt (`[E] Search … (x/y)`) instead of repeating enter/exit notification spam.
- Completing a shipment now reports exactly which seeds you found.
- Plant interactions surface upkeep at a glance: the inspect label shows status (Healthy / Thirsty / Needs Water + Feed! / Wilting!), and the water/feed options show current levels. Labels refresh when a plant's status changes.

### Usefulness
- Added an in-resource street-selling toggle command (`Config.Selling.Command`, default `/sellweed`) so selling no longer depends solely on an external radial menu.

### Fixes
- Planter and plant `ox_target` registrations no longer attach both an entity target and an overlapping sphere zone, which produced duplicate menu entries.
- Fixed version drift: `shared/constants.lua` now matches the manifest version.

## [0.4.1] - 2026-05-23

- Added ESX (`es_extended`) support alongside Qbox and QBCore
- Added unified framework helpers for player identity, money, and police alerts
- Widened DB `citizenid` columns to fit ESX identifiers (auto-migrates on start)

## [0.4.0] - 2026-05-23

- Added plant lifecycle: water, nutrients, and health stats with decay and death
- Added watering can and fertiliser upkeep; dead plants can be removed
- Added 3-bag soil requirement before a planter is filled
- Added ox_lib inspect menus for plants and planters (replaces notify popups)
- Added styled placement TextUI for planters, seeds, and placeables
- Fertiliser now refills nutrients as well as boosting growth

## [0.3.0] - 2026-05-23

- Added street selling with ox_target (replaces qbx_drugs corner selling)
- Added cursor-based planter placement
- Added sphere-zone fallback for plant harvest interactions
- Disabled `grow_light` placeable until glow behaviour is ready
- Fixed planter cursor placement, missing harvest target, drug notify spam, and missing sell target

## [0.2.0]

- Initial release: planters, growth, rolling station, shipments, loyalty, placeables, contact ped, store integration
