# Stylized R02 field cookbook — dedicated slim rig

This is a newly modeled portable cookbook, not a recolor of the original thick BookMenu tome.
All source, outputs and reports in this directory are standalone. Existing BookMenu content was read only.

## Open

- `Cookbook_StylizedR02.blend`: illustrated demo. Recipe images are packed.
- `Cookbook_StylizedR02_WidgetReady.blend`: same geometry/rig/actions, plain ivory page materials. No page image nodes.
- `Renders/ContactSheet.png`: closed, open, rear, profile, page turn, opening.
- `Renders/CookbookMotion.gif`: 66-frame opening, both page turns, and closing preview.
- `FBX/SK_Cookbook_StylizedR02.fbx`: rest mesh + dedicated skeleton + four morphs.
- Six `FBX/Book_*.fbx`: individually baked clips with their mesh/rig and morph animation. For animation-only Unreal import, disable mesh import and select the new skeleton.

## Physical size and axes

Page: **17 × 23 cm**. Boards approximately **18.16 × 24.53 cm**.
Evaluated closed whole-object bound: **19.074 × 26.696 × 2.808 cm**, including sewn spine, bookmark, raised emblem and corner guards.
The bookmark extends beyond the board. Evaluated open whole-object bound: **36.312 × 26.696 × 2.256 cm**.

Blender units are metres. Mesh and armature object scales are exactly **1,1,1**. The geometry, shape-key Basis, all four morph targets, and bone rest positions were resized together during authoring. No nonuniform object/pose scale is used.
FBX exports `-Z` forward / `Y` up with unit conversion. **Import at scale 1.0**, then verify cm bounds against `roundtrip_validation.json`; do not apply the old .6689 component multiplier.
The FBX exporter temporarily multiplies all mesh/key/rest coordinates by 100 and uses scene unit .01, then restores the source metre coordinates. This prevents Unreal's stripped Blender dummy from leaving skeletal reference scale100 while imported animated root scale is1. `cm_export_report.json` records the source file hashes, reference root scale1 and cover hinge .952 cm. `fbx_binary_units.json` checks the FBX's actual unit metadata and root transforms directly. Blender roundtrip alone did not catch the original Unreal-specific scale mismatch.
The export-only armature dummy is named `Armature`; `Master` is the sole skeletal root, with no additional Empty. Blender reimport confirms 12 bones.

## Compatibility and rig

**Not compatible with `Anim_Book_Skeleton` or its original animations.** The old 87-bone skeleton's rest offsets and thick block travel are unsuitable for this physical thin hinge. Matching the old names alone would not establish compatibility.

The dedicated rig has 12 bones:

- `Master`: root.
- `Cover_L`: front cover, left page block, left widget page; rotates around the actual spine hinge.
- `Cover_R`: rear cover, right block, right widget page.
- `Spine`: brown rounded leather binding, stitches, bookmark.
- `PageTurn_01..08`: smooth weights on the double-sided turning leaf.

The six action names retain the menu's useful semantics: closed idle, open idle, open, close, R→L page turn and L→R page turn. They run at 60 fps; idle clips 24 frames, transitions 48, turns 108. Each transition has baked bone animation. `PageBend_01..04` morphs remain; demo drivers read same-name armature properties and FBX includes sampled shape animation.

This package does not replace or configure `UBookMenuAnimInstance`. A project-side AnimBP/controller must use the new skeleton/clips and preserve page-widget binding behavior. This is an explicit integration task, not demonstrated by a Blender render.

## Page material contract

The first eight material slots are stable and ordered:

| Index | Slot | Geometry / demo |
|---:|---|---|
| 0 | `Cover` | Olive board cloth |
| 1 | `PagesBase` | Block edges and turning-leaf rim |
| 2 | `PageA` | Fixed left page / PageLeft.png |
| 3 | `PageB` | Turning leaf front / PageRight.png |
| 4 | `PageC` | Turning leaf back / PageLeft.png |
| 5 | `PageD` | Fixed right page / PageRight.png |
| 6 | `PageFirst` | Right inside-board endpaper / PageRight.png |
| 7 | `PageLast` | Left inside-board endpaper / PageLeft.png |

