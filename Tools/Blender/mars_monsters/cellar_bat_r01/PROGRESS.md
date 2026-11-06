# Cellar Bat R01 - PROGRESS

Living record for the end-to-end production of the Cellar Bat (prompt:
`docs/art/flying-units-r01/MODEL_ANIMATE_IMPORT_PROMPT.md`). Another session must be able to resume from this file.
Every claim below is marked **confirmed** (evidence named) or **inferred**.

Owned roots: source `Tools/Blender/mars_monsters/cellar_bat_r01/` (this folder; `scripts/`, `source/`, `export/`,
`review/`), Unreal `/Game/ArtCandidates/CellarBat/R01/`. Runtime source may go under `Script/` in new files only.
Nothing is committed or pushed by this task.

## Phase 1 - environment, MCP and baseline (2026-11-05, DONE)

- Branch `dev`, HEAD `f87f9473d7f3af5d71e60b83b9a8bc2ba24c7ea1`, 64 dirty paths at start (unrelated: Sandbox map +
  Jolt cells, Script/ECS gameplay work, generated spawn params). **confirmed** (`git status --porcelain | wc -l`).
  None of those paths are touched by this task.
- Blender: `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe` = **5.2.2 LTS**; `bpy.ops.export_scene.fbx` and
  `import_scene.fbx` present; numpy 2.3.4; render engines `BLENDER_EEVEE` (+ Workbench). **confirmed** (background
  `--python-expr` probe). No Blender MCP server exists in `.mcp.json`; Blender work runs as fresh background processes
  (`blender -b --factory-startup --python <script> -- <args>`), never touching a user scene.
- Unreal: `.mcp.json` -> Monolith `http://localhost:9316/mcp`, **v0.23.0**, answers for project
  `D:/Repositories/CkRepos/Orion/Mars.uproject`, engine **5.7.4**, map `/Game/Mars/Maps/Sandbox_Mars_MAP`, PIE off,
  0 dirty packages, `unreal.FbxImportUI` available. **confirmed** (`editor_query run_python` identity probe,
  `list_dirty_packages`). Live editor process `MarsEditor.exe` pid 44472 started 17:30. Writes through this route are
  authorised only under `/Game/ArtCandidates/CellarBat/R01/`.
- Existing pipeline to pattern after: `Tools/Blender/mars_monsters/pale_crawler_r01/` (headless builder authored in the
  Unreal frame, FBX export `axis_forward=-Z, axis_up=Y, FBX_SCALE_NONE`, round-trip validator, `pale_crawler_ue.py`
  candidate importer under `/Game/ArtCandidates/PaleCrawler/R01`), and
  `Tools/Blender/mars_send_to_unreal/unreal/mars_character_ue.py` (legacy FBX importer with the Interchange flag off,
  skeleton reuse, slot restore). The crawler is static pieces; the bat is the first skinned candidate on this route,
  so the armature scale/axis recipe must be proven on a cube + blockout before it is trusted.
- Flying navigation: **CkVoxelNav exists** (`Plugins/CkFoundation/Source/CkVoxelNav/CLAUDE.md`): a volume feature
  (`utils_voxel_nav_volume::Add(owner, FCk_VoxelNavVolume_Spec{_VolumeBounds, _FinestCellSizeUu, _ClearanceUu})`)
  bakes a sparse voxel octree of free space from the Jolt static world; `utils_voxel_nav_path::Add(agent,
  FCk_VoxelNavPath_Spec{_AgentRadiusUu})` + `Request_FindPath(FCk_Request_VoxelNavPath_FindPath{_Volume,_From,_To})`
  answers next tick with `OnPathReady` / `OnPathFailed(outcome in {NoBake, EndpointUnresolvable, Unreachable,
  IterationCapReached, InvalidRequest})`. CkCrowd agents with `_AgentMode = Flying` follow such a path in 3D
  (`ApplyDisplacement3D`, `FaceAngle3D`), no avoidance. Jolt PIE static world defaults to `LiveExtract`
  (`CkJolt_ProjectSettings`), so a new review map with collision geometry needs no cook. No Mars script uses VoxelNav
  yet. **confirmed** (module CLAUDE.md, Fragment_Data headers, generated `utils_voxel_nav_*.as`).
- Build/test: toolbox rules in `CkAuto/.claude/skills/build-test/SKILL.md`. AngelScript-only changes take the
  test-only path (`--test --test-pattern <X>`) beside the open editor under the quiescence protocol; C++ changes need
  the editor closed. No runtime change yet, so no baseline captured yet - capture `--test-pattern` evidence for the
  touched modules before the first `Script/` edit (Phase 6).

## Phase 2 - blockout + early folding proof (2026-11-05, DONE - awaiting Fable audit)

Brief: `PHASE_2_BRIEF.md`. Executor: Opus. Evidence lands in `review/phase2/` and `export/validation/`.

### Commands (run from this folder; each prints CELLAR_BAT_OK / CELLAR_BAT_FAIL and exits non-zero on failure)

```bash
B="C:/Program Files/Blender Foundation/Blender 5.2/blender.exe"
"$B" -b --factory-startup --python scripts/build_cellar_bat.py   # [--no-renders] [--no-save] [--views-only] [--seq a,b]
"$B" -b --factory-startup source/CellarBat_R01.blend --python scripts/export_cellar_bat.py
"$B" -b --factory-startup --python scripts/validate_roundtrip.py
# Unreal, Monolith editor_query run_python {mode: execute_file, unattended: true}, command:
#   import runpy; runpy.run_path(r"D:/Repositories/CkRepos/Orion/Tools/Blender/mars_monsters/cellar_bat_r01/scripts/cellar_bat_validation_ue.py", run_name="__main__")
```
Last runs: build exit 0 (log `review/phase2/build_log.txt`), export OK, round trip OK, Unreal OK twice (import +
re-import). **confirmed** (printed markers / exit codes this session).

### Scene (`source/CellarBat_R01.blend`)
- Unit 1 BU = 1 cm (`scale_length 0.01`), 30 fps, frames 0..15. Collections: `Authoring` (per-part solids `AUTH_*`,
  left side only - the right is mirrored in the build), `Rig` (empty: no animator controls in Phase 2; poses rotate
  export bones directly), `Export` (`CellarBat_R01_Body` + `CellarBat_R01_Armature`), `Review` (camera, 10 cm rulers,
  label, perch bar). Action `CellarBat_R01_FlapTest` (fake user) on the armature. **confirmed**.
- Frame: Blender (x, y, z) == Unreal (x, -y, z). Bat faces +X; `_l` bones at Blender +Y = Unreal -Y; root at the
  origin pointing +Y, roll 0 => rest matrix identity. **confirmed** (builder check + Unreal root readback).

### Measured (bind = spread), `review/phase2/measurements.json`  **confirmed**
| quantity | target | measured |
|---|---:|---:|
| span tip-to-tip (mesh Y extent) | 75 | 74.965 |
| nose-to-rump along the leaning body axis (head+torso+tufts) | 22 | 21.994 |
| nose tip to rump point (straight line, reference) | - | 19.22 |
| torso width | 12 | 12.000 |
| ear base-to-tip | 10 | 10.000 |
| nose x (= max x of the whole mesh, +X forward) | - | 8.246 |

Interpretation (inferred, flag for audit): the bind body leans 30 deg forward (head up-forward), so "nose-to-rump" is
measured as the extent along that body axis; the straight nose-tip-to-rump distance is 19.2 cm.
Topology: 2042 tris, 1282 verts, slots `Body, Membrane, Eyes`, max 4 influences, normalized, every vertex weighted;
eyes = 2 octahedra (16 tris, slot Eyes). Palette as briefed via a per-corner sRGB byte colour attribute `Col` (the
Body slot carries fur/face/mouth/ribs/claws/fangs). Flat shaded, no subdivision.

### Rig check  **confirmed**
42 bones, names and parents == RIG.json (builder check; Blender round trip extra/missing/wrong = 0/0/0; Unreal
`get_skeleton_info` parents == RIG.json, diff []). No extra root (the armature object exports as `Armature`, which
Blender and Unreal drop as a node), no leaf bones.

### Pose proofs (`review/phase2/`): triangle-pair intersections (BVH overlap of the posed export mesh)  **confirmed**
| pose | memL-body | memR-body | memL-memR | mem-oppRibs | memL-legs | memR-legs | memL-self | memR-self | ribsL-body | ribsR-body | ribsL-ribsR | memRoot-body |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| spread | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 18 | 18 | 0 | 32 |
| half_fold | 0 | 0 | 0 | 0 | 0 | 0 | 32 | 32 | 18 | 18 | 0 | 32 |
| wrapped | 0 | 0 | 0 | 0 | 5 | 7 | 25 | 29 | 22 | 22 | 0 | 42 |
| hanging | 0 | 0 | 0 | 0 | 0 | 0 | 25 | 29 | 22 | 22 | 0 | 42 |
| flap_f00 | 0 | 0 | 0 | 0 | 0 | 0 | 6 | 6 | 20 | 20 | 0 | 16 |
| flap_f04 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 18 | 18 | 0 | 32 |
| flap_f08 | 6 | 6 | 0 | 0 | 0 | 0 | 0 | 0 | 20 | 20 | 0 | 28 |
| flap_f12 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 19 | 19 | 0 | 32 |

Reading: `body` = torso/head/face/tufts/ears. `ribs-body` 18 at bind is the upper-arm root buried in the torso by
design (so 22 in the wrap = +4). `memRoot-body` = membrane rows attached inside the flank (expected; excluded from
memX-body). `self` = non-adjacent triangle pairs within one wing's membrane: pleats of a partly closed fan touching
(inferred benign from the renders; not inspected per pair). `memX-legs` 5/7 in the wrap = inner panel at its ankle
attachment (inferred). `flap_f08` 6/side = the deep downstroke's inner panel grazing the flank (known, minor).
Hanging: root bone stays at the origin; body inverted by pelvis rotation; toes 0.1 cm into the bar surface (bar
radius 1.1 cm placed 1.0 cm above the toes - contact by construction, not solved).

How the wrap was closed (no proportion change needed): the first wrap rotated the wing by angle parameters
(adduct/sweep/flex/fan); elbow flex and fan close added up so the closed fingers swung back over the shoulder
(ribs-body 103-111, membrane-body 19-25, ribsL-ribsR 106). Fold poses are now aim targets in the body frame
(`WRAP_WING`, `HALF_WING`, `HANG_LEG` in the builder): elbow down the flank, wrist to the chest front near the
midline, finger fan draped over the belly, right wing one layer (1.2 cm) behind the left. Bone lengths never change;
nothing is scaled, hidden or detached. The failed first wrap image was overwritten; its numbers are above.

Look-and-fix rounds on the views (sheets in `review/phase2/iterations/`): r0 first build; r1 palette (colour
attribute had been written as linear, now `color_srgb`) + dark background; r2 wing plane pitched 46 deg back
(`WING_T_PITCH_DEG`) so the dorsal view shows broad wings; r3 broader ears (3.6 cm half-width) with a brown rim around
an oxblood cavity; r4 deeper chord (`WING_T_SCALE` 1.45) and scallops (0.38). Flap recovery key reworked (hand
counter-rotated at the wrist): membrane self 90 -> 0 at f12.

### Export recipe (`export/validation/export_settings.json`, verbatim)  **confirmed**
Scene `scale_length 0.01`; `apply_unit_scale=True`, `apply_scale_options='FBX_SCALE_NONE'`, `global_scale=1`,
`axis_forward='-Z'`, `axis_up='Y'`, `use_mesh_modifiers=False`, `mesh_smooth_type='FACE'`, `use_triangles=True`,
`use_tspace=False`, `add_leaf_bones=False`, `path_mode='STRIP'`, `colors_type='SRGB'`. Skeletal adds
`object_types={'ARMATURE','MESH'}`, `primary_bone_axis='Y'`, `secondary_bone_axis='X'`,
`use_armature_deform_only=True`, `armature_nodetype='NULL'`. Clip adds `bake_anim=True`,
`bake_anim_use_all_actions=False`, `bake_anim_use_nla_strips=False`, `bake_anim_use_all_bones=True`,
`bake_anim_force_startend_keying=True`, step 1, simplify 0. Armature object renamed `Armature` during export only.
Blender 5.2.2 LTS, FBX IO 5.15.0. **FBX written: binary 7400 (FBX 7.4, FBXHeaderVersion 1003), not 2020.2** (read
from the file headers).

### Blender round trip (`export/validation/roundtrip_report.json`)  **confirmed**
Cube: object scale 1, bounds +/-5.000. SK: armature object `Armature` scale 1 / rot 0 / loc 0; 42 bones, no
extra/missing/wrong parents; bind head error 0.00007 cm; 2042 tris (all triangles); slots in order; bounds error
0.0005 cm; 2042/2042 triangles matched by centroid (max 0.00001 cm), normals within 0.031 deg; max 4 influences.
Clip: one action, frames 0..15 (16); knuckle/wrist/thumb bone heads within 0.0004 cm and skinned wing-tip extremes
within 0.0008 cm at keys 0/4/8/12/15. Validator notes: imports with `anim_offset=0` (Blender's default 1.0 shifts frame
0 to 1); bone tails are not compared (FBX carries joints only; the importer invents tails).

### Unreal readback (`export/validation/unreal_readback.json`; re-import `unreal_readback_rerun.json`)  **confirmed**
Monolith `editor_query run_python` (project `D:/Repositories/CkRepos/Orion/Mars.uproject`, PIE off, 5.7.4) plus
`animation_query get_skeleton_info / get_sequence_info`. Legacy FBX importer; the Interchange FBX flag was on, was
switched off for the import and restored on (before/after true/true). Saved, only these (`save_loaded_asset`):
`/Game/ArtCandidates/CellarBat/R01/Validation/{Cube10_Mars_SM, CellarBat_R01_Blockout_Mars_SK,
CellarBat_R01_Blockout_Mars_SKEL, CellarBat_R01_Blockout_Flap_Mars_ANIM}`. Dirty packages before 0, after 0.
- Cube bounds 10.000 x 10.000 x 10.000.
- SK imported bounds X -12.18..8.246 (nose at max X), Y -37.482..37.482 (**span 74.965**), Z -16.10..18.11; slots
  `Body, Membrane, Eyes`; LOD0 render verts 5730 (flat-shaded split).
- Skeleton: 42 bones, parents == RIG.json; root local transform identity (t 0, q (0,0,0,1), s 1); every bone local
  scale (1,1,1) (max dev 0.0); bone world heads match Blender within 0.0001 cm; `upperarm_r` at Y +4.3 (Unreal right),
  `upperarm_l` at -4.3 - handedness correct; no root scale 100, no extra root.
- Anim: 16 keys / 15 intervals, 0.5 s, 30/1 fps, 42 tracks, skeleton = the new SKEL, no root motion; `wrist_l` local
  rotation changes (quaternion delta 0.355 f0 vs f12), seam f0 == f15 exactly; root rotation constant identity.
- Re-import of all three (replace_existing): identical readback, folder still exactly 4 assets (no duplicates).
- Note: `unreal.AnimationLibrary` has no `get_frame_rate` and the AnimPose API has no parent accessor in 5.7.4; those
  two facts come from Monolith `get_sequence_info` / `get_skeleton_info`.

### Deviations (recorded, low-blast)
- DEV-1 Wing chord deepened vs sheet 03 (`WING_T_SCALE` 1.45, scallop 0.38) to match sheet 02's broader membranes.
- DEV-2 Wing plane pitched 46 deg back from vertical (`WING_T_PITCH_DEG`) while the body leans 30 deg: reconciles the
  front view (fan visible) with the top view (broad wings); the sheets are not consistent projections.
- DEV-3 Fold poses use aim targets rather than finger-fan angle closing. Proportions were NOT changed for the wrap.
- DEV-4 Review renders use Workbench exposure +1.3 (palette values unchanged).

### Open risks / not verified
- Membrane pleat self-contacts (25-32 pairs) in the half and full fold are counted, not inspected per pair; panels
  between nearly-parallel closed fingers are thin wedges. Phase 3 topology should add pleat-friendly rows.
- Wrap transitions slerp each aimed bone from identity; in-between frames (`wrapped/frame_03..05`) swing the upper arm
  through odd intermediate angles - fine for a proof, not for the Perch clip.
- Toe/bar contact in the hanging proof is placed, not solved by IK.
- Workbench renders only; no EEVEE lighting pass and no Unreal viewport capture of the imported blockout yet.
- Nose-to-rump interpretation (axis extent vs straight distance) - see the measured table.

## Phase 3 - finished mesh, materials, animator rig, LODs (2026-11-05, DONE - awaiting Fable audit)

Brief: `PHASE_3_BRIEF.md`. Executor: Opus. Evidence lands in `review/phase3/`, `export/`, `export/validation/`.

### Phase 3 acceptance list (brief audit items 1-5 + maintainer review of the Phase 2 renders, 2026-11-05)
- A1 Inner membrane (plagiopatagium) a real broad panel, finger 4 -> flank -> ankle, continuous curved trailing edge.
- A2 Wrap/hang read as a cloak: elbows at the sides, wrists up at shoulder/chin, closed fans flat on sides/front, ribs as
  diagonals across the front, left over right with 1-2 cm layering, zero body and zero L/R intersection; proven with
  front/side/back/three-quarter renders + counts. Hang: feet clamped on the bar, head at the bottom, ears down.
- A3 Torso a plump pear (width 12, nose-to-rump 22 along the body axis); lower two thirds covered by 4-5 overlapping
  scallop shingle rows (broad low wedges); head low on the chest with a thick neck ruff; upper back smooth faceted.
- A4 Flap frame 8 flank graze resolved.
- A5 Head: recessed oval dark mask inset in a lighter brown hood; short blunt muzzle with a small nose wedge; mouth a dark
  slit, two short ivory upper fangs; eyes exactly two small bright amber solids set wide; ears broad triangles, thick
  brown rim, slightly lighter inner face, bases overlapping the hood, base-to-tip 10 cm.
- A6 Finger ribs: tapered, gently curved pale bones sweeping back, a visible knuckle bend; chunky wrist knuckle with a
  small hooked thumb claw.
- A7 Trailing edge: deep rounded scallops between fingertips, broad rounded inner panel to the ankle (as 02 FRONT);
  shallow catenary sag between ribs, no straight chords.
- A8 Every contact sheet and comparison has an EEVEE soft key + fill + rim pass; each round renders a side-by-side
  (concept crop next to the render, same view). Fidelity judged on the lit renders.
- Contract kept: 42 bones/names, slot order `Body, Membrane, Eyes`, export recipe, facet style (no subdivision/noise).

### Commands (run from this folder; each prints CELLAR_BAT_OK / CELLAR_BAT_FAIL and exits non-zero on failure)

```bash
B="C:/Program Files/Blender Foundation/Blender 5.2/blender.exe"
"$B" -b --factory-startup --python scripts/build_cellar_bat.py            # [-- --solve-wrap] [--no-save]  (~40 s)
"$B" -b --factory-startup source/CellarBat_R01.blend --python scripts/export_cellar_bat.py      # bakes the flap clip
"$B" -b --factory-startup --python scripts/validate_roundtrip.py
"$B" -b --factory-startup source/CellarBat_R01.blend --python scripts/render_cellar_bat.py -- [--only compare,ref,palette,wrap,hang,lod,flap] [--tag rNN]
"$B" -b --factory-startup source/CellarBat_R01.blend --python scripts/bake_cellar_bat.py -- --action <Ctl action> [--name X] [--fbx out.fbx]
```
Last runs (this session, in that order on the final build): build exit 0 `CELLAR_BAT_OK` (`review/phase3/build_log.txt`),
export exit 0 (`export_log.txt`), round trip exit 0 (`roundtrip_log.txt`), renders exit 0 (`render_log.txt`).
**confirmed** (exit codes + markers). `--solve-wrap` re-runs the wrap twist solve (warm-started from
`scripts/wrap_solution.json`, ~30 s) and rewrites that file; a plain build loads it, so builds are deterministic.

### Scripts
- `scripts/build_cellar_bat.py` - parametric geometry for all three LODs (`DETAIL[0..2]`), skinning, vertex-colour
  palette + baked cavity alpha, UV0, the 42-bone armature, pose definitions, the rig wiring, audits, intersections,
  review fixtures; saves `source/CellarBat_R01.blend`. Wrap twist solver (`solve_wrap`, `wrap_cost`).
- `scripts/bat_rig.py` - control armature + constraints on the export bones; `set_controls`, pose actions, mute.
- `scripts/bat_audit.py` - defect audit, intersections, UV overlap raster, render-vertex count, cavity bake.
- `scripts/bake_cellar_bat.py` - control action -> export bones (`nla.bake`, visual keying) + proof.
- `scripts/export_cellar_bat.py` - recipe unchanged; writes bind/LOD1/LOD2 SK FBXs, cube, baked flap clip.
- `scripts/validate_roundtrip.py` - re-import of every LOD + clip; colours, UV0, morphs, weights, landmarks.
- `scripts/render_cellar_bat.py` - Workbench rulers + EEVEE (warm / neutral / amber-teal) sheets and side-by-sides.
- `scripts/wrap_solution.json` - solved wrap twists (data, regenerated by `--solve-wrap`).

### Scene (`source/CellarBat_R01.blend`)  **confirmed** (saved by the build, reopened by export/render/bake)
Collections: `Authoring` (LOD0 parts, hidden), `Rig` (`CellarBat_R01_Controls`), `Export` (`CellarBat_R01_Body`,
`CellarBat_R01_Body_LOD1`, `CellarBat_R01_Body_LOD2` hidden, all skinned to `CellarBat_R01_Armature`), `Review`
(camera, rulers, label, perch bar). Actions (fake user, on the controls): `CellarBat_R01_FlapTest_Ctl` (0..15) and
pose actions `CellarBat_R01_Pose_{Spread,Up,Down,Recover,HalfFold,Wrap,BankLeft,BankRight,Hang,Screech,EarsFlat}`.
The export armature carries no action in the saved file (the exporter bakes one in memory).

### Measured (bind), `review/phase3/measurements.json`  **confirmed**
| quantity | target | Phase 2 | Phase 3 |
|---|---:|---:|---:|
| span tip-to-tip | 75 | 74.965 | 75.000 |
| nose-to-rump along the body axis (head+torso+tufts+ruff) | 22 | 21.994 | 22.086 |
| torso width (torso solid) | 12 | 12.000 | 12.000 |
| torso depth | - | - | 11.9 |
| ear base-to-tip | 10 | 10.000 | 10.000 |
| nose x (max x) | - | 8.246 | 8.353 |

