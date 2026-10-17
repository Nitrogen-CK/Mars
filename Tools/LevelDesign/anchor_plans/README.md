# Anchor plans

Anchored expedition maps resolve their route anchors from a seed at run start (`Script/ECS/AnchorResolver/`). Each
such map has a frozen route graph here.

- `data/<map>.json` is the frozen route graph for one anchored map: nodes and polylines in metres, `costCm` per link
  (the walk cost in centimetres; a ladder's climb time is folded in as walking distance), the entrances, the hunt
  courts, the closure groups with their caps, and the channel tag per route anchor. Warrens' data also carries the
  greybox-only layers (rooms, crawl gaps, ladder galleries, lights, footprint, the Deep's rect); the emitter ignores
  them. `python design_warrens_r2.py` writes `data/warrens.json` from the authored layout; edit that script, not the
  JSON.
- `python Tools/LevelDesign/anchor_plans/emit_plan.py warrens` writes
  `Script/ECS/AnchorResolver/Plans/Mars_AnchorPlan_Warrens.as`. Never edit that file by hand; change the data and
  re-run the emitter. The emitter exits 1 if the data breaks a rule the plan's `Validate()` also enforces.
- `build_warrens.py` builds the Warrens greybox inside Unreal Python from the same data. Run it on the already-open,
  empty `/Game/Mars/Maps/Warrens_Mars_MAP`; it never creates or loads a level. `python build_warrens.py` alone writes
  `Saved/AnchorPlans/warrens-manifest.json` and prints the counts; inside Unreal, `build_warrens.apply()` builds and
  `build_warrens.audit()` checks floors, start capsules, crawl-gap fit (stops a standing chef, passes a crouched one)
  and the Jolt bake. The builder rasterizes each level at 0.5 m (links by width, rooms, foyer pads walkable; the rest
  of the footprint solid), so bent passages are built as drawn. The Deep is roofed; the map has no daylight.

Changing a node position or a link cost changes the plan, so the solver tests' expected distances must be
recomputed from the new data.
