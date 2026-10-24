# Chain Crossing production

Written 2026-10-24. Current state lives in PROGRESS.md. Superseded when this production kit is accepted or replaced.

Generate all 88 Chain Crossing/Sluice component entries with reusable Blender-headless tools, a packed asset library, a diorama, FBX exports and Unreal content. Dress only the relevant Variant C level instances. Preserve source layout, routes, gameplay colliders, hand grips, gate travel, water levels and protected views. No commit/push requested.

Canonical art and catalog: docs/art/warrens-c-dressing-r01/sections/chain-crossing-sluice. Current source layout: Tools/LevelDesign/anchor_plans/data/warrens_v8c.json. Source JSON owns coordinates; artwork supplies shape/style. Source moving-gate and handwheel contracts remain authoritative. Existing design/builder wheel-versus-lever mismatch is an integration question to inspect, not permission to alter unrelated gameplay.

Use deterministic family generators, linked Blender data/collection instances and Unreal ISM/HISM where viable. Moving mechanism art must remain separable from static dressing. Re-running the section dresser updates only owned actors/components. Baseline backups and ownership manifest precede map writes.

Reference workflows: Tools/BookMenuArt/StylizedR02/Model/export_centimetres.py and import_unreal.py; docs/art/warrens-c-dressing-r01/build_blender_library.py; Tools/LevelDesign/anchor_plans/build_warrens.py. All engine build/test work uses CkAuto/UnrealToolbox.exe.
