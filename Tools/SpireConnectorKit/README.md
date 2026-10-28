# Spire Connector Kit

Four modeled connector concepts, an editable linked-mesh Blender asset library,
and six native Unreal levels. These are stylized concept models with palette
materials, UV0 and per-part vertex tint, rather than baked production texture sets.

![Four modeled concepts, Blender review render](Output/Renders/Diorama_Overview.png)

## Open the results

| Unreal level | Content Browser path |
|---|---|
| Hearthscrew | `/Game/Mars/Maps/Spire/LI_Spire_Hearthscrew_Mars_MAP` |
| Braided Well | `/Game/Mars/Maps/Spire/LI_Spire_BraidedWell_Mars_MAP` |
| Rootwinder | `/Game/Mars/Maps/Spire/LI_Spire_Rootwinder_Mars_MAP` |
| Hanging Larder | `/Game/Mars/Maps/Spire/LI_Spire_HangingLarder_Mars_MAP` |
| Comparison diorama | `/Game/Mars/Environment/SpireConnectorKit/Maps/Spire_Diorama_Mars_MAP` |
| Complete kit library | `/Game/Mars/Environment/SpireConnectorKit/Maps/Spire_KitLibrary_Mars_MAP` |

Blender files: `Output/Blender/Spire_{HS,BW,RW,HL,KitLibrary,Diorama}.blend`.
Each file contains the shared source mesh scene, four complete scenes and both
review scenes; the filename selects the opening scene. Add **`Output/AssetLibrary`**
as a Blender Asset Library to use the 105 marked source assets and named catalogs.
That directory contains one canonical library file, avoiding duplicate browser
entries from the six scene snapshots in `Output/Blender`.
These six files are snapshots of one project; regenerate together after edits.

The Blender and native Unreal kit libraries contain all **105 exported meshes**
at actual scale. The libraries include 20 props,
29 collision proxies and the axis/scale gauge. Use the
`PropsDetail` camera or focus a mesh for small items. Collision previews are
visible in the library but have no gameplay collision there. `Output/KitCatalog.csv`
lists actual bounds, triangle counts, reuse and native paths.

## Edit and regenerate

The dimensional authority is
`Docs/design/spire-blender-handoff-20261026/spire_spec.json` at repository root.
It defines landings, flights, materials, props, chain bores and local placements.
`production.py` owns architecture and hero recipes; `props.py` owns the 20 prop
recipes; `geometry.py` supplies reusable mesh, UV, tint, convex and FBX helpers.
Blender instances share mesh data. Unreal instances share Static Mesh assets
and HISM components grouped by mesh and layer.1680 Hanging Larder chain links
share one mesh and one HISM group in its source level.

Run from PowerShell:

```powershell
./Tools/SpireConnectorKit/Build.ps1
# Include rendered previews:
./Tools/SpireConnectorKit/Build.ps1 -Render
# Recheck the saved Blender project without rebuilding:
./Tools/SpireConnectorKit/Build.ps1 -ValidateOnly
```

The tools require Blender 5.2 (validated with 5.2.2). Export geometry uses UE
centimetres and FBX identity import scale. The Y reflection is applied once in
the Blender mesh and once in Blender placement; Unreal placements are already
UE coordinates. The imported axis fixture verifies signs and 100 cm scale.

In Unreal's Python console, import the regenerated kit in bounded batches:

```python
import runpy
n = runpy.run_path('D:/Repositories/CkRepos/Orion/Tools/SpireConnectorKit/import_unreal.py')
for start in range(0, len(n['manifest']()['assets']), 15):
    n['import_batch'](start, 15)
```

Imports verify ownership metadata and source paths, reuse unchanged FBXs, assign
shared materials by slot name, and check bounds and convex counts. They save
only owned assets. FBX import mode and Jolt auto-cook settings are restored
after use; no project config is written. Save unrelated editor edits first.

Rebuild a source/review level only when its existing authored actors may be
replaced. The tool rejects foreign actors or dirty unrelated packages:

```python
s = runpy.run_path('D:/Repositories/CkRepos/Orion/Tools/SpireConnectorKit/unreal_scenes.py')
s['build_map']('HS')  # BW, RW, HL, KitLibrary or Diorama
```

