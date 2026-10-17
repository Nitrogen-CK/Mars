# Expedition maps

The four user-created map assets are the deliverables:

- `/Game/Mars/Maps/BrokenCistern_Mars_MAP`
- `/Game/Mars/Maps/PilgrimsHollow_Mars_MAP`
- `/Game/Mars/Maps/SevereredAqueduct_Mars_MAP` (original spelling)
- `/Game/Mars/Maps/SunkenKitchens_Mars_MAP`

Construction source is `data/layouts.json`, `data/art_bounds.json` and `build_maps.py`. The data freezes the concept plans and measured art bounds from the 2026-10-15 design pass; it lives beside the tool because this repository ignores `docs/`. Run `python Tools/LevelDesign/expedition_maps/build_maps.py` to regenerate the construction manifest. It does not open or change Unreal maps. Refresh the measured bounds if the kit itself changes.

Inside Unreal Python, import this directory, then use `build_maps.apply_current(index)` **only after loading the matching map**, where index is 0–3 in the list above. The authoring pass refuses another map and removes only actors tagged `Mars.Expedition.Authoring.20261016`. It saves the current map and references shared art without modifying it. Dedicated expedition materials provide the water and bronze clue glyphs. Original map backups are in the campaign directory. Rebuilding replaces hand edits to owned actors; author permanent changes in the layout/pass or remove the ownership tag from a deliberately retained actor.

`audit_current(index)` samples actual UE collision along the route ribbons, checks floor and standing-capsule clearance at each start, and validates the Jolt bake. This does not prove a continuous cargo-sized path through every furnishing or a complete puzzle solve. `capture(...)` writes actual editor SceneCapture images. Python `Rotator` calls intentionally use named arguments: positional order differs from the visible pitch/yaw/roll convention in this engine binding.

The scoped expedition game mode chooses one entrance group per run and leases separate starts in its foyer. Existing gameplay remains the parent. Each map contains real forage spawners, FoodPiece ingredients, cutting/searing/frying/batter/tumbler/mortar stations, provisioned entrances, two kitchen trays and two crawler encounters with a local navigation field. Optional puzzles reuse the existing Mourner, Bell/Porter and Censer circuits. All repeated masonry is native HISM geometry, grouped by district and material.

The hunt's cookable cache is provisional stock, separate from severed crawler parts. The camp catalog now includes all four expeditions. No recipe/service evaluator, severed-part-to-food conversion or multiplayer combat/forage upgrade is included. Those systems must be integrated separately before claiming the entire production loop. Current evidence and remaining acceptance are in the campaign's `PROGRESS.md`.

Do not repeat the removed four-local-player Python probe: it stalled the live editor. Use a normal multiplayer test session for party acceptance. Build and automation always run through `CkAuto/UnrealToolbox.exe`; never invoke raw Unreal build/test executables.

`probe_walk(index, stair=True)` runs normal CharacterMovement up a selected 4 m or 8 m stair route. `prepare_mourner()` temporarily puts the local real pack on its pressure plate before PIE; always call `restore_mourner()` after PIE, before saving or changing maps. This fixture is never permanent map stock. The plate probe teleports the chef between test stances and sweeps the real doorway; it does not prove a manual pack pickup/drop journey. `probe_bell()` uses the editor-only `Mars_ExpeditionAcceptance` helper to aim the camera director, then inject the real mapped LeftMouseButton Use press/release into the local input source. Resolver-only requests do not exercise the player's input-to-interaction task. Its camera aim phase must run after the stance has settled, before pressing.

Read the physical `*-stair.json`, `*-mourner.json`, and `*-bell.json` assertions as well as the smoke report. A clean runtime log alone does not mean the gate opened. Jolt auto-cook can finish after a map save returns; validate it again after returning to the editor. Never treat an immediate stale result as a valid bake.

Tuning: district footprints, route widths and elevation live in `data/layouts.json`; optional pocket placement is `POCKETS` in `build_maps.py`; `BASE_FLOORS` closes empty construction trenches and `RECOVERY` is intentionally empty. `CEILING_AMBIENT`, `CEILING_EXPOSURE` (currently -1.0), `CEILING_LAMP_INTENSITY` and the light multiplier in `apply_current()` set interior lighting. `apply_exposure_current(index)` updates only the matching owned exposure volume. The generator freezes one authored layout per map; it does not generate random topology at runtime.

The r02 pass adds continuous supported barrel vaults with closed ends, removes empty scenic recovery ladders and loose filler, provisions every entrance, and supplies two scoped crawler encounters plus cookable MushroomBeds. `playtest.py` drives normal player movement and mapped inputs, records pauses separately, and never forces puzzle/food state. Its complete runs are separate from the earlier fixture probes. Current ceiling, support and map hash records live under `playtest-r02/`.

The current measured forage-to-meal routes take approximately 5–9 minutes with the informed input driver. They do not meet the 15–20 minute target or establish blind-player pacing. The final meal payoff remains undecided. Read `RUN_RESULTS.json` for exact per-map times and limits; a returned plated mushroom is not proof of a completed protein recipe or persistent camp delivery. Keep the editor restored during live input tests: minimized editor windows can throttle to 3 FPS even with background CPU throttling disabled. `begin()` rejects world deltas >=100 ms and current events record frame delta; these samples are not a performance benchmark.