| LOD | tris | verts | render verts (unique vertex/face-normal/UV/colour) | Body / Membrane / Eyes tris | max infl. | UV0 overlap px (1024 raster) |
|---|---:|---:|---:|---|---:|---:|
| LOD0 | 6482 | 3545 | 19446 | 3582 / 2884 / 16 | 4 | 0 |
| LOD1 | 2648 | 1561 | 7944 | 1958 / 674 / 16 | 4 | 0 |
| LOD2 | 1202 | 757 | 3606 | 1054 / 132 / 16 | 4 | 0 |

Phase 2 blockout: 2042 tris / 1282 verts / 5730 render verts (Unreal). LOD2 is 20% over "about 1k" (kept: ears, wing
outline and membrane attachments are at their minimum; inferred acceptable, flag for audit).

Defect audit (every LOD): open non-membrane islands 0, non-membrane boundary edges 0, edges with 3+ faces 0, winding
flips 0, inverted closed islands 0, zero-area tris 0, duplicate verts within an island 0. Intentional: 2 open membrane
islands (one per wing) with 188 / 90 / 40 membrane boundary edges. Info: coincident verts across islands 38/36/14
(touching separate solids), sliver tris (< 2 deg) 38/18/4 - the membrane fan hub at the wrist, not the finger tips.
The builder flips closed islands built inside-out before the audit (2 per LOD; deterministic, reported as
`orientation_fixes`). Split normals: every face flat (facets on body and membrane), `mesh_smooth_type=FACE`.
Triangulation: `bmesh.ops.triangulate(quad FIXED, ngon BEAUTY)` in the build; exported with `use_triangles`.

### Materials / vertex colour  **confirmed** (export_settings.json, round trip)
Corner attribute `Col` (BYTE_COLOR): RGB = palette albedo written as sRGB bytes (fur #433831, hood #544439, face/mask
#171415, mouth #0E0A0A, membrane #713B46, ribs #B7A18A, claws #8E7A66, fangs #E6DAC2, ear inner #6B4B45, eye #FFC570,
+-6% per-facet jitter), A = cavity/occlusion (24-ray cos-weighted per-face occlusion in the bind pose,
1 - 0.85 * occ, floor 0.15; mean 0.75). FBX `colors_type=SRGB` writes the bytes unchanged (round trip RGBA error 0.0).
Unreal binding (to build in Phase 5): three material instances reading VertexColor - BaseColor = VertexColor.RGB x
lerp(0.45, 1, VertexColor.A); Body roughness 0.8, Membrane roughness 0.65 + Two Sided, Eyes emissive =
VertexColor.RGB x 2.0; metallic 0 (whether 5.7 linearises the sRGB vertex bytes on import is unverified - check the
importer's vertex colour option). The Blender materials use the same graph (`ShaderNodeVertexColor` -> MapRange ->
Multiply). No textures. UV0 = layer `UV0`, lightmap-packed (one chart per face; flat shading means the seams add
~0.6% render verts).

### Rig: controls (`CellarBat_R01_Controls`, 51 bones, collection `Rig`, never selected for export)
- FK: `CTL_<bone>` for all 41 non-root export bones -> `RIG_FK` Copy Transforms (local, replace). Body pitch/roll =
  `CTL_pelvis` (+ `CTL_spine`); per-wing flap `CTL_upperarm_*`; elbow `CTL_forearm_*`; wrist curl `CTL_wrist_*`;
  fingers/thumbs, neck, head, jaw, ears, legs FK.
- Sliders (local Y, Limit Location): `CTL_fold_l/_r` 0..1 (0.5 = half fold, 1 = the solved wrap: `RIG_fold_a/b`
  Transform constraints holding the solved local rotations), `CTL_fan_l/_r` -0.3..1 (one control spreads/closes the
  four fingers, `RIG_fan`), `CTL_ears` Y -1 flat / 0 rest / +1 alert, X 0..1 twitch (both ears), `CTL_jaw_open` 0..1,
  `CTL_perch` 0..1 (drives IK + foot orientation influence via simple-expression drivers, no Python on load).
- Foot contact: `CTL_foot_ik_l/_r` (IK chain 2 on `shin_*`, world Copy Rotation on `foot_*`). Root never constrained.
- Proof: every review pose is defined directly, captured, and reproduced through the rig; rig vs direct max 3.4e-5 cm,
  0.0 deg for Spread, flap 0/4/8/12, HalfFold (fold 0.5), Wrap (fold 1), both banks. **confirmed** (RIGCHECK).

### Bake proof  **confirmed** (export_log.txt BAKE line)
`bake_cellar_bat.bake("CellarBat_R01_FlapTest_Ctl")` -> `CellarBat_R01_FlapTest`: 16 frames, 42 bones keyed, baked
(constraints muted) vs live rig max 1.6e-5 cm / 0.0 deg, root deviation 0, non-unit scale keys 0. Exported as
`export/validation/CellarBat_R01_FlapTest_Mars_ANIM.fbx`; round trip landmarks within 0.0008 cm.

### Round trip (`export/validation/roundtrip_report.json`)  **confirmed**
Cube +/-5.000. Each of `export/CellarBat_R01_Mars_SK.fbx`, `_LOD1_`, `_LOD2_`: armature `Armature` scale 1, 42 bones,
extra/missing/wrong parents 0/0/0, bind heads 6e-5 cm, tris 6482 / 2648 / 1202 all triangles, slots `Body, Membrane,
Eyes`, bounds error 0.0004 cm, span 75.000, every triangle matched (centroid 1e-5 cm, normal <= 0.033 deg), colour
attribute `Col` RGBA error 0.0 on every corner, `UV0` error 0.0 and no overlap after import, morphs 0 = 0, max 4
influences, normalized. Clip: one action, frames 0..15, landmarks within 0.0008 cm (bones) / 0.0008 cm (wing tips).

### Intersections (triangle pairs, posed through the rig)  **confirmed** (measurements.json)
Cross-part counts (memb-body, memb-legs, ribs-body, ribs-legs, memb L-R, ribs L-R, memb-opposite ribs), both sides:

| pose | LOD0 | LOD1 | LOD2 | same-wing pleat contacts L/R (LOD0, info) |
|---|---|---|---|---|
| Spread | 0 | 0 | 0 | 0 / 0 |
| Up (highest upstroke) | 0 | 0 | 0 | 44 / 44 |
| Down (deepest downstroke) | 0 | 0 | 0 | 0 / 0 |
| Recover | 0 | 0 | 0 | 19 / 19 |
| HalfFold (fold 0.5) | 0 | 0 | 0 | 3 / 3 |
| Wrap (fold 1) | 0 | 0 | 0 | 12 / 21 |
| BankLeft / BankRight | 0 | 0 | 0 | 0 / 0 |
| Hang | 0 | 0 | 0 | 12 / 24 |

Also 0 at fold slider 0.25 and 0.75 and at all 16 flap frames (LOD0). Phase 2 had wrap memb-legs 5/7, flap f08
memb-body 6/6, ribs-body 18-22 in every pose. Attachment contact is reported separately: `attach_memroot_body` (the
membrane rows on the flank line - last 2 panel rows at LOD0, 1 at LOD1/2 - which ride the body) and
`attach_ribroot_body` (upper-arm root inside the shoulder). Hang: bar r = 1.0 cm at Blender (3.0, y, 18.75); bar height
solved so the deepest claw vertex grips 0.12 cm; IK ankle error 0.0 cm; 12 foot verts per foot within 0.25 cm of the
bar surface, 1 inside; root at the origin.

### How the wrap became a cloak (and what was tried)
r01-r02: Phase 2 targets with the new panel = splayed skirt. r03: closed bundle, wrist mid-chest -> membrane inside the
body (452 pairs): linear-blend skinning swings the panel around each aimed bone. r04: twist of each aimed bone about
its own axis solved numerically against the counts (`solve_wrap`) -> 0 body but flared pouches; r05 added a hug term
(mean stand-off beyond a 3 cm shell). r06-r07: wrists at the shoulders, half-open fans draped diagonally, then the
forearm crossing the upper chest (sheet 03 diagonal). r08-r10: over-wing layer 1.5 -> 3.2 cm where the wings cross
(chord sag ate the smaller layer). r12: shoulder pivot 0.7 cm out (upper arm grazed the pear flank). The inner-panel
skin falloff (v^1.7, rows at the flank ride the body) and a 1.8 cm flank fillet were tuned against the downstroke,
banks and wrap together; penetration terms dominate the cost (x10 body/legs, x20 ribs, x30 L/R). The downstroke,
recovery, bank and half-fold keys were searched against the counts (scripts in the session scratchpad, results baked
into `FLAP_KEYS` / `BANK` / `HALF_WING`).

### Acceptance list status (A1-A8)
- A1 inner panel: real Coons panel with its own rows (17/8/4), continuous sine-scalloped trailing edge from the
  finger-4 tip to the ankle (`INNER_SCALLOP` 0.20 of the chord). **confirmed** (front/back refs).
- A2 wrap/hang cloak: elbows at the sides, forearms crossing the upper chest to wrists under the chin, half-open fans
  draped diagonally across the front, left over right (layer 3.2 cm where they cross); every cross-part count 0 at
  every LOD; hang inverted with feet on the bar, head at the bottom, ears down. **confirmed** (wrap_sheet, hang_sheet).
  Still differs: the cloak is more open at the upper chest (ruff visible between the forearms) and the hang hem points
  up at the feet, where sheet 03 tapers down past the head.
- A3 plump pear (width 12, length 22.09), 5 rows of broad low shingles on the lower front, smooth faceted back, head
  lowered into a 7-wedge ruff. **confirmed**. Still differs: the shingle rows read more regular than the sheet's tufts.
- A4 flap f08: 0 (was 6/6), and all 16 frames 0. **confirmed**. Note: the deeper downstroke uses a 36 deg twist that
  shows the hand membrane edge-on from the front; Phase 4 should re-key it.
- A5 head: recessed oval mask in a lighter hood, blunt muzzle + nose wedge, dark mouth slit, two ivory fangs, two amber
  octahedral eyes set wide, broad cupped ears (thick brown rim, lighter inner face) based inside the hood.
  **confirmed** (face tiles). Still differs: ears flatter and thinner than the sheet; eyes smaller than the sheet's.
- A6 ribs: tapered, bowed (4.5%) finger bones, knuckle hulls at the bend, chunky faceted wrist knuckle, hooked thumb
  claw. **confirmed**.
- A7 deep rounded scallops (`SCALLOP` 0.40), catenary sag between ribs (`SAG` 0.07 of the gap). **confirmed**.
  Still differs: the front view foreshortens the chord (DEV-2 wing pitch), so the membrane reads narrower than 02 FRONT.
- A8 every sheet has an EEVEE soft key/fill/rim pass; every round rendered a side-by-side. **confirmed**.

### Deviations (recorded)
- DEV-5 `WING_DIHEDRAL` 0.16 -> 0.42 (M silhouette of sheet 02 front) and the finger layout rotated toward the leading
  edge; flap/bank elevations shifted -14 deg to keep their absolute angles. Bone positions changed; names/parents not.
- DEV-6 `SHOULDER` y 4.3 -> 5.0 (arm clears the pear flank in the wrap). Head scaled 1.12 about its centre and lowered
  0.7 cm (`HEAD_SCALE`, `HEAD_U`); ear length still 10 cm.
- DEV-7 UV0 is lightmap-packed (one chart per face) instead of smart-project islands (those folded inside islands).
- DEV-8 The fold is per-bone twists solved against intersection counts (`wrap_solution.json`), not hand angles.
- DEV-9 BankLeft = the bat rolls toward its own left (left wing low); sheet 04's labels look camera-relative.
- Export recipe unchanged (args verbatim in `export/validation/export_settings.json`); no morph targets.

### Review evidence (`review/phase3/`)
`compare_sheet.png` (concept | render pairs, warm EEVEE: 02 front/side/back/top/underside/three-quarter, 03 spread/half
fold/wrapped/hang/face, 04 up/down/recover/bank L/bank R), `ref_workbench_sheet.png` + `ref_eevee_sheet.png` (rulers;
front, side, back, dorsal, ventral, three-quarter, face, wing root front/back), `palette_sheet.png` (neutral top row,
amber key/teal fill bottom row), `wrap_sheet.png`, `hang_sheet.png` (front, side, back, three-quarter, other side,
below + Workbench front/side), `lod_poses_sheet.png` (rows LOD0/1/2 x Spread, Up, Down, Recover, Wrap, BankLeft,
BankRight, Hang), `flap_sheet.png` (16 frames front + three-quarter), `iterations/r01..r20_*` (every round), `_tiles/`.

### Open risks / not verified
- Nothing imported into Unreal this phase (recipe unchanged, so the Phase 2 Unreal proof stands for axes/scale);
  `cellar_bat_validation_ue.py` still points at the Phase 2 blockout files. The VertexColor material graph, the LOD
  import and two-sided membrane shading in 5.7 are unverified.
- Same-wing pleat contacts in folds (up to 44 pairs at the highest upstroke) are counted, not inspected per pair.
- The fold slider interpolates Euler angles between solved states (0 / 0.5 / 1); 0.25 and 0.75 are clean, other values
  are not individually checked.
- Lit look judged in Blender EEVEE only; the warm comparison key is a presentation choice, the neutral rig is the
  palette check.

## Phase 3b - wrap cloak, membrane palette, ears (2026-11-05, DONE - awaiting Fable audit)

Brief: `PHASE_3B_BRIEF.md`. Executor: Opus. Evidence in `review/phase3b/`; Phase 3 sheets left in `review/phase3/` for the
before column. Phase 3 scripts/blend/exports backed up outside the repo before the first edit (session scratchpad).

### Commands (same as Phase 3; outputs now land in `review/phase3b/`)
```bash
B="C:/Program Files/Blender Foundation/Blender 5.2/blender.exe"
"$B" -b --factory-startup --python scripts/build_cellar_bat.py -- --solve-wrap   # ~6 min with the solve; plain build loads wrap_solution.json
"$B" -b --factory-startup source/CellarBat_R01.blend --python scripts/render_cellar_bat.py -- --tag r01
python scripts/sidebyside_phase3b.py        # Pillow only: concept | Phase 3 | Phase 3b
"$B" -b --factory-startup source/CellarBat_R01.blend --python scripts/export_cellar_bat.py
"$B" -b --factory-startup --python scripts/validate_roundtrip.py
```
Last runs, in that order on the final build: build exit 0 `CELLAR_BAT_OK` (`review/phase3b/build_log.txt`), renders exit 0
(`render_log.txt`), export exit 0 `CELLAR_BAT_OK` (`export_log.txt`, BAKE 16 frames / 42 bones / 1.6e-5 cm), round trip exit 0
`CELLAR_BAT_OK`, `fails []` (`roundtrip_log.txt`, `export/validation/roundtrip_report.json`). **confirmed**

### 1. Wrap cloak (fold slider = 1; the Hang pose is the same fold + body inverted)  **confirmed** (counts + renders)
How: the wrap is no longer free per-bone aim points. `wrap_spec` (builder) now places the elbow at the flank
(`WRAP_ELBOW` u -7, phi 115), the wrist up at the shoulder (`WRAP_WRIST` u 3.5, phi 55), and each finger segment WALKS its
own bone length over a shell around the torso (`shell_walk`) along a heading (`WRAP_FAN` left/over: f1 85/80 deg ... f4
5/30; `WRAP_FAN_UNDER` right: f1 60/45 ... f4 0/25; 0 = down the body axis, 90 = across the front). Each aimed bone gets a
**lie-flat twist** (`apply_pose`, new `flat` term): its rest in-plane direction toward the neighbouring finger is turned onto
the posed chord to that finger, so the panels lie on the body; finger 4's chord runs to the flank line so the inner panel
hugs the side. `solve_wrap` then searches small twist offsets (+-45 deg, steps 15/7.5/3.75; upper arm and thumb free)
scoring Wrap AND Hang at all three LODs (penetrations x10/x20/x30 + hug term). Clearances: under fan 3.0 cm, left over
right +1.6 (`WRAP_C`, `WRAP_LAYER`), arms 2.8 (+0.8 left), elbow +1.6; the skirt below u -8 keeps that ring's girth
(`WRAP_SKIRT_U`) so the hang tapers toward the feet. Thumb aimed flat along the top edge (`WRAP_THUMB`). Bone lengths,
span (75.000) and proportions unchanged; nothing scaled, hidden or detached. No deviation needed.

Cross-part intersections (memb-body, memb-legs, ribs-body, ribs-legs, memb L-R, ribs L-R, memb-opposite ribs), posed
through the rig, from `review/phase3/measurements.json` (before) and `review/phase3b/measurements.json` (after):

| pose | before LOD0/1/2 | after LOD0/1/2 | pleat self L/R LOD0 before -> after (info) |
|---|---|---|---|
| Spread | 0/0/0 | 0/0/0 | 0/0 -> 0/0 |
| Up | 0/0/0 | 0/0/0 | 44/44 -> 44/44 |
| Down | 0/0/0 | 0/0/0 | 0/0 -> 0/0 |
| Recover | 0/0/0 | 0/0/0 | 19/19 -> 19/19 |
| HalfFold | 0/0/0 | 0/0/0 | 3/3 -> 3/3 |
| Wrap | 0/0/0 | 0/0/0 | 12/21 -> 106/76 |
| BankLeft / BankRight | 0/0/0 | 0/0/0 | 0/0 -> 0/0 |
| Hang | 0/0/0 | 0/0/0 | 12/24 -> 98/76 |

Fold slider 0.25 / 0.75: 0 / 0 (pleats 0 / 42+26). All 16 flap frames: worst 0. Rig vs direct: max 2.1e-5 cm, 0.0 deg.
Hang: IK ankle error 0.0, 12 foot verts per foot within 0.25 cm of the bar, 1 inside, bar (3.0, 0, 18.75).
Cloak metrics (new in measurements.json): mean membrane stand-off beyond a 3 cm shell 0.691 -> 0.179 cm
(`wrap_standoff_cm`); left-over-right layering on the front, `wrap_layering`: 65 left verts over the right fan, gap min
0.48 / p10 0.72 / median 1.32 / p90 1.66 cm. The pleat contacts rose because the fans now lie flat and their panels
fold against each other; they are counted, not inspected per pair (inferred benign: same-wing panels, renders clean).
Look at: `review/phase3b/sbs_wrap.png`, `sbs_hang.png` (concept | Phase 3 | Phase 3b), `wrap_sheet.png`, `hang_sheet.png`,
`lod_poses_sheet.png`. Iteration renders of the rounds are in the session scratchpad (t01..t18), not kept.

### 2. Palette  **confirmed** (vertex bytes in the build; lit values sampled from the renders)
Membrane `#713B46` -> `#803E40` (G = B: the old blue bias rendered magenta); materials: Membrane roughness 0.65 -> 0.80,
Body 0.80 -> 0.85, Principled Specular IOR Level 0.5 -> 0.25 on both (`make_material(spec=)`, also stored as
`mars_specular`); no transmission. Ribs stay `#B7A18A`, fur stays `#433831` (base was not drifted; the grey cast came from
the specular). Ear inner `#6B4B45` -> `#7A4842`; ear rim faces use hood `#544439`.
Lit front-view means (visible faces, spread pose, `pal_probe` in the scratchpad), sheet 02 FRONT membrane ~`#633535`:

| rig | membrane before -> after | fur | ribs |
|---|---|---|---|
| neutral front | `#553037` -> `#603233` | `#524842` -> `#4E423C` | `#A6917E` -> `#A7907C` |
| amber/teal front | `#4D2A30` (warm, before) -> `#502C28` | `#44392B` | `#937B5A` |

Look at: `sbs_palette.png` (rows: neutral front, amber/teal front, neutral three-quarter, warm compare front),
`palette_sheet.png`, `compare_sheet.png`. Unreal: the material-instance plan in Phase 3 should take roughness 0.8 /
specular 0.25 (inferred equivalent; unverified in 5.7).

### 3. Ears  **confirmed** (geometry params + renders; ear base-to-tip 10.000)
`build_ear` keeps the 8-vertex ring and the 10 cm length, now with a deeper back shell (`EAR_SHELL` 1.8 cm at the base), a
wide brown rim band (`EAR_RIM` 1.05) standing forward of a cupped inner face (`EAR_LIP` 0.9, `EAR_CUP` 1.1), and the opening
turned 35 deg out to the side (`EAR_FACE_OUT_DEG`) so the cup and rim read in profile instead of a fin. Half width stays
4.4: 4.9 put the ear into the upper arm at the highest upstroke (ribs-body 4/6 at flap f00), so it was reverted. LOD tri
counts unchanged (6482 / 2648 / 1202; render verts 19446 / 7944 / 3606). Look at: `sbs_ears.png`, `ref_eevee_sheet.png`.

### Contract  **confirmed**
42 bones, names/parents per RIG.json, slots `Body, Membrane, Eyes`, export recipe unchanged, control rig unchanged (fold
tables re-captured from the new solve; `scripts/wrap_solution.json` rewritten). Every LOD: defects 0, UV0 overlap 0, max 4
influences. Round trip: span 75.000, colour RGBA error 0.0, every triangle matched.

### Still differs from the sheets (not fixed)
- The back stays bare fur in wrap and hang: the inner panel attaches along the flank, so the folded wings can cover the
  front and sides only. Covering the back would need a different membrane attachment, not a fold solve.