Rebuilding replaces actors in that owned source level; it does not preserve
manual changes within those actors. Keep custom arrangements in a separate
integration map. Asset and map ownership tag: `Mars.SpireConnectorKit.v1`.

## Integrate with basecamp

Use the selected source level as a Level Instance for visual authoring. Its
local pivot is the upper threshold `(0,0,0)`. The saved-camp fit assumes world
placement `(1640,0,0)`, yaw 0, scale 1, at the end of the existing east neck.
`SP_UpperSocket` and `SP_LowerSocket` mark its local seams. Lower seam is
`(1500,0,-1200)` for HS/RW/HL or `(1700,0,-1200)` for BW. The four source maps
are full assemblies. Only the comparison scene omits `Roof` and `ShellFront`.

**Visual source instances use NoCollision.** This project's CkJolt cooker
rejects transient `_LevelInstance_` and `/Temp/` level keys; see
`Plugins/CkFoundation/Source/CkJoltEditor/Public/CkJoltEditor/Cook/CkJoltCook_WorldCooker.cpp:100`.
Keep collision in a stable persistent map until that framework limitation is
resolved. Native editor Chaos traces do not prove CkJolt packaged lookup.

The opt-in helper below places invisible architectural collision in the
currently open persistent level, with the same translation/yaw as the visual
instance. It rejects the wrong destination and duplicate placements. **It does
not save or cook the destination.** Substitute your actual destination path:

```python
s['place_stable_collision']('HS', expected_map='/Game/YourIntegrationMap',
                            location_cm=(1640,0,0), yaw_deg=0)
```

Save your integration map and cook its CkJolt static world using the project's
normal editor workflow, then validate pawn traversal and packaged collision.
Use identity scale. Source props, the central flue/root and suspended basket
are visual dressing; the exported proxy set covers floors, walls, main roofs,
vestibule, guards and BW yokes. Small chain holes are deliberately filled in the walking
collision proxy. The basket is decorative storage, without lift gameplay.
Existing camp server travel remains unchanged; these models do not wire a new
camp-to-Warrens transition. PlayerStarts should belong to the persistent map.

## Evidence and limits

- Numeric design gate: 767 passes, 0 failures, 0 skips in the design handoff.
- Fresh saved Blender: 105 assets, 405 surface/bore rays, no errors; collision
  proxy surfaces checked for manifold edges.
- Standing headroom: 1167 upward rays at 220 cm on complete saved visual meshes,
  no blockers at sampled stations. This is not a continuous capsule sweep.
- Native meshes: 105 bounds/material/source checks; 516 imported convex hulls.
- Native saved maps: source instance totals 163/166/156/1874, every source
  transform checked after reload. Library 105, diorama 2219 visual instances.
- Native editor simple collision: 389 tread/landing rays, no errors.
- Focused Toolbox gate: 40 CkJolt tests passed, 0 failed, 0 contaminated.
  `Saved/Logs/Spire-PIE-CkJolt-Test.log`. No C++ or AngelScript changes or rebuild.
- Final single-player PIE: 18 chef cases, 9 larger-gauge cases, 16 physical rail
  contacts and 769 safety sweeps passed. All 39700 recorded movement frames
  used Walking, with no route teleports. Missing roof collision was fixed
  and the four failing checks passed on rerun.
- Co-op, performance, manual keyboard feel and packaged acceptance remain unverified.
  The native no-AA project preview exhibits shadow/lighting noise; Blender
  renders are separate studio review images, not gameplay screenshots.

Reports live in `Output/Reports`. No live camp/Warrens edits, commit or push
were made by this delivery. Rollback new content by removing only the new
`Content/Mars/Environment/SpireConnectorKit`, `Content/Mars/Maps/Spire` and this
tool folder with the editor closed, after preserving any later user edits.


See [PIE acceptance](PIE_ACCEPTANCE.md) for baseline/final results, the roof
collision fix and repeatable runtime checks. The saved acceptance map is
`/Game/Mars/Environment/SpireConnectorKit/Maps/Spire_PIEAcceptance_R02_Mars_MAP`.