All six page-facing slots have normalized **UV0 [0,1] × [0,1]** rectangles. Back-face page UVs are mirrored appropriately so reading direction remains correct after turning. Endpapers lie below the blocks; the six primary clips expose the A/B/C/D reading surfaces. Endpaper-only first/last-page choreography is not authored.
The current 1024×1536 illustration aspect (2:3) is stretched slightly onto a 17:23 page; replace it with widget render targets or exact-aspect page artwork for final content.

Additional decorative material slots are intentional, appended after the eight required slots: `CoverDark`, `Brass`, `BrassLight`, `Scuff`, `Patch`, `Thread`, `Emblem`, `Leather`, `LeatherLight`, `PageEdgeLight`, `Bookmark`, `BookmarkLight`. These make modeled shapes legible without permanent painted page graphics. They are **20 material sections total**, a performance tradeoff appropriate to a close-up menu prop; atlas/consolidation is possible later without changing the first eight slots.
FBX material textures are not embedded. Use the packed demo blend or sibling `../Textures/PageLeft.png` and `PageRight.png` for previews; Unreal widgets should use their own dynamic page materials with the expected `BC` parameter.

## Geometry and evidence

The boards, faceted brass corner protectors, gold pot/leaf emblem, repair patches, patch stitches, raised spine sewing, paper signature ridges and red swallowtail bookmark are actual mesh geometry. Broad scuffs use flat polygon shapes; no photorealistic surface noise.

- 10,512 vertices / 20,204 triangles; maximum two bone influences; zero unweighted vertices.
- `validation.json`: source anatomy, action sample bounds, page UV extents and material contract.
- `roundtrip_validation.json`: independent Blender FBX import of the mesh and six clips, bone/morph/slot checks and dimensions.
- The start/middle/end deformed bounds of every imported FBX clip match the saved Blender source within 0.0001 metres (actual maximum error is reported); this also checks the morph/base-vertex sizing contract.
- Both 108-frame page turns are tested at every baked frame using triangle BVH overlap: **zero turning-sheet versus fixed-page surface intersections**.
- Closed/open block clearance follows the physical hinge design. Decorative sewing and spine overlap intentionally. Whole-mesh self-collision is not exhaustively tested; animated cover/stack/spine contact still needs the project's visual acceptance.
- No claim of Unreal runtime/AnimBP/physical input validation follows from these Blender checks. The main session owns Unreal import and runtime evidence.
- Unreal's initial import did not retain the four morph animation curves despite importing the targets. `morph_curves.json` supplies actual evaluated per-frame values for all six clips, sampled from the final source, including Blender's negative-driver clamp. Project integration must restore these as same-name morph curves; a zero float-curve count does not match the preview.

## Rebuild

Run from the repository root, with the user's open Blender left untouched:

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b --factory-startup --python-exit-code 1 --python 'Tools/BookMenuArt/StylizedR02/Model/build_stylized.py'
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b 'Tools/BookMenuArt/StylizedR02/Model/Cookbook_StylizedR02.blend' --python-exit-code 1 --python 'Tools/BookMenuArt/StylizedR02/Model/export_centimetres.py'
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b 'Tools/BookMenuArt/StylizedR02/Model/Cookbook_StylizedR02.blend' --python-exit-code 1 --python 'Tools/BookMenuArt/StylizedR02/Model/validate_and_roundtrip.py'
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b --factory-startup --python-exit-code 1 --python 'Tools/BookMenuArt/StylizedR02/Model/inspect_fbx_units.py'
python 'Tools/BookMenuArt/StylizedR02/Model/make_contact_sheet.py'
```

`build_stylized.py` defines base dimensions and the physical `AUTHOR_SCALE` in one place. `COLORS` controls flat material colors; the physical page/cover/hinge constants control thickness. Keep hinge and page-surface clearances coupled when changing thickness. Re-run both scripts after edits; a rendered scaled Basis alone is not proof that FBX base geometry is scaled.

## Spine-centred turn correction

`PageTurn_01` retains its offset rest head for mesh compatibility. `set_pose` compensates its translation around spine X0; both turn actions key that location. `export_centimetres.py` scales animated location keys/handles with rest geometry, then verifies restoration. Run `check_gutter.py` alongside the round-trip validator: the moving/fixed page rectangles must agree in XY at all four endpoints. Baseline2/4 -> final4/4. See `../GutterFix/REPORT.json` for actual native endpoint traces and screenshots.