- Pale ribs read stronger than on the sheet (the sheet's bones are close to the membrane value); the wrap hem still shows
  finger tips as short points below the cloak, and the right (under) fan shows at the bat's right front.
- Fur renders grey-brown; the sheet fur is redder (~`#553B38` swatch). Kept `#433831` as briefed.
- Ears are still narrower than the sheet's (width capped by the upstroke clearance); eyes unchanged.
- Hang top flares a little at the feet end (the inner-panel corner follows the shin up to the bar).

## Phase 4 - all 18 clips, baked, reviewed in motion, exported (2026-11-05, DONE - awaiting Fable audit)

Brief: `PHASE_4_BRIEF.md`. Executor: Opus. Evidence in `review/phase4/`, `export/anims/`, `export/CellarBat_R01_Manifest.json`.
Phase 3b blend/scripts/exports backed up outside the repo before the first edit (session scratchpad `p4/backup`).

### Commands (run from this folder; each prints CELLAR_BAT_OK / CELLAR_BAT_FAIL and exits non-zero on failure)
```bash
B="C:/Program Files/Blender Foundation/Blender 5.2/blender.exe"
"$B" -b --factory-startup source/CellarBat_R01.blend --python scripts/animate_cellar_bat.py   # [-- --clips A,B] [--no-save] [--no-audit] [--detail] [--keys]   (~13 s)
"$B" -b --factory-startup source/CellarBat_R01.blend --python scripts/render_anims_cellar_bat.py -- --clips A,B   # tiles + sequences (~40 s per 6 clips)
python scripts/sheets_phase4.py                                                              # Pillow: sheets + strips
"$B" -b --factory-startup source/CellarBat_R01.blend --python scripts/export_anims_cellar_bat.py   # bind + LODs + 18 clip FBX + manifest
"$B" -b --factory-startup --python scripts/validate_roundtrip.py                             # Phase 3 checks + every clip
```
Last runs, in this order on the final scene: animate exit 0 (`review/phase4/animate_log.txt`, 18/18 clips zero cross-part
contact at LOD0/1/2), renders exit 0 x3 (`render_log_*.txt`), export exit 0 (`export_log.txt`), round trip exit 0
`CELLAR_BAT_OK`, `fails []` (`roundtrip_log.txt`, `export/anims/roundtrip_report.json`). **confirmed** (exit codes + markers).
The rebuild path is unchanged: `build_cellar_bat.py` rebuilds the Phase 3b scene WITHOUT the clips; run animate after it.

### Scripts (new unless marked)
- `scripts/animate_cellar_bat.py` - pose library + clip definitions + authoring + bake + per-frame audit; saves the blend.
  Pose language = the builder's (`build_cellar_bat.pose_rotations`, imported, its main() not run) + rig sliders + per-control
  offsets (`extra`: bone -> [(axis, deg)]) + two captured rig poses read from the Phase 3 pose actions (`Hang`, `Wrap`).
  Timing: each control channel (loc xyz + quat wxyz per control bone) is a Catmull-Rom spline through the keys, periodic
  for loops, eased at the ends of one-shots and at listed `ease` keys (stroke turnarounds); group lags give overlap
  (fingers + fan 0.5-2 fr = membrane drag, ears 1-3 fr, legs 1-3 fr = trailing feet); `layer` functions add breathing,
  tremble, wobble. Keys are written on every frame from those functions (generated, not hand-typed).
  `fold_corrective` (see Findings) and `hand_untwist` (see Fixes) are part of the library.
- `scripts/render_anims_cellar_bat.py` - renders the BAKED export actions (rig muted) with fixed cameras: contact-sheet
  tiles (front / side / three-quarter / top x up to 8 frames incl. 0, N and markers), real-time sequence
  `review/phase4/<Clip>/frame_###.png` (three-quarter), half-speed `review/phase4/<Clip>_half/` (0.5-frame steps) for
  Hover, Launch, Perch, Swoop, RoostIdle. EEVEE neutral rig, 400x300, perch bar shown for the four roost clips.
- `scripts/sheets_phase4.py` - `<Clip>_sheet.png` (labelled 4-up sheet + audit verdict) and `<Clip>_strip.png` /
  `<Clip>_half_strip.png` (every sequence frame in one grid) - the files to look at.
- `scripts/export_anims_cellar_bat.py` - recipe of `export_cellar_bat.py` unchanged (imports its COMMON/BIND/CLIP args):
  bind + LOD1 + LOD2 re-exported at rest, one FBX per clip, `export/anims/expected_anims.json`, the manifest.
- `scripts/validate_roundtrip.py` (extended) - `check_anims`: each clip FBX into a fresh scene; bones+parents, one action,
  keyed frames == first..last and sample count, root bone == rest on every sample, loop seam (first == last), bone-head
  landmarks (knuckles f1/f3, wrists, head, jaw, ankles, ear tip) on EVERY frame within 0.1 cm, skinned mesh extremes
  (wing tips +-Y, top, bottom) on EVERY frame (includes the flap keys 0/4/8/12/15) within 0.1 cm.
- `scripts/export_cellar_bat.py`, `bake_cellar_bat.py`, `bat_rig.py`, `bat_audit.py`, `build_cellar_bat.py`: unchanged.

### Conventions (stable for every clip)
- **Loops: N+1 samples, frame N duplicates frame 0** (Hover/FlyForward 16, Glide/Stun 31, RoostIdle 61) - the CSV
  sample_count and PRODUCTION_SPEC section 4. Unreal reads N+1 keys, length N/30 s; play looping without holding the seam.
- **Clip FBX = export armature + LOD0 mesh + exactly one action** (`bake_anim_use_all_actions=False`,
  `bake_anim_use_nla_strips=False`, scene range = the clip range).
- Export action names = the clip name exactly (`Hover`, ...); control actions `CellarBat_R01_<Clip>_Ctl`. On import Blender
  names the take `Armature|Scene`; Unreal names the asset from the import destination.
- **Additive banks:** `BankLeft`/`BankRight` are full one-frame poses authored as **Hover frame 0 + the bank intent**
  (body roll -/+25 deg toward the bat's own left/right, inner wing -30 elev +10 sweep +10 twist, outer -4 elev -8 sweep
  (its height comes from the roll), head counter-roll 12 deg + neck 5, ears splayed in). Reference pose = **Hover frame 0**
  (recorded in the manifest `clip_contract.additive_reference_pose` and on both clip entries). Building them on the
  reference keeps the additive delta = only the bank (a bank built on a spread pose would add a spread offset on top of
  every flap frame). They therefore look like a rolled high-V, not the sheet's spread bank. Decision made rather than
  asked; say if you want them on Glide frame 0 instead (one constant `ADDITIVE_REF` + the base in `build_clips`).
- Root bone identity on every sample of every clip: asserted by the bake (`root_max_deviation` 0.0) and the round trip
  (`root_max_dev` 0.0). No pelvis translation is keyed anywhere (rotation-only body acting); no scale keys.

### Clip table  **confirmed** (`review/phase4/anim_report.json`, `export/anims/roundtrip_report.json`)
Seam: pose error frame N vs 0 / second difference of bone heads at the seam vs the largest inside the clip (cm per frame^2;
<= means the seam is as smooth as any other frame). Feet drift = foot (toe) positions vs RoostIdle frame 0 over the frames
in brackets. Bake = baked (rig muted) vs live rig, max over frames.

| clip | frames | samples | loop seam | markers (presentation only) | feet drift on the bar | bake err |
|---|---|---:|---|---|---|---|
| RoostIdle | 0-60 | 61 | 5e-6 cm, 0 deg; 0.001 <= 0.064 | - | 0.0001 cm [0-60] | 9e-6 cm |
| RoostAlert | 0-18 | 19 | - | - | 0.0000 [0-18] | 1.2e-5 |
| Launch | 0-24 | 25 | - | ReleaseContact 6 | 0.0000 [0-5] | 1.3e-5 |
| Hover | 0-15 | 16 | 5e-6, 0; 5.81 <= 7.48 | Wingbeat 6 | - | 1.0e-5 |
| FlyForward | 0-15 | 16 | 2e-6, 0; 5.12 <= 6.33 | Wingbeat 6 | - | 1.2e-5 |
| Glide | 0-30 | 31 | 2e-6, 0; 0.010 <= 0.045 | - | - | 1.2e-5 |
| BankLeft | 0-1 (CSV 0-0, DEV-10) | 2 identical | additive vs Hover f0 | - | - | 1e-5 |
| BankRight | 0-1 (CSV 0-0, DEV-10) | 2 identical | additive vs Hover f0 | - | - | 7e-6 |
| Brake | 0-18 | 19 | - | - | - | 1.7e-5 |
| Perch | 0-24 | 25 | - | FootContact 12 | 0.0000 [12-24] | 1.2e-5 |
| Screech | 0-24 | 25 | - | ScreechSound 9 | - | 1.3e-5 |
| SwoopTelegraph | 0-18 | 19 | - | - | - | 1.7e-5 |
| Swoop | 0-18 | 19 | - | SwoopContact 9 (visual contact) | - | 1.3e-5 |
| SwoopRecover | 0-18 | 19 | - | - | - | 1.8e-5 |
| Hit | 0-12 | 13 | - | - | - | 1.1e-5 |
| Stun | 0-30 | 31 | 8e-6, 0; 0.82 <= 1.87 | - | - | 1.6e-5 |
| DeathFall | 0-21 | 22 | - | - | - | 1.6e-5 |
| DeathLand | 0-18 | 19 | - | - | - | 1.5e-5 |

Clip contents: Hover = keys 0 Up (elev 44, wrist folded) / 4 Power / 8 Down (elev -50) / 12 Recover (elbow 62, wrist -36)
/ 15 = 0, chest pitch -4..+5 and spine response, ears lag 2, fingers 1.5, legs 2.5. FlyForward = same cycle, body +24
pitched, head -16, downstroke -38, legs trailing 30. Glide = spread + 1 s breath. RoostIdle = Hang (fold 1, perch 1, IK on
the bar) + spine breath (1 s) + one ear twitch (34-44). RoostAlert = partial unwrap (fold 0.82-0.90), ears alert, head lifts
toward +X. Launch = hold on the bar to 5, feet released by 10 (perch 1 -> 0), pelvis hang -> half turn -> dive (head
forward, belly down) -> pull-up Up -> Power -> first Down at 24. Brake = one beat then wings cupped forward, feet forward.
Perch = brake -> pitched back with feet forward (5) -> swing (7-9, wings folding) -> feet on the bar at 12 (perch 1) -> wrap
by 24 == RoostIdle frame 0. Screech = dip 4, jaw open + ears back + wings braced at 9, shudder 9-17, back to Hover f0.
SwoopTelegraph = beat, rear up with wings high, quiver. Swoop = tuck 5 (body +40), feet/jaw strike 9, reopening.
SwoopRecover = one hard pull-out beat to Hover f0. Hit = snap at 2 (left wing flung up, right dropped, roll), settle to Hover
f0 by 12. Stun = half-rate weak flap, lopsided wobble, ears flat (loop 30). DeathFall = jolt 4, limp by 21 (body +50, head
dropped, wings up and back). DeathLand = DeathFall end -> impact 3 -> bounce -> belly-down, wings flat by 18.
Deviations from the CSV: **DEV-10 only** (names, fps, loop flags and every other range/sample count equal):
- **DEV-10 (justified, 2026-11-05, coordinator request after the Unreal import):** BankLeft/BankRight export **2 identical
  samples on frames 0..1** (one key held; frame 1 == frame 0, landmark difference 0.0) instead of the CSV's 0-0 / 1 sample.
  CSV says 0-0; padded to 2 identical samples because the Unreal FBX importer rejects a zero-length take ("Animation Stack
  Scene does not contain any valid key", SkeletalMeshEdit.cpp:384 rejects duration <= 0; no import option pads it). Same
  pose, same bake, same additive reference (Hover frame 0). Re-done with `animate_cellar_bat.py -- --clips
  BankLeft,BankRight` and `export_anims_cellar_bat.py -- --clips BankLeft,BankRight` (merges into the manifest and
  expected_anims.json; no other FBX rewritten). Recorded in the manifest (`clips.<Bank>.csv_deviation`, additive_note),
  `clips.json` note and the clip table above.
Swoop's contact marker is named `SwoopContact`; Hover/FlyForward carry the optional `Wingbeat`.

### Intersection audit  **confirmed** (`anim_report.json` `per_frame`, every frame of every clip, baked pose)
Cross-part pairs (memb-body, memb-legs, ribs-body, ribs-legs, memb L-R, ribs L-R, memb-opposite ribs) summed:

| clip | LOD0 frames with contact | LOD1 worst | LOD2 worst | pleat self L/R max (info) | attachment memroot/ribroot max (info) |
|---|---|---:|---:|---|---|
| RoostIdle | none | 0 | 0 | 100/82 | 66/48 |
| RoostAlert | none | 0 | 0 | 98/109 | 78/48 |
| Launch | none | 0 | 0 | 169/169 | 84/62 |
| Hover | none | 0 | 0 | 105/105 | 84/64 |
| FlyForward | none | 0 | 0 | 197/197 | 84/60 |
| Glide | none | 0 | 0 | 0/0 | 66/54 |
| BankLeft / BankRight | none | 0 | 0 | 75/116, 116/75 | 71/59 |
| Brake | none | 0 | 0 | 108/108 | 88/74 |
| Perch | none | 0 | 0 | 102/115 | 86/68 |
| Screech | none | 0 | 0 | 114/114 | 76/64 |
| SwoopTelegraph | none | 0 | 0 | 108/108 | 84/64 |
| Swoop | none | 0 | 0 | 264/264 | 78/64 |
| SwoopRecover | none | 0 | 0 | 117/117 | 84/64 |
| Hit | none | 0 | 0 | 130/121 | 80/68 |
| Stun | none | 0 | 0 | 50/54 | 80/60 |
| DeathFall | none | 0 | 0 | 160/146 | 78/65 |
| DeathLand | none | 0 | 0 | 152/144 | 80/100 |

Attachment contacts are the designed membrane-root rows on the flank and the upper-arm roots inside the shoulder (same
definitions as Phase 3; present in the bind pose too). Same-wing pleat contacts are counted, not inspected pair by pair
(max 264 in the Swoop tuck, where the fan closes); inferred benign (same panel folding on itself, renders clean).

### Findings and fixes (what I looked at and what changed, one issue per round)
1. Exaggerated upstroke (elev 52) put the upper arm into the head/ears (ribs-body 37-41). Searched elev x sweep x head x
   ear splay: **Up = elev 44, sweep -24, head +12 (ducks), ears splayed in 10** (all flap keys carry the ear splay). The
   wrist fold (30/26) and recovery fold (62/-36) carry the extra exaggeration.
2. Downstroke membrane edge-on from the front (Phase 3 note: twist 36). Lower arm twist re-grazes the flank (searched: twist
   24 -> 7 pairs, 0 -> 23). Fix: `hand_untwist(0.6)` turns fingers 1-3 back toward the stroke plane (graded 30/24/14/4 deg x
   0.6 about the span axis) while finger 4 / the inner panel keep the arm twist: front-projected membrane area +38% at k 0.5 and
   +83% at k 1.0 (static search; 0.6 not measured on its own), zero contact (k 0.8 grazed in transitions).
3. Membrane-to-flank grazes in one-shots whenever the arm reached Down straight from Up (fingers still lagging the Up
   fan/curl). Rule applied in every clip: Up -> Power -> Down -> Recover, never Up -> Down; dropped wings keep the Down's
   small flex (flex 20 on a dropped wing grazed in Hit).
4. **Rig finding: the fold slider grazes the flank between 0.55 and 0.70** (5-8 pairs on the Wrap base; 0.5 and >= 0.75
   clean) - the Euler interpolation between the solved half fold and wrap (Phase 3 only checked 0.25/0.75). Not fixed in
   the rig (would reopen the Phase 3 solve); every clip applies `fold_corrective`: upper arm +8 elev / +8 sweep / -8 adduct
   weighted by a smooth function of the slider value (full on 0.55-0.70, zero below 0.48 / above 0.76) - continuous and
   loop-safe. Searched: legs, flex, twist alone do not clear it; that combination clears the whole band.
5. Folded states off the bar must use the wrap's legs (spread -6), not the hang's aimed legs, and perch 0: the inherited
   perch 1 pulled the legs to the bar mid-Launch (26 pairs). `l0b` base = Hang minus inversion, wrap legs, feet free.
6. DeathFall read as an upright flier with half-raised wings; reworked to a forward collapse (body +50, head dropped,
   wings up and back). DeathLand wing tips stood above the body; sweep 44/38 lays them at body level (tips z -7..+3 vs
   belly -8).
7. Perch reach barely changed in the first 5 frames; pelvis now pitches back 70 with feet forward. (Still subtle in the
   three-quarter strip; reads in side view.)
Look at: `review/phase4/<Clip>_sheet.png` (all 18), `Hover_half_strip.png`, `Launch_half_strip.png`, `Perch_half_strip.png`,
`Swoop_half_strip.png`, `RoostIdle_half_strip.png`, `Launch_strip.png`. Sequences: `review/phase4/<Clip>/frame_###.png`.

### Export + round trip  **confirmed**
- `export/CellarBat_R01_Mars_SK.fbx`, `_LOD1_`, `_LOD2_` re-exported from the final scene (tris 6482 / 2648 / 1202, slots
  Body, Membrane, Eyes, 42 bones, morphs none); `export/anims/CellarBat_R01_<Clip>_Mars_ANIM.fbx` x 18;
  `export/CellarBat_R01_Manifest.json` (versions, units/axes + exporter args, dimensions, LOD counts, bones+parents, slots,
  morphs [], clip contract, clips with fps/frames/samples/loop/markers/source control action/export action/file/Unreal
  path, additive reference, export paths, intended Unreal paths for SK/SKEL/PHYS/ANIM/MI).
- Round trip (`export/anims/roundtrip_report.json`): 18/18 clips one armature + one mesh, 42 bones, 0 mismatched parents,
  one action, keyed frames == 0..N with N+1 samples (BankLeft/Right 0..1, 2 samples after DEV-10), root max deviation 0.0, loop seam landmark
  error <= 1.1e-5 cm, bone-head landmarks max 0.0013 cm, skinned mesh extremes max 0.0012 cm (tolerance 0.1).
  The Phase 3 checks (cube, LOD0/1/2 geometry, colours, UV0, weights, flap test clip) still pass on the re-exported files.
- Round-trip gotchas found: FBX keeps no bone tails (leaf bone lengths change on import, a constant 2.35 cm "error" on tail
  landmarks), so landmarks are bone heads + mesh extremes; a point extreme can swap between two near-equal wing tips
  (Perch, 16 cm false alarm), so extremes are compared as scalars.

### Open risks / not verified
- Nothing imported into Unreal by this executor (no Unreal writes by brief): the additive setup against Hover frame 0 and
  the N+1 loop import in 5.7 are unverified here. The 1-sample banks were rejected by the Unreal importer (zero-length
  take) -> DEV-10; the 2-sample re-export has not been re-imported by this executor.
- Contacts are triangle-pair overlaps of LOD0-2 at integer frames; sub-frame blends in Unreal (and blending between
  clips, e.g. Hover + additive bank at full weight on a Down frame) are not audited.
- Launch/Perch body flips: the rotation path between hang and flight is an axis-angle half turn (a twisting drop / swing).
  It reads in the strips; whether it reads at game distance is a PIE judgement. Perch's 4-frame swing (7-11) is fast.
- RoostAlert's "head turn toward +X" is a head lift (the face already faces +X in the hang); no yaw.
- Markers are frame numbers in the manifest only (no FBX notifies); the Unreal side must add them.
- Same-wing pleat contacts counted, not inspected pair by pair.
- The rig's fold-slider band (0.55-0.70) remains in the rig itself; anyone keying the slider by hand must use the corrective
  or stay out of the band.

## Phase 6a - baseline (runtime track)

Brief: `PHASE_6_BRIEF.md`. Executor: Opus (runtime track, parallel to the Blender track).

### Baseline (before any Script/ edit, 2026-11-05 22:41)

- Command: `./CkAuto/UnrealToolbox.exe --test --test-pattern Monster --output=Saved/Logs/Test-Bat-Baseline.log
  --project="D:\Repositories\CkRepos\Orion"` -> **EXIT 0**, Total 3 / Passed 3 / Failed 0 / Contaminated 0 (focused).
  Passing: `Mars_AutoTest_Crawler_ComposesWalkerPartsAndMonster`, `Mars_AutoTest_Monster_BodyDepletionSetsDeadAndSignals`,
  `Mars_AutoTest_Monster_RegisterPartTalliesOnce`. Known reds block: 81 listed, "no listed test ran in this run, and there
  were no new failures". **confirmed** (summary block + `Test Completed` lines in `Saved/Logs/Test-Bat-Baseline.log`).

## Decisions

- D-1 Four fingers + two-segment thumb per wing, 42 export bones exactly as `RIG.json` (the v1 three-finger notes are
  superseded).
- D-2 (settled after the runtime brief) Flight = CkCrowd flying agent (`_AgentMode = Flying`) bound to a CkVoxelNav
  volume authored in the review map, the stack CkTests' `CkVoxelNavGym_FlyingVsGrounded` already proves. The bat kernel
  owns phases/clocks/targeting/swoop ledger and issues MoveTo/Stop; the agent is the only root-transform writer while
  alive. No Mars feature does free 3D movement (Mover is a two-pose tween; Crawler/RootMaw/PickleMimic are
  SurfaceMotion walkers), so nothing existing is reused for travel. Attack = RootMaw's per-frame `Request_StrikeSweep`
  + ledger (one hit per committed swoop). Monster plumbing = `utils_monster::Add`.
- D-3 Phase 6a (kernel/HFSM/assembly/map builder/tests, `WithVisuals` switch + placeholder body) runs in parallel with
  the Blender phases; Phase 6b (AnimBP, PIE review, captures) waits for the imported mesh and clips.

## Phase 6a - runtime candidate (DONE headless, 2026-11-05; PIE/visual review is Phase 6b)

Brief: `PHASE_6_BRIEF.md`. Executor: Opus. Nothing committed or pushed; no git state changed by this executor.

### Files (all new unless marked)

- Kernel `Script/ECS/Bat/`: `Mars_Bat_Feature.as` (handle `FCk_Handle_Bat`, enums, `FMars_Bat_Spec` in sub-structs,
  fragments, roost-claim fragments on the perch entity, signals, requests), `Mars_Bat_Utils.as` (`utils_bat::Add`,
  `Add_Roost`, `Add_FlightVolume`, getters, request mixins, bindings), `Mars_Bat_Processor_Requests.as` (bat drain +
  `UMars_Processor_BatRoost_HandleRequests` / `_Tick`), `Mars_Bat_Processor_Setup.as`, `Mars_Bat_Processor_Targeting.as`,
  `Mars_Bat_Processor_Tick.as`, `Mars_Bat_Hfsm.as`.
- Assembly `Script/WorldObjects/Monsters/`: `Mars_CellarBat_EntityScript.as` (`UMars_CellarBat_EntityScript`,
  `UMars_BatRoost_EntityScript`, `UMars_BatFlightVolume_EntityScript`), `Mars_CellarBat_AnimInstance.as`,
  `Mars_SandboxBat.as` (review presets: bat on team Three, dummy + `TAG_MarsCombatTarget`, room volume).
- `Script/Editor/Mars_CellarBat_MapBuilder.as` (`Mars.CellarBat.BuildReviewMap`; human-run only, never loads a level:
  it needs the review map open, or an untitled level the first time).
- `Tools/LevelDesign/cellar_bat_r01_review/cellar_bat_review_ue.py` (`build_review_scene()` / `restore_level(path)` for
  `editor_query run_python`, the pale_crawler pattern) - the Phase 6b entry point. Syntax-checked only, not run yet.
- Tests `Script/Tests/Bat/`: `Mars_AutoTestRig_Bat.as` + 6 `Mars_AutoTest_Bat_*.as`.
- Edited (additive, allowed by the brief): `Script/Generated/DynamicHandleTypes.json` (one `FCk_Handle_Bat` entry; the
  live editor had already self-healed the same entry, my duplicate was removed), `Config/DefaultGameplayTags.ini`
  (`Monster.Mars.Bat`, mirroring `Monster.Mars.RootMaw`).
- Regenerated by the live editor (not hand-edited): `Script/Generated/Mars_EntitySpawnParams.as`,
  `Mars_AutoTestActors.as`, `Mars_ScriptProcessorDrivers.as`; the autotest populator placed 6 wrapper actors in
  `AutoTests_Mars_MAP` (external-actor packages) and auto-saved it.

### Design facts (confirmed by reading the code and by the tests named)

- Movement: CkCrowd agent (`Flying`) on the bat root + CkVoxelNav path; the kernel issues `Request_SetMaxSpeed` +
  `Request_MoveTo(ForceRepath)` / `Request_Stop`. The kernel writes the root only while Falling, after
  `Request_EnableDisable(Disable)` and `euler_integrator::Request_Stop`.
- Route outcomes are explicit (`EMars_Bat_RouteOutcome`, `OnRouteOutcome` once per route generation): NoVolume / NoBake /
  EndpointUnresolvable are refused before a MoveTo (kernel checks `Get_IsBuilt` / `Get_IsPointFree`); Unreachable /
  SearchFailed come from the path's `OnPathFailed`, GoalFailed / GoalBlocked from the agent; the first answer wins and any
  failure stops the agent (so CkCrowd's Recast fallback is not followed). An Approaching route failure drops and ignores
  the target for `HoverRetrySeconds`. A HFSM route condition only trusts a route issued in its own phase (`Route.IssuedIn`).
- Swoop ledger: StartSwoop admitted only by `Get_SwoopAdmission` (alive, idle, not hurt, cooldown 0, valid target, in
  Range, aim point free) -> Telegraphing (cancellable, no damage; target loss -> TargetLost) -> Committed (sweep each frame
  from the last mouth point, only while `HitZones` is empty and the monster is not dead) -> Recovering (no damage) ->
  cooldown. One generation = at most one result; cancel / hit / death end it (`OnSwoopCancelled` with the reason) and the
  tick ends it `Died` the frame the monster is dead, before the HFSM catches up.
- Roost: the claim lives on the perch entity (`FMars_Fragment_BatRoost`: Occupancy, Claimant, ClaimCount, ReleaseCount).
  Released by the Die task's `Request_ReleaseRoost` (latched) or by the roost tick when the claimant is invalid or pending
  destroy - one `Free_Roost` path, so the count goes up once whichever way the bat ends.
- Control: CanSwoop requires the bat within `StrikeTolerance` (70) of its strike point. Without it the first run
  telegraphed at the edge of Range and the committed flight ran out short (observed in the lane log: first swoop missed,
  second landed). Fixed; the happy-path test now asserts `Generation == 1`.

### Runs (toolbox, test-only path beside the live editor; all focused, none is the full gate)

- Baseline: see above (Monster, EXIT 0, 3/3).
- Iteration: `--test --discover-fresh --test-pattern Mars_AutoTest_Bat_ --output=Saved/Logs/Test-Bat.log` -> EXIT 0, 6/6
  (the attempt without `--discover-fresh` exited 1 "No tests matched": cached test list).
- `--test --discover-fresh --test-pattern Bat --output=Saved/Logs/Test-Bat-Final.log` -> EXIT 1, 78/79 (before the CanSwoop
  fix; same single red as below).
- Final, after the last `.as` edit (23:20 UTC reload, clean):
  - `--test --test-pattern Bat --output=Saved/Logs/Test-Bat-Final2.log` -> **EXIT 1**: Total 79, Passed 78, Failed 1,
    Contaminated 0. All 6 `Mars_AutoTest_Bat_*` Success. The red is
    `CkTests.UnitTests.CkGroundNav.LinkState.BatchAdmitsAllOrNothing` (matched by "Batch"; expected Warning
    'batch is admitted whole or not at all' 2 times, found 1), reported NEW (not in knownReds).
  - `--test --parallel 1 --known-reds off --test-pattern "CkTests.UnitTests.CkGroundNav.LinkState.BatchAdmitsAllOrNothing"
    --output=Saved/Logs/Test-GroundNavBatch-Alone.log` -> **EXIT 1**, red alone too (deterministic).
  - `--test --test-pattern Monster --output=Saved/Logs/Test-Monster-Final2.log` -> **EXIT 0**, 3/3, same names as the
    baseline, no new failures.
- GroundNav red ownership: **inferred** not mine - a synchronous C++ unit test of CkGroundNav link state; this task changed
  AngelScript, one gameplay tag and one handle-registry entry only. Not A/B-proven (no stash allowed). Prime suspect: the
  CkFoundation/CkTests C++ in this checkout (sibling work). Not added to knownReds (forbidden).
- Evidence (`Angelscript: [BatTest]` lines in the headless lane logs, final run): happy path phases Roosting, Alert,
  Launching, Approaching, Telegraphing, Swooping, Recovering, Returning, Braking, Perching, Roosting; target hits 1,
  landed 1. Blocked route outcomes Reached (the launch), Unreachable; max frame step 6.3 uu.

### Placeholder pending the Blender track

- `UMars_CellarBat_EntityScript` loads `/Game/ArtCandidates/CellarBat/R01/Meshes/CellarBat_R01_Mars_SK` and the ABP
  `.../Animation/CellarBat_R01_Mars_ABP_C`; until they exist it draws a placeholder (sphere body + two wing slabs) and logs
  one Warning. The ABP must reparent to `UMars_CellarBat_AnimInstance` (Phase, PhaseIndex, Speed, TurnRate, BankAlpha,
  Pitch, SwoopAlpha, IsFlying, IsHanging). Sockets read if present: `Mouth` (warns when > 5 cm from
  `Spec.Swoop.Blow.MouthOffset`, default (26, 0, -4)) and `Perch` (pinned to the perch anchor while hanging). Hanging =
  presentation node rolled 180, never the root.

### Not verified (Phase 6b)

- Nothing visual: no PIE; the review map is NOT built (the console-command attempt hung the editor, see Incidents).
  Build it with `cellar_bat_review_ue.build_review_scene()` via run_python, or by hand from the editor console.
- The flight volume entity script bakes `BuildDelaySeconds` (0.5 s) after setup, assuming the LiveExtract static world is
  in by then (**inferred**). The review map's walls/pillar/beam reaching the bake is unverified.
- The swoop has only been seen landing on a 70 x 70 x 180 test hurtbox; the review dummy (`AimHeight` 80) is untested.
- Multiplayer not addressed (DoesNotReplicate throughout).

## Audit of Phases 3 and 3b (Fable, 2026-11-05 19:40)

- Phase 3 renders inspected (`review/phase3/compare_sheet.png`, `ref_eevee_sheet.png`, `wrap_sheet.png`,
  `hang_sheet.png`): large fidelity step (shingled chest, hooded mask face, curved tapered ribs, broad scalloped inner
  membrane); counts and round trip green **confirmed from the report's numbers, not re-run**. Three gaps sent back as
  Phase 3b: wrap not a cloak, membrane rendering pink-magenta, ears thin.
- Phase 3b inspected (`review/phase3b/sbs_wrap.png`, `sbs_hang.png`, `sbs_palette.png`): palette now on the sheet's
  oxblood; ears cupped; wrap lays the fans flat on the chest with ribs as diagonals, hang hem at the head with feet on
  the bar; zero cross-part intersections at all LODs kept. ACCEPTED for animation. Residual differences recorded:
  ribs read stronger than the sheet, finger tips show at the hem, back bare (flank attachment), pleat contacts
  counted (106/76 wrap) but not inspected pair by pair. LOD2 is 1202 tris (20% over the "about 1k" target), accepted.

## Audit of Phase 4 (Fable, 2026-11-05 20:10)

- Motion sheets inspected (`review/phase4/Hover_half_strip.png`, `Launch_strip.png`, `Perch_half_strip.png`,
  `Swoop_half_strip.png`): full flap cycle (high V -> power -> deep downstroke -> bent-wrist recovery -> seam), launch
  from the wrapped hang through release/rotation into the first downstroke with the root fixed, perch reach -> swing
  -> wrap with feet on the bar, swoop tuck -> extend. ACCEPTED. 18 clips match the CSV; loops N+1 samples with the
  last frame duplicating frame 0 (the importer must not double-hold); banks are one-sample full poses additive
  against Hover frame 0 (decision made by the executor; swap to Glide frame 0 via `ADDITIVE_REF` if the rolled high V
  reads wrong in Unreal); round trip `fails []` per the report, not re-run by me.
- Phase 5 Part B (clip import) released on these files.

## Audit of Phase 5 (Fable, 2026-11-05 20:30)

- Report's readback table accepted (all PASS: span 75.000, bind bounds 0.0004 cm from Blender, 42 bones in order, root
  identity, LOD tris 6482/2648/1202 = Blender, 16 clips N+1 keys with seams within 1e-6, banks 2 identical keys additive
  LocalSpaceBase vs Hover f0, sockets within 0.0001 cm, bounds contain all clips with 3.2 cm margin, cold-read after the
  relaunch and two `replace_existing` reimport passes with 0 diffs, 25 owned assets, no duplicates). Not re-run by me;
  `export/unreal_readback_final.json` is the evidence.
- `review/phase5/mesh_views_sheet.png` inspected: oxblood membrane visible from both sides, amber eyes, but the fur
  reads nearly black under the preview scene's backlit HDRI - Phase 6b-2 must judge the body under the review map's
  neutral and amber/teal rigs before accepting the palette in engine.
- Deviations accepted: physics stopgap (5 generated bodies; head/wrist_l/wrist_r set kinematic + no collision; the
  3-body deletion in the Physics Asset editor is a 30 s maintainer step), LOD screen sizes at importer defaults
  (1.0/0.5/0.25), marker notifies as sound-less PlaySound notifies named `<Marker>_Silent`, sockets on the skeleton
  via Monolith `add_socket`. Manifest `unreal_paths` still says `Meshes/` for the physics asset (actual `Physics/`):
  fix in 6b-2's asset manifest.
- Limitation: Monolith `capture_anim_frames` / `capture_scene_preview` return the bind pose for every frame
  (executor's reading of MonolithEditorActions.cpp: SetPosition + zero-length tick). Animated Unreal evidence comes
  from PIE in Phase 6b-2 only.
- Incidents I-3 (raw `SkeletalMesh.add_socket` from Python killed the editor) and I-4 (`unload_packages`/reload of 23
  live packages killed the editor) recorded by the executor; both rules are now in force.

## Audit of Phase 6b-2 and campaign close (Fable, 2026-11-05 21:20)

- Final gates re-read: `Saved/Logs/Test-Bat-6b2-final2.log` 7/7 by name (BlockedRoute, CancelBeforeCommit,
  DeathDuringSwoop, LostTargetAndInvalidPerch, RoostsAlertsLaunchesAndSwoopsOnce, StaleRouteAnswerIsIgnored,
  TeardownReleasesBindingsOnce), `Test-Monster-6b2-final2.log` 3/3, contaminated 0, both 21:09-21:10 local, after
  the last script edit. **confirmed**. Focused runs only; the full gate was never run (maintainer rule).
- PIE frames inspected: `captures/final_light_roost3_body_lifted/frame_006.png` (wrapped under the beam, toes on it),
  `final_p_roost_lod_patrol_perch/frame_114.png` (underside, level flight), `final_s2_swoop_hit_stun/frame_117.png`
  (dive at the post at contact), `final_d_death/frame_060.png` (corpse holding DeathLand). **confirmed by looking**.
  Hit ledger per the report: 5/5 and 4/4 landed swoops = dummy hits, 0 after death; stun cancels a telegraphed swoop.
- Residuals handed to the maintainer: physics asset head/wrist_l/wrist_r bodies to delete by hand; prep assets
  `Animation/CellarBat_R01_Mars_ABP`, `_Locomotion_Mars_BS1D`, `Additive/*` superseded by `_Final_` (delete with the
  editor closed); FlyForward->Glide never blends (Glide sample 620 above the patrol speed); perch rise ~60 cm in
  0.33 s (HangOffset vs clip hang height); LOD screen sizes at importer defaults; `LogPhases` review logging on in
  the preset; review map lighting is dim so the fur reads dark in engine even after the Body MI lift; the first swoop
  of a sortie can run out short at low frame rates. Multiplayer, packaged build and performance: not addressed, no
  claim. Nothing committed or pushed. Captures under `Tools/LevelDesign/cellar_bat_r01_review/captures/` are 4.2 GB
  of PNG frames (untracked): keep the named evidence frames, the rest is disposable.

## Audit of Phase 6a (Fable, 2026-11-05 18:30)

- Logs re-read: `Saved/Logs/Test-Bat-Final2.log` 78 passed / 1 failed / 0 contaminated (the one red is
  `CkTests.UnitTests.CkGroundNav.LinkState.BatchAdmitsAllOrNothing`, a C++ CkTests unit test matched by the `Bat`
  substring, red alone too, not in any knownReds list, untouched by this task; prime suspect: the CkTests/CkFoundation
  C++ in this checkout); `Test-Monster-Final2.log` 3/3. **confirmed**. Focused runs only; no full gate.
- Code read in full: Feature, Utils, Processor_Requests, Processor_Tick, Processor_Setup, Hfsm. Doctrine holds; the
  swoop ledger (one generation, sweep only while HitZones is empty and the monster is not dead) and the roost release
  (Die path or claimant-gone path, never both) are correct by construction. **confirmed by reading**, exercised by the
  six tests.
- Follow-ups folded into Phase 6b-1 (cheap hardening, not blockers): (a) stamp `_CorrelationId = Route.Generation` on
  the crowd MoveTo and ignore goal answers for another generation where the payload exposes it; (b) also gate the
  sweep on `Monster.Get_BodyHealth().Get_IsDepleted()` so the frame between depletion and the Dead latch cannot deal.
- `Config/DefaultGameplayTags.ini` diff = the editor's auto-generated `Mars.SmState.Bat.*` rows + `Monster.Mars.Bat`
  + one stray blank line after the METADATA header (editor rewrite; harmless, the gate rewrites this file anyway).

## Phase 6b-1 - kernel hardening, review map, first PIE (2026-11-05, runtime track)

Brief: `PHASE_6B1_BRIEF.md`. Executor: Opus. No git state changed; nothing committed.

### Kernel hardening (done, tests green)  **confirmed**
- `utils_bat::Issue_Move` (`Script/ECS/Bat/Mars_Bat_Processor_Requests.as`) stamps the crowd MoveTo with
  `Set_CorrelationId(Route.Generation)`.
- `FCk_CrowdAgent_GoalFailedInfo` / `GoalBlockedInfo` carry **no** correlation id (read
  `CkCrowdAgent_Fragment_Data.h:809-866`). So `UMars_Processor_Bat_Setup::OnGoalFailed/OnGoalBlocked` now stamp their
  `FMars_Request_Bat_RouteResult` with `utils_crowd_agent::Get_ActiveMoveCorrelationId(Agent)` (the agent sets it only
  when it accepts a MoveTo, `CkCrowdAgent_HandleRequests_Processor.cpp:370`), and `HandleRouteResult` drops an answer whose
  `Generation` (new `TOptional<int32>` on the request) differs from `Route.Generation`. **Deviation from the brief:**
  `OnGoalReached` is stamped the same way (the brief said leave it). PIE run 9 showed why it has to be: the launch's late
  OnGoalReached (route 6) was credited to the Approach route 7 issued the frame before. The voxel path's Unreachable for
  route 7 then found the route no longer Pending, so the agent was never stopped and the bat sank to (-600,0,-1297) under
  the floor. With the stamp (run 10) the late answers for the launch routes (18, 38) are dropped and every Approach gets its
  Unreachable. The voxel path's `OnPathFailed` stays unstamped. Residual (inferred): an answer the agent broadcasts after it
  has already accepted a newer MoveTo reads the newer id.
- `UMars_Processor_Bat_Tick`: new `Get_IsDying` = `Get_IsDead()` or `Monster.Get_BodyHealth().Get_IsDepleted()`;
  `TickSwoop` ends the swoop `Died` + stops the agent on it, and `Sweep` checks it again before the strike.
- Two kernel bugs found in PIE and fixed (outside the brief's two edits, both small, test-gated):
  - `Get_HasPerch` (`Mars_Bat_Utils.as`): a Pending claim queued on a live roost (owner set, not granted yet) read as "no
    perch", so a discovering bat went Roost -> Hover on its first frame (PIE run 2, t=0.06). Now Pending counts as a perch
    while the owner is still a roost; TickPerch still turns it Lost when the roost goes or is taken.
  - `Issue_Move` immediate refusal (NoVolume/NoBake/EndpointUnresolvable) now drops an Approaching target the same way a
    late failure does (new `utils_bat::Try_DropApproachTarget`, shared with `HandleRouteResult`). Before, the Approach state
    waited forever on a route that was never issued (PIE run 2: NoBake at t=0.24, stuck in Approaching for 90 s).
- Runs (`./CkAuto/UnrealToolbox.exe ...`, test-only path beside the live editor, focused, not the full gate):
  - after the two briefed edits: `--test --discover-fresh --test-pattern Mars_AutoTest_Bat_ --output=Saved/Logs/Test-Bat-6b1.log`
    -> **EXIT 0**, 6/6/0, Contaminated 0; `--test --test-pattern Monster --output=Saved/Logs/Test-Monster-6b1.log` -> **EXIT 0**, 3/3.
  - after the perch/refusal fixes: `--test --test-pattern Mars_AutoTest_Bat_ --output=Saved/Logs/Test-Bat-6b1-b.log` -> **EXIT 0**, 6/6.
  - after the last kernel edit (Reached stamped, 23:54 UTC): `--test --test-pattern Mars_AutoTest_Bat_
    --output=Saved/Logs/Test-Bat-6b1-c.log` -> **EXIT 0**, 6/6/0, Contaminated 0; `--test --test-pattern Monster
    --output=Saved/Logs/Test-Monster-6b1-b.log` -> **EXIT 0**, 3/3/0 (same names as the baseline). No `Script/` file changed
    after these two runs. **confirmed**
  - No new test covers the three PIE-found bugs. The rig hands the perch over through the spec and the volume is baked
    before the bat wakes, so the headless lanes never hit them. Follow-up: a rig variant with DiscoverRadius and a late bake.

### Stand-in visuals + review hooks (Script, compiled clean in the live editor 23:32 UTC)  **confirmed compile only**
- `UMars_CellarBat_EntityScript`: new `LoopClip` (`TSoftObjectPtr<UAnimSequence>`, played with `PlayAnimation(clip, true)`
  when `AnimClass` is unset/unloadable), `LogPhases` (one `[CellarBat]` log line per phase change, route outcome, swoop
  landed/cancelled, with the script's own clock and the bat location), `Get_Bat()`. Final asset paths stay the defaults.
- `UMars_CellarBatReview_Bat_EntityScript` (`Mars_SandboxBat.as`): Mesh = `/Game/ArtCandidates/CellarBat/R01/Validation/
  CellarBat_R01_Blockout_Mars_SK`, AnimClass cleared, LoopClip = `CellarBat_R01_Blockout_Flap_Mars_ANIM`, LogPhases on;
  `Review_Kill()` (100000 Blunt on the body health, the death test's request) and `Review_Describe()` for editor Python.
- `UMars_CellarBatReview_TargetDummy_EntityScript` is now a standalone entity script (no longer a subclass of
  `UMars_TargetDummy_EntityScript`): same post size, team Two, `TAG_MarsCombatTarget`, Health (MaxHealth 100000), Body zone and
  hurtbox, but the post draws with **NoCollision**. Reason (confirmed in PIE run 5 by `Review_IsPointFree`):
  the base dummy's BlockAll post reaches the Jolt static world and the voxel bake carves it plus 40 cm clearance out of the
  volume: (600,0,80/140/170) were not free and (600,0,200) was. Swoop admission then answered `GoalBlocked` for every aim
  point on the dummy and the bat hovered at its strike point. Hooks: `Review_DamagedCount()`, `Review_Retire()` (drops it
  5000 under the floor, out of the bat's senses), `[CellarBat] dummy damaged #N` log line.
- Review bat hooks: `Review_Kill()`, `Review_Describe()` (phase, location, swoop ledger, route, claim, admission and aim
  freedom), `Review_IsPointFree(FVector)`.
- Review map additions: `CellarBatReview_CameraClose` (250,-450,330) and an unbound PostProcessVolume `CellarBatReview_Exposure`
  (auto-exposure bias -2.5; the amber key blew the first captures out). The lights keep the pale_crawler values. 21 tagged
  actors now (readback json rewritten).

### Review map (built and saved through run_python)  **confirmed**
- `Tools/LevelDesign/cellar_bat_r01_review/cellar_bat_review_ue.py`: fixed `phys_material_override` (now
  `set_phys_material_override`), added `_place_cameras` (CameraActor `CellarBatReview_Camera` at (950,-950,560) yaw 137.9
  pitch -14, FOV 90), `readback(path)`, PIE helpers `probe()` / `kill()` (iterate the PIE instances of the review script
  classes and `call_method`).
- `/Game/ArtCandidates/CellarBat/R01/Review/CellarBat_R01_Review_MAP` exists on disk (`Content/.../Review/
  CellarBat_R01_Review_MAP.umap`), 19 tagged actors: Floor, Ceiling, 4 walls, PerchBeam (-600,0,540), PerchPost, Pillar
  (0,0,300, 120x120x600), entity spawners Roost (-600,0,530), FlightVolume (0,0,300), Bat (-600,0,450), TargetDummy
  (600,0,0, yaw 180), PlayerStart, NeutralSun, NeutralSky, AmberLight, TealLight, Camera. Readback:
  `Tools/LevelDesign/cellar_bat_r01_review/review_map_readback.json`. Dirty packages after save: none. Sandbox restored
  after the first build (`restore_level` -> loaded True).
- Side effect (not authored by this task, flag for audit): saving the map ran the CkJolt OnSave cook hook, which wrote
  `/Game/CkJoltData/ArtCandidates/CellarBat/R01/Review/CellarBat_R01_Review_MAP/{JoltCell_0_0, JoltCell_0_-1,
  JoltCell_-1_0, JoltIndex}` (.uasset + .ckexport), outside `/Game/ArtCandidates/CellarBat/R01/`. Left in place (it is the
  map's static-world cook, the same thing the Sandbox map carries). Delete the folder if unwanted.
- Editor-world note: placing the FlightVolume spawner composed its entity in the editor world, and its bake timer raised
  `CkEnsure ... VoxelNav Volume could not resolve a Jolt query session in world [CellarBat_R01_Review_MAP]. Refusing to
  bake` (23:33:34 UTC, PIE-ID -2). Editor preview only (no Jolt session outside PIE); harmless but noisy. Follow-up: skip the
  bake timer when the world is not a game world.

### PIE runs (all through Monolith; map opened by run_python; PIE stopped after each; Sandbox restored at the end)

Route: `editor_query capture_pie_movement_clip` / `run_pie_smoke` with `probe_scripts` calling `cellar_bat_review_ue.probe()`
/ `kill()` / `retire_dummy()` / `free_grid()`. Timeline = `[CellarBat]` log lines (script clock `t`, from the first tick)
in `Saved/Logs/Mars.log` after each `CELLARBAT_PIE<N> begin` marker. **confirmed** for every line below.

- **Run 1 (CELLARBAT_PIE1, capture) - editor stopped in the VS debugger.** The clip's first ReadPixels hit the engine ensure
  `InRHITexture` (`D3D12RHI/Private/D3D12RenderTarget.cpp:617`) at 23:34:57 UTC. The editor runs under Visual Studio (devenv
  pid 9944 is the parent of MarsEditor pid 26028), so the ensure broke into the debugger: every thread suspended, 0 CPU. I did
  not kill the editor. The maintainer pressed Continue at 23:39:18 and the session ended after one PIE tick. The ensure did not
  fire again in capture runs 6-11 (it fires once per callsite). Not Bat code.
- **Run 2 (no capture)**: Roosting -> Hovering t=0.06 (perch bug), Hovering -> Approaching 0.22, route 1 NoBake 0.24, then stuck
  in Approaching for 90 s (refusal bug). The bake completed at ~0.9 s (`VoxelNav bake complete in [30] slices / 0.51 s, 2048
  leaves (900 occluded)`). The Jolt static world swept `[9] static bodies` (floor, ceiling, 4 walls, beam, post, pillar), so
  **the bake needed no map fix**.
- **Run 3** (after the perch/refusal fixes): Launch NoBake at t=0.85 -> Roost -> Alert -> Launch reached at 2.05 -> Approach,
  reached its strike point (391,59,240) at 5.2, then held: admission `GoalBlocked` (run 4 readout: aim (600,0,80) not free).
- **Run 5**: `free_grid` proved the dummy post is carved out of the volume (above). Fixed by the standalone review dummy, then
  rebuilt the map.
- **Run 6 (capture `captures/pie2_flight/`, 177 frames, overview camera, 90 s)**: 23 telegraphs, 23 swoops, 23 `landed`, 23
  dummy OnDamaged (12 each), 0 cancels: **exactly one hit per swoop**. The bat keeps cycling Approach/Telegraph/Swoop/Recover
  while the dummy stays a target. That is the design: it returns only on NoTarget.
- **Run 7 (capture `captures/pie3_cycle/`, 118 frames, exposure bias -2.5, 60 s)**: the full cycle. The dummy was retired at
  14.5 s:

  | t (s) | phase / event | bat location |
  |---:|---|---|
  | 0.23 | Roosting -> Alert | (-600,0,450) |
  | 0.86 | Alert -> Launching; route 1 **NoBake** (bake not done) -> Roosting 0.89 | (-600,0,450) |
  | 0.94 / 1.71 | Roosting -> Alert -> Launching | (-600,0,450) |
  | 2.21 | route 2 Reached; Launching -> Approaching 2.23 | (-600,0,314) |
  | 4.95 | Approaching -> Telegraphing (flew round the pillar) | (333,78,246) |
  | 5.55 | Telegraphing -> Swooping | (333,78,246) |
  | 6.26 | Swooping -> Recovering, **swoop 1 missed** (no landed, no damage) | (507,27,138) |
  | 7.08 / 8.58 / 9.30 | Approaching -> Telegraphing -> Swooping | (346,74,238) / (388,62,240) |
  | 9.83 | **swoop 2 landed**, dummy damaged #1 | (544,16,122) |
  | 10.02 / 10.86 | Recovering -> Approaching | (624,-7,62) / (597,253,66) |
  | 12.39 / 12.99 | Telegraphing -> Swooping | (598,218,242) |
  | 13.48 | **swoop 3 landed**, dummy damaged #2 | (599,81,140) |
  | 13.70 | Swooping -> Recovering | (600,13,89) |
  | 14.50 | dummy retired | - |
  | 14.53 / 14.54 | Recovering -> Approaching; route 13 EndpointUnresolvable (the target was gone) | (598,244,262) |
  | 14.58 | Approaching -> Returning | (598,247,264) |
  | 18.03 | Returning -> Braking | (-592,12,313) |
  | 19.06 | Braking -> Perching | (-603,-4,425) |
  | 19.69 | Perching -> Roosting | (-603,-4,425) |
  | 25.7 - 40.6 | Roost idle 6 s -> Alert -> Launch -> Patrolling the 4 nodes -> Returning -> Braking -> Perching -> Roosting | nodes reached within ~25 cm |

  Hits: 3 swoops, 2 landed, 2 OnDamaged. At most one hit per swoop, and none while telegraphing or recovering.
- **Run 8 (capture `captures/pie4_death/`, 0.25 s frames)**: `Review_Kill` (100000 Blunt) at t=3.5 while Approaching at
  (-545,19,241). Approaching -> **Falling** at 3.57 (-528,25,240) -> **Landed** at 4.04 (-179,145,32), resting at
  (-139,159,10). Dead, claim Released, target none. The dummy's OnDamaged count stayed 0, so nothing was dealt after death.
  The corpse despawned before t=10 (probe `invalid`).
- **Run 9 (pillar stretched into a full wall across X=0, `captures/pie5_blocked_before_reached_stamp/`)**: the first Approach
  got route 3 **Unreachable** -> Returning -> Braking -> Perching -> Roosting. The second Approach exposed the stale-Reached
  bug: the bat ended at (-600,0,-1297), under the floor. Fixed by stamping Reached.
- **Run 10 (same wall, after the fix, `captures/pie6_blocked/`, 40 s)**: all 12 Approach routes (3, 7, ... 47) answered
  **Unreachable** within 0.02-0.16 s, each followed by Returning -> Braking -> Perching -> Roosting at the perch. The bat
  never left the perch side and never went under the floor. Finding (inferred, not fixed): it wakes again and retries the
  unreachable target every ~3.3 s. An Approach failure ignores the target only for `HoverRetrySeconds`, and the roost wakes on
  any target. Whether unreachable targets need a longer memory is the maintainer's call.
- **Run 11 (capture `captures/pie7_swoop_close/`, 105 frames, CameraClose)**: 2 swoops, both landed, 2 OnDamaged. Frames show the
  blockout descending onto the post. At a 0.1 s capture interval the editor ran at ~6 fps, so the frame-sliced bake was
  slow: the first three launches got NoBake and recovered through Roosting before the fourth flew.
- After the wall test the map was rebuilt clean (`build_review_scene`, saved; pillar scale back to 1.2,1.2,6). At the end, PIE
  is off, the Sandbox map is open and no packages are dirty (run_python readback). **confirmed**

### Captures (PNG, `Tools/LevelDesign/cellar_bat_r01_review/captures/`)
`pie1_flight/` (2 frames, the debugger-break run), `pie2_flight/` (177), `pie3_cycle/` (118), `pie4_death/`,
`pie5_blocked_before_reached_stamp/`, `pie6_blocked/`, `pie7_swoop_close/` (105). `pie2_flight` is blown out by the amber key
(8000 cd over the dummy); from `pie3_cycle` on, the -2.5 exposure-bias PPV is in place. At the overview distance the 75 cm
blockout is a few pixels across, so the flight path, the swoop descent and the wing shadow read, but **the flap loop is not
visually verified**. It is only inferred to play: `PlayAnimation` is called when `AnimClass` is cleared, and nothing samples it.

### Not verified / open
- Whether the flap clip actually animates on the blockout (no close-up frame of the bat, no anim sampling).
- First-swoop shortfall: in run 7 (and in the Phase 6a lane) the first swoop, committed from a strike point ~270 cm from the
  aim point, ran out of `SwoopSeconds` before it reached the hurtbox. Later swoops start closer and land. This is a tuning
  call: SwoopSeconds / SwoopSpeed / Standoff.
- Swoop admission requires a free aim point, so a target whose own collision is in the Jolt static world can never be swooped.
  That is fine for pawns (excluded by the bake filter) but a hidden coupling for static props.
- Editor-world noise: on build, the FlightVolume spawner's editor preview raises the ensure `could not resolve a Jolt query
  session`.
- Multiplayer is still not addressed.

## Audit of Phase 6b-1 (Fable, 2026-11-05 19:05)

- `Saved/Logs/Test-Bat-6b1-c.log` 6/6, `Test-Monster-6b1-b.log` 3/3, contaminated 0 **confirmed**. Review map on disk
  at `Content/ArtCandidates/CellarBat/R01/Review/CellarBat_R01_Review_MAP.umap` **confirmed**; its save-hook Jolt cook
  wrote `Content/CkJoltData/ArtCandidates/CellarBat/R01/Review/` (derived data outside the owned root; retire it with the
  map). Pre-existing dirty files (`Mars_SandboxMapBuilder.as`, `Mars_PlayerCharacter.as`, Items, Cookbook/FPHands tests)
  have mtimes of 2026-11-03: untouched by this task **confirmed**.
- Functional runtime accepted on LOG evidence (phase timeline with locations, 23/23 swoops landed = 23 OnDamaged, death
  fall + despawn, 12 explicit Unreachable outcomes on the walled route). The PIE captures are NOT accepted as visual
  proof: the bat is a few pixels in the room-wide frames (`pie3_cycle/frame_030.png`) and absent from the sampled
  `pie7_swoop_close` and `pie4_death` frames. Phase 6b-2 must capture with a camera that tracks the bat.
- Noted limitations (not blockers): first swoop can run out short of the hurtbox (tuning); a target whose own
  collision is in the Jolt static world is never swoopable (the aim point must be free); the bat wakes before the first
  bake (recovers via Roost); retry of an unreachable target every HoverRetrySeconds.
- Four kernel fixes found only in PIE (Reached mis-attribution across route generations, pending-claim perch, immediate
  route refusal while Approaching, depleted-health sweep gate) are not covered by headless tests; a test for the route
  generation stamp is owed in 6b-2.

## Phase 6b-2 prep - AnimBP route, bat-tracking captures, route-stamp test (2026-11-05, DONE - awaiting audit)

Brief: `PHASE_6B2_PREP_BRIEF.md`. Executor: Opus. No git state changed; nothing committed.

### AnimBP builder  **confirmed** (run output + readback json)
- `Tools/LevelDesign/cellar_bat_r01_review/cellar_bat_animbp_ue.py` + `cellar_bat_animbp_manifest_prep.json` (every clip =
  the blockout flap, blockout skeleton). **Deviation:** Monolith actions have no in-editor Python binding, and an HTTP call
  from the editor's own Python to Monolith would block the game thread. So the builder is an OUTSIDE-editor Monolith
  JSON-RPC client (`python cellar_bat_animbp_ue.py --manifest <json> [--no-save] [--readback-only]`). It sends
  `editor_query run_python` for the editor-only steps. The docstring lists the calls that worked and the dead ends.
- Build run 19:26-19:40: CELLAR_BAT_ABP_OK, EXIT 0, 366 calls, 0 failed. It saved only `Animation/CellarBat_R01_Mars_ABP`,
  `Animation/CellarBat_R01_Locomotion_Mars_BS1D` and `Animation/Additive/CellarBat_R01_Bank{Left,Right}_Add_Mars_ANIM`.
  Dirty packages after the save: none. Readback regenerated after the restart (`--readback-only`, EXIT 0, no compile):
  `Tools/LevelDesign/cellar_bat_r01_review/cellar_bat_animbp_manifest_prep_readback.json`.
- Structure: parent `Mars_CellarBat_AnimInstance`, skeleton = blockout SKEL. AnimGraph: SM `Bat` -> Output Pose. 14 states,
  entry RoostIdle. 156 transitions, a full mesh over the 13 phase-driven states, rule `PhaseValue == <T's phases>`.
  Crossfade by destination, verified 156/156 from get_transitions: RoostIdle 0.35; Perch 0.3; RoostAlert and Locomotion 0.25;
  Launch, Recover and Brake 0.2; Telegraph, Stun and DeathLand 0.15; Swoop and DeathFall 0.1; Hit 0.08.
- Locomotion: BS1D (Speed 0..900; samples Hover 0, FlyForward 380, Glide 620) with X bound to Speed -> ApplyAdditive
  (BankRight, Alpha bound to BankRightAlpha) -> ApplyAdditive(BankLeft, Alpha bound to BankLeftAlpha) -> state result.
  The additive copies are LocalSpace, ref AnimFrame 0. Every other state plays its clip (looped in prep). Screech has no
  kernel phase, so no transition enters it. list_errored_blueprints: [].
- Dead ends: a conduit hub (add_conduit works; add_transition then answers "State 'Router' not found"); rules on the int
  `PhaseIndex` (set_transition_rule accepts only floats inherited from the parent, hence the new `PhaseValue`); Python
  `AnimStateTransitionNode` state getters (not exposed, so nodes are matched by creation order and verified by from/to).
- Rebuild policy (changed after the incidents below): the builder never clears in place and never deletes. If the manifest's
  .uasset exists on disk it builds `<name>_v<N>` and reports which. The clean path is to delete the stale file with the
  editor closed (or with delete_asset before anything has loaded it), then run again.
- Known flaw in the current asset: two earlier in-place rebuilds left the removed state machines' sub-graphs in the saved
  package (5 SM node names, 313 transition nodes for 156 live ones, 4.3 MB). It compiles and runs. Replace it by the clean
  path when convenient.

### Script edits  **confirmed compile** (live editor reloads, 0 AS errors)
- `Mars_CellarBat_AnimInstance.as`: + `BankRightAlpha` / `BankLeftAlpha` (max(+/-BankAlpha, 0)), + `PhaseValue` (float PhaseIndex).
- `Mars_CellarBat_EntityScript.as`: BankAlpha = clamp(SignedTurnRate / MaxTurnRate, -1, 1), then FInterpTo at
  `BankSmoothRate` 6. Before, it was clamped only, with no smoothing. SwoopAlpha comes from the ledger (Get_SwoopFrame:
  StageElapsed / stage seconds), unchanged.
- `Mars_SandboxBat.as`: the review preset's AnimClass = `CandidateAnimClassPath` (the ABP_C); LoopClip stays as the
  fallback; + `Review_Location()`.
- New `Script/Tests/Bat/Mars_AutoTest_Bat_StaleRouteAnswerIsIgnored.as`.

### Tests (focused, toolbox test-only beside the live editor; not the full gate)
- `./CkAuto/UnrealToolbox.exe --test --discover-fresh --test-pattern Mars_AutoTest_Bat_ --output=Saved/Logs/Test-Bat-6b2.log`
  -> **EXIT 0**, Total 7 / Passed 7 / Failed 0 / Contaminated 0. Lane log for the new test: stale gen 0 against route 1 left
  the route Pending with 0 outcomes; the current-gen Unreachable was taken once (generation 1).
- `--test --test-pattern Monster --output=Saved/Logs/Test-Monster-6b2.log` -> **EXIT 0**, 3/3, same names as the baseline.
- Both ran after every kernel/test .as edit. After them, `Mars_SandboxBat.as` was edited twice more (AnimClass cleared,
  then restored; net change = the restore to the ABP). That is a review preset no test spawns. **Inferred** harmless; not re-run.

### Bat-tracking captures (ABP live; frames LOOKED at)  **confirmed**
Chase camera: `cellar_bat_review_ue.chase_start(offset, fov, follow_rate, lead)` is a Slate post-tick callback. It moves the
PIE copy of `CellarBatReview_CameraClose` to bat + offset, leads the aim by `lead` x the last tick's motion, and keeps that
camera as the view target. It logs CELLARBAT_CHASE every 0.5 s and stops when PIE ends. In PIE, `sample_pie_anim_instance`
on actor `Ck_UnrealComponent_Host` read AnimationMode = AnimationBlueprint and class `CellarBat_R01_Mars_ABP_C`; Phase 4
gave active state `Locomotion`, Phase 8 gave `Locomotion`. `wrist_l` rotation changed between samples.
- `Tools/LevelDesign/cellar_bat_r01_review/captures/pie8_tracked_cycle/` (105 frames, 0.25 s, offset (0,-190,60), FOV 60).
  Log: Alert t=1.10, Launch, Approach, swoop 1 landed t=6.19, swoop 2 landed t=9.77 (2 OnDamaged), dummy retired,
  EndpointUnresolvable -> Return, Brake, Perch, Roost t=17.79, relaunch -> Patrol. **Wing motion:** frame_012 (right wing
  raised) vs frame_013 (both wings swept down). **Swoop:** frame_022 (the dive low over the floor) and frame_023 (at the dummy
  post 0.18 s after "swoop 1 landed"). **Perch/roost:** frame_067 (Perching) and frame_075 (Roosting), inverted at the perch
  with the wings in different positions. Here the bat is ~11% of the frame width and ~25% of its height.
- `captures/pie9_tracked_swoop/` (131 frames, 0.12 s, offset (-190,-90,70), FOV 45, lead 1.5). Swoop 1 landed at
  00:48:54.224 UTC. **Contact:** frame_078 shows the bat at the post's side, wing spread, 3 ms before the logged hit.
  frame_076 is the dive just before it (wings up, legs out, post ahead). In frame_079 the camera runs into the post.
  Kept for comparison: `pie9_tracked_swoop_attempt1_nolead/` (camera lagged the swoop; the bat left the frame at contact) and
  `pie9_tracked_swoop_attempt2_side/` (frame_045 is a sharp large dive, ~25% of the width; at contact the post occludes it).
- `captures/pie10_tracked_death/` (66 frames, 0.15 s). Review_Kill at 00:49:22.46 while Approaching -> Falling, then Landed
  0.81 s later at (391,342,97), resting at (561,400,10), dead = true. **Fall:** frame_020 (mid-air after the kill).
  **Down:** frame_026. **Corpse:** frame_052, on the floor, wings still moving: the prep ABP loops the flap in DeathLand, so
  there is no corpse pose until the final clip.
- The `InRHITexture` ensure fired once at PIE8's first viewport read. The new editor did not break into VS and carried on.
- At the end: PIE off, chase callback unregistered, Sandbox map restored, 0 dirty packages (run_python + list_dirty_packages).

### Audit of Phase 6b-2 prep (Fable, 2026-11-05 20:00)

- Frames inspected: `Tools/LevelDesign/cellar_bat_r01_review/captures/pie8_tracked_cycle/frame_012.png` (wings up) and
  `frame_013.png` (wings swept down) prove wing motion in PIE; `pie9_tracked_swoop/frame_078.png` shows the bat at the
  dummy post at contact; `pie8_tracked_cycle/frame_075.png` shows it back at the roost. The blockout renders in the
  default material (teal-lit) because the validation import bound no materials - expected for the stand-in.
  **confirmed by looking**. Tests: Bat 7/7 (`Test-Bat-6b2.log`), Monster 3/3 (`Test-Monster-6b2.log`) per the report;
  not re-read by me.
- AnimBP builder deviation accepted: it runs as an outside-editor Monolith client (`python cellar_bat_animbp_ue.py
  --manifest ...`) because Monolith's graph actions have no in-editor binding. 14 states, 156 phase-driven transitions
  with per-destination crossfades, 1D locomotion blend on Speed, additive banks on `BankLeftAlpha`/`BankRightAlpha`.
- Carried into Phase 6b-2 final: BankAlpha stayed 0 in every PIE sample (diagnose: does the flying agent's
  FaceAngle3D yaw the root transform, and does the telemetry read it before smoothing?); per-state poses unjudged
  (every state played the one flap clip); the saved ABP carries orphaned sub-graphs (313 transition nodes for 156
  live) from in-place rebuilds - the final ABP is built fresh on the final skeleton under a name that does not exist on
  disk, never by deleting a loaded Blueprint; the Screech state has no kernel phase (add a `Screeching` presentation
  phase or drive it from the Alert/Telegraph phases); death-fall sideways travel ~900 cm in 0.81 s is suspicious (fall
  velocity seeded from telemetry during a capture hitch) - clamp the seed speed.
- Editor incidents I-1 (ObjectTools ensure on force-delete of a loaded ABP) and I-2 (PIE pre-play compile of the broken
  dirty ABP killed the editor, no crash report) are recorded by the executor in the Phase 6b-2 prep section; the rule
  "never delete, force-delete or reload a Blueprint the live editor has loaded; PIE compiles every dirty Blueprint" is
  now part of this task's operating rules.

## Phase 7 - attack-pattern fix and audit (Fable, 2026-11-05 21:45)

Maintainer observation: after the first swoop the bat telegraphed facing away from the dummy. Cause (read in the code):
Recover flew back to the commit point, so the pull-out travelled away from the target and the crowd agent faced its
travel; the next strike point was almost where the bat already was, and nothing turned the root while it telegraphed
(CkCrowd's facing writer disengages below its speed floor). Changes, all in `Script/ECS/Bat/` + the rig/test:
- `FaceAimPoint` in the tick: while Telegraphing the kernel slews the root yaw (and a pitch clamped to -50..+20) toward
  the aim point at `Flight.MaxTurnRate`; safe because the agent is stopped and its facing writer holds.
- Recover carries THROUGH: the mirror of the strike point past the aim point along the dive line (fallback: back to the
  commit point when that point is not free in the volume).
- Orbit between swoops (control layer, `UMars_SmTask_Bat_Approach`): while the admission is Cooldown or NoLineOfSight
  the bat chases a point 45 deg ahead on the standoff circle (direction alternates per sortie), so it circles the
  target instead of hovering and each telegraph comes from a new bearing.
- Target lead: the targeting processor samples the held target's velocity each sense; Commit aims half a swoop ahead
  (lead capped at Standoff).
- Line of sight: `Get_SwoopAdmission` refuses `NoLineOfSight` when a Jolt static ray from the mouth to the aim point
  hits (no diving into a pillar); the orbit keeps moving until the line clears.
- New test `Mars_AutoTest_Bat_TelegraphFacesTheTargetAndCarriesThrough` (facing within 15 deg at commit; first
  recovery ends past the target). Gates: `Saved/Logs/Test-Bat-audit.log` 8/8, `Test-Monster-audit.log` 3/3,
  contaminated 0 **confirmed**.
- PIE (`run_pie_smoke` marker CELLARBAT_AUDIT, 45 s, review map): 6/6 swoops landed = 6 dummy hits in 26 s; every
  recovery ended ~200 cm past the dummy (x ~790 vs 600); telegraph points alternated sides (y -82, +48, -77, +52);
  facing error at the end of all 11 telegraphs 0.0-0.1 deg (first sample of each up to 94 deg before the slew)
  **confirmed from the [CellarBat] log lines**. Not captured visually this time.
- Not done (audit items for a later pass): last-known-position search when the target leaves LoseRadius; hit-and-run
  retreat after taking damage; altitude bob / path smoothing (CkCrowd passes default refinement to the voxel search
  with smoothing off and exposes no knob - a framework change); jink/wobble presentation; GOAP is not needed for one
  attack and one home.

## Phase 8 - search, hit-and-run, altitude bob (Fable, 2026-11-05 23:15)

The three audit items left open by Phase 7, on the maintainer's go-ahead. All in `Script/ECS/Bat/` (kernel + HFSM), the
cellar bat assembly, the test rig and three new tests; the review preset and driver gained hooks for the PIE proof.
- **Last-known-position search.** Kernel: `Sensing.SearchSeconds` (TOptional, default 3 s); a hostile target lost by
  distance (past LoseRadius, still within HomeRadius, still hostile; not dead, not ignored) leaves `LastKnown` in the
  fragment (Targeting), cleared when a target is held again, by `Request_EndSearch` (the control layer's) or by the fall.
  Readers `Get_LastKnown/Get_HasLastKnown/Get_SearchAim/Get_SearchPoint/Get_OrbitPointAround/Get_OrbitGoal`. Control:
  new phase `Searching` and state `Search` (every flying state and Launch go `->Search [ShouldSearch]` before `->Return`;
  Roost wakes on a last-known place too): FlyTo Swoop.Height over the place, then circle it (`FMars_Fragment_Bat_
  SearchBlackboard.ArrivedClock`) for SearchSeconds, `->Approach [HasTarget]`, `->Return [SearchFailed | SearchDone]`
  (SearchDone also after SearchSeconds + 6 s unreached); exit sends EndSearch. `Get_HasLastKnown` reads false while an
  EndSearch is queued so Return is not bounced straight back.
- **Hit-and-run.** Kernel: `Timing.RetreatDistance` (TOptional, default 450) + `RetreatSeconds` 1.5; `Get_RetreatPoint`
  (RetreatDistance from the aim point along the ground away from the target, Height up; halved once when not free, then
  the strike point). Control: phase `Retreating`, state `Retreat`: `Hurt ->Retreat [NotHurt + HasTarget + distance set]`
  else `->Return`; `Retreat ->Approach [RetreatDone: reached | failed | RetreatSeconds]`, `->Search`, `->Return [NoTarget]`.
- **Orbit goal fallback** (`Get_OrbitGoal`): an orbit point the volume does not have free (a target against a wall, the
  search in a corner) falls back to the other way round, then to the strike/search point. Found by the first PIE smoke of
  this phase: the search reached the corner and ended on `route 46 EndpointUnresolvable` (the orbit point in the wall)
  instead of circling; the same path would have DROPPED a target standing against a wall while Approaching (the Phase 7
  orbit had no check).
- **Altitude bob** (assembly only, the look node): 4 cm at 1.9 Hz (near the Hover clip's beat) + 8 cm at 0.37 Hz along
  world up while Patrolling/Approaching/Returning/Hovering/Searching/Retreating/Recovering, faded at 3/s; none while
  hanging, braking, telegraphing, diving, falling or down. Not judged visually (no capture this phase).
- **AnimBP:** the two new phases come after Screeching in the enum (earlier PhaseIndex values unchanged) and
  `utils_bat::Get_AnimPhase` folds Searching -> Patrolling and Retreating -> Returning for `PhaseIndex/PhaseValue`, so
  the saved ABP (built with the phases up to Screeching) draws them as locomotion with no rebuild. `Phase` itself stays
  the kernel's.
- **Tests** (`Script/Tests/Bat/`): `SearchesTheLastKnownPlaceThenGivesUp` (lose/acquire 900; target hops to
  (-700, 700) after the first landing, is destroyed once Searching; asserts Swooping -> Searching -> Returning -> Roosting,
  closest approach within Standoff + tolerance of the search point, memory forgotten), `SearchFindsTheTargetAgain` (same
  hop, target stays; a second swoop lands via Searching -> Approaching), `RetreatsAfterABlowThenAttacksAgain` (5 damage
  through the body zone while Telegraphing; Interrupted, Telegraphing -> Hit -> Retreating -> Approaching -> Swooping,
  further from the target at the retreat's end by > 100, then one landing). Rig: `HitBat`, `Get_DistanceToTarget`,
  `_FirstRetreatEnd`.
- **Gates (test-only path, quiescence kept):** `Test-Bat-audit2.log` 11/11 (before the orbit fallback),
  `Test-Bat-audit3.log` 11/11 and `Test-Monster-audit3.log` 3/3 after it, contaminated 0, exit 0 each **confirmed**.
  The headless run added `Mars.SmState.Bat.Retreat` / `.Search` to `Config/DefaultGameplayTags.ini` and the live editor
  regenerated `Script/Generated/Mars_AutoTestActors.as` with the three runners (both committed with the change).
- **PIE** (`run_pie_smoke` on the review map, 62 s each, chase camera on, probes through `cellar_bat_review_ue`;
  `[CellarBat]` timeline from `Saved/Logs/Mars.log`, script clock t about 1 s behind the session clock) **confirmed**:
  - CELLARBAT_AUDIT2: `damage(5)` at 9 s in Approaching -> Hit t=8.17 -> Retreating 8.54 at (506,-168) -> Approaching
    9.36 at (391,-376) (254 -> 459 cm from the dummy) -> Telegraph -> swoop 2 landed 11.58. Dummy to the corner at 21 s
    -> Searching 20.27 -> reached (-836,-707) 24.9 -> `route 46 EndpointUnresolvable` -> Returning (the wall bug above).
  - CELLARBAT_AUDIT3 (fallback in): retreat again (276 -> 460 cm); the corner dummy was re-sensed 0.2 s into the
    search (AcquireRadius 1600 reaches the corner) -> Searching -> Approaching, i.e. the find-again branch; the retire
    0.8 s later made the approach route fail -> Return -> Roost; dummy back at 42 s -> re-aggro, swoops 5-9 landed.
  - CELLARBAT_AUDIT4 (`move_then_retire_dummy`, retire 0.45 s after the hop): retreat (Hit 8.18 -> Retreating 8.55 at
    (469,-139) -> Approaching 9.35 at (303,-315)); Searching 20.36 at (595,199) -> in the corner at (-870,-721) by
    the 27 s probe, circling -> Returning 27.52 at (-905,-814) with no route failure -> Braking 30.05 -> Perching 30.98
    -> Roosting 31.60; dummy back at 44 s -> Patrolling -> Approaching 43.22 -> swoops 5-9 landed. 9/9 swoops landed
    across the run.
  Review hooks added for this: `Review_MoveTo`, `Review_MoveThenRetire` on the review dummy (`Mars_SandboxBat.as`), the
  preset's LoseRadius 1900 -> 1600 (= AcquireRadius, so a hop to the far corner is a loss inside the room), driver
  `move_dummy` / `move_then_retire_dummy`. The smokes reported ok, 0 must-absent hits; the review map was restored to
  the Sandbox map afterwards.
- **Not done / open:** the bob was not looked at (presentation only; tune `BobAmplitudeCm`/`DriftAmplitudeCm` in
  `Mars_CellarBat_EntityScript.as`); path smoothing still needs a CkCrowd knob; the review map holds two dummy entity
  scripts (`dummies=2` in every probe; the second reports 0 hits) - a leftover of a rebuild, harmless, clean up with the
  next `build_review_scene`.

## Phase 9 - the review room runs itself (Fable, 2026-11-05 23:55)

Asked whether the review map showcased everything: by hand it showed only the swoop cycle, the orbit and the return; the
retreat, the search, the lead and the line-of-sight refusal needed the Python probes. Now it stages them itself, as class
defaults on the review scripts (no map rebuild, no editor map operation):
- `UMars_CellarBatReview_TargetDummy_EntityScript` walks a loop (`FMars_CellarBatReview_Walk`, default route from the post
  at (600, 0): south to (600, -600), west to the pit at (0, -700) and 8 s 1200 cm under the floor, up to the cover spot
  (160, 0) behind the pillar for 5 s, out to (600, 500), back; 160 cm/s, about 50 s a lap) and draws a dark plate at every
  pit node. `Review_MoveTo` / `Review_MoveThenRetire` stay.
- `UMars_CellarBatReview_Bat_EntityScript` swats back: every 3rd landed swoop, 0.5 s later (the pull-out), 5 damage through
  its own body zone (`CounterBlowEveryNthLanding`, `CounterBlowDamage`). Preset radii 1300/1300 (acquire just over the
  roost-to-post distance; lose equal so the pit is a loss inside the room).

The walking target exposed four kernel faults, all fixed here (`Script/ECS/Bat/`):
- **The remembered place must be flyable.** The voxel volume answers free for space it never rasterized inside its
  power-of-two cube (probed in PIE: (0, -700, -960) under the floor free, (1100, 0, 300) past the east wall free,
  (1300, 0, 300) outside the cube not free), so a target that dropped into the pit left a place under the floor. Now
  `Try_RememberLastKnown` (shared by the losing sense and the route-failure drop, which remembered nothing before) takes
  the target's location only when it is goal-free AND no static lies between the bat and it (a Jolt ray, game worlds
  only), else where the previous sense saw it (the rim), else nothing.
- **Goals need a body margin** (`Get_IsGoalFree`: free at the point and 2 x AgentRadius out along +-X/+-Y). A bare free
  point next to the pillar's or a wall's clearance band gets `Unreachable` from the path (probed: (0, 151, 240) and
  (-5, 145, 240) free, both Unreachable from 150 cm away - a CkVoxelNav limitation inside a partially occluded leaf,
  recorded, not fixed here). Used by the strike point, the orbit goal and the retreat point.
- **The strike point turns to the open side** when the natural one is not goal-free (45, -45, 90 ... 180 degrees round the
  target), so a target hugging the pillar is attacked instead of dropped.
- **A stranded bat climbs out.** After a retreat near the south wall the agent overshot into the wall's clearance band
  (578, -983) where no path can start, and sat Hovering for 25 s. `TickUnstick`: after a route failure or while Hovering,
  a bat whose own spot is not goal-free moves itself toward the nearest goal-free point (`Get_NearestGoalFree`, rings of
  AgentRadius) at half cruise. Test `ClimbsOutOfBlockedSpaceAndGetsHome` (set down at 15 cm over the floor, a route
  asked from there fails, it climbs clear and roosts).
- **The lead follows the dive's acceleration profile** (`Get_DiveSeconds`: from rest at MaxAcceleration toward
  SwoopSpeed over the distance to the aim less ContactRadius), not half a SwoopSeconds at full speed: landings on the
  walking post went from 3/9 to 6/11 and 8/17 across the runs. Still under half on a target walking at 160 cm/s: the
  misses are all mid-walk, the pauses are always hit. Left as the next tuning item (lead factor, ContactRadius, or a
  wider blow).
- Also: `Get_IsStaticBetween` now takes the bat and reads clear outside a game world (the review map's editor preview
  composed the bat and the walking dummy, and the losing sense fired a Jolt ray there: `Calling a function that requires
  WorldContext`, spammed every sense until gated).
- Tests: `SearchesTheRimWhenTheTargetDropsOutOfReach` (target teleported 1200 under the floor after the first landing;
  the remembered place is the rim) and `ClimbsOutOfBlockedSpaceWhileHovering` (a hovering bat set down 120 cm inside a
  400 cube comes out through the nearest face on its own). A route failure from inside blocked space could not be
  forced headless: the voxel planner snaps a start in the floor's band, and even one inside the solid cube, to a free
  neighbour (two failed test drafts), so the test exercises the Hovering trigger of the climb-out; the route-failure
  trigger is covered by the PIE stranding only. Route log lines now carry the goal.
- Gates (test-only, quiescence kept): `Test-Bat-showcase.log` 12/12 and `Test-Monster-showcase.log` 3/3 after the first
  three fixes; `Test-Bat-showcase2.log` 12/13 (the first strand draft) and `Test-Monster-showcase2.log` 3/3 after the
  margin, the ray gate and the unstick; `Test-Bat-showcase3.log` 12/13 (the second draft); `Test-Bat-showcase4.log`:
  SEE THE LINE BELOW.
- PIE (`run_pie_smoke`, 100 s, no probes but the chase camera and a state readout every 15 s) **confirmed** from the
  `[CellarBat]` lines:
  - CELLARBAT_SHOWCASE1 (before the fixes): pit -> route Unreachable to z -960 -> target dropped, no search; cover spot ->
    Unreachable strike points, target dropped, home and back twice; swat -> Hit -> Retreating -> second landing; 3/9 dives.
  - CELLARBAT_SHOWCASE2 (lead, strike bearing, remember-on-drop): the pit still remembered under the floor (the volume's
    free answer); retreat 31.3 s; after the second swat the bat overshot into the south wall's band at (578, -983) and
    hovered from 72 s to the end; 6/11 dives.
  - CELLARBAT_SHOWCASE3 (all fixes): pits at 7.6 / 40.5 / 72.4 s each -> Searching the rim for ~3 s -> Returning -> Perch
    -> Roost -> re-launch when the dummy climbed out; cover spot at 18-23 / 50-55 / 83-88 s -> dives from the open side
    landed (swoops 3, 9, 15 at (213, 44), (206, 49), (212, 50)); swats after landings 3 and 6 -> Hit -> Retreating ->
    Approaching; no stranding; 8/17 dives landed, every miss on the walking legs.
  - CELLARBAT_SHOWCASE4 (final code, with the carry-through margin and the wider climb-out rings): pits at 7.6 / 40.1 /
    73.5 s -> Searching ~3 s -> home; swats after landings 3 and 6 -> Retreating; no Hovering at all; one `Unreachable`
    to an orbit point at (124, -147, 240) beside the pillar (all four margin probes free there: the CkVoxelNav leaf
    limitation again) from which it recovered within a second; 6/17 dives landed.
- Open after this phase: landing rate on a walking target (35-47 %); the pillar-adjacent `Unreachable` from the voxel
  planner for goal-free points (report to CkPlugins with the probe numbers above); `Get_IsFlyable`'s ray is a proxy for
  "inside the volume" until the volume exposes its bounds.

## Phase 9b - dives on a walking target (Fable, 2026-11-06 00:25)

Measured before changing anything: the review bat logs one `[CellarBat] dive` line per committed swoop (`DiveDiagnostics`
on `UMars_CellarBatReview_Bat_EntityScript`): target speed, the lead used, the start distance, the mouth's closest
approach to the hurtbox centre (distance, time, height) and the miss split along the walk and across it.
- CELLARBAT_DIVE1 (before): 6/17 landed. Every miss had its closest approach on the LAST frame of the 0.7 s dive, the
  mouth 45-183 cm behind the target and 57-131 cm above it: the dive was too short, not mis-aimed. A dive at a standing
  target starts 225 cm out and lands at 0.6-0.68 s; at a walking one it started 290-410 cm out, because the target walks
  ~96 cm away during the 0.6 s telegraph while the bat holds still, and from rest at 1400 cm/s^2 a 0.7 s dive covers 343 cm.
- Changes (`Script/ECS/Bat/`): the strike point leads the aim by the target's velocity over TelegraphSeconds (capped at
  Standoff), so the bat waits where the target will be at commit; the committed dive ends when its route reaches the aim
  point (`Get_IsRouteReachedIn(Swooping)`), with `SwoopSeconds` now the cap (0.7 -> 1.2 s); `Swoop.LeadScale` (1.3)
  scales the lead, measured: the agent reaches the aim 1.14-1.4x later than the from-rest acceleration model.
- CELLARBAT_DIVE2 (lead + end on arrival): 12/16; closest approaches 36-65 cm, still 50-60 cm behind at 0.9 s on the
  300+ cm dives. CELLARBAT_DIVE3 (+ LeadScale 1.3): 11/16, but on straight walking legs 8/8 with closest approaches
  34-43 cm and the along error centred (-29..+25 cm); the misses were three dives whose target dropped into the pit
  mid-dive (closest 150 at the cap, or a dive admitted the frame before the drop) and two at the dummy's corner turns
  (across ~100 cm: the velocity estimate still points the old way). Standing-target dives unchanged (33-36 cm).
- Gates: `Test-Bat-dive.log` 13/13 + `Test-Monster-dive.log` 3/3 after the strike lead and the arrival end;
  `Test-Bat-dive2.log` 13/13 after LeadScale; exit 0 each **confirmed**.
- One `Dynamic Fragment Get rejected invalid input` from the editor-world preview bat the frame after the full reload that
  changed `FMars_Bat_Swoop`'s layout (one stack, did not repeat): a hot-reload transient, not runtime behaviour.
- Open: a corner-turning target (the lead could decay with the estimate's age, or sample the velocity faster); the
  SwoopAlpha the AnimBP reads still runs over SwoopSeconds (1.2) so the Swoop clip now plays slower than the dive.

## Incidents (this phase)
- **I-1 force delete (19:41 local).** Changing the rebuild to delete-and-recreate made `EditorAssetLibrary.delete_asset`
  refuse the loaded ABP: "in use", 156 native GCObjectReferencer references (one per transition node). `ForceDeleteObject`
  failed, and the ensure `ObjectTools.cpp:3963` "Failed to unload all packages during ForceDeleteObjects ... likely corrupt"
  fired. The editor kept running, but the in-memory ABP lost its generated class and stayed dirty. The disk copy (19:40) was
  untouched. Reported to main; no reload or delete was attempted afterwards.
- **I-2 editor death at PIE start (19:44 local).** My last Monolith call before it: `editor_query capture_pie_movement_clip`
  {marker CELLARBAT_PIE8, duration 30, capture_interval 0.25, view_target_actor CellarBatReview_CameraClose, output
  captures/pie8_tracked_cycle, probes 0.3 chase_start / 8 probe / 14.5 retire_dummy / 29 probe}, sent ~00:44:08 UTC with
  the review map open. The preset's AnimClass was cleared, but the dirty broken ABP was still in memory. Log tail
  (`Saved/Logs/Mars-backup-2026.11.06-00.44.23.log`): `LogBlueprint: Compiling Blueprint '.../CellarBat_R01_Mars_ABP'`,
  `[PlayLevel] Compiling CellarBat_R01_Mars_ABP before play...`, then 14 `LogOutputDevice: Warning: Script Stack (0 frames)`
  lines from 00:44:09 to 00:44:23 UTC, and the log ends. No new Saved/Crashes folder. A new MarsEditor started at 19:44:26
  (the maintainer relaunched it). The 19:40 disk ABP loaded clean in the new editor (generated class, 0 dirty, 0 errored BPs).
- **Lessons.** (1) PIE start compiles EVERY dirty Blueprint, used or not, so a broken dirty BP in memory takes PIE down even
  when nothing references it. (2) Never delete, force-delete or reload a Blueprint that the live session has loaded or
  edited; build under a new name instead (now the builder's policy). (3) An in-place graph clear through remove_node_slice
  leaves the removed sub-graphs in the saved package.

### Open
- BankAlpha read 0 in every PIE sample, including mid-turn. Telemetry SignedTurnRate comes from the root yaw, and the
  flying agent may not yaw the root while turning (**inferred**). Check the agent's facing before the bank layer can show anything.
- The Speed telemetry spikes under capture load (a sample read 2596 cm/s at cruise 380). The death fall inherits
  `Telemetry.Velocity`, so a hitch can throw the corpse far: PIE10 travelled ~900 cm horizontally in 0.81 s.
  **Inferred** link; a clamp on the fall's start velocity is a candidate.
- The bat fills ~25% of the frame height in PIE8 and ~25-50% of the width in PIE9; the chase camera clips into the post at contact.
- The ABP asset carries the orphaned sub-graphs (see above). A clean rebuild needs the editor closed or a fresh name.
- Every state loops the one flap clip, so per-state poses (hang, perch, corpse) are unverifiable until the 18 clips exist.
- Screech has no kernel phase; the first-swoop shortfall still happens (PIE9's third attempt missed its only swoop).

## Audit of Phase 6b-2 prep (Fable, 2026-11-05 20:00)

- Frames inspected: `Tools/LevelDesign/cellar_bat_r01_review/captures/pie8_tracked_cycle/frame_012.png` (wings up) and
  `frame_013.png` (wings swept down) prove wing motion in PIE; `pie9_tracked_swoop/frame_078.png` shows the bat at the
  dummy post at contact; `pie8_tracked_cycle/frame_075.png` shows it back at the roost. The blockout renders in the
  default material (teal-lit) because the validation import bound no materials - expected for the stand-in.
  **confirmed by looking**. Tests: Bat 7/7 (`Test-Bat-6b2.log`), Monster 3/3 (`Test-Monster-6b2.log`) per the report;
  not re-read by me.
- AnimBP builder deviation accepted: it runs as an outside-editor Monolith client (`python cellar_bat_animbp_ue.py
  --manifest ...`) because Monolith's graph actions have no in-editor binding. 14 states, 156 phase-driven transitions
  with per-destination crossfades, 1D locomotion blend on Speed, additive banks on `BankLeftAlpha`/`BankRightAlpha`.
- Carried into Phase 6b-2 final: BankAlpha stayed 0 in every PIE sample (diagnose: does the flying agent's
  FaceAngle3D yaw the root transform, and does the telemetry read it before smoothing?); per-state poses unjudged
  (every state played the one flap clip); the saved ABP carries orphaned sub-graphs (313 transition nodes for 156
  live) from in-place rebuilds - the final ABP is built fresh on the final skeleton under a name that does not exist on
  disk, never by deleting a loaded Blueprint; the Screech state has no kernel phase (add a `Screeching` presentation
  phase or drive it from the Alert/Telegraph phases); death-fall sideways travel ~900 cm in 0.81 s is suspicious (fall
  velocity seeded from telemetry during a capture hitch) - clamp the seed speed.
- Editor incidents I-1 (ObjectTools ensure on force-delete of a loaded ABP) and I-2 (PIE pre-play compile of the broken
  dirty ABP killed the editor, no crash report) are recorded by the executor in the Phase 6b-2 prep section; the rule
  "never delete, force-delete or reload a Blueprint the live editor has loaded; PIE compiles every dirty Blueprint" is
  now part of this task's operating rules.

## Phase 7 - attack-pattern fix and audit (Fable, 2026-11-05 21:45)

Maintainer observation: after the first swoop the bat telegraphed facing away from the dummy. Cause (read in the code):
Recover flew back to the commit point, so the pull-out travelled away from the target and the crowd agent faced its
travel; the next strike point was almost where the bat already was, and nothing turned the root while it telegraphed
(CkCrowd's facing writer disengages below its speed floor). Changes, all in `Script/ECS/Bat/` + the rig/test:
- `FaceAimPoint` in the tick: while Telegraphing the kernel slews the root yaw (and a pitch clamped to -50..+20) toward
  the aim point at `Flight.MaxTurnRate`; safe because the agent is stopped and its facing writer holds.
- Recover carries THROUGH: the mirror of the strike point past the aim point along the dive line (fallback: back to the
  commit point when that point is not free in the volume).
- Orbit between swoops (control layer, `UMars_SmTask_Bat_Approach`): while the admission is Cooldown or NoLineOfSight
  the bat chases a point 45 deg ahead on the standoff circle (direction alternates per sortie), so it circles the
  target instead of hovering and each telegraph comes from a new bearing.
- Target lead: the targeting processor samples the held target's velocity each sense; Commit aims half a swoop ahead
  (lead capped at Standoff).
- Line of sight: `Get_SwoopAdmission` refuses `NoLineOfSight` when a Jolt static ray from the mouth to the aim point
  hits (no diving into a pillar); the orbit keeps moving until the line clears.
- New test `Mars_AutoTest_Bat_TelegraphFacesTheTargetAndCarriesThrough` (facing within 15 deg at commit; first
  recovery ends past the target). Gates: `Saved/Logs/Test-Bat-audit.log` 8/8, `Test-Monster-audit.log` 3/3,
  contaminated 0 **confirmed**.
- PIE (`run_pie_smoke` marker CELLARBAT_AUDIT, 45 s, review map): 6/6 swoops landed = 6 dummy hits in 26 s; every
  recovery ended ~200 cm past the dummy (x ~790 vs 600); telegraph points alternated sides (y -82, +48, -77, +52);
  facing error at the end of all 11 telegraphs 0.0-0.1 deg (first sample of each up to 94 deg before the slew)
  **confirmed from the [CellarBat] log lines**. Not captured visually this time.
- Not done (audit items for a later pass): last-known-position search when the target leaves LoseRadius; hit-and-run
  retreat after taking damage; altitude bob / path smoothing (CkCrowd passes default refinement to the voxel search
  with smoothing off and exposes no knob - a framework change); jink/wobble presentation; GOAP is not needed for one
  attack and one home.

## Incidents

- 2026-11-05 18:10 local: the live MarsEditor (pid 44472) stopped responding after the Phase 6a executor ran
  `Mars.CellarBat.BuildReviewMap` through Monolith `run_console_command`. Last log lines were Nanite material warnings
  during a level load; no modal was logged; Monolith's socket reset; no crash folder was written (`Saved/Crashes/`
  newest is 2026-10-30). The maintainer killed and restarted the editor. Inferred cause: a level load/new-level issued
  inside the MCP request handler. Rule from here: level creation for the review map goes through
  `editor_query run_python` using the pattern proven by `pale_crawler_ue.build_review_scene`, or the console command is
  run by a human from the editor console; never via `run_console_command`. **inferred** until reproduced deliberately
  (which this task will not do).
  Follow-up (Phase 6a executor): `Mars.CellarBat.BuildReviewMap` no longer calls LoadLevel/NewLevel (it needs the map,
  or an untitled level, open by hand); `Tools/LevelDesign/cellar_bat_r01_review/cellar_bat_review_ue.py` is the
  run_python route (not run yet).

## Phase 5 - Unreal import of the final bat (DONE except animated captures - awaiting Fable audit; Opus executor)

Brief: `PHASE_5_BRIEF.md`. Importer: `scripts/cellar_bat_import_ue.py` (stages `part_a`, `readback`, `reload`, `reimport_a`,
`part_b`, `reimport_b`; run as Monolith `editor_query run_python {"command": "<abs path>/cellar_bat_import_ue.py <stage>",
"mode": "execute_file", "unattended": true}`; merges each stage into `export/unreal_readback_final.json`).

Run order that produced the final state (editor pid 28740 then the relaunch of 20:09:46; project
`D:/Repositories/CkRepos/Orion/Mars.uproject`, 5.7.4, PIE off and 0 dirty packages checked before every write):
`part_a` (20:02) -> sockets via Monolith `animation_query add_socket` on the SKEL (rule after I-3) -> `physics` (reshape) +
Monolith `set_body_properties` x3 -> `part_b` (16 clips) -> `bounds` -> `part_b` again -> [I-4 crash] -> `reload` (cold read on
the relaunched editor) -> `part_b` (all 18, banks re-exported as 2 samples, DEV-10) -> `reimport_a` -> `reimport_b` -> captures.
Every stage merged into `export/unreal_readback_final.json` (keys `part_a_pass1` - first run, before the sockets existed -,
`physics`, `part_b_pass1`, `bounds`, `readback_a`, `reload_a`, `part_a_reimport`, `part_b_reimport`).

### Assets (all under `/Game/ArtCandidates/CellarBat/R01/`; 25 owned, 34 under the root incl. Phase 2/6 assets)  **confirmed**
- `Materials/CellarBat_R01_Mars_M` (master), `CellarBat_R01_Body_Mars_MI`, `CellarBat_R01_Membrane_Mars_MI`, `CellarBat_R01_Eyes_Mars_MI`
- `Meshes/CellarBat_R01_Mars_SK` (3 LODs), `Meshes/CellarBat_R01_Mars_SKEL` (dedicated), `Physics/CellarBat_R01_Mars_PHYS`
- `Animation/CellarBat_R01_<Clip>_Mars_ANIM` x18
Untouched (hash-identical before/after): Phase 6 ABP/BS1D/Additive banks, Review map, Validation folder.

### Materials  **confirmed** (readback)
Master: BaseColor = VertexColor.RGB ^ `VertexColorGamma` (2.2) x lerp(`CavityFloor` 0.45, 1, VertexColor.A); `Roughness`,
`Specular` scalars; Metallic 0; Emissive = `EmissiveColor` x `EmissiveIntensity`; used_with_skeletal_mesh. Instances: Body
rough 0.85 / spec 0.25; Membrane rough 0.8 / spec 0.25 + two-sided via the MI base-property override (override_two_sided =
two_sided = true, read back) - no second master needed; Eyes emissive (1.0, 0.558, 0.162) = #FFC570 linear x 3.0, rough 0.4.
Vertex colour bytes: the legacy importer writes the FBX floats x 255 unchanged (`FbxSkeletalMeshImport.cpp:3851`), so the
material sees sRGB-encoded bytes and the gamma 2.2 decodes them (**confirmed by code**, look **confirmed** in the captures:
oxblood membrane, pale ribs, dark brown fur, amber eyes). Knob: `VertexColorGamma` / `CavityFloor` on the master.

### Readback (final: `part_a_reimport` + `part_b_reimport`; identical to the first pass and to the cold read)
| item | expected | got | |
|---|---|---|---|
| span (imported bounds Y) | 75 +/- 0.5 | 75.000 | PASS |
| bind bounds vs Blender | <= 0.1 cm | 0.0004 cm | PASS |
| nose at +X | max X = 8.353 | 8.3526 | PASS |
| skeleton | dedicated SKEL | `Meshes/CellarBat_R01_Mars_SKEL` | PASS |
| bones / order / parents | 42, manifest order, exact | 42, same, 0 wrong | PASS |
| root ref pose | identity | t 0, q (0,0,0,1), s 1 | PASS |
| bone scales | 1 | max dev 2e-7 | PASS |
| bone heads vs Blender | <= 0.1 cm | 6e-5 cm | PASS |
| handedness | upperarm_r +Y | +5.0 / -5.0 | PASS |
| slots in order + bound | Body, Membrane, Eyes -> 3 MIs | same | PASS |
| LODs | 3; tris 6482 / 2648 / 1202 | 3; 6482 / 2648 / 1202 (T3D SourceModels TriangleCount) | PASS |
| LOD render verts | 19446 / 7944 / 3606 (Blender) | 19446 / 7944 / 3606 | PASS |
| morph targets | 0 | 0 | PASS |
| import data saved | IMPORT_NORMALS, vcolour REPLACE | same | PASS |
| sockets (component pos, bind) | Mouth/Perch/RoostFootL/R | err 0.0 / 0.0001 / 0 / 0 cm | PASS |
| physics | 1-2 torso bodies | spine + pelvis capsules (collide) + head/wrist_l/wrist_r kinematic NO_COLLISION (stopgap) | PASS (stopgap) |
| bounds contain clips | margin >= 2 cm over bone-tail extents | 3.22 cm | PASS |
| 16 clips: keys / length | N+1 / N/30 | all equal (e.g. Hover 16 / 0.5 s, RoostIdle 61 / 2.0 s) | PASS |
| banks | 2 identical keys, 1/30 s, LocalSpaceBase vs Hover f0 | 2 keys, delta 0.0, AAT_LOCAL_SPACE_BASE / ABPT_ANIM_FRAME / Hover / 0 | PASS |
| tracks | 42 | 42 every clip | PASS |
| root stationary | identity at 5 samples | identity, every clip | PASS |
| loop seams (Hover/FlyForward/Glide/Stun/RoostIdle) | f0 == last | max delta <= 1e-6 | PASS |
| loop flag / root motion / rate | manifest loop / off / 1 | same | PASS |
| skeleton per clip | the SKEL | all 18 | PASS |
| notifies | marker frames | Launch ReleaseContact 0.2 s, Hover/FlyForward Wingbeat 0.2, Perch FootContact 0.4, Screech ScreechSound 0.3, Swoop SwoopContact 0.3 | PASS |
Banks vs Hover f0 (raw keys): pelvis 25.0 deg, inner upper arm 31.2, outer 8.9, head 12.0 - the authored bank. Socket check in
motion: Perch rides `pelvis` and sits on the bar centre (3.0, 0, 18.75) at RoostIdle f0 (err 0.001 cm); the breath moves it
0.23 cm by f30; the RoostFoot sockets stay planted (< 1e-5 cm).

### Reload proof (method changed after I-4: no unload in the live editor)  **confirmed**
Pre-restart readback (01:08:46 UTC) saved as `review/phase5/readback_pre_restart.json`; disk hashes `review/phase5/
hashes_all_pre_restart.txt`. On the relaunched editor (20:09:46, every asset loaded cold from disk) `reload` read everything
back: `diff_mesh` [], `diff_materials` [], `diff_clips` [] (16 clips), readings_match true (`reload_a` in the readback json).

### Reimport proof (`replace_existing`, legacy importer, no unload)  **confirmed**
`reimport_a`: existing mesh reused its SKEL, LOD1/LOD2 re-imported in place, all 22 mesh checks pass, owned assets 25 -> 25,
whole root 34 -> 34 (identical lists), no `_1`/`_2` names, slots still bound, bone order unchanged, sockets intact, physics
asset still assigned. `reimport_b`: all 18 clips re-imported, clip readback field-for-field identical to the previous pass
(0 diffs), every clip on the SKEL. Final hashes (`review/phase5/hashes_all_final.txt`): the 11 assets this phase did not write
are byte-identical; SKEL and PHYS re-saved byte-identical; the rest re-saved with equal readbacks. Dirty packages at the end: 0.

### Captures (`review/phase5/`)
- Static mesh, Monolith `capture_scene_preview` (its preview scene: sky + one key from behind-left; no custom lights):
  `mesh_views_sheet.png` (top, below, back, front, face close-up, back three-quarter) and the single PNGs. Looked at: the
  membrane renders from both sides (back view lit, front view dark but present - one-layer membrane, so two-sided works);
  eyes glow amber in shadow; fur/ribs/membrane palette as authored; LOD0 at this distance.
- **Animated captures NOT achieved.** `capture_anim_frames` (Hover, 8 times) wrote 8 byte-identical PNGs, and
  `capture_scene_preview` with `animation_path` + seek 0.0 vs 0.27 gives identical images showing the BIND pose, not Hover's
  high V (`probe_preview_*`). Cause (**inferred from the Monolith source**, `MonolithEditorActions.cpp:2667-2685` /
  `3309-3351`): the pose is set by SetPosition and a zero-delta TickComponent, before/without the component evaluating its
  single-node instance, so the bones never leave the ref pose. Fixing it is a Monolith plugin change (out of this phase's
  scope). The clips' motion is proven numerically instead (bank deltas, seams, root, AnimPose extents per clip), and visually
  only in Phase 4's Blender renders. Neutral vs amber/teal comparisons were not possible in the preview scene.

### Deviations (this phase)
- D5-1 Sockets live on the dedicated SKELETON (Monolith `add_socket`), not on the mesh (raw Python `add_socket` crashed the
  editor, I-3). `mesh.find_socket` resolves them; the runtime reads them the same way.
- D5-2 Physics: the generator made 5 bodies; 5.7.4 exposes no body removal (Python: SkeletalBodySetups protected; Monolith:
  no remove). Stopgap per coordinator: spine capsule r 6 / len 6 along the 30 deg lean centred on the torso (-0.725, 0, -1.256),
  pelvis capsule r 4.5 / len 1 at the rump (-2.6, 0, -4.5) (both colliding); head/wrist_l/wrist_r kinematic + NO_COLLISION.
  **Maintainer step (30 s, not done):** open `Physics/CellarBat_R01_Mars_PHYS`, delete the head, wrist_l and wrist_r bodies,
  save; `cellar_bat_import_ue.py readback` then reports `physics_clean_target_met: true`.
- D5-3 LOD screen sizes stay at the import defaults 1.0 / 0.5 / 0.25 (brief's start 1.0 / 0.35 / 0.15): LODInfo is protected in
  Python and Monolith's setter is static-mesh only; the alternative (a SkeletalMeshLODSettings asset) was not worth an extra
  asset and an LOD rebuild risk. Higher-detail-longer, so no popping risk.
- D5-4 Silent markers = one notify track per marker named `<Marker>_Silent` holding a sound-less `AnimNotify_PlaySound`
  (5.7.4 cannot author a name-only skeleton notify from Python or Monolith). SwoopContact (manifest) added beside the four
  the brief named.
- D5-5 Banks: 2 identical samples (Blender DEV-10) because the legacy FBX importer rejects zero-length takes
  (`SkeletalMeshEdit.cpp:384`).
- D5-6 Bounds extension +X25/+Y6/+Z14, -X13/-Y6/-Z10 from the union of the Phase 3 pose meshes and the 18 clips' bone-tail
  extents (+3 cm); Launch's dive reaches x +30.1. Mesh extents beyond bone tails are covered only by that 3 cm margin
  (**inferred** sufficient: membrane edges end at the finger tails).
- D5-7 `physics_asset` path is `Physics/` (brief) while the manifest's `unreal_paths` says `Meshes/` - manifest to update.

### Not verified
- Any animated view in Unreal (see captures); culling in motion; amber/teal lighting; LOD switching in a viewport.
- The VertexColor gamma decode on the GPU is inferred from the importer code + the look, not from a shader read.

### Incident I-3 - editor crash caused by this executor (2026-11-05 20:01:21 local / 01:01:21 UTC)
- Preceding state: `part_a` run at ~20:00:55 local imported materials + `CellarBat_R01_Mars_SK` + LODs in memory, renamed the
  auto skeleton to `Meshes/CellarBat_R01_Mars_SKEL` (EditorAssetLibrary.rename_asset SAVED it to disk, 20:00, with a
  content-validation modal logged as `MODAL_CLOSE`), then failed at socket creation (`SkeletalMeshSocket.socket_name` and
  `bone_name` are read-only from Python in 5.7.4). Nothing else was saved: on disk under the owned root only
  `Content/ArtCandidates/CellarBat/R01/Meshes/CellarBat_R01_Mars_SKEL.uasset` is new. **confirmed** (directory listing).
- Last call (the crashing one), `editor_query run_python`, mode execute_file, unattended, sent ~20:01:20 local:
  ```python
  import unreal
  t = unreal.SkeletalMesh()                      # transient mesh, no skeleton, no render data
  s = unreal.SkeletalMeshSocket(outer=t)
  t.add_socket(s, False)
  print('n', t.num_sockets(), t.get_socket_by_index(0).get_editor_property('socket_name'))
  print('rename', t.rename_socket('None', 'Probe'))
  print('name', t.get_socket_by_index(0).get_editor_property('socket_name'), t.find_socket('Probe'))
  ```
  Purpose: test whether a socket added with no name can be renamed, on a throwaway mesh instead of the real one.
- Log tail (`Saved/Logs/Mars-backup-2026.11.06-01.01.21.log`): last lines `[2026.11.06-01.01.21:965][ 25]LogOutputDevice:
  Warning: Script Stack (1 frames) : /Script/Engine.SkeletalMesh.AddSocket`, then the log ends. No new `Saved/Crashes` folder
  (newest 2026-10-30). Monolith connection closed mid-call. A new MarsEditor (pid 28740, parent devenv 9944) started 20:01:37.
- Cause (**inferred**, high confidence): `USkeletalMesh::AddSocket` on a transient mesh with no skeleton/imported model
  dereferenced null (the script stack names AddSocket as the frame). My mistake: a "throwaway" object is not safe for
  engine calls that assume a fully built asset. Rule added for this phase: no engine calls on transient/unbuilt assets.
- Next (after the maintainer confirms the editor is back): sockets go through a different route (Monolith `animation_query
  add_socket` on the dedicated skeleton, or add_socket on the real imported mesh followed by `rename_socket` - to be
  decided without further experiments on transient objects); part_a re-run will reuse the saved SKEL (same FBX, same bones).

### Incident I-4 - editor died during the reload proof (2026-11-05 20:09:29 local / 01:09:29 UTC), caused by this executor
- State before: every owned asset saved, `list_dirty_packages` = 0 (checked immediately before). On disk: SK, SKEL, PHYS,
  4 materials, 16 clips (banks pending re-export).
- Last call, `editor_query run_python` (execute_file, unattended), sent ~20:09:25 local: loaded
  `scripts/cellar_bat_import_ue.py` with importlib and called `main('reload')` = `prove_reload()`: hashes of the owned
  packages, full readback (materials, mesh, 16 clips incl. AnimPose evaluation), then
  `unreal.EditorLoadingAndSavingUtils.unload_packages(<the 23 owned packages: SK, SKEL, PHYS, M + 3 MI, 16 ANIM>)`, then
  `find_object` per package and a second readback that re-loads them (`unreal.load_asset`).
- Log tail (`Saved/Logs/Mars.log`, the log of the editor started 20:01:37): `LogUObjectHash: Compacting FUObjectHashTables`
  x2 (the unload's GC), `LogStreaming: Display: FlushAsyncLoading(691): 1 QueuedPackages, 0 AsyncPackages` (the first
  re-load), `LogOutputDevice: Warning: Script Stack (0 frames)`, end of log. No Saved/Crashes folder. MarsEditor process gone.
- Cause (**inferred**): unloading the skeletal mesh + skeleton + physics asset + clips together while something in the
  editor still referenced them (candidates: the AnimPose / SkeletonModifier objects my readback created in the same Python
  call, Monolith's asset index, asset-registry thumbnails), then re-loading them, crashed the engine. The same pattern was
  safe for the pale crawler's static meshes; it is not safe for this skeletal set. Rule from here: no
  `unload_packages` in this editor for this task; the "fresh disk read" proof is replaced by disk-side evidence (hashes,
  mtimes, `project_query get_saved_asset_state`, and a readback in the NEXT editor session, which loads every asset
  from disk by construction).

## Phase 6b-2 - final AnimBP, wiring, bank fix, gates, PIE review (2026-11-06, DONE - awaiting Fable audit)

Brief: `PHASE_6B2_BRIEF.md`. Executor: Opus. No git state changed; nothing committed. Editor at start: pid 43188,
project `D:/Repositories/CkRepos/Orion/Mars.uproject`, PIE off, 0 dirty packages, map Sandbox (run_python, 01:3x UTC).

### 1. Final AnimBP  **confirmed** (builder exit + readback json + editor Python readback)
- Name: **`Animation/CellarBat_R01_Final_Mars_ABP`**. Why not `CellarBat_R01_Mars_ABP`: that path exists on disk (the prep
  build on the blockout skeleton). It was not loaded in this session, but taking the name would mean deleting a saved
  Blueprint from the live editor (I-1/I-2); the brief's fallback name avoids any delete. The prep ABP, its BS1D and the two
  `Additive/*_Add_Mars_ANIM` copies are now superseded (nothing references them; delete with the editor closed).
- Manifest `Tools/LevelDesign/cellar_bat_r01_review/cellar_bat_animbp_manifest_final.json`: skeleton
  `Meshes/CellarBat_R01_Mars_SKEL`, 18 real clips (Telegraph = SwoopTelegraph, Recover = SwoopRecover), blend space
  `Animation/CellarBat_R01_Locomotion_Final_Mars_BS1D`, `banks_additive: true` (the imported banks are already
  LocalSpaceBase vs Hover f0, so no copies), `loops: [RoostIdle, Hover, FlyForward, Glide, Stun]`.
- Builder changes (`cellar_bat_animbp_ue.py`): `Screeching` appended to the phase table and routed to the Screech state;
  per-manifest loop list (`state_loops`); `banks_additive` uses the clips directly; `owned_outputs` = what is saved.
- Run: `python Tools/LevelDesign/cellar_bat_r01_review/cellar_bat_animbp_ue.py --manifest
  Tools/LevelDesign/cellar_bat_r01_review/cellar_bat_animbp_manifest_final.json` -> **CELLAR_BAT_ABP_OK, EXIT 0**, 410
  Monolith calls, 0 failed. Readback `cellar_bat_animbp_manifest_final_readback.json`: parent `Mars_CellarBat_AnimInstance`,
  skeleton = final SKEL, 1 state machine `Bat`, 14 states, **182 transitions** (full mesh, Screech now phase-driven),
  crossfades set and verified 182/182 by from/to, compile -> generated `..._Final_Mars_ABP_C`, errored blueprints [],
  saved only the ABP and the BS1D, dirty after save [].
- Loop flags read from the AnimGraph nodes (editor Python, `AnimGraphNode_SequencePlayer.node.loop_animation`): RoostIdle
  true, Stun true, bank players true (single pose); RoostAlert, Launch, Telegraph, Swoop, Recover, Brake, Perch, Screech,
  Hit, DeathFall, DeathLand false (hold last frame). BS1D: Speed 0..900, Hover 0 / FlyForward 380 / Glide 620.
- A later comment-only edit to `Mars_CellarBat_AnimInstance.as` full-reloaded the parent class while the ABP was loaded:
  checked afterwards - generated class present, 0 dirty, 0 errored BPs. Lesson: do not touch the AnimInstance file while
  its ABP is loaded unless needed.

### 2. Kernel / control / assembly changes (Script, compile clean in the live editor)
- `EMars_Bat_Phase::Screeching` appended last (earlier PhaseIndex values unchanged). **Decision: Telegraph entry**, the
  first telegraph of each sortie (since the last Launch). Not the Alert option: Alert is a hanging phase and the Screech
  clip is a flying clip (Hover f0 to Hover f0), so it would have drawn a flying bat pinned to the beam. Mechanics:
  `UMars_SmTask_Bat_Telegraph` is now a Tick task: once the kernel has admitted the swoop (stage Telegraphing, phase
  Telegraphing) and `FMars_Fragment_Bat_SortieBlackboard.Screeched` is false, it sets the flag and requests
  `SetPhase(Screeching)` (a frame after StartSwoop because the drain applies SetPhase before StartSwoop). The Launch task
  clears the flag. `HandleSetPhase` accepts Screeching only while the ledger and phase are Telegraphing (otherwise
  ignored); the ledger, clocks and outcomes are untouched and the commit names Swooping as usual. Happy-path test now
  expects `Telegraphing -> Screeching -> Swooping` (subsequence).
- Death-fall seed clamped: `State.Fall.Velocity = Telemetry.Velocity.GetClampedToMaxSize(Spec.Flight.SwoopSpeed)`.
- Telemetry: unchanged in the end (diagnostic fields added and removed again, see the bank section).
- Entity script (`Mars_CellarBat_EntityScript.as`): `CandidateAnimClassPath` -> the Final ABP; `MouthSocketOffset`
  (default = the Mouth socket's bind position (7.703, 0, 3.749), Phase 5 readback) replaces `Spec.Swoop.Blow.MouthOffset`
  in the Spec passed to `utils_bat::Add` (so headless runs use the same mouth); sockets are now read right after
  `SetSkeletalMeshAsset`, before the AnimBP poses the mesh (the first read, after the AnimBP, gave (4.67, 0, -4.70) and a
  false mismatch warning); `ClipsHang` (default true): with the final AnimBP the presentation node no longer rolls 180 -
  the clips hang the body - it levels the root's pitch away while hanging (keeps the yaw) and pins the **live** Perch
  socket (re-read every tick from the evaluated pose) to the perch anchor, eased by the hang alpha; the placeholder and
  the no-AnimBP fallback still roll. Speed fed to the AnimBP is smoothed (`SpeedSmoothRate` 6). Review log line
  `[CellarBat] bank ...` every 0.2 s when `LogPhases`.
- Review preset (`Mars_SandboxBat.as`): final mesh + Final ABP, `LoopClip` = `CellarBat_R01_Hover_Mars_ANIM` (no-ABP
  fallback), new `Review_Damage(float)` (a blow through the body zone, the weapon route). Physics asset: the mesh's own
  (`Physics/CellarBat_R01_Mars_PHYS`), body collision stays off. LOD screen sizes: still the asset's 1.0/0.5/0.25
  (D5-3; Python cannot set skeletal LODInfo and the review needed no change). Bounds: the asset's Phase 5 extension.
- Review tooling (`cellar_bat_review_ue.py`): `open_review()`, `chase_set(offset, fov, aim)` and an `aim` offset on the
  chase (the hanging body is ~60 cm above the root), `damage(amount)`, `set_rig(mode)` (moves the two review point lights
  to the bat: key 1200 cd at (+220,-160,-10), fill 400 cd at (-220,+160,-40); 'neutral' = both white, 'amberteal' = the
  map's colours, same intensities/positions; 'map' restores), `force_lod(n)`, `mesh_info()`.

- Later entity-script edits (after run D): the trailing bank heading is normalized (`FRotator::NormalizeAxis`), and the
  presentation also levels the body once it is Landed/Dead (`_Down`, eased at `HangRate`) so the corpse does not keep the
  root's last flight pitch.

### 3. Bank diagnosis  **confirmed** (PIE log, run A 01:40 UTC)
- CkCrowd `FProcessor_CrowdAgent_FaceAngle3D` **does** yaw (and pitch) the root (`CkCrowdAgent_FaceAngle3D_Processor.cpp`,
  absolute SetRotation at `_MaxTurnRate` per axis), and `TickTelemetry` reads it: root yaw went 0 -> -77 -> -3.5 -> 88.7 on
  the patrol corners, `SignedTurnRate` -231 / +220 deg/s on those frames. Why BankAlpha read 0: the agent turns at
  MaxTurnRate = 360 deg/s, so a path corner is a ~0.2 s yaw burst at 60 fps (one 0.33 s frame at this editor's rate); the
  rate-based bank was a one-frame blip, smoothed down, and the prep's point samples never caught one. The velocity
  heading was no better (straight path segments, the heading also jumps at corners; logged +-540 deg/s noise at a node).
- Fix (presentation, entity script `UpdateBank`): a trailing heading follows the root's yaw at `BankFollowRate` 3/s; the
  bank target is how far it trails, full at `BankFullDegrees` 40, then smoothed (`BankSmoothRate` 8); reset while hanging,
  falling or down. Evidence: run L/B logs show `raw=+-1.00 bank=+-1.00` on every corner and easing back
  (`raw=0.27 -> 0.14 -> 0.07 -> 0.05` over 0.9 s on the first approach turn). Kernel telemetry left as it was.

### 4. Gates (toolbox test-only beside the live editor, quiescence checked first: last `==script reload total==` with nothing pending)
- `./CkAuto/UnrealToolbox.exe --test --discover-fresh --test-pattern Mars_AutoTest_Bat_ --output=Saved/Logs/Test-Bat-6b2-final.log`
  -> **EXIT 0**, Total 7 / Passed 7 / Failed 0 / Contaminated 0 (46 s). Happy path lane line: phases `Roosting Alert
  Launching Approaching Telegraphing Screeching Swooping Recovering Returning Braking Perching Roosting`, target hits 1,
  landed 1.
- `--test --test-pattern Monster --output=Saved/Logs/Test-Monster-6b2-final.log` -> **EXIT 0**, 3/3/0, Contaminated 0,
  same three names as the baseline. Known reds: none ran, no new failures. No full gate (brief). **confirmed**
- Run after the last kernel/HFSM/test edit. Afterwards only `Mars_SandboxBat.as` changed (an A/B line added and removed
  again, net zero) and no test spawns the review preset.

### 5. PIE review so far (all through Monolith; frames LOOKED at; the editor ran PIE at ~3 fps, see below)
Captures under `Tools/LevelDesign/cellar_bat_r01_review/captures/`:
- `final_a_roost_patrol/` (run A, 149 frames): bank diagnosis log; flight frames small. `frame_030`: the bat in flight.
- `final_l_roost_light_lod_patrol/` (run L, 166 frames): `frame_020` **the hang**: inverted under the beam, toes clamped on
  the beam's underside, wings wrapped as a cloak (pale ribs, oxblood membrane), amber eyes, ears down. Lighting/LOD probes
  in this run fired before the chase camera started (module not reloaded) - not evidence. `frame_064/066`: spread wings from
  above, `frame_078`: front view in flight, wings spread, eyes lit.
- `final_light_roost2/` (rig on the bat, before the Body change) and `final_light_roost3_body_lifted/` (after): neutral
  front `frame_006` (feet on the beam clearly visible), amber/teal front `frame_013`, neutral back `frame_017`, amber/teal
  back `frame_022`. Reading: the lit back fur reads grey-brown, the front reads near-black (face mask #171415 by design +
  wrapped membranes) with oxblood membrane and pale ribs; the amber/teal rig turns the lit fur teal-brown.
- **Body MI adjusted** (brief addition 1): `Materials/CellarBat_R01_Body_Mars_MI` `VertexColorGamma` 2.2 -> 1.9,
  `CavityFloor` 0.45 -> 0.6 (about 1.5x the fur's linear albedo), saved alone, dirty after []. Before/after pairs:
  `final_light_roost2/frame_0NN` vs `final_light_roost3_body_lifted/frame_0NN` (06, 13, 17, 22): a modest lift on the lit
  fur, front silhouette still dark. Revert: set 2.2 / 0.45 on the MI and save.
- `final_b_swoop_hit_stun/` (run B, 127 frames, map lights): log timeline (bat clock): Alert 0.37, Launch 1.00 NoBake ->
  Roost 1.07 -> Alert 1.12 -> Launch 1.75, Reached 2.23, Approaching 2.36, Telegraphing 5.84, **Screeching 6.17**, Swooping
  6.50, Recovering 7.50; later sorties Telegraphing -> Swooping without Screeching (first-of-sortie rule holds). Hit: damage
  8 at 15.17 while Telegraphing -> swoop 3 cancelled Interrupted, **Hit** 15.51 -> Returning 16.51. Stun: damage 25 at
  22.5 while Recovering -> **Stunned** 22.51 -> Returning 24.51. Frames near the dummy are blown out by the map's 8000 cd
  amber key (`frame_028/036/042/050`); not usable as material evidence.
- **Swoops landed: 0 of 7 in run B, 0 of 3 in a 30 s no-capture run (CELLARBAT_FINAL_HITS).** A/B with the old
  `MouthOffset` (26, 0, -4) (CELLARBAT_FINAL_HITS_AB, temp line in the review preset, removed): identical trajectory, 0/3,
  so the socket mouth is not the cause. The drawn mouth during the Swoop clip sits 7.4-9.5 cm ahead of the root (AnimPose
  readback of the socket at 0/0.2/0.3/0.4/0.6 s), so the socket value is the honest one. Cause (**confirmed** by stats):
  the game thread ran at ~3 fps; at 0.33 s steps the swoop (900 cm/s, 0.7 s, accel 1400) ends ~110 cm short of the aim
  point and the recover overshoots below the floor. Not judged at this rate.
- Frame rate: `Monolith get_stat_group_values Threading` during PIE: `STAT_GameTickWantedWaitTime` 314-321 ms,
  `GameIdleTime` ~319 ms, CPU 0.4% (the game thread sleeps: the editor's throttled MaxTickRate). The EditorPerformanceSettings
  CDO read `bThrottleCPUWhenNotForeground` = False, `bMonitorEditorPerformance` = False (C++ names; nothing changed, so
  nothing to restore). `UEditorEngine::ShouldThrottleCPUUsage` (EditorEngine.cpp ~5036-5052) then throttles only when
  `AreAllWindowsHidden()`: the editor window was minimized (confirmed by Win32 `IsIconic` = true, below). On the relaunched,
  un-minimized editor PIE ran at ~12-13 fps under capture and the swoops landed (section 6).

### Incident I-5 - editor exit right after the window restore (2026-11-06 01:59 UTC)
- Authorized by the coordinator: restore the minimized editor window without focus. Last calls, in order:
  1. Monolith `editor_query run_pie_smoke` {marker CELLARBAT_FPS2, duration 25, console_script ["stat unit", "stat
     threading"]} at 01:58:26 UTC, plus `get_stat_group_values` Threading; the session had ended (PIE off) before step 2.
  2. Outside the editor, Python + ctypes (`scratchpad/win.py`), ~01:59:0x UTC: EnumWindows for pid 43188 -> one
     unowned top-level window, title 'Mars - Unreal Editor', hwnd 12453464, visible, minimized; then
     `ShowWindow(12453464, SW_SHOWNOACTIVATE = 4)` -> returned 24, `IsIconic` false afterwards. No other window call.
- Log tail (`Saved/Logs/Mars-backup-2026.11.06-01.59.09.log`): ordinary editor-world `[CellarBat] bank ... Roosting` lines
  every 0.333 s (frames 703-727, the throttled rhythm) until `01.59.09:175 [727]`, then the log ends. No error, no
  `Script Stack`, no new `Saved/Crashes` folder (newest 2026-10-30). pid 43188 gone; a new MarsEditor (pid 17304) logged
  from 01:59:21 UTC - the coordinator reports the maintainer relaunching it.
- Cause: **the maintainer relaunched the editor deliberately** ("relaunching editor", per the coordinator); the exit
  coincides with the window restore in time only. No window operation after this. The CPU-throttle setting was never
  changed (it read False), so there is nothing to restore.
  State at the exit: PIE off; every asset this phase wrote had been saved (Final ABP, Final BS1D, Body MI); 0 dirty at the
  last check (01:4x). Resumed on the coordinator's go-ahead (section 6).

### Asset manifest  **confirmed** (written from the live AssetRegistry listing, 01:56 UTC)
`Tools/Blender/mars_monsters/cellar_bat_r01/export/CellarBat_R01_AssetManifest.json`: 36 packages under the candidate
root (class, producer, sources, disk size/mtime, status final / superseded / validation) + the 4 derived Jolt cook packages;
physics asset recorded under `Physics/` (corrects the Phase 4 manifest's `unreal_paths` line).

### 6. PIE review on the relaunched editor (pid 17304, 02:00-02:08 UTC) - frames LOOKED at
Ground: run_python at 02:00: project `D:/Repositories/CkRepos/Orion/Mars.uproject`, PIE off, 0 dirty, the Final ABP class
loads cold from disk, Body MI reads 1.9 / 0.6 from disk. No window operation after I-5 (coordinator's order); the window
was not minimized and PIE ran at **~12-13 fps under frame capture** (log frame counter: run S 291->682 in 31 s, run P
798->1604 in 60 s) instead of 3. Review-tool fix found here: PIE holds a second, entity-less instance of the review bat
class (`Review_Describe` = "invalid"); the chase, `damage` and `kill` now skip it (run S's chase had followed it and
framed nothing: `captures/final_s_swoop/` is only the hit count).
- **Hit count** (`final_s_swoop`, CELLARBAT_FINAL_S, map lights + neutral rig at the strike zone): 5 swoops committed,
  **5 landed, 5 dummy OnDamaged (#1-#5), one per swoop**, none during telegraph or recover; first swoop Telegraphing 7.62
  -> **Screeching 7.76** -> Swooping 8.26 -> landed 9.01. With the socket mouth (7.703, 0, 3.749).
- **Swoop/Hit/Stun** (`final_s2_swoop_hit_stun`, 263 frames): timeline Alert 0.37 -> Launch NoBake 1.06 -> Roost -> Alert
  1.26 -> Launch 1.95 -> Approach 2.60 -> Telegraph 5.67 -> **Screech 5.82** -> Swoop 6.36 -> landed 7.08 -> Recover 7.08 ...
  7 swoops committed: 4 landed (gen 1, 2, 3, 5), 2 ran out short (gen 4 ended at (533,20,132), gen 7 at (505,33,153); the
  known first-run shortfall when the strike point is far), 1 cancelled Interrupted by the stun; **4 OnDamaged = 4 landed**.
  Hit: 8 damage at 21.1 while Approaching -> **Hit** 21.14 -> Returning 21.64. Stun: 25 damage at 27.2 while
  Telegraphing -> swoop 6 cancelled Interrupted -> **Stunned** 27.21 -> Returning 29.02. Frames: `frame_030` launch climb
  seen from behind, wings fully spread, oxblood membrane + pale ribs, feet trailing; `frame_114` upstroke (wings high V);
  `frame_117` the dive at the post (contact window); `frame_120` at the post just after contact, wings driving down;
  `frame_183` spread wings from behind. Frames at the post are partly occluded by it.
- **Death** (`final_d_death`, 144 frames): Review_Kill at 4.0 while Approaching at (-135,160,300) -> **Falling** 4.17 ->
  **Landed** 5.07 at (145,257,7): about 240 cm sideways in 0.9 s (PIE10 before the clamp: ~900 cm in 0.81 s). Corpse
  despawned ~6 s later (probe at 15 s: invalid), dummy OnDamaged 0. Frames: `frame_035` flight just before, `frame_038`
  DeathFall collapse (wings up, body tipping), `frame_041` impact, `frame_044`..`frame_089` the corpse lying belly-down
  with the wings out, the same pose in every frame (holds DeathLand's last frame), gone from `frame_092`. The corpse in
  `frame_050` still shows the root's last pitch; after this run the presentation also levels the body once Landed/Dead
  (`_Down`, entity script) - **not re-captured**.
- **Roost / feet / LOD** (`final_lod_bias`, `final_p_roost_lod_patrol_perch`): `final_light_roost2/frame_006` and
  `final_lod_bias/frame_012`: toes clamped on the beam's underside, body hanging inverted, wings wrapped. LOD:
  `Monolith console r.SkeletalMeshLODBias 1/2/0` at 3.5/5.0/6.5 s: `final_lod_bias/frame_012` (LOD0, dense facets on the
  back fur and membrane) vs `frame_015` (LOD1, fewer facets) vs `frame_021` (LOD2, coarse fur facets, simpler feet and
  membrane) - **LOD switching confirmed**; the per-frame crop difference steps at frames 13 and 18-19 match the bias
  changes. `SkinnedMeshComponent.set_forced_lod` (run P) logged success on the component but showed no visible step:
  not used as evidence. Far camera (run P frames 34-44, ~1300 cm, FOV 20): the bat is a few pixels; auto LOD not judged.
- **Patrol, banks, membrane sides** (`final_p_roost_lod_patrol_perch`, 413 frames): every patrol node Reached (no
  low-rate overshoot this time), two full sorties Launch -> Patrol 4 nodes -> Return -> Brake -> Perch -> Roost. Bank log on
  every corner: `raw=-1.00 bank=-1.00` at t=9.84 easing to -0.24/-0.05/-0.01 over 1 s; +1.00 at 12.21 -> 0.39 -> 0.11; +1.00
  at 14.88, 0.95, 0.30 ...; Return turn 0.63 -> 0.91 -> 0.54 -> 0.23. Frames: `frame_110` seen from below while banked
  (one wing high, one low) - underside membrane oxblood with pale ribs; `frame_114` from below, level, face mask and amber
  eyes; `frame_162` from above, wings raised (upstroke), dorsal membrane dark with lit ribs; `frame_170` from above, deep
  downstroke (motion-blurred); `frame_286` from behind, wings spread.
- **Launch / Perch** (`final_r_launch_perch`, 229 frames, map lights): Launch: `frame_066`..`071` RoostAlert unwrap at
  the beam, `frame_073` the drop (the chase lags it, the bat leaves the frame to `079`), `frame_082` first flight. Perch:
  Brake 22.38 -> Perch 23.67 -> Roost 24.45; `frame_182/185` braking climb, wings forward, belly and face to camera;
  `frame_188/191/194` pitched back, feet reaching up; `frame_197` the mesh rising to the beam; `frame_200/210` hanging
  inverted, feet on the beam, wrapped. The rise in `frame_194 -> 200`: the root stops at the hang point 80 cm under the
  anchor (kernel `HangOffset`) and the presentation pins the Perch socket to the anchor over the hang ease (0.33 s), so
  the body travels ~60 cm up in that time (inferred to read as the final swing; a smaller `HangOffset` would shorten it
  but the voxel clearance needs the root 40+ cm under the beam).
- **FlyForward -> Glide blend: not exercised.** The blend space puts Glide at Speed 620 but the kernel never flies the
  Locomotion phases above cruise (380; the smoothed `drawnSpeed` peaked ~453 in run P). Swoop/Recover use their own clips.
  Either lower the Glide sample (e.g. 450) or let Return glide; not changed here.
- **Bounds**: component bounds radius 36.8 (hanging, wrapped) and 46.3-46.8 (flight / fall) read live (`mesh_info`); no
  wing clipped at the frame edge in any frame looked at, but no frame was composed with the wing at the frustum edge on
  the downstroke - **unverified** as a deliberate test.
- Fur judgement (brief addition 1): under the neutral rig the lit fur reads mid grey-brown (`final_s2_swoop_hit_stun/
  frame_030`, `final_lod_bias/frame_012` back view), under amber/teal it takes the light's hue; the front of the hang stays
  dark by design (mask #171415, wrapped membranes). Kept the Body MI lift (VertexColorGamma 1.9, CavityFloor 0.6).

### 7. Gates on the final Script state (after the last .as edit: presentation levelling once Landed/Dead)
- `./CkAuto/UnrealToolbox.exe --test --test-pattern Mars_AutoTest_Bat_ --output=Saved/Logs/Test-Bat-6b2-final2.log` ->
  **EXIT 0**, 7/7/0, Contaminated 0 (47 s).
- `--test --test-pattern Monster --output=Saved/Logs/Test-Monster-6b2-final2.log` -> **EXIT 0**, 3/3/0 (39 s), baseline names.
  **confirmed** (summary blocks). No full gate; no known-red edits.

### End state  **confirmed** (run_python 02:1x UTC)
PIE off, chase stopped, Sandbox map restored (`/Game/Mars/Maps/Sandbox_Mars_MAP`), dirty packages []. Saved this phase:
`Animation/CellarBat_R01_Final_Mars_ABP`, `Animation/CellarBat_R01_Locomotion_Final_Mars_BS1D`,
`Materials/CellarBat_R01_Body_Mars_MI`. No window operation after I-5; the editor window was left as the maintainer
relaunched it.

### Remaining limitations
- Multiplayer not addressed (DoesNotReplicate throughout); packaged build not tested; no performance claim (the frame
  rates above are editor + capture rates, not a measurement).
- FlyForward -> Glide never blends at the kernel's speeds; the frustum-edge bounds check was not composed; the corpse
  levelling change is not re-captured; 2 of 6 uncancelled swoops in run S2 ran out short (tuning, as in 6b-1).
- The physics asset still carries the head/wrist stopgap bodies (D5-2 maintainer step); LOD screen sizes stay 1.0/0.5/0.25.
- Superseded assets to delete with the editor closed: `Animation/CellarBat_R01_Mars_ABP`,
  `Animation/CellarBat_R01_Locomotion_Mars_BS1D`, `Animation/Additive/CellarBat_R01_Bank{Left,Right}_Add_Mars_ANIM`.
- The editor-world copy of the review bat logs a `[CellarBat] bank` line every 0.2 s while the review map is open (review
  logging; turn `LogPhases` off in the preset when the review is done).

## Blockers

- none open
