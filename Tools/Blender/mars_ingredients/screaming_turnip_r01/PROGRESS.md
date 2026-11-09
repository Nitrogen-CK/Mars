# Screaming Turnip R01 - PROGRESS

Living record for the end-to-end production of the Screaming Turnip / Radish v1 (handoff package:
`docs/art/screaming-turnip-production-r01/`, read `DESIGN_TECH_SPEC.md`, `ASSET_MANIFEST.json`, `ANIMATION_MANIFEST.csv`
and the six PNG sheets first). Another session must be able to resume from this file. Every claim below is marked
**confirmed** (evidence named) or **inferred**.

Owned roots: Blender `Tools/Blender/mars_ingredients/screaming_turnip_r01/` (this folder: `scripts/`, `source/`, `export/`,
`review/`); Unreal `/Game/ArtCandidates/ScreamingTurnip/R01/`; runtime under `Script/` in NEW files only
(`Script/ECS/ScreamingTurnip/`, `Script/WorldObjects/Items/Mars_ScreamingTurnip_*.as`, `Script/Items/...`,
`Script/Tests/ScreamingTurnip/`). Nothing is committed or pushed by this campaign unless the maintainer asks.

Pattern to follow: the Cellar Bat campaign, `Tools/Blender/mars_monsters/cellar_bat_r01/` (its `PROGRESS.md`, scripts and
briefs). Routing: Fable plans + audits, Opus executes each phase (memory: review -> plan -> delegate to Opus).

## Scope rulings (maintainer, 2026-11-06)

- v1 = planted -> unarmed harvest -> picked up / held -> thrown -> physically settled, repeated screams while Held or
  LooseSettled. No cooking, cutting, muffling, cargo whimpers, safe harvest.
- **RootMaw hearing is OUT of v1** ("don't integrate rootmaw aggro, the ingredient should not be tied to enemies
  directly, we will circle back on that part later"). The kernel still broadcasts `OnScreamCommitted(sequence, world
  position)` so a listener can be added later; no RootMaw file is touched, no noise adapter, no occlusion trace.
- Exaggerate features/proportions during animation (cheeks, gape, squash/stretch, crown).

## Phase 1 - environment, state, baseline (2026-11-06, DONE)

- Branch `dev`, HEAD `c7e3445d3b0aeb70ce080e7be2b55ef05e1b936e`, 71 dirty paths at start. The package's
  `BASELINE_DIRTY.txt` matches except three submodule gitlinks now also dirty (`Plugins/CkFoundation`, `Plugins/CkTests`,
  `Plugins/Monolith`: sibling-session work inside the submodules). **confirmed** (`git status --porcelain`, `comm`).
  None of those paths are touched by this campaign.
- Blender: `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe` (5.2.2 LTS per the bat record). Headless only:
  `blender -b --factory-startup --python <script> -- <args>`; never attach to a user scene. **confirmed** (path exists).
- Unreal: live `MarsEditor` is OPEN (exclusive lock on `Saved/Logs/Mars.log`). Monolith v0.23.0 on
  `http://localhost:9316`, project `Mars`, 1390 actions. **confirmed** (`monolith_status`). Consequences: no `--build`
  until the editor is closed (AngelScript-only changes take the test-only path beside the editor under the quiescence
  protocol); Unreal imports go through Monolith `editor_query run_python` (mode `execute_file`, unattended).
- Toolbox: `CkAuto/UnrealToolbox.exe` v1.73. Known reds in `AutomationGate.json` are the baseline of record; gates are
  focused patterns only (maintainer rule: no full suite, no `Mars` lane, no pre-change baseline run).
- Engine association GUID `{E4464C1C-43B7-7194-E787-E7B5711509D4}` (resolved by the toolbox, never hardcoded).
- Pipeline precedent (bat): scene `scale_length 0.01` (1 BU = 1 cm), 30 fps, collections `Authoring/Rig/Export/Review`;
  FBX recipe `axis_forward=-Z, axis_up=Y, apply_unit_scale, FBX_SCALE_NONE, mesh_smooth_type=FACE, use_triangles,
  add_leaf_bones=False, colors_type=SRGB`, skeletal adds `object_types={ARMATURE,MESH}, primary_bone_axis=Y,
  secondary_bone_axis=X, use_armature_deform_only, armature_nodetype=NULL`, clip adds `bake_anim` with
  `use_all_actions=False, use_nla_strips=False, force_startend_keying`; armature object renamed `Armature` during export
  (Unreal drops it, no extra root). Round-trip validator re-imports with `anim_offset=0`. Unreal: legacy FBX importer
  (`Interchange.FeatureFlags.Import.FBX 0` in a try/finally), `FbxImportUI`, `FBXNIM_IMPORT_NORMALS`, vertex colour
  REPLACE, `convert_scene=True`, `import_uniform_scale=1`; one-sample clips are rejected (export 2 identical samples).
  Editor-killing operations (never): level load via `run_console_command`, raw Python `SkeletalMesh.add_socket`,
  `unload_packages`/reload of live packages, deleting/force-deleting/reloading a loaded Blueprint. **confirmed** (bat
  PROGRESS.md, `cellar_bat_import_ue.py`, memory).
- Gameplay survey: see Phase D section (filled when the executor brief is written).

## Decisions made rather than asked (low-blast; say if you want them changed)

- D-1 Unreal naming follows the bat, not the spec's suggested stems: `ScreamingTurnip_R01_Mars_SK`, `_Mars_SKEL`,
  `ScreamingTurnip_R01_<Clip>_Mars_ANIM`, `ScreamingTurnip_R01_Mars_M` + `_<Slot>_Mars_MI`; statics
  `TurnipBed_R01_Mars_SM`, `TurnipBedEmpty_R01_Mars_SM`, `ScreamingTurnip_R01_Collision_Mars_SM`.
- D-2 Bone names use the bat's underscore convention: `root, body, jaw, cheek_l, cheek_r, crown, taproot,
  leaf_01_a, leaf_01_b ... leaf_05_a, leaf_05_b` (17). Expressive scale keys are allowed on every bone EXCEPT `root`
  (root: identity on every frame of every clip).
- D-3 Animation playback in Unreal: single-node `PlayAnimation(clip, loop)` on the skeletal component driven by the
  kernel's phase signal (no AnimBP for v1). Blends between clips are hard cuts; the Recover/RecoveryIdle clips are
  authored to start where Scream ends so cuts read as continuous.
- D-4 The four `HANDS_*` glove actions are NOT Blender deliverables; they map to the existing FPHands grip/reach
  presentation (decided in Phase D).
- D-5 PROGRESS lives here (tracked path, bat precedent); the gitignored package folder only gets a pointer file.

## Phase A - blockout, 17-bone rig, four extremes, export-recipe proof (brief: `PHASE_A_BRIEF.md`)

Status: DONE 2026-11-06 (Opus executor) - awaiting Fable audit. Evidence in `review/phaseA/` and `export/validation/`.

### Commands (run from this folder; each prints TURNIP_OK / TURNIP_FAIL and exits non-zero on failure)

```bash
B="C:/Program Files/Blender Foundation/Blender 5.2/blender.exe"
"$B" -b --factory-startup --python scripts/build_screaming_turnip.py            # [-- --no-save]; ~1 min
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python scripts/render_screaming_turnip.py -- --planted [--poses a,b] [--tag rNN]
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python scripts/export_screaming_turnip.py
"$B" -b --factory-startup --python scripts/validate_roundtrip.py
```
Final chain run on the final code, in that order: build exit 0 (`review/phaseA/build_log.txt`), render exit 0
(`render_log.txt`), export exit 0 (`export/validation/export_log.txt`), round trip exit 0 (`roundtrip_log.txt`), all
`TURNIP_OK`. **confirmed** (exit codes + logs this session). Shared audits live in `scripts/turnip_audit.py`.

### Scene (`source/ScreamingTurnip_R01.blend`)  **confirmed** (builder)
1 BU = 1 cm (`scale_length 0.01`), 30 fps, frames 0..18. Collections: `Authoring` (`AUTH_Bulb/Teeth/Taproot/Leaf_0N`,
hidden), `Rig` (empty: no control armature; poses are rotations/scales/one location of export bones), `Export`
(`ScreamingTurnip_R01_Body` + `ScreamingTurnip_R01_Armature`, `TurnipBed_R01`, `TurnipBedEmpty_R01`,
`ScreamingTurnip_R01_Collision`), `Review` (`ReviewCam`, `Ruler_10cm_V/H`, `Label`). Action
`ScreamingTurnip_R01_ScreamTest` (fake user, not assigned). Slots `Skin, Leaf, Mouth, Teeth`; colour attribute `Col`
BYTE_COLOR / CORNER written as sRGB, A = 1.0; Principled base = `Col`.RGB x lerp(0.45, 1, A) (the bat graph).
Mesh: 1276 tris / 668 verts (Skin 740, Leaf 310, Mouth 98, Teeth 128); 15 closed islands (shell+mouth sock, 8 teeth,
taproot, 5 leaves); 0 boundary / non-manifold / winding / inverted / zero-area defects; max 3 influences, normalised,
nothing on `root`. Flat shaded, no modifiers but Armature, no shape keys.

### Neutral measurements (`review/phaseA/measurements.json`)  **confirmed**
| quantity | target | measured |
|---|---:|---:|
| overall height, taproot tip (z 0) to highest leaf tip | 16.0 | 16.000 |
| bulb height (z 1.80..11.70, shell only) | ~10 | 9.90 |
| bulb width (Y) | ~9 | 8.912 |
| bulb depth (X) | ~8 | 7.973 |
| overall neutral bounds h x w x d (leaves widen it) | <= 22x14x13 | 16.00 x 11.885 x 9.670 |

Landmarks, Blender cm (Unreal = (x, -y, z), also in the json): root (0,0,0); body centre / `body` head (0,0,6.825);
bulb bounds centre (-0.013,0,6.75); crown base (0,0,11.55); highest leaf tip (-4.925,0,16.0) (leaf_03, the back leaf);
jaw hinge (-1.0,0,6.65); cheek heads (0.584,+-1.717,6.1); taproot head (0,0,1.9).
Proposed sockets (data only, no bones): `Grip_L/_R` (0, +-3.94, 4.0) = bulb surface at z 4 (the surface is at |y|
3.4-4.1 for z 3-4; |y| 4.5 is only reached at z 5.9-6.4); `MouthCue` (3.45, 0, 6.4) = seam centre on the +X face;
`SoilLine` (0,0,9.6), bulb half-width there 3.30; `HarvestGrip_L/_R` (-0.525, +-1.617, 12.678) = 0.8 cm up the stems of
leaf_02 (+Y) / leaf_04 (-Y).
Collision hull `ScreamingTurnip_R01_Collision`: 36 tris, 20 verts (bottom + 3 hexagons at z 3.35/6.15/9.45, radii
x1.07, + top), extents x -3.707..3.707, y -4.815..4.815, z 1.80..11.70; centre offset from root (0, 0, 6.75); no
material slot. Beds: `TurnipBed_R01` 224 tris, `TurnipBedEmpty_R01` 288 tris (through-socket, top radius 4.3), both
24.0 x 24.0 x 4.09 local (z -3.4..+0.69), slot `Soil`, origin = soil-line centre, placed at z 9.6 in the scene.

### Bone check  **confirmed** (builder + round trip)
17 bones, names and parents exact (`root -> body -> {jaw, cheek_l, cheek_r, crown, taproot}`, `crown -> leaf_0N_a ->
leaf_0N_b`), all `use_deform`, none connected, all QUATERNION. `root` rest matrix identity at the origin. Every
non-leaf bone has an identity rest rotation (points +Y, roll 0; D-A1). Heads as listed above; leaf_a heads at the stem
emergence above the crown dimple (z 11.67+), leaf_b heads at the blade bases.

### Posed extremes (`review/phaseA/pose_report.json`; renders `review/phaseA/<pose>/`)  **confirmed**
Poses are `POSES` in the builder: body scale (X == Z by D-A1) with a body location that keeps z 1.9 fixed ("bottom"
pivot) or none ("centre"), jaw rotation about Y, cheek scale, crown rotation about Y + counter-scale, taproot
counter-scale, leaf_a/leaf_b tilt about each leaf's outward axis. Root matrix deviation 0 in every pose.

| pose | bounds h x w x d (cm) | over 22x14x13 | bulb h / w ratio | key numbers |
|---|---|---|---|---|
| neutral | 16.00 x 11.89 x 9.67 | no | 1 / 1 | seam centre gap 0.08 cm |
| inhale | 16.50 x 11.28 x 7.31 | no | 0.92 / 1.27 | cheek region mean radius x1.41 (cheek bone 1.5 x body); bulb width at cheek band 11.28 (x1.27); centre aperture 0.18 cm, jaw 1.5 deg |
| scream | 18.20 x 12.56 x 11.08 | no | 1.30 / 0.90 | jaw 40 deg; corner-to-corner span 5.89 = **0.661** of neutral bulb width; lip separation 3.9-4.1 cm; both tooth rows visible |
| recover | 10.80 x 12.63 x 10.64 | no | 0.75 / 1.25 | cheeks 0.85 (mean radius x0.95), crown +4 deg, leaves drooped |
| impact_squash | 11.93 x 12.77 x 11.50 | no | 0.80 / 1.20 | centre pivot: taproot tip rises to z 0.985 (root unmoved) |

Triangle-pair intersections (BVH overlap of the posed export mesh; pairs sharing a vertex never counted):
| pose | lip/cavity self | teeth vs mouth | teeth vs teeth | mouth vs outer shell | outer shell self | leaf vs leaf | leaf vs bulb | taproot vs bulb |
|---|---|---|---|---|---|---|---|---|
| neutral | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| inhale | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| scream | 0 | 0 | 0 | 0 | 3 | 0 | 0 | 0 |
| recover | 0 | 0 | 0 | 0 | 0 | 20 | 0 | 0 |
| impact_squash | 0 | 0 | 0 | 0 | 0 | 8 | 0 | 0 |
Attachments, by design, excluded from the above: tooth roots in the gum 80, stem roots in the crown 77-85, taproot root
in the bulb bottom 34 (constant across poses except stems, whose roots swing inside the crown). Reading (inferred, not
inspected per pair): scream `outer shell self 3` = chin facets folding where the jaw falloff meets the body under the
lower lip; recover/impact `leaf vs leaf` = neighbouring drooped blades touching near their wide middles (they layer
visually in the renders).

Unreal composition check (`ue_dev_cm`): skinning the mesh with Unreal's FTransform composition (per-axis scale, no
shear) from the local transforms the exporter writes differs from Blender by <= 0.00001 cm in every pose. **confirmed**.

### Look-and-fix rounds (sheets `review/phaseA/iterations/rNN_*`)
- r00 first build: seam = straight slit, upper teeth hidden, cheeks unreadable from the front, leaves small, grey bg.
- r01 24 columns (front-dense) + 16 rings; slit corners +-48 -> +-50 (gape ratio 0.63 -> 0.66); cheeks forward
  (phi 60, depth 2.6) and 1.5 on inhale; broader, wider-fanned leaves; diagonal "valley" darkening -> read as a
  blotchy checkerboard (rejected next round).
- r02 valley darkening removed; lips roll inward and meet on the seam plane; teeth staggered in depth (upper forward);
  calmer light. Scream now matches sheet 04 (both rows visible).
- r03 corners split into upper/lower vertices closed by a cheek-lobe triangle: lip edges diverge from the pinched centre
  -> the closed seam reads as a folded "><"; lip roll plum; diagonal recess softened (removed streaky facets).
- r04 steeper X arms (0.50 at the corners: too heavy, read as an open bowtie); tooth collars lifted off the curved gum;
  lower row moved to depth 1.2 (teeth vs mouth 8 -> 0, found by a per-pair diagnostic: inner lower teeth touched the
  floor where it bends up). r04 sheets were re-rendered after the teeth fix (first r04 overwritten).
- r05 arms back to 0.34; inhale jaw 4 -> 1.5 deg; per-leaf droop stagger (`leaf_k`) for recover / impact (leaf vs leaf
  34 -> 20, 16 -> 8). r06_final = the same build re-rendered with `--planted` after a whitespace-only edit.

### Export recipe (`export/validation/export_settings.json`)  **confirmed**
The bat recipe verbatim (`apply_unit_scale`, `FBX_SCALE_NONE`, `global_scale 1`, `-Z` forward / `Y` up, FACE smoothing,
triangles, no leaf bones, `colors_type SRGB`; skeletal + `primary Y / secondary X`, deform-only, `armature_nodetype
NULL`; clip + `bake_anim`, all bones, no NLA, `use_all_actions False`, force start/end keys, step 1, simplify 0).
Armature object renamed `Armature` during export only. Beds' location zeroed for export. Blender 5.2.2 LTS, FBX IO
5.15.0; every file binary FBX 7400 (FBXHeaderVersion 1003), Creator "Blender (stable FBX IO) - 5.2.2 LTS - 5.15.0".
Files: `Cube10_Mars_SM.fbx`, `ScreamingTurnip_R01_Blockout_Mars_SK.fbx`,
`ScreamingTurnip_R01_Blockout_ScreamTest_Mars_ANIM.fbx` (neutral -> scream at frame 9 -> neutral, smoothstep, every
bone keyed every frame, root identity keys), `TurnipBed_R01_Mars_SM.fbx`, `TurnipBedEmpty_R01_Mars_SM.fbx`,
`ScreamingTurnip_R01_Collision_Mars_SM.fbx`.

### Blender round trip (`export/validation/roundtrip_report.json`)  **confirmed**
Cube: scale 1, bounds +-5.000. SK: object `Armature` scale 1; 17 bones, extra/missing/wrong parents 0/0/0; bind heads
0.000065 cm, rest rotations 0.0 deg; 1276 tris; slots `Skin, Leaf, Mouth, Teeth`; bounds 0.00003 cm; `Col`
BYTE_COLOR/CORNER; max 3 influences, none on root. Clip: exactly one action (`Armature|Scene`), keyed frames 0..18 (19);
root == rest on every frame (deviation 0); jaw/cheek/leaf_b heads + leaf tips within 0.000066 cm and skinned bounds
within 0.000046 cm at frames 0/9/18; non-unit scale keys survive on body, cheek_l, cheek_r, crown, taproot;
**scale-key check: cheek_l at frame 9 = (0.95, 0.95, 0.95) == authored, body = (1.3, 0.9, 1.3) == authored, error 0.0**.
Statics: scale 1, tris 224 / 288 / 36, slots `Soil` / `Soil` / none, bounds 0.00003 cm, 0 boundary edges.

### Decisions and deviations
- D-A1 (decision, rig contract) All non-leaf bones have identity rest rotation; body scale keeps X (depth) == Z
  (height); jaw and crown rotate only about Y; crown and taproot counter-scale the body. Reason: Unreal composes bone
  scale per axis without shear, Blender multiplies matrices; under this contract both agree exactly (measured above), so
  the Blender preview is what Unreal will play. Cost: the stretch is also 1.3 deep and the squash 0.75 deep (spec only
  fixes h/w). To revert: drop the X == Z rule in `POSES` and re-measure `ue_dev_cm`.
- DEV-1 Bulb height measures 9.90 (target "about 10"): taproot 1.8 cm + crown/leaves 4.3 cm hold the 16.0 total.
- DEV-2 Tri count 1276, under the brief's "roughly 1.5-3k": kept facets broad (24 columns x 16 rings). Builder gate set to
  1200-3000. Raise columns/rings in `P` if the audit wants the count.
- DEV-3 Grip sockets at |y| 3.94 (the bulb surface at z 4), not 4.5 (see landmarks).
- DEV-4 Lip roll faces are slot `Mouth` with a plum/magenta mix; the X seam is an open-ended split-corner fold
  ("><" of thin plum), not four separate creases - the sheet's lobes are suggested, not modelled.
- DEV-5 Poses carry a body location key (keeps the bulb bottom at z 1.9); `impact_squash` uses the centre pivot.
- DEV-6 `source/ScreamingTurnip_R01.blend1` is Blender's automatic save backup (harmless; not an export input).

### Open risks / not verified
- Unreal import not done (Phase C). The Unreal-composition equality is computed in Python from the exporter's local
  transforms (inferred to match what the FBX importer reads; the readback in Phase C confirms it).
- Inhale aperture: centre gap only 0.18 cm, but the split corners open to 0.57 cm as the cheeks inflate, so the pursed
  mouth reads as a small bowtie, not a pinhole.
- Upper teeth show only their tips at the scream (lower row fully); Phase B can lengthen them or lift the upper lip.
- Scream side view shows the lower lip notch biting into the profile (`review/phaseA/scream/scream_side.png`) - reads as
  the jaw drop, but the chin fold (`outer shell self 3`) is there.
- Leaf blades touch when drooped (recover 20, impact 8 pairs); cheek inflation is a uniform scale, so cheeks puff in
  depth too.
- Renders are EEVEE neutral light only; no amber/teal pass, no first-person-scale check.

## Phase 1 addendum - gameplay survey facts (2026-11-06, **confirmed** by the survey's file:line reads; re-verify lines)

- WorldItem (`Script/WorldObjects/Items/Mars_WorldItem_EntityScript.as`): `DoesNotReplicate`; the Jolt body shape is the
  presentation's STATIC mesh (`ShapeSource::StaticMeshAsset`, :306); the visual is always a `UStaticMeshComponent`
  (`AddVisual`, private, :276); subclass hooks `DoOnVisualMeshAdded`, `Compose_WorldItem` (:230). Persistent skeletal
  precedent = Cookbook (`Mars_Cookbook_EntityScript.as` + `Mars_CookbookPresentationComponent.as`: AnimationSingleNode,
  `PlayAnimation`, `Request_EnableTransformPush`). Grips read `Grip_L/Grip_R` sockets + hold faces from the static
  mesh (`Mars_FPHands_Grips.as:371`), so the turnip keeps a hidden static proxy (= the neutral collision hull).
- Mounts: `World / Carried / Held` only; no Airborne/Thrown state. `Get_IsSettled()` (`Mars_WorldItem_Utils.as:569`) is
  mount bookkeeping (true in flight). Throw: `HeldItemUse.Request_Throw` -> `WorldItem.Request_Release` -> `Commit_World`
  (:195) -> `OnMountChanged(Held->World)` + `OnMountSettled(World)` AT RELEASE, then `Processor_Launch` sets velocity.
- Jolt AS API (`utils_jolt_body.as`): `Get_LinearVelocity`, `Get_SleepState`, `Get_MotionType`, contact Added/Persisted/
  Removed signals (persisted needs `Set_PersistContacts(Enable)`), payload `Get_OtherEntity` is INVALID for the baked
  static world. NO angular velocity, NO body support state. Settle precedents: Platter drift watchdog or Asleep
  (`Mars_Platter_Processor_Settle.as:150-190`), Resting (contacts on target entities), Fry `Get_IsStill` (< 5 cm/s).
- Forage: `Request_Release(Reason)` -> `utils_world_item::Request_SpawnWorld` at the ReleasePoint pose + launch; reason
  `Plucked` is declared and unused; `OnReleased(forage, item-under-construction, reason)`; `Persists` + 1 charge = one-shot.
  Source base `Mars_ForageSource_EntityScript.as` (`SetYieldVisible` casts to UStaticMeshComponent).
- Unarmed hold-to-use = interact target with CompletionPolicy Timed + `Set_InteractionDuration` + `RequiresFreeHands`
  (`Mars_Control_Utils.as:77-91` pattern; `Mars_HandWheel_EntityScript.as`; `Mars_TestLamp.as:60-129` minimal target);
  AfterCompletion Timed targets cancel when the press ends; completion via `BindTo_OnInteractionFinished` (:474).
- Tests: rigs `Mars_AutoTestRig_Forage.as`, `Mars_AutoTestRig_PickupByPress.as` (carrier + hands + hotbar + slab +
  throw + UseKey), `Script/Tests/Cookbook/`; registration generated by the live editor (`Mars_AutoTestActors.as`).
- No noise/hearing system exists anywhere in Mars script (CkPerception is a legacy actor-component module, unused).
  Jolt LOS helper precedent for later: `Mars_Bat_Utils.as:703` (`utils_jolt_query::Get_RayCast`, StaticNonSensor).

## Phase D - runtime slice (brief: `PHASE_D_BRIEF.md`)

Status: EXECUTED 2026-11-06 (Opus), placeholder assets; nothing committed. 8/8 ScreamingTurnip tests green; the five
regression patterns green against their pre-change baselines. PIE and every visual unverified.

### Files (all new, plus one JSON entry)
- `Script/ECS/ScreamingTurnip/Mars_ScreamingTurnip_Feature.as` - handle asset, enums, Spec (Vocal/Settlement/Parts, each
  with `Validate()`), Params / state / Settle scratch fragments, NeedsSetup tag, signals, Suspend request.
- `.../Mars_ScreamingTurnip_Utils.as` - `utils_screaming_turnip::Add`, support predicate, readers, `Request_Suspend`, bind mixins.
- `.../Mars_ScreamingTurnip_Processor_Setup.as` - binds the body's ContactAdded/Persisted; stamps `LastSupportAt`.
- `.../Mars_ScreamingTurnip_Processor_Requests.as` - drains Suspend.
- `.../Mars_ScreamingTurnip_Processor_Tick.as` - clock, placement derivation + settle sampler, placement rules, voice.
- `Script/Items/Mars_Item_ScreamingTurnip.as` - `constants_screaming_turnip_assets` (every path) + `Mars_ItemDef_ScreamingTurnip`.
- `Script/Items/Presentation/Mars_ScreamingTurnipPresentationComponent.as` - single-node skeletal adapter (item + bed).
- `Script/WorldObjects/Items/Mars_ScreamingTurnip_EntityScript.as` - World-mode subclass: own proxy + PersistContacts body, `Compose_WorldItem`, kernel, presentation.
- `Script/WorldObjects/Forage/Mars_ScreamingTurnipBed_EntityScript.as` - bed + `UMars_SmState/SmTask_ScreamingTurnipBed_Pull`.
- `Script/Editor/Mars_ScreamingTurnip_MapBuilder.as` - `Mars.ScreamingTurnip.BuildReviewRoom` (open level only, never loads/saves).
- `Script/Tests/ScreamingTurnip/` - rig + the eight tests.
- `Script/Generated/DynamicHandleTypes.json` - one `FCk_Handle_ScreamingTurnip` entry (before `Searing`). No ini tag added.
- Side effect, not authored: the live editor regenerated `Script/Generated/Mars_AutoTestActors.as` /
  `Mars_EntitySpawnParams.as` and its populator re-saved `Content/Mars/Maps/AutoTests_Mars_MAP.umap` (already dirty at
  start) with the eight new test actors. **confirmed** (Mars.log 06.43.47 class-descriptor lines; spawn-params rewrite lines).

### Design facts (confirmed by reading code, or by the tests named)
- Body: the base `AddBody` is private and not configurable (`Mars_WorldItem_EntityScript.as:306`), so the subclass
  overrides `DoConstruct` for World mode (Visual mode delegates to Super) and builds its own proxy visual + body
  (base tuners copied, `Set_PersistContacts(Enable)`), then the shared `Compose_WorldItem` tail - the FoodItem route.
  FPHands reads grips from the definition's `Presentation.Visual.Mesh`, not the component (`Mars_FPHands_Grips.as:645-660`),
  so owning the proxy component changes no grip path. **confirmed** (read; WorldItem/FPHands/HeldItem gates green).
- Contacts: `Persisted` needs the tag (`CkJoltBody_ContactRouter.cpp:65`); `Removed` always fires. A baked floor contact
  resolves to its JoltStaticActor attribution entity (CkJolt CLAUDE.md), so support = non-sensor and (other invalid, or
  no JoltBody, or a JoltBody not Dynamic), or `Asleep`. **confirmed** (read; test 1 settles on a Static JoltBody slab).
- Angular speed: `AngularDistance` between the root rotation at this and the previous sample, in degrees, over the kernel
  clock between samples; first sample after a reset (or no body / unadded body / NaN velocity) reads unsettled.
  **confirmed** (code); thresholds behaviour **confirmed** only for the drop-and-settle cases the tests drive.
- Placement: Held/Carried + `Get_IsSettled()==false` -> Transfer; additionally World + `PendingMount` -> Transfer (a pickup
  underway; deviation D-D1). Test 3 observed Transfer on a World->Held pickup; test 2 observed Loose 1 frame after the
  release request. **confirmed** (tests 2, 3).
- Commit time = this tick's clock (not the theoretical Inhale end), so a hitch emits one scream and schedules the next from
  it; other phase boundaries carry over. Intervals = Cooldown + Anticipate + Inhale within one tick. **confirmed** (tests 1, 5).
- Bed: `UCk_GenericEntityScript_UE` + `utils_forage::Add` (ForageSource composes Health/HitZone/knock body an unarmed pull
  lacks). Route: Use target Timed 0.7 s, AfterCompletion, `RequiresFreeHands`, ReachKind Hold, state class
  `UMars_SmState_ScreamingTurnipBed_Pull` whose task claims the target and issues `Request_Release(Plucked)` (deviation D-D2).
  The context's `InteractableOwner` is the bed entity. **confirmed** (test 7 releases Plucked).
- Presentation: TickViaProcessor component, `Request_EnableTransformPush` each tick as the Cookbook does, `PlayAnimation`
  only when the wanted clip changes; follows OnPhase/OnPlacementChanged plus a tick re-read (support flips are not
  signalled). Assets are looked up in the asset registry before loading: a failed soft load logs
  `LoadPackage: SkipPackage` / `Failed to find object` errors that fail a headless test (iteration 1, 3 reds).
  **confirmed** (Test-Turnip-Iter1 vs Iter2).

### Deviations / decisions (low-blast; say if you want them changed)
- D-D1 World mount with a `PendingMount` reads Transfer (spec: "existing item/mount transfer not yet settled").
- D-D2 The pull's work is an HFSM task (Mars "behaviour lives in HFSM tasks") instead of an `OnInteractionFinished`
  handler; OnInteractionStarted/Finished drive only the bed's clips.
- D-D3 The bed's target is claimed with `EMars_Interactable_DisableReason::Ledger` (no `Exhausted` reason exists; adding one
  is an edit to `Mars_Interactable_Feature.as`, not ours). Follow-up: add `Exhausted` and switch.
- D-D4 Proxy is a uniform 9 cm sphere (not 9 x 8 x 10) to stay clear of Jolt's non-uniform-sphere scale rejection.
- D-D5 Tests drive the pull with `Request_StartInteraction` / `Request_CancelInteraction` from a free-handed test entity
  (Lever rig precedent), and the throw with `WorldItem.Request_Release` (what HeldItemUse's throw calls); the real Use-key
  press/release and HeldItemUse path are not exercised by these tests.
- D-D6 `Suspend` exists but nothing issues it (DoEndPlay only unbinds; the Tick skips an entity that `Get_IsEnding`).
- Not done: SRC_Grip / SRC_Release clips (Tug on start, Cancel on a failed finish only), impact-squash / settle-rock overlays,
  audio/VFX cues.

### Gates (toolbox v1.73 test-only path, editor open, quiescence checked before each run)
| Pattern | Baseline (before any Script/ edit) | Final (final code) |
|---|---|---|
| WorldItem | 23/23, 0 failed | 23/23, 0 failed |
| Forage | 9/9 | 9/9 |
| Cookbook | 5/5 | 5/5 |
| FPHands | not captured (brief asked three) | 31/31, no new failure vs knownReds |
| HeldItem | not captured | 5/5, no new failure vs knownReds |
| ScreamingTurnip | n/a | iter1 5/8 (3 reds = missing-SK load errors, the first test per lane), iter2 8/8 |
Logs: `Saved/Logs/Test-Turnip-{Baseline,Final}-<Pattern>.stdout.txt`, `Test-Turnip-Iter{1,2}.stdout.txt`.

### Placeholder lines to swap after Phase C (all in `Script/Items/Mars_Item_ScreamingTurnip.as`)
- `Proxy()` -> `return CollisionProxy_R01();` and `k_ProxyScale` -> `FVector::OneVector` (if authored at size).
- `Bed()` -> `return Bed_R01();`, `BedEmpty()` -> `return BedEmpty_R01();`, `k_BedScale` -> `FVector::OneVector`
  (the bed transform's `-50 * Z` centring assumes the engine cube; re-check the bed pivot).
- `k_SkeletalOffset`, `k_PlantedOffset` - tune once the SK's pivot is known.
- `Mounting.HeldOffset` (14, 0, -7.5) in the asset block - tune in PIE.
The SK and clips need no edit: they load as soon as the registry knows the paths.

### Not verified
PIE (pickup by the real Use press, gloves cradling the proxy, HeldOffset, throw from HeldItemUse, a planted bed in a map),
any visual (proxy colour, bed slabs, skeletal clips, first-person primitive type), the review-room command (compiled, never
run), Jolt behaviour of the placeholder sphere beyond the slab drops the tests make, the presentation's clip switching
(no SK exists), multiplayer.

## Phase E - grip nodes (brief: `PHASE_E_BRIEF.md`)

Maintainer direction 2026-11-06: grips should be target points (entities with a transform) attached to any mesh
(static/skeletal/other). Status: EXECUTED 2026-11-06 (Opus), nothing committed. Finding behind it (**confirmed**,
`Mars_FPHands_Grips.as:620, :646`, `Mars_FPHands.as:555`): the grip table already won the reach for mechanisms but never
filled the pickup facts, and `Make_Hold` built `SocketGrips` only from static-mesh sockets.

### Files
- `Script/Items/Traits/Mars_ItemTrait_Presentation.as` - `FMars_ItemPresentation_GripPoints { TOptional<FTransform> Right, Left }`
  as `Grip.Points`; `Validate(GripPoints, Handedness)` mixin (Left needs Right, TwoHanded both-or-neither, OneHanded no
  Left, unit scale), chained from the Presentation's `Validate()`; field docs say SocketTwist applies to mesh sockets only.
- `Script/WorldObjects/Items/Mars_WorldItem_EntityScript.as` - the producer (`Resolve_GripPoints`, `DoGet_VisualMeshSockets`,
  private `Add_GripPoints` / `Make_GripEntry`, called from `Compose_WorldItem` (World) and the Visual branch of `DoConstruct`),
  and `protected void DoConfigure_BodySpec(FCk_JoltBody_Spec& InOutSpec)` called by `AddBody` before `utils_jolt_body::Add`.
- `Script/ECS/FPHands/Mars_FPHands_Grips.as` - reach consumer: an item owner with a table is re-anchored to its root and
  gets the pickup facts (`Anchor_ToOwnerRoot`, `Anchor_HandGrip`, `Fill_PickupFacts`); the item static-socket branch is
  deleted; items never take the object-socket branch. Header comments updated.
- `Script/ECS/FPHands/Mars_FPHands.as` - hold consumer: `Make_Hold` takes `SocketGrips` from the item's resolved points
  (`Get_WorldItemScriptClass(item).GetDefaultObject().Resolve_GripPoints`); `Find_MeshSockets` call and `Measure_Faces`
  deleted; fitted faces = `Measure_BoxFaces(Hold.Bounds)`.
- `Script/ECS/Interactable/Mars_Interactable_Feature.as` (`Exhausted`), `Mars_Interactable_Utils.as`
  (`Get_ClaimRemovesFocus` includes it: the only lookup over the enum).
- Turnip: `Mars_Item_ScreamingTurnip.as` (`Grip.Points`, `k_GripLocation_R/_L`), `Mars_ScreamingTurnip_EntityScript.as`
  (back to `Super::DoConstruct` + `DoConfigure_BodySpec` + `DoOnVisualMeshAdded`; `AddTurnipProxy`, `AddTurnipBody`,
  `OnProxyAdded`, the copied `k_Turnip*` tuners deleted), `Mars_ScreamingTurnipBed_EntityScript.as` (`Exhausted` in
  `Claim_Target` and the pull task), Phase D test `..._AnUnarmedPullReleasesOneRootAndEmptiesTheBed.as:83` (asserts `Exhausted`).
- New tests: `Script/Tests/WorldItem/Mars_AutoTest_WorldItem_MeshSocketsBecomeGripPoints.as`,
  `.../Mars_AutoTest_WorldItem_GripPointsValidate.as`, `Script/Tests/FPHands/Mars_AutoTest_FPHands_AGripPointItemIsReachedAsAPickup.as`,
  `.../Mars_AutoTest_FPHands_GripPointsGiveTheHeldSocketGrips.as`, `.../Mars_AutoTest_FPHands_ATransientHeldItemResolvesGripPoints.as`.
- Not edited: item definitions (the cleaver/tenderizer need no fix), Content/, Generated (the live editor regenerated
  `Mars_AutoTestActors.as` / spawn params for the five new tests and repopulated the autotest map, as in Phase D).

### Producer (one resolution, `UMars_WorldItem_EntityScript::Resolve_GripPoints(Presentation) const`)
Order: (a) `Grip.Points` as declared (no twist) -> (b) `DoGet_VisualMeshSockets(Presentation)` (protected hook, default
`Find_MeshSockets(TryLoad_Mesh(Presentation), MeshScale)`: `Grip_R` or `Grip`, `Grip_L`, MeshScale on locations once)
turned by `Twist_AboutHandle(SocketTwist_R/_L)` -> (c) none. `Add_GripPoints` validates the points (ensure, none on
failure), then registers one scene node per point under the root with `Add_Grips` (Frame Node, Roll Fixed, the
Presentation's pose, debug names `WorldItem.Grip_R/_L`), in World mode (via `Compose_WorldItem`, which every World-mode
subclass runs, FoodItem included) and Visual mode. No subclass calls `Add_Grips` for an item (`rg Add_Grips Script`:
Station entity script + two FPHands tests + the base).

### Resolution table (reach / hold), before -> after
| item kind | before | after |
|---|---|---|
| static mesh with grip sockets (Cleaver, Tenderizer) | reach: item branch read `Find_MeshSockets` at reach time, untwisted, anchored to the root, Authored + pickup facts. hold: `Find_MeshSockets` in `Make_Hold`, twisted, x HeldOffset | grip nodes (twisted sockets) on the World AND Visual entity. reach: grip table, re-anchored to the root, pickup facts, Authored; locations equal, rotations now carry the twist (E-DEV-2). hold: the same resolution -> equal to the captured constants (0.001) |
| static mesh without sockets (Rock, Tallow, Pan, closed Cookbook, Potion, Lantern) | reach: reach-hint Sides (two-handed, both free) or point; object-socket scan reachable for items. hold: `Measure_Faces(mesh)` | no table. reach: unchanged (pickup facts + reach hint / point); object-socket scan skipped for items. hold: `Measure_BoxFaces(Bounds)` (equal numbers, E-DEV-3) |
| skeletal (Screaming Turnip: sphere proxy, no sockets) | reach: Sides (two-handed reach hint), Cradle. hold: fitted Cradle from the proxy bounds | `Grip.Points` -> two nodes; reach Authored to the points (pickup facts: proxy mesh, Sphere, Cradle); hold SocketGrips = points x HeldOffset |
| transient held visual (any non-persistent item) | hold read the mesh at equip | the Visual-mode entity registers the same nodes; the hold reads the same resolution, so it is right at equip although the visual constructs later (E-DEV-1) |
| procedural (FoodItem joint: mesh-less, `HalfWidth`) | Sides from HalfWidth | unchanged (no points, no mesh) |

### Turnip grip points (`Mars_Item_ScreamingTurnip.as`)
Root frame = `FTransform(identity rotation, k_GripLocation) * k_SkeletalOffset`, with `k_GripLocation_R = (0, 3.94, 4.0)`,
`k_GripLocation_L = (0, -3.94, 4.0)` (Phase A/B landmark table `Grip_R/_L`, Unreal cm, rotation 0 as the table gives it,
per the coordinator 2026-11-06; identity under Frame Node = palm up, index side forward), `k_SkeletalOffset` identity
(the proxy hull's pivot is the skeletal root). Cradle pose. The hull's own `Grip_L/_R` sockets (same locations) are not
read: explicit points win.

### Equality (deliverable 4)
Captured BEFORE any code edit by a capture pass of `MeshSocketsBecomeGripPoints` on the old code
(`Saved/Logs/Test-TurnipE-Capture.*`, values in `Saved/Logs/Mars_2.log` lines `[TurnipE-Capture]`), Cleaver, empty hands:
- Hold: Kind TwoHanded; `SocketGrip_R` Q(0.365525, -0.516709, 0.382345, 0.673213) L(-4, 22, -14);
  `SocketGrip_L` Q(0.146168, -0.607768, 0.209271, 0.751970) L(-1.568925, 23.918822, -0.346869).
- Reach (root-relative, anchor = root, Authored, Pickup set): R Q(0.707107, 0, 0, 0.707107) L(0, 0, 0);
  L Q(0.707107, 0, 0, 0.707107) L(14, 0, 0).
New path (test green): hold R/L and Kind equal within 0.001; reach locations equal within 0.001; reach rotations equal
the old ones turned by SocketTwist_R (-25) / _L (-60) within 0.001 (E-DEV-2). **confirmed** (Test-TurnipE-Iter1).

### Deviations (say if you want them changed)
- E-DEV-1 (API boundary) The hold consumer reads the item's resolution, not the presentation entity's nodes. A held
  visual is spawned through `Request_SpawnEntity`, which only enqueues a request entity
  (`Plugins/CkFoundation/Source/CkEcs/Public/CkEcs/EntityScript/CkEntityScript_Utils.cpp:365-385`, drained later by
  `FProcessor_EntityScript_SpawnEntity_HandleRequests`), while `Mars_HeldItem_Processor_Sync.as:46-53` broadcasts
  `OnHeldItemChanged` in the same pass and `Mars_PlayerCharacter_Hfsm_Inventory.as:164-171` calls `Request_SetHold`,
  `Make_Hold` and `utils_held_view::Make` inline in that broadcast. Walking nodes would have needed a not-yet-constructed
  fallback (forbidden). Instead the one resolution lives on the WorldItem script class and is asked of its class default
  object; the nodes are registered from the same call, and three tests prove nodes == hold (persistent turnip, transient
  cleaver visual, World cleaver). Cost: `DoGet_VisualMeshSockets` must read no instance state (documented).
- E-DEV-2 Socket items' reach rotation changes by the socket twist: the old reach used the untwisted socket and the old
  hold the twisted one, so the glove turned between reaching and holding. One node cannot reproduce both; the hold
  (what is seen while held) is reproduced exactly and the reach now arrives at the hold's grip. No model or definition fix
  is needed or proposed.
- E-DEV-3 `Measure_Faces(UStaticMesh)` deleted (brief: socket/mesh readers only in the producer); fitted faces come from
  `Measure_BoxFaces(Hold.Bounds)`. Numerically identical while `Bounds` = `Make_BoundsFit(Presentation)` (mesh bounds x
  MeshScale; signed vs abs extents give the same 8 corners), which every mesh-bearing world item composes today (writers of
  `Composition.BoundsFit`: base, turnip, FoodItem joint (mesh-less)). **inferred** from reading those writers.
- E-DEV-4 Mesh-less pickup facts keep `Shape.Mesh` null (as before) rather than a BoundsFit shape:
  `FMars_FPHands_ShapeMesh` (`Mars_FPHands_Contact.as`, not in this phase's edit list) holds only a static mesh.
- E-DEV-5 An item's table targets are re-anchored to the item root: `Mars_FPHands_Contact.as:119` places the pickup mesh by
  `AnchorWorld` and `Mars_FPHands_Processor_Requests.as:113, :262` use the leading grip's `AnchorWorld` as the item's pose.
- E-DEV-6 The skeletal hook exists but no override and no skeletal socket reader: the turnip declares points.
- E-DEV-7 `Exhausted` removes focus (`Get_ClaimRemovesFocus`), as `Ledger` did for the bed.
- Gate pattern for "Stations" is `Station` (matches Station plus *Station tests); `TPBody`, `Interactable` and `Forage`
  added because their files or consumers changed (HeldView folder, enum lookup, the bed).

### Gates (toolbox v1.73 test-only path, editor open, quiescence checked before each run)
Baselines before the first .as edit: FPHands 31/31, HeldView 2/2, WorldItem 23/23, HeldItem 5/5, TPBody 4/4
(`Saved/Logs/Test-TurnipE-Baseline-*.stdout.txt`). New tests: `GripPoint` 5/5 on the first run (`Test-TurnipE-Iter1`). Phase C ran Unreal imports in the live editor
07:34-07:36 during Final-1; Final-2 re-ran the touched patterns afterwards.
| Pattern | Baseline | Final-1 (grip points, `Test-TurnipE-Final-*`) | Final-2 (after the asset swap, `Test-TurnipE-Swap-*`) |
|---|---|---|---|
| GripPoint (5 new) | n/a | 5/5 (Iter1) | 5/5 |
| FPHands | 31/31 | 34/34 (+3 new) | 34/34 |
| HeldView | 2/2 | 2/2 | 2/2 |
| TPBody | 4/4 | 4/4 | not re-run |
| WorldItem | 23/23 | 25/25 (+2 new) | 25/25 |
| HeldItem | 5/5 | 6/6 (+ATransientHeldItem..., name match) | 6/6 |
| ScreamingTurnip | Phase D 8/8 | 8/8 | 8/8 |
| Cookbook | Phase D 5/5 | 5/5 | not re-run |
| Searing | not captured (knownReds) | 39/39 | not re-run |
| Station | not captured (knownReds) | 74/76, 2 NEW (below) | FryStation 8/8 |
| Interactable | not captured (knownReds) | 14/14 | not re-run |
| Forage | Phase D 9/9 | 9/9 | 9/9 |

Station NEW failures, solo re-runs (`--no-live --parallel 1 --known-reds off`, `Test-TurnipE-Solo-*`):
- `CkTests.UnitTests.CkCrowd.StationaryMarkup.WindowedSpeedThreshold` - red alone too ("Expected ... 'Invalid
  stationary-markup movement sample' to occur 6 times ... found 1"). A synchronous C++ unit test of CkCrowd (CkTests
  submodule); nothing this phase touches reaches it (AngelScript only). Not mine (**inferred** from scope; no A/B stash run).
  Prime suspect: the C++ CkCrowd/CkTests binaries vs the sibling-dirty submodules. Candidate for a knownReds entry by its owner.
- `Mars_AutoTest_FryStation_TheOperatorsKeysDriveTheSkimmer` - green alone, and the whole `FryStation` group 8/8 after the
  swap: flaky (a 2.2 s condition timeout in lane 3 of the Station run). **inferred** flake, not a regression.

### Phase C asset swap (coordinator request 2026-11-06, folded into this pass)
In `constants_screaming_turnip_assets`: `Proxy()` -> `CollisionProxy_R01()`, `k_ProxyScale` = one; `Bed()` / `BedEmpty()` ->
`Bed_R01()` / `BedEmpty_R01()`, `k_BedScale` = one; `k_PlantedOffset` = (0, 0, -9.6); `k_SkeletalOffset` stays identity
(hull pivot = SK root, so the SK, the hull and the grip points share the item root). Bed script: the `-50 * Z` cube
centring dropped (bed pivot = soil-line centre); the planted stand-in hull now sits at `k_PlantedOffset` like the SK
(it was centred on the soil line as a sphere). BoundsFit / ProbeFit need no code change: `Make_BoundsFit` centres on the
mesh bounds origin (hull centre +6.75 Z), and the Jolt body is the hull's own shape. `HeldOffset` (14, 0, -7.5) ->
(14, 0, -12): the food cradle value, since the pivot is now the base as a food's is (decision, PIE-unverified). The
SK/clip asset-registry guard is unchanged. The hull and beds are now loaded directly (the assets exist on disk:
`Content/ArtCandidates/ScreamingTurnip/R01/Meshes/`), so headless lanes now depend on those three statics.

### Not verified
PIE: the gloves on the cleaver/tenderizer reach (rotation now twisted on the way in), the turnip's Cradle points (palm
direction chosen, never seen), the turnip proxy hiding through the base visual hook (headless tests only), third-person
held view of the turnip; multiplayer.

## Audit of Phase A (Fable, 2026-11-06) - ACCEPTED for pipeline/rig, look corrections carried into Phase B

Looked at: `review/phaseA/poses_overview.png`, `neutral/neutral_sheet.png`, `scream/scream_sheet.png`,
`inhale/inhale_sheet.png`, `planted/planted_sheet.png`. Accepted (**confirmed** by the executor's printed numbers +
my read of the sheets): 17 bones exact, root identity in every pose/clip, bone scale keys survive the FBX round trip,
every pose inside the 22 x 14 x 13 envelope, neutral 16.000 cm, five leaves / eight teeth / one taproot, beds and hull
exported, scream readable (gape, teeth, stretch). D-A1 (identity rest rotations, body X == Z scale, jaw/crown rotate
about Y only) accepted: it is what makes Unreal's per-axis bone scale reproduce Blender's result.
Misses against sheets 01/04 (Phase B must fix before authoring clips on the mesh):
- A-1 Neutral seam reads as a dark horizontal slit; the reference is a closed X-pucker with no cavity visible at rest.
- A-2 Inhale does not read: cheeks barely leave the silhouette (cheek bones at |y| 1.7 are too central), and the mouth
  widens (0.57 cm bowtie) instead of pursing. Needs lateral bellows lobes and a pursed aperture.
- A-3 Colour transition is four flat horizontal bands; the reference steps magenta into ivory through irregular facets.
- A-4 Scream side profile: the lower lip notches into the bulb; lips should roll outward on the gape.
- A-5 (minor) leaves thin; recover/impact leaf overlaps (20 / 8 pairs) must be 0 in the final clips.

## Phase B - look pass, cavity bake, 15 clips, exports, round trip, manifest (brief: `PHASE_B_BRIEF.md`)

Status: DONE 2026-11-06 (Opus executor) - awaiting Fable audit. Evidence in `review/phaseB/`, `export/`, `export/anims/`.
Nothing under Content/Script/Plugins touched; no git operation; no Unreal import.

### Commands (run from this folder, in this order; each prints TURNIP_OK / TURNIP_FAIL and exits non-zero on failure)

```bash
B="C:/Program Files/Blender Foundation/Blender 5.2/blender.exe"
"$B" -b --factory-startup --python scripts/build_screaming_turnip.py                                   # mesh+rig+poses, saves blend (~1 min)
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python scripts/animate_screaming_turnip.py # 15 clips + per-frame audit, saves blend
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python scripts/export_screaming_turnip.py  # FBX + expected + manifest (no save)
"$B" -b --factory-startup --python scripts/validate_roundtrip.py                                       # fresh-scene re-import of every FBX
# renders (separate, no save):
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python scripts/render_screaming_turnip.py -- --poses neutral,inhale,scream,recover,impact_squash --planted --compare --fp [--tag rNN]
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python scripts/render_anims_screaming_turnip.py [-- --tag rNN]
python scripts/sidebyside_screaming_turnip.py <tag>        # system Python + Pillow: concept crop | front | three-quarter
```
Final chain on the final code: build 0, animate 0, export 0, round trip 0 (logs `review/phaseB/build_log.txt`,
`animate_log.txt`, `export/export_log.txt`, `export/roundtrip_log.txt`); renders r08_final / clip r03_final made from
that final blend. **confirmed** (exit codes + logs, this session).

### Part 1 - look pass (per audit item; proving sheets under `review/phaseB/`)
- **A-1 neutral seam -> closed X-pucker. FIXED, confirmed** (`iterations/r08_final_sidebyside.png` row 1 vs sheet 01
  FRONT; `neutral/neutral_sheet.png` mouth close-up). The mouth slit is replaced by a face patch: the grid rectangle
  |phi| <= 66 deg, z 4.4..8.3 is rebuilt as 5 concentric loops (`LOOP_F`) from a closed X seam (four flaps U / S+ / L /
  S- meeting on four arms, tips at (+-2.25, +-1.05) cm from the seam centre) out to the rectangle. Lip edges sit on the
  surface (L0), roll 0.32 cm into a closure line (L1, gap 0.012 cm), then the open sock (two ellipses + back). Flaps
  are pillowed (puff peak at f = 1/3), the centre pinched 0.62 cm; groove width falls off as (1-s)^2.5 so the arms are
  thin creases with a dark centre. Closure aperture at rest 0.012 cm; no plum cavity visible. 40 loop entries.
- **A-2 inhale -> lateral bellows lobes, pursed aperture. FIXED (numbers), look acceptable, confirmed**
  (`iterations/r08_final_sidebyside.png` row 2 vs sheet 04 INHALE; `lighting/lighting_compare.png`). Cheek heads moved
  to the lobe centres (1.7, +-3.25, 6.4); radial lobe weights (1 inside 1.1 cm, 0 at 3.1, z distance x0.7), neutral lobe
  bump 0.5 cm. Cheek poses are scale-about-a-pivot (`cheek_params`: location = (s-1)(head-pivot), never rotation):
  inhale s (1.04, 1.40, 1.30) about the seam centre, so the pinch stays put while the lobes balloon. Bulb width at cheek
  height 13.51 cm = **1.469x** neutral (target >= 1.35); closure aperture **0.115 cm** (<= 0.15). The cheek Y scale is
  held at the spec guardrail 1.40 (a 1.48 try gave 1.55x; reverted). Inferred / not matched: the sheet's cheeks are near
  spheres bulging forward; ours read as two side bumps around a pinched X. Forward (X) cheek scale is the limiter: any
  X scale moves the side flaps (cheek weight 1) relative to the upper/lower lips and opens the aperture (1.22 gave 0.33 cm).
- **A-3 colour transition. FIXED, confirmed** (`neutral/neutral_sheet.png`, `lighting/lighting_compare.png`). Per-triangle
  colours: magenta rows, two blended rows (0.30 / 0.66 toward ivory) whose base row random-walks +-1 per column
  (seed 11), the row under it tinted (0.90) on upper triangles only (zig-zag edge), ivory below; +-5% jitter kept.
- **A-4 scream profile. FIXED, confirmed** (`scream/scream_sheet.png` side view; `iterations/r08_final_sidebyside.png`
  row 3). Jaw hinge lowered to (-0.5, 4.2): the 34 deg drop swings the lower lip down AND forward (side view: lower lip
  flares past the bulb line, no notch). Upper-lip centre carries 0.25 per cheek so the scream's cheek lift (+0.7 cm)
  rounds the top lip into an arch (r03). Teeth enlarged (hw 0.30, h 0.72 / 0.62) and moved forward: upper row tips +
  wedges and the full lower row visible at the peak; 0 tooth penetrations in every pose and every clip frame.
  Open width at mid-height (side-lip separation) 5.754 cm = **0.626** of the neutral bulb width (9.191; target about
  0.65), vertical lip separation 4.263 cm.
- **A-5 leaves. FIXED, confirmed** (sheets above; anim_report). Blades longer (5.4) and broader (half-width 1.82),
  midrib thickness 0.46-0.60 cm (half-thick 0.30..0.23), stems radius 0.36, embedded stem roots tapered (x0.55) and
  spread (base r 0.78, z 11.3) - that removed the in-crown root collisions. Five leaves at 72 deg in top view.
  Leaf-vs-leaf = 0 in every frame of every clip. Deviation: the leaf mass stays smaller than the sheets' because the
  spec's 16.0 cm total fixes the leaf height (bulb ~10 cm + taproot); width went to 13.36 instead.
- Cavity bake: `Col` alpha = 1 - 0.85 * cos-weighted occlusion (32 rays, 4 cm, floor 0.15) in the neutral rest pose,
  RGB untouched (`turnip_audit.bake_cavity`, bat recipe): min 0.15, mean 0.794 (round trip reads 0.149 / 0.794).
- Rounds: pose looks r01..r08_final (`iterations/rNN_poses_overview.png`, `rNN_sidebyside.png` from r04): r01 X built,
  r02 overlaps cleared (tooth collars, stem roots), r03 thinner closure + pillows + upper-lip arch, r04 no cheek X scale,
  r05 lighting + pillow profile + bigger teeth, r06 lobes + leaves, r07/r08 final + lighting/FP. Clip rounds r01..r03
  (`iterations/rNN_ROOT_Scream_sheet.png`, `_Inhale_`, `_cycle_sheet`): r02 scream leaves flare up/out then recoil
  (was out/down), inhale cheek 1.48 tried and reverted to the guardrail.
- EEVEE three-light rig (warm key / neutral fill / rim, world 0.25) and the game rig (amber key / teal fill / cool rim):
  `lighting/lighting_compare.png` (neutral, inhale, scream x front/three-quarter x both rigs). Both keep the X, lobes,
  gape and teeth readable; teal fill reads on the ivory shadow side. **confirmed** (looked at it).
- First-person mock (`fp_mock/fp_sheet.png`, 90 deg FOV, 45 cm, camera level with the body centre, 10 cm ruler):
  the turnip spans ~18% of frame width. Scream reads instantly (dark gape + both tooth rows); inhale reads by silhouette
  (wide lobes); neutral X is small but legible as a crease mark. Verdict (inferred from stills): the design bet holds
  for the scream; the neutral seam is a detail read, fine at hand distance, likely lost at 2 m+.

### Re-measured (`review/phaseB/measurements.json`)  **confirmed**
| quantity | Phase A | Phase B |
|---|---:|---:|
| overall height, taproot tip -> highest leaf tip | 16.000 | 16.000 |
| bulb h x w x d | 9.90 x 8.912 x 7.973 | 9.90 x 9.191 x 8.021 (lobe bumps, pillow flaps) |
| neutral overall h x w x d | 16.00 x 11.885 x 9.670 | 16.00 x 13.361 x 11.301 (longer, broader leaves) |
| tris / verts | 1276 / 668 | 1944 / 1002 (Skin 1226, Leaf 310, Mouth 280, Teeth 128) |
| islands / defects / max influences / root-weighted | 15 / 0 / 3 / 0 | 15 / 0 / 3 / 0 |
| jaw head | (-1.0, 0, 6.65) | (-0.5, 0, 4.2) |
| cheek heads | (0.584, +-1.717, 6.1) | (1.7, +-3.25, 6.4) |
| highest leaf tip | (-4.925, 0, 16.0) | (-5.897, 0, 16.0) (leaf_03) |
| collision hull | 36 tris, x +-3.707, y +-4.815 | 40 tris, x +-4.40, y +-4.95, z 1.8..11.7, centre (0,0,6.75) |
Unchanged: root (0,0,0), body head (0,0,6.825), crown (0,0,11.55), taproot head (0,0,1.9), beds 224 / 288 tris.
Sockets (Blender cm): Grip_L/_R (0, +-3.94, 4.0); MouthCue (3.43, 0, 6.4); SoilLine (0, 0, 9.6); HarvestGrip_L/_R
(-0.507, +-1.561, 12.678).

Posed extremes (`pose_report.json`; Unreal composition deviation 0.0 cm in all five):
| pose | bounds h x w x d | bulb h / w | open width / neutral w | closure aperture | width at cheek height | intersections |
|---|---|---|---|---|---|---|
| neutral | 16.00 x 13.36 x 11.30 | 1 / 1 | 0.034 | 0.012 | 9.19 (1.00) | 0 |
| inhale | 16.87 x 13.51 x 8.19 | 0.92 / 1.47 | 0.051 | 0.115 | 13.51 (1.469) | 0 |
| scream | 19.86 x 11.42 x 10.51 | 1.30 / 0.89 | 0.626 | open | 8.17 | shell self 1 (mouth-corner fold) |
| recover | 10.83 x 13.83 x 12.21 | 0.75 / 1.25 | 0.043 | 0.013 | 11.49 | 0 |
| impact_squash | 12.16 x 14.12 x 12.80 | 0.80 / 1.20 | 0.041 | 0.013 | 11.03 | 0 |

### Part 2 - clips (`scripts/animate_screaming_turnip.py`; `export/anims/clips.json`; `review/phaseB/anim_report.json`)
Decision D-B1 (rather than asked): no control armature; poses are parameter vectors (`build_screaming_turnip.PKEYS`:
body h/w scale + pivot + z offset + Y rotation, jaw, cheek scale/location, crown Y rotation + z, per-leaf tilt/fan),
Catmull-Rom through key poses (periodic for loops, zero-slope holds where keyed `ease`), additive layers (breath, sway,
15 Hz shake, damped recoil). Splining parameters (not bone channels) keeps D-A1 on every interpolated frame. Pass A
evaluates with no action assigned, pass B writes the F-curves (every non-root bone, every frame, LINEAR), pass C plays
the action back with `frame_set` and audits what the ACTION produces (action vs authored 0.0 in all clips).
`root` is never keyed (the FBX bake writes identity keys); identity asserted every frame. Planted body offset: **-0.6 cm**
(seam top z 6.85 < 9.6; 1.5 cm of magenta shoulder above the soil line; taproot tip z -0.6 in the SRC clips).

| clip | frames (samples) | loop | seam / end delta | intersections max | bounds h x w x d |
|---|---|---|---|---|---|
| SRC_Idle | 0..60 (61) | yes | 0 / velocity 0.0003 cm/f | 0 | 16.34 x 13.58 x 11.71 |
| SRC_Grip | 0..6 (7) | no | chain 0 | 0 | 16.43 x 13.36 x 11.30 |
| SRC_Tug | 0..15 (16) | no | chain 0 | 0 | 17.21 x 12.45 x 10.16 |
| SRC_Release | 0..6 (7) | no | chain 0; ends == QuietIdle f0 | 0 | 17.21 x 14.21 x 12.87 |
| SRC_Cancel | 0..7 (8) | no | chain 0; ends == SRC_Idle f0 | 0 | 17.21 x 13.36 x 11.30 |
| ROOT_QuietIdle | 0..60 (61) | yes | 0 / 0.0009 | 0 | 16.27 x 13.49 x 11.52 |
| ROOT_Anticipate | 0..9 (10) | no | chain 0 | 0 | 16.38 x 13.36 x 11.30 |
| ROOT_Inhale | 0..36 (37) | no | chain 0 | 0 | 16.87 x 13.51 x 9.77 |
| ROOT_Scream | 0..18 (19) | no | chain 0 | shell self 1 (f3..18) | 20.60 x 13.75 x 12.36 |
| ROOT_Recover | 0..30 (31) | no | chain 0 both ends | shell self 1 (f0..1) | 19.86 x 14.10 x 12.74 |
| ROOT_RecoveryIdle | 0..60 (61) | yes | 0 / 0.0001 | 0 | 13.53 x 14.11 x 12.76 |
| ROOT_AirborneLeafTrail | 0..30 (31) | yes | 0 / 0.0022 | 0 | 15.87 x 14.12 x 12.76 |
| ROOT_ImpactSquash | 0..7 (8) | no | start/end neutral | 0 | 16.00 x 14.12 x 12.80 |
| ROOT_SettleRock | 0..12 (13) | no | start/end neutral | 0 | 16.50 x 13.95 x 12.47 |
| ROOT_PlaceSettle | 0..7 (8) | no | start/end neutral | 0 | 16.00 x 13.36 x 11.30 |
Chain (max bone head cm / rot deg, all 17 bones): QuietIdle f0 -> Anticipate f0, Anticipate fN -> Inhale f0, Inhale fN
-> Scream f0, Scream fN -> Recover f0, Recover fN -> RecoveryIdle f0, SRC Idle -> Grip -> Tug -> Release/Cancel ->
Idle/QuietIdle: all **0.0000 / 0.000**. Documented hard cuts (reported, not failed): RecoveryIdle f0 -> Anticipate f0
**0.652 cm / 42.5 deg** (worst over the loop 0.785 / 42.0; drooped leaves vs gathered leaves - the leaves snap up);
QuietIdle any frame -> Anticipate f0 **0.160 cm / 4.1 deg**. Unreal composition deviation <= 0.00001 cm every frame.
Intersection maxima: leaf-vs-leaf, leaf-vs-bulb, teeth-vs-mouth, teeth-vs-teeth, lip/cavity self, mouth-vs-shell,
taproot-vs-bulb all 0 in every frame; outer-shell self 1 pair in Scream f3..18 and Recover f0..1 (the (-,-) mouth
corner fold where jaw and cheek falloffs meet; <= 3 allowed). **confirmed** (anim_report.json).
**Global envelope** across all clips: **21.20 h x 14.21 w x 13.14 d cm** (min (-7.22, -7.11, -0.60), max
(5.92, 7.11, 20.60)) - exceeds 22 x 14 x 13 by 0.21 w and 0.14 d (leaf tips in Release / Recover / RecoveryIdle /
Airborne / Impact). Not clipped; reported (brief rule). The -0.6 z is the planted SRC offset.
Renders: `review/phaseB/clips/<Clip>_sheet.png` (8 frames x front/three-quarter, bed shown for SRC_*),
`clips/cycle_sheet.png` (+ `_threequarter`) - QuietIdle -> ... -> RecoveryIdle at 6 fps, 45 frames. Looked at: Scream,
Inhale (2 rounds each), cycle, SRC_Release.

### Part 3 - export / round trip / manifest  **confirmed**
Files: `export/ScreamingTurnip_R01_Mars_SK.fbx`, `export/ScreamingTurnip_R01_Collision_Mars_SM.fbx`,
`export/TurnipBed_R01_Mars_SM.fbx`, `export/TurnipBedEmpty_R01_Mars_SM.fbx`, `export/validation/Cube10_Mars_SM.fbx`,
`export/anims/ScreamingTurnip_R01_<Clip>_Mars_ANIM.fbx` (15; armature + mesh + one action, scene range = clip range),
`export/expected.json`, `export/anims/expected_anims.json` (every frame: 11 landmark heads, 6 extremes, scales),
`export/export_settings.json`, **manifest `export/ScreamingTurnip_R01_Manifest.json`**. Export recipe verbatim (Phase A).
Round trip (`export/roundtrip_report.json`, `export/anims/roundtrip_report.json`): cube +-5.000 scale 1; SK 17 bones
exact, bind heads 0.000067 cm, rest rotations 0.0 deg, 1944 tris, slots Skin/Leaf/Mouth/Teeth, bounds 0.000052, `Col`
BYTE_COLOR/CORNER (alpha min 0.149 mean 0.794), max 3 influences, none on root; statics scale 1, 224 / 288 / 40 tris,
closed, bounds <= 0.00003. Every clip: one action, keyed first..last with N+1 samples exact, root deviation 0.0 on
every frame, landmark heads <= 0.000085 cm and skinned extremes <= 0.000053 cm on every frame, loop seams 0.0,
scale keys at the peak frame == authored (e.g. Scream f3 body (1.3, 0.9, 1.3), cheek_l (1.0, 0.3, 1.0); Inhale f30
cheek_l (1.04, 1.40, 1.30); error 0.0).
Sockets (manifest, Unreal cm (x, -y, z), rotation 0): Grip_L root (0, -3.94, 4.0); Grip_R root (0, 3.94, 4.0);
MouthCue jaw root-rel (3.43, 0, 6.4) / jaw-rel (3.93, 0, 2.2); SoilLine body root-rel (0, 0, 9.6) / body-rel
(0, 0, 2.775); HarvestGrip_L crown root-rel (-0.507, -1.561, 12.678) / crown-rel (-0.507, -1.561, 1.128); HarvestGrip_R
crown (-0.507, 1.561, 12.678) / (-0.507, 1.561, 1.128). Decision: grips on root (spec: never inherit body scale),
SoilLine on body (carries the planted offset), HarvestGrip on crown (rides the grip dip / tug stretch).

### Deviations (Phase B)
- DEV-7 Mouth topology: slit -> X seam face patch (spec "folded cross-like mouth seam"; sheets 01/02 show four flaps and
  a star opening). Before/after: `review/phaseA/neutral/neutral_sheet.png` vs `review/phaseB/neutral/neutral_sheet.png`.
- DEV-8 Shell grid 24 x 16 -> 28 columns x 19 rings, triangles authored directly (tri count 1276 -> 1944, inside the
  brief's 1.5-3k; closes DEV-2).
- DEV-9 Cheek poses translate as well as scale (pivot form); jaw hinge lowered to z 4.2 (inside the bulb, below the
  seam); upper-lip centre carries 0.25 per cheek. All keep D-A1 (no cheek rotation; ue_dev 0).
- DEV-10 Global envelope 21.20 x 14.21 x 13.14 (over by 0.21 w / 0.14 d, leaf tips) - reported, not clipped.
- DEV-11 Scream open width 0.626 of the neutral bulb width (target "about 0.65"); bulb width grew 9.06 -> 9.19 with the
  lobe bumps, which lowers the ratio.
- DEV-12 Leaf mass smaller than the sheets (16.0 cm total fixed by the spec); broader/longer blades instead.
- Phase A artefacts kept: `export/validation/ScreamingTurnip_R01_Blockout_*.fbx`, `export_settings.json`,
  `expected.json`, `roundtrip_report.json` there are Phase A outputs (stale vs the new mesh; Phase C must import the
  `export/` files, not these). `review/phaseA/` untouched.

### Not verified / open
- No Unreal import (Phase C): FTransform equality is computed in Python (`ue_dev` 0.00001 cm); importer behaviour on the
  per-axis cheek/body scale keys is inferred from the Phase A readback plan, not seen.
- Inhale look vs sheet 04: two side bumps, not forward spheres (see A-2). Scream corner fold (1 shell pair) not visible
  in renders but present.
- The 15 Hz scream shake and timing feel are judged only from stills (contact sheets at 8 frames / 6 fps); nobody has
  watched the clips play.
- First-person verdict is from static renders on a grey backdrop, not in-game.
- Hard cut RecoveryIdle -> Anticipate snaps the leaves 42 deg in one frame; whether that reads as a deliberate "jolt"
  or a pop needs an in-engine look (option: author an Anticipate variant from the tired pose).

## Phase B - final look + 15 clips (brief: `PHASE_B_BRIEF.md`)

Status: executor launched 2026-11-06 after the Phase A audit; runs in parallel with Phase D (Blender only).

## Phase C - Unreal candidate (brief: `PHASE_C_BRIEF.md`)

Status: DONE 2026-11-06 (Opus executor) except the cold-reload proof (needs the next editor restart) - awaiting Fable
audit. Imported the **Phase B exports** (`export/*.fbx`, `export/anims/*.fbx`, all mtime 02:24; the stale
`export/validation/*Blockout*` files were not touched except `validation/Cube10_Mars_SM.fbx`, re-exported by Phase B).
When Phase B3 re-exports after the B2 mouth rework, run `reimport` then `readback` (the readback refreshes the reload
snapshot). No git operation; nothing under `Script/` edited.

### Commands (Monolith `editor_query run_python`, mode `execute_file`, `unattended: true`)
`D:/Repositories/CkRepos/Orion/Tools/Blender/mars_ingredients/screaming_turnip_r01/scripts/screaming_turnip_import_ue.py <stage>`,
stages `materials | mesh | socket_plan | statics | clips | readback | reimport | reload | all`. Each prints
`TURNIP_UE ...` lines + `TURNIP_OK`/`TURNIP_FAIL` and merges its report into `export/unreal_readback_final.json`
(keys = stage names). `readback` also writes the reload snapshot `review/phaseC/readback_pre_restart.json` (with disk
hashes). Sockets on the SKEL are NOT written by the script (bat I-3): Monolith `animation_query add_socket` with the
bone-relative transforms that `socket_plan` prints. Review room: `Tools/LevelDesign/screaming_turnip_r01_review/
screaming_turnip_review_ue.py` (`build_review_scene()`, `capture_views(dir)`, `readback(path)`, `restore_level(path)`).
Run order that produced the final state (editor project `D:/Repositories/CkRepos/Orion/Mars.uproject`, 5.7.4, PIE off and
0 dirty packages before and after every stage; Mars.log's latest reload line a Soft Reload at 07:23 throughout):
`materials` -> `mesh` -> `socket_plan` -> 6 x `add_socket` -> `save_packages` (SKEL only) -> `statics` -> `clips` (first
readback FAILED only the chain-count check: my threshold assumed 10 links, the manifest has 9; fixed, plus two extra end
checks) -> `readback` -> `reimport` -> `readback` -> preview captures -> review room (build, `author_map_settings`,
captures x3 lighting rounds) -> `restore_level` (CellarBat review map, the level open at start). **confirmed** (outputs).

### Assets (`/Game/ArtCandidates/ScreamingTurnip/R01/`, 27 owned + the review map)  **confirmed** (asset registry list)
- `Materials/ScreamingTurnip_R01_Mars_M`, `ScreamingTurnip_R01_{Skin,Leaf,Mouth,Teeth}_Mars_MI`, `TurnipBed_R01_Mars_MI`
- `Meshes/ScreamingTurnip_R01_Mars_SK`, `Meshes/ScreamingTurnip_R01_Mars_SKEL` (dedicated; no physics asset)
- `Meshes/ScreamingTurnip_R01_Collision_Mars_SM`, `Meshes/TurnipBed_R01_Mars_SM`, `Meshes/TurnipBedEmpty_R01_Mars_SM`
- `Animation/ScreamingTurnip_R01_<Clip>_Mars_ANIM` x15 (`SRC_{Idle,Grip,Tug,Release,Cancel}`, `ROOT_{QuietIdle,Anticipate,
  Inhale,Scream,Recover,RecoveryIdle,AirborneLeafTrail,ImpactSquash,SettleRock,PlaceSettle}`)
- `Validation/Cube10_Mars_SM`; `Review/ScreamingTurnip_R01_Review_MAP`
- Side files, not authored by me: `.ckexport` sidecars beside the 6 material assets (written on save by a Ck hook, inside the
  root); the CkJolt on-save static-world cook of the review map wrote `/Game/CkJoltData/ArtCandidates/ScreamingTurnip/R01/
  Review/ScreamingTurnip_R01_Review_MAP/{JoltIndex, JoltCell_*}` (Mars.log 07:38:32 "cooked map ... [8] bodies, [3] cells")
  - OUTSIDE the owned root, same side effect the bat review map had; it is the map's Jolt static world (PIE needs it).
  Delete that folder if unwanted.

### Readback (`export/unreal_readback_final.json` keys `readback` and `reimport`; all from the editor, not Blender)  **confirmed**
| item | expected | got | |
|---|---|---|---|
| master | VertexColor^gamma x lerp(cavity), 4 scalars, skeletal usage | params CavityFloor/Roughness/Specular/VertexColorGamma, used_with_skeletal_mesh true, 10 expressions | PASS |
| Skin / Leaf / Mouth / Teeth / Bed MI | rough .85/.7/.9/.5/.95, spec .25/.3/.1/.4/.1, Leaf two-sided | identical; Leaf override [true,true], others [false,false]; CavityFloor .45, gamma 2.2 | PASS |
| SK bind bounds vs manifest | (-5.8966,-6.6803,0)..(5.4047,6.6803,16.0) | err 0.0001 cm | PASS |
| mouth at +X | max X 5.4047 | 5.4047 | PASS |
| tris / render verts / LODs / morphs | 1944 / - / 1 / 0 | 1944 (Monolith mesh_query) / 5812 / 1 / 0 | PASS |
| bones / names / parents | 17, manifest names, exact | 17, 0 extra/missing, 0 wrong parents | PASS |
| root ref pose | identity | t 0, q (0,0,0,1), s 1 | PASS |
| bone scales (ref) / heads vs Blender | 1 / <= 0.01 cm | max dev 2e-7 / 0.0 cm | PASS |
| handedness | cheek_l at -Y | -3.25 / +3.25 | PASS |
| slots + binding | Skin, Leaf, Mouth, Teeth -> 4 MIs | same order, bound | PASS |
| physics asset | none (collision = static hull) | None | PASS |
| import data saved | IMPORT_NORMALS, vcolour REPLACE, scale 1, convert_scene | same | PASS |
| bounds extension | envelope (-7.222,-7.107,-0.6)..(5.919,7.107,20.596) + 2 cm | +X3/+Y3/+Z7, -X4/-Y3/-Z3; bounds (-9.90,-9.68,-3)..(8.40,9.68,23); min margin 2.40 cm | PASS |
| sockets (component, bind) | Grip_L/R root (0,-+3.94,4); MouthCue jaw (3.43,0,6.4); SoilLine body (0,0,9.6); HarvestGrip_L/R crown (-0.507,-+1.561,12.678) | all six on the right bones, err 0.0 cm (relative jaw (3.93,0,2.2), body (0,0,2.775), crown (-0.507,-+1.561,1.128); Monolith get_skeleton_sockets agrees) | PASS |
| Collision_Mars_SM | bounds (-4.4,-4.95,1.8)..(4.4,4.95,11.7), 40 tris | err 0.0, 40 tris, 1 convex elem, slot "WorldGridMaterial" -> Skin MI | PASS |
| Collision_Mars_SM sockets | Grip_L (0,-3.94,4), Grip_R (0,3.94,4), rot 0 | exact, rot (0,0,0) | PASS |
| TurnipBed / TurnipBedEmpty | 24x24x4.09 (z -3.4..0.6866), 224 / 288 tris, Soil | err 0.0, 224 / 288, Soil -> TurnipBed MI, 1 box elem each | PASS |
| Cube10 | +-5.000 | +-5.000, 12 tris | PASS |
| 15 clips keys / length | N+1 / N/30 s | all equal (QuietIdle 61 / 2.0, Scream 19 / 0.6, Grip 7 / 0.2, ...) | PASS |
| tracks / skeleton / rate / root motion | 17 / SKEL / 1 / off | 17 / SKEL / 1 / off, every clip; 30/1 fps (Monolith) | PASS |
| loop flags | Idle x2, RecoveryIdle, AirborneLeafTrail true; rest false | same | PASS |
| root identity, 5 samples per clip | t 0, q identity, s 1 | exact, every clip | PASS |
| loop seams (QuietIdle, RecoveryIdle, SRC_Idle, AirborneLeafTrail) | first == last | 0.0 cm / 0.0 deg / 0.0 scale | PASS |
| landmark heads, EVERY frame of every clip | expected_anims.json | worst 0.000194 cm (QuietIdle f51 leaf_05_b) | PASS |
| scale peak Scream f3 | body (1.3,0.9,1.3), cheek_l/r (1.0,0.3,1.0), crown/taproot (0.769,1.111,0.769) | identical, err 0.0 | PASS |
| scale peak Inhale f30 | body (0.92,1.08,0.92), cheek (1.04,1.40,1.30), crown/taproot (1.087,0.926,1.087) | identical, err 0.0 (non-uniform bone scale imports) | PASS |
| scale peaks, other 13 clips | expected_anims peak frame | err 0.0 | PASS |
| chain (9 manifest links + Release end == QuietIdle f0, Cancel end == SRC_Idle f0) | 0 | max 3e-6 cm / 1e-5 deg / 0 scale | PASS |
| hard cut RecoveryIdle -> Anticipate f0 | Blender 0.652 cm / 42.5 deg (worst 0.785 / 42.0) | 0.6517 / 42.46 (worst 0.7854 / 41.99 at f44) | matches |
| hard cut QuietIdle -> Anticipate f0 | Blender worst 0.160 / 4.1 | f0 0.0; worst 0.1603 / 4.13 at f30 | matches |
| reimport (replace_existing, all 4 import stages) | identical readback, no `_1` | 0 diffs in materials/mesh/statics/clips/owned/root lists; 27 -> 27; existing SKEL reused; 0 dirty | PASS |
| reload (cold read) | readback after the next editor restart == `review/phaseC/readback_pre_restart.json` | NOT RUN (needs a restart) | pending |

### Paths for the Phase E swap (`constants_screaming_turnip_assets`, `Script/Items/Mars_Item_ScreamingTurnip.as`)
- Proxy / collision hull: `/Game/ArtCandidates/ScreamingTurnip/R01/Meshes/ScreamingTurnip_R01_Collision_Mars_SM.ScreamingTurnip_R01_Collision_Mars_SM`
  (authored at size, pivot = the SK root, so `k_ProxyScale` -> `FVector::OneVector`; its hull centre is +6.75 cm Z above
  the pivot, unlike the engine sphere which is centred - re-check `k_SkeletalOffset`/the body's centre of mass).
- SK: `/Game/ArtCandidates/ScreamingTurnip/R01/Meshes/ScreamingTurnip_R01_Mars_SK.ScreamingTurnip_R01_Mars_SK` (already the
  path in the file); SKEL `.../Meshes/ScreamingTurnip_R01_Mars_SKEL.ScreamingTurnip_R01_Mars_SKEL`.
- Clips: `/Game/ArtCandidates/ScreamingTurnip/R01/Animation/ScreamingTurnip_R01_<Clip>_Mars_ANIM.ScreamingTurnip_R01_<Clip>_Mars_ANIM`
  with `<Clip>` = the stems above (matches `Clip(InClip)` in the file).
- Beds: `.../Meshes/TurnipBed_R01_Mars_SM.TurnipBed_R01_Mars_SM`, `.../Meshes/TurnipBedEmpty_R01_Mars_SM.TurnipBedEmpty_R01_Mars_SM`
  (pivot = the soil-line centre, mesh z -3.4..+0.69; `k_BedScale` -> `FVector::OneVector` and drop the `-50 * Z` cube
  centring; a planted SK sits at bed origin - 9.6 cm Z, the SoilLine socket height).
- Materials (if needed): `.../Materials/ScreamingTurnip_R01_{Skin,Leaf,Mouth,Teeth}_Mars_MI`, `.../Materials/TurnipBed_R01_Mars_MI`.

### Review room  **confirmed** (readback `Tools/LevelDesign/screaming_turnip_r01_review/review_map_readback.json`, 18 actors)
`/Game/ArtCandidates/ScreamingTurnip/R01/Review/ScreamingTurnip_R01_Review_MAP`: floor slab 1200 x 1200 (top Z 0, BlockAll,
ProtoGrid Floor), four 400 cm ProtoGrid walls, no ceiling; NeutralSun (3 lux, yaw 30 pitch -45) + NeutralSky (cubemap,
0.5); AmberKey 900 cd at (-330, 70, 190) behind the player start, TealFill 250 cd at (330, -320, 90). Displays (no
collision, mouths toward the start): `Display_Planted_SK` (150, 200, -6.2) in `Display_PlantedBed` TurnipBed (150, 200, 3.4);
`Display_Bed` (150, 300, 3.4); `Display_BedEmpty` (150, 400, 3.4); `Display_OnSide_SK` (150, -200, 4.6) roll 90;
`Display_HandHeight_SK` (-205, 0, 135) = 45 cm in front of `PlayerStart` (-250, 0, 100). Entities through the entity-spawner
factory: `Bed` (UMars_ScreamingTurnipBed_EntityScript) at the origin, `SecondBed` at (450, -450, 0) (636 cm; the Phase D
command's 1000 cm does not fit the 1200 room). GameMode override `/Script/Angelscript.Mars_Gameplay_GameMode` set through
Monolith `editor.author_map_settings` (saved; read back). Saved only that map; 0 dirty after; previous level restored.
Not run in PIE.

### Captures (look at these)
- Monolith `capture_scene_preview` (bind pose, preview scene lit from behind -X): `review/phaseC/UE_SK_{front,side,
  threequarter,mouth_closeup,back}.png`. The preview key is behind the mouth, so front/mouth views are dark; `back` shows the
  stepped magenta -> ivory facets; `threequarter` the leaves and silhouette.
- Review room (SceneCapture2D, manual exposure -2 EV): `Tools/LevelDesign/screaming_turnip_r01_review/captures/
  UE_review_{room_from_playerstart, fp_hand_height, planted_front, planted_threequarter, beds, onside, hand_mouth_closeup}.png`.
  Looked at: `hand_mouth_closeup` (the closed X pucker reads clearly at hand distance, ivory body / pink crown, leaves),
  `fp_hand_height` (first-person scale at 45 cm, 90 deg FOV, eye 64 cm above the start: the turnip ~10% of frame width,
  pucker legible), `planted_front`/`planted_threequarter` (1.5 cm pink shoulder above the soil, leaves up), `onside`
  (lying on its side, leaves on the floor), `room_from_playerstart`. Lighting rounds: r1 +2 EV blown out; r2 -2 EV but every
  display back-lit (fronts black); r3 displays turned to face the start, key moved behind the start, sun yaw 30 (final).
  Knobs: `EXPOSURE_BIAS`, `AMBER`, `TEAL`, `SUN_YAW` at the top of `screaming_turnip_review_ue.py`.
- No animated capture: Monolith anim captures return the bind pose (bat Phase 5); motion is proven only numerically above.

### Decisions / deviations (low-blast; say if you want them changed)
- C-1 Collision-guard exempts `Cube10_Mars_SM` (the bat has one under its own `Validation/`; per-campaign convention).
- C-2 Collision proxy material = the Skin MI (the FBX has no slot; the importer named the slot `WorldGridMaterial`). Hidden
  at runtime; if shown it looks turnip-coloured.
- C-3 Bed collision = one box each (both beds, incl. the empty one: the box fills the hole; a turnip never sits in an empty
  bed in v1). Proxy collision = one convex hull from the mesh (`set_convex_decomposition_collisions(1, 32, 100000)`).
- C-4 Master also flags `used_with_instanced_static_meshes`; plain static meshes need no usage flag ("static mesh usage
  flag too" read that way).
- C-5 Static-mesh sockets via `StaticMesh.add_socket` on the real imported hull (potion importer precedent; the I-3 crash
  was SkeletalMesh.add_socket on a transient mesh). Skeleton sockets via Monolith only.
- C-6 Review room has no ceiling (the neutral sun/sky must reach the displays); bounds-extension rounded up to whole cm
  (bat recipe), so every margin is >= 2.40 cm.
- C-7 `SecondBed` at 636 cm instead of the Phase D command's 1000 cm (room size). The map was built by my script, not by
  `Mars.ScreamingTurnip.BuildReviewRoom` (same entity class and factory; the command would also add its own 2400 cm slab).

### Incidents
None. No crash, no modal left open (Monolith logged auto-dismissed save modals), no foreign dirty package at any point.
Mars.log shows `Could not find the Logger [CkAbility]` errors around the review-map load (07:38:30) - not from this phase's
code (inferred: a logger lookup in a loaded module), not investigated.

### Not verified
- Cold reload: run `screaming_turnip_import_ue.py reload` in the NEXT editor session (no unload in this one, bat I-4);
  expected `readings_match: true`, empty `hash_diff`.
- Any animated view in Unreal; the clips' motion is proven numerically (every-frame landmark heads vs Blender <= 0.0002 cm,
  scale peaks exact) and visually only in Blender (Phase B sheets).
- PIE in the review room (bed entity, pickup, throw); the bed entity was composed in the editor world without logged
  ensures (inferred from the log scan, not exercised).
- Neutral-light colour judgement in engine: the room captures are amber/teal-lit (beds read orange under amber).
- The B2 mouth rework will replace the SK and clips: the readback numbers above are for the Phase B mesh.

## Audit of Phase D (Fable, 2026-11-06) - ACCEPTED; two shortcuts folded into Phase E

Read: `Mars_ScreamingTurnip_Processor_Tick.as`, `_Feature.as`, `_Processor_Setup.as`, `_Utils.as` (surface),
`Mars_ScreamingTurnip_EntityScript.as`, `Mars_ScreamingTurnipBed_EntityScript.as`, `Mars_Item_ScreamingTurnip.as`,
the presentation component's head; gate summaries re-read from `Saved/Logs/Test-Turnip-Final-*.stdout.txt` and
`Test-Turnip-Iter2.stdout.txt` (WorldItem 23/23, Forage 9/9, Cookbook 5/5, FPHands 31/31, HeldItem 5/5,
ScreamingTurnip 8/8; every summary `Failed: 0`, exit 0). **confirmed**.
Holds: single writer (tick + setup contact stamp, both the feature's own processors); one commit per pass with
carry-over on every other boundary; cooldown from the actual commit; warning frozen on Transfer (incl. World +
PendingMount, D-D1 accepted), cancelled on Loose/Protected; resume from WarningElapsed; settle = (recent supporting
contact or Asleep) + linear/angular bars with enter/exit dwell; angular speed from the root rotation delta; signals
broadcast after all writes; teardown unbinds; no ArtCandidates dependency headless (asset-registry guard).
Folded into Phase E (not acceptable as a base to build on):
- D-E1 The turnip re-implements the base World-mode `DoConstruct` and copies the body tuners because `AddBody` is
  private -> protected body-spec hook on the base, turnip back to `Super::DoConstruct`.
- D-E2 The bed claims its target with `DisableReason::Ledger` (D-D3) -> add `Exhausted` to the enum.
Known one-frame latencies (inferred, acceptable): placement follows the WorldItem processors by up to one pass (no
declared RunAfter edge to Reconcile/Mount/Launch); a Transfer freeze keeps the WarningElapsed of the previous eligible
tick.

## Audit of Phase B (Fable, 2026-11-06) - ACCEPTED; two follow-ups to judge in motion

Looked at: `review/phaseB/iterations/r08_final_sidebyside.png`, `lighting/lighting_compare.png`, `clips/cycle_sheet.png`,
`fp_mock/fp_sheet.png`. A-1 (X-pucker, no cavity at rest), A-3 (stepped faceted colour), A-4 (scream profile, teeth),
A-5 (leaves, 0 leaf overlaps) fixed as the sheets show. A-2 partially: width 1.47x at cheek height and a pursed
aperture, but no forward lobes (any forward cheek scale opens the pucker). Pipeline numbers **confirmed** by the
executor's logs (15 clips, N+1 samples, root identity, chain deltas 0, scale keys through the round trip, envelope
21.20 x 14.21 x 13.14 - leaf tips 0.21 / 0.14 cm over the proposal, accepted; bounds extension covers it).
Follow-ups (not blocking Phase C):
- B-1 Inhale lobes do not bulge forward like sheet 04; revisit only if PIE says the warning is not readable.
- B-2 RecoveryIdle f0 -> Anticipate f0 hard cut snaps the crown 42 deg. If it pops in PIE: add `ROOT_AnticipateTired`
  (starts from the drooped crown), chosen by the presentation from the previous phase; no kernel change.
- Stale: `export/validation/*Blockout*` + Phase A json there; Phase C imports `export/` and `export/anims/` only.

## Phase B2 - mouth rework (brief: `PHASE_B2_BRIEF.md`)

Maintainer 2026-11-06, on `r08_final_sidebyside.png`: "very disappointed with the result for the mouth. It needs to be
much better." Fable read: the concept has plump lip pads with deep creases and a pinched centre, forward+outward cheek
lobes on the inhale, a thick rolled rim with gum-seated teeth on the scream; the model has a thin X on a smooth shell,
no lobes, and a hole-cut gape. Phase B2 rebuilds the mouth patch (radial loops, lip pads, gums, cavity, lobes) with a
Fable/maintainer review gate BEFORE the clips are re-authored (Phase B3 = animate + export + round trip + Phase C
`reimport`). Status: executor launched; Phase C keeps importing the Phase B exports (the importer's reimport stage
replaces them later).

### Phase B2 executor report (Opus, 2026-11-06) - DONE, awaiting the maintainer's mouth review (gate: STOP before B3)

Nothing under `export/` written; `animate_screaming_turnip.py`, `export_screaming_turnip.py`, `validate_roundtrip.py` NOT
run; no git; no Unreal. Writes: `scripts/` (build, audit, render, side-by-side), `source/ScreamingTurnip_R01.blend`
(rebuilt), `source/ScreamingTurnip_R01_phaseB_clips.blend` (byte copy of the Phase B blend taken BEFORE the first
rebuild: it holds the 15 Phase B clip actions), `review/phaseB2/`, this section. **confirmed**.

**The rebuilt `.blend` has NO clip actions**: the builder's `reset_scene` wipes actions, and animate was not run (gate).
The Phase B clips live only in `source/ScreamingTurnip_R01_phaseB_clips.blend` and `export/anims/` - both are stale
against the new mesh (different vertex count / weights). Phase B3 must re-run animate on the new blend.

#### Rerun (from this folder)
```bash
B="C:/Program Files/Blender Foundation/Blender 5.2/blender.exe"
"$B" -b --factory-startup --python scripts/build_screaming_turnip.py      # -> review/phaseB2/{measurements,pose_report}.json, saves blend (~1 min)
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python scripts/render_screaming_turnip.py -- \
    --poses neutral,inhale,scream,recover,impact_squash --planted --compare --fp --mouth --tag rNN   # ~4 min
#   (--poses none --mouth --res 400 renders only the mouth crops, ~40 s)
python scripts/sidebyside_screaming_turnip.py rNN                          # -> review/phaseB2/iterations/rNN_mouth_sidebyside.png
#   (--phaseB keeps the old Phase B whole-turnip side-by-side)
```
Final chain on the final code: build exit 0 TURNIP_OK (`review/phaseB2/build_log.txt`), render exit 0 TURNIP_OK
(`render_log.txt`, 9 sheets tagged `r12_final`), side-by-side TURNIP_OK. **confirmed**.

**Look at:** `review/phaseB2/iterations/r12_final_mouth_sidebyside.png` (3 rows x concept | front | three-quarter |
side), then `r12_final_poses_overview.png`, `r12_final_lighting_compare.png`, `r12_final_fp_sheet.png`. Round history:
`r00`..`r12` `_mouth_sidebyside.png` in the same folder.

#### Topology change (builder `build_bulb`, `seam_loop`, `muzzle_h`, `edge_weights`)
- Patch rectangle widened to |phi| <= 66, z 3.8..8.85 (was z 4.4..8.3): 44 spokes (one per boundary vertex), 10
  concentric loops `LOOP_F = 0, .045, .10, .17, .26, .37, .50, .65, .82, 1` around the seam centre. Loop 0 = the lip
  edge on the crease floor (the closed X: four pads U / S+ / L / S- meeting on four arms, tips (+-2.25, +-1.05), arm
  2.48 cm); loops 1-3 = lip wall + rolled crest; 4-5 = outer slope / outer crease edge; 6-8 = muzzle-to-bulb blend; 9 =
  the grid. The four X arms are the spokes the pads meet on (not literally +-45 deg: the X angle is +-25 deg as in
  sheet 01 - say if the +-45 deg wording was meant literally).
- Muzzle field (2D in (y, dz), along the bulb normal): dome 1.05 cm (ellipse 2.6 x 1.95, plateau r_e < 0.45, 0 at 1.3);
  each pad rises in a steep sine wall over 0.38 cm (0.28 at the tips) from the crease floor to a crest AT the lip edge,
  then slopes 35% down over 1.4 cm (rolled lip, not a plateau); crease strength 1.0 at the centre -> 0.45 at the tips;
  centre pinch 0.42 cm (r 1.0). Lip edges open into a tapered slit (half-width 0.30 at the centre -> 0.03 at the tips,
  side pads capped by their 50 deg wedge so they never cross).
- Mouth pocket hangs off the closure line (x_c = 3.372, the closure centre; was the lip edge): L0 -> L1 lip roll (0.28
  deep, dark plum), 2 gum levels (`gum` part, plum lighter than the cavity), 2 cavity levels, back at 3.40 cm.
- Teeth: 4 + 4, roots seated on the gum (ray to the pocket), rows at 0.72 / 1.02 behind the closure; **weights copied
  from the nearest gum vertex** (were hard body / jaw), so they ride with the gum - none floats.
- Parts: new `pad` (12, muzzle faces) and `gum` (13); slots unchanged (gums in `Mouth`). Colours: pad faces tinted
  toward `#F1C3AE` (<= 42%), crease walls toward `#C27C83`, gum `#8E3E5C`+10% magenta; muzzle facet jitter 1.5% (5% elsewhere).
- Cheek lobes: `CHEEK_HEAD` (1.5, +-3.3, 6.4) (was 1.7, 3.25), R0 1.6 / R1 3.4, neutral lobe bump 0.60 at |y| 3.3.

#### Weights / poses (the load-bearing decision; D-B2-1 below)
- Both cheeks get the SAME transform on the inhale (pivot on y = 0) and the jaw translates with them, so a vertex's
  inhale motion depends only on its total cheek share C and moving share F = C + J (1 - C); `edge_weights` makes C and
  F equal on both sides of every crease -> the pucker cannot open (measured gap 0.03 cm). The scream opens the mouth
  through what differs per pad: the left/right split (S+ all `cheek_l`, U/L by y) and the jaw/body split.
- inhale: body 0.92 h / 0.88 w; jaw `jx` +1.3 (new PKEY, appended last: animate's vectors stay compatible); cheeks
  scale (0.55, 1.55, 1.40) about `SEAM_PIVOT` (3.37, 0, 6.4) + translate +1.3 X.
- scream: body 1.30 h / 0.90 w, jaw 34 deg; cheeks scale (0.60, 0.30, 1.0) about `SCREAM_PIVOT` (3.3, 4.5, 6.4) + lift 0.7 Z.
- D-A1 holds: no cheek / jaw rotation besides the jaw's Y; Unreal composition deviation 0.00000 cm in all five poses. **confirmed**.

#### Look-and-fix rounds (`review/phaseB2/iterations/rNN_mouth_sidebyside.png`; one fix per round)
| round | fix | what the sheet showed after it |
|---|---|---|
| r00 | first radial build | neutral X = long hairlines on a noisy muzzle; inhale jag at the back; scream folds |
| r01 | crease opens at the centre (dark wedge) | centre reads, arms still scratches; framing corrected to the concept's 9.2 cm |
| r02 | pads rise in a rounded shoulder | side view gains two proud lips; front unchanged (metric fixed: chord depth, ellipse protrusion) |
| r03 | crest moved to the lip edge (rolled lip, slope back) | crease 0.55 at mid-arm; front still thin lines |
| r04 | tapered slit (0.30 -> 0.03) + dark roll walls | **first neutral that reads like sheet 01**; exposed side-wedge self-crossing (fixed: cap) + teeth through the closure (fixed: pocket off the closure line) |
| r05 | scream: pocket follows the lip's jaw share; upper pad interior follows its edge | upper teeth at the upper rim (were mid-gape); corner folds 19 -> 3 |
| r06 | inhale: side field front-only; lobes +1.3 forward, z 1.40 | back jag gone; lobes +1.08 / +1.31 |
| r07 | inhale: cheek share 0 at the arm tips | pucker purses to 0.88 / 0.92; scream became gull-winged |
| r08 | scream: cheeks flatten X 0.6 about the closure | visor/fins reduced |
| r09 | scream: shallower lower pocket, chin jaw field to z 2.7 | whole gape visible (scream crop widened to 10.5 cm: our gape is ~1.3x the concept's) |
| r10 | lower lip jaw to s 0.8, softer upper split | **null round** - no visible change (the V comes from the glued lower arms, not these knobs); kept, harmless |
| r11 | lower arms open (cheek share 0.6 sin(pi s)) | **regression**: lower lip torn into jagged flaps, inhale pocket folds 6 -> **reverted** (`clo_peak` 0) |
| r12 | muzzle facet jitter 5% -> 1.5% | slightly calmer muzzle; geometry == r10. `r12_final` = the delivered build |

#### Measured (`review/phaseB2/pose_report.json` `mouth_b2`, `measurements.json` `muzzle_rest`)  **confirmed**
| quantity | target | neutral | inhale | scream |
|---|---|---:|---:|---:|
| muzzle proud >= 0.25 cm, w x h | ~5.5 x 4.0 | 5.58 x 3.53 | - | - |
| muzzle max protrusion (fades 0.12 at loop 9) | 0.8-1.0 | 1.03 | - | - |
| pad thickness U / L / S (crest x - closure x) | >= 1.0 | 1.53 / 1.59 / 1.69 | 0.66 / 1.46 / 1.03 | 1.40 / 1.06 / 1.32 |
| crease depth at mid-arm, min over 4 arms (chord) | >= 0.5 | **0.39** (s .25: 0.47-0.49) | 0.40 | 0.25 |
| centre pinch (floor at s .5 - centre) / below crests | >= 0.4 | 0.61 / 0.83 | 0.33 / 0.42 | - |
| closure gap / centre aperture | <= 0.15 | 0.026 / 0.002 | **0.030 / 0.003** | open |
| lip tip span y / z vs neutral (purse) | 0.85-0.90 | 1 / 1 | **0.88 / 0.92** | - |
| lobe apex forward / outward | >= 1.0 / >= 1.2 | 0 / 0 | **0.98 / 1.31** | 1.00 / 0.22 |
| lobe apex x - lip crest x (past the lips) | >= 0 | -1.79 | -1.59 | -2.25 |
| rim, lip edge -> outer crease edge (front), min / mean | >= 0.8 | 0.79 / 1.17 | 0.76 / 1.67 | **0.55** / 1.84 (U 0.62, L 0.55, S 0.61) |
| cavity depth (mean lip edge x - deepest x) | >= 3 | 4.55 | 4.51 | 5.12 |
| gape (side-lip separation / neutral bulb w) | 0.62-0.68 | - | - | **0.613** (5.67 cm; vertical 5.97) |
| bulb width at cheek height / neutral | - | 1.00 | 1.364 | 0.883 |
| lip+cavity self / teeth vs mouth / teeth vs pad | 0 | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 0 / 0 |
| mouth vs shell / shell self / pad self (info) | - | 0 / 0 / 0 | 0 / 0 / 0 | **56 / 27 / 7** |
recover and impact_squash: every intersection 0, gap <= 0.022.
Mesh: 2572 tris / 1316 verts (Skin 1650, Leaf 310, Mouth 484, Teeth 128), 15 closed islands, 0 defects, max 3
influences, normalised, none on root; 17 bones exact, root identity, non-leaf rest rotations 0. Neutral height 16.000;
bulb 9.90 x 9.251 x 8.086 (Phase B 9.90 x 9.191 x 8.021: +0.06 / +0.07, inside +-0.3). Hull unchanged (40 tris).
Sockets unchanged except **MouthCue (3.43, 0, 6.4) -> (4.686, 0, 6.4)** (the raised lip edge; `measurements.json`
updated; the Phase B manifest under `export/` still says 3.43 - B3's export rewrites it).

#### Deviations / misses (each is the maintainer's call)
- D-B2-1 (decision, rig) matched-C/F crease weights + jaw translation `jx` on the inhale (above). Revert: drop `jx`,
  set `INHALE_T` 0 (lobes then move ~0.5 forward, not 1.0).
- DEV-B2-a crease depth at mid-arm 0.39-0.41 < 0.5 (0.47-1.06 at s .25). The slit width that makes the X read (r04)
  costs depth at mid-arm. Knob: `MUZZLE.crease` (1.0, 0.45) -> (1.0, 0.7).
- DEV-B2-b scream rim min 0.55 < 0.8 (lower lip at the corners; mean 1.84). Scream shell overlaps 56 mouth-vs-shell + 27
  shell-self at the LOWER MOUTH CORNERS (z 3-4, |y| ~2; Phase B accepted <= 3): the side pad's lower half and the lower lip
  stay glued along the lower arms, so the corner folds. r11's fix tore the lip (reverted). This needs a different scream
  topology at the lower corners, not a knob - not solved.
- DEV-B2-c gape 0.613 (target 0.62-0.68; Phase B 0.626).
- DEV-B2-d lobes do not stand past the lips in X (apex 1.6 cm behind the crest). An affine cheek transform moves the lip
  region near the seam with the lobes (proof sketch in the D-B2-1 reasoning: lobe apex and lips sit at similar x), so
  "past the lips" in depth is out of reach with these 17 bones; the lobes do stand outside the lip outline in the front view.
- Inhale U pad thickness 0.66 (the upper lip flattens as the cheeks pull forward).
- Muzzle crest x 5.05 stands 0.65 cm outside the collision hull's +X extent (4.40); hull left unchanged (Phase C imports it).

#### My read vs the concept (inferred from the sheets; the maintainer's eye decides)
- Neutral: closest of the three. Four raised lips, dark tapered slits, a pinched dark centre, a proud muzzle in profile.
  Still differs: the arms are long, straight and even (the sheet's are shorter, slightly curved, widest at the centre);
  the pads read as ridges along the slits more than four separate pillows; the muzzle carries saw-tooth facet noise
  below the lower lip where the sheet has big calm facets.
- Inhale: purse, closed pucker and lateral bulge are real in numbers, but it does NOT read like sheet 04: the sheet has
  two distinct spheres with a crease separating each from the bulb and the pucker; ours is one wide smooth mass with the
  full-length X across it. The biggest remaining gap.
- Scream: teeth seated at the rims, plum cavity with depth, upper lip a thick band. Still differs: outline is a
  trapezoid (wide top, narrow V bottom) not the sheet's rounded oval; side rims are flat squashed bands; the face juts
  forward in profile; the gape is ~1.3x the sheet's relative to the bulb (driven by the 0.62-0.68 target).
- The claim I'd most expect to be wrong: that the inhale reads as "lobes" at all at hand distance (`fp_sheet` inhale
  shows a wide bulb, not two cheeks).

#### Next (B2.1 if the maintainer wants another pass before B3)
1. Inhale: localise the lobe weight (R0 ~1.0, R1 ~2.2) with a scale-up about its own centre on X/Z (pivot y stays 0),
   so each lobe becomes a sphere with a visible crease - must re-check scream monotonicity (fold risk).
2. Scream lower corners: give the side pad's lower half its own loop split from the lower lip at s < 0.6 (topology), then
   re-try opening the lower arms.
3. Neutral: shorter, curved arms (`X_TIP` 2.0, bow the arms), fewer loops (6) for calmer facets.
Then B3 (animate -> export -> round trip -> Phase C reimport).

## Phase B2b - mouth, second round (brief: `PHASE_B2b_BRIEF.md`)

### Phase B2b executor report (Opus, 2026-11-06) - DONE, awaiting the maintainer's mouth review (gate: STOP before B3)

Not run (gate): `animate_screaming_turnip.py`, `export_screaming_turnip.py`, full `validate_roundtrip.py`. Nothing under
`export/` or `export/anims/` written except the single test clip `export/validation/ScreamingTurnip_R01_ShapeKeyTest_Mars_ANIM.fbx`.
No git, no Unreal. Writes: `scripts/` (build, render, side-by-side, audit, validate, new `shapekey_test_screaming_turnip.py`),
`source/ScreamingTurnip_R01.blend` (rebuilt, no clip actions - same as after B2), `source/ScreamingTurnip_R01_phaseB2.blend`
(byte copy of the B2 blend taken before the first B2b rebuild), `review/phaseB2b/`, this section. **confirmed**.

**Incident (fixed):** my first B2b build still had `REVIEW = review/phaseB2` and overwrote `review/phaseB2/measurements.json`
and `pose_report.json`. Restored by re-running the untouched B2 builder (scratch copy) into a scratch folder and copying the
two files back; its `B2 scream` line is identical to the one in `review/phaseB2/build_log.txt`, and the restored
measurements show 2572 tris / MouthCue (4.686, 0, 6.4) as recorded above. **confirmed** (diff + readback). Every later run
writes `review/phaseB2b/`.

#### Rerun (from this folder)
```bash
B="C:/Program Files/Blender Foundation/Blender 5.2/blender.exe"
"$B" -b --factory-startup --python scripts/build_screaming_turnip.py      # -> review/phaseB2b/{measurements,pose_report}.json, build_log; saves blend (~5 s)
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python scripts/render_screaming_turnip.py -- \
    --poses neutral,inhale,scream,recover,impact_squash --planted --compare --fp --mouth --res 400 --tag r15_final
python scripts/sidebyside_screaming_turnip.py r15_final                    # -> review/phaseB2b/iterations/r15_final_mouth_sidebyside.png
# shape-key route proof (writes ONLY the test clip under export/validation/ + review/phaseB2b/shapekey_*.json)
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python scripts/shapekey_test_screaming_turnip.py
"$B" -b --factory-startup --python scripts/validate_roundtrip.py -- --shapekey-test
```
Final chain on the final code: build exit 0 TURNIP_OK (`review/phaseB2b/build_log.txt`), render exit 0 TURNIP_OK
(`render_log.txt`), side-by-side TURNIP_OK, shape-key export TURNIP_OK (`shapekey_export_log.txt`), shape-key round trip
TURNIP_OK (`shapekey_roundtrip_log.txt`, `shapekey_roundtrip.json`). **confirmed**.

**Look at:** `review/phaseB2b/iterations/r15_final_mouth_sidebyside.png`, then `r15_final_poses_overview.png`,
`r15_final_lighting_compare.png`, `r15_final_fp_sheet.png`. Rounds: `r00`..`r14_mouth_sidebyside.png`.

#### What changed (decisions 1-5)
- **D1 weights** (`lip_jaw`, `field_cheeks`, the patch-loop weight line in `build_bulb`): patch loops 0-4, the closure line
  and the pocket carry body / jaw only (jaw = smooth((-dz + 0.35) / 0.7) about the seam height); the cheek weight
  (`cheek_radial`) ramps in over loops 5-6 (`W.cheek_ramp` 2) while the jaw hands over to `jaw_field`; grid = lobe + jaw
  field. The matched-C/F scheme, the side-pad wedge and `edge_weights` are gone; `jx` removed from `PKEYS` (replaced by
  `k_inhale`, `k_scream`). Inhale cheeks: scale 1.3 about their own head + local translation (1.6, 1.25, 0) (no rotation,
  D-A1). The local translation is in body space, so after the inhale body squash (0.92 / 0.88) the cheek head moves
  +1.47 forward / +1.10 outward in the world - the brief's ">= 1.5 / >= 1.2" holds for the keyed values, not the world
  offset (say if you want 1.65 / 1.4 keyed). **confirmed** (pose_report, `lobe_centre_l`).
- **D2 shape keys** (`SK`, `add_shape_key`, `inhale_targets`, `scream_targets`): two relative keys `Inhale`, `Scream`
  authored in POSED space at their full pose: delta_rest = A_v^-1 (T - P0) with A_v / P0 the vertex's linear-blend skin
  matrix / bone-only position (morphs apply before skinning in Blender and Unreal alike). The builder checks the skin
  model against Blender (err <= 4e-6 cm) and that each key lands on its targets (err <= 4e-6 cm). `apply_params` sets the
  key values from `k_inhale` / `k_scream`, so pose specs carry `"sk": {"Inhale": 1.0}` and animate's splined vectors carry
  them. `turnip_audit.ue_composition_deviation` now skins the shape-mixed rest (ue_dev 0.00000 in all poses).
  - `Inhale`: the face = the body-posed bulb (the cheek bones' displacement replaced by the key) soft-UNION two spheres
    (centre = posed cheek head + (-0.05, -0.30, -0.24), r 2.75), taken along rays from an origin inside the bulb (star-
    shaped, cannot fold); lip loops 0-2 + closure + pocket + teeth purse 0.97 in (y, z) about the mouth centre, loops 3-4
    fade the purse and join the union (the crease wall). 1090 vertices moved.
  - `Scream`: lip loop 0 = an ellipse 0.64 x neutral bulb width wide, 1.10x tall, centred on the body-posed seam centre;
    loops 1-5 a rolled rim (offset, height along the posed shell normal: (0.22, 0.72) (0.50, 0.90) (0.80, 0.74)
    (1.02, 0.38) (1.18, 0.02), offsets x0.82 at the sides); loops 6-11 blend onto the bone-posed patch boundary over the
    posed shell; closure line rolled 0.42 behind the lip edge; gum band + pocket as shrinking ellipses 0.70..3.05 behind the
    lip edge, back 3.55; teeth placed rigidly on the first gum ring (rows spread x1.3, length x1.7, width x1.3, axis toward
    the opening centre tilted forward). Spokes are evenly spaced around the ellipse, so the old glued lower corners are
    gone. 1101 vertices moved.
- **D3 neutral X**: `X_TIP` (2.25, 1.05) -> (1.95, 1.0) (tip span 4.23 cm = 0.45 of the bulb width); arms bowed 0.14 cm
  toward the side wedge (`arm_curve`); U / L lip edges hug the arm (groove 0.08 -> 0.03); the side pads are arrowheads
  (`X_S_APEX` 0.75: their edges run straight from an apex 0.75 cm off-centre to the tips, each lip-edge vertex placed
  across the arm from its closure point) so the dark wedge opens left / right of a pinched centre (sheet 01); pillow pads
  (`muzzle_h`: the rise starts AT the lip edge and rounds over 0.70 -> 0.40 cm, side pads rise from their own edges);
  patch quads split along the flattest diagonal (`flat_split`) - removed the saw-tooth below the lower lip.
- **D4 scream outline**: see `Scream`; `scream.bw` 0.90 -> 1.0 (room for the rim inside the bulb; sheet 04's scream bulb is
  not narrower than neutral) - say if 0.90 must stay.
- **Topology**: patch |phi| <= 66 / z 3.8..8.85 / 44 spokes / 10 loops -> |phi| <= 92 / z 2.5..10.05 / 60 spokes /
  13 loops (`LOOP_F` 0 .045 .10 .17 .26 .33 .41 .49 .58 .68 .79 .90 1): the scream rim needs the room, the lobes need the
  outer density. 3188 tris (B2 2572).
- **D5 hull**: lip crest x 5.061 stood 0.661 outside the hull's +X 4.40 -> the hull's front half widened to x 5.061 (still
  40 tris). Phase C re-imports it in B3. **confirmed** (`HULL_FRONT` line, `collision_hull`).
- Pocket cavity-bake floor 0.70 on lip / gum / cavity faces (baked closed, seen open) - lighter plum, gum band visible.

#### Look-and-fix rounds (`review/phaseB2b/iterations/rNN_mouth_sidebyside.png`; one fix per round)
| round | fix | what the sheet showed after it |
|---|---|---|
| r00 | D1 weights + D2 keys + D3 short bowed X + bigger patch (first build) | scream already an oval rolled rim with seated teeth; neutral X reads as two crescents (side pads vanished); inhale lobes flat cut slabs |
| r01 | side pads become arrowheads, U/L groove 0.08 | neutral reads as an X with dark wedges (sheet 01); 24 hidden lip folds found later |
| r02 | inhale: every masked vertex onto the sphere | round lobes but placed like ears; 146 shell self-folds |
| r03 | inhale: union along normals | folds 4, but wide "wings" (the bone bulge pokes out) |
| r04 | inhale: union along rays from an origin in the bulb | folds 14; lobes still lateral, flat diamond between |
| r05 | inhale: base = body-only pose (key replaces the cheek-bone bulge) + union | 0 folds; clean spheres, still lateral |
| r06 | sphere centre inward / forward | small change; inner lobe facets coarse |
| r07 | 13 loops (denser outside the lips) | rounder lobes; found neutral `mouth_self` 24 |
| r08 | S-pad inside test with tolerance, lip edge across the arm from its closure, bow 0.20 -> 0.14 | `mouth_self` 0 in every pose; X arms smooth |
| r09 | inhale: purse 0.97 (brief 10-15%), sphere r 2.75 covering the bulb side | lobes form the silhouette like sheet 04, gap to the pucker |
| r10 | inhale: lip loops 3-4 join the union | **lobes close onto the pucker** - the best inhale |
| r11 | scream fangs x1.7 / x1.3, rows spread x1.3 | scream reads like sheet 04 |
| r12 | flattest-diagonal quad split | saw-tooth below the lower lip gone; calmer face |
| r13 | soft-max union (0.30) | **null round** - the narrow crease spike at the upper X tips unchanged; kept (harmless) |
| r14 | pocket bake floor 0.70 | cavity / gum lighter plum (subtle) |
| r15_final | D5 hull widening (no look change) + final pose / lighting / fp sheets | = r14 look |

#### Measured (`review/phaseB2b/pose_report.json` `mouth_b2` / `gape` / `intersections`, `measurements.json`)  **confirmed**
| quantity | target | neutral | inhale | scream |
|---|---|---:|---:|---:|
| X tip span y / bulb width | ~0.45 | 4.23 cm / 0.453 | 3.61 cm | - |
| muzzle proud >= 0.25, w x h / max protrusion | - | 5.40 x 3.57 / 1.04 | - | - |
| pad thickness U / L / S (crest x - closure x) | pillow | 1.57 / 1.69 / 1.56 | 1.44 / 1.55 / 1.43 | (n/a: rim) |
| crease depth at mid-arm, min over 4 arms | >= 0.5 | **0.85** | 0.77 | - |
| centre pinch: floor s .5 - centre / below the pad crests | >= 0.4 | **0.32** / 1.05 | 0.29 / 0.97 | - |
| closure gap / centre aperture | <= 0.15 | 0.014 / 0.000 | 0.011 / 0.000 | open |
| purse: tip span y / z vs neutral | 0.85-0.90 | 1 / 1 | **0.854 / 0.892** | - |
| lobe front x - lip crest x | >= +0.5 | -1.70 | **+0.71** (front 5.36, crest 4.66) | - |
| lobe apex vertex forward / outward | (decision 1) | 0 / 0 | 1.91 / 1.58 | - |
| bulb width at cheek height / neutral | - | 1.00 | 1.381 | 0.963 |
| gape ellipse: side-lip separation (/ neutral bulb w) x vertical | 0.62-0.68, ~1.1x | - | - | **5.98 (0.640) x 6.70 (1.12x)** |
| rim, lip edge -> outer crease (front), min / mean | >= 0.8 | 1.18 / 1.64 | 1.08 / 2.29 | **0.97 / 1.10** (U 1.13, L 1.13, S 0.97) |
| cavity depth | >= 3 | 4.16 | 3.82 | 3.64 |
| mouth self / teeth vs mouth / teeth vs pad | 0 | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 0 / 0 |
| mouth vs shell / shell self (lower corners incl.) | 0 | 0 / 0 | 0 / 0 | **0 / 0** (B2: 56 / 27) |

recover and impact_squash: every intersection 0, gap <= 0.010. ue_dev 0.00000 cm and root deviation 0 in all five poses.
Mesh: 3188 tris / 1624 verts (Skin 2090, Leaf 310, Mouth 660, Teeth 128), 15 closed islands, 0 defects, max 3 influences,
normalised, none on root; 17 bones exact, root identity, non-leaf rest rotations 0; slots Skin, Leaf, Mouth, Teeth.
Neutral height 16.000; bulb 9.90 x 9.338 x 7.944 (Phase B 9.90 x 9.191 x 8.021: +0.15 / -0.08, inside +-0.3).
Shape keys: `Basis`, `Inhale` (1090 verts, max rest delta 2.27 cm), `Scream` (1101 verts, 3.53 cm).
Sockets unchanged except **MouthCue x 4.686 -> 4.136** (the centre lip-edge max x: the side pads' apex now sits on the
crease floor); `measurements.json` updated, the Phase B manifest under `export/` stays stale until B3.

#### Shape-key route proof (decision 2)  **confirmed**
- Test clip: `Scream` keyed 0 (f0) -> 1 (f5) -> 0 (f10), linear, bones at rest every frame, exported with the Phase B
  clip recipe EXCEPT `use_triangles=False`; re-imported in a fresh scene (`validate_roundtrip.py --shapekey-test`):
  keys `Basis, Inhale, Scream` come back by name; actions `Armature|Scene` (bones) + `Key|Scene` (2 curves:
  `key_blocks["Inhale"].value`, `key_blocks["Scream"].value`); Scream value per frame 0, .2, .4, .6, .8, **1.0 at frame 5**,
  .8 ... 0 (max err 0.0); evaluated (skinned + morphed) vertices at frames 0 / 5 / 10 within 0.000008 cm of the authored
  mesh. `review/phaseB2b/shapekey_roundtrip.json`.
- **Exporter fact (load-bearing for B3):** with the verbatim recipe (`use_triangles=True`) the exporter writes the mesh from
  a temporary converted copy whose Key is not animated, so every baked shape-key value is 0.0: the BlendShapeChannel and
  `DeformPercent` curves are in the file, all zero; the re-import reads 0.0 at frame 5 and the peak mesh is off by 3.53 cm
  (`shapekey_roundtrip_verbatim.json`, `shapekey_export_verbatim_log.txt`, `shapekey_roundtrip_verbatim_log.txt`). The
  copy explanation is inferred from the exporter's behaviour (only the flag differs between the failing and passing runs).
  Our mesh is already all triangles, so `use_triangles=False` writes the same polygons (vertex error 0.000008 cm); the test
  script refuses to export if any polygon is not a triangle. Other facts: Blender writes each relative key as an FBX
  BlendShape + BlendShapeChannel (deform percent = value x 100); `bake_anim` samples every key every frame (both keys get a
  curve though only one is animated); Blender re-imports them as a second action on the Key (`Key|Scene`).
- **B3 must:** (1) export the SK and clips with `use_triangles=False` (keep the all-triangles assert); (2) key the shape
  values in animate (the PKEY vectors already carry `k_inhale` / `k_scream`; `key_pose` keys bones only); (3) let the
  round-trip validator accept two actions per clip (armature + Key) and check the key value at the peak frame.
- **Phase C must read back (route inferred, not run):** import the SK with `import_morph_targets=True`; on the SK the morph
  target names `Inhale`, `Scream`; on each AnimSequence `get_sequence_info` curve names `Inhale` / `Scream` (morph curves)
  with the peak value 1.0; single-node `PlayAnimation` drives them (verify in the review room: the gape opens). Risk: with
  `FBXNIM_IMPORT_NORMALS` Unreal may recompute morph normals - check the scream rim shading in engine.

#### Misses / deviations (the maintainer's call)
- DEV-B2b-a neutral centre pinch 0.32 < 0.4 by the B2 metric (floor at mid-arm minus centre); the centre sits 1.05 below
  the pad crests. Knob: `MUZZLE.pinch` 0.42 (or `pr` 0.9).
- DEV-B2b-b at full inhale the key REPLACES the cheek bones' displacement (base = body-only pose); the bones still carry
  the lobes in partial frames. Decision 1's bones do the gross motion; the key owns the final sphere.
- DEV-B2b-c `scream.bw` 0.90 -> 1.0; patch enlarged to the whole front hemisphere (60 x 13); 3188 tris.
- DEV-B2b-d export recipe needs `use_triangles=False` for any FBX carrying shape keys (above).
- The B2 per-pad "pad thickness" metric is meaningless on the scream rim (reported, not gated).

#### My read vs the concept (inferred from the sheets; the maintainer's eye decides)
- Neutral (closest): four pads with a pinched centre and dark side wedges, arms short and bowed - reads like sheet 01's X.
  Still differs: the side view is a beak (pads 1.0 cm proud; sheet 01 RIGHT barely shows the mouth); the crease walls are
  greyish where the sheet's are warm shadow; the face still has more, smaller facets than the sheet.
- Inhale: two big spheres closing onto a pinched X with a chin bulge below - the structure of sheet 04 INHALE. Still
  differs: the X stays full size (the sheet's pucker is a small pinched knot); a narrow sharp crease runs up from each upper
  X tip (r13 didn't soften it); the lobes read whiter than the sheet's warm ivory.
- Scream: oval rolled ivory rim, plum gum band, fangs seated top and bottom, deep pocket - reads like sheet 04 SCREAM PEAK.
  Still differs: the opening is a near-circle (the sheet is a slightly squarer oval, wider at the top); the cavity is darker
  and flatter than the sheet's lit red pocket; in profile the opening is a large notch because the rim reaches near the
  silhouette (0.64 of the neutral width + a 1 cm rim on a 9.3 cm bulb) - the brief's 0.62-0.68 forces it.
- The claim I'd most expect to be wrong: that Unreal plays the morph targets identically (morph normals / import options are
  Phase C's to prove; only the Blender round trip is proven).

## Audit of Phase C (Fable, 2026-11-06) - ACCEPTED

Checked: 15 clip .uassets + Meshes/Materials/Review/Validation folders on disk; `export/unreal_readback_final.json`
`reimport.diff_vs_readback` every list empty; `captures/UE_review_hand_mouth_closeup.png` and `_room_from_playerstart.png`
show the Phase B mesh with its faceting and stepped colour in engine. **confirmed**. Non-uniform bone scale keys import
exactly (Inhale f30 cheek (1.04, 1.40, 1.30)), so the D-A1 rig contract holds in Unreal. Side effect kept: the CkJolt
on-save cook wrote `Content/CkJoltData/ArtCandidates/ScreamingTurnip/R01/Review/` (PIE in the review map needs it).
Owed: the cold-reload stage on the next editor restart; `reimport` + `readback` after Phase B3 re-exports the
reworked mouth; the asset swap in `constants_screaming_turnip_assets` (handed to the Phase E executor with the paths).

## Audit of Phase B2 (Fable, 2026-11-06) - NOT ACCEPTED; second round launched (brief: `PHASE_B2b_BRIEF.md`)

Looked at `review/phaseB2/iterations/r12_final_mouth_sidebyside.png` and `r12_final_poses_overview.png`. Neutral close
(raised lips, deep creases, pinch, profile bump) but X arms ~90% of the bulb width and straight, pads read as ridges,
facet noise under the lower lip. Inhale: one wide wrinkled mass, no spheres - cause is the weighting (lips given cheek
weight to keep the pucker shut, so the whole face moves), not the rig. Scream: V-bottom trapezoid, flat side rims,
56/27 lower-corner overlaps, gape ~1.3x the concept's. Decisions for B2b: lips to body/jaw only and lobes to cheeks
only (cheeks translate forward); shape keys authorised (`Inhale`, `Scream`, optional `Pucker`) with the FBX round
trip of a keyed shape key proven first and the Unreal morph/curve readback named for Phase C; short curved pillowed
X; the gape as a rounded ellipse of the lip loop with a rolled rim. Gate unchanged: no production export/animate.

## Audit of Phase E (Fable, 2026-11-06) - ACCEPTED

Read: `Resolve_GripPoints` / `DoGet_VisualMeshSockets` / `DoConfigure_BodySpec` in the WorldItem base, `Make_Hold` in
`Mars_FPHands.as`, the `GripPoints` `Validate` mixin, the turnip entity script's hook use; gate summaries re-read from
`Saved/Logs/Test-TurnipE-*.stdout.txt` (FPHands 34/34, HeldView 2/2, TPBody 4/4, WorldItem 25/25, HeldItem 6/6,
ScreamingTurnip 8/8, Forage 9/9, Searing 39/39, Interactable 14/14, GripPoint 5/5; Station 74/76). **confirmed**.
- E-DEV-1 accepted: the hold resolves through the WorldItem script class's `Resolve_GripPoints` (CDO) because a
  transient visual is not constructed when `Make_Hold` runs inside `OnHeldItemChanged`. One resolution function, two
  projections (nodes for the reach, SocketGrips for the hold). Constraint recorded on the hook: no instance state.
- E-DEV-2 accepted: the reach now takes the twisted sockets like the hold (the old reach/hold disagreement was a bug);
  PIE must confirm the cleaver/tenderizer reach-in.
- E-DEV-3 verified equivalent: `Make_BoundsFit` = mesh bounds x MeshScale, the same inputs `Measure_Faces` fed to
  `Measure_BoxFaces`.
- Station reds: `CkTests.UnitTests.CkCrowd.StationaryMarkup.WindowedSpeedThreshold` red alone - a C++ unit test
  unreachable from AngelScript; prime suspect the sibling session's dirty CkTests/CkFoundation work (not A/B-stashed;
  the submodules are not ours to touch). `Mars_AutoTest_FryStation_TheOperatorsKeysDriveTheSkimmer` green alone and
  8/8 in its group -> flake. Neither added to knownReds.
- Asset swap landed (proxy hull at scale 1, R01 beds, planted offset -9.6, HeldOffset (14, 0, -12) unverified in PIE).

## Phase F - PIE verification of the vertical slice (brief: `PHASE_F_BRIEF.md`)

Status: EXECUTED 2026-11-06 (Opus), one PIE session (`run-01`, 390 s of game time) in
`/Game/ArtCandidates/ScreamingTurnip/R01/Review/ScreamingTurnip_R01_Review_MAP`. The previous level (the CellarBat review map)
was restored, with 0 dirty packages before and after. Nothing was saved and no git command ran. The editor window was not
throttled: of 14712 sampled frames the median was about 0.025 s, and the 38 frames at or above 0.1 s (max 0.40 s) were each a
`run_python` call blocking the game thread. **confirmed** (run.json `max_delta`, the monitor's delta list).

### Files
- NEW `Script/Editor/Mars_ScreamingTurnipAcceptance.as` (`#if EDITOR`):
  - `Turnips(pawn)`: per turnip, placement / phase / seq / clock / warning / next warning / last commit / support / mount /
    settled / speed / sleep / root location and up vector, plus the `TAG_MarsWorldItem` count.
  - `Bed(bedScript)`: charges / released / exhausted / target enabled / focused.
  - `Watch(pawn)`: binds `ck::Trace` lines `[TurnipReview] OnScreamCommitted|phase|placement ...` to every turnip.
  - The first save had an f-string nesting error, so hot reload kept the old code (Mars.log 08.14.11). The fixed file compiled at
    08.14.17. Nothing else in Script/ changed.
- NEW `Tools/LevelDesign/screaming_turnip_r01_review/screaming_turnip_pie_ue.py` (driver):
  - Functions: `begin`, `note`, `screenshot`, `key`, `key_after`, `aim_at`, `walk_to`, `shoot_at_phase`,
    `throw_during_inhale`, `chase_view` / `mouth_view` / `chase_back`.
  - A per-tick monitor records every placement / phase / seq / mount / playing-clip change with the game time.
  - The clip readout is `SkeletalMeshComponent.get_anim_instance().get_animation_asset()` + `get_position()`; Python has no
    `get_single_node_instance`.
  - Third-person views borrow the PIE copy of `Display_HandHeight_SK` (mesh hidden) as the view target, because Python cannot
    spawn into the PIE world. The editor map is untouched.
- Evidence: `Tools/LevelDesign/screaming_turnip_r01_review/captures/pie/run-01/`. `run.json` holds `events` (the note rows) and
  `changes` (every monitored change, key edge and shot), next to the PNGs and the `sheet_*.png` / `crop_*.png` crops. The Mars.log
  `[TurnipReview]` lines run from 08.16.26 to 08.22.12.
- Input:
  - Use and Primary are both LMB (`Mars_Gameplay_InputProfile.as:178-180`); the brief's "E" is LMB in this project.
  - Throw = Drop (R), held past `ThrowHoldSeconds` 0.35 and then released (`Mars_PlayerCharacter_Hfsm_Inventory.as:290-400`).
  - Stow / unstow = the Slot keys `Two` / `One`.
  - Every key edge lands on a later tick than the call that scheduled it (the playtest.py `tap()` pattern).

### Step table (game seconds from `begin`; clocks are the turnip kernel's own)
| step | what was done | measured | verdict |
|---|---|---|---|
| F1 | walked to (-98, 0) (from the start, 250 cm away, the bed is at the trace limit) and aimed at the bed | bed 13 `focused=true`; prompt "Pull Screaming Turnip" on screen (`F1_prompt_bed1.png`) | PASS **confirmed** |
| F2 | LMB down 35.210, up 35.527 (0.317 s) | SRC_Tug 35.275, SRC_Cancel 35.550. `world_items=0`, charges 1, released 0, target enabled | PASS **confirmed**; finding P-3 (Cancel never returns to SRC_Idle) |
| F3 | LMB down 43.112, up 44.127 | SRC_Tug 43.133; yield entity at 43.824 (0.712 s after the press), `world_items=1`. Bed `charges=0 released=1 exhausted=true`, target `Disable` (Exhausted); planted SK hidden, empty bed shown (`F3_after_harvest.png`). The root hops to (24.7, -0.9, 6.6), plays AirborneLeafTrail then QuietIdle while rolling, is LooseSettled at 45.186 (1.36 s after spawn), Asleep | PASS **confirmed**; finding P-2 (lands 25 cm out, mouth into the floor) |
| F4 | waited while it lay settled (production Vocal, no preset) | commits at clock 2.891 / 12.411 / 21.912 / 31.413 / 40.935; start-to-start 9.520 / 9.501 / 9.500 / 9.523; settle to first commit 1.529 s. One `OnScreamCommitted` per scream (Mars.log seq 1..11), same root position X=24.660 Y=-0.917 Z=6.633 every time, up (0.80, 0.41, -0.44) unchanged. Clips follow the phases: Anticipate, Inhale, Scream, Recover, RecoveryIdle, Anticipate (`changes`) | PASS **confirmed** (T05 timing; the pose is kept) |
| F5 | aimed, LMB tap 144.945 - 145.247 (during RecoveryIdle, seq 11) | mount Held at 145.312 (the kernel still read LooseSettled that frame), Transfer 145.347, Held 145.616 with phase RecoveryIdle kept. Hotbar slot1 = the turnip; gloves on it (`F6_held_recoveryidle.png`, `sheet_F6_held.png`) | PASS **confirmed**; finding P-4 (placement lags the mount by one frame) |
| F6 | held it | held commits at clock 107.552 / 117.076 / 126.577 / 136.097 (intervals 9.524 / 9.501 / 9.521; one frame ~0.025). 98.028 to 107.552 = 9.524 across the pickup, so the cooldown was kept | PASS **confirmed** |
| F7 | `throw_during_inhale`: R down once next_warning <= 0.45, up at Inhale clip t 0.313 (warning 0.613, 226.687) | mount World 226.721 (the kernel read Held / Inhale that frame); Loose + Dormant + AirborneLeafTrail 226.754; seq 19 unchanged, no commit. In flight the bounces flip AirborneLeafTrail and QuietIdle. It hits the east wall and is LooseSettled at 228.503 at (595.7, 7.1, -1.7). Fresh warning: Anticipate 228.503, Inhale 228.807, Scream 230.018 (1.515 s, not resumed from 0.613) | PASS **confirmed** ("within a frame": Loose lands one tick after the mount flip, P-4) |
| F8 | picked it up again; stowed it (`Two`) in Recover, 1.06 s after the commit at 277.152; waited 3.0 s; unstowed it (`One`) | Stow: Transfer 322.241, Protected 322.535 (Dormant, QuietIdle), silent. Unstow: Transfer 325.255, Held 325.552 in RecoveryIdle. Anticipate at clock 285.174 = commit + 8.022; Scream 286.677 (warning 1.503); interval 9.525. An earlier 17 s stow (290.46 - 307.44, cooldown already expired) produced no commit and a fresh 1.511 s warning on unstow | PASS **confirmed**; finding P-5 (the stowed root stands on the floor behind the chef) |
| F9 | walked to (450, -340), dropped the first root (R tap), harvested bed 15 | two roots on the floor, `world_items=2`. The second root (424) committed at clock 2.86 / 12.37 / 21.90 (seq 1-3) while the first (329) ran seq 31-34 at clock 305.7 - 334.2: positions and sequences independent. The second root landed at the SAME bed-relative pose as the first ((+24.66, -0.92, 6.63), up (0.80, 0.41, -0.44)) | PASS **confirmed** (T17) |
| F10 | `stop_pie` (08.22.13) | After BeginTearingDown: 0 `[TurnipReview]` and 0 `[ScreamingTurnip]` lines, so no stale callback. Two `Request_RemoveItem ... World teardown is in progress` Display lines for the two WorldItemHolder inventories (benign, inferred). No audio exists in v1, so nothing can loop. Across the whole PIE window: 0 `[ScreamingTurnip]` warnings or errors, 0 `Ensure condition failed`. The HUD's "29 Ensures" is the editor world's `CkVoxelNavVolume_Processor.cpp:533 [BackendIsValid]` aggregate (`[PIE-ID -2]`, first seen 02:45 today, before this phase) | PASS **confirmed** for the turnip; the voxel-nav ensure is unrelated (**inferred** from the PIE-ID and timing) |

### Visual answers (from the captures named; judged on the Phase B mesh, mouth fidelity out of scope)
- **Does the inhale read as a warning at hand distance? NO in first person.** **confirmed** (captures + forward vector).
  - The held root faces AWAY from the player: presentation forward (1.0, 0.0, -0.09) == view forward (`F5-held` row).
  - The holder sees its back. The crown leaves lift on Anticipate, the bulb widens a little on Inhale and stretches tall on
    Scream (`sheet_F6_held.png`). That reads as "something is happening", not as the cheek-puff warning.
  - From the front (third person, `sheet_F6_held_front.png`), the X pucker, the inhale cheeks and the scream gape with teeth
    read clearly at chest height.
  - Settled roots in this run landed mouth-down (`sheet_F4b_settled_mouth.png`: base and taproot toward the camera, forward
    z -0.9) or mouth into a wall (`sheet_F7_settled2.png`). The settled warning was readable only by silhouette (widen /
    stretch). **confirmed**.
- **Does the RecoveryIdle -> Anticipate hard cut pop (B-2)? Not judged.** The leaves go from drooped (RecoveryIdle) to raised by
  the first Anticipate capture (clip t 0.18; `F6_held_anticipate`, `F4_settled_anticipate`). Telling a pop from a jolt needs a
  moving view: the screenshots arrive at about 2 per real-time second and cannot show one frame. **inferred** (the snap exists
  numerically, Phase C 42.5 deg; not watched).
- **Gloves: plausible as a two-handed cradle.** Two gloves close on the lower flanks from both sides, palms in. The root sits low
  between them, about half hidden, centred on screen (`crop_F6_held_recoveryidle.png`). The gloves are large next to the 16 cm
  root and cover the lower bulb. **confirmed** (looked at); "plausible" is my judgement.
- **Cleaver after Phase E: NOT CHECKED.** No cleaver review preset exists in the review map and I placed none.
- **Planted root at the soil line: yes in the numbers, seen only at a distance.** The planted SK sits at z -9.6 under the bed
  origin (clip readout `at [.., .., -9.6]`, both beds). At ~120 cm it shows a pink shoulder and leaves above the soil
  (`F9_bed2_prompt_planted_before.png`). No PIE close-up was taken; Phase C's `UE_review_planted_front.png` is the close look.
  **confirmed** numerically, visually only at a distance.
- Third person, held: the root is carried at the chef's chest, offset to the chef's right, mouth outward
  (`sheet_F6_held_front.png`).

### Findings and proposed fixes (not applied: kernel / item / bed / FPHands edits are outside this phase)
- **P-1 (high) The held root faces away from the holder.**
  - Measured: forward (1.0, 0, -0.09) == the view forward. The warning is the design bet for the holder.
  - Proposed change in `Script/Items/Mars_Item_ScreamingTurnip.as`: `Presentation.Mounting.HeldOffset` =
    `FTransform(FRotator(0, 180, 0), FVector(14, 0, -12))`.
  - Swap the grip points in the same change: `k_GripLocation_R` -> (0, -3.94, 4.0), `_L` -> (0, 3.94, 4.0). SocketGrips =
    points x HeldOffset (Phase E), so a 180 yaw alone would put the right glove on the left flank.
  - Maintainer's call: facing outward is what other players see (third person reads well); facing the holder makes the warning
    readable in first person. I recommend facing the holder, then re-checking the third-person hold.
- **P-2 (medium) The harvest yield lands 25 cm out, mouth into the floor, every time.**
  - Measured: with `ReleaseLaunch = FVector(60, 0, 120)` (`Script/WorldObjects/Forage/Mars_ScreamingTurnipBed_EntityScript.as`),
    both beds put the root at bed + (24.66, -0.92, 6.63), up (0.80, 0.41, -0.44), forward (-0.39, -0.20, -0.90).
  - Proposed: a longer horizontal hop (e.g. (150, 0, 180)) so it lands on a clear patch.
  - Also check the launch's spin so the root lands on its side more often. Prime suspect for the forward tumble: the Forage
    launch, or the item's Throwable `AngularVelocityDeg (0, 180, 0)` (**inferred**, not read).
  - Never snap it upright (spec).
- **P-3 (low) SRC_Cancel holds its last frame forever.**
  - Measured: after the F2 cancel the bed's clip stayed `SRC_Cancel` until the next pull (35.550 -> 43.133, no SRC_Idle in
    between).
  - Proposed (bed script `OnPullFinished`): after `Play_Clip("SRC_Cancel")`, a `utils_timer` of the clip length (0.233 s) that
    plays `SRC_Idle` looping if the bed is still planted.
- **P-4 (low) Placement trails the mount by one tick.**
  - Measured: at pickup, mount Held with placement LooseSettled for one frame (145.312). At the throw, mount World with placement
    Held / phase Inhale for one frame (226.721).
  - Risk: no commit fell in those frames this run, but a throw in the last tick of an Inhale could still commit after the
    release.
  - Proposed: `UMars_Processor_ScreamingTurnip_Tick` adds `_RunAfter` on the WorldItem processor(s) that commit the mount (names
    to verify in `Script/ECS/WorldItem/`).
  - Known since the Phase D audit, which inferred it acceptable.
- **P-5 (medium) The stowed root stands upright on the floor behind the chef.**
  - Measured: Carried root at (433.6, 3.7, 7.2) with the chef at (493.5, 4.9, 77.2), a world offset of (-60, -1, -70)
    (`crop_F8_stowed_carried_3p.png`). The chef wore no backpack (`pack=false`).
  - Item settings: `Mars_Item_ScreamingTurnip.as` `CarryPoint = AttachPoint_Mars_Back`, `CarryOffset (-35, 0, -25)`.
  - Cause (**inferred**): either the Back point sits near the feet when no pack is worn, or the offset is wrong for this item.
    Compare with a whole food's carry in PIE before changing anything.
- Side effect, not mine to fix: `Config/DefaultGameplayTags.ini` was rewritten at 08.16.23, in the frame the first yield spawned
  (log: "ConstructGameplayTagTree ... after adding new tag"). The file was already dirty at the campaign start. Not staged, not
  inspected.

### Not verified
- Motion quality of any clip (stills only), so the B-2 pop and the 15 Hz shake are unjudged. Audio: none exists.
- Cleaver / tenderizer reach after Phase E (no preset).
- Acceptance cases not exercised:
  - T06: throw while screaming.
  - T07: disturbing a settled root (hysteresis).
  - T08: rapid re-grabs.
  - T14: clipping. The wall-side scream may push the stretched mesh into the wall; not inspected.
  - T16, T18.
- A close planted-root framing in PIE; neutral-light colour.
- The claim I'd most expect to be wrong: P-2's cause (spin from the launch). The landing pose is measured; the cause is a guess.

## Audit of Phase F (Fable, 2026-11-06) - ACCEPTED as the gameplay proof; five fixes -> Phase G

Looked at `captures/pie/run-01/sheet_F6_held.png`, `sheet_F6_held_front.png`, `sheet_F4b_settled_mouth.png`,
`crop_F8_stowed_carried_3p.png`. F1-F10 pass with production timings (start-to-start 9.50-9.52 s, one commit per
scream, cooldown kept across pickup and stow, throw silent one tick after the mount flip, two roots independent,
clean teardown). **confirmed** by the executor's run.json/Mars.log numbers and the captures. Brief corrections for
future drivers: Use/Primary = LMB, throw = R held > 0.35 s then released, stow/unstow = slot keys Two/One.
P-1..P-5 decided (brief `PHASE_G_BRIEF.md`): face the holder + mirrored grip points; longer hop with a yaw spin;
one-shot clip falls back to the loop; `_RunAfter` the WorldItem mount processors; carry point/offset as the Cookbook.
Design fork raised to the maintainer: at 16 cm the turnip is small in the first-person mitts; recommendation is a
~22 cm neutral height carried by Phase B3's re-export (builder parametric; kernel unaffected). Awaiting the ruling.
Not exercised: T06 throw while screaming, T07 disturb a settled root, T08 rapid re-grabs, T14 wall clipping, T16,
T18 (networking: WorldItem DoesNotReplicate - explicit prerequisite, no claim). Motion (B-2 pop, shake) still unjudged.

## Audit of Phase B2b (Fable, 2026-11-06) - ACCEPTED at the gate; sheet sent to the maintainer

Looked at `review/phaseB2b/iterations/r15_final_mouth_sidebyside.png` and `r15_final_poses_overview.png`. Neutral =
the sheet's pucker (short bowed arms, pillows, deep creases, pinch, profile bump). Inhale = two spherical cheeks
pinching the X with the chin bulge (the biggest gap, closed). Scream = rolled continuous rim, gums, seated teeth,
deep cavity, 0 corner overlaps. Remaining: opening a near-circle vs the sheet's squarer oval; cavity darker than the
sheet's red; centre pinch 0.32 vs 0.4. Shape keys `Inhale` / `Scream` accepted with DEV-13 (`use_triangles=False`,
proven by the keyed round trip) and the Unreal morph readback owed to Phase C2. Maintainer may call a third round
on the oval; B3 is launched meanwhile (its clip output is re-run if so). Size ruling (16 vs ~22 cm) still open.

## Phase B3 - clips on the B2b mouth (bones + shape keys), export, round trip, manifest (brief: `PHASE_B3_BRIEF.md`)

### Phase B3 executor report (Opus, 2026-11-06) - DONE, awaiting Fable audit; no Unreal (Phase C2 reimports)

No git, no Unreal, nothing outside this folder. Writes: `scripts/animate_screaming_turnip.py`, `export_screaming_turnip.py`,
`validate_roundtrip.py`, `render_anims_screaming_turnip.py` (extended); `source/ScreamingTurnip_R01.blend` (B2b mesh + 16 x 2
clip actions, saved by animate); `source/ScreamingTurnip_R01_phaseB2b.blend` (byte copy of the B2b blend taken before animate);
`export/` (SK, 3 statics, `expected.json`, manifest, `export_settings.json`, logs), `export/validation/Cube10_Mars_SM.fbx`,
`export/anims/` (16 clip FBX, `clips.json`, `expected_anims.json`, `roundtrip_report.json`), `review/phaseB3/`. The builder was
NOT re-run (the B2b mesh is used as built). Size ruling (16 vs ~22 cm) not applied: still open. **confirmed**.

#### Rerun (from this folder; each prints TURNIP_OK / TURNIP_FAIL and exits non-zero on failure)
```bash
B="C:/Program Files/Blender Foundation/Blender 5.2/blender.exe"
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python scripts/animate_screaming_turnip.py   # 16 clips, audit, saves blend (~15 s)
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python scripts/export_screaming_turnip.py    # FBX + expected + manifest (no save)
"$B" -b --factory-startup --python scripts/validate_roundtrip.py                                         # fresh-scene re-import of every FBX
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python scripts/render_anims_screaming_turnip.py -- [--tag rNN] [--shapekey-only]   # ~30 s
```
(To rebuild from scratch: run the B2b builder first, then the chain above - the builder wipes the clip actions.)
Final chain on the final code: animate exit 0 `TURNIP_OK (16 clips, 14 s)` (`review/phaseB3/animate_log.txt`), export exit 0
(`export/export_log.txt`), round trip exit 0 (`export/roundtrip_log.txt`, `fails: []`), renders exit 0
(`review/phaseB3/render_log.txt`, sheets tagged `r01` in `review/phaseB3/iterations/`). **confirmed**.

**Look at:** `review/phaseB3/clips/cycle_sheet.png`, `ROOT_Scream_sheet.png`, `ROOT_Recover_sheet.png`,
`ROOT_AnticipateTired_sheet.png`, `ROOT_Inhale_sheet.png`, `shapekey_sheet.png` (keys alone at rest bones: the keys are sculpted
for their full bone pose, so at rest they look wrong by design - the inhale "wings", the scream rim low - this sheet proves the
channels, the clip sheets show the look).

#### Clips (`animate_screaming_turnip.py`; `export/anims/clips.json`; `review/phaseB3/anim_report.json`)  **confirmed**
Two actions per clip: `<Clip>` on the armature (Phase B rules: every non-root bone, every frame, LINEAR; root never keyed) and
`<Clip>_Key` on the mesh Key (`key_blocks["Inhale"].value`, `key_blocks["Scream"].value`, every frame, LINEAR). Values come
from the pose vectors (`k_inhale`, `k_scream`) except Recover's Scream channel (authored table, below). Pass C plays both actions
back: action vs authored 0.0 cm / 0.0 deg / 0.0 key value in every clip.

| clip | frames | loop | seam (loops) | Inhale peak (frames) | Scream peak (frames) | isect max | bounds h x w x d |
|---|---|---|---|---|---|---|---|
| SRC_Idle | 0..60 | yes | 0 / vel 0.0003 | 0 | 0 | 0 | 16.34 x 13.58 x 11.71 |
| SRC_Grip | 0..6 | no | - | 0 | 0 | 0 | 16.43 x 13.36 x 11.30 |
| SRC_Tug | 0..15 | no | - | 0 | 0 | 0 | 17.21 x 12.45 x 10.26 |
| SRC_Release | 0..6 | no | - | 0 | 0 | 0 | 17.21 x 14.21 x 12.87 |
| SRC_Cancel | 0..7 | no | - | 0 | 0 | 0 | 17.21 x 13.36 x 11.30 |
| ROOT_QuietIdle | 0..60 | yes | 0 / 0.0009 | 0 | 0 | 0 | 16.27 x 13.49 x 11.52 |
| ROOT_Anticipate | 0..9 | no | - | 0 | 0 | 0 | 16.38 x 13.36 x 11.30 |
| **ROOT_AnticipateTired** (new) | 0..9 | no | - | 0 | 0 | 0 | 16.38 x 14.11 x 12.83 |
| ROOT_Inhale | 0..36 | no | - | **1.0 (f30..f36)** | 0 | 0 | 16.87 x 12.90 x 10.52 |
| ROOT_Scream | 0..18 | no | - | 1.0 at f0 only (-> 0 by f3) | **1.0 (f3..f18)** | 0 | 20.60 x 13.75 x 13.65 |
| ROOT_Recover | 0..30 | no | - | 0 | 1.0 at f0, **0 from f8** | 0 | 19.86 x 14.10 x 13.55 |
| ROOT_RecoveryIdle | 0..60 | yes | 0 / 0.0001 | 0 | 0 | 0 | 13.53 x 14.11 x 12.76 |
| ROOT_AirborneLeafTrail | 0..30 | yes | 0 / 0.0022 | 0 | 0 | 0 | 15.87 x 14.12 x 12.76 |
| ROOT_ImpactSquash | 0..7 | no | - | 0 | 0 | 0 | 16.00 x 14.12 x 12.80 |
| ROOT_SettleRock | 0..12 | no | - | 0 | 0 | 0 | 16.50 x 13.95 x 12.48 |
| ROOT_PlaceSettle | 0..7 | no | - | 0 | 0 | 0 | 16.00 x 13.36 x 11.30 |

Per-frame curves: Inhale 0, .007, .028 ... .453 (f10), .65 (f14), .78 (f18) ... .998 (f29), 1.0 f30..f36 (eased, monotone).
Scream clip: Inhale 1, .741, .259, 0; Scream 0, .259, .741, 1 (f0..f3), 1.0 to f18. Recover Scream: 1, .94, .82, .70, .30, .15,
.07, .02, 0 (f0..f8), 0 after; Inhale 0. Every other clip keys both at 0.0 on every frame. Every frame of every clip:
intersections 0 in every category (incl. outer-shell self and mouth-vs-shell: the B2b zero at the scream corners holds through
all of Scream and Recover - no lip/chin fold allowance used), root identity, Unreal composition deviation <= 0.00001 cm.

Chain (max bone head cm / rot deg / key value), all **0 / 0 / 0**: QuietIdle f0 -> Anticipate f0, Anticipate fN -> Inhale f0,
Inhale fN -> Scream f0, Scream fN -> Recover f0, Recover fN -> RecoveryIdle f0, **RecoveryIdle f0 -> AnticipateTired f0** (gated
<= 0.1 / 1), **AnticipateTired fN -> Inhale f0**, SRC Idle -> Grip -> Tug -> Release / Cancel -> Idle, Release fN -> QuietIdle f0.
Hard cuts (reported): QuietIdle any frame -> Anticipate f0 **0.160 cm / 4.13 deg** (as Phase B); RecoveryIdle any frame ->
AnticipateTired f0 **0.149 cm / 2.30 deg** (the breath + sway mid-loop); for comparison the old RecoveryIdle f0 -> Anticipate f0 is
still 0.652 cm / 42.5 deg (any frame 0.785 / 42.0) - so the presentation must pick AnticipateTired after the recovery phase.
Key values match at every chain joint (0 delta).

**Global envelope: 21.20 h x 14.21 w x 13.90 d cm** (min (-7.22, -7.11, -0.60), max (6.68, 7.11, 20.60)); over 22 x 14 x 13 by
0.21 w (leaf tips, as Phase B) and **0.90 d** (Phase B 0.14): the Scream rim stands to x 6.68 (Phase B 5.92) - not clipped,
reported. Planted (SRC): body -0.6, seam top z 6.80, shoulder 1.5 cm above the soil line, taproot tip -0.6.

#### Export (DEV-13)  **confirmed**
`export/ScreamingTurnip_R01_Mars_SK.fbx` (3188 tris, 17 bones, shape keys Basis / Inhale / Scream), statics
`ScreamingTurnip_R01_Collision_Mars_SM.fbx` (40 tris, widened +X 5.061), `TurnipBed_R01_Mars_SM.fbx` (224),
`TurnipBedEmpty_R01_Mars_SM.fbx` (288), `validation/Cube10_Mars_SM.fbx`, 16 x `anims/ScreamingTurnip_R01_<Clip>_Mars_ANIM.fbx`.
**DEV-13**: skeletal exports (bind + clips) use `use_triangles=False`; statics keep the Phase B recipe (`True`). The export asserts
the body is all triangles before any skeletal export. Reason + proof references in `export/export_settings.json`
`recipe_change_DEV_13` and the manifest `clip_contract.export_recipe_change`.

#### Round trip (`validate_roundtrip.py`; `export/roundtrip_report.json`, `export/anims/roundtrip_report.json`)  **confirmed**
Cube +-5.000 scale 1. SK: 17 bones exact, bind heads 0.000067 cm, rest rotations 0.0, 3188 tris, slots Skin/Leaf/Mouth/Teeth,
bounds 0.000052, `Col` BYTE_COLOR/CORNER (alpha min 0.173 mean 0.860), max 3 influences, none on root, **shape keys
['Basis', 'Inhale', 'Scream']**. Statics scale 1, 224 / 288 / 40 tris, closed, bounds <= 0.00003. Every clip: actions
`Armature|Scene` + `Key|Scene` (curves `key_blocks["Inhale"].value`, `key_blocks["Scream"].value`), nothing else; N+1 keyed
samples first..last; root 0.0 every frame; landmarks <= 0.000086 cm, skinned extremes <= 0.000053 cm every frame; loop seams 0.0;
scale keys at the peak frame err 0.0; **shape-key values every frame err 0.000000**; peaks read back = authored (Inhale 1.0 f30..f36,
Scream 1.0 f3..f18, Recover Scream 0 from f8, all other clips 0 everywhere); **evaluated mesh at the peak frames <= 0.000011 cm**
(Inhale f0 / f36, Scream f3..f18 each, QuietIdle f0, SRC_Idle f0).

#### Manifest (`export/ScreamingTurnip_R01_Manifest.json`)  **confirmed** (read back)
tris 3188 / verts 1624, 17 bones, sockets (MouthCue jaw, root-rel (4.136, 0, 6.4), jaw-rel (4.636, 0, 2.2); others as Phase B),
collision extents x -4.40..5.061, 16 clips each with `curves`, `curve_peaks`, `curve_note`, `unreal_path`;
`morph_targets: [Inhale, Scream]` + note; `clip_contract.curves`, `.export_recipe_change`, `.chain_deltas`, hard cuts naming
AnticipateTired; `unreal_paths.animation_list` + `new_in_b3` (`/Game/ArtCandidates/ScreamingTurnip/R01/Animation/ScreamingTurnip_R01_ROOT_AnticipateTired_Mars_ANIM`);
`phase_c_readback`: import the SK with `import_morph_targets=True`, clips + statics `replace_existing=True`, `FBXNIM_IMPORT_NORMALS`
with the unproven morph normals noted; assert morph targets `Inhale` / `Scream` on the SK, `get_sequence_info` curve names
`Inhale` / `Scream` on every AnimSequence with the per-clip peaks and key counts; single-node playback of ROOT_Scream in the
review room.

#### Deviations / decisions (low-blast; say if you want them changed)
- **DEV-B3-a Recover Scream ease-out is an authored table, not the spline.** The Scream key's teeth cross the lip roll for key
  values ~0.43..0.67 at every jaw angle of the deflate (3-5 tooth-vs-lip pairs; grid `review/phaseB3/recover_band_grid.txt`). The
  spline put f4 at 0.45 (4 pairs, the first animate run FAILED on it). The table jumps the band between f3 (0.70) and f4 (0.30);
  zero from f8 (0.267 s; the brief's "first 0.25 s" falls between f7 and f8). Visible on `ROOT_Recover_sheet.png` f4 as a squarish
  half-open mouth with teeth for one frame.
- **Sub-frame transients (info, not gated):** the half-frame audit (`subframe_isect_info` in anim_report) finds teeth_vs_mouth 3 at
  Scream f1.5 (keys 0.5 / 0.5) and 4 at Recover f3.5 (Scream 0.5): any continuous path from 0 to 1 crosses the band. Integer
  frames are clean; in engine, an in-between render frame may show a tooth tip through the lip for <= 33 ms. A real fix is a
  builder change (teeth path inside the Scream key, e.g. a second in-between key) - not done (mesh frozen at the B2b gate).
- Key action naming `<Clip>_Key` (the FBX re-imports it as `Key|Scene`); recorded in clips.json `export_key_action`.
- Envelope depth 13.90 (DEV-10 grows: scream rim +X 6.68).

#### Not verified
- Unreal: morph target import, curve names/values on the AnimSequences, morph normals, runtime curve -> morph binding (Phase C2).
- Motion read: only stills (contact sheets, 6 fps cycle); the 1-frame band jump at Recover f3 -> f4 and the f0 -> f3 scream snap
  are unwatched; the AnticipateTired leaf rise looks smooth on its sheet but nobody has seen it play.
- The claim I'd most expect to be wrong: that the sub-frame tooth poke is invisible in game (it is a geometric count, not a look).

## Audit of Phase B3 (Fable, 2026-11-06) - ACCEPTED

Looked at `review/phaseB3/clips/cycle_sheet.png` and `ROOT_Recover_sheet.png`. 16 clips, every frame 0
intersections, chain links 0, RecoveryIdle -> AnticipateTired cut 0.149 cm / 2.3 deg (B-2 solved on the clip side;
the presentation must pick `ROOT_AnticipateTired` after RecoveryIdle - Phase H), shape-key peaks as authored, round
trip `fails: []`, DEV-13 recorded with its proof. Envelope 21.20 x 14.21 x 13.90 (depth +0.9 from the rim; bounds
extension in C2). Noted, deferred: B3-1 Recover f4 one-frame squarish half-open (the Scream key jumps the 0.43-0.67
tooth-through-lip band); fix = an in-between key in the builder. Next: C2 reimport + morph readback (after Phase G
frees the editor), then Phase H (presentation clip map incl. AnticipateTired, final PIE on the real mouth).

## Phase G - the five PIE findings (brief: `PHASE_G_BRIEF.md`)

Status: EXECUTED 2026-11-06 (Opus). Five fixes applied, one new test, six gate patterns green, one PIE pass (`run-02`) on
the Phase B mesh still in the editor (C2 not imported yet). Nothing committed, no git command, no Content/ write by me, no
live map touched. Every claim is marked **confirmed** (evidence named) or **inferred**.

### Files
- `Script/Items/Mars_Item_ScreamingTurnip.as`
  - P-1: `k_HeldRotation` (yaw 180) applied in `HeldOffset`; the location (14, 0, -12) is kept.
  - P-1: `k_GripLocation_R` = (0, -3.94, 4.0), `_L` = (0, 3.94, 4.0); both points carry `k_GripRotation` (yaw 180).
  - P-5: `CarryOffset` removed (identity, as the Cookbook has it).
- `Script/WorldObjects/Forage/Mars_ScreamingTurnipBed_EntityScript.as`
  - P-2: `ReleaseLaunch` (120, 0, 170). A new `ReleaseSpinDeg` (0, 0, 270) is passed to `FMars_Forage_LaunchSpec`.
  - P-3: the three `Play_Clip` calls take the clip-end enum.
- `Script/Items/Presentation/Mars_ScreamingTurnipPresentationComponent.as`
  - P-3: `EMars_ScreamingTurnip_ClipEnd { Loop, HoldLastFrame, ReturnToLoop }` replaces the `Loops` bool in
    `FMars_ScreamingTurnip_PresentationClip`.
  - `Play_Clip(FMars_ScreamingTurnip_PresentationClip)`; `DoReturn_ToLoopIfPlayedThrough()` runs in the existing Tick.
- `Script/ECS/ScreamingTurnip/Mars_ScreamingTurnip_Processor_Tick.as`
  - P-4: `_RunAfter` on the WorldItem HandleRequests, Reconcile, Mount, Arrive and Launch processors.
  - The header comment states the order and what it does not cover (the tail pump).
- NEW `Script/Tests/ScreamingTurnip/Mars_AutoTest_ScreamingTurnip_AThrowOnTheLastInhaleTickDoesNotScream.as`.
- `Tools/LevelDesign/screaming_turnip_r01_review/screaming_turnip_pie_ue.py`: the Phase G helpers `bed_params`, `item_pose`
  and `view_forward` are appended. No existing function changed.
- Side effects, not authored by me:
  - The live editor regenerated `Script/Generated/Mars_EntitySpawnParams.as` (the bed's `ReleaseSpinDeg`, the new test's
    params) and `Mars_AutoTestActors.as` (the new test actor).
  - Its populator touched `Content/Mars/Maps/AutoTests_Mars_MAP.umap`, which was already dirty, as in Phases D and E.
  - **inferred** from the Phase D/E pattern and the Mars.log line `Can't find class descriptor ...
    AThrowOnTheLastInhaleTickDoesNotScream_Actor ... for saving` (08.33.45).
- Grip-point tests: none was edited. None asserts the turnip's numbers: `GripPointsGiveTheHeldSocketGrips`,
  `AGripPointItemIsReachedAsAPickup` and `GripPointsValidate` compare against the definition's own values. **confirmed** (read).

### Per fix

**P-1 face the holder - FIXED.**
- Decision I made rather than asking: the grip points are mirrored AND turned by the same yaw 180.
  - So `points x HeldOffset` (the gloves' SocketGrips) equals the Phase F hold exactly in the hand frame: palm up, index
    forward, right glove on the right. Only the root turns between the gloves.
  - Mirroring the locations alone would have turned both glove frames 180 (index toward the player). Say if you want
    location-only.
- PIE (**confirmed**, `run.json` events `F5-held`): the mouth faces the camera.
  - Looking level: held presentation forward (-1.0, 0.0, 0.02), view forward (1.0, 0.0, -0.02).
  - Looking down: (-0.57, -0.03, 0.82) against (0.57, 0.03, -0.82).
- What I saw in `sheet_G_held_fp.png` / `crop_G_held_fp_face.png` (RecoveryIdle; Inhale at clip t 0.496; Scream at t 0.053):
  - The face is toward the holder.
  - The X pucker shows in RecoveryIdle and Inhale; the scream gape with teeth is fully readable.
  - The inhale cheek puff barely differs from RecoveryIdle at this distance. That is my judgement; mouth fidelity belongs to
    Phase B2.
- Gloves: still a two-handed cradle on the lower flanks, the right glove on the right.
- Third person (`crop_F6_held_3p_front_zoom.png`):
  - The root floats at the chef's right shoulder beside the hands, the same place as in Phase F, and now shows its back to
    an onlooker.
  - Plausible as a carry, but not in the hands. That offset belongs to the third-person held view, which this phase did not
    change.

**P-2 landing - FIXED as briefed, measured.**
- How the launch works (**confirmed**, read):
  - `Mars_Forage_Processor_Requests.as:72-76` turns the linear launch into the release point's frame
    (`Pose.TransformVectorNoScale`) but passes `AngularVelocityDeg` unchanged, so the spin is in WORLD axes.
  - `Mars_WorldItem_Processor_Launch.as:56-71` applies both once the body reads Dynamic (deg -> rad).
  - The Throwable's (0, 180, 0) is read only by HeldItemUse (`Mars_HeldItemUse_Processor_Requests.as:167-172`), never by a
    Forage release.
  - So Phase F's suspect for the forward tumble was wrong. The old launch had NO spin; the tumble came from the root's own
    shape over the hop.
- The placed beds construct with the new values (**confirmed**): `bed_params()` in PIE read launch (120, 0, 170) and spin
  (0, 0, 270) on both beds, so the review map stores no stale value.
- Landing on both beds (**confirmed**, `item_pose`, `run.json` F3/F9):

| | bed 1 | bed 2 |
|---|---|---|
| root from the bed origin | (70.4, -5.8, 6.8), 70.6 cm out | (70.3, -5.9, 6.8), 70.5 cm out |
| up | (-0.62, 0.65, -0.43) | (-0.61, 0.67, -0.43) |
| forward (mouth) | (0.46, 0.75, 0.47) | (0.48, 0.74, 0.47) |
| yield after the press | 0.70 s | 0.72 s |
| LooseSettled after spawn | 1.48 s | 1.48 s |

  - Both roots lie on their side with the crown low. The mouth points sideways and 28 deg UP, not into the floor (Phase F:
    forward z -0.90).
  - Both settled Asleep; the first scream came 1.52 s after settling.
  - The two beds land identically (the launch is deterministic).
- What I saw in `crop_F9_bed2_landed_mouth_scream_zoom.png`: a side-lying root, the screaming mouth and teeth clearly visible
  from beside it.
- The root settles by physics only; no snap exists in code.
- Not tuned further: one pose seen, rolled by physics, mouth readable. "Within reach" here means 70 cm from the bed; the
  player reached it by walking 80 cm.

**P-3 one-shot back to the loop - FIXED.**
- Decision I made rather than asking: each clip carries how it ends (`EMars_ScreamingTurnip_ClipEnd`) instead of one
  component-wide fallback.
  - The bed's `SRC_Tug` (0.5 s) is shorter than the 0.7 s pull, so a blanket fallback would snap to SRC_Idle mid-pull.
  - The item's one-shots are `HoldLastFrame`, so nothing fights `Refresh_FromKernel`: the kernel's wanted clip always wins.
- The return is polled in the component's existing Tick (`IsPlaying() == false` or position >= the clip length); no timer.
- PIE (**confirmed**, `run.json` changes):
  - F2: press 16.41, release 16.81. SRC_Tug 16.81 -> SRC_Cancel 16.839 -> SRC_Idle 17.101 (0.262 s: the 0.233 s clip plus a
    frame). Bed charges 1, `world_items=0`.
  - Completed pull: SRC_Tug held at t 0.500 until the release. Then the planted component was hidden and the empty bed shown
    (bed rows `visible: false`, F3 / F9).

**P-4 scheduler edge - FIXED and proven.**
- Processor order in the PIE world (**confirmed**, `Ck.Ecs.Scheduler.ExportOrder` -> `Saved/CkEcs/SchedulerOrder.txt`):

| position | processor |
|---|---|
| 141 | `FProcessor_Inventory_DataOnly_HandleRequests` (FGroup_Gameplay) |
| 466 | HeldItemUse_HandleRequests |
| 526 | WorldItem_HandleRequests |
| 527 | WorldItem_Arrive |
| 528 | WorldItem_Launch |
| 529 | WorldItem_Reconcile |
| 530 | WorldItem_Mount |
| 533 | ScreamingTurnip_Tick |

- What that order means:
  - A throw from HeldItemUse is drained by WorldItem in the same main pass, before the kernel tick. The PendingRelease then
    reads Transfer at once.
  - The World commit itself answers the inventory transfer, which runs in the scheduler's tail pump (CkEcs `Claude.md`, pump
    policy) after the main graph. The marker-less kernel tick does not run there, so it reads World on the next frame.
  - This is documented in the processor header. **inferred** from the group order and the observed one-frame Transfer -> Loose.
- The test `AThrowOnTheLastInhaleTickDoesNotScream`:
  - Automation runs on a fixed 1/60 s step. The release is requested on the poll where the Inhale has at most one step left.
  - It asserts that the first tick after the release is Held -> Transfer, and that this tick's clock reaches the Inhale's end.
  - Then it asserts no commit through Loose and through the settle.
  - Log (`Saved/Logs/Mars_2.log` 08.46.28): released at clock 0.8785, the Inhale ends 0.8950, the tick that read the release
    ran at 0.8951.
- A/B (**confirmed**):
  - With the five WorldItem `_RunAfter` lines commented out, the same test FAILS: "the released Inhale committed nothing
    (expected 0, got 1)" (`Saved/Logs/Test-TurnipG-AB-NoRunAfter.stdout.txt`).
  - Restored, it passes (`Test-TurnipG-Edge`, `Test-TurnipG-Final-ScreamingTurnip`).
- PIE:
  - At the pickup, the placement left LooseSettled in the same sample the mount read Held (86.967 Transfer/Held). Phase F had
    a LooseSettled/Held frame here.
  - At the stow, Transfer/Carried arrived in one sample (132.767).
  - The throw was not re-driven in PIE (it is not in the brief's list).
- The first test iteration failed: the condition "remaining <= half a step" never came true, because the fixed step makes the
  remaining Inhale a whole number of steps (a diagnostic run showed it). I changed it to "<= one step" and removed the
  diagnostic logging.

**P-5 carry on the back - FIXED.**
- Cause (**confirmed**, read):
  - `Config.Inventory.BackOffset` is (-25, 0, -45) from the capsule centre (`Mars_PlayerCharacter_Assets.as:130`).
  - The food's (-35, 0, -25) is for a joint centred on its pivot. Under this root's base pivot the two summed to
    (-60, 0, -70): the floor.
  - The Cookbook uses CarryOffset identity.
- PIE (**confirmed**, F8 row):
  - Stowed to slot 2 (key Two): Transfer -> Protected.
  - The root sat at (-34.4, -6.0, 32.2) with the chef at (-9.4, -6.0, 77.2), exactly the Back point, upright, in QuietIdle.
  - It kept riding while the chef walked to bed 2 (328.2, -451.9, 32.2).
- What I saw in `crop_F8_stowed_zoom.png`: the root hangs on the chef's lower back at the belt line, off the floor.
- It reads small and low (seat height). Raising it is a CarryOffset Z of +15 to +20 if wanted.

### Gates
Toolbox test-only path beside the open editor; quiescence checked before each run. The baseline is the Phase E final count
for the same patterns (recorded above). Final = the final code, after the A/B restore (live reload 08.44.27).

| Pattern | Baseline (Phase E) | Final (`Saved/Logs/Test-TurnipG-Final-<Pattern>.stdout.txt`) |
|---|---|---|
| ScreamingTurnip | 8/8 | 9/9 (+1 new) |
| WorldItem | 25/25 | 25/25 |
| FPHands | 34/34 | 34/34 |
| HeldItem | 6/6 | 6/6 |
| Forage | 9/9 | 9/9 |
| Interactable | 14/14 | 14/14 |

No new failure; no knownReds entry involved. Iteration runs:
- `Test-TurnipG-ScreamingTurnip`: 8/9 (the new test's first condition, above).
- `Test-TurnipG-Diag`: 1/1.
- `Test-TurnipG-Edge`: 1/1.
- `Test-TurnipG-AB-NoRunAfter`: 0/1 (intended).

### PIE re-check (`captures/pie/run-02/`, review map, 08.56 - 09.00)
- The window was not throttled (**confirmed**, `run.json` max_delta and deltas).
  - 7992 sampled frames; 27 at or above 0.1 s (max 0.40 s), each one a `run_python` call.
  - The first `begin` asserted on the PIE start hitch; the next call passed at 0.0167 s.
- Previous level restored: `/Game/Mars/Maps/Sandbox_Mars_MAP`, which the editor had open after its restart at 08.31.20.
  0 dirty packages before and after. **confirmed**.
- Mars.log from PIE start to teardown (**confirmed**, grep):
  - 0 `Ensure condition failed`.
  - 0 `[ScreamingTurnip]` warnings or errors.
  - 0 turnip lines after BeginTearingDown (09.00.45).
- The `[TurnipReview]` trace lines are absent. `Watch` ran in `begin`, before any root existed, and binds only existing
  roots. The monitor's `changes` carry the sequence instead.
- Captures to look at:
  - `sheet_G_held_fp.png`, `crop_G_held_fp_face.png`
  - `crop_F6_held_3p_front_zoom.png`
  - `crop_F8_stowed_zoom.png`
  - `crop_F9_bed2_landed_mouth_scream_zoom.png`
  - `crop_F5_aim_root1.png` (pickup prompt and reach)
- `F3_landed_bed1_3p.png` is a poor framing (the borrowed camera looked past the root). Use the F9 crops for the landing.

### Incident
- The live editor's process changed between 08.31.13 and 08.31.20.
  - The old Mars.log (`Mars-backup-2026.11.06-08.31.13.log`) ends during the full reload that my bed edit triggered (the new
    `ReleaseSpinDeg` spawn-param field).
  - A new editor (`-skipcompile`) opened 7 s later.
- No crash folder was written (the newest `Saved/Crashes` entry is from 2026-10-27). It reads as a deliberate close and
  relaunch by someone else, not a crash. **inferred**; whether my reload caused it is not known.
- Everything after ran on the new editor, which compiled every later edit (no AS errors after 08.32.30).

### Not verified
- The throw path in PIE after P-4. The order is confirmed; the throw itself was not re-driven.
- Landing pose variety. Both beds land identically, so I saw one pose, not a distribution, and no launch from another bed yaw.
- How the ReturnToLoop switch looks in motion (I saw stills and the change log only). The bed's Cancel -> Idle is a hard cut.
- Third person: the held root sits beside the chef's hands at shoulder height (the existing third-person held view).
- The claim I'd most expect to be wrong: that the 08.31 editor restart was unrelated to my reload.

## Audit of Phase G (Fable, 2026-11-06) - ACCEPTED

Looked at `captures/pie/run-02/crop_G_held_fp_face.png` (mouth faces the player; pucker and gape read; inhale puff
subtle at 16 cm) and `crop_F9_bed2_landed_mouth_scream_zoom.png` (side-lying, mouth clear of the floor, screaming).
Gates re-read from `Saved/Logs/Test-TurnipG-Final-*.stdout.txt`: ScreamingTurnip 9/9, WorldItem 25/25, FPHands 34/34,
HeldItem 6/6, Forage 9/9, Interactable 14/14; the A/B log `Test-TurnipG-AB-NoRunAfter` 0/1 proves the scheduler edge.
**confirmed**. Accepted decisions: grip points carry the yaw 180 with the HeldOffset (hold identical in the hand
frame); per-clip end policy (Loop / HoldLastFrame / ReturnToLoop) instead of a blanket fallback; `ReleaseSpinDeg`
(0, 0, 270) + hop (120, 0, 170) -> lands 70 cm out on its side. Known: the World commit happens after the main graph,
so Transfer -> Loose is read one frame later (header comment); the stowed root hangs low on the back (a CarryOffset Z
of +15..+20 would raise it; left as the Cookbook's identity). Incident: the live editor was replaced at 08:31 (no crash
folder; inferred a deliberate relaunch). Next: C2 (launched), then H.

## Scope ruling 2026-11-06: size x3.0 (maintainer: "at least 2.5x / 3x bigger", "the size of the rock sphere in the sandbox gym")

The sandbox Rock is `engine::Sphere()` x 0.3 = 30 cm (`Mars_Item_Sandbox.as:7`); the bulb (9.9 cm) is the comparable
mass -> factor 3.0. Neutral height 16 -> 48 cm via one builder parameter `P["SCALE"] = 3.0` (brief `PHASE_B4_BRIEF.md`); beds, hull,
sockets, pose translations and shape-key offsets scale with it; rig, ratios, timings and the kernel unchanged. Order:
C2 finishes (morph pipeline proof, independent of size) -> B4 (rebuild, re-animate, re-export) -> C3 (reimport with
the new numbers) -> H (Script re-tune from the manifest's `gameplay_numbers`, AnticipateTired wiring, final PIE,
VERIFICATION.md). The 16 cm candidate assets are superseded; the Phase F/G PIE evidence stays valid for gameplay.

## Phase C2 - B3 reimport, morph targets + curves in Unreal, playback proof (brief: `PHASE_C2_BRIEF.md`)

### Phase C2 executor report (Opus, 2026-11-06) - DONE, awaiting Fable audit
Imported the **Phase B3 exports** (`export/*.fbx`, `export/anims/*.fbx`, `validation/Cube10_Mars_SM.fbx`, all mtime 03:55).
These are the 16 cm assets. The x3.0 size ruling above supersedes them, and C3 re-runs this chain on the B4 exports. No git,
nothing under `Script/` edited, writes only under `/Game/ArtCandidates/ScreamingTurnip/R01/` and this folder. Editor
`D:/Repositories/CkRepos/Orion/Mars.uproject` 5.7.4, PIE off, 0 foreign dirty packages before and after every stage, and no
"Full Reload is required" in `Mars.log` before any stage. **confirmed** (stage preflights in `export/unreal_readback_final.json`, log grep).

#### Commands (Monolith `editor_query run_python`, `execute_file`, `unattended: true`)
`scripts/screaming_turnip_import_ue.py <stage> [arg]`. New stages: `reimport_b3 [key]` (materials + mesh + statics +
clips, full readback, diffed against `readback_b3` when it exists), `readback_b3` (also writes the reload snapshot
`review/phaseC2/readback_pre_restart.json`, which `reload` now diffs against), and `playback_setup | playback_set "<t> <on|off>" |
playback_read <tag> | playback_room | playback_cleanup`. Run order that produced the final state:
`reimport_b3` x2 (incidents C2-1/C2-2, fixed) -> Monolith `set_socket_transform` MouthCue -> `reimport_b3` (final options;
saves the master with the morph flag) -> `readback_b3` -> `reimport_b3 reimport_b3_r2` -> `reimport_b3 reimport_b3_r3` ->
`readback_b3` (snapshot refreshed after the last save) -> 3 Monolith `capture_scene_preview` -> `playback_setup` -> reads/sets ->
`playback_room` -> `playback_cleanup` (Sandbox_Mars_MAP restored). **confirmed**.

Importer changes (low-blast; the Phase C copy is in the session scratchpad): SK `import_morph_targets=True` and
`update_skeleton_reference_pose=True`; clips `do_not_import_curve_with_zero=False`. These options are **written onto each
existing asset's stored import data before the reimport** (`_sync_stored`), because `replace_existing` on an existing asset goes
through FReimportManager with the stored data and ignores the task options (C2-1). The master gets `used_with_morph_targets`.
The readback now also asserts: morph names, skeleton curve morph flags, per-clip curves (presence, every-frame value vs
`expected_anims.json` `sk`, peaks vs the manifest's `phase_c_readback.curve_peaks`), 16 clips, and the AnticipateTired cut gate.

#### Readback (`export/unreal_readback_final.json` `readback_b3`; Monolith rows in `monolith_b3`)  **confirmed**
| item | expected | got | |
|---|---|---|---|
| morph targets on SK | [Inhale, Scream] | [Inhale, Scream] (Python `get_all_morph_target_names` + Monolith `get_skeletal_mesh_info`) | PASS |
| skeleton curve metadata | morph flag on Inhale/Scream | both true (`get_curve_meta_data_morph_target`) | PASS |
| tris / LOD / sections | 3188 / 1 | 3188 (Monolith `get_mesh_info`; log sections 2090+310+660+128) / 1 / 4; render verts 9536 | PASS |
| bones / names / parents / root | 17, exact, identity | 17, 0 extra/missing, 0 wrong parents, root t 0 q identity s 1 | PASS |
| bone heads vs B3 expected.json | <= 0.01 cm | 0.0 (after C2-2: cheek_l/r now (1.5, -+3.3, 6.4)) | PASS |
| bind bounds vs manifest | (-5.8966,-6.6803,0)..(5.4047,6.6803,16) | err 0.0001 cm | PASS |
| bounds extension (envelope 21.20 x 14.21 x 13.90 + 2 cm) | contains (-7.222,-7.107,-0.6)..(6.679,7.107,20.596) + 2 | +X4/+Y3/+Z7, -X4/-Y3/-Z3 -> (-9.90,-9.68,-3)..(9.40,9.68,23); min margin 2.40 cm | PASS |
| sockets (component, bind) | Grip_L/R root (0,-+3.94,4); MouthCue jaw (4.136,0,6.4) [jaw-rel (4.636,0,2.2)]; SoilLine; HarvestGrip_L/R | all six err 0.0 cm; MouthCue moved via Monolith `set_socket_transform`, read back by `get_skeleton_sockets` | PASS |
| slots / binding / no PHYS | Skin, Leaf, Mouth, Teeth -> MIs; none | same; None | PASS |
| SK import data | IMPORT_NORMALS, REPLACE, scale 1, morphs on | same + `import_morph_targets True`, `update_skeleton_reference_pose True` | PASS |
| master | + used_with_morph_targets | true; MIs unchanged (rough/spec/cavity/gamma/two-sided) | PASS |
| Collision_Mars_SM (widened) | (-4.4,-4.95,1.8)..(5.0613,4.95,11.7), 40 tris | err 0.0, 40, 1 convex elem (regenerated), Skin MI | PASS |
| hull sockets Grip_L/R | (0,-+3.94,4) rot 0 | exact (re-asserted) | PASS |
| beds / Cube10 | as Phase C | err 0.0, 224 / 288, 1 box each; +-5.000 | PASS |
| 16 clips keys / length / tracks / skeleton / rate / root motion / loop | N+1, N/30, 17, SKEL, 1, off, manifest | all equal; AnticipateTired 10 keys / 0.3 s / 17 tracks / loop off | PASS |
| curve names per clip | Inhale + Scream on all 16 | 16/16 (Python `get_animation_curve_names`; Monolith `get_sequence_curves`, N+1 keys each) | PASS |
| curve values, every frame vs Blender `sk` | <= 0.001 | worst 6e-7 (ROOT_Inhale Inhale f23); every zero clip 0.0 on every key | PASS |
| ROOT_Inhale | Inhale 1.0 at f30..f36 incl. last | max 1.0, frames 30..36; Scream 0 | PASS |
| ROOT_Scream | Scream 1.0 f3..f18; Inhale 1.0 f0 -> 0 from f3 | Scream max 1.0 at 3..18; Inhale 1.0 at f0 only (f1 .741, f2 .259, f3 0) | PASS |
| ROOT_Recover | Scream 1, .94, .82, .70, .30, .15, .07, .02, 0 (f0..f8), 0 after | same table, worst err 0.0; Inhale 0 | PASS |
| QuietIdle / SRC_* / others | both curves present, 0 everywhere | present, max 0.0 | PASS |
| root identity 5 samples / landmarks every frame / scale peaks | exact / <= 0.02 cm / err 0 | exact / worst 0.000194 cm (QuietIdle f51 leaf_05_b) / 0.0 | PASS |
| loop seams (QuietIdle, RecoveryIdle, SRC_Idle, AirborneLeafTrail) | first == last | 0.0 cm / 0.0 deg / 0.0 | PASS |
| chain (10 manifest links incl. RecoveryIdle f0 -> AnticipateTired f0, + 2 note ends) | 0 | 12 links, max 3e-6 cm / 1e-5 deg / 0 scale | PASS |
| cut RecoveryIdle f0 -> AnticipateTired f0 (bone level, world heads) | <= 0.1 cm / 1 deg | 0.0 / 0.0; any frame worst 0.1485 cm / 2.299 deg at f15 (Blender 0.148 / 2.30) | PASS |
| old cuts (RecoveryIdle -> Anticipate, QuietIdle -> Anticipate) | Blender 0.652/42.5, 0.160/4.1 | 0.6517/42.46, worst 0.1603/4.13 | matches |
| double reimport | identical readback, no `_1`, 28 owned | `reimport_b3_r2` and `_r3`: `identical: true`, every diff list empty, duplicates [], 28 owned (+ review map = 29 in root), 0 dirty after | PASS |
| reload (cold read) | readback after the next restart == `review/phaseC2/readback_pre_restart.json` | NOT RUN (needs a restart) | pending |

Morph normals: the import log has **no morph-normal line**. The only SK lines are `LogFbx: Warning: Not valid bind pose for Pose
(ScreamingTurnip_R01_Body) - Node ScreamingTurnip_R01_Body : Not all the deformers are stored in this BindPose` (followed by
`Valid bind pose for Pose (ScreamingTurnip_R01_Body)`), `FBXImport: Warning: Mesh 'ScreamingTurnip_R01_Body' has no UV set.
Creating a default set.` (both as in Phase C), and `LogMaterial: Display: Material .../ScreamingTurnip_R01_Skin_Mars_MI needed to
have new flag set bUsedWithMorphTargets !` (fixed in the master). Engine source, 5.7 fork: with a mesh description,
`LODUtilities.cpp:2969` forces `ShouldImportNormals = false` for the morph build. Morph normals are then **recomputed** from the
morphed positions (`:3056`, `CalculateNormals` with BlendOverlappingNormals), and IMPORT_NORMALS applies to the base mesh only.
**confirmed by reading the source; the visual effect is inferred** (see the rim note under Not verified).

#### Single-node playback proof outside PIE (`playback_b3`)  **confirmed**
Editor world, no PIE: a transient SkeletalMeshActor in the owned review map at (-150, 120, 60), yaw 180. Calls:
`SetUpdateAnimationInEditor(true)`, `PlayAnimation(ROOT_Scream, false)`, `SetPosition(t, false)`, `Stop()`. Each read happens in a
later `run_python` call, after the editor ticked the component.
| t | morphs | anim instance curves (Inhale / Scream) | GetMorphTarget | jaw (component) | body scale | MouthCue |
|---|---|---|---|---|---|---|
| 0.4 | on | 0.0 / **1.0** | 0 / 0 | (-0.739, 0, 4.908) pitch **-35.5** | (1.3, 1.0, 1.3) | (5.828, 0, 3.737) |
| 0.4 | off | 0.0 / 1.0 | 0 / 0 | same | same | same |
| 0.0 | on | **1.0** / 0.0 | 0 / 0 | (-0.460, 0, 4.016) pitch 0 | (0.92, 0.88, 0.92) | (3.805, 0, 6.040) |
The anim instance's curve values equal the sequence at that time and the pose is evaluated, so the component does evaluate
outside PIE. The Monolith preview path stays at bind pose (bat record); this route does not.
`GetMorphTarget` returns 0 by design: it reads only the manual `SetMorphTarget` map (`SkeletalMeshComponent.cpp:3810-3822`;
written only at `:3781-3807`). Anim-curve morph weights live in ActiveMorphTargets/MorphTargetWeights, which Python cannot read.
The morph proof is visual: at 0.4 s, morphs on shows the full gape (rolled rim, upper and lower tooth rows, open pocket). Morphs
off, with the same bones, shows only the bone-stretched X pucker. At 0.0 s the inhale bellows show. All three match
`review/phaseB3/clips/ROOT_Scream_sheet.png` f0 / f12. The actor bounds do not change with the pose (ref bounds + fixed
extension). Per-vertex positions are not readable from Python. The review map was never dirtied; the probe was destroyed and
`Sandbox_Mars_MAP` restored, 0 dirty.

#### Captures (look at these)
- `review/phaseC2/playback/UE_probe_t040_morph_on.png` vs `UE_probe_t040_morph_off.png` (the morph isolated) and
  `UE_probe_t000_morph_on.png` (inhale). The amber key over-exposes these at 24 cm; read them for shape, not colour.
- `review/phaseC2/UE_SK_{front,mouth_closeup,threequarter}.png`: Monolith `capture_scene_preview`, bind pose. The preview
  scene is still lit from behind (as in Phase C), so the front is dark.
- `review/phaseC2/room/UE_review_*.png` (7 views; `room_from_playerstart`, `hand_mouth_closeup` show the B3 mesh in place).

#### Incidents
- C2-1 The first `reimport_b3` reimported the SK **without** morph targets, because `replace_existing` -> FReimportManager uses the
  asset's stored import data (`import_morph_targets False` from Phase C). Fixed by writing the options onto the stored data first.
  That run's report was overwritten by later runs of the same key.
- C2-2 The same run left the dedicated SKEL on the Phase B ref pose (cheeks (1.7, -+3.25) vs B3 (1.5, -+3.3); bone-head check
  0.206 cm). Fixed with `update_skeleton_reference_pose=True` on the stored data.
- C2-3 `disable_morph_target` set through `set_editor_property` re-registers the component and resets the single-node instance
  (position 0, ref pose). `playback_set` now sets the flag first, then re-plays and re-seeks. Transient actors are not listed by
  `EditorActorSubsystem.get_all_level_actors`, so the probe is found through `GameplayStatics`.
- No crash, no modal left open, no foreign dirty package. Log noise during the map switches was not caused by this phase:
  `CkLogger: Error: Could not find the Logger [CkAbility]` (as Phase C) and FlameCard Nanite translucency warnings on the
  Sandbox reload.
- Readback JSON keys `readback`/`reimport` are the stale Phase B numbers. `playback_read` holds only the last read; `playback_b3`
  holds all three.

#### Not verified
- Cold reload in the next editor session: `screaming_turnip_import_ue.py reload`, expect `readings_match: true`, empty `hash_diff`.
- Motion: only paused frames were evaluated (0.0 / 0.4 s). Nobody has watched playback (the Recover f3 -> f4 band jump, the
  sub-frame tooth poke); PIE in Phase H is the visual proof.
- Morph-normal shading: the gape rim in `UE_probe_t040_morph_on.png` has dark wedge patches at the corners. **Inferred** cause:
  recomputed morph normals or self-shadowing under the hot key, not proven. Judge it under neutral light in PIE.
- That the runtime presentation (kernel phase -> PlayAnimation) drives these curves in game: same single-node path, but untested in PIE here.

## Audit of Phase C2 (Fable, 2026-11-06) - ACCEPTED

Looked at `review/phaseC2/playback/UE_probe_t040_morph_on.png` vs `_off.png`: the gape (rolled rim, both tooth rows)
comes from the `Scream` morph; bones alone give a stretched X pucker. **confirmed**. Readback table all PASS (morph
names on the SK, curves on all 16 clips within 6e-7, double reimport identical, 28 owned assets). Importer facts kept:
`replace_existing` reuses the asset's SAVED import options (the script now syncs them first); the skeleton needs
`update_skeleton_reference_pose=True` when bone heads move; morph normals are recomputed by the engine
(`LODUtilities.cpp:2969`); `GetMorphTarget` reads only manual weights (proof is visual). Watch in PIE under neutral
light: dark wedge patches at the rim corners (C2-1; morph normals on flat facets, or the amber key). The 16 cm assets
are superseded by B4; C3 = the same chain (`reimport_b3` -> `readback_b3` -> `reimport_b3 x2` -> `playback_*`) on
the x3.0 exports with the manifest's new expected numbers.

## Phase B4 - the whole asset x3.0, re-animated, re-exported (brief: `PHASE_B4_BRIEF.md`)

### Phase B4 executor report (Opus, 2026-11-06) - DONE, awaiting Fable audit; no Unreal (C3 reimports)

No git, no Unreal, no `Script/` edit, writes only in this folder. The C2 gate held: `## Phase C2` was present (line 1704)
when checked in the same shell line as the first `export/` write (04:18). **confirmed**.

#### How the scale is applied (one parameter, `P["SCALE"] = 3.0`)
The builder still builds every part, the rig and both shape keys in the 16 cm design frame, then one step
(`apply_global_scale`) multiplies every length: body vertices and every key block (Basis / Inhale / Scream), the Authoring
solids, the three statics and the beds' scene z, bone heads/tails (rolls kept). Pose translations (body z, crown z, cheek
offsets) scale in `bone_targets` through `unit()` = body head z / ZC read off the rig (1.0 on a design blend, 3.0 on B4), so
animate / render / export take the factor from the blend they open. Design thresholds inside metrics (`prot_of`, the 0.25 cm
muzzle, the 0.8 cm cheek band, `X_GAP`) scale too. Tri count 3188, 17 bones, slots, root identity, D-A1 unchanged; no
geometry added. Why not multiply every literal: the builder holds hundreds of design lengths in code; scaling the output is
exact by construction and is proven vertex by vertex below.

#### Rerun (from this folder; each prints TURNIP_OK / TURNIP_FAIL and exits non-zero on failure)
```bash
B="C:/Program Files/Blender Foundation/Blender 5.2/blender.exe"
"$B" -b --factory-startup --python scripts/build_screaming_turnip.py                                        # blend + review/phaseB4/{measurements,pose_report}.json
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python scripts/render_screaming_turnip.py -- --planted --compare --fp --tag r01
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python scripts/animate_screaming_turnip.py      # 16 clips, audit, saves the blend
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python scripts/render_anims_screaming_turnip.py -- --tag r01
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python scripts/export_screaming_turnip.py
"$B" -b --factory-startup --python scripts/validate_roundtrip.py
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python scripts/scale_check_screaming_turnip.py -- --stage export
```
Logs: `review/phaseB4/{build,render,animate,render_anims,scale_check*}_log.txt`, `export/export_log.txt`, `export/roundtrip_log.txt`;
every run exit 0 / `TURNIP_OK` on the final code. **confirmed**. B3 kept for comparison: `source/ScreamingTurnip_R01_phaseB3.blend`
(byte copy before the build) and `review/phaseB4/b3_baseline/` (copies of the B3 reports and manifest).

#### Scale proof (`scripts/scale_check_screaming_turnip.py`; `review/phaseB4/scale_check_export.json`)  **confirmed**
- Builder self-check (`measurements.json` `scale_check`): every pose's evaluated mesh (neutral, inhale, scream, recover,
  impact_squash, planted; keys at their pose values) == 3.0 x the design-frame mesh within 1.5e-5 cm; unit 3.0; rest
  rotations changed 0.0 deg.
- Against the B3 blend, vertex by vertex: body Basis / Inhale / Scream, both beds, hull <= 1.9e-6 cm from 3.0 x B3; bone
  heads and tails exact; rest rotations, parents, polygons, material indices, weights, vertex colours identical; bed scene
  z 9.6 -> 28.8. The current builder reproduces the B3 asset exactly, x3.
- Every numeric length in the reports vs B3 x 3.0 (0.5 %, or 0.002 cm rounding slack): measurements 222, pose_report 361,
  anim_report 166, expected.json 76, expected_anims.json 107 682 (every landmark, extreme and peak vertex of every frame of
  every clip): **0 fails**. Worst 0.29 % (`apex_x_minus_lip_crest_x` 0.232 -> 0.694, a difference of two roundings). Areas
  scale 9.0. Left alone by design: counts, ratios, angles, key values, unit vectors, the design `params` dump.

Headline ratios (`review/phaseB4/ratio_table.md`):

| quantity | B3 (cm) | B4 (cm) | ratio |
|---|---|---|---|
| neutral height (tip to highest leaf) | 16.0 | 48.0 | 3.0 |
| neutral width w_y | 13.361 | 40.082 | 2.9999 |
| neutral depth d_x | 11.301 | 33.904 | 3.0001 |
| bulb h_z | 9.9 | 29.7 | 3.0 |
| bulb w_y | 9.338 | 28.013 | 2.9999 |
| bulb d_x | 7.944 | 23.832 | 3.0 |
| body bone head z | 6.825 | 20.475 | 3.0 |
| jaw hinge x | -0.5 | -1.5 | 3.0 |
| jaw hinge z | 4.2 | 12.6 | 3.0 |
| crown base z | 11.55 | 34.65 | 3.0 |
| cheek_l head y | 3.3 | 9.9 | 3.0 |
| Grip_L y (UE) | -3.94 | -11.82 | 3.0 |
| Grip_L z | 4.0 | 12.0 | 3.0 |
| MouthCue x | 4.136 | 12.407 | 2.9998 |
| MouthCue z | 6.4 | 19.2 | 3.0 |
| SoilLine z | 9.6 | 28.8 | 3.0 |
| HarvestGrip_L z | 12.678 | 38.035 | 3.0001 |
| hull extents d_x | 9.461 | 28.384 | 3.0001 |
| hull extents w_y | 9.9 | 29.7 | 3.0 |
| hull extents h_z | 9.9 | 29.7 | 3.0 |
| hull front x (widened) | 5.061 | 15.184 | 3.0002 |
| hull centre offset x | 0.331 | 0.992 | 2.997 |
| hull centre offset z | 6.75 | 20.25 | 3.0 |
| bed outer w | 24.0 | 72.0 | 3.0 |
| bed h | 4.087 | 12.26 | 2.9998 |
| bed top z (above soil line) | 0.687 | 2.06 | 2.9985 |
| bed scene z | 9.6 | 28.8 | 3.0 |
| muzzle protrusion max | 1.04 | 3.12 | 3.0 |
| seam floor x_c | 3.349 | 10.047 | 3.0 |
| Inhale key max rest delta | 2.266 | 6.798 | 3.0 |
| Scream key max rest delta | 3.532 | 10.596 | 3.0 |
| scream pose height | 19.858 | 59.574 | 3.0 |
| scream side lip separation | 5.976 | 17.929 | 3.0002 |
| scream cavity depth | 3.635 | 10.904 | 2.9997 |
| inhale lobe forward (l) | 1.906 | 5.717 | 2.9995 |
| recover width | 13.831 | 41.494 | 3.0001 |

#### Sheets (looked at)
- `review/phaseB4/poses_overview.png`, `<pose>/<pose>_sheet.png`: B3 framing x unit, the 10 cm ruler now ~1/5 of the
  turnip; look unchanged. `planted/planted_sheet.png` (72 cm bed, soil line 28.8), `lighting/lighting_compare.png`.
- First-person mock `fp_mock/fp_sheet.png` (90 deg FOV, eye 45 cm from the bulb centre at its height, 960x540): **neutral
  covers 19.4 % of the frame (silhouette pixels), bbox 39 % of the width, 90 % of the height**; inhale 27.1 %, scream
  22.8 %. B3 at the same camera (`b3_fp_reference/fp_mock/`): 2.2 % / 14 % / 32 % (x8.9 area). At 45 cm the 48 cm root no
  longer fits vertically: the leaves leave the top of the frame (the 90 % is clipped there). `fp_mock/fp_fraction.json`.
  **confirmed** (alpha pixel count of `fp_alpha_*.png`).
- Clips: `clips/cycle_sheet.png`, `ROOT_Scream_sheet.png`, `ROOT_Inhale_sheet.png` (+ every clip sheet, `shapekey_sheet.png`):
  frame for frame the B3 look at 3x; the Recover f4 squarish half-open (B3-1) is still there.

#### Clips (`review/phaseB4/anim_report.json`, `export/anims/clips.json`)  **confirmed**
Same keys, frames, loops, layers and curves as B3. Every frame of every clip: intersections 0 in every category, root
identity, Unreal composition deviation <= 0.00002 cm, playback == authored. Every clip's bounds = B3 x 3.000.

| clip | frames | loop (seam pose / vel cm/f) | Inhale peak | Scream peak | isect max | bounds h x w x d |
|---|---|---|---|---|---|---|
| SRC_Idle | 0..60 | yes, 0 / 0.00082 | 0 | 0 | 0 | 49.01 x 40.75 x 35.14 |
| SRC_Grip | 0..6 | no | 0 | 0 | 0 | 49.27 x 40.08 x 33.90 |
| SRC_Tug | 0..15 | no | 0 | 0 | 0 | 51.64 x 37.36 x 30.79 |
| SRC_Release | 0..6 | no | 0 | 0 | 0 | 51.64 x 42.64 x 38.61 |
| SRC_Cancel | 0..7 | no | 0 | 0 | 0 | 51.64 x 40.08 x 33.90 |
| ROOT_QuietIdle | 0..60 | yes, 0 / 0.00264 | 0 | 0 | 0 | 48.80 x 40.46 x 34.57 |
| ROOT_Anticipate | 0..9 | no | 0 | 0 | 0 | 49.14 x 40.08 x 33.90 |
| ROOT_AnticipateTired | 0..9 | no | 0 | 0 | 0 | 49.14 x 42.33 x 38.49 |
| ROOT_Inhale | 0..36 | no | 1.0 (f30..f36) | 0 | 0 | 50.62 x 38.70 x 31.56 |
| ROOT_Scream | 0..18 | no | 1.0 (f0..f0) | 1.0 (f3..f18) | 0 | 61.79 x 41.26 x 40.94 |
| ROOT_Recover | 0..30 | no | 0 | 1.0 (f0..f0), 0 from f8 | 0 | 59.57 x 42.30 x 40.63 |
| ROOT_RecoveryIdle | 0..60 | yes, 0 / 0.00032 | 0 | 0 | 0 | 40.59 x 42.33 x 38.27 |
| ROOT_AirborneLeafTrail | 0..30 | yes, 0 / 0.00665 | 0 | 0 | 0 | 47.61 x 42.37 x 38.27 |
| ROOT_ImpactSquash | 0..7 | no | 0 | 0 | 0 | 48.00 x 42.35 x 38.39 |
| ROOT_SettleRock | 0..12 | no | 0 | 0 | 0 | 49.49 x 41.86 x 37.43 |
| ROOT_PlaceSettle | 0..7 | no | 0 | 0 | 0 | 48.00 x 40.08 x 33.90 |

Chain joints all 0 / 0 / 0 (incl. RecoveryIdle f0 -> AnticipateTired f0, gate <= 0.1 cm / 1 deg kept absolute). Hard cuts
(B3 x 3): QuietIdle any -> Anticipate f0 0.481 cm / 4.13 deg; RecoveryIdle any -> AnticipateTired f0 0.445 cm / 2.30 deg;
RecoveryIdle f0 -> Anticipate f0 1.955 cm / 42.46 deg. **Envelope 63.589 h x 42.641 w x 41.702 d cm** (B3 21.196 x 14.214 x
13.901). Planted: body -1.8, seam top 20.4, shoulder 4.5 cm above the 28.8 soil line, taproot tip -1.8.

#### Export (DEV-13 recipe unchanged) + round trip  **confirmed**
SK (3188 tris, 17 bones, Basis/Inhale/Scream), the three statics, `validation/Cube10_Mars_SM.fbx` (still 10 cm: the unit
check), 16 clip FBX (armature + Key action each), `expected.json`, `anims/expected_anims.json`, `export_settings.json`.
Round trip `fails: []` (bind and anims): bind heads 6.1e-5 cm, rest rotations 0.0, bounds 5.5e-5, statics <= 4.9e-5, cube
+-5.000; 16 clips, actions `Armature|Scene` + `Key|Scene` only, N+1 samples, root 0.0, landmarks <= 8.7e-5 cm, extremes <=
6.7e-5, seams 0, key values <= 5e-7, peaks as authored (Inhale 1.0 f30..f36, Scream 1.0 f3..f18, Recover 0 from f8),
peak-frame mesh <= 2.8e-5 cm. Tolerances are the B3 absolute ones (3x stricter relative to the asset).
`export/unreal_readback_final.json` (C2's) untouched.

#### Manifest (`export/ScreamingTurnip_R01_Manifest.json`)  **confirmed** (read back)
`scale_factor: 3.0` + `scale_note`; neutral 48.0 h, bulb 29.7 x 28.013 x 23.832; sockets (root-relative UE cm): Grip_L/R
(0, -/+11.82, 12.0), MouthCue (12.407, 0, 19.2) on jaw, SoilLine 28.8, HarvestGrip_L/R (-1.522, -/+4.683, 38.035);
collision 40 tris, x -13.2..15.184, y +-14.85, z 5.4..35.1, centre (0.992, 0, 20.25); beds 72 x 72, z -10.2..2.06.
`phase_c_readback` (for C3) carries the B4 bind bounds, every bone head, envelope + 6 cm bounds extension, statics bounds,
hull sockets, cut numbers, and two import notes: **the skeleton reference pose must update (bones moved x3,
`update_skeleton_reference_pose=True`, C2-2) and all six SK sockets must be re-set**.

#### gameplay_numbers (manifest block, verbatim)
```json
{
 "frame": "Unreal cm (x, -y, z) from the skeletal mesh root (the taproot tip); the item's proxy pivot == that root",
 "scale_factor": 3.0,
 "k_GripLocation_R": [
  0.0,
  -11.82,
  12.0
 ],
 "k_GripLocation_L": [
  0.0,
  11.82,
  12.0
 ],
 "grip_note": "R takes the root's -Y flank landmark (its Grip_L), L the +Y one, as now (k_GripRotation yaw 180 unchanged); was (0, -/+3.94, 4.0). The grips are now 23.64 cm apart (was 7.88): check the Cradle glove layout spreads that wide",
 "hull_centre_offset_from_root": [
  0.992,
  0.0,
  20.25
 ],
 "hull_centre_note": "bounds centre of the collision hull; x is 0.992 (not 0) because the hull's +X half is widened over the lip crest (B2b); comment in constants_screaming_turnip_assets says 6.75 -> 20.25",
 "hull_extents": {
  "h_z": 29.7,
  "w_y": 29.7,
  "d_x": 28.384
 },
 "k_PlantedOffset": [
  0.0,
  0.0,
  -28.8
 ],
 "bed": {
  "outer_size_cm": [
   72.0,
   72.0,
   12.26
  ],
  "top_z_above_soil_line": 2.0597,
  "bottom_z": -10.2,
  "pivot": "soil-line centre (unchanged)"
 },
 "k_ReleasePointOffset_suggestion": [
  0.0,
  0.0,
  60.0
 ],
 "release_note": "bed centre + 60 cm (was + 20): the hop starts with the 48.0 cm root's base clear of the 2.06 cm bed top. ReleaseLaunch / ReleaseSpinDeg / the bed probe (30, 30, 20) half extents are not re-derived here: the probe box is now smaller than the 72 cm bed (judge in Phase H)",
 "HeldOffset_location": [
  14.661,
  0.0,
  -25.5
 ],
 "HeldOffset_rotation": [
  0.0,
  180.0,
  0.0
 ],
 "held_note": "B3 HeldOffset (14, 0, -12) yaw 180 put the hull centre at [13.669, 0.0, -5.25] in the hand frame (root + yaw180([0.331, -0.0, 6.75])); the B4 root goes at [14.661, 0.0, -25.5] so the hull centre stays there. With the brief's x-free centre (0, 0, 20.25) the value is (14, 0, -25.50)",
 "hull_bounding_radius": 15.018,
 "PickupProbeRadius_suggestion": 21.0,
 "pickup_note": "hull bounding radius from its centre 15.02 + 5 cm margin, rounded up (B3 radius would be 5.01). Only used when the item has no Mesh (Mars_WorldItem_Utils.as:391 / :406): the proxy hull's bounds drive the probe otherwise"
}
```
Phase H mapping: `k_GripLocation_R/L`, `k_PlantedOffset` z -28.8, `HeldOffset` (14.661, 0, -25.5) yaw 180 (or (14, 0, -25.5)
with the brief's x-free centre), `k_ReleasePointOffset` (0, 0, 60), `PickupProbeRadius` 21 (used only without a mesh). Not
applied here.

#### Deviations / decisions (low-blast; say if you want them changed)
- Scale applied to the build output, not to each literal (above); same result, proven to 1.9e-6 cm.
- Hull centre offset (0.992, 0, 20.25), not the brief's (0, 0, 20.25): the B2b-widened +X half. HeldOffset uses it; the
  x-free alternative is in the block.
- Chain / seam / playback / round-trip gates stay absolute cm (stricter, not loosened). Envelope limit 22 x 14 x 13 ->
  66 x 42 x 39; exceeded by w 0.641 / d 2.702 (B3's 0.214 / 0.901 x 3: leaf tips and the scream rim).
- Rulers in the sheets and the validation cube stay 10 cm (length references).
- `PickupProbeRadius` margin 5 cm is my pick (radius 15.02 -> 21).

#### Not verified
- Unreal: nothing imported (C3). SK reference pose, sockets, bounds extension and collision must be redone there.
- In game: HeldOffset / grip numbers are arithmetic only. The grips are 23.64 cm apart (was 7.88): whether the Cradle glove
  layout reaches that wide, and how a 48 cm root sits in first person at the real held offset, are PIE questions (H). The
  bed's interaction probe (30, 30, 20 half extents) is now smaller than the 72 cm bed; not re-derived.
- Physics (mass, `ReleaseLaunch` (120, 0, 170)) not re-tuned for a 3x root.
- Motion: stills only (B3-1 band frame and the sub-frame tooth poke carried from B3).
- The claim I'd most expect to be wrong: that HeldOffset (14.661, 0, -25.5) reads well in first person. It preserves the
  hull centre, but the bigger body may want to sit further out or lower.

## Audit of Phase B4 (Fable, 2026-11-06) - ACCEPTED

Scale applied as one output transform (`apply_global_scale`, P["SCALE"] = 3.0) and proven by construction: body,
shape keys, statics, bones within 1.9e-6 cm of 3 x B3; 108k report numbers within 0.5 %; clips re-authored, 0
intersections, round trip `fails: []`; manifest `scale_factor 3.0`, `phase_c_readback` and `gameplay_numbers`
present. fp mock 19.4 % of frame area (B3 2.2 %). **confirmed** by the executor's scale_check and my read of the
ratio table. Open for H: HeldOffset (14.661, 0, -25.5) starting value, Cradle layout at 23.64 cm grip spread, bed
probe half-extents vs the 72 cm bed, ReleaseLaunch re-tune. C3 launched.

## Phase C3 - reimport of the B4 (x3.0) mesh, statics and 16 clips; readback; morph proof; review room re-placed (brief: `PHASE_C2_BRIEF.md` on the B4 exports)

### Phase C3 executor report (Opus, 2026-11-06) - DONE, awaiting Fable audit
Imported the **Phase B4 exports** (`export/*.fbx`, `export/anims/*.fbx`, `validation/Cube10_Mars_SM.fbx`, mtime 04:18; manifest
`scale_factor 3.0`). No git, nothing under `Script/` edited. Unreal writes only under `/Game/ArtCandidates/ScreamingTurnip/R01/`
(plus the CkJolt on-save side files of the review map, below). Disk writes in this folder, `review/phaseC3/`, and the review
module in `Tools/LevelDesign/screaming_turnip_r01_review/`. Editor `D:/Repositories/CkRepos/Orion/Mars.uproject` 5.7.4, PIE off,
0 dirty packages before and after every stage, no "Full Reload is required" in `Mars.log` (the last reload lines, 08:44, are
per-class `Soft Reload`/`Full Reload: <class>` records). **confirmed** (stage preflights in `export/unreal_readback_final.json`, log grep).

#### Commands (Monolith `editor_query run_python`, `execute_file`, `unattended: true`)
`scripts/screaming_turnip_import_ue.py <stage> [arg]`. New stages `reimport_b4 [key]` and `readback_b4` (same chain as the b3
ones). The snapshot is `review/phaseC3/readback_pre_restart.json`, which `reload` now diffs. `playback_*` write under
`review/phaseC3/`. Expected numbers now come from the manifest, not constants:
- bounds margin: parsed from `phase_c_readback.import.bounds_extension` ("+ 6 cm margin"), cross-checked == 2 cm x `scale_factor`
- hard-cut reference numbers: `phase_c_readback.cuts`. A new check `cut matches manifest` (tol 0.01 cm / 0.1 deg).
- extra cross-checks against `phase_c_readback.assert_on_*`: envelope, bind bounds, bone heads, slot list, the six sockets'
  bone-relative transforms, statics bounds and tris, hull sockets (rotation 0 too), num_keys per clip.

The C2 copy of the importer is in the session scratchpad.

Run order: `reimport_b4` (only `sockets_6` red: the SKEL still had the 16 cm sockets) -> `socket_plan` (bind gives the manifest
bone-relative values, delta 0.0) -> Monolith `set_socket_transform` x6 on the SKEL -> `save_packages` (SKEL only,
`fail_on_unrequested_dirty`) -> `readback_b4` -> `reimport_b4 reimport_b4_r2` -> `reimport_b4 reimport_b4_r3` -> `readback_b4`
(snapshot after the last save) -> Monolith reads + 3 `capture_scene_preview` -> `playback_setup` -> 3 x (`playback_set`,
`playback_read`) -> `replace_displays()` (review module) -> `playback_room` -> `playback_cleanup` (Sandbox_Mars_MAP restored) ->
cold re-open of the review map + `readback()` -> Sandbox restored. **confirmed**.

#### Readback (`export/unreal_readback_final.json` `readback_b4`; Monolith rows in `monolith_b4`)  **confirmed**
| item | expected (manifest / sidecars) | got (editor) | |
|---|---|---|---|
| morph targets on SK | [Inhale, Scream] | [Inhale, Scream] (Python + Monolith `get_skeletal_mesh_info`) | PASS |
| skeleton curve morph flags | Inhale, Scream | both true | PASS |
| tris / verts / LOD / sections | 3188 / - / 1 / 4 | 3188 (Monolith `get_mesh_info`; log sections 2090+310+660+128) / 9536 render verts / 1 / 4 | PASS |
| bones / names / parents / root | 17, exact, identity | 17, 0 extra/missing, 0 wrong parents, root t 0 q (0,0,0,1) s 1 | PASS |
| bone heads x3 (expected.json + `phase_c_readback.bone_heads_ue_cm`) | e.g. body z 20.475, jaw (-1.5,0,12.6), cheek_l (4.5,-9.9,19.2), crown 34.65 | worst 0.0001 cm vs both | PASS |
| bone ref scales / handedness | 1 / cheek_l -Y | max dev 1e-7 / -9.9, +9.9 | PASS |
| bind bounds | (-17.6897,-20.0408,0)..(16.2142,20.0408,48.0) | err 0.0001 cm | PASS |
| bounds extension (envelope 63.589 x 42.641 x 41.702 + 6 cm) | contains (-21.665,-21.32,-1.8)..(20.036,21.32,61.789) + 6 | +X10/+Y8/+Z20, -X10/-Y8/-Z8 -> (-27.69,-28.04,-8)..(26.21,28.04,68); min margin 6.02 cm; envelope == `phase_c_readback` (err 0) | PASS |
| SK sockets (component, bind; bone-relative vs `phase_c_readback`) | Grip_L/R root (0,-+11.82,12); MouthCue jaw rel (13.907,0,6.6) -> comp (12.407,0,19.2); SoilLine body rel (0,0,8.325) -> 28.8; HarvestGrip_L/R crown rel (-1.522,-+4.683,3.385) -> 38.035 | all six on the right bones, err 0.0 cm component and relative; Monolith `get_skeleton_sockets` agrees | PASS |
| slots / binding / no PHYS | Skin, Leaf, Mouth, Teeth -> MIs; none | same; None | PASS |
| SK import data | IMPORT_NORMALS, REPLACE, scale 1, morphs on, update ref pose | same (`import_morph_targets True`, `update_skeleton_reference_pose True`) | PASS |
| materials | as C2 | material_readback pass (unchanged) | PASS |
| Collision_Mars_SM | (-13.2,-14.85,5.4)..(15.1839,14.85,35.1), 40 tris | err 0.0, 40, 1 convex elem regenerated: 32 verts (-12.728,-14.377,5.767)..(14.691,14.377,34.684), Skin MI; centre (0.992, 0, 20.25) (Monolith) | PASS |
| hull sockets Grip_L/R | (0,-+11.82,12) rot 0 | exact, rot (0,0,0) | PASS |
| TurnipBed / TurnipBedEmpty | (-36,-36,-10.2)..(36,36,2.0597), 224 / 288 tris | err 0.0, 224 / 288, Soil MI, 1 box each = 72 x 72 x 12.26 at z -4.07 | PASS |
| Cube10 | +-5.000 | +-5.000, 12 tris | PASS |
| 16 clips keys / length / tracks / SKEL / rate / root motion / loop | `num_keys` table, N/30, 17, SKEL, 1, off, manifest loops | all equal (e.g. Scream 19 / 0.6 s, Inhale 37 / 1.2 s, AnticipateTired 10 / 0.3 s); 4 loops true | PASS |
| curve names, every clip | Inhale + Scream | 16/16; N+1 keys each (Monolith `get_sequence_curves` ROOT_Scream 19/19) | PASS |
| curve values every frame vs Blender `sk` | <= 0.001 | worst 6e-7 (ROOT_Inhale Inhale f23) | PASS |
| ROOT_Inhale | Inhale 1.0 at f30..f36 incl. last | max 1.0 at 30..36 (f28 .992, f29 .998); Scream 0 | PASS |
| ROOT_Scream | Scream 1.0 f3..f18; Inhale 1.0 f0, 0 from f3 | Scream 1.0 at 3..18; Inhale 1.0, .741, .259, 0 (f0..f3) | PASS |
| ROOT_Recover | Scream 1.0 f0, 0 from f8 | 1, .94, .82, .70, .30, .15, .07, .02, 0 (f0..f8), 0 after; Inhale 0 | PASS |
| the other 13 clips | both curves 0 on every key | max 0.0 | PASS |
| root identity (5 samples) / landmarks every frame / scale peaks | exact / <= 0.02 cm / err 0 | exact / worst 8.6e-5 cm (ROOT_Recover f4 cheek_l) over every frame of every clip / 0.0 | PASS |
| loop seams (QuietIdle, RecoveryIdle, SRC_Idle, AirborneLeafTrail) | first == last | 0.0 / 0.0 / 0.0 | PASS |
| chain (10 manifest links + 2 note ends) | 0 | 12 links, max 8e-6 cm / 2e-5 deg / 0 scale | PASS |
| cut RecoveryIdle f0 -> AnticipateTired f0 (gate) | <= 0.1 cm / 1 deg | 0.0 / 0.0 | PASS |
| cuts vs manifest (Blender) | RecIdle f0 -> Anticipate 1.95521 / 42.4622, fany 2.35608 / 41.993; QuietIdle fany -> Anticipate 0.48077 / 4.1313; RecIdle fany -> AnticipateTired 0.44542 / 2.2985 | 1.9552 / 42.462; 2.3561 / 41.993 (f44); 0.4808 / 4.131 (f30); 0.4454 / 2.299 (f15) | PASS |
| double reimport | identical readback, no `_1`, 28 owned | `reimport_b4_r2` and `_r3`: `identical: true`, all six diff lists empty, duplicates [], 28 owned (29 in root with the map), 0 dirty after; sockets survive the SK reimport | PASS |
| reload (cold read) | readback after the next restart == `review/phaseC3/readback_pre_restart.json` | NOT RUN (needs a restart) | pending |

Morph normals: the B4 SK import log again has **no morph-normal line**. The SK block (Mars.log 09.26.13) reads, in order:
- `Performing atomic reimport of [...ScreamingTurnip_R01_Mars_SK.fbx]`
- `LogFbx: Warning: Not valid bind pose for Pose (ScreamingTurnip_R01_Body) - Node ScreamingTurnip_R01_Body : Not all the deformers are stored in this BindPose`
- `Valid bind pose for Pose (ScreamingTurnip_R01_Body)`
- `Bones digested - 17  Depth of hierarchy - 5`
- the four section lines
- `FBXImport: Warning: Mesh 'ScreamingTurnip_R01_Body' has no UV set. Creating a default set.`

There is no `bUsedWithMorphTargets` line (C2 already flagged the master). The C2 source reading (morph normals recomputed,
`LODUtilities.cpp:2969/3056`) still applies; the visual effect is still not proven.

#### Morph proof (`playback_b4`; editor world, no PIE)  **confirmed**
Same transient probe as C2: in the review map at (-150, 120, 60), yaw 180. The capture camera is 72 cm in front at the
MouthCue height (24 cm x 3).

| t | morphs | anim-instance curves (Inhale / Scream) | GetMorphTarget | jaw (component) | body scale | MouthCue |
|---|---|---|---|---|---|---|
| 0.4 | on | 0.0 / **1.0** | 0 / 0 | (-2.2173, 0, 14.7246) pitch **-35.5** | (1.3, 1.0, 1.3) | (17.4836, 0, 11.2111) |
| 0.4 | off | 0.0 / 1.0 | 0 / 0 | same | same | same |
| 0.0 | on | **1.0** / 0.0 | 0 / 0 | (-1.3801, 0, 12.048) pitch 0 | (0.92, 0.88, 0.92) | (11.4144, 0, 18.1199) |

The bone values are C2's x 3 to the 4th decimal (jaw (-0.739, 0, 4.908) x 3, MouthCue (5.828, 0, 3.737) x 3, t0 jaw (-0.460, 0,
4.016) x 3). As C2 found, `GetMorphTarget` reads manual weights only, so the proof is visual:
- `UE_probe_t040_morph_on.png`: the full gape, with the rolled rim, the upper and lower tooth rows and the pink pocket.
- `UE_probe_t040_morph_off.png`, same bones: only the bone-stretched X pucker.
- `UE_probe_t000_morph_on.png`: the inhale bellows (cheek lobes out, pucker drawn in).

All three were looked at. Shapes match the B3/B4 `ROOT_Scream_sheet.png` f0 / f12.

#### Review room (`ScreamingTurnip_R01_Review_MAP`)  **confirmed** (re-opened from disk, `review/phaseC3/review_map_readback.json`)
New `replace_displays()` in `screaming_turnip_review_ue.py` moves the six existing display actors; it deletes and spawns
nothing, and leaves entities, lights, walls and the PlayerStart alone. It saves only the review map and refuses if any
package is dirty first. Placements now derive from the manifest (`SOIL_LINE_Z` 28.8, `BED_BOTTOM` = -bed min z = 10.2, `BED_W` 72,
`SIDE_Z` = bulb w_y / 2 = 14.0065, `SCALE` 3.0), so `build_review_scene()` follows the asset too. The 16 cm values stand in
brackets in the file. Moves (from -> to):
- `Display_PlantedBed` (150,200,3.4) -> (150,160,10.2)
- `Display_Planted_SK` (150,200,-6.2) -> (150,160,-18.6), the root 28.8 below the soil line
- `Display_Bed` (150,300,3.4) -> (150,280,10.2)
- `Display_BedEmpty` (150,400,3.4) -> (150,400,10.2), beds 72 cm wide with 48 cm gaps
- `Display_OnSide_SK` (150,-200,4.6) -> (150,-200,14.0065)
- `Display_HandHeight_SK` unchanged (-205,0,135): its root stays 45 cm from the start, the B4 fp-mock distance

Bed boxes after the move are z 0..12.26 (on the floor). The only overlapping display AABBs are the planted SK and its own bed
(by design). The map was re-opened from disk: 18 actors, GameMode override intact, the positions above. The view framings in
`_views()` are the Phase C offsets x `SCALE`, except `beds`, which is framed for the two 72 cm beds.

#### Captures (look at these)
- `review/phaseC3/playback/UE_probe_t040_morph_on.png` vs `UE_probe_t040_morph_off.png` (the morph isolated), and
  `UE_probe_t000_morph_on.png` (inhale). The amber key over-exposes them; read them for shape.
- `review/phaseC3/room/UE_review_{room_from_playerstart, fp_hand_height, planted_front, planted_threequarter, beds, onside,
  hand_mouth_closeup}.png`.
  - Looked at: `room_from_playerstart` (the 48 cm hand-height turnip fills most of the frame at 45 cm), `planted_front`,
    `planted_threequarter` (pink shoulder and leaves above the soil), `beds` (both on the floor, apart), `onside` (bulb on the
    floor) and `hand_mouth_closeup` (closed X pucker).
  - Not looked at: `fp_hand_height`.
- `review/phaseC3/UE_SK_{front,threequarter,mouth_closeup}.png`: Monolith `capture_scene_preview`, bind pose, explicit cameras
  for 48 cm. The preview scene is still lit from behind, so the front is dark (as in C/C2). I looked at front and threequarter;
  I did not look at mouth_closeup.

#### Decisions / deviations (low-blast; say if you want them changed)
- C3-1 Room displays were moved, not rebuilt. `build_review_scene()` would also respawn the two bed entities and the lights;
  the move touches only what grew. The rebuild path is updated and would give the same placements.
- C3-2 `Display_HandHeight_SK` kept at 45 cm from the start (root), as in the B4 fp mock. Its mouth surface is then about 29
  cm from the start axis; the display has no collision.
- C3-3 On-side rule unchanged from Phase C: bulb flank on the floor. With bind-pose leaves at y +-20.04, the leaf tips would
  reach about 6 cm below the floor plane (inferred from the bind bounds; Phase C had the same at 2 cm). Knob: `SIDE_Z` in the
  review module (20.04 makes no leaf penetrate and floats the bulb 6 cm).
- C3-4 Bed spacing 48 cm (`BED_GAP`), planted bed moved to y 160 so the third bed stays at 400.

#### Incidents
- None. No crash, no modal left open (Monolith logged auto-dismissed modals), no foreign dirty package at any point.
- Moving actors through Python did not mark the review map dirty. `save_current_level` wrote it anyway (umap 04:29:51), and the
  cold re-open proved the positions.
- Side effect, as Phase C: the CkJolt on-save cook rewrote `/Game/CkJoltData/ArtCandidates/ScreamingTurnip/R01/Review/
  ScreamingTurnip_R01_Review_MAP/{JoltCell_0_0, JoltIndex}` (04:29:53), outside the owned root.
- Log noise: only `CkLogger: Error: Could not find the Logger [CkAbility]` on each review-map load (pre-existing since Phase C).
- The bed entities (`Bed` at the origin, `SecondBed`) render their own bed and turnip from the Script constants. In the
  captures they are still the pre-B4 size next to the 48 cm displays. Inferred: the Script `k_*` numbers are Phase H's re-tune.
- Readback JSON keys: `readback`/`reimport` = Phase B and `*_b3` = C2 (16 cm, superseded). `playback_read` holds only the last
  read; `playback_b4` holds all three.

#### Not verified
- Cold reload in the next editor session: run `screaming_turnip_import_ue.py reload` and expect `readings_match: true` and an
  empty `hash_diff` vs `review/phaseC3/readback_pre_restart.json`.
- Motion: only paused frames (0.0 / 0.4 s) were evaluated. Playback, the B3-1 band frame and the rim-corner shading (C2 note)
  are for PIE in Phase H, under neutral light.
- Runtime: kernel phase -> PlayAnimation -> curves at the 48 cm size; the Script grip/held/planted numbers still have to be
  re-tuned (manifest `gameplay_numbers`, Phase H).
- The claim I'd most expect to be wrong: that the on-side display reads as resting, not sunk (C3-3). Leaf-tip penetration is
  inferred from bounds, not seen; in `onside.png` it looks grounded.

## Audit of Phase C3 (Fable, 2026-11-06) - ACCEPTED

Readback every row PASS against the refreshed manifest (bone heads x3 within 0.0001 cm, bounds, 6 cm margin, six
sockets exact, hull/beds, 16 clips' curves within 6e-7, cuts match the manifest), double reimport identical, morph
on/off proof repeated at x3, review-room displays re-placed from the manifest and verified from a cold re-open.
**confirmed** from the executor's table and file list. Owed: cold-reload stage (next editor restart); the two bed
entities still at the 16 cm Script numbers (Phase H); on-side display leaf tips ~6 cm under the floor (inferred,
`SIDE_Z` knob). Phase H launched.

## Phase H - x3 re-tune, AnticipateTired, morphs in game, final PIE (run-03), verification report (brief: `PHASE_H_BRIEF.md`)

### Phase H executor report (Opus, 2026-11-06) - DONE, awaiting Fable audit
Report: `VERIFICATION.md` (T01-T18 matrix, gates, deferred items, maintainer steps). No git. The editor stayed open,
Sandbox_Mars_MAP was restored, and 0 dirty packages were left before and after every level operation. No Content/ write.
No kernel change. Every claim is **confirmed** (evidence named) or **inferred**. `pie3/` = `Tools/LevelDesign/screaming_turnip_r01_review/captures/pie/run-03/`.

#### Files
- `Script/Items/Mars_Item_ScreamingTurnip.as`
  - Deliverable 0 numbers (table below).
  - New `k_HeldLocation`.
  - New `k_Clip_Anticipate` / `k_Clip_AnticipateTired`.
  - `PickupProbeRadius` 21.
  - Comments now carry the x3 sizes.
- `Script/WorldObjects/Forage/Mars_ScreamingTurnipBed_EntityScript.as`: release point, probe extents and offset, comments.
- `Script/Items/Presentation/Mars_ScreamingTurnipPresentationComponent.as`
  - The tired-warning choice: `_DrawnPhase` and `_AnticipateFrom`.
  - `FMars_ScreamingTurnip_PresentationQuery`: four inputs, so `Get_WantedClip` keeps the three-parameter rule.
  - `Get_PlayingClip()`.
- NEW `Script/Tests/ScreamingTurnip/Mars_AutoTest_ScreamingTurnip_TheWarningAfterARecoveryPlaysTheTiredAnticipate.as`.
- `Tools/LevelDesign/screaming_turnip_r01_review/screaming_turnip_pie_ue.py`
  - x3 camera distances.
  - Curve values in `clips()`.
  - New `sequence` / `step_*` / `harvest_steps` / `morph_probe` / `slomo`.
  - `begin(check_throttle=False)`, used for the capture runs only.
- Not edited: the acceptance helper (the curve read went through Python's `get_curve_value`) and the map builder (below).
- Side effects, not authored by me: the live editor regenerated `Script/Generated/Mars_AutoTestActors.as` and
  `Mars_EntitySpawnParams.as` for the new test (Mars.log 09.38.36 compile lines). Its populator may also have touched the
  already-dirty `AutoTests_Mars_MAP.umap` (**inferred**, as in Phases D/E/G).

#### Deliverable 0 - every changed number and its source (`export/ScreamingTurnip_R01_Manifest.json` line)
| what | was | now | source |
|---|---|---|---|
| `k_GripLocation_R` | (0, -3.94, 4.0) | (0, -11.82, 12.0) | `gameplay_numbers.k_GripLocation_R` :1947 (yaw 180 `k_GripRotation` unchanged) |
| `k_GripLocation_L` | (0, 3.94, 4.0) | (0, 11.82, 12.0) | `k_GripLocation_L` :1952 |
| `HeldOffset` | (14, 0, -12) yaw 180 | `k_HeldLocation` (14.661, 0, -25.5), yaw 180 | `HeldOffset_location` :1990, `_rotation` :1995 (hull centre at the 16 cm hand-frame place); PIE kept it (below) |
| `k_PlantedOffset` | (0, 0, -9.6) | (0, 0, -28.8) | `k_PlantedOffset` :1969; PIE clip readout `at [.., .., -28.8]` on both beds |
| bed `k_ReleasePointOffset` | (0, 0, 20) | (0, 0, 60) | `k_ReleasePointOffset_suggestion` :1984 |
| bed `k_ProbeHalfExtents` / `k_ProbeOffset` | (30, 30, 20) / (0, 0, 10) | (40, 40, 22) / (0, 0, 12) | derived: `bed.outer_size_cm` 72 :1975 (half 36 + 4), `bed.bottom_z` -10.2 :1981, top = `dimensions_cm.global_clip_envelope` max z 61.789 :163 - `planted.soil_line_z` 28.8 :1414 = 33.0 -> Z -10..+34 |
| `ReleaseLaunch` / `ReleaseSpinDeg` | (120, 0, 170) / (0, 0, 270) | unchanged | PIE: from the 60 cm release point the 48 cm root lands 77.6 cm out on its side (up z 0.49), mouth (-0.88, 0, 0.48) back toward the bed and up, LooseSettled 2.2 s after spawn; both beds identical (`pie3` F3, F9) |
| `PickupProbeRadius` | 40 (default) | 21 | `PickupProbeRadius_suggestion` :2002; read only without a Mesh (`Mars_WorldItem_Utils.as:391/:406`), so no behaviour change |
| driver `chase_view` offset | (-60, -70, 40) | (-180, -210, 120) | `scale_factor` 3.0 :1946 |
| driver `mouth_view` distance / lift / centre | 38 / 8 / up x 6 | 114 / 24 / up x 20.25 | `scale_factor`; `hull_centre_offset_from_root` z :1958 |
| map builder bed spacing | second bed +1000 X, PlayerStart -250 | unchanged | 72 cm bed + 78 cm hop fit in the 1000 cm spacing; from -250 the prompt shows at -133 (F1). The live review map (Python-built) has its beds at (0,0) and (450,-450); the yields land at (76.6,-12.4) and (526.5,-462.4), clear of every display |

Gates for Deliverable 0: `ScreamingTurnip` 10/10 (`Test-TurnipH-ScreamingTurnip`) and `GripPoint` 5/5 (`Test-TurnipH-GripPoint`).
The GripPoint tests compare against the definition's own values, so no test edit was needed (**confirmed**, read in Phase G).

#### AnticipateTired (deliverable 1) - DONE, test + PIE
- How it works:
  - The component records the phase it last drew (`_DrawnPhase`).
  - On the change into Anticipate it stores where that came from (`_AnticipateFrom`).
  - `Get_WantedClip(Query)` plays `k_Clip_AnticipateTired` when it came from RecoveryIdle or Recover, else `k_Clip_Anticipate`.
  - The per-tick re-read keeps the stored choice until the phase changes.
- Deviation H-DEV-1, decision I made: the transition is observed by the component, not taken from `OnPhaseChanged`'s
  `prev`.
  - Reason: the entity script, which forwards the signal, is outside this phase's edit list. A second binding inside the
    component would race the entity script's refresh.
  - The two differ only when one kernel pass skips a phase. The drawn phase is then the right input anyway, because the
    cut starts from what is on screen.
  - Say if you want the signal route; it is an entity-script edit.
- Test `TheWarningAfterARecoveryPlaysTheTiredAnticipate` is green.
  - It needs the SK, which loads headless.
  - Sampled every poll: Anticipate, then Tired, then Tired; one clip per phase.
- PIE: every RecoveryIdle -> Anticipate played Tired (27.667, 37.191, 46.808 ...). Dormant -> Anticipate played the full
  clip after landing (18.146), after a throw (145.416), after the disturbance (243.093), and after a pickup or unstow
  resume (267.063, 273.792). **confirmed** (`pie3/run.json`).
- Known: a pickup during a Tired warning resumes the kernel mid-warning but plays ROOT_Anticipate from frame 0 (266.7 ->
  267.06). This is the existing Transfer -> Dormant behaviour; inferred acceptable.

#### Morph playback in game (deliverable 2) - confirmed, no fix needed
- The anim instance curves read `Inhale` 1.0 at the inhale peak (Inhale t 1.13-1.16) and `Scream` 1.0 at the scream peak
  (Scream t 0.23-0.24), both settled (3 cycles) and held.
- `GetMorphTarget` reads 0, as Phase C2 found: it holds manual weights only. `disable_morph_target` is false.
- The captures show the morph-only shapes: the inhale cheek lobes and the rolled rim with both tooth rows.
- Evidence: `pie3/sheet_F4_settled_mouth.png`, `sheet_F6_held_fp.png`, and the `morph` rows in `pie3/run.json`.

#### run-03 step table (review map; game s from `begin`; 09.43 - 09.48 UTC; 9680 frames sampled, 41 at or above 0.1 s, max 0.40 s, each one a run_python or screenshot call)
| step | what | measured | verdict |
|---|---|---|---|
| F1 | walk to -133, aim at the bed | `focused=true`, "Pull Screaming Turnip" prompt (`F1_prompt_bed1.png`) | PASS **confirmed** |
| F2 | LMB 4.582 - 5.135 | Tug -> Cancel 5.162 -> SRC_Idle 5.432; charges 1, no yield | PASS **confirmed** |
| F3 | LMB 15.227 - 16.402 | yield 15.934 (0.707 s); bed exhausted; root at bed + (76.6, -12.4, 3.1), 77.6 cm, side, mouth to the bed and 28 deg up; LooseSettled 18.146 with ROOT_Anticipate | PASS **confirmed** |
| F4 | settled, mouth camera | commits on the kernel clock 3.717 / 13.227 / 22.865 / 32.454 / 42.067 ...; unhitched intervals 9.510 - 9.523, the three screenshot-hitched ones 9.59 - 9.64 (0.23 s frames on the commit tick); pose unchanged; Tired every later warning | PASS **confirmed** |
| F5 | pickup tap 100.617 | Transfer/Held 101.028, Held + RecoveryIdle 101.318 | PASS **confirmed** |
| F6 | held, first person | presentation fwd (-1, 0, 0.04) vs view (1, 0, -0.04): the face is toward the holder; held intervals 9.509 (across the pickup) / 9.505 / 9.522 | PASS **confirmed** |
| F7 | throw in the Inhale (t 0.316) and in the Scream (t 0.08 press, 0.49 release) | both silent in flight; the committed seq 17 is kept; the next Anticipate = commit + 8.007 | PASS **confirmed** (T06) |
| F7b | root 2 thrown into root 1 during root 1's Inhale | one Loose and one re-settle, a fresh ROOT_Anticipate, a scream 1.541 s later; walking into a root does not move it (the capsule is blocked) | PASS **confirmed** (T07) |
| F8 | pick up, stow (Two), 5.4 s, unstow (One) | Transfer -> Protected (silent) -> Transfer -> Held, a fresh warning of 1.512 s; it rides the Back point at the belt (`crop_F8_stowed_3p.png`) | PASS **confirmed** |
| F9 | harvest bed 2 | second root at the same bed-relative pose; seq independent of root 1 | PASS **confirmed** (T17) |
| F10 | `stop_pie` 09.48.52 | 0 turnip lines after BeginTearingDown, 0 ensures in the window (Mars.log 13762-14683) | PASS **confirmed** |

#### Motion clip (`run-03-clip/`)
- Attempt 1 (`frames/`, 2 frames): the first ReadPixels hit the engine ensure `InRHITexture` (`D3D12RenderTarget.cpp:617`) at
  09.49.11 and the editor stalled 129 s. This is the bat's known once-per-callsite ensure; not turnip code.
- Attempt 2 (`frames2/`, 217 frames): `begin()` refused the 0.15 s capture frames as "throttled", so no harvest happened.
- Attempt 3 (`frames3_far_camera/`): the cycle was captured but the camera stood 112 cm away; the root was too small to judge.
- Attempt 4 (`frames4/`, 259 frames, `ok: true`, 0 ensures):
  - Camera 75 cm in front of the mouth, aimed on settle.
  - slomo 0.15 over warning / scream / recover, 1.0 over RecoveryIdle; about 0.05 game s per frame.
  - It covers fresh Anticipate -> Inhale -> Scream -> Recover -> RecoveryIdle -> AnticipateTired -> Inhale -> Scream ->
    Recover.
  - Sheets: `strip_cycle1_inhale_scream_recover.png` (frames 76-102), `strip_cycle2_recoveryidle_to_tired.png` (127-153),
    `strip_cycle2_tired_anticipate_scream.png` (155-199).
- What I see, my judgement:
  - The scream snaps open with one squarish in-between frame.
  - Through the held gape the leaves and bulb jitter frame to frame. That is the shake, but its 15 Hz is not resolvable
    at about 20 Hz of game sampling.
  - Recover closes in about three frames through the squarish B3-1 frame: quick, not a pop.
  - AnticipateTired lifts the drooped leaves smoothly with no jump at the cut.
  - The capture views have no HUD (scene-only read).

#### Look at 48 cm (my judgement from the captures named)
- Held, first person (`pie3/crop_F6_held_fp.png`, `sheet_F6_held_fp.png`):
  - The face points at the camera. The pucker, the inhale lobes and the gape all read clearly at hand distance.
  - The gloves cup the lower flanks 23.6 cm apart; the Cradle layout reaches that wide.
  - The root sits low: the mouth is in the lower third of the frame and the taproot tip near the bottom edge.
  - The manifest HeldOffset is kept. Raising it is `k_HeldLocation` Z.
  - The inhale cheeks swell out over the glove cuffs (overlap, not checked for interpenetration).
- Settled (`sheet_F4_settled_mouth.png`): side-lying, the mouth toward the bed and up; the warning reads in silhouette and
  shape.
- Rim corners: a darker violet patch inside the upper-left rim and grey wedges at the corners at full gape. Mild under the
  review light. The cause is still the C2 inference (recomputed morph normals); not proven.

#### Gates
Toolbox v1.73 test-only path, quiescence checked before each run (`Saved/Logs/Test-TurnipH-*.stdout.txt`). "Final" ran on
the final code, after the last (comment-only) bed edit reloaded at 09.59.01.
| pattern | result | knownReds |
|---|---|---|
| ScreamingTurnip, final | 10/10 (9 earlier + 1 new), exit 0 | none ran, no new failure |
| Cookbook, final | 5/5, exit 0 | none ran, no new failure |
| WorldItem, final | 25/25, exit 0 | none ran, no new failure |
| ScreamingTurnip, iteration | 10/10 | none ran, no new failure |
| GripPoint, after the x3 grips | 5/5 | none ran, no new failure |

The baselines are the Phase G counts (ScreamingTurnip 9/9, WorldItem 25/25) and Phase E (Cookbook 5/5). No delta except
the new test. No full gate was run (maintainer rule).

#### Not verified
- The motion clip's shake frequency.
- Wall clipping (T14), rapid re-grabs (T08), the two-interactor race (T02), full inventory (T16), networking (T18).
- The cold asset reload after a restart (C2/C3 owed).
- Audio (none exists).
- The third-person held view at 48 cm (no capture this run).
- The claim I would most expect to be wrong: "the RecoveryIdle -> AnticipateTired cut does not pop". At the capture's 0.05
  game-s sampling, a 1-2 frame pose jump of 0.45 cm / 2.3 deg (the manifest's worst any-frame cut) would not show.

## Audit of Phase H (Fable, 2026-11-06) - ACCEPTED; stalk-grip addendum in progress

Looked at `captures/pie/run-03/sheet_F6_held_fp.png` (pucker / cheeks over the cuffs / full gape, facing the holder)
and `sheet_F4_settled_mouth.png` (side-lying warning and scream). Gates re-read from `Saved/Logs/Test-TurnipH-*`:
ScreamingTurnip 10/10, Cookbook 5/5, WorldItem 25/25, GripPoint 5/5. `VERIFICATION.md` headline and T01-T18 table
read: 10 PASS, 5 PARTIAL, 3 NOT RUN, T11-T13 out of scope. **confirmed**. H-DEV-1 accepted (the component tracks its
own last-drawn phase; the kernel's phase trail broadcasts every step, so the two agree except across a skipped phase,
where the choice is moot). Maintainer request from PIE (gloves under the ground on the pull) -> the bed registers
grip nodes at the HarvestGrip stalk sockets (Phase H resumed with the addendum).

#### Addendum (coordinator request during Phase H): the pull's gloves take the leaf stalks
Maintainer report from PIE: the gloves reached under the ground on the pull.

**Change.**
- `Mars_ScreamingTurnipBed_EntityScript.as` gains `AddHarvestGrips`. It registers a grip table on the bed entity (the
  interactable's owner) with `utils_fphands::Add_Grips`, as the Station entity script does. There are two entries,
  Right and Left. Each is a scene node under the bed root with Frame `Node`, Roll `Fixed`, pose `Power`.
- `constants_screaming_turnip_assets` gains `k_HarvestGripLocation_R` / `_L`.
- The Use interaction is unchanged: Timed 0.7 s, `RequiresFreeHands`, AfterCompletion, ReachKind Hold. Only the glove
  targets change.

**Node transforms used** (bed-root local = the manifest socket's root-relative position + `k_PlantedOffset` (0, 0, -28.8)):

| node | manifest source | root-relative | bed-local location | rotation |
|---|---|---|---|---|
| `ScreamingTurnipBed.HarvestGrip_R` | `sockets.HarvestGrip_R` (manifest :1323; crown-relative (-1.522, 4.683, 3.385)) | (-1.522, 4.683, 38.035) | (-1.522, 4.683, 9.235) | `Make_GripRotation(Right, fingers +X, palm -Y)` |
| `ScreamingTurnipBed.HarvestGrip_L` | `sockets.HarvestGrip_L` (manifest :1304; crown-relative (-1.522, -4.683, 3.385)) | (-1.522, -4.683, 38.035) | (-1.522, -4.683, 9.235) | `Make_GripRotation(Left, fingers +X, palm +Y)` |

- The rotation puts the fingers round the stalk from the bed's -X side (where the review approach comes from) and turns
  the palms in toward the crown.
- The manifest has R on +Y and L on -Y. That matches a player facing +X; from the bed's far side the hands would cross.
  Inferred acceptable for now.
- **The nodes are static at the bind-pose sockets: they do not ride the SRC_Tug dip.** Making them follow the planted
  component's `HarvestGrip` sockets would need a per-tick transform write the bed does not have today. Not done.

**PIE** (`Tools/LevelDesign/screaming_turnip_r01_review/captures/pie/run-03-pull/`, review map, 10.08-10.11 UTC; 0 ensures
in the window, Mars.log 17625-18001; Sandbox restored, 0 dirty):
- Bed 2 at (450, -450, 0). At game 36.028, 0.48 s into the press, the gloves' `grip_r` bone was at (448.5, -445.3, 9.2)
  and `grip_l` at (448.5, -454.7, 9.2). The nodes' world positions are (448.478, -445.317, 9.235) and (448.478, -454.683,
  9.235), so each glove sits on its stalk node.
- The lowest glove point that frame was the pinky tips at z 4.3. The floor is 0 and the bed top 2.06, so **no glove part
  is under the soil**. Per-tick bone samples are in the session (`gloves` rows); the frame's row is in `run.json` event
  `P6_bed2_cancel_t012`.
- Capture `crop_P6_bed2_t012.png`: both gloves are closed on the crown among the leaf stalks, above the bed, under the
  focus tint. My judgement: the 9.4 cm stalk spacing puts the two big gloves against each other (palms together); they
  read as grabbing the leaves.
- Bed 1's pull (`P1_pull_cancel_t040.png`) was captured too late: the root was already out.
- Driver note: a `Shot` takes about 0.3 s of frame, so a press meant to cancel at 0.35-0.45 s completed the 0.7 s pull
  on both beds. Both beds were harvested; there is no SRC_Tug-mid capture with the root still planted.

**Gates** (`Saved/Logs/Test-TurnipH-Grips-*.stdout.txt`, on this code): ScreamingTurnip 10/10, FPHands 34/34, Forage 9/9, each exit 0, no known red ran, no new failure. Cookbook 5/5 and WorldItem 25/25 ran before this addendum. The addendum touched only the bed script and two new constants, which neither pattern loads (**inferred**; not re-run).

## Campaign close (Fable, 2026-11-06)

Stalk-grip addendum accepted on the measured placement (grip bones within 0.1 cm of the nodes, lowest glove point
z 4.3 above the floor; `Test-TurnipH-Grips-*`: ScreamingTurnip 10/10, FPHands 34/34, Forage 9/9). Mid-tug look
unverified (capture taken after the harvest, from afar); the gloves press palm to palm at 9.4 cm stalk spacing
(`k_HarvestGripLocation_*` in `Mars_Item_ScreamingTurnip.as` is the knob). Nothing committed; the campaign's dirty
paths are new files plus the FPHands/WorldItem/Interactable/Presentation edits of Phase E and the editor-regenerated
Generated/*, AutoTests map, DefaultGameplayTags.ini. Maintainer steps: PIE the review map / BuildReviewRoom in the
sandbox; rule on HeldOffset Z, stalk grip spread, a third mouth round; run the importer's `reload` stage after the
next editor restart; decide what to commit (per-repo, explicit pathspecs; never the Generated files or the autotest map).

## Phase I (Fable script side, 2026-11-06): the gloves ride the pull; the pull is 1.4 s

**Ruling** (maintainer, with three concept sheets - Reach / Grip / Load tension / Break free / Recoil / Recover): "I would
expect the hands to kinda follow the motion of the pull. Increase the interaction time by 2x to make it easier to test and
validate."

**Measured before deciding** (`export/anims/expected_anims.json`, UE cm): the HarvestGrip sockets ride the crown bone, and
across the pull the crown head goes 32.85 (SRC_Idle) -> 31.80 (SRC_Grip f6) -> 32.45 (SRC_Tug f7) -> 32.39 (SRC_Tug f15);
the body squashes in place (18.68 -> 17.20). Gloves following the sockets would move about 1 cm over the Tug. So the
follow is one half; the other half is a Tug with travel, which is Phase I's executor part (`PHASE_I_BRIEF.md`: crown head
to 39.5 +- 0.5 cm at SRC_Tug's last frame, the bulb planted and elongating, clip lengths unchanged).

**Script changes** (confirmed by the live editor's two soft reloads at 22:47:52 / 22:48:02 UTC, no error lines; the second
reload was the regenerated `Mars_EntitySpawnParams.as` picking up the new defaults, "first diff at line 18917"):

- `Script/WorldObjects/Forage/Mars_ScreamingTurnipBed_EntityScript.as`: `GripSeconds 0.4`, `TugSeconds 1.0` (were 0.2 /
  0.5; the clips stay authored at 0.2 / 0.5 s and are stretched to span the stages). The two grip nodes are kept
  (`FCk_Handle_SceneNode`) with their authored `Make_GripRotation` frames; a follow tick (`utils_timer::Create_Tick`, from
  the press until the root is out or the planted idle is back) writes each node's offset under the bed root every tick:
  position = the planted mesh's `HarvestGrip_R / _L` socket in the bed's frame, rotation = the authored one
  (`utils_scene_node::Request_UpdateOffset`; the nodes stay children of the root, so a moved bed still works). FPHands
  needs nothing: `Apply_HandReach` (Mars_FPHands.as:599) rebuilds each glove's `ReachGrip` every tick through
  `Make_LeanedGrip` -> `Resolve_WorldGrip`, which re-reads the anchor node (`Mars_FPHands_Grips.as:895`) - the same path
  `Mars_AutoTest_FPHands_SocketGripFollowsMovingPart` covers. A press plays the chain SRC_Grip (spanning GripSeconds) ->
  SRC_Tug (spanning TugSeconds); a cancel plays SRC_Cancel from `1 - the Tug's played alpha` (SRC_Cancel eases the full
  strain back to the rest, so its pose at 1 - a is near the Tug's at a; during the Grip, from its end - the 1 cm dip).
- `Script/Items/Presentation/Mars_ScreamingTurnipPresentationComponent.as`: `FMars_ScreamingTurnip_PresentationClip` gains
  `SpanSeconds` (TOptional; play rate = length / span, set after `PlayAnimation` which resets the rate) and `StartAlpha`
  (`SetPosition`); `Play_ClipChain` queues clips, the next starting when the playing one has played through (a Loop clip
  ends a chain; `Play_Clip` drops a chain); `Get_PlayedAlpha()`; `Get_HasPlayedThrough()` shared by the chain and
  ReturnToLoop. A play of the stem already playing changes nothing, span and start included (documented).
- `Script/Items/Mars_Item_ScreamingTurnip.as`: `k_Clip_Grip / _Tug / _Cancel / _PlantedIdle`, `k_HarvestGripSocket_R / _L`.
- `Script/Tests/ScreamingTurnip/Mars_AutoTestRig_ScreamingTurnip.as`: the rig pins `GripSeconds 0.2 / TugSeconds 0.5` on
  the bed it spawns, so the tests keep their 0.7 s and do not move with the design knob.
- `Tools/LevelDesign/screaming_turnip_r01_review/screaming_turnip_pie_ue.py`: `harvest_steps(hold=1.8)`.

**Gates** (`Saved/Logs/Test-TurnipI-{ScreamingTurnip,FPHands,Forage}.stdout.txt`, test-only path beside the open editor,
17:48-17:51 local, no .as edit during the runs): ScreamingTurnip `Passed: 10 / Failed: 0`, FPHands `34 / 0`, Forage
`9 / 0`, each exit 0, "no listed test ran in this run, and there were no new failures". Same counts as Phase H's gates.

**Not verified here**: the follow itself (needs PIE with the skeletal mesh: node-to-socket and glove-to-node distances
per tick, the executor's Part 2); the placed review-map beds taking the new defaults (they were spawned without explicit
stage seconds, so delta-serialisation should load the CDO's 0.4 / 1.0 - inferred; Part 2 measures the pull's length);
the cancel's start-alpha approximation against the Tug's mid key (judged on the Part 2 capture). Decision made rather
than asked: the follow lives in the bed (assembly layer, its own nodes and mesh), not as an FPHands "animated socket"
frame; say if a second animated grip shows up and it should move into FPHands.

## Phase I Part 1 - Blender: SRC_Tug lifts the crown (executor report, Opus, 2026-11-06) - DONE, waiting for Fable's go before Part 2

> **Superseded (Fable ruling):** the bh 1.22 strain below was replaced by the builder stem-weight fix + bh 1.06; see "Phase I Part 1b + Part 2" further down.

No Unreal, no `Script/` edits, no git. Every write is under this folder.

**Script changes**
- `scripts/animate_screaming_turnip.py`: STRAIN, a new TUG_MID, the SRC notes, a `stem_gap` audit, and a `--review` flag.
- `scripts/export_screaming_turnip.py`: a `--review` flag (picks the anim_report source and writes `crown_travel.json`)
  and `crown_travel_ue_cm` on the SRC clips in the manifest.
- `scripts/render_anims_screaming_turnip.py`: `--out`, `--views` and `--pull-chain` flags.
- New `scripts/diff_expected_anims.py`.

**Data written**
- `source/ScreamingTurnip_R01.blend`: re-animated.
- `source/ScreamingTurnip_R01_phaseH.blend`: byte copy of the blend taken before the first write (md5 d7a20d10...).
- `export/`: SK, statics, 16 clips, expected files, manifest and reports re-written.
- `review/phaseI/`, including `baseline/`: copies of the pre-Phase-I expected_anims, clips, manifest, reports and
  animate script.

**confirmed**.

#### Rerun (from this folder; each prints TURNIP_OK / TURNIP_FAIL)
```bash
B="C:/Program Files/Blender Foundation/Blender 5.2/blender.exe"
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python scripts/animate_screaming_turnip.py -- --review phaseI
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python scripts/export_screaming_turnip.py -- --review phaseI
"$B" -b --factory-startup --python scripts/validate_roundtrip.py
python scripts/diff_expected_anims.py review/phaseI/baseline/expected_anims.json export/anims/expected_anims.json \
    --expect-changed SRC_Tug,SRC_Release,SRC_Cancel --out review/phaseI/expected_anims_diff.json
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python scripts/render_anims_screaming_turnip.py -- --out phaseI \
    --clips SRC_Tug,SRC_Cancel,SRC_Release --views front,side,threequarter --no-shapekey --pull-chain
```
Final chain, all on the final code. **confirmed**.
- animate: exit 0, `TURNIP_OK (16 clips, 13 s)` (`review/phaseI/animate_log.txt`).
- export: exit 0 (`export/export_log.txt`).
- round trip: exit 0 (`export/roundtrip_log.txt`).
- diff: exit 0.
- renders: exit 0 (`review/phaseI/render_anims_log.txt`).

#### Pose numbers (pose parameters in the 16 cm design frame; crown z in UE cm, root-relative)
| pose | before (B4/H) | brief's numbers (tried, rejected) | after (shipped) |
|---|---|---|---|
| STRAIN | bh 0.90, bw 1.10, bdz -0.6, cr_dz 0.9, la -12, lb -7; crown 32.385 | bh 1.06, bw 0.96, cr_dz 1.545; crown 39.500 | **bh 1.22, bw 0.90, bdz -0.6, cr_dz 0.077, la -12, lb -7; crown 39.50** |
| SRC_Tug f8 | STRAIN with bh 0.93, bw 1.07, cr_dz 0.6, la -10, lb -6; crown 32.50 | bh 1.03, bw 0.98, cr_dz 0.74; crown 36.00 | **bh 1.11, bw 0.95, cr_dz -0.01, la -10, lb -6; crown 36.00 (54.5 % of the lift)** |
| GRIP, PLANT, REL_OVER, REL_UNDER, NEUTRAL | unchanged | - | unchanged |

**DEV-I-1: the bulb elongates to bh 1.22, not the brief's "about 1.06" (Fable's call to accept or reverse).**
- **What went wrong with 1.06.** With the brief's numbers, every stalk base pulled out of the bulb. At Tug f15 there
  was a 1.8-2.1 cm gap under each stalk, plainly visible on the first sheet (stalks floating above a pink cone).
- **Cause.** I read the builder but did not change it.
  - The stems are weighted 100 % to `leaf_a`, which rides the crown, all the way down to their embedded base ring.
  - The bulb's top ring takes only 0.35 crown weight, and the dimple 0.6.
  - So every cm the crown gains on the body pulls the stem bases out of the bulb.
  - The old B4 strain already had a 0.5-1.1 cm gap. It was never gated.
- **Why bh 1.22.** Only the body can carry the lift without a gap, so the elongation went to bh 1.22 with cr_dz near 0.
  The sweep below hits crown 39.5 at each bh and reports `stem_gap`: the worst of the 5 stems, + = outside the bulb.

  | bh | 1.06 | 1.10 | 1.14 | 1.18 | 1.20 | **1.22** | 1.24 |
  |---|---|---|---|---|---|---|---|
  | stem_gap (cm) | +2.09 | +1.43 | +0.86 | +0.25 | -0.10 | **-0.45** | -0.66 |

- **The alternative.** Getting bh ~1.06 with no gap needs a builder change: weight the stem base ring to the body so the
  stalk itself stretches. That means an SK mesh reimport in Part 2. I did not do it; it is outside this brief.
- The crown target (39.5 cm) holds either way.

**New gate: `stem_gap`.** The animate audit now measures it on every frame of every clip. It fails the run only for
SRC_* clips.
- SRC results: Idle -0.659, Grip -0.737, Tug / Cancel / Release -0.446. Every stem is seated.
- Pre-existing on untouched clips (not gated, recorded as a follow-up): ROOT_Anticipate, ROOT_AnticipateTired and
  ROOT_Inhale reach **+0.317 cm**. The cause is the ANT pose (cr_dz 0.4 on bh 0.9).

#### Crown travel (`review/phaseI/crown_travel.json`; crown head z, UE cm, root-relative, per frame)  **confirmed**
| clip | after, f0..fN | before | largest per-frame step |
|---|---|---|---|
| SRC_Grip | 32.85 / 32.77 / 32.58 / 32.33 / 32.07 / 31.88 / 31.80 | identical | 0.25 |
| SRC_Tug | 31.80 / 31.92 / 32.25 / 32.75 / 33.37 / 34.05 / 34.75 / 35.42 / 36.00 / 36.58 / 37.22 / 37.89 / 38.50 / 39.02 / 39.37 / 39.50 | 31.80, peaking at 32.51 (f9), ending at 32.38 | 0.70 |
| SRC_Cancel | 39.50 / 39.13 / 38.17 / 36.87 / 35.46 / 34.16 / 33.22 / 32.85 | 32.38 -> 32.85 | 1.42 |
| SRC_Release | 39.50 / 38.60 / 37.05 / 35.32 / 33.93 / 34.14 / 34.65 | 32.38 / 34.79 / 37.05 / 35.73 / 33.93 / 34.14 / 34.65 | 1.73 |

- **The sockets ride the crown rigidly.** HarvestGrip_R / _L keep x -1.522 and y +-4.683 on every frame; z = crown +
  3.385. Over the Tug they rise 35.185 -> 42.886 (+7.70 cm), monotonically.
- **The socket math matches the export.** Release f6 gives 38.035, the manifest socket value.
- **Manifest.** `clips.SRC_*.crown_travel_ue_cm` carries first / last / min / max. `scale_factor` is still 3.0, and the
  SRC notes are refreshed.
- **Your cancel start-alpha** (SRC_Cancel from `1 - a`): the crown under Tug(a) vs Cancel(1 - a), sampled every 0.1:
  - a >= 0.3: Tug sits 0.05-0.58 cm below Cancel (a 0.5: 35.71 vs 36.16).
  - a 0-0.2: the gap is 0.84-1.05 cm, which is the Grip's 1 cm dip.
  - So a cancel starts within about 0.6 cm of the Tug pose once the Tug is under way.

#### Audit (`review/phaseI/anim_report.json`)  **confirmed**
- **Every frame of every clip:**
  - Intersections are 0 in every category. No lip-fold allowance was used on the SRC clips.
  - Root identity holds.
  - UE composition deviation is <= 2e-5 cm.
  - Playback equals the authored values.
- **SRC chain joints** are all 0 / 0 / 0: Idle -> Grip -> Tug -> Release / Cancel -> Idle, and Release fN ==
  ROOT_QuietIdle f0.
- **Bounds.** SRC_Tug / Cancel / Release height 51.64 -> 58.75 cm. The global envelope is unchanged at 63.589 x 42.641 x
  41.702 (the Scream sets it).
- **Soil line at STRAIN** (soil at 28.8):
  - The seam top is at 24.03, so the mouth stays 4.8 cm under the soil.
  - The bulb top is at 39.83, a shoulder 11.0 cm above the soil (planted: 4.5).
- **REL_OVER / REL_UNDER not re-tuned.** Release still settles at NEUTRAL (chain 0), and it never rises above its f0
  height.

#### Round trip  **confirmed**
- `export/roundtrip_report.json` and `export/anims/roundtrip_report.json` both end with `fails: []`.
- SRC_Tug: landmarks <= 8.7e-5 cm, extremes <= 5.4e-5, root 0.0, shape-key value error 0.0.

#### Untouched clips (diff proof)  **confirmed**
- **Command.** `python scripts/diff_expected_anims.py review/phaseI/baseline/expected_anims.json
  export/anims/expected_anims.json --expect-changed SRC_Tug,SRC_Release,SRC_Cancel`
- **Result.** Exit 0, `TURNIP_OK (3 changed: ['SRC_Cancel', 'SRC_Release', 'SRC_Tug'])`.
- Every ROOT_* clip, SRC_Idle and SRC_Grip: max abs difference **0.0** over every numeric field (landmarks, extremes,
  scale, shape-key values, peak vertices). Output: `review/phaseI/expected_anims_diff.json`.
- **Manifest diff.** Only `clips.SRC_Tug/Cancel/Release` (note, bounds_cm, crown_travel_ue_cm) and
  `SRC_Grip.crown_travel_ue_cm` changed.

#### Sheets (looked at)
- **Files** (all in `review/phaseI/`):
  - `SRC_Tug_sheet.png`, `SRC_Cancel_sheet.png`, `SRC_Release_sheet.png`: front / side / three-quarter.
  - `pull_chain_sheet.png`: Idle -> Grip -> Tug -> Release (side and 3/4), then the same into Cancel (side and 3/4).
- **Tug.**
  - The bulb domes up out of the soil and the crown rises with it.
  - The stems stay seated in the top (checked on 2x zoom crops of f15, side / front / 3/4).
  - The leaves keep their droop and do not fan.
  - The paler lower band of the bulb comes above the soil at f12-f15.
  - Honest read: it reads as the root being pulled up and stretching, and most of the lift is the bulb. The stalks do
    not lengthen, so it is not the concept's "stalks pulled straight".
- **Release.**
  - From the higher strain it now reads as a downward snap: the crown drops 39.5 -> 33.9 by f4 and the leaves flatten at
    f2. The old Release read as an upward pop.
  - It settles cleanly at neutral.
  - In game it plays while the root is launched, so the direction may not read. Judge it in Part 2's motion clip.
- **Cancel.** A smooth sink back to planted, no tearing.
- **Deformation.** No inverted faces and no leaf/stalk detachment at sheet resolution (300 px tiles, 2x zoom crops).

#### Incident
- **What happened.** My first sheet render ran before the `--out` edit took effect: an assert in my edit failed, and the
  render command was not chained to it. It overwrote `review/phaseB4/clips/SRC_{Tug,Cancel,Release}_sheet.png` with
  Phase I poses.
- **Restored.** Byte-identical from `review/phaseB4/iterations/r01_*` (same sizes, 04:17).
- **Still affected.** The B4 `_frames/` tiles for those three clips hold Phase I renders. They are intermediates only.

#### Not verified
- **Unreal (Part 2).** The clips reimport, the crown track readback, the gloves riding the sockets, and the motion read.
- **Part 2 bed-2 rule** (the crown socket never jumps more than 1.5 cm between samples). Inferred to hold:
  - Cancel's largest step is 1.42 cm per frame at 30 fps, or 0.71 at the bed's 0.5 play rate.
  - Release reaches 1.73 cm per frame at rate 1.0, but the rule does not cover Release.
- **First-person read of bh 1.22.** The bulb is 22 % taller and 22 % deeper (the rig scales x with z). The maintainer may
  prefer the stem-weight builder fix with bh 1.06.
- **The claim I'd most expect to be wrong.** That a seated stem base means no visible seam from every view. `stem_gap`
  only measures the signed distance of the 4 lowest stem vertices, and I checked the look only at 300 px.

## Phase I Part 1b + Part 2 (Opus, 2026-11-06): stems weighted to the body, STRAIN bh 1.06, SK + clips reimported, PIE run-04 - DONE, awaiting Fable audit

Fable ruled against bh 1.22 and asked for the builder stem-weight fix. **This section supersedes the bh 1.22 numbers in the
Part 1 report above.** The Part 1 crown-travel table still holds: the bone tracks are those of the brief's 1.06 / 1.545
numbers, identical to the first Part 1 run.

Constraints held:
- No git and no `Script/` edits.
- Unreal writes stayed under `/Game/ArtCandidates/ScreamingTurnip/R01/`, saved per asset by the importer.
- Driver work stayed under `Tools/LevelDesign/screaming_turnip_r01_review/`.

### Part 1b - Blender

**Stem weights** (`scripts/build_screaming_turnip.py` `build_leaf`, about l.931; 5 stems x 8 vertices = 40 vertices changed).

| stem station | vertices | before | after |
|---|---|---|---|
| s0, the embedded base ring (the 4 lowest stem vertices) | 4 per stem | leaf_a 1.0 | **body 1.0** |
| s1, the emergence ring (just above the bulb surface; the stem has one) | 4 per stem | leaf_a 1.0 | **body 0.5 / leaf_a 0.5** |
| b1, the stem-to-blade ring | 4 per stem | leaf_a 0.5 / leaf_b 0.5 | unchanged |
| blade stations | - | leaf_b 1.0 (t > 0.3), else leaf_b 0.85 / leaf_a 0.15 | unchanged |

The 0.5 crown share on s1 sits between the bulb top ring's crown weight (0.35) and the dimple's (0.6), so the stalk leaves
the bulb where the surface is.

**Rebuild proof** (new `scripts/compare_rebuild_screaming_turnip.py`; `review/phaseI/rebuild_compare.json`): the rebuilt
blend against `source/ScreamingTurnip_R01_phaseH.blend`. **confirmed**.
- Counts: 1624 vertices / 3188 triangles both sides; polygons and material indices identical.
- Positions:
  - Rest vertex max difference 0.0 cm.
  - Shape keys [Basis, Inhale, Scream]: block and offset max differences 0.0.
  - Vertex colour max difference 0.0.
- Bones: 17 / 17, head / tail / matrix max difference 0.0.
- Statics: 0.0.
- Mesh id props (mouth landmarks): identical.
- **Weights**: 40 vertices changed (stem_root 20, stem + stem_root 20), nothing else.
- Sockets: `review/phaseB4/measurements.json` against the pre-rebuild copy in `review/phaseI/baseline/` gives 1 diff, a
  1e-5 float in `scale_check`; the six sockets are identical.
- `pose_report.json`: 4 diffs, all in the info-only `attach_stem_root` embed count.
- Builder exit 0, `TURNIP_OK`, its own scale check <= 1.5e-5 cm (`review/phaseI/build_log.txt`).

Copies kept:
- The bh 1.22 blend: `source/ScreamingTurnip_R01_phaseI_part1.blend`.
- The B4 builder reports from before the rebuild: `review/phaseI/baseline/{measurements,pose_report}.json`.

**STRAIN re-tuned** (`scripts/animate_screaming_turnip.py`):
- STRAIN: bh 1.06, bw 0.96, bdz -0.6, cr_dz 1.545, la -12, lb -7. Crown head **39.50 cm** at SRC_Tug f15.
- TUG_MID: bh 1.03, bw 0.98, cr_dz 0.74, la -10, lb -6. Crown 36.00 at f8, 54.5 % of the lift.
- Crown per frame: as the Part 1 table (31.80 -> 39.50; Cancel 39.50 -> 32.85; Release 39.50 -> 34.65), **confirmed**
  (`review/phaseI/crown_travel.json`).

**Audit** (`review/phaseI/anim_report.json`, animate exit 0, `TURNIP_OK (16 clips, 13 s)`). **confirmed**.
- Every frame of every clip: intersections 0, root identity, UE composition deviation <= 2e-5 cm, chain joints 0.
- `stem_gap` per clip (max over frames and stems, cm; <= 0 = seated):

  | clip | stem_gap | clip | stem_gap |
  |---|---|---|---|
  | SRC_Idle | -0.737 | ROOT_Inhale | -0.688 (was +0.317) |
  | SRC_Grip | -0.315 | ROOT_Scream | -0.688 |
  | SRC_Tug | -0.315 | ROOT_Recover | -0.506 |
  | SRC_Release | -0.574 | ROOT_RecoveryIdle | -0.500 |
  | SRC_Cancel | -0.737 | ROOT_AirborneLeafTrail | -0.661 |
  | ROOT_QuietIdle | -0.737 | ROOT_ImpactSquash | -0.641 |
  | ROOT_Anticipate | -0.737 (was +0.317) | ROOT_SettleRock | -0.737 |
  | ROOT_AnticipateTired | -0.506 (was +0.317) | ROOT_PlaceSettle | -0.702 |

  The pre-existing +0.317 cm gap is closed.
- Envelope unchanged.

**Export** (DEV-13 recipe; exit 0) and **round trip**: `fails: []` in both reports. **confirmed**.

**Diff proof against `review/phaseI/baseline`.**
- Command: `python scripts/diff_expected_anims.py review/phaseI/baseline/expected_anims.json
  export/anims/expected_anims.json --bones-only --tol 0.0 --expect-changed SRC_Tug,SRC_Release,SRC_Cancel`
- Result: exit 0, `TURNIP_OK (3 changed: ['SRC_Cancel', 'SRC_Release', 'SRC_Tug'])`. **confirmed**.
- Every ROOT_* clip, SRC_Idle and SRC_Grip: bone landmarks (heads, root deviation, scale, shape-key values) are 0.0, and
  the skinned extremes are 0.0.
- Peak vertices change only on stem vertices: ROOT_Scream 1.218 cm, ROOT_Inhale 0.993 cm, others 0.0.
- All-frame skinned-vertex change, Phase H blend vs new (`review/phaseI/stem_weight_vertex_delta.json`): only the 40
  stem vertices move.

  | clip | max change (cm) |
  |---|---|
  | SRC_Grip | 1.246 (f6, the crown dip) |
  | ROOT_Scream | 1.220 |
  | ROOT_Recover | 1.202 |
  | ROOT_Anticipate / AnticipateTired / Inhale | 1.165 |
  | ROOT_ImpactSquash | 0.874 |
  | ROOT_AirborneLeafTrail | 0.842 |
  | ROOT_RecoveryIdle | 0.839 |
  | ROOT_SettleRock | 0.383 |
  | ROOT_PlaceSettle | 0.244 |
  | SRC_Idle | 0.131 |
  | ROOT_QuietIdle | 0.096 |

**Sheets, looked at** (`review/phaseI/`, re-rendered; `baseline/` kept):
- `pull_chain_sheet.png` and `SRC_Tug_sheet.png`: the bulb stays planted with a slight dome, and the stalks stretch
  straight up out of a peaked top. On the 2x crops of f15 (side / front / 3/4) the stalks run continuously into the bulb,
  with no gap and no tear.
- `SRC_Release_sheet.png` and `SRC_Cancel_sheet.png`: Release from the higher strain is still a downward snap that
  settles; Cancel is a smooth sink.
- `ROOT_Scream_sheet.png`, `ROOT_Inhale_sheet.png`, `ROOT_RecoveryIdle_sheet.png`, `ROOT_AirborneLeafTrail_sheet.png`:
  the stalks read as before, with no visible change at sheet resolution.

### Part 2 - Unreal (live editor, kept open)

**Preflight.** Before each stage `Mars.log` had 0 `Full Reload is required` lines (the `Full Reload: <class>` lines are
per-class records from 22.47). PIE was off, 0 dirty packages, 0 foreign dirty. **confirmed**.

**SK + statics + materials + 16 clips: `screaming_turnip_import_ue.py reimport_b4 reimport_phaseI`.**
- Stored import options synced as C2 did: import_morph_targets True, FBXNIM_IMPORT_NORMALS, vertex colour REPLACE.
- `update_skeleton_reference_pose` stayed True, as stored since C2. The bone heads are unchanged, so it changes nothing,
  and the readback asserts it (`bone_heads_vs_blender` and `bone_heads_vs_phase_c_readback` PASS).
- Every readback group PASS, duplicates [], foreign dirty [].
- Owned assets rewritten 18:04:25-28: SK, SKEL, 3 statics, 16 clips.
- Diffed against C3's `readback_b4`:
  - Material, mesh, statics, owned-asset and root-asset readbacks identical.
  - Clip readback: 46 diff lines. All are in SRC_Tug / SRC_Cancel / SRC_Release (scale peak 0.9 / 1.1 -> 1.06 / 0.96,
    landmark-worst locations), plus 2 chain-note `rot_deg` 1e-5 vs 2e-5.
  - ROOT_* clips, SRC_Idle and SRC_Grip: no diff. Curve peaks unchanged.

  **confirmed** (`export/unreal_readback_final.json` key `reimport_phaseI`).
- **SRC_Tug crown track.** The clip readback compares every landmark bone head of every frame with
  `expected_anims.json`. Worst 8e-5 cm (leaf_01_b f7), so the crown's last-frame head is 39.50 within 1e-4 of
  `crown_travel.json`. **confirmed** through the importer's per-frame landmark check (no separate crown-only row).
- **Monolith reads.**
  - Morph targets [Inhale, Scream].
  - 3188 tris, 9536 render verts, 17 bones.
  - 6 sockets on their bones, values identical to C3 (HarvestGrip_L/R crown (-1.522, -/+4.683, 3.385)).
  - Bounds (-27.69, -28.04, -8)..(26.21, 28.04, 68).

  **confirmed**.
- Snapshot refreshed by `readback_b4`: `review/phaseC3/readback_pre_restart.json`, so the pending cold `reload` compares
  against the current assets. The C3 file and the full C3 readback JSON are kept in `review/phaseI/baseline/`.
- Skin weights are not read back by the importer. That the new weights landed is shown by the PIE look below (stalks
  stretch, no gap). **inferred** from the captures.

**PIE.** Driver addition: `Tools/LevelDesign/screaming_turnip_r01_review/screaming_turnip_pull_ue.py`. It samples per tick
the planted component's clip / t, the HarvestGrip_R / _L sockets and the crown, plus the glove `grip_r` / `grip_l` bones.
The grip nodes are private ECS handles of the bed script, unreadable from Python, so **node-to-socket is not measured**;
the bed writes them from the socket each tick (`DoMove_GripNode`), and glove-to-socket is measured end to end.

- `run-04-pull` (`captures/pie/run-04-pull/`: `run.json`, `pull_rows.json`; 381 samples, about 20-25 fps under the
  sampler).
  - **Pull length (bed 2's second press, no screenshots: the clean sample).**
    - SRC_Grip 12.663 -> 13.074 = **0.41 s**.
    - SRC_Tug 13.074 -> root out at 14.039 = **0.97 s**.
    - Tug position advances 0.461 over 0.921 game s = **0.50 rate**.
    - Bed 1 agrees: 0.42 s + 0.95 s.

    The placed beds took the new defaults (not 0.7 s). **confirmed**.
  - **Sockets rise across the Tug**: bed 2 6.47 -> 14.02 (**+7.55 cm**); bed 1 6.46 -> 13.97 (+7.51). The last sample
    before the root pops is at Tug t 0.48, crown 39.43 root-relative. **confirmed**.
  - **Glove-to-socket once reached** (from about 0.17 s into the Grip):
    - Same-frame distance: max 0.53 cm (bed 2 full), 0.42 (bed 1 between hitches), 0.57 (bed 2 before the cancel).
    - Glove at frame n vs socket at frame n-1: **0.000 cm** in every sample. The gloves sit exactly one frame behind the
      sockets.
    - The 0.53 cm is one frame of socket travel (about 0.5 cm per 50 ms tick at mid-Tug), within the brief's one-frame
      lag.
    - On the two 0.32-0.34 s screenshot-hitch frames it reads 2.9-3.0 cm (one long frame of travel).

    **confirmed**.
  - **Clip rows.** SRC_Idle -> SRC_Grip -> SRC_Tug, then the planted component is hidden at the yield and the item plays
    its ROOT clips. **SRC_Release never plays on the bed**: the planted component stays on SRC_Tug t 0.5, invisible.
    This was so before Phase I too (Script side). **confirmed** (rows).
  - **Bed 2 cancel.**
    - Press 7.975, let go 8.994 (1.02 s held; Tug t 0.297, alpha 0.59).
    - SRC_Cancel's first sample t 0.084 (alpha 0.36). The crown socket steps **+0.46 cm up** at the switch: the Cancel
      pose at 1 - a sits above the Tug pose at a, as the Blender table predicted (0.45 cm at a ~0.5).
    - Cancel then plays at rate 1 (0.233 s): crown socket 11.56 -> 9.44 in one 64 ms frame (**2.12 cm**), then -> 7.44
      across a 0.37 s screenshot frame, then SRC_Idle at 9.531.
    - **Fails the brief's "<= 1.5 cm between consecutive samples"** at this sampler's 15-20 fps. Peak speed 33 cm/s; at
      60 fps that is about 0.55 cm per frame (inferred).
    - **The gloves do not ride the cancel down**: 0.46 cm on the first Cancel sample, 23 cm 64 ms later, 93 cm at rest.
      The interaction ends on the let-go and FPHands returns the hands. A Script-side behaviour, measured, not changed.

    **confirmed** (rows).
- `run-04-pull-strain` (`captures/pie/run-04-pull-strain/`, slomo 0.2 over bed 1's pull so the end-of-frame Shot lands
  before the yield).
  - `S1_tug_mid_fp.png` and `S2_tug_end_full_strain_fp.png` (first person, HUD prompt visible).
  - `S3_tug_end_side.png` (side chase view at Tug t >= 0.47) and `crop_S2_S3.png`.
  - In the side view the stalks stand straight and stretched out of a slightly peaked pink dome on the bed, with no gap
    between stalk and bulb.
  - In first person the two gloves close on the stalks from above, and the dome is hidden by the gloves, the yellow focus
    tint and the prompt. **The dome cannot be judged from first person.**
  - run-04-pull's `I3_tug_end_full_strain_fp.png` landed after the yield (the root mid-air, motion-blurred): the
    screenshot lag. Superseded by S2 / S3.
- Movement clip `run-04-pull-clip/` (`capture_pie_movement_clip`, 9 s, 29 frames; a probe drives bed 1's pull and sets a
  side view at 150 cm; `ok: true`, 28 valid frames, no must-absent hits).
  - Sheets: `clip_contact_sheet.png`, `strip_tug_side_f15_f21.png`.
  - My read: the root rises out of the soil over about 4 captured frames (Grip with the leaves splayed, then the stalks
    lengthening upward and the dome growing), then the bed is empty and the root is airborne (frames 20-27).
  - Smooth but coarse: only about 3 captured frames per real second, because the capture's ReadPixels slows the game.
  - The first-person gloves do not render in the side view.
- Captures in `run-04-pull/`: `I1_grip_end`, `I2_tug_mid`, `I4_after_release`, `I5_bed2_cancel_press`,
  `I6_bed2_cancel_plus02`, sheet `sheet_I1_I5_I6_I4.png`. I6 shows the gloves already on their way back.
- **Ensures.** Mars.log 19338-20084, covering run-04-pull, run-04-pull-strain and the clip session: 0
  `Ensure condition failed`, 0 errors (excluding the known `CkAbility` logger line), and no InRHITexture ensure this time.
  **confirmed**.

**Not restored: the review map is still loaded and dirty.**
- `/Game/ArtCandidates/ScreamingTurnip/R01/Review/ScreamingTurnip_R01_Review_MAP` has been dirty since the SK reimport:
  the display actors re-registered. I made no authored change to it.
- `load_level` Sandbox with `dirty_policy: discard` was **refused by the session's permission classifier** (irreversible
  local destruction). I did not save the map either: that writes the CkJolt side files outside the root.
- **0 dirty packages outside the owned folder.** Fable's call: save the map (owned; CkJolt rewrites its two side files) or
  discard it, then load the Sandbox.

### Not verified
- Node-to-socket distance (no Python path to the bed's private node handles); covered only end to end by glove-to-socket.
- The dome at 1.06 from first person: the gloves and prompt hide it. The side view shows a slight peaked dome.
- The Cancel's "<= 1.5 cm per sample" fails at this sampler's frame rate. The gloves leave on the cancel instead of riding
  it down (Script side: the interaction ends on let-go).
- Skin weights in Unreal are inferred from the look, not read back.
- Cold `reload` after an editor restart: still pending, against the refreshed snapshot.
- The claim I'd most expect to be wrong: that the stalk read is right in motion at game frame rate. The movement clip gives
  only about 4 frames of the Tug.

## Phase J Part 1 - Blender: SRC_Tug re-authored as the lean-and-stretch toward -X (executor report, Opus, 2026-11-08) - DONE, waiting for Fable's go before Part 2

No Unreal, no `Script/`, every write under this folder. One slip: I ran a read-only `git diff --stat` on the builder once
(no state change) against the brief's "no git"; nothing else touched git.

**Files**
- `scripts/build_screaming_turnip.py`: `cr_dx` appended to `PKEYS` after `cr_dz`, read by `params_of`, applied in
  `bone_targets` as the crown's local X (design cm x `unit()`); the docstring rig contract says the crown translates in X and Z.
- `scripts/animate_screaming_turnip.py`: STRAIN, TUG_MID, the three SRC notes (the comments carry the targets and the sweep).
- `scripts/export_screaming_turnip.py`: `crown_travel.json` gains a `stretch` block; manifest `gameplay_numbers.k_StretchTravelCm`
  + `stretch_note`; `clips.SRC_*.crown_travel_ue_cm` gains crown / socket x; `per_frame` path follows `--review`; `rig_contract` text.
- `scripts/render_anims_screaming_turnip.py`: `--ortho` / `--target` framing override (the lean leaves the default frame).
- Data: `source/ScreamingTurnip_R01.blend` re-animated (md5 4c2db60a...); backup `source/ScreamingTurnip_R01_phaseI.blend`
  (byte copy before the first write, md5 49d9f0c7..., == the Phase I blend); `export/` SK, statics, 16 clips, expected files,
  manifest, reports; `review/phaseJ/` (sheets, `anim_report.json`, `crown_travel.json`, `expected_anims_diff.json`, logs;
  `baseline/` = pre-Phase-J expected_anims / manifest / anim_report / crown_travel / round-trip reports / the three scripts;
  `iterations/r01/` = the rejected cr_y -48 / dz 9 attempt).

#### Rerun (from this folder; each prints TURNIP_OK / TURNIP_FAIL)
```bash
B="C:/Program Files/Blender Foundation/Blender 5.2/blender.exe"
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python scripts/animate_screaming_turnip.py -- --review phaseJ
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python scripts/export_screaming_turnip.py -- --review phaseJ
"$B" -b --factory-startup --python scripts/validate_roundtrip.py
python scripts/diff_expected_anims.py review/phaseJ/baseline/expected_anims.json export/anims/expected_anims.json \
    --expect-changed SRC_Tug,SRC_Release,SRC_Cancel --out review/phaseJ/expected_anims_diff.json
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python scripts/render_anims_screaming_turnip.py -- --out phaseJ \
    --clips SRC_Tug,SRC_Cancel,SRC_Release --views front,side,threequarter --no-shapekey --pull-chain --ortho 34 --target -6,0,8.5
```
Final chain, all on the final code, **confirmed**: animate exit 0 `TURNIP_OK (16 clips, 14 s)` (`review/phaseJ/animate_log.txt`);
export exit 0 `TURNIP_OK` (`export/export_log.txt`); round trip exit 0 `TURNIP_OK`; diff exit 0; renders exit 0
(`review/phaseJ/render_anims_log.txt`).

#### Pose numbers (design frame; crown head UE cm (x, z), root-relative)
| pose | before (Phase I) | after (Phase J) |
|---|---|---|
| STRAIN | bh 1.06, bw 0.96, bdz -0.6, cr_dz 1.545, la -12, lb -7; crown (0, 39.50) | **bh 1.04, bw 0.98, bdz -0.6, brot -8, cr_y -50, cr_dx -10.398, cr_dz 4.192, la -12, lb -7; crown (-36.00, 42.30)** |
| TUG_MID (f8) | bh 1.03, bw 0.98, cr_dz 0.74, la -10, lb -6; crown (0, 36.00) | **bh 1.02, bw 0.99, brot -4, cr_y -46, cr_dx -6.113, cr_dz 1.543, la -10, lb -6; crown (-20.00, 36.80) = 55.6 % of the dx** |
| GRIP, PLANT, REL_OVER, REL_UNDER, NEUTRAL | - | unchanged (not re-tuned) |

**DEV-J-1: dz +10.5 (brief +9 +- 2, inside the band) and the pitch leading the travel (-46 at f8, -50 at f15; brief "about
35-50 at f15").** The brief's first numbers (dz 9, cr_y -40..-48, mid -22) fail the intersection gate: 3-28 `leaf_vs_bulb`
pairs on Tug f10-f15 and Cancel f0-f2.
- **Cause** (scratch sweep with a per-pair breakdown): always stem 3 (the -X stalk, azimuth 180) against bulb triangles at
  x -13..-18, z 36-37. The bulb's top ring (0.35 crown) and dimple (0.6 crown) follow the crown further than stem 3's
  emergence ring (0.5), so past ~25 cm of lean the dragged bulb top overtakes that stalk.
- The weights are the builder's (Part 1b). I did not touch them: that would mean an SK reimport.
- Leaf 3's `la` (-28..+6) changes nothing. Less body tilt (brot 0) is clean at f15 but not on f14 / Release f0.
- What clears it: more height (stem 3 rides above the bulb neck) and a pitch already near its end while the travel is large.

Sweep (0 = clean on every frame of Tug / Cancel / Release):

| STRAIN cr_y / dz, mid cr_y | worst pairs |
|---|---|
| -48 / 9, -22 (first try) | 25 (Tug f12-15, Cancel f0-2, Release f0) |
| -50 / 9, -22..-42 | 22-27 |
| -48 / 10, -42 | 3 |
| -50 / 10.5, -36 | 3 |
| -49 / 10.5, -46; -49 / 11, -42; -49 / 11, -46; -50 / 10.5, -42; -50 / 11, -42; -50 / 11, -46 | 0 |
| **-50 / 10.5, -46 (shipped)** | **0** |

Shipped in the middle of the clean neighbourhood. The margin is thin: one step outside it gives 3 pairs again.

#### Crown + socket travel (`review/phaseJ/crown_travel.json`, UE cm, root-relative)  **confirmed**
| SRC_Tug frame | crown head (x, z) | HarvestGrip_R (x, y, z) | socket horizontal travel from f0 |
|---|---|---|---|
| f0 (== SRC_Grip f6) | (0.00, 31.80) | (-1.522, 4.683, 35.185) | 0 |
| f8 | (-20.00, 36.80) | (-23.570, 4.683, 37.809) | 22.05 (57.8 %) |
| f15 | (-36.00, 42.30) | (-39.675, 4.683, 42.804) | **38.153** |

- HarvestGrip_L mirrors it (y -4.683), same travel. The sockets move only in X / Z (the crown rotates about Y only).
- **`k_StretchTravelCm = 38.2`** (manifest `gameplay_numbers`, with `stretch_note` naming the frames).
  - It is 2.2 cm more than the crown's 36.0: the 50 deg pitch swings the socket offset (-1.522, 3.385) forward on the crown.
  - For the same reason the crown rises +10.5 at f15 but the sockets only +7.6 (35.19 -> 42.80).
- Monotonic in x over the Tug; largest per-frame socket step 3.64 cm (f5-f6). The Tug is scrubbed by alpha, so no rate applies.
- SRC_Cancel (7 frames at rate 1): socket steps 2.2 / 5.6 / 7.6 / **8.3** / 7.6 / 5.5 / 2.1 cm per 1/30 s (Phase I peak 1.4).
- SRC_Release: 16.0 / **22.4** cm over f0-f2 (the snap); the crown overshoots to x +2.1 at f3 and settles at NEUTRAL.

#### Audit (`review/phaseJ/anim_report.json`, `fails: []`)  **confirmed**
- Every frame of every clip: intersections 0 in every category (no lip-fold allowance used on SRC), root identity (max dev
  0.0), UE composition deviation <= 3e-5 cm, playback == authored.
- `stem_gap` (max over frames and stems; <= 0 = seated): SRC_Idle -0.737, Grip -0.315, **Tug -0.315, Release -0.231,
  Cancel -0.607**; every ROOT_* clip as in Phase I. The stem bases hold the 36 cm lean.
- SRC chain joints 0 / 0 / 0 (Idle -> Grip -> Tug -> Release / Cancel -> Idle; Release fN == ROOT_QuietIdle f0).
- SRC_Tug bounds: h 63.59, d_x 74.06, min x -57.89.
- **Global envelope**: d_x 41.70 -> 77.93, min x -21.67 -> -57.89, h 63.59 -> 63.63. The manifest's
  `phase_c_readback.bounds_extension` / `envelope_cm` follow it.

#### Round trip  **confirmed**
- `export/roundtrip_report.json` and `export/anims/roundtrip_report.json`: `fails: []`.
- SRC_Tug: landmarks <= 7.5e-5 cm, extremes <= 6e-5, root 0.0, scale / shape-key error 0.0.
- `export/expected.json` (bind, statics, cube) is byte-identical to the baseline: the mesh and rig did not change.

#### Untouched clips (diff proof)  **confirmed**
- **Command.** `python scripts/diff_expected_anims.py review/phaseJ/baseline/expected_anims.json
  export/anims/expected_anims.json --expect-changed SRC_Tug,SRC_Release,SRC_Cancel --out review/phaseJ/expected_anims_diff.json`
  (full compare, not `--bones-only`; tol 0.001 cm).
- **Result.** Exit 0, `TURNIP_OK (3 changed: ['SRC_Cancel', 'SRC_Release', 'SRC_Tug'])`. Every ROOT_* clip, SRC_Idle and
  SRC_Grip: max abs difference **0.0** on every leaf (bone heads, extremes, scale, shape-key values, peak vertices).
- **Manifest diff** vs `review/phaseJ/baseline/`. Only these change:
  - `clips.SRC_Tug/Cancel/Release`;
  - the new x fields and the `per_frame` path on `SRC_Idle/Grip.crown_travel_ue_cm`;
  - the envelope and its `phase_c_readback` copies;
  - `rig_contract`;
  - `gameplay_numbers.k_StretchTravelCm / stretch_note`.

  `scale_factor` 3.0 is untouched.

#### Sheets (looked at; `review/phaseJ/`)
- **`SRC_Tug_sheet.png`** (front / side / 3/4) and **`crop_tug_f15_x3.png`** (f15 at 3x).
  - The stalks lean out long and thin toward -X, about 3.5x their length. The leaves end pitched forward-up.
  - The bulb stays in the soil and tilts slightly.
  - **The bulb top is pulled into a pink tapered neck** about a third of the way up the stalks (the 0.35 / 0.6 crown
    weights on the top ring and dimple). The stalks come out of that neck.
  - No gap, tear or detached blade at sheet resolution.
- **Honest read.** It reads as a rubbery stalk pulled sideways out of a peaked bulb, the Astro Bot rope idea. Two things to
  judge:
  - The pink neck. A builder-weight change would remove it but needs an SK reimport.
  - The leaves point along the pull rather than trailing behind it. That is what a -X crown pitch does; a +X pitch would
    trail, but it swings stem 3 into the bulb neck harder.
  - Side tiles: the f15 leaf tip touches the right edge of the frame.
- **`SRC_Cancel_sheet.png`**: a smooth spring-back to planted, no tearing; the neck shrinks back into the bulb.
- **`SRC_Release_sheet.png`**: a 2-frame snap from the lean to the domed REL_OVER (leaves flat), then it settles at neutral.
- **`pull_chain_sheet.png`**: Idle -> Grip -> Tug -> Release / Cancel, side and 3/4. Continuous; the joints are 0 (audit).

#### Decisions made rather than asked (say to swap)
- **REL_OVER / REL_UNDER not re-tuned.**
  - The release settles at NEUTRAL (chain 0) but snaps 36 cm in 2 frames (22 cm per frame), with a 2.1 cm overshoot to +X.
  - Phase I's PIE showed SRC_Release never plays visibly on the bed: the planted component is hidden at the yield. So I
    left it.
  - If it should play, re-key it (e.g. a REL_OVER at f2 with cr_dx +1.5).
- **Framing override** in the renderer rather than changing the default views.

#### For Part 2 / 3 (findings, not acted on)
- **Cancel speed vs the Part 3 bed-2 rule** (no socket jump > 1.5 cm between samples).
  - Cancel peaks at 8.3 cm per 1/30 s = 248 cm/s, about 4.1 cm per sample at 60 fps.
  - To hold 1.5 cm at 60 fps it needs a playback rate <= 0.36: a span >= ~0.65 s from full strain (less from 1 - a).
  - The clip length stays as briefed. Either the bed spans SRC_Cancel (`SpanSeconds`) or the rule is relaxed.
- **Skeletal mesh bounds.** The clip envelope now reaches x -57.9, while the mesh's bind bounds are -27.7..26.2.
  - The SK's bounds extension must cover the lean, or the planted turnip may be culled when the bind bounds leave the view.
  - Inferred; check in Part 3.
- **Part 3 readback target**: SRC_Tug crown head at f15 = (-35.998, 0, 42.3013) UE root-relative (`crown_travel.json`).

#### Not verified
- Anything in Unreal: the reimport, the scrub, culling, the gloves on the moved sockets.
- The look in first person at game frame rate, including the pink neck from the player's view.
- **Sub-frame audit** (`review/phaseJ/subframe_audit.json`, from the saved actions every 0.1 frame; script
  `review/phaseJ/subframe_audit_j.py`, run like the animate command with `--python review/phaseJ/subframe_audit_j.py`;
  it prints `TURNIP_FAIL subframe` because of the two rows below). **confirmed**:
  - SRC_Tug (what the bed scrubs), 151 samples: 0 intersections, stem_gap -0.315.
  - SRC_Cancel, 71 samples: **3 stem-3-vs-bulb pairs at f2.4 only** (a graze between the whole frames; at 60 fps the
    cancel will pass through it).
  - SRC_Release, 61 samples: **3 pairs at f0.5 and 25 at f0.6**, inside the 22 cm/frame snap. It does not play visibly on
    the bed today.
  - Fix if wanted: a Cancel mid key (and a Release re-key) that keeps the pitch ahead of the travel, as the Tug does.
    Not done: the brief gates whole frames, and the sweep margin is thin.
- **The claim I'd most expect to be wrong**: that the pink bulb neck reads as rubber stretch, not a defect, from the player's
  view. Judged only on 300 px sheets.

## Phase J Part 1b - Blender: the bulb top stays with the bulb (no neck); SK + every clip re-exported (Opus, 2026-11-08) - DONE, awaiting Fable audit

Fable's audit of Part 1 accepted the gates and the travel numbers but rejected the pink neck. The bulb top was dragged a
third of the way up the stalks, the same read as Phase I's rejected bh 1.22. **This section supersedes Part 1's sheets and
its sub-frame finding.**

The poses are unchanged: STRAIN and TUG_MID ship as in Part 1. No Unreal, no `Script/`, no git. Every write is under this
folder.

**Part 3 must reimport the SK as well as SRC_Tug / SRC_Cancel / SRC_Release.** The skin weights changed; the geometry,
bones and sockets did not.

### Weights (`scripts/build_screaming_turnip.py` `build_bulb`; 29 bulb vertices)
| vertices | before | after |
|---|---|---|
| bulb top ring (28) | crown 0.35 (x rem x (1 - jaw)) | **crown 0.08** |
| dimple (1, on the axis) | crown 0.6 / body 0.4 | **crown 0.15 / body 0.85** |
| stem emergence rings | body 0.5 / leaf_a 0.5 | unchanged (stem_gap still <= 0, below) |

The comments carry the target. The `build_leaf` comment now records why the emergence ring keeps 0.5.

### Neck gauge (`review/phaseJ/neck.json`, new; written by the export, which now fails if the target is missed)  **confirmed**
Displacement from SRC_Tug f0 in UE cm. The dimple is the axis vertex with crown weight; the ring is the other bulb
vertices with crown weight.

| SRC_Tug | crown head d (x, z) | dimple d (x, z) | dimple % of crown | ring max d (max abs dx / max dz) | ring % |
|---|---|---|---|---|---|
| f4 | (-7.53, 1.96) | (-1.44, 0.47) | 19.5 | 1.07 (0.97 / 0.47) | 13.7 |
| f8 | (-20.00, 5.00) | (-3.86, 1.21) | 19.6 | 2.87 (2.61 / 1.18) | 13.9 |
| f12 | (-31.39, 8.92) | (-6.19, 2.09) | 20.0 | 4.64 (4.22 / 1.93) | 14.2 |
| **f15** | (-36.00, 10.50) | **(-7.14, 2.44)** | **20.1** | **5.36 (4.88 / 2.22)** | **14.3** |

Target was dimple <= 25 %, <= 9 cm x, <= 3 cm z, ring less than the dimple. Met. Phase J Part 1's weights (0.35 / 0.6)
put the dimple about 0.6 of the way, about 22 cm (estimated from the weights; not measured, the gauge is new).

### Rebuild proof (`review/phaseJ/rebuild_compare.json`, vs `source/ScreamingTurnip_R01_phaseI.blend`)  **confirmed**
- Counts: 1624 vertices / 3188 triangles; polygons and material indices identical.
- Positions: rest vertices 0.0; Basis / Scream key blocks 0.0; Inhale 3.8e-6 cm (float noise). Vertex colour 0.0.
- Bones 17 / 17 at 0.0; statics 0.0; mouth id props identical.
- **Weights: 29 vertices changed, all bulb**, nothing else.
- `review/phaseB4/measurements.json` (sockets, landmarks) has 0 differences from the pre-rebuild copy in
  `review/phaseJ/baseline/`.
- `pose_report.json` has 15 differences, all bulb-top bounds <= 0.07 cm lower in posed extremes (impact / inhale /
  recover / scream) plus the info-only `attach_stem_root` count.
- Builder exit 0, `TURNIP_OK` (`review/phaseJ/build_log.txt`); compare exit 0, `TURNIP_OK`.
- `scripts/compare_rebuild_screaming_turnip.py` gained `--out`.

### Audit, poses, intersections  **confirmed**
- Animate: exit 0, `TURNIP_OK (16 clips, 18 s)`; `review/phaseJ/anim_report.json` `fails: []`.
- Every frame of every clip:
  - intersections 0 in every category;
  - root identity;
  - UE deviation <= 3e-5 cm;
  - chain joints 0.
- `stem_gap` (max over frames and stems; <= 0 = seated):

  | clip | Part 1 | Part 1b |
  |---|---|---|
  | SRC_Tug | -0.315 | -0.648 |
  | SRC_Grip | -0.315 | -0.648 |
  | SRC_Release | -0.231 | -0.691 |
  | SRC_Cancel | -0.607 | -0.731 |
  | ROOT_* | -0.500 or lower | -0.574 or lower |

- Stem 3 does not collide with the bulb top any more, so no cr_y change and no sweep was needed. The cause of Part 1's
  thin margin (the dragged dimple) is gone.
- **Sub-frame audit** (`review/phaseJ/subframe_audit.json`, every 0.1 frame from the saved actions): 0 intersections on
  SRC_Tug (151 samples), SRC_Cancel (71) and SRC_Release (61). `TURNIP_OK subframe`.
  - Part 1's Cancel f2.4 and Release f0.5 / f0.6 pairs are gone, so **no SRC_Cancel mid key was added**. Release is
    untouched.

### Export, round trip, diff, manifest  **confirmed**
- Export (DEV-13 recipe; SK, statics, 16 clips): exit 0, `TURNIP_OK`.
- Round trip: exit 0, `TURNIP_OK`; `fails: []` in both reports.
- Diff proof:
  - Command: `python scripts/diff_expected_anims.py review/phaseJ/baseline/expected_anims.json
    export/anims/expected_anims.json --bones-only --expect-changed SRC_Tug,SRC_Release,SRC_Cancel --out
    review/phaseJ/expected_anims_diff.json`.
  - Result: exit 0, `TURNIP_OK (3 changed: ['SRC_Cancel', 'SRC_Release', 'SRC_Tug'])`.
  - Every ROOT_* clip, SRC_Idle and SRC_Grip, against the pre-Phase-J baseline: bone landmarks 0.0 and skinned extremes 0.0.
  - Peak vertices change only on ROOT_Inhale (0.49 cm) and ROOT_Scream (0.20 cm): bulb-top vertices with the new weights.
- **`k_StretchTravelCm` re-measured: 38.2** (sockets 38.1532 cm; the crown -36.00 / +10.50). Sockets ride the crown bone,
  so the weights cannot move them. The manifest `scale_factor` is still 3.0.

### Sheets (looked at; `review/phaseJ/`, overwritten)
- **`crop_tug_f15_x3.png`** (f15, side / 3/4 / front at 3x).
  - **The neck is gone.** The bulb top is a low peaked dome leaning slightly toward the pull, and the stalks leave its
    peak straight out.
  - The peak is still a visible point (the dimple's 7 cm); it reads as a bulb being tugged, not a bulb leaving the soil.
  - No gap, tear or floating stalk at sheet resolution.
- **`SRC_Tug_sheet.png`**: the dome stays in the soil on every frame; the stretch is all stalk.
- **`SRC_Cancel_sheet.png`**, **`SRC_Release_sheet.png`**, **`pull_chain_sheet.png`**: as in Part 1, minus the neck.
  - Cancel is a smooth spring-back.
  - Release is the 2-frame snap, then it settles.
- **For the record**: `iterations/r02/` holds Part 1's neck version (the crop, four sheets, crown_travel, anim_report,
  subframe audit, expected_anims and its blend `ScreamingTurnip_R01_phaseJ_part1.blend`). `iterations/r01/` is the cr_y -48
  try.

### Rerun (from this folder)
```bash
B="C:/Program Files/Blender Foundation/Blender 5.2/blender.exe"
"$B" -b --factory-startup --python scripts/build_screaming_turnip.py
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python scripts/compare_rebuild_screaming_turnip.py -- \
    --ref source/ScreamingTurnip_R01_phaseI.blend --out review/phaseJ/rebuild_compare.json
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python scripts/animate_screaming_turnip.py -- --review phaseJ
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python review/phaseJ/subframe_audit_j.py
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python scripts/export_screaming_turnip.py -- --review phaseJ
"$B" -b --factory-startup --python scripts/validate_roundtrip.py
python scripts/diff_expected_anims.py review/phaseJ/baseline/expected_anims.json export/anims/expected_anims.json \
    --bones-only --expect-changed SRC_Tug,SRC_Release,SRC_Cancel --out review/phaseJ/expected_anims_diff.json
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python scripts/render_anims_screaming_turnip.py -- --out phaseJ \
    --clips SRC_Tug,SRC_Cancel,SRC_Release --views front,side,threequarter --no-shapekey --pull-chain --ortho 34 --target -6,0,8.5
```
The blend md5 is now 89f8e34a.... Each step was run in this order on the final code; each printed TURNIP_OK and exited 0.
**Confirmed.**

### Still standing from Part 1 (for Part 2 / 3)
- **Cancel speed.** Peak 8.3 cm per 1/30 s, against the Part 3 bed-2 rule of <= 1.5 cm per sample.
- **Mesh bounds.** The clip envelope now reaches x -57.9.
- **Part 3 readback target.** SRC_Tug crown head at f15 = (-35.998, 0, 42.3013).
- **SK reimport.** Part 3 now reimports the SK (weights). Skin weights are not read back by the importer: verify them by
  the in-engine look, as Phase I did.

### Not verified
- Unreal.
- The dome's first-person read.
- **The claim I'd most expect to be wrong**: that the residual peak (dimple 7 cm toward the pull) reads as fine in motion.
  It is judged only on 300 px sheets and a 3x crop.

## Phase J Part 2 - Script + tests: the walk-away pull on the Control kernel (Opus, 2026-11-08) - DONE, awaiting Fable audit

Brief: `PHASE_J_BRIEF.md` D-J1, D-J2, D-J4, "Part 2", plus Fable's addendum (k_StretchTravelCm measured, SRC_Cancel spanned).
No git, no `Script/Generated/*` by hand, no `Config/DefaultGameplayTags.ini`, nothing under `Tools/Blender` but this section.

### What changed (Script/)

- `ECS/Control/Mars_Control_Feature.as`: `enum EMars_Control_PullSource { Look, Walk }`; `FMars_Control_Manipulation_Spec`
  gains `PullSource` (default Look) and `WalkCm` (default 40), declared after `Mode` and added as trailing defaulted ctor
  params, so the spawn-params generator's 7-arg calls still compile and its 9-arg ones do too. `Validate`: Walk needs
  ManuallyCompleted (error names `PullSource`), `Mode == Travel` (names `Mode`), `WalkCm > 0` (names `WalkCm`).
  `FMars_Control_Manipulation` gains `Puller` + `WalkStartCm`; `FMars_Request_Control_BeginManipulation` gains `Puller` and
  the `(Interaction, Completion, Puller)` ctor. PullAxis / AlphaPerDegree documented as Look-only.
- `ECS/Control/Mars_Control_Utils.as`: mixins `Get_PullSource`, `TryGet_Puller` (invalid unless a Walk control is being
  manipulated), `Get_HorizontalDistanceTo(Puller)` (XY distance from the control entity's own transform).
- `ECS/Control/Mars_Control_Processor_Requests.as`: Begin on a Walk control ensures and returns false without a valid
  Puller (or without a transform on the control); records `WalkStartCm`. `ApplyNudges` returns 0 on Walk without touching
  Pull (commented: not an error, the player task sends none).
- `ECS/Control/Mars_Control_Processor_Tick.as`: Walk branch before the spring:
  `Pull = Clamp((Dist - WalkStartCm) / WalkCm, 0, 1)`, mirrored `1 - ...` for TowardStart. A Walk grip whose Puller is no
  longer valid ends inline as EndManipulation does (`EndWithoutPuller`: reset, untag, Mover settle, Released + progress 0).
- `PlayerCharacter/HFSM/Mars_PlayerCharacter_Hfsm_Tasks.as` (`UMars_SmTask_ManipulateControl`): for a Walk control no
  `HoldView` at the interaction's start or at begin, no nudges in `DoTick`; `BeginManipulation` now always sends
  `(Interaction, AtEngageAlpha, _Player.As_Transform(UnChecked))` (a Look control ignores the Puller). Grip wait, push-end
  wait, refusal, OnInteractionFinished shared.
- `WorldObjects/Forage/Mars_ScreamingTurnipBed_EntityScript.as`: composes `utils_control::Add` (ManuallyCompleted,
  Toggle, Walk, `WalkCm = k_StretchTravelCm`, EngageAlpha 0.97, Stiffness 60, Damping 12, no Mover); target now
  ManuallyCompleted (no duration), state class / RequiresFreeHands / AfterCompletion / Hold unchanged. `TugSeconds` and its
  readers removed (the target duration, the Grip->Tug chain). OnPullStarted plays SRC_Grip only (span GripSeconds). Follow
  tick: `DoTurn_TowardPuller` (planted node yawed so mesh -X faces the puller in XY, eased 540 deg/s, held after a cancel),
  `DoScrub_Tug` (scrubs SRC_Tug to the Control's alpha while the drawing is in Grip or Tug, once alpha > 0 or the Grip
  has played through; never overrides SRC_Cancel), then the grip nodes with their rotations pre-multiplied by the same yaw.
  Cancel (addendum): `SpanSeconds = k_CancelSecondsFromFullStrain (0.7 s)` when Strain >= 0.05, StartAlpha 1 - Strain;
  below 0.05 the tail plays at authored rate.
- `Items/Presentation/Mars_ScreamingTurnipPresentationComponent.as`: `Scrub_Clip(Clip, Alpha)` - starts the clip
  HoldLastFrame if not playing (drops any chain), then `SetPlayRate(0)` + `SetPosition(alpha * length, false)` per call.
  `Play_ClipChain` is now unused (kept; one-line follow-up: delete it if Part 3 does not need it).
- `Items/Mars_Item_ScreamingTurnip.as`: `k_StretchTravelCm = 38.2f` (manifest `gameplay_numbers.k_StretchTravelCm`,
  confirmed 38.2 in `export/ScreamingTurnip_R01_Manifest.json` at append time); clip comment updated (Tug is scrubbed).
- Tests, Control: rig `Mars_AutoTestRig_Lever.as` gains `_PullSource` / `_WalkCm` (subclass `default`s), a puller entity
  (60 cm out on -X, 150 cm up so a 3D distance would read wrong), `Walk_Puller`, `Step_BeginWalkManipulation`. New
  `WalkPullFollowsTheDistance` (0 -> 0.5 -> 0.3 within 0.05 after 1 s each, then 1.3 x WalkCm -> Succeeded, engaged),
  `WalkPullIgnoresLookNudges` (30 frames of 4 deg: peak alpha 0, live, nothing engaged), `WalkPullDoesNotHoldTheView`
  (through the player: test entity given a transform; never a ControlPull hold / orientation lost from Use to threshold;
  `TryGet_Puller() == player root`; walking it 1.3 x WalkCm ends Succeeded). `SpecValidateRejectsMismatchedPolicies`
  gains a valid Walk spec and three rejections (Timed, FreeTurn, WalkCm 0).
- Tests, ScreamingTurnip: rig spawns a puller with the bed; the bed's `OnNewInteraction` begins the manipulation with it
  (as ManipulateControl does without gloves), `OnInteractionFinished` ends it (as the task does); `Walk_Puller`,
  `Get_WalkCmFor(alpha)`, `Get_PullAlpha`, `Mark_Time`. Rewritten `AnUnarmedPullReleasesOneRootAndEmptiesTheBed` (walk
  1.25 x WalkCm), `ACancelledPullKeepsTheCharge` (0.5, cancel, alpha < 0.05 within 1 s, charge kept). New
  `AStretchShortOfTheBreakNeverReleases` (0.8 for 1 s, within 0.05, live, kept), `WalkingBackUnstretches` (0.8 then 0.2:
  under 0.3 within 1 s, still gripped, nothing released).

### Lanes (toolbox, `--test --no-live --discover-fresh`, focused; no full gate)

| Pattern | Passed | Failed | Exit | Known reds |
| --- | --- | --- | --- | --- |
| Control | 74 | 0 | 0 | none ran, no new failures |
| ScreamingTurnip | 12 | 0 | 0 | none ran, no new failures |
| FPHands | 34 | 0 | 0 | none ran, no new failures |
| Interactable | 14 | 0 | 0 | none ran, no new failures |

Evidence: `Saved/Logs/TurnipJ/{control,ScreamingTurnip,FPHands,Interactable}.out` (toolbox console; `Passed:` lines at
26958 / 24561 / 24607 / 24525), editor logs `Saved/Logs/Test-TurnipJ-<P>.log`. The three new Control tests completed
Success at control.out:25834 / 26097 / 26832; all 12 ScreamingTurnip tests listed Success. All four ran after the addendum
edits (stale-green check: they started after the last `.as` write).

A first Control run without `--discover-fresh` passed 71/0 but used a cached test list (the new tests were never
discovered): discarded. Its regen editor logged "Full Reload is required ... Keeping old angelscript code active" for the
changed generated files; the second regen boot compiled clean ("Script/Generated unchanged") - transient, as
ARCHITECTURE.md §22.3 describes. The toolbox regenerated `Script/Generated/Mars_EntitySpawnParams.as` /
`Mars_AutoTestActors.as` (TugSeconds gone, new tests present): generated, not to be committed by hand.

Rerun:
```bash
./CkAuto/UnrealToolbox.exe --test --no-live --discover-fresh --test-pattern Control --output=Saved/Logs/Test-TurnipJ-Control.log --project=D:/Repositories/CkRepos/Orion/Mars.uproject
# same with ScreamingTurnip, FPHands, Interactable (one at a time)
```

### Decisions made rather than asked (one line each to revert)

- Cancel span: the addendum wrote `SpanSeconds = 0.7 * Strain` but also "the play rate is constant whatever the strain".
  `DoPlay` sets rate = clip length / SpanSeconds for the whole clip, then seeks to StartAlpha, so `0.7 * Strain` would
  make the rate grow as the strain falls. Implemented the constant rate: SpanSeconds = 0.7 (rate 0.233/0.7 = 0.33), so the
  remaining Strain of the clip takes 0.7 x Strain s. Revert: multiply by Strain in `OnPullFinished`.
- The bed's Control sets `ReturnsToRest = true` (not in the brief): IsActive never flips, but this pins Get_PullDirection
  to TowardEnd regardless. Revert: drop the line.
- The player task passes its transform as Puller to every control (Look ignores it), rather than branching.
- The ScreamingTurnip rig ends the manipulation on the interaction's finish (the player task's job); without that a
  cancelled rig pull would stay gripped with a dead interaction.

### Unverified headless (Part 3, PIE)

- The yaw (planted node facing the puller, 540 deg/s, grip rotations yawed), the Tug scrub posing bones and morph curves
  while the single node sits at rate 0, `Get_HasPlayedThrough` staying false short of alpha 1, the spanned SRC_Cancel's
  socket steps, and the gloves on the sockets: all visual, none exercised by a lane (headless has no gloves on the bed and
  the rig never reads the presentation). **inferred** from the code only.
- "Alpha back near 0 within 1 s" in `ACancelledPullKeepsTheCharge` is satisfied by the manipulation ending (alpha unset ->
  0), not by a spring: the bed has no Mover; the visible springback is SRC_Cancel. **confirmed** by the test, but it proves
  the end, not the drawing.
- The real player's root as Puller: the through-player test gives the test entity a transform; that the PIE player
  entity carries one is **inferred** (`ck::Ctx` of the Locomotion task; a missing one would ensure in the Control).

Not started: Part 3.

## Phase J Part 3 - Unreal reimport + PIE run-05-walk (Opus, 2026-11-08) - DONE, awaiting Fable audit

No git, no `Script/` edits, no level load through the console, no unload / reload of packages. Unreal writes: the SK, its
SKEL and the three SRC clips under `/Game/ArtCandidates/ScreamingTurnip/R01/`, saved per asset. Driver files under
`Tools/LevelDesign/screaming_turnip_r01_review/` (`R` below). Editor left running on the review map, PIE stopped.

### Preflight  **confirmed**
- Monolith answered on :9316. Mars.log boot: AngelScript full compile with warnings only, `new module swap-in` done, 0
  `Full Reload is required` lines. 0 dirty packages, PIE off. The editor was on the Sandbox; the review map was loaded with
  `LevelEditorSubsystem.load_level` (clean; not a console command).

### Reimport (`R/phaseJ/reimport_phaseJ_ue.py import`; report `R/phaseJ/reimport_phaseJ.json`)
- The wrapper drives the importer's own functions (`run_mesh`, `import_clips` with the clip list filtered to SRC_Tug /
  SRC_Cancel / SRC_Release, `full_readback`) without editing it. It does not write the importer ledger
  (`export/unreal_readback_final.json` is untouched); it diffs against that ledger's `reimport_phaseI`.
- Mesh: stored import options synced (morph targets True, IMPORT_NORMALS, vcolor REPLACE, update ref pose True), the
  existing SKEL reused, SK + SKEL saved. Clips: 3 saved. Duplicates []; root assets before == after. **confirmed**.
- Bounds: the importer's rule (envelope + 6 cm) gave negative extension x 47 (x min -64.69); positive x was raised from 10
  to 14 so +x reaches 30.21 (Fable's "-60..+30"). Bounds with extension (-64.69, -28.04, -8)..(30.21, 28.04, 68).
  **confirmed** (`mesh_readback.bounds_with_extension`).
- Readback: material / mesh / statics / clip groups all PASS, `TURNIP_OK`. SRC_Tug crown head at f15 = (-35.998, -0.0,
  42.3013), err 0.0 cm vs `crown_travel.json`. Frames: Tug 15 (16 keys, 0.5 s), Cancel 7 (8, 0.2333 s), Release 6 (7,
  0.2 s); landmark worst <= 7.2e-5 cm. Morphs [Inhale, Scream], 9536 render verts, 6 sockets err 0.0. **confirmed**.
- Diff vs `reimport_phaseI`: materials, statics, owned / root assets 0 lines. Mesh 5 lines, all the bounds extension.
  Clip 56 lines, all in the three SRC clips except ROOT_QuietIdle and SRC_Idle `landmark_worst_cm` (7.9e-5 / 8.2e-5 ->
  6.4e-4 / 3.5e-4 cm). Those two assets were not reimported; Part 1b re-exported `expected_anims.json` (its diff used tol
  0.001), so the reference moved by < 0.001 cm. **confirmed** (diff); the cause is **inferred**.
- Skin weights are not read back: the dome look below is the evidence.

### PIE sessions (review map; `R/screaming_turnip_walk_ue.py` on top of `screaming_turnip_pie_ue.py`)
| session | folder (`R/captures/pie/`) | what | Mars.log |
|---|---|---|---|
| void | `run-05-walk-void-a/` | a sampler bug (`bounds` attribute) blanked the bed rows, and the run broke bed 1 at a timeout. Discarded. | from 3551 |
| A | `run-05-walk/` (`walk_rows.json`, `walk_rows_analysis.json`) | the numbers: no screenshots, real time, ~15 fps under the sampler | to 4173 |
| B | `run-05-walk-shots/` (J0-J13 png, 3 sheets, rows, analysis) | the captures: `Shot SHOWUI`, slomo 0.25 (game steps ~0.016 s: the 60 Hz numbers) | 4174-4473 |
| C | `run-05-walk-clip/` (217 frames, `sheet_pull_side.png`) | `capture_pie_movement_clip`, wide side view of bed 0's pull to the break | 4488-4948 |
| D | `run-05-walk-clip-edge/` (297 frames, `sheet_hold_views.png`) | as C, held at alpha 0.87 with two close side views | 4949-5467 |

Driver: walk at 30 cm/s (input scale 0.075; calibrated 392 cm/s at scale 1.0, 40 at 0.1), camera re-aimed at the bed every
tick (Aim), Use through `Key`. Bed 0 from the diagonal (-80, -80) (the root must turn 45 deg), bed 1 from +Y (450, -320)
(-90 deg). Alpha = the scrubbed SRC_Tug position / 0.5 s. The ring = the prompt widget's Duration DMI `Percent` (read
from session B on; A's ring reader filtered the widget out).

### Numbers (A unless stated; analysis files above, `R/phaseJ/rest_error.txt`, `pose_lag.txt`, `clip_linearity.txt`)
- **Alpha vs (d - d0) / 38.2.** Standing still (spring settled): max |err| 0.0028 (A bed 1 pull 2, 31 rows), 0.0021 /
  0.0029 (B bed 0 hold / bed 1 pull 2). While walking at 30 cm/s the spring trails by 0.105-0.113 (max 0.113 A bed 0,
  mean -0.085): a velocity lag of about 0.135 s, about 4.2 cm of walk. In B (fine steps) the alpha matches the target
  0.2 s earlier (Damping / Stiffness) within 0.039. **confirmed**.
- **The ring fills with the Control's alpha**: |ring x 0.97 - drawing alpha| <= 0.00014 over 256 / 84 / 387 rows (B); max
  ring 0.983 / 0.998 on the last visible row before each break. **confirmed**.
- **Release at alpha >= 0.97.** Last visible row before the root hides: alpha 0.954 (A bed 0), 0.966 (A bed 1), 0.953 /
  0.968 (B; ring 0.983 / 0.998); the root is out on the next tick. **confirmed** that it releases one tick after 0.95-0.97;
  that the crossing value is >= 0.97 is **inferred** (the threshold is the only Succeeded path; no row samples it).
- **Socket travel toward the player vs alpha x 38.2** (along the planted -X, frame-correct): max 4.38 cm (A), 2.97 cm (B).
  Two parts:
  1. The drawn pose is one tick behind the scrub position. The sockets match SRC_Tug's authored travel at the previous
     row's alpha within 0.012 cm, and at the same row's within 3.1 cm (A, 15 fps) (`pose_lag.txt`).
  2. The clip's own ease differs from linear by up to 2.98 cm (alpha 0.8; `clip_linearity.txt`).

  **confirmed**. The paused node (rate 0) poses the bones exactly at the set position (D-J2's proof) **confirmed**; the
  morph curves at the set position were not checked.
- **Gloves on the sockets**: glove bone at tick n vs socket at tick n-1 = 0.000 cm on all 127 rows (A) and 84 rows (B bed 1
  pull 1): the gloves sit exactly one tick behind. Same tick max 3.07-3.16 cm at 15 fps, 2.02 cm in B. The FPHands reach
  cap never left a glove short (0 rows > 0.5 cm lagged). B's bed 0 / pull 2 rows under a chase view are excluded (the
  gloves follow the view, 155-179 cm off). **confirmed**.
- **Yaw.** The turn starts when the manipulation begins (after the 0.4 s Grip; `TryGet_Puller` is unset before), not
  during the Grip clip: bed 0 0 -> 36.2 -> 43.5 deg in 2 ticks, bed 1 0 -> -33.8 -> -64.3 -> -90.2 in 3. From then on
  |yaw - bearing| <= 0.001 deg. Sidestep (A): bearing -90.0 -> -66.2, yaw -90.0 -> -66.2, max err 0.001, d held
  149.45-149.55; B -90.0 -> -61.5, max err 0.001. The yaw is kept after the cancel (pull 2 starts at -90.18). **confirmed**.
- **Bed 1 cancel** (B, ~60 Hz steps).
  - Let go at alpha 0.586 -> SRC_Cancel first row t 0.0945 = start alpha 0.405 (1 - a = 0.414; one tick of play).
  - In-clip socket steps 1.22-1.28 cm per sample (<= 1.5).
  - **The switch frame steps 3.57 cm**: SRC_Cancel at 1 - a sits about 3.1-3.7 cm above SRC_Tug at a for a 0.3-0.6
    (`crown_travel.json`; 3.36 cm at a 0.586), 0.44 cm at a 0.9.
  - A (15 fps): 6.06 cm per 70 ms sample = 86.6 cm/s = 1.44 cm per 60 Hz frame.
  - Ends on SRC_Idle 0.436 s (B) / 0.556 s (A) after the first Cancel row.
  - **The gloves do not ride the cancel**: 3.8, 6.4, 12.7 ... 94 cm off the sockets over the first 0.18 s. The interaction
    ends on the let-go and FPHands releases the grip (Script side, as Phase I).

  **confirmed**.
- **Charge kept, second pull works**: `bed1_after_cancel` charges=1 released=0 enabled; after pull 2 released=1
  exhausted (A and B marks). **confirmed**.
- **Culling.** `was_recently_rendered(0.2)` true on every visible planted row in A, B, D, including D's close views at
  alpha 0.868 (11 + 11 rows). **confirmed**.

### Captures, my read
- `run-05-walk-shots/sheet_bed0.png` (J0-J3, J6, J7 first person, HUD): the prompt ("Pull Screaming Turnip") and its ring
  sit on top of the turnip and hide most of it; the gloves are on the stalks, the leaves lean toward the camera. J7: the
  root in the air beside the empty bed, gloves back. The dome cannot be judged from first person (as Phase I).
- `sheet_side_bounds.png` (J4, J5a, J5b, chase views at full strain): the stalks run long and low from a small pink dome in
  the bed to the leaves at the chef's hands: a lean, not a lift. The dome stays a low dome in the soil, no neck. The chase
  view keeps the player camera's 90 deg FOV (my FOV argument does nothing), so J5a / J5b do not frame what their names say:
  the bulb is in view in both. Superseded by D.
- `run-05-walk-clip-edge/sheet_hold_views.png` frames 082-090 (scene only, 25 cm off the axis, held at alpha 0.87): the
  stretched stalks and blades fill the frame, the pink dome cut by the bottom-right edge: **the bulb at the edge of view and
  the leaves draw**. Frames 094-102 (aimed 60 cm toward the player): the leaves fill the frame, a sliver of the dome is
  still in the corner, so "bind bounds wholly outside the frustum" is **not** shown (90 deg at 25 cm reaches the bulb).
- `run-05-walk-clip/sheet_pull_side.png` frames 055-073 (wide side view): idle stalks; the stalks lengthen and lean toward
  the chef while the dome stays in the bed; frame 073 the root is airborne over the empty bed. About 5 game fps (0.2 s per
  frame under ReadPixels). The gloves do not render in a third-person view.
- `sheet_bed1.png`: J8 (alpha 0.5, prompt over the turnip), J9 / J10 (cancel early / mid: the gloves already off the
  stalks and coming back), J11 (idle, gloves at rest), J12 / J13 (top view before / after the sidestep: the stalks point at
  the player in both; the turn follows the player round the bed).

### Ensures, dirty, Sandbox
- Mars.log 3406-5467 (reimport through session D): **1** `Ensure condition failed`, line 4635: `InRHITexture`
  D3D12RenderTarget.cpp:617, frame [833], 27 ms after `MONOLITH_CLIP begin` (line 4633), before the driver's probe: the
  clip capture's first readback; the stack is D3D12RHI / Engine / RenderCore. Sessions A, B and D: 0. **confirmed**
  (lines); not the turnip **inferred** from the stack and timing.
- 0 dirty packages after the reimport and after the last session. The Sandbox map was only unloaded (file mtime
  2026-11-07 21:08, unchanged). **confirmed**.

### Rerun
```text
# editor (review map loaded, PIE off), Monolith editor_query run_python execute_file:
D:/Repositories/CkRepos/Orion/Tools/LevelDesign/screaming_turnip_r01_review/phaseJ/reimport_phaseJ_ue.py import
# PIE (editor_query start_pie), then run_python:
import sys; sys.path.insert(0, r"D:/Repositories/CkRepos/Orion/Tools/LevelDesign/screaming_turnip_r01_review")
import screaming_turnip_pie_ue as t, screaming_turnip_walk_ue as w
t.begin("run-05-walk"); w.state["full_speed"] = 400.0; w.sample_start(); w.run_measure(30.0)   # or run_captures(30.0, 0.25)
# poll w.status(); then w.finish(); stop_pie
# clips: capture_pie_movement_clip duration 45 / 60, interval 0.15, a probe at 1.5 s running w.clip_drive_walk() or
#        w.clip_drive_walk('run-05-walk-clip-edge', 15.0, 0.8)
# from R/: python phaseJ/analyse_walk.py captures/pie/run-05-walk/walk_rows.json
#          python phaseJ/rest_error.py <analysis.json> ; python phaseJ/pose_lag.py <analysis.json>
#          python phaseJ/crop_sheet.py ... ; python phaseJ/clip_sheet.py ...   (sheets)
```

### Not verified / findings for Fable
- **Cancel switch jump 3.57 cm** (authored: SRC_Cancel at 1 - a is not SRC_Tug at a mid-strain). A fix is either a Blender
  re-key of Cancel (or of the Tug ease) so the two poses meet, or a Script start alpha matched by pose rather than 1 - a.
- **Gloves leave on the cancel** (Script side, unchanged since Phase I).
- **The yaw turns after the Grip**, not during it (D-J2 asked for "through the Grip clip").
- The walking spring lag (0.11 at 30 cm/s) exceeds the brief's 0.1 while walking; at rest it is 0.003.
- The pose is one tick behind the scrub, which adds about one frame of socket travel to the glove's same-tick gap.
- Bind bounds wholly outside the view with the leaves drawn: not framed (FOV fixed at 90 deg in the chase view).
- The morph curves under the scrub, the release crossing value, node-to-socket (private handles): not read.
- The claim I'd most expect to be wrong: that the gloves-on-stalks read is right at game frame rate in first person. Every
  first-person capture has the prompt over the turnip.

## Phase J Part 2b - Script: the plant turns toward the presser from the press, not from the grip (Opus, 2026-11-08) - DONE, awaiting Fable audit

Why: PIE (Part 3) showed the turn starting only at the manipulation's begin (after the 0.4 s Grip; the Control's Puller is
unknown until then) and finishing in 2-3 ticks: a snap as the pull starts.

- `Script/WorldObjects/Forage/Mars_ScreamingTurnipBed_EntityScript.as` only:
  - New member `_Aim` (FCk_Handle_Transform), set in `OnPullStarted` from
    `utils_interaction::Get_InteractionSource(InInteraction).As_Transform(UnChecked)`.
  - `DoTurn_TowardPuller` uses `_Control.TryGet_Puller()` while gripped, else `_Aim`. It is the same 540 deg/s ease, so the
    turn runs through the Grip clip and the gloves' reach.
  - `_Aim` is cleared where the follow ends: the follow tick's Done branch (the cancel back at SRC_Idle, or harvested) and
    `OnForageReleased`.
- No new mixin. The live interaction's source is already a public CkFoundation util (`utils_interaction::Get_InteractionSource`),
  and `Mars_Interactable_Hfsm_Tasks.as` `DoGet_Initiator` uses the same call for a live interaction. The stamped
  `FMars_Fragment_InteractionContext.Initiator` exists only on the completion's sub-SM, too late for the press.
- No headless test (`ThePlantTurnsTowardThePullerDuringTheGrip` not added):
  - The rig cannot read the planted yaw cheaply. CkFoundation has no handle -> entity-script-object getter (only
    `Get_ScriptClass`).
  - The turn runs only on the follow tick, which needs the planted skeletal component.
  - The rig's carrier has no transform, so `_Aim` is invalid there and the turn holds.
  - Left to PIE: the yaw should start moving on the press and face the player within 5 deg before the grip.
- Inferred, not confirmed: the PIE interaction source is the player entity with its transform. The Use path starts
  interactions with source `_Player`, and `Mars_Interactable_Processor_Setup.as:80` takes the source as the initiator.

Lane (`--test --no-live --discover-fresh --test-pattern ScreamingTurnip`): **12 passed, 0 failed, exit 0**, no known red
ran, no new failures (`Saved/Logs/TurnipJ/ScreamingTurnip_2b.out` lines 24521-24542; editor log
`Saved/Logs/Test-TurnipJ2b-ScreamingTurnip.log`). Started after the edit (stale-green check).

Rerun: `./CkAuto/UnrealToolbox.exe --test --no-live --discover-fresh --test-pattern ScreamingTurnip --output=Saved/Logs/Test-TurnipJ2b-ScreamingTurnip.log --project=D:/Repositories/CkRepos/Orion/Mars.uproject`

## Phase J Part 1c - Blender: SRC_Cancel re-keyed as the Tug's mirror (Opus, 2026-11-08) - DONE, awaiting Fable audit

**Why.** PIE (Part 3) measured a 3.57 cm on-screen jump at a 0.586 where the cancel takes over: SRC_Cancel(1 - a) sat
3.1-3.7 cm above SRC_Tug(a). Cancel was keyed STRAIN -> PLANT with no mid key, while Tug has TUG_MID at f8.

No Unreal, no `Script/`, no git. Every write is under this folder. Only SRC_Cancel changed; **Part 3 reimports that one
clip** (the SK and the other clips are byte-identical in intent; diff below).

### Change (`scripts/animate_screaming_turnip.py`)
- SRC_Cancel keys: `[(0, STRAIN), (7, PLANT)]` -> **`[(0, STRAIN), (49/15 = f3.2667, TUG_MID), (7, PLANT)]`**.
  - 49/15 = 7 x (1 - 8/15), the mirror of Tug's f8.
  - The spline takes a fractional key, and every integer frame is still keyed in the action.
  - The clip still covers 0..7 and still ends at PLANT (chain Cancel fN -> Idle f0 is 0).
- `clips.json` `key_frames` now keeps a fractional key (`[0, 3.2667, 7]`) instead of truncating it.
- The comment and the clip note carry the numbers.

### Match (`review/phaseJ/cancel_match.json`, from `review/phaseJ/cancel_match_j.py`)  **confirmed**
Method: Cancel sampled at frame 7(1 - a) against Tug at frame 15a, every 0.01 of alpha. Crown head and both HarvestGrip
sockets, UE cm, root-relative. Two evaluations:
- `actions`: the exported keys at 30 fps with linear sub-frame interpolation, as Unreal plays them.
- `spline`: the authored curve.

Choosing k by the spline, max crown mismatch over a 0.05..0.95:

| k | max mismatch (cm) | at a 0.59 (cm) |
|---|---|---|
| none (old) | 2.79 | 2.39 |
| 3 | 1.66 | 1.59 |
| 3.2 | 1.03 | 0.42 |
| **3.2667** | **1.03** | **0.05** |
| 3.3 | 1.03 | 0.19 |
| 3.5 | 1.55 | 1.35 |
| 4 | 4.92 | 4.02 |

Shipped f3.2667: the f3 / f4 integer choices are worse at every alpha.

As played (`actions`), before -> after:

| | crown max, a 0.05..0.95 | socket max | at a 0.59 | crown max, a 0.2..0.95 |
|---|---|---|---|---|
| before (Part 1b blend) | 2.76 (at a 0.43) | 3.93 | 2.36 | 2.76 |
| **after** | **1.26 (at a 0.07)** | **1.26** | **0.02** | **0.89** |

The "before" is the actions block of `iterations/r02/cancel_match_before_1c.json`; its spline block is meaningless (it
reads the current script).

**Target (<= 1.0 cm over a 0.05..0.95) MISSED at the low end, for two measured reasons:**
- The floor is the Grip dip. Tug starts at GRIP (crown 31.80) and Cancel ends at PLANT (32.85), so a -> 0 cannot match
  better than 1.05 cm while Cancel ends at PLANT, which the chain requires. The spline is at 1.03 at a 0.05 and <= 1.0
  from a 0.08.
- 30 fps keys. Linear interpolation between the 7 Cancel keys and the 15 Tug keys adds up to about 0.25 cm near the eased
  ends. So as played it peaks at 1.26 (a 0.07), is <= 1.01 from a 0.12, and <= 0.89 from a 0.2. Fixing this would need a
  longer Cancel, which the brief forbids.
- `cancel_match_j.py` is a measurement: it prints `TARGET ... MISSED` per evaluation and `TURNIP_OK` once written.

Sockets match the crown to within 0.003 cm on the same curve.

**Cancel speed** (`crown_travel.json`): socket steps per 1/30 s are 2.7 / 6.1 / 6.6 / 6.2 / 7.7 / 6.8 / 2.9 cm. Peak 7.7
(was 8.3), more even. Still above Part 3's bed-2 1.5 cm-per-sample rule at rate 1.

### Gates (each on the final code; real lines and exit codes)  **confirmed**
- Animate: exit 0, `TURNIP_OK (16 clips, 24 s)`; `anim_report.json` `fails: []`.
  - SRC_Cancel: intersections 0, stem_gap -0.690, UE deviation 2e-5.
  - SRC chain joints 0.
- Sub-frame audit (`subframe_audit.json`, every 0.1 frame): SRC_Cancel 71 samples, 0 intersections. Tug and Release are
  unchanged and still 0. `TURNIP_OK subframe`.
- Export (DEV-13): exit 0, `TURNIP_OK`. The neck gauge is unchanged (dimple 20.1 %).
- Round trip: exit 0, `TURNIP_OK`; `fails: []` in both reports. SRC_Cancel landmarks 7.3e-5 cm, root 0, scale and
  shape-key error 0.
- **Diff proof** (full compare, not bones-only, tol 0.001 cm, against Part 1b's expected_anims):
  - Command: `python scripts/diff_expected_anims.py review/phaseJ/iterations/r02/expected_anims_part1b.json
    export/anims/expected_anims.json --expect-changed SRC_Cancel --out review/phaseJ/expected_anims_diff_1c.json`.
  - Result: exit 0, `TURNIP_OK (1 changed: ['SRC_Cancel'])`. Every ROOT_* clip, SRC_Idle, SRC_Grip, SRC_Tug and
    SRC_Release: 0.0 on every leaf.
- **Manifest** vs Part 1b's copy (`iterations/r02/ScreamingTurnip_R01_Manifest_part1b.json`): only
  `clips.SRC_Cancel` (note, bounds h 63.627 -> 63.59) and the envelope h_z 63.627 -> 63.59 changed. The envelope's max z
  came from the old Cancel's f1 overshoot; it is also copied into `phase_c_readback`.
  `k_StretchTravelCm` is still 38.2 and `scale_factor` 3.0.

### Sheet (looked at)
`review/phaseJ/SRC_Cancel_sheet.png` (front / side / 3/4; the Part 1b version is in `iterations/r02/`): a smooth, even
spring-back from the lean to planted, retracing the Tug's arc. No tearing; the dome stays in the soil.

### Rerun (from this folder)
```bash
B="C:/Program Files/Blender Foundation/Blender 5.2/blender.exe"
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python scripts/animate_screaming_turnip.py -- --review phaseJ
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python review/phaseJ/subframe_audit_j.py
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python review/phaseJ/cancel_match_j.py
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python scripts/export_screaming_turnip.py -- --review phaseJ
"$B" -b --factory-startup --python scripts/validate_roundtrip.py
python scripts/diff_expected_anims.py review/phaseJ/iterations/r02/expected_anims_part1b.json export/anims/expected_anims.json \
    --expect-changed SRC_Cancel --out review/phaseJ/expected_anims_diff_1c.json
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python scripts/render_anims_screaming_turnip.py -- --out phaseJ \
    --clips SRC_Cancel --views front,side,threequarter --no-shapekey --ortho 34 --target -6,0,8.5
```
The blend md5 is now 798d0826....

### Not verified
- Unreal: the reimport of SRC_Cancel, and the switch-frame jump in PIE.
  - Expected about 0.02 cm at a 0.59 and <= 1.26 cm anywhere. That is inferred from the Blender actions; Unreal's
    interpolation of the same keys should match.
- **The claim I'd most expect to be wrong**: that a cancel at a <= 0.1 reads clean. That is where the 1.05 cm Grip-dip
  step sits, unavoidable while Cancel ends at PLANT.

## Phase J Part 3b - SRC_Cancel reimport (Part 1c mirror), aim from the press, PIE run-06 from a 110 cm stand (Opus, 2026-11-09) - DONE, awaiting Fable audit

Same hard rules as Part 3. One asset written: `ScreamingTurnip_R01_SRC_Cancel_Mars_ANIM`, saved alone. `R` =
`Tools/LevelDesign/screaming_turnip_r01_review/`. The editor is left running on the review map, with PIE stopped.

### Correction to the brief's premise (from my own files)
Part 3 did not start the pulls at the 250 cm spawn. `d0` was 114.3 / 129.9 / 128.1 cm in
`R/captures/pie/run-05-walk/walk_rows_analysis.json`, and 112.6 / 128.7 / 130.2 cm in `run-05-walk-shots/`.
- The bed 0 stand was (-80, -80), 113 cm away; the bed 1 stand was (450, -320), 130 cm away.
- The gloves were on the stalks in those runs (glove lag 0.000 cm). They look small in first person because of the
  camera geometry, and the prompt covers them.
- run-06 stands at 110 cm all the same: d0 110.44 / 110.50 / 111.08 cm, stand offsets 1.22 / 1.26 / 1.08 cm
  (`run-06-walk/walk_rows.json` marks). **confirmed**.

### Preflight  **confirmed**
- Mars.log 5468-5561 covers the hot compile of the bed change. It is a soft reload: `Compiling (structural)` for
  `Mars_ScreamingTurnipBed_EntityScript` followed by `new module swap-in`. It has no error lines and no
  `Full Reload is required`.
- PIE was off, 0 packages were dirty, and the review map was loaded.

### Reimport: `R/phaseJ/reimport_phaseJ_ue.py clips SRC_Cancel` (report `R/phaseJ/reimport_phaseJ_clips.json`)
- This is the new `clips` mode of the same wrapper: `import_clips` with the clip list filtered to SRC_Cancel, then a
  full readback.
- Only SRC_Cancel was saved. Duplicates []. Root assets unchanged. 0 packages dirty before and after.
- All four readback groups PASS (`TURNIP_OK`).
- SRC_Cancel: 7 frames, 8 keys, 0.2333 s, landmark worst 6.4e-5 cm. Chain: from Tug f15 1.1e-5 cm, end to Idle f0 0.0.
- Diff against Part 3's `reimport_phaseJ.json`:
  - The clip lines are all SRC_Cancel.
  - Mesh has one line: `bounds_contain_clip_envelope_margin` 6.173 -> 6.2. The asset did not change. The manifest
    envelope that the margin is measured against did (Part 1c); this is **inferred**.
  - Everything else: 0 lines.

  **confirmed**.

### run-06-walk (`R/captures/pie/run-06-walk/`)
Sampled per tick at slomo 0.25 (game steps of about 0.016 s); `walk_rows.json` and `walk_rows_analysis.json`. Driver:
`run_06` in `R/screaming_turnip_walk_ue.py`. Each pull walks to the stand and makes a slow final approach to within
1.5 cm, aiming at the bed. Bed 0 is approached from the -X/-Y diagonal (the root must turn 45 deg); bed 1 from +Y
(-90 deg).

**The yaw starts on the press** (`yaw_from_press` in the analysis file). **confirmed**.

| pull | yaw track from the press | within 5 deg | Grip clip at that moment |
|---|---|---|---|
| bed 0 | 0 until +0.043 s (the first SRC_Grip tick), then 8.9 / 17.7 / 26.0 / 34.3 / 41.6 / 44.41 deg | +0.120 s | t 0.046 of 0.2 s authored (0.4 s span) |
| bed 1, pull 1 | 0 -> -88.6 deg | +0.195 s | t 0.090 |
| bed 1, pull 2 | the yaw was kept from pull 1; error 0.575 deg on the press, 0.0 from +0.048 s | at the press | - |

After the turn the yaw error is <= 0.001 deg for the rest of every pull.

**Bed 0 back-off to the break.**
- Alpha vs (d - d0) / 38.2 at rest (hold): <= 0.002 (`R/phaseJ/rest_error_run06.txt`). While walking the spring trails
  by up to 0.155. Against the target 0.2 s earlier the error is <= 0.049.
- Ring: abs(ring x 0.97 - alpha) <= 0.00014 (219 rows).
- The last visible row before the break is at alpha 0.967 (ring 0.997); the root is out on the next tick.
- Sockets: they match SRC_Tug at the previous row's alpha within 0.010 cm (`pose_lag_run06.txt`).
- Gloves: glove(n) vs socket(n-1) 0.000 cm on 121 first-person Tug rows, 0 rows over 0.5 cm, same tick <= 3.10 cm
  (`R/phaseJ/run06_gloves_bed0.txt`; the hold rows taken under the side view are excluded).
- `was_recently_rendered` was true on every visible row.

**confirmed**.

**Bed 1 cancel** (`bed1_cancel` in the analysis file).
- The let-go came at alpha 0.650. That is over the asked 0.5-0.6: the move stops at 0.55, and the spring plus the shot
  frame carried it on.
- The SRC_Cancel first row is at t 0.0799, start alpha 0.342 (1 - a = 0.350, one tick of play later).
- Switch frame: the step is 0.371 cm on the switch row. On the first row with the Cancel pose drawn (the pose is one tick
  behind) it is 1.019 cm, which includes that tick's play at about 1.0 cm. Part 3 measured 3.57 cm here.
- In-clip steps are 0.88-1.41 cm per sample at about 60 Hz. One 5.45 cm step falls over a 73.5 ms shot frame
  (1.24 cm per 60 Hz frame).
- The cancel ends on SRC_Idle 0.477 s after the first Cancel row.
- `bed1_after_cancel`: charges=1, released=0, enabled.

**confirmed**.

**Bed 1, pull 2 to the break.**
- Gloves 0.000 cm lagged, <= 0.76 cm same tick.
- The last visible row is at alpha 0.968 (ring 0.998).
- `bed1_after`: released=1, exhausted.

**confirmed**.

**Still Script side:** the gloves leave on the cancel (2.1 cm on the first Cancel-pose row, then 5.7, 11.9 ... 89 cm).

### Captures, my read
- `run-06-walk/sheet_bed0.png` (K0 prompt, K1 grip, K2 alpha 0.3, K3 0.7, K4 full strain, K6 break; first person, HUD).
  - K0, taken just before the press, shows the gloves big in the foreground with the prompt and ring over the bed.
  - From K1 on, the gloves are at the stalks, small at 110 cm and partly under the prompt.
- `run-06-walk/zoom_K1_K4.png` (crops around the turnip).
  - K1: the two gloves clasp the stalks under the leaves.
  - K2-K4: gloves, stalks and leaves come down-screen toward the camera, the leaves trailing beside the gloves, and the
    pink dome stays behind the prompt at the bed.
  - **The lean toward the camera reads; the gloves are on the stalks.**
- `sheet_side_bed1.png`.
  - K5 (side, full strain): long low stalks from a small pink dome in the bed toward the chef. The dome stays low; there
    is no neck.
  - K7: the root in the air beside the empty bed, the gloves back.
  - K8 (alpha 0.55-0.65): the turnip under the prompt.
  - K9: the gloves already leaving at the cancel.
  - K10: idle, the gloves at rest.
- `run-06-walk-clip/sheet_pull_side.png` (capture_pie_movement_clip, 231 frames, `poll.json` ok true, 0 ensures).
  - Frames 020-022 are first person before the view switch: prompt, gloves reaching to the bed.
  - Frames 024-040 are the side view: grip, then the stalks lengthening and leaning low toward the chef while the dome
    stays in the bed.
  - Frames 042-044: the root airborne.
  - About 5 game fps under ReadPixels.

### Ensures, dirty, Sandbox  **confirmed**
- Mars.log 5562-6326 (the reimport, run-06 and the clip): 0 `Ensure condition failed`, 0 `Full Reload is required`.
- 0 dirty packages after the last session.
- The Sandbox file mtime is 2026-11-07 21:08, unchanged.

### Rerun
```text
run_python execute_file: D:/Repositories/CkRepos/Orion/Tools/LevelDesign/screaming_turnip_r01_review/phaseJ/reimport_phaseJ_ue.py clips SRC_Cancel
start_pie; run_python: t.begin("run-06-walk"); w.state["full_speed"] = 400.0; w.sample_start(); w.run_06(30.0, 0.25)
  ... w.finish(); stop_pie
capture_pie_movement_clip duration 45, interval 0.15, probe at 1.5 s: w.clip_drive_06()
python phaseJ/analyse_walk.py captures/pie/run-06-walk/walk_rows.json; rest_error.py / pose_lag.py on the analysis
```

### Not verified
- The release crossing value, still inferred: a release one tick after alpha 0.967 / 0.968.
- Node-to-socket (private handles).
- The morph curves under the scrub.
- Bind bounds wholly off-screen.
- The let-go landed at 0.65, not within 0.5-0.6.
- The claim I'd most expect to be wrong: that the first-person read is good at full game speed. The first-person
  evidence is slomo screenshots and two clip frames.

## Phase J - Fable audit (2026-11-09): the walk-away pull is ACCEPTED, uncommitted

Audited against the artifacts, not the reports: the Part 1/1b/1c sheets and crops, `crown_travel.json`, `neck.json`,
`cancel_match.json`, the Part 2 diff (Control tick/requests/utils/feature, the player task, the bed, the presentation
component, the rigs and tests), the four lane logs, the run-05 and run-06 capture sheets and `zoom_K1_K4.png`.

- Part 1 rejected once (the bulb top dragged into a pink neck a third of the way up the stalks: the Phase I "bulb out of
  the soil before break-free" read); Part 1b's weights (top ring crown 0.08, dimple 0.15) fixed it, dimple travel 20 % of
  the crown's. Part 1c re-keyed SRC_Cancel as the Tug's mirror (fractional key f3.2667): switch mismatch 0.02 cm at a 0.59,
  1.26 cm worst at a 0.07 (the Grip dip; structural).
- Part 2 accepted: Walk pull source on the Control kernel (Look unchanged), bed composes it, Scrub_Clip, cancel spanned
  0.7 s (the executor's constant-span correction of my `0.7 * Strain` is right: DoPlay's rate covers the whole clip).
  Part 2b: the plant aims at the presser from the press (utils_interaction::Get_InteractionSource).
- Part 3/3b accepted: readback exact, PIE run-06 from a 110 cm stand: yaw within 5 deg at 0.12-0.20 s after the press
  (during the Grip), alpha vs distance within 0.002 at rest (spring trails up to 0.155 while walking, by design), ring
  fills, release one tick after alpha 0.967, glove-to-previous-tick socket 0.000 cm, cancel switch 0.37 cm (drawn 1.02),
  cancel steps 0.88-1.41 cm per 60 Hz sample, charge kept and the second pull works, 0 ensures in Mars.log 5562-6326.
- My own error, for the record: I read run-05's d0 as 250 cm (the spawn) from the first sampler row; the pulls actually
  started at 114-130 cm. run-06 at 110 cm stands anyway and is the first-person evidence.

Rulings: the gloves leaving the stalks on a cancel stays (the player let go; the plant springs back without them). The
prompt label and ring sit over the turnip from the standing view: a HUD placement matter, out of Phase J.

Owed / maintainer's: judge the first-person read at full game speed (all evidence is slow-motion or sheet frames); a
let-go inside alpha 0.5-0.6 was not sampled (run-06's came at 0.65); morph curves under the scrub, bind bounds wholly
off-screen, grip-node-to-socket (glove-to-socket covers it) not measured; the two untracked
`Content/EntitySpawnParams/EntitySpawnParams_CkEntityScriptEditorServices_*` assets are lane regen output, never committed;
`Play_ClipChain` has no callers left (delete when convenient); `Script/Generated/*` regenerated by the lanes.


## Phase J Part 1d - Blender: the stretch at 2x (shipped) and a 3x preview (Opus, 2026-11-09) - DONE, awaiting Fable audit

The maintainer, on the walk-away pull: the leaves should stretch much more, "2x-3x as a start". **Shipped: 2x.** 3x is
rendered and audited as a preview only (a scratch blend; not exported).

No Unreal, no `Script/`. Two slips: a read-only `git status` (piped to `head -0`, no output used), and earlier in Part 1 a
`git diff --stat`. Neither changed anything.

**The skin weights changed, so Part 3 reimports the SK plus SRC_Tug / SRC_Cancel / SRC_Release.**

### Changes
- **`scripts/build_screaming_turnip.py`**: bulb top ring crown 0.08 -> **0.03**, dimple 0.15 / 0.85 -> **0.06 / 0.94**
  (29 vertices). This keeps the absolute neck target (dimple <= 9 cm x / <= 3 cm z, ring below it) at 2x *and* 3x, so
  picking 3x later needs no further weight change. Emergence rings unchanged (0.5 / 0.5).
- **`scripts/animate_screaming_turnip.py`**:
  - STRAIN: cr_y -60, cr_dx -21.667, cr_dz 6.908 (bh 1.04, bw 0.98, brot -8, la -12, lb -7 unchanged).
  - TUG_MID: cr_y -50, cr_dx -12.571, cr_dz 2.878 (bh 1.02, bw 0.99, brot -4, la -10, lb -6).
  - SRC_Release gains `ease=(2,)` at REL_OVER.
  - SRC_Cancel keeps the Part 1c mirror key (f3.2667 TUG_MID).
  - New `STRAIN_3X` / `TUG_MID_3X` and a `--variant 3x` flag. It swaps the poses, saves to
    `source/ScreamingTurnip_R01_phaseJ_3x_preview.blend`, and does not write `export/anims/clips.json`.
  - Clip notes and comments carry the numbers.
- **New measurement script** `review/phaseJ/stretch_audit_j.py`: crown / socket travel, neck, stem lengths at f0 vs f15.

### Pose choice (sweep through the clip splines, every frame of Tug / Cancel / Release; scratch `tune_j2.py`)
| 2x STRAIN cr_y, mid cr_y | Tug | Cancel | Release |
|---|---|---|---|
| -50 / -55, mid -46 / -50 / -55 | 0 | 0 | 3 pairs at f3 (stem 3 vs the bulb top at x -1, z 36) |
| -60, mid -46 / -50 / -55 | 0 | 0 | 3 pairs at f3 |
| **-60, mid -50, plus Release ease at f2 (shipped)** | **0** | **0** | **0** |

- The Release f3 graze is the spline's overshoot past neutral into +X after a 72 cm snap. Zero slope at REL_OVER removes
  the overshoot.
- Stem 3 never touches the bulb top on the Tug at 2x or 3x: the cut bulb-top weights did that.
- Pitch -60 is the top of the brief's 50-60 band. As at 1x, the leaves point along the pull (a -X crown pitch).

### 2x numbers (confirmed)
**SRC_Tug** (`crown_travel.json`, UE cm, root-relative):

| frame | crown head (x, z) | HarvestGrip_R (x, y, z) | horizontal socket travel |
|---|---|---|---|
| f0 | (0, 31.80) | (-1.522, 4.683, 35.185) | 0 |
| f8 | (-40.00, 39.50) | (-43.630, 4.683, 40.254) | 42.11 (56.8 %) |
| f15 | (-71.99, 45.80) | (-75.703, 4.683, 45.656) | **74.18** |

- **`k_StretchTravelCm = 74.2`**, not the ~76 expected. The -60 deg pitch swings the socket offset forward by 2.2 cm
  (crown 72.0 -> socket 74.2).
- The manifest is refreshed; `rig_contract` text untouched; `scale_factor` 3.0.

**Neck** (`neck.json`; the export gates it): f15 dimple (-6.25, 1.79) = 8.9 % of the crown's travel; ring max 4.57.
**PASS.**

**Audit** (`anim_report.json` `fails: []`, animate `TURNIP_OK (16 clips, 17 s)`):
- Intersections 0 on every frame of every clip; root identity; UE deviation <= 3e-5; chain joints 0.
- stem_gap: Tug -0.687, Cancel -0.686, Release -0.687, Grip -0.712. Every ROOT_* clip <= 0.
- Envelope: d_x 113.23 cm (min x -93.19), h 65.76.

**Sub-frame audit** (`subframe_audit.json`, every 0.1 frame): Tug 151 / Cancel 71 / Release 61 samples, 0 intersections.
`TURNIP_OK subframe`.

**Cancel match** (`cancel_match.json`, as played: 30 fps keys, linear between them):
- Max crown 1.65 / socket 1.68 cm, at a 0.07. That is **over the 1.3 target for a 0.04..0.10**.
- <= 1.13 from a 0.15; 0.04 at a 0.59. The spline itself is <= 1.03.
- Cause, measured:
  - The 1.05 cm Grip-dip floor (Cancel must end at PLANT) remains.
  - On top of it sits the chord error of the 7-key Cancel near its eased end. That error scales with the travel: about
    1.3 cm at 72 cm, about 0.7 at 36. Only a longer Cancel (more keys) shrinks it, and that is off-brief.
  - So the mismatch is above 1.3 cm only while a is between 0.04 and 0.10.

**Speeds:**
- SRC_Cancel socket steps per 1/30 s: 5.1 / 11.7 / 12.8 / 12.1 / 14.8 / 12.8 / 5.5 cm.
- SRC_Release: 36.0 / 38.6 cm over f0-f2, then <= 1.7 (no overshoot now).

**Export / round trip** (DEV-13, the SK included): exit 0 `TURNIP_OK` both; `fails: []` in both reports.

**Rebuild proof** (`rebuild_compare.json` vs `source/ScreamingTurnip_R01_phaseI.blend`):
- 1624 / 3188, polygons identical.
- Rest, bones, statics 0.0; Inhale key 3.8e-6.
- Weights: 29 bulb vertices, nothing else.
- `TURNIP_OK`.

**Diff proof**:
- Command: `python scripts/diff_expected_anims.py review/phaseJ/iterations/r03_1c/expected_anims.json
  export/anims/expected_anims.json --bones-only --expect-changed SRC_Tug,SRC_Release,SRC_Cancel --out
  review/phaseJ/expected_anims_diff_1d.json`.
- Result: exit 0, `TURNIP_OK (3 changed: ['SRC_Cancel', 'SRC_Release', 'SRC_Tug'])`.
- Every ROOT_* clip, SRC_Idle and SRC_Grip: bone landmarks 0.0 and skinned extremes 0.0.
- Peak vertices: ROOT_Inhale 0.097 cm and ROOT_Scream 0.037 cm (bulb-top vertices, the weights).
- The same command against the pre-Phase-J baseline also passes.

### 3x preview (not shipped; `stretch_3x_audit.json`, `SRC_Tug_3x_sheet.png`)
- Poses: STRAIN cr_dx -32.913, cr_dz 9.783, cr_y -60; mid cr_dx -19.04, cr_dz 4.05, cr_y -50. Same weights as 2x.
- Crown (-107.99, +18.00); socket horizontal travel 110.18 (`k_StretchTravelCm` would be 110.2).
- Neck: dimple (-8.41, 2.03), ring 5.62. **PASS**, at the edge of the 9 cm x.
- Its animate run (`variant_3x/anim_report.json`): `fails: []`; intersections 0 on every frame of every clip;
  stem_gap Tug / Cancel / Release about -0.60. Envelope min x -129.2.
- **Not run at 3x**: sub-frame audit, cancel match, export, round trip.
- Blend: `source/ScreamingTurnip_R01_phaseJ_3x_preview.blend`. The shipped blend and the exports are the 2x: confirmed
  by mtime, the 3x run wrote neither.

### Stem lengths (`stretch_audit_j.py`; base ring -> blade ring, SRC_Tug f15 / f0)
| | leaf 1 / 5 | leaf 2 / 4 | leaf 3 | emergence -> blade |
|---|---|---|---|---|
| 1x | 9.0x | 8.6x | 8.7x | 7.3-8.2x |
| **2x (shipped)** | **17.1x** (4.5 -> 76.8 cm) | **16.4x** | **16.7x** | 13.9-15.2x |
| 3x | 25.1x | 24.4x | 24.8x | 20.5-22.4x |

The brief guessed 7x and 10x of rest. The short rest stalk (about 4.5 cm base to blade) already makes 1x about 9x, so 2x
is about 17x and 3x about 25x.

### What the stems look like (`crop_tug_f15_2x.png`, `crop_tug_f15_3x.png`, `stretch_1x_2x_3x.png`; looked at)
- **No thinning.** Linear skinning keeps each ring's cross-section, so the stalks stay the same width along their whole
  length. At 2x and 3x they read as thin, uniform green rods (wires) with no taper.
- **Faceting.** The four-sided stem cross-section cannot be resolved at 300 px x3. It is likely to show up close in first
  person (inferred).
- **Blades.** They stay attached at the far end, clustered at the crown: no gap at the blade ring, no detached blade. They
  read small against 75-110 cm of stalk. Leaf 3's blade points along the pull, like an arrowhead.
- **The bulb.** A low peaked dome; the stalks leave its peak. There is no neck at 2x or 3x.
- **The read.** 2x reads as a long rubber band. 3x reads as a fishing line: the stalks dominate and the plant shrinks to
  a dome plus a tuft.
- **If the maintainer goes 3x**, the honest fix for the rod look is builder-side, and needs a reimport. Fatter stems
  (STEM_R), more rings along the stem so it can taper or sag, or a 6-sided cross-section. None of this was done.

### Sheets
- `review/phaseJ/SRC_Tug_sheet.png`, `SRC_Cancel_sheet.png`, `SRC_Release_sheet.png`, `pull_chain_sheet.png`: 2x, framing
  `--ortho 44 --target -12,0,8.5`.
- `SRC_Tug_3x_sheet.png` (`--ortho 56 --target -18,0,8.5`).
- `stretch_1x_2x_3x.png`: f15 side and 3/4, same framing. 1x is the Part 1c blend with the Part 1b weights.
- Part 1c state kept in `iterations/r03_1c/` (blend, expected_anims, manifest, crown_travel, neck, cancel_match, sheet).

### Rerun (from this folder)
```bash
B="C:/Program Files/Blender Foundation/Blender 5.2/blender.exe"
"$B" -b --factory-startup --python scripts/build_screaming_turnip.py
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python scripts/compare_rebuild_screaming_turnip.py -- --ref source/ScreamingTurnip_R01_phaseI.blend --out review/phaseJ/rebuild_compare.json
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python scripts/animate_screaming_turnip.py -- --review phaseJ
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python review/phaseJ/subframe_audit_j.py
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python review/phaseJ/cancel_match_j.py
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python scripts/export_screaming_turnip.py -- --review phaseJ
"$B" -b --factory-startup --python scripts/validate_roundtrip.py
python scripts/diff_expected_anims.py review/phaseJ/iterations/r03_1c/expected_anims.json export/anims/expected_anims.json --bones-only --expect-changed SRC_Tug,SRC_Release,SRC_Cancel --out review/phaseJ/expected_anims_diff_1d.json
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python scripts/render_anims_screaming_turnip.py -- --out phaseJ --clips SRC_Tug,SRC_Cancel,SRC_Release --views front,side,threequarter --no-shapekey --pull-chain --ortho 44 --target -12,0,8.5
# 3x preview (scratch blend; run after the shipped chain)
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python scripts/animate_screaming_turnip.py -- --review phaseJ/variant_3x --variant 3x
"$B" -b --factory-startup source/ScreamingTurnip_R01_phaseJ_3x_preview.blend --python review/phaseJ/stretch_audit_j.py -- 3x review/phaseJ/stretch_3x_audit.json review/phaseJ/variant_3x/anim_report.json
```
Each printed TURNIP_OK with exit 0 on the final code. The shipped blend md5 is 4b064dcd....
`cancel_match_j.py` prints `TARGET ... MISSED` (a measurement, by design).

### Part 3 notes
- Reimport the **SK** (weights) and the three SRC clips.
- The SK bounds must now cover x -93 (2x).
- Readback: SRC_Tug crown head at f15 = (-71.9944, 0, 45.7995).
- Script side: `k_StretchTravelCm` 38.2 -> **74.2**, so `WalkCm` doubles and the player backs off 74 cm. The 250 cm
  interaction trace and the 40 cm probe box were judged at 36 cm. Re-check that the focus holds (inferred risk).

### Not verified
- Unreal.
- The 3x sub-frame / cancel match / round trip.
- The first-person read of the rods.
- **The claim I'd most expect to be wrong**: that a 74 cm walk-away keeps the turnip in focus and the gloves on the
  sockets. The FPHands `MaxReachCm` and the interaction probe were tuned for 36 cm.

## Phase J Part 3c - the 2x stretch in Unreal: SK + three SRC clips, bounds to x -100, PIE run-07 (Opus, 2026-11-09) - DONE, awaiting Fable audit

Same hard rules. `R` = `Tools/LevelDesign/screaming_turnip_r01_review/`. The editor is left running on the review map,
with PIE stopped.

### Preflight  **confirmed**
- Mars.log 7659-7690 is the hot compile of `k_StretchTravelCm = 74.2` (`Compiling (code only): Items.Mars_Item_ScreamingTurnip`,
  line 7672). It has no error lines, ends in `new module swap-in`, and has 0 `Full Reload is required` lines.
- PIE was off, 0 packages were dirty, and the review map was loaded.

### Reimport: `R/phaseJ/reimport_phaseJ_ue.py import 1d` (report `R/phaseJ/reimport_phaseJ_1d.json`)
- It runs the mesh stage (stored options synced, existing SKEL reused, SK + SKEL saved), then the three clips.
- The new `1d` tag sets the 1d crown target and a negative bounds floor of 83. The report is diffed against
  `reimport_phaseJ_clips.json`.
- All four readback groups PASS (`TURNIP_OK`). No duplicates, root assets unchanged, 0 packages dirty before and after.
- SRC_Tug crown at f15: (-71.9944, -0.0, 45.7995), err 0.0 cm.
- Frames: Tug 15, Cancel 7, Release 6. Landmark worst <= 7.5e-5 cm. Chains (Grip <- Idle, Tug <- Grip, Cancel / Release
  <- Tug f15, the two notes ends) <= 1.1e-5 cm.
- Bounds with extension: (-100.69, -28.04, -8)..(30.21, 28.04, 70).
  - Negative extension x 83 (the importer's rule gave 82, raised to 83).
  - Positive x 14.
  - z 22 (the importer's rule).
  - `bounds_contain_clip_envelope_margin` 6.044 cm.
- Diff: the clip lines are all in the three SRC clips; mesh lines are the bounds only; 0 lines elsewhere.
- The new bulb-top weights cannot be read back; the look is in the captures.

**confirmed**.

### run-07-walk (`R/captures/pie/run-07-walk/`)
Run with `run_06(30, 0.25, "run-07-walk", let_go=0.45)` and `WALK_CM = 74.2`. Samples were per tick at slomo 0.25 (game
steps of about 0.009 s). Files: `walk_rows.json`, `walk_rows_analysis.json` (`WALK_CM=74.2 python phaseJ/analyse_walk.py`),
and `R/phaseJ/run07_extra.txt`, `rest_error_run07.txt`, `pose_lag_run07.txt`. Stands: d0 110.43 / 110.39 / 111.02 cm.

**Bed 0, back-off to the break.**
- Alpha vs (d - d0) / 74.2 at rest (the hold): max 0.0016 (`rest_error_run07.txt`, 112 rows). While walking the spring
  trails by up to 0.083.
- Ring: abs(ring x 0.97 - alpha) <= 0.00014 (493 rows).
- The sockets match SRC_Tug at the previous tick's alpha within 0.017 cm (`pose_lag_run07.txt`). Against alpha x 74.2 the
  max is 5.49 cm, which is the clip's ease plus that one-tick pose lag.
- Gloves: glove(n) vs socket(n-1) 0.000 cm on all 332 first-person Tug rows, 0 rows over 0.5 cm, same tick <= 4.03 cm
  (`run07_extra.txt`).
- The FPHands reach cap: the player sets no MaxReachCm (`Mars_PlayerCharacter_Assets.as:225`, "unset = uncapped"), and the
  bed's grip entries pass none. So **0 ticks were left short**, matching the 0 lagged rows above.
- **The focus held to the break.**
  - Every Tug row had the prompt ring up. No `pull_dropped` mark.
  - Bed 0's last visible row: d 184.61 cm, camera pitch -27.7 deg.
  - Bed 1 pull 2: d 189.63, pitch -27.1.
  - The pitch ran from -41.3 at the grip up to -27.7.
- Release.
  - Bed 0: the last visible row is at alpha 0.9456 (ring 0.9748). The release tick is the K6 screenshot's long tick
    (dt 0.094 s), so the crossing happened inside that tick.
  - Bed 1 pull 2: last visible alpha 0.969 (ring 0.999).
  - That the crossing value is >= 0.97 is **inferred**.
- Yaw: within 5 deg 0.101 s after the press (45 deg turn) and 0.184 s (90 deg); kept for pull 2.
- `was_recently_rendered` was true on every visible row.

**confirmed**.

**Bed 1 cancel.**
- Let go at alpha 0.496 (the stop is at 0.45, then the spring lag). SRC_Cancel's first row: start alpha 0.501 vs
  1 - a = 0.504.
- Switch row step 0.228 cm. The first row with the Cancel pose drawn moves 1.38 cm in 8.6 ms. That includes about 1.0 cm of
  play at ~120 cm/s, so the pose mismatch itself is about 0.35 cm (**inferred**).
- **Spanned cancel speed**: the plateau is 120-150 cm/s, i.e. **2.0-2.5 cm per 60 Hz frame**; peak 2.67 cm (the step
  that contains the switch). Over 35 in-clip steps the 60 Hz equivalent ranges 0.39-2.67 cm (`run07_extra.txt`). This
  exceeds the 1.5 cm rule.
  - Inferred: the speed scales with 1 / span, so holding 1.5 cm at the measured 150 cm/s peak needs
    k_CancelSecondsFromFullStrain of about 0.7 x 150 / 90 = 1.17 s. That is Fable's call.
- Ends on SRC_Idle 0.363 s after the first Cancel row. `bed1_after_cancel`: charges=1, released=0, enabled.
- The gloves leave on the cancel (1.6, 1.9, 3.7 ... 41 cm; Script side).

**confirmed** (the measured numbers).

**Bed 1, pull 2** broke, and `bed1_after` reads released=1. **confirmed**.

### Captures, my read
- `sheet_bed0.png` (first person: K0 prompt, K1 grip, K2 0.3, K3 0.7, K4 full strain, K6 break).
  - K0: the gloves big, the prompt over the bed.
  - From K1 on, the gloves are on the stalks.
  - K3 to K6: the gloves, stalks and leaves come toward the camera and sit at the bottom edge of the frame. They are partly
    cut off by the screen bottom because the camera keeps aiming at the bed, at pitch about -27.7 by the break. The pink
    dome is behind the prompt at the bed.
- `zoom_K4b_stalks_fp.png` (close crop at full strain): five thin stalks run from the dome to the gloves. **Faceting
  shows**: each 4-sided stalk reads as flat bands, a light and a dark green stripe per face, a ribbon rather than a round
  stem. Not a tear; visible at this size.
- `zoom_K5_rods_side.png` and `sheet_side_bed1.png` K5 (side, full strain).
  - The stalks are long straight rods, about the length of the chef's reach, converging to thin points at a small pink
    dome that stays low in the soil. No neck.
  - The rods read as flat-faced (olive / yellow bands), the leaves clustered at the far end.
- K7: the root in the air beside the empty bed.
- K8 to K10: the cancel; the gloves leave the stalks at once (K9) and are at rest by K10.
- `R/captures/pie/run-07-walk-clip/sheet_pull_side.png` (capture_pie_movement_clip, 146 frames, `poll.json` ok true,
  0 ensures).
  - Frames 044-054: idle and grip.
  - Frames 056-060: the rods lengthen low toward the chef while the dome stays in the bed.
  - Frames 062-066: the root airborne.
  - About 3 game fps under capture (0.35 s per frame).

### Ensures, dirty, Sandbox  **confirmed**
- Mars.log 7737-8506 (the reimport, run-07 and the clip): 0 `Ensure condition failed`, 0 `Full Reload is required`.
- 0 dirty packages. The Sandbox mtime is 2026-11-07 21:08, unchanged.

### Rerun
```text
run_python execute_file: D:/Repositories/CkRepos/Orion/Tools/LevelDesign/screaming_turnip_r01_review/phaseJ/reimport_phaseJ_ue.py import 1d
start_pie; run_python: w.WALK_CM = 74.2; t.begin("run-07-walk"); w.state["full_speed"] = 400.0; w.sample_start();
  w.run_06(30.0, 0.25, "run-07-walk", 0.45) ... w.finish(); stop_pie
capture_pie_movement_clip duration 50, interval 0.15, probe at 1.5 s: w.clip_drive_06('run-07-walk-clip', 30.0, 74.2)
WALK_CM=74.2 python phaseJ/analyse_walk.py captures/pie/run-07-walk/walk_rows.json; rest_error.py / pose_lag.py likewise
```

### Not verified / findings for Fable
- The cancel at 2x is 2.0-2.5 cm per 60 Hz frame, against the 1.5 cm rule. k_CancelSecondsFromFullStrain of about
  1.2 s would hold it (inferred).
- The stalks show faceting at full strain in a close first-person view.
- In first person the stretched stalks and gloves leave the bottom of the frame by full strain, because the camera stays
  on the bed.
- The release crossing value, node-to-socket and the morph curves are not read.
- The claim I'd most expect to be wrong: that the first-person read at full game speed is good. The evidence is slomo
  screenshots and a 3 fps clip.

## Phase J - Fable audit addendum (2026-11-09): the 2x stretch (Part 1d / 3c) is ACCEPTED, uncommitted

Seen: `review/phaseJ/stretch_1x_2x_3x.png`, the run-07 sheets, `zoom_K4b_stalks_fp.png`, `zoom_K5_rods_side.png`;
read: `reimport_phaseJ_1d.json`, `rest_error_run07.txt`, `pose_lag_run07.txt`, `run07_extra.txt`.

- Shipped: crown travel (-72.0, +14.0) cm, sockets 74.18 cm, `k_StretchTravelCm = 74.2` (Fable's one-line edit,
  ScreamingTurnip lane 12/0 exit 0 on it: `Saved/Logs/TurnipJ/ScreamingTurnip_1d.out`), SK weights top ring 0.03 /
  dimple 0.06 (dome holds at 2x and 3x), SRC_Release eased at REL_OVER. PIE run-07 from 110 cm: focus held to the break at
  185-190 cm (pitch -27 deg), alpha vs distance within 0.0016 at rest, gloves on the previous-tick socket 0.000 cm on 332
  rows, 0 reach-cap shortfalls (the player's MaxReachCm is unset), yaw within 5 deg at 0.10-0.18 s, cancel switch 0.23 cm,
  charge kept, second pull breaks, 0 ensures (Mars.log 7737-8506).
- Ruling, cancel speed: the 1.5 cm-per-sample rule is RELAXED for the cancel. It was written for gloves riding the
  sockets, and the gloves let go on a cancel; a spring-back is meant to be quick. `k_CancelSecondsFromFullStrain` stays
  0.7 s (120-150 cm/s, 2.0-2.5 cm per 60 Hz frame, switch mismatch ~0.35 cm). Raise it if the snap reads harsh in play.
- Ruling, framing: the stretched stalks leave the bottom of the first-person frame at full strain because the view aims
  at the bed; the player can look down. Accepted.
- Maintainer's call, stems: at 17x their rest length the 4-sided stems read as flat light/dark ribbons close up
  (`zoom_K4b_stalks_fp.png`). Options if it bothers: 6-8 sided stems, a slight taper, more rings - a builder mesh change
  plus an SK reimport.
- 3x preview only (`SRC_Tug_3x_sheet.png`, `stretch_3x_audit.json`): crown -108, sockets 110 cm, dome holds, audits
  clean; not exported. A 3x walk ends ~220 cm from the bed where the 250 cm interaction trace is at its limit (the run-07
  ray at the break was ~213 cm): 3x needs a longer trace or a closer stand, and the stems would want the mesh change above.


## Phase J Part 1e - Blender: the stretch at 4x, shipped (Opus, 2026-11-09) - DONE, awaiting Fable audit

The maintainer saw 2x and the 3x preview: "go with 4x". No Unreal, no `Script/`, no git this round.

**The skin weights changed again, so Part 3 reimports the SK plus SRC_Tug / SRC_Cancel / SRC_Release.**

The 2x state is kept in `review/phaseJ/iterations/r04_2x/`: the blend, expected_anims, manifest, crown_travel, neck,
cancel_match, sub-frame audit, anim_report, stretch_2x, the four sheets, the 2x crop, rebuild_compare, and the 2x builder
and animate scripts.

### Changes
- **`scripts/build_screaming_turnip.py`**: bulb top ring crown 0.03 -> **0.01**, dimple 0.06 / 0.94 -> **0.03 / 0.97**
  (29 vertices, commented). The neck target is absolute: dimple <= 9 cm x / <= 3 cm z, ring below it.
- **`scripts/animate_screaming_turnip.py`**:
  - STRAIN: cr_y -60, cr_dx -44.249, cr_dz 12.023. Bulb unchanged: bh 1.04, bw 0.98, bdz -0.6, brot -8, la -12, lb -7.
  - TUG_MID: cr_y -50, cr_dx -25.534, cr_dz 4.864 (bh 1.02, bw 0.99, brot -4, la -10, lb -6).
  - SRC_Cancel keeps the Tug-mirror key (f3.2667); SRC_Release keeps the REL_OVER ease.
  - Clip notes and comments carry the numbers. The 2x / 3x poses stay in comments; the `--variant 3x` preview flag is
    left in place.
- **New** `review/phaseJ/closeup_j.py`: close-ups of SRC_Tug f15 at the stem base, mid-stalk and crown.

### Pose sweep (`tune_j2.py`, every frame of Tug / Cancel-with-mirror-key / Release-with-ease, 4x weights)
STRAIN cr_y -55 / -60 x mid -50 / -55: **0 intersections in all four**, stem_gap -0.71. Shipped -60 / -50, as 2x.
Stem 3 does not touch the bulb top at 144 cm, and the Release ease still clears it.

### Numbers (confirmed)
**SRC_Tug** (`crown_travel.json`, UE cm, root-relative):

| frame | crown head (x, z) | HarvestGrip_R (x, y, z) | horizontal socket travel |
|---|---|---|---|
| f0 | (0, 31.80) | (-1.522, 4.683, 35.185) | 0 |
| f8 | (-79.99, 42.79) | (-83.624, 4.683, 43.549) | 82.10 (56.2 %) |
| f15 | **(-143.99, 51.80)**: dx -144.0, dz +20.0 | (-147.694, 4.683, 51.654) | **146.17** |

- **`k_StretchTravelCm = 146.2`**, not the ~148 expected. The -60 deg pitch adds only 2.2 cm over the crown, as at 2x.
- Manifest refreshed; `rig_contract` text and `scale_factor` 3.0 untouched.

**Neck** (`neck.json`; the export gates it): f15 dimple (-6.31, 1.58) = 4.5 % of the crown's travel; ring max 3.82 (dx
3.59, dz 1.56). **PASS.**

**Audit** (`anim_report.json` `fails: []`, animate `TURNIP_OK (16 clips, 16 s)`):
- Intersections 0 on every frame of every clip; root identity; UE deviation <= 5e-5 cm; chain joints 0.
- stem_gap: Tug / Cancel / Release -0.710, Grip -0.733. Every ROOT_* clip <= -0.55.
- Envelope: min x -165.18, d_x 185.22, h 71.75. The height is now over the 66 cm design limit; that is reported, not gated.

**Sub-frame audit** (`subframe_audit.json`, every 0.1 frame): Tug 151 / Cancel 71 / Release 61 samples, 0 intersections.
`TURNIP_OK subframe`.

**Cancel match** (`cancel_match.json`, as played: 30 fps keys, linear between them):
- Max socket 2.66 cm at a 0.07 and 2.24 cm at a 0.93. <= 1.01 cm over a 0.25..0.80; 0.10 at a 0.59.
- The spline itself is still <= 1.03 cm.
- Both peaks are the chord error of the 7-key Cancel against the 15-key Tug at the eased ends. It scales with the
  travel: 0.7 cm at 1x, 1.3 at 2x, about 2.6 now. The low-a end also carries the 1.05 cm Grip-dip floor.
- **New at 4x: the a -> 1 end** (a cancel let go just short of the break) jumps up to 2.24 cm.

**Speeds** (socket per 1/30 s):
- SRC_Cancel: 10.2 / 23.1 / 25.4 / 24.0 / 29.0 / 24.8 / 10.5 cm.
- SRC_Release: 71.3 / 75.7 cm over f0-f2, then <= 1.7.

**Export / round trip** (DEV-13, the SK included): exit 0 `TURNIP_OK` both; `fails: []` in both reports.

**Rebuild proof** (`rebuild_compare.json` vs `source/ScreamingTurnip_R01_phaseI.blend`):
- 1624 / 3188, polygons and material indices identical.
- Rest 0.0; Basis / Scream 0.0, Inhale 3.8e-6 (noise); vertex colour 0.0; bones 0.0; statics 0.0.
- **Weights: 29 bulb vertices only.** `TURNIP_OK`.

**Diff proof**:
- Command: `python scripts/diff_expected_anims.py review/phaseJ/iterations/r04_2x/expected_anims.json
  export/anims/expected_anims.json --bones-only --expect-changed SRC_Tug,SRC_Release,SRC_Cancel --out
  review/phaseJ/expected_anims_diff_1e.json`.
- Result: exit 0, `TURNIP_OK (3 changed: ['SRC_Cancel', 'SRC_Release', 'SRC_Tug'])`.
- Every ROOT_* clip, SRC_Idle and SRC_Grip: bone landmarks 0.0 and skinned extremes 0.0.
- Peak vertices: ROOT_Inhale 0.032 cm and ROOT_Scream 0.015 cm (bulb-top weights).
- The same command against the pre-Phase-J `baseline/` also passes.

### Stretch (`stretch_4x.json`, base ring -> blade ring, SRC_Tug f15 / f0)
| | leaf 1 / 5 | leaf 2 / 4 | leaf 3 | emergence -> blade |
|---|---|---|---|---|
| 1x | 9.0x | 8.6x | 8.7x | 7.3-8.2x |
| 2x | 17.1x | 16.4x | 16.7x | 13.9-15.2x |
| **4x (shipped)** | **33.0x** (4.5 -> about 148 cm) | **32.2x** | **32.9x** | **27.1-29.5x** |

### How it looks (looked at)
Files: `crop_tug_f15_4x.png`, `stretch_1x_2x_4x.png` (f15, side and 3/4, one framing), and `closeup_4x.png` (600 px
close-ups at f15: the stem base 18 cm wide, mid-stalk 18 cm, the crown 24 cm).

- **Stalks** (mid-stalk close-up):
  - Every stalk is a square-section rod: four flat faces, one lit and one dark. Edge-on, two faces read as a flat green
    ribbon. Seen whole, they read as long thin wires.
  - The cross-section holds its width all the way (linear skinning), so there is no thinning and no taper.
  - Each stalk is one long segment between rings, so there are no gaps between rings to open.
  - A fine stipple runs along the edge where two stalks run side by side. Near-coincident faces shading against each
    other is my inference; the audit counts 0 leaf-vs-leaf intersections.
- **Blades** (crown close-up): all five stay attached. Each stalk widens into its blade at the stem-to-blade ring with a
  visible kink; there is no gap and no detached blade. Leaf 3's blade points along the pull. Against about 1.5 m of stalk
  the leaf tuft reads very small in the full-frame views.
- **The dome** (stem base close-up):
  - With the crown share almost gone, the bulb top is now a **flat-topped, faceted cone**: the dimple plateau, tilted 8 deg
    toward the pull.
  - The stalks leave from the -X rim of the plateau, with a dark notch where their embedded segment enters.
  - No gap, no neck, nothing lifting out of the soil. It reads as a turnip top, but blockier than the 1x / 2x peaked dome.
- **Overall**:
  - 4x reads as a fishing line from a turnip to a tuft of leaves.
  - The stretch is unmistakable, and nothing tears.
  - The square, flat-shaded rod is plain at close range. That is the stem-mesh call (more sides, taper, sag rings),
    deliberately not made this round.
- **Release**: snaps back 147 cm in 2 frames, then settles. **Cancel**: retraces the arc.

### Sheets
- `review/phaseJ/SRC_Tug_sheet.png`, `SRC_Cancel_sheet.png`, `SRC_Release_sheet.png`, `pull_chain_sheet.png`: framing
  `--ortho 70 --target -28,0,8.5`.
- In that framing the bulb is small. Use the close-ups for detail.

### Rerun (from this folder)
```bash
B="C:/Program Files/Blender Foundation/Blender 5.2/blender.exe"
"$B" -b --factory-startup --python scripts/build_screaming_turnip.py
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python scripts/compare_rebuild_screaming_turnip.py -- --ref source/ScreamingTurnip_R01_phaseI.blend --out review/phaseJ/rebuild_compare.json
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python scripts/animate_screaming_turnip.py -- --review phaseJ
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python review/phaseJ/subframe_audit_j.py
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python review/phaseJ/cancel_match_j.py
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python scripts/export_screaming_turnip.py -- --review phaseJ
"$B" -b --factory-startup --python scripts/validate_roundtrip.py
python scripts/diff_expected_anims.py review/phaseJ/iterations/r04_2x/expected_anims.json export/anims/expected_anims.json --bones-only --expect-changed SRC_Tug,SRC_Release,SRC_Cancel --out review/phaseJ/expected_anims_diff_1e.json
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python review/phaseJ/stretch_audit_j.py -- 4x review/phaseJ/stretch_4x.json review/phaseJ/anim_report.json
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python scripts/render_anims_screaming_turnip.py -- --out phaseJ --clips SRC_Tug,SRC_Cancel,SRC_Release --views front,side,threequarter --no-shapekey --pull-chain --ortho 70 --target -28,0,8.5
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python review/phaseJ/closeup_j.py
```
Each printed TURNIP_OK with exit 0 on the final code. The shipped blend md5 is c81a59bc....
`cancel_match_j.py` prints `TARGET ... MISSED` (a measurement, by design).

### Part 3 notes
- Reimport the SK (weights) and the three SRC clips.
- The SK bounds must cover x -165 and z 70; Part 3c set -100.
- Readback: SRC_Tug crown head at f15 = (-143.9856, 0, 51.7974).
- Script side: `k_StretchTravelCm` 74.2 -> **146.2**. The player backs off about 1.5 m holding Use. Re-check that the
  250 cm trace and the probe box keep the focus, and that the FPHands reach holds the sockets (inferred risk).

### Not verified
- Unreal.
- The first-person read of a 1.5 m square rod.
- Whether the stipple between neighbouring stalks shows in engine.
- **The claim I'd most expect to be wrong**: that walking 146 cm back while holding Use keeps the turnip in focus and the
  gloves on the sockets. Nothing in Script was tuned for this distance.

## Phase J Part 3d - the 4x stretch in Unreal: SK + three SRC clips, bounds to x -170 / z 75, PIE run-08 past the 250 cm trace (Opus, 2026-11-09) - DONE, awaiting Fable audit

Same hard rules. `R` = `Tools/LevelDesign/screaming_turnip_r01_review/`. The editor is left running on the review map with
PIE stopped.

### Preflight  **confirmed**
- Mars.log 8735-8741 is the hot compile of `k_StretchTravelCm = 146.2` (`Items.Mars_Item_ScreamingTurnip`, code only). It
  ends in `new module swap-in`, with no error lines and 0 `Full Reload is required`.
- PIE was off, 0 packages were dirty, and the review map was loaded.

### Reimport: `R/phaseJ/reimport_phaseJ_ue.py import 1e` (report `R/phaseJ/reimport_phaseJ_1e.json`)
- The wrapper's tag table gained `1e`: crown target (-143.9856, 0, 51.7974), bounds floor x 153, z 27. The report is
  diffed against `reimport_phaseJ_1d.json`.
- All four readback groups PASS (`TURNIP_OK`). No duplicates, root assets unchanged, 0 packages dirty before and after.
- SRC_Tug crown at f15: (-143.9856, -0.0, 51.7974), err 0.0 cm.
- Frames: Tug 15, Cancel 7, Release 6. Landmark worst <= 9.1e-5 cm. Chains <= 2.6e-5 cm.
- Bounds with extension: (-171.69, -28.04, -8)..(30.21, 28.04, 76).
  - The importer's own rule already gave negative x 154 and z 28, so no raise was needed beyond the +x 14.
  - Envelope margin 6.046 cm.
- Diff: clip lines only in the three SRC clips; mesh lines only the bounds; 0 lines elsewhere.

**confirmed**.

### run-08-walk (`R/captures/pie/run-08-walk/`)
- Run: `run_06(30, 0.25, "run-08-walk", let_go=0.45, side=(70, 260), speed2=400)` with `WALK_CM = 146.2`.
- Sampling: per tick, game steps of about 0.008 s.
- New per-tick fields: the camera location / pitch / yaw (`cam`), and each bed's `focused` flag from the Bed() readout.
- Files:
  - `walk_rows.json`, `walk_rows_analysis.json` (`WALK_CM=146.2`)
  - `ray_focus.json` (from `R/phaseJ/ray_focus.py`)
  - `R/phaseJ/ray_focus_run08.txt`, `run08_extra.txt`, `rest_error_run08.txt`, `pose_lag_run08.txt`
- Stands: d0 110.40 / 110.29 / 111.21 cm.
- Pulls:
  - Bed 0: slow, 30 cm/s.
  - Bed 1, pull 1: slow, let go.
  - Bed 1, pull 2: **full backward walking speed** (input scale 1.0; measured up to 425.6 cm/s).

**The pull survives the ray leaving the probe**. `ray_focus.py` intersects the view ray with the bed's probe box (centre
bed + (0, 0, 12), half (40, 40, 22)) inside the 250 cm trace. **confirmed**.

**Bed 1, pull 2 (full speed).**
- From game 20.913 (player 278.7 cm from the bed, eye 294.8 cm from the probe centre, pitch -18.6 deg) the ray reaches
  the probe only at 251.9 cm, past the trace.
- From there to the break it stays out of reach: 40 rows. On the 38 rows before the release, `focused=true` and the
  prompt ring is up.
- It breaks at alpha 0.968 (ring 0.998) with the player 388.0 cm away and the ray entering the probe at 358 cm.
- Focus and ring go only on the release rows. The pinned focus holds.

**Bed 0 (slow pull).**
- The break comes at 255.0 cm horizontal (eye 273.9 cm). The ray still enters the probe's near face at 219 cm, so this
  pull does not test the pin.
- The rows where the ray misses (pitch about -4 deg) are the side-view shots: the camera manager is the chase camera
  there, not the player's view.

**Bed 0, back-off to the break.**
- Alpha vs (d - d0) / 146.2 at rest: max 0.001 (137 rows, `rest_error_run08.txt`). While walking at 30 cm/s it trails by
  up to 0.043.
- Ring: abs(ring x 0.97 - alpha) <= 0.00015.
- The sockets match SRC_Tug at the previous tick's alpha within 0.033 cm (`pose_lag_run08.txt`). Against alpha x 146.2 the
  max is 10.6 cm, which is the clip's ease plus the one-tick lag.
- Gloves: glove(n) vs socket(n-1) <= 0.001 cm on 667 first-person rows, 0 rows over 0.5 cm, same tick <= 3.61 cm.
- Reach-cap shortfalls: 0 (MaxReachCm unset, `Mars_PlayerCharacter_Assets.as:225`).
- Yaw: within 5 deg 0.094 s after the press (45 deg) and 0.181 s (90 deg), inside the Grip clip.
- Release: the last visible row is at alpha 0.969 (ring 0.999). That the crossing is >= 0.97 is **inferred**.
- `was_recently_rendered` was true on every visible row.

**confirmed**.

**Spring lag at full speed** (bed 1 pull 2, `run08_extra.txt`).

| game s | walked | target (walked / 146.2) | alpha | trail |
|---|---|---|---|---|
| 20.597 | 34.9 cm | 0.238 | 0.028 | 0.21 |
| 20.685 | 71.7 cm | 0.490 | 0.109 | 0.38 |
| 20.770 | 107.4 cm | 0.735 | 0.250 | 0.49 |
| 20.853 | 142.4 cm | 0.974 | 0.436 | **0.54** |
| 20.940 | 179.0 cm | 1.0 | 0.649 | 0.35 |

- The break comes at 276.8 cm walked, **130.6 cm past WalkCm**, about 0.7 s after starting to walk.
- At normal walking speed the root comes out well after the walk distance. **confirmed**.

**Bed 1 cancel.**
- Let go at alpha 0.473. SRC_Cancel's first row: start 0.523 vs 1 - a = 0.527.
- Switch row step 0.185 cm. The first row with the Cancel pose drawn moves 2.64 cm in 7.9 ms. That includes about 1.9 cm
  of play at about 240 cm/s, so the pose mismatch is about 0.7 cm (**inferred**).
- **Cancel steps per 60 Hz equivalent** (34 in-clip steps): median 4.11 cm, max 5.57 cm (the step containing the
  switch), min 1.74. The plateau is about 240-250 cm/s. This exceeds the 1.5 cm rule.
  - Inferred: about 1.9 s of k_CancelSecondsFromFullStrain would hold it.
- Ends on SRC_Idle 0.342 s after the first Cancel row. `bed1_after_cancel`: charges=1, released=0.
- The full-speed second pull broke; `bed1_after` reads released=1.
- The gloves still leave on the let-go (Script side).

**confirmed** (the measured numbers).

### Captures, my read
- `sheet_bed0.png` (first person: K0 prompt, K1 grip, K2 0.3, K3 0.7, K4 full strain, K6 break).
  - K0 / K1: the gloves on the bed.
  - From K3 on, the stretched stalks run from the bed straight down out of the bottom of the frame toward the camera,
    with the gloves already below the frame. At 4x the gloves and leaves are off-screen at full strain; only the green
    rods are seen converging on the bed.
  - The white root at the bottom-left of K3 to K6 is the review map's floating `Display_HandHeight_SK` display actor (at
    -205, 0, 135), not the pull.
- `zoom_K4b_stalks_fp.png`: the five stalks show flat light / dark bands per face, faceted as at 2x.
- `K5_full_strain_side.png`, `zoom_K5_rods_side.png`, `zoom_K5_cone_side.png` (side, full strain).
  - About 1.5 m of thin straight rods run from the chef's hands to the bed, with the leaves bunched at the far end. They
    read as a long thin pole, square in section (flat olive / yellow faces).
  - Near the bed **the stipple reads as a dashed yellow / dark line along the rods**: at that size it is a dotted
    pattern, not a texture.
  - The base is a smooth pink cone low in the soil, the rods joined at its apex; no neck.
- `sheet_side_bed1.png`: K7 the root in the air; K8 to K10 the cancel, with the gloves leaving at once.
- `R/captures/pie/run-08-walk-clip/sheet_pull_side.png` (capture_pie_movement_clip, 185 frames, `poll.json` ok true,
  0 ensures).
  - Frames 028-038: idle and grip.
  - Frames 040-048: the rod lengthens low toward the chef across the floor while the cone stays in the bed.
  - Frames 050-052: the root airborne.
  - About 3 game fps.

### Ensures, dirty, Sandbox  **confirmed**
- Mars.log 8795-9600 (the reimport, run-08 and the clip): 0 `Ensure condition failed`, 0 `Full Reload is required`.
- 0 dirty packages. The Sandbox mtime is 2026-11-07 21:08, unchanged.

### Rerun
```text
run_python execute_file: D:/Repositories/CkRepos/Orion/Tools/LevelDesign/screaming_turnip_r01_review/phaseJ/reimport_phaseJ_ue.py import 1e
start_pie; run_python: w.WALK_CM = 146.2; t.begin("run-08-walk"); w.state["full_speed"] = 400.0; w.state["track_focus"] = True;
  w.sample_start(); w.state["track_focus"] = True; w.run_06(30.0, 0.25, "run-08-walk", 0.45, side=(70.0, 260.0), speed2=400.0)
  ... w.finish(); stop_pie
capture_pie_movement_clip duration 60, interval 0.15, probe at 1.5 s: w.clip_drive_06('run-08-walk-clip', 30.0, 146.2)
WALK_CM=146.2 python phaseJ/analyse_walk.py captures/pie/run-08-walk/walk_rows.json
python phaseJ/ray_focus.py captures/pie/run-08-walk/walk_rows.json captures/pie/run-08-walk/ray_focus.json
```

### Not verified / findings for Fable
- The cancel at 4x is about 4 cm per 60 Hz frame. A span of about 1.9 s would hold 1.5 cm (inferred).
- At full walking speed the spring trails by up to 0.54, and the root breaks 131 cm past WalkCm.
- The ray-vs-probe test is geometric, from the camera manager's view. The game's own trace result is not read; the
  focused flag and the ring are the game's own evidence that the pin held.
- In first person at 4x the gloves and leaves leave the frame by full strain.
- Faceting and the stipple read as noted.
- The claim I'd most expect to be wrong: that the pinned focus holds in a real session with mouse look. The driver
  re-aims the camera at the bed every tick.

## Phase J Part 3e - the bed's spring at 400 / 40: full-speed pulls, the mid-pull stop, run-09 / run-10 / run-10b (Opus, 2026-11-09) - DONE, awaiting Fable audit

No reimport and no Unreal writes. Driver and analysis files are under `R` = `Tools/LevelDesign/screaming_turnip_r01_review/`.
The editor is left running on the review map with PIE stopped.

### Preflight  **confirmed**
- Mars.log 9613-9618 is the hot compile of `Mars_ScreamingTurnipBed_EntityScript` (k_PullStiffness 400, k_PullDamping 40,
  lines 62-63). It ends in `new module swap-in`, with no error lines and 0 `Full Reload is required`.
- PIE was off, 0 packages were dirty.

### Finding: a stiff spring releases the root early on one long frame  **confirmed** (rows + reproduction)
- run-09 bed 0 (full speed, `R/captures/pie/run-09-walk/walk_rows.json`). The last visible row is at game 2.6576: walked
  75.4 cm, drawn alpha 0.295, ring 0.304. The next tick, the L2 screenshot's, lasted **0.0955 game s**; the planted root
  was then hidden and the bed reports released=1.
  - The root came out at 114 cm walked with the drawn alpha at 0.30. That is a Succeeded threshold, not a cancel.
- Reproduction (`R/phaseJ/run09_spring_step.txt`). One step of the Control's semi-implicit Euler
  (`Mars_Control_Processor_Tick.as`: v += a dt, x += v dt; dt capped at k_MaxStepSeconds 0.1 s) with 400 / 40, starting
  from the sampled state (alpha 0.295, velocity 2.35 /s, pull 0.782):

  | step dt | alpha after one step |
  |---|---|
  | 0.0167 s | 0.362 |
  | 0.050 s | 0.665 |
  | 0.070 s | 0.954 |
  | 0.080 s | **1.129**: crosses EngageAlpha 0.97 |
  | 0.0955 s | **1.440** |

  The old 60 / 12 spring reaches 0.529 on the same 0.0955 s step.
- So any frame of about 0.07-0.08 s or longer in mid-walk (under ~13 fps) can pop the root early. This is **inferred**
  from the reproduction for states other than the sampled one.
- The run-09 bed 0 full-speed pull is therefore void for the overshoot number. run-10 redid it with no screenshots, and
  run-10b took the side capture at slomo 0.1 (screenshot ticks <= 0.034 game s).

### Full-speed pulls (input scale 1.0; walk up to 425-436 cm/s)
| run / bed | file | walked at the break | vs WalkCm 146.2 | trail max | ticks (dt max) |
|---|---|---|---|---|---|
| run-10 bed 0 (no screenshots) | `R/phaseJ/run10_fast_bed0.txt`, `R/captures/pie/run-10-walk/fast_bed0.json` | 212.05 cm (alpha 0.967, ring 0.997) | **+65.9** | 0.263 | 83 (0.0103 s) |
| run-10 bed 1 (screenshots, slomo 0.1) | `run10_fast_bed1.txt`, `fast_bed1.json` | 216.9 | +70.7 | 0.238 | 172 (0.036) |
| run-10b bed 0 (side shot, slomo 0.1) | `run10b_fast_bed0.txt`, `R/captures/pie/run-10b-walk/fast_bed0.json` | 208.3 | +62.1 | 0.264 | 195 (0.034) |
| run-08 (60 / 12, for reference) | Part 3d | 276.8 | +130.6 | 0.54 | |

- **The overshoot halves (+131 -> +62..71 cm) but is not within ~25 cm.** **confirmed**.
- Inferred: the trail plateaus at about 0.26, i.e. a steady lag of about 0.09 s at 425 cm/s (Damping / Stiffness =
  0.1 s), plus the critically damped tail to 0.97 after the walk passes WalkCm.
- Gloves, run-10 bed 0: glove(n) vs socket(n-1) 0.000 cm on all 83 rows, same tick <= 4.74 cm, 0 reach-cap shortfalls.
- Run-10 bed 1 and run-10b rows under the chase view are not glove evidence: the gloves follow the view, 32-37 cm off.
- **Arm reach**: eye-to-glove went from 82.9 cm at the press to **196.1 cm at the break**, with the player 322.5 cm from
  the bed (`R/phaseJ/run10_reach.txt`). FPHands MaxReachCm is unset, so the gloves never fall short.
- Ring: abs(ring x 0.97 - alpha) <= 0.00014 in all three pulls.

### The mid-pull stop (run-09 bed 1, `R/captures/pie/run-09-walk/run09_analysis.json` `bed1_stop`, `R/phaseJ/run09_summary.txt`)
- Full speed until the target reached 0.5, then no input, held for 1 s.
- The player slid 6.3 cm after the stop: the target went 0.556 -> 0.599.
- Alpha at the stop was 0.325 (0.23 behind). It rose monotonically to 0.5986.
- **Overshoot: -0.0001**, none. **Settled within 0.01 of the target 0.251 s after the stop.** The asked 0.2 s is missed by
  0.05 s; the remaining distance was 0.27 alpha.

**confirmed**.

### Cancel, charge, slow pull (run-09 bed 1)  **confirmed**
- Let go at alpha 0.5986. SRC_Cancel's first row t 0.0936 = start 0.4011 vs 1 - a = 0.4014.
- `bed1_after_cancel`: charges=1, released=0.
- Slow pull 2 at 30 cm/s: the break at 144.55 cm walked (-1.65 vs WalkCm), alpha 0.969 (ring 0.999), trail <= 0.020.
  `bed1_after` reads released=1.

### Captures, my read
- `R/captures/pie/run-10-walk/sheet_fast_bed1.png`.
  - M1 grip: the gloves on the stalks under the prompt.
  - M2 mid-walk (60 cm walked): the turnip still nearly upright; the stretch lags the walk.
  - M3: **void**. The side camera was placed outside the room (bed 1 + 260 cm on x) and shows only the wall.
  - M4 break: the stalks run from the bed down off the frame bottom.
  - M5: the root in the air, the gloves returning.
- `R/captures/pie/run-10b-walk/N3_midwalk_side_viewport.png` (side, 101 cm walked, alpha 0.43, full speed).
  - The chef is well clear of the bed. The leaves reach only about 60 cm out from a pink cone, so a gap of roughly 40 cm
    separates the leaf end from the chef's hands: the spring lag, seen.
  - The FP gloves do not render in third person, so the "arm stretch" is not visible on the body. It is measured above as
    the 196 cm eye-to-glove reach.
- run-09's L1-L4 screenshots: L1 / L2 are valid. L3 and L4 were taken after the early release, so they show the empty bed.

### Ensures, dirty, Sandbox  **confirmed**
- Mars.log 9666-10396 (run-09, run-10, run-10b): 0 `Ensure condition failed`, 0 `Full Reload is required`.
- 0 dirty packages. The Sandbox mtime is 2026-11-07 21:08, unchanged.

### Rerun
```text
start_pie; run_python: w.WALK_CM = 146.2; t.begin("run-09-walk"); w.state["full_speed"] = 400.0; w.sample_start(); w.run_09(0.25)
  (run-10: w.run_10("run-10-walk"); run-10b: w.run_10b("run-10b-walk")); poll; w.finish(); stop_pie
python phaseJ/analyse_run09.py captures/pie/run-09-walk/walk_rows.json captures/pie/run-09-walk/run09_analysis.json
python phaseJ/analyse_fast.py captures/pie/run-10-walk/walk_rows.json 0 0 fast0_start captures/pie/run-10-walk/fast_bed0.json
```

### Not verified / for Fable
- **The stiff spring's early release on a long frame** is a Script-side issue in the Control kernel's integration, not in
  the bed. Possible fixes, Fable's call:
  - substep the spring (dt slices <= 1/60 s);
  - an exact critically damped step;
  - lower stiffness.
- The overshoot is +62..71 cm, not within ~25. Damping / Stiffness sets the lag: 0.1 s at 400 / 40.
- The settle is 0.25 s, not 0.2.
- The claim I'd most expect to be wrong: that the early release needs a frame as long as 0.07 s. That threshold is from
  one sampled state; a faster alpha velocity lowers it.

## Phase J Part 3f - the Control's substepped spring (1/240 s): run-11 (Opus, 2026-11-09) - DONE, awaiting Fable audit

No reimport and no Unreal writes. `R` = `Tools/LevelDesign/screaming_turnip_r01_review/`. The editor is left running on the
review map with PIE stopped.

### Preflight  **confirmed**
- Mars.log 10409-10415 is the hot compile, structural, of `ECS.Control.Mars_Control_Processor_Tick` and
  `Generated.Mars_ScriptProcessorDrivers`. It ends in `new module swap-in`; lines 10397-10613 hold 0 errors and 0
  `Full Reload is required`.
- The code reads `k_MaxSubstepSeconds = 1/240`, with the frame still capped at 0.1 s (`Mars_Control_Processor_Tick.as`
  lines 16-18, 55-61).

### The reproduction against the substepped update (`R/phaseJ/run11_spring_substep.txt`)  **confirmed** (arithmetic)
Same sampled state as Part 3e: alpha 0.2952, velocity 2.346 /s, pull 0.7821.

| frame dt | substeps | alpha after the frame |
|---|---|---|
| 0.0955 s | 23 | **0.6087** (was 1.440 in one step) |
| 0.07 s | 17 | 0.540 |
| 0.1 s (and any longer frame, capped) | 24 | 0.619 |

No frame length crosses 0.97 from this state.

### run-11 bed 0: full speed with screenshots at normal time (slomo 1)
Files: `R/captures/pie/run-11-walk/fast_bed0.json`, `R/phaseJ/run11_fast_bed0.txt`.
- d0 110.42 cm. 13 Tug ticks: the sampler runs at about 25 fps at normal time.
- **The root released only past WalkCm.** The last visible tick was at 204.86 cm walked (+58.7 vs 146.2), alpha 0.924
  (ring 0.952). The release fell inside the next tick, the P3 screenshot's **0.4 s** tick, during which the player
  reached 345.9 cm. **confirmed**.
- **Ticks longer than 0.05 s while the root was visible: one.** Game 3.4962, dt 0.3625 s (the P2 screenshot's tick):
  alpha 0.4202 -> 0.7890, **delta +0.369**, walked 74.4 -> 199.6 cm (target 0.51 -> 1.0).
  - So "never more than 0.1 per tick" **fails on that tick**. It is the walk of a 0.36 s frame, not an overshoot: the
    target itself moved +0.49, and the Control integrates only the first 0.1 s (the cap).
  - No other tick moved more than 0.07. The run-09 failure (a Succeeded at drawn alpha 0.30) did not recur.
  - Inferred: from the spring's state at 3.13 a 0.1 s substepped integration toward 1.0 ends near 0.79.
- Gloves: glove(n) vs socket(n-1) 0.000 cm on every tick. Same tick up to 18.5 cm on the long ticks; that is one frame of
  socket travel.
- Ring: abs(ring x 0.97 - alpha) <= 0.00012.

### run-11 bed 1: as run-09 (slomo 0.25; `R/captures/pie/run-11-walk/run11_analysis.json`, `R/phaseJ/run11_summary.txt`)  **confirmed**
- **Stop at target 0.5.** The player slid 6.0 cm after the stop (target 0.547 -> 0.588).
  - Alpha at the stop 0.312, rising monotonically to 0.5884.
  - **Overshoot 0.0001.**
  - **Settled within 0.01 at 0.243 s** (run-09: 0.251 s).
- **Cancel.** Let go at alpha 0.5884; start 0.4119 vs 1 - a = 0.4116. `bed1_after_cancel`: charges=1.
- **Slow pull 2.** The break at 144.70 cm walked (-1.5 vs WalkCm), alpha 0.970 (ring 0.9997), trail <= 0.020.
  `bed1_after` reads released=1.

### Captures, my read (`R/captures/pie/run-11-walk/sheet_fast_bed0.png`)
- P1 grip: the gloves on the stalks under the prompt.
- P2 mid-walk at 74 cm: the turnip only starting to lean; leaves and stalks under the prompt.
- P3, the hitch-frame mid-walk at 205 cm: the stretched stalks run toward the camera with the leaves and gloves in view
  below the prompt, and the pink cone at the bed.
- P4: taken on the release tick, so it is after the break. The root is airborne and the gloves are returning, blurred.
- The white root at the left of P3 / P4 is the review map's display actor.

### Ensures, dirty, Sandbox  **confirmed**
- Mars.log 10614-10872 (run-11): 0 `Ensure condition failed`, 0 `Full Reload is required`.
- 0 dirty packages. The Sandbox mtime is 2026-11-07 21:08, unchanged.

### Rerun
```text
start_pie; run_python: w.WALK_CM = 146.2; t.begin("run-11-walk"); w.state["full_speed"] = 400.0; w.sample_start(); w.run_11("run-11-walk")
  ... w.finish(); stop_pie
python phaseJ/analyse_fast.py captures/pie/run-11-walk/walk_rows.json 0 0 fast0_start captures/pie/run-11-walk/fast_bed0.json
python phaseJ/analyse_run09.py captures/pie/run-11-walk/walk_rows.json captures/pie/run-11-walk/run11_analysis.json
```

### Not verified
- A sampled tick at the exact crossing: the release fell inside a 0.4 s screenshot tick.
- The "<= 0.1 alpha per tick" rule cannot hold on a 0.36 s frame where the target itself moves 0.49. It holds on every
  tick of 0.044 s or less (max 0.07).
- The claim I'd most expect to be wrong: that no long frame can still pop the root early. That is shown for one sampled
  state plus one 0.36 s frame, not for every state.

## Phase J - Fable audit addendum 2 (2026-11-09): 4x shipped (Parts 1e / 3d / 3e / 3f), spring stiffened and substepped; ACCEPTED, uncommitted

- Shipped 4x: crown travel (-144, +20) cm, sockets 146.17 cm, `k_StretchTravelCm = 146.2`, SK weights top ring 0.01 /
  dimple 0.03 (the bulb top is a flat cone in the soil), SK bounds to x -171.7. Readback exact (crown f15 -143.9856 / 51.7974).
- PIE run-08: the pinned focus carries the pull past the 250 cm trace (full-speed pull: ray off the probe from 279 cm,
  focused and ring up to the break at 388 cm). Slow pull: alpha vs distance within 0.001 at rest. 0 ensures.
- Fable edits this round (Script, both lane-proven): bed spring 60/12 -> 400/40 (the lever's spring trailed a full-speed
  walk by alpha 0.54 and broke 131 cm past WalkCm); then the Control kernel's spring integrator now substeps at <= 1/240 s
  (`Mars_Control_Processor_Tick.as`): the single semi-implicit Euler step at 400/40 carried alpha 0.30 -> 1.44 on a 0.0955 s
  hitch frame and popped the root early (run-09); substepped it gives 0.61 and no frame length crosses the threshold from
  that state. Lanes after the fix: Control 74/0, ScreamingTurnip 12/0 (`Saved/Logs/TurnipJ/*_3f.out`).
- PIE run-10/11 on the fixed spring: full-speed break 59-71 cm past WalkCm (trail plateau ~0.26, the 0.1 s lag of 40/400),
  mid-pull stop overshoot 0.0001 and settle 0.24 s, cancel at 1 - a, charge kept, slow pull breaks 1.5 cm short of WalkCm.
- Rulings: the per-tick alpha rule is restated as "no overshoot past the walked target" (a 0.36 s screenshot frame moved
  the target 0.49); the cancel-speed rule stays relaxed (4-5 cm per 60 Hz frame at 4x, span 0.7 s); the 60-70 cm
  full-speed overshoot is the spring's load read, tunable at `k_PullStiffness` / `k_PullDamping` (stiffer = less).
- Maintainer's questions answered: the stretch amount is NOT tunable in Unreal today (authored crown travel in SRC_Tug,
  WalkCm must match). Proposed next phase: a runtime crown-bone driver scaling the clip's crown translation by a bed
  `StretchTravelCm` param (the clip keeps the lean/trail/tilt), so no Blender round per distance. Stem look at 33x stretch
  (square rods, stipple between neighbours) is the other open call (6-8 sided, tapered stems = mesh change + SK reimport).


## Phase K Part 1 - Blender: the clips keep only the pose; the stretch audited as a runtime offset (Opus, 2026-11-09) - DONE, awaiting Fable audit

Brief: `PHASE_K_BRIEF.md` D-K2 Blender bullet and Part 1. No Unreal, no `Script/` writes (one read-only `rg` over the bed
script to check which clips it plays), no git, no deletes.

**Only SRC_Tug / SRC_Cancel / SRC_Release changed; the mesh and weights did not, so Part 3 reimports those three clips
only (no SK).**

### Files
- `source/ScreamingTurnip_R01_phaseJ.blend`: the backup, a byte copy before any write. md5 c81a59bc..., == the Phase J 1e
  blend.
- **`scripts/animate_screaming_turnip.py`**:
  - STRAIN / TUG_MID lose the authored travel (below).
  - New `inject_audit()` and the `--inject-stretch T,L` mode (audit only; no actions written, no save).
  - The normal run now gates SRC_Tug / SRC_Cancel on the injected default (`DEFAULT_STRETCH = (146.2, 20.0)`). Their
    standalone intersections (offset 0) are recorded as `standalone_isect_info`.
  - Clip notes rewritten. The `--variant 3x` flag is marked obsolete (kept for the 1d record).
- **`scripts/export_screaming_turnip.py`**:
  - `gameplay_numbers.k_StretchTravelCm` is replaced by `k_StretchTravelCm_default` (146.2), `k_StretchLiftCm_default`
    (20.0), `stretch_runtime_safe_travel_cm` and a `stretch_note`, read from `review/<rev>/inject_summary.json`. The
    export fails if that file is missing.
  - The clip-only neck gate is now absolute (<= 9 cm x / <= 3 cm z). The percentage and ring-below-dimple rules are
    meaningless with 2 cm of clip travel; the stretched neck is gated through the injection.
  - The crown_travel `stretch` block reports `clip_socket_travel_cm`.
- **`scripts/render_anims_screaming_turnip.py`**: `--inject-stretch T,L` poses Tug / Cancel as spline + offset.
- **New** `review/phaseK/inject_summary_k.py` (plain Python, TURNIP_OK / _FAIL): summarises the runs into
  `inject_summary.json`.
- **Outputs**: `review/phaseK/` (anim_report, crown_travel, neck, the inject_T_L.json runs + logs, inject_summary.json,
  rebuild_compare.json, expected_anims_diff.json, sheets, `baseline/`) and `export/` (16 clips, SK, statics, manifest,
  reports).

### Poses (design cm; DEV-K-1)
| | Phase J 1e (4x) | Phase K |
|---|---|---|
| STRAIN | cr_dx -44.249, cr_dz 12.023 | **cr_dx +0.6512, cr_dz -0.0915**; cr_y -60, bh 1.04, bw 0.98, brot -8, la -12, lb -7 unchanged |
| TUG_MID | cr_dx -25.534, cr_dz 4.864 | **cr_dx +0.3289, cr_dz -0.0230**; cr_y -50, bh 1.02, bw 0.99, brot -4, la -10, lb -6 unchanged |

**DEV-K-1 (decided, not asked): not the brief's cr_dx = 0 / cr_dz = 0.**
- Measured with cr_dx = 0 / cr_dz = 0, the 8 deg body tilt alone carries the crown head to x -2.05 cm at STRAIN (-1.01
  at TUG_MID). That would break the brief's own Part 3 readback (f15 crown x within 0.05 of f0) and add 2 cm to every
  tuned travel.
- So cr_dx is solved to hold the crown head at x 0, and cr_dz is solved to keep the z that cr_dz = 0 gives.
- **Exported crown head x over SRC_Tug: max |x| 0.016 cm** (f0 0.0, f8 0.0003, f15 0.0); SRC_Cancel 0.0013, SRC_Release
  0.012 (`crown_travel.json`).
- Crown z 31.80 -> 33.86 (+2.07 from the bulb's bh 1.04). Note for Part 2: a LiftCm of 20 puts the crown at +22.1 over
  the grip, 2 cm higher than Phase J's +20. A LiftCm of 18 would reproduce Phase J's full-strain height (inferred from
  the sum).
- Undo: set both to 0.0 in STRAIN / TUG_MID and re-run.

### Injected-stretch audit (`review/phaseK/inject_T_L.json`, `inject_summary.json`)  **confirmed**
Method:
- Offset (-T * a, 0, L * a) UE cm added to the crown's armature-space matrix on top of the authored spline pose.
- a = f / 15 on SRC_Tug and 1 - f / 7 on SRC_Cancel. SRC_Release uses a = 1 - f / 6 as info only: the bed never plays it
  (`rg` over `Mars_ScreamingTurnipBed_EntityScript.as`: Grip, Tug scrub, Cancel, PlantedIdle only).
- Gates: every intersection category 0; stem_gap <= 0; neck = dimple <= 9 cm x / <= 3 cm z from Tug f0 and ring below
  the dimple.
- The brief's four points use its L. The others use L ~ 0.137 T (146.2 / 20).

| T / L (cm) | result | first failing gate (frame) | Tug f15 crown (x, z) | dimple d (x, z) / ring | stem_gap max |
|---|---|---|---|---|---|
| 0 / 0 | FAIL 35 | intersections leaf_vs_bulb 28 on Tug f7-f15, Cancel f0-f3; neck (ring > dimple) | (0, 33.87) | (-1.99, 1.05) / 2.47 | -0.120 |
| 5 / 0.7 | FAIL 31 | **stem_gap +0.921** (a stem base lifts out); neck ring rule | (-5, 34.57) | (-2.14, 1.07) / 2.52 | +0.921 |
| 10 / 1.4 | FAIL 14 | neck ring rule only (ring 1.1-2.6 cm > dimple; both < 2.6 cm) | (-10, 35.27) | (-2.29, 1.09) / 2.56 | -0.733 |
| 20 / 2.7 | PASS | - | (-20, 36.57) | (-2.59, 1.13) / 2.65 | -0.733 |
| 28 / 3.8 | PASS | - | | (-2.83, 1.16) / 2.73 | -0.733 |
| **36 / 5** | **PASS** | - | (-36, 38.87) | (-3.07, 1.20) / 2.80 | -0.733 |
| **74 / 10** | **PASS** | - | (-74, 43.87) | (-4.21, 1.35) / 3.16 | -0.733 |
| **146 / 20** and **146.2 / 20 (default)** | **PASS** | - | (-146.2, 53.87) | (-6.38, 1.65) / 3.85 | -0.715 |
| **220 / 30** | **PASS** | - | (-220, 63.87) | (-8.59, 1.95) / 4.57 | -0.649 |
| 230 / 31.5 | PASS | - | (-230, 65.37) | (-8.89, 1.99) / 4.67 | -0.642 |
| **235 / 32.1** | **FAIL 2** | **neck: dimple x -9.04 > 9** (Tug f15, Cancel f0) | (-235, 65.97) | (-9.04, 2.01) / 4.71 | -0.638 |
| 240 / 32.8 | FAIL 2 | neck dimple x -9.19 | | | |
| 260 / 35.6 | FAIL 3 | neck dimple x | | | |
| 280 / 38.3 | FAIL 5 | neck dimple x | | | |
| 300 / 41 | FAIL 6 | neck dimple x; **outer_shell_self 26 at Tug f6** | | (-10.99, 2.28) / 5.36 | -0.596 |
| 400 / 55 | FAIL 9 | neck dimple x | | (-13.99, 2.70) / 6.35 | |
| 500 / 68 | FAIL 13 | neck dimple x; leaf_vs_leaf 12 / outer_shell_self 26 at Tug f3-f4 | | (-16.99, 3.09) / 7.34 | |

- **Safe travel: 20..230 cm** (manifest `stretch_runtime_safe_travel_cm` [20.0, 230.0]).
- **The first failure above the default is at 235 cm**: the neck gate, the bulb-top dimple dragged 9.04 cm (> 9) at full
  strain.
- The first non-neck failure above it is at 300 cm (bulb shell self-intersection mid-pull).
- Below 20 cm only the relative ring-below-dimple rule fails at 10 cm; that is no visible neck, both move under 2.6 cm.
- The real low-end limits: a stem base lifts out at 5 cm, and at 0 cm the pitched crown lays the leaves into the bulb.
- SRC_Release at the default (info): leaf_vs_leaf 40 and dimple z +5.1 at f2. That is the REL_OVER bh 1.10 overshoot
  with half the offset still applied, under an assumed alpha. Unused by the bed.

### Gates on the shipped clips  **confirmed**
- **Animate**: exit 0, `TURNIP_OK (16 clips, 19 s)`; `anim_report.json` `fails: []`.
  - Every non-SRC clip is gated as before: 0 intersections, stem_gap <= 0.
  - SRC_Tug / SRC_Cancel / SRC_Release standalone: leaf_vs_bulb 28 recorded as info. These clips never render without
    the offset.
  - The injected default gates Tug / Cancel: `INJECT T 146.2 L 20: fails 0`, stem_gap -0.715, full-strain socket R
    (-149.91, 4.68, 53.72).
  - SRC chain joints 0. Envelope back to d_x 42.16 (clip-only).
- **Export**: exit 0, `TURNIP_OK`. Neck (clip-only, absolute gate) dimple (-1.99, 1.05).
- **Round trip**: exit 0, `TURNIP_OK`; `fails: []` in both reports.
- **Diff proof**:
  - Command: `python scripts/diff_expected_anims.py review/phaseK/baseline/expected_anims.json
    export/anims/expected_anims.json --expect-changed SRC_Tug,SRC_Release,SRC_Cancel --out
    review/phaseK/expected_anims_diff.json` (full compare, tol 0.001 cm).
  - Result: exit 0, `TURNIP_OK (3 changed: ['SRC_Cancel', 'SRC_Release', 'SRC_Tug'])`.
  - Every ROOT_* clip, SRC_Idle and SRC_Grip: 0.0 on every leaf. SRC_Tug's exported crown head is fixed in x (above).
- **Mesh / weights** (`compare_rebuild` against `source/ScreamingTurnip_R01_phaseJ.blend`, `review/phaseK/rebuild_compare.json`):
  - 1624 / 3188, polygons and material indices identical.
  - Rest, shape keys, vertex colour, bones and statics all 0.0; id props identical.
  - **0 weight changes.** `TURNIP_OK`.
  - `export/expected.json` (bind / statics facts) is byte-identical to the Phase J baseline. The SK FBX was re-written by
    the export; the same mesh and weights went in.
- **Manifest**:
  - `k_StretchTravelCm` is gone. `k_StretchTravelCm_default` 146.2, `k_StretchLiftCm_default` 20.0,
    `stretch_runtime_safe_travel_cm` [20.0, 230.0], plus the tuner `stretch_note`.
  - `scale_factor` 3.0; `rig_contract` untouched.
  - The `clips` envelope / bounds are now clip-only: Part 3's SK bounds come from the presentation's `BoundsScale`, not
    the manifest.

### Not run this round
- `cancel_match_j.py`: it writes into review/phaseJ. With the crown fixed in x, the Tug(a) / Cancel(1 - a) pose mismatch
  should be far smaller than Phase J's, and the offset is the same alpha on both sides (inferred; Part 3 measures the
  switch).
- The 0.1-frame sub-frame audit: it runs on the standalone actions, which intersect by design now. The injected audit is
  per whole frame.

### Sheets (looked at; `review/phaseK/`)
- **`SRC_Tug_sheet.png` and `SRC_Cancel_sheet.png`** (front / side / 3/4) and **`pull_chain_sheet.png`**, all with the
  injected 146.2 / 20 offset. Framing `--ortho 70 --target -28,0,8.5`.
  - The stalks stretch toward -X and the leaves pitch and trail as in Phase J.
  - **`compare_f15_phaseK_injected_vs_phaseJ_1e.png`**: f15 injected (top) against the Phase J 1e clip (bottom) are the
    same picture. The tuft sits about 2 cm higher (the LiftCm note above).
  - Mid-pull (f2-f6) the offset is linear in alpha while the pitch and leaves follow the authored ease. At f2 / f4 the
    crown is already 20-40 cm out with the leaves still nearly upright, then the pitch catches up by f8. That is the
    D-K3 lead / trail. It reads as the stalks stretching first and the leaves tipping after, and it is visible.
- **`standalone/SRC_Tug_sheet.png`**: the clip alone (offset 0). The crown pitches to -60 over the bulb and the leaves
  lie on and into the bulb and bed, which is the 28-pair `leaf_vs_bulb` info. It only shows if the tuner goes below about
  10 cm.
- The release sheet was not re-rendered (unused by the bed; standalone it starts in the same intersecting pose).

### Rerun (from this folder)
```bash
B="C:/Program Files/Blender Foundation/Blender 5.2/blender.exe"
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python scripts/animate_screaming_turnip.py -- --review phaseK
for tl in 0,0 5,0.7 10,1.4 20,2.7 28,3.8 36,5 74,10 146,20 220,30 230,31.5 235,32.1 240,32.8 260,35.6 280,38.3 300,41 400,55 500,68; do
  "$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python scripts/animate_screaming_turnip.py -- --inject-stretch $tl --review phaseK
done      # failing points exit 1 / TURNIP_FAIL by design
python review/phaseK/inject_summary_k.py
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python scripts/export_screaming_turnip.py -- --review phaseK
"$B" -b --factory-startup --python scripts/validate_roundtrip.py
python scripts/diff_expected_anims.py review/phaseK/baseline/expected_anims.json export/anims/expected_anims.json --expect-changed SRC_Tug,SRC_Release,SRC_Cancel --out review/phaseK/expected_anims_diff.json
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python scripts/compare_rebuild_screaming_turnip.py -- --ref source/ScreamingTurnip_R01_phaseJ.blend --out review/phaseK/rebuild_compare.json
"$B" -b --factory-startup source/ScreamingTurnip_R01.blend --python scripts/render_anims_screaming_turnip.py -- --out phaseK --clips SRC_Tug,SRC_Cancel --views front,side,threequarter --no-shapekey --pull-chain --ortho 70 --target -28,0,8.5 --inject-stretch 146.2,20
```
Each gate printed TURNIP_OK with exit 0 on the final code; the inject runs as tabled.

### For Part 2 / 3
- The anim instance offset must be component space, Add, on `crown`, exactly (-TravelCm * a, 0, LiftCm * a).
- The clips' crown head stays at x 0 (|x| <= 0.016 cm), so Part 3's readback of x within 0.05 holds (confirmed in the
  export).
- The pull chain at the default reproduces Phase J's full-strain look.
- Validate (Part 2): TravelCm outside 20..230 still deforms legally per the audit's gates except as tabled. The Validate
  rule in the brief is only "travel > 0". Consider whether `stretch_runtime_safe_travel_cm` should bound it (Fable's call).

### Not verified
- Unreal: the ABP's ModifyBone matching this Blender-side injection, especially the component-space order against the
  scrubbed pose.
- The sub-frame audit with the offset.
- **The claim I'd most expect to be wrong**: that the Blender injection (translate the crown's armature-space matrix after
  the pose) equals Unreal's ModifyBone Add in ComponentSpace. They should agree because both translate the bone's
  component transform and the children follow. That is unchecked until Part 3's readback.

## Phase K Part 2 - Script: the stretch is a bed tuner, the presentation plays through an anim blueprint (Opus, 2026-11-09) - DONE except the map builder args (blocked, below); awaiting Fable audit

Brief: `PHASE_K_BRIEF.md` D-K2 and "Part 2", plus the coordinator's addendum (the safe travel range 20..230 cm, LiftCm 18,
manifest-key comments). No git, no `Script/Generated/*` by hand, no tags ini.

### Files

- `Script/WorldObjects/Forage/Mars_ScreamingTurnipBed_PullSpec.as` (new):
  - `FMars_ScreamingTurnipBed_StretchSpec` {TravelCm 146.2, LiftCm 18}, `_SpringSpec` {Stiffness 400, Damping 40,
    EngageAlpha 0.97}, `_TimingSpec` {GripSeconds 0.4, CancelSecondsFromFullStrain 0.7, TurnDegreesPerSecond 540}.
  - `FMars_ScreamingTurnipBed_PullSpec` {Stretch, Spring, Timing}. Every struct has UPROPERTY fields and full positional
    ctors.
  - `mixin Validate`: travel positive and finite, then inside [20, 230] cm (the error names the range); lift finite;
    stiffness > 0; damping >= 0; engage alpha in (0, 1]; both spans > 0; turn rate > 0. Each error names its field
    (`Pull.Stretch.TravelCm`, ...).
- `Script/WorldObjects/Forage/Mars_ScreamingTurnipBed_EntityScript.as`:
  - `UPROPERTY(ExposeOnSpawn) Pull` replaces `GripSeconds` and the private spring / turn / cancel constants.
    `k_MinAimCm` and `k_MinSpannedStrain` stay constants.
  - `DoConstruct` validates first and on failure ensures (`rejected the Pull: ...`), destroys the entity and composes
    nothing.
  - The Control's WalkCm, stiffness, damping and threshold come from the tuner. The +2 cm socket swing is documented at
    `Make_ControlSpec`.
  - The follow tick sets the stretch alpha: `1 - Get_PlayedAlpha()` while SRC_Cancel plays, else the Control's alpha,
    else 0. It passes `Set_Stretch(FMars_ScreamingTurnip_Stretch(alpha, TravelCm, LiftCm))`, still scrubs the Tug and
    still turns.
  - The stretch is set to 0 at rest (the planted component's add, which widens the bounds before the first pull), when
    the follow ends, and in `OnForageReleased` before the visuals swap.
- `Script/Items/Presentation/Mars_ScreamingTurnip_AnimInstance.as` (new): `UMars_ScreamingTurnip_AnimInstance : UAnimInstance`
  with `UPROPERTY(BlueprintReadOnly, NotEditable, Category = "ScreamingTurnip")`:
  - `UAnimSequenceBase Sequence`
  - `float32 ClipTime`
  - `FVector CrownOffset` (component space, cm)

  It has no BlueprintUpdateAnimation. The presentation writes the three fields through one method,
  `Set_Pose(Sequence, ClipTime, CrownOffset)`, the bat's `Apply` pattern: I did not rely on another script class
  writing BlueprintReadOnly fields directly.
- `Script/Items/Presentation/Mars_ScreamingTurnipPresentationComponent.as` (rewritten):
  - `default AnimationMode = AnimationBlueprint`. DoInitialize loads the mesh, then `TryLoad_AnimClass()` ->
    `SetAnimInstanceClass` (which sets the mode and initialises the instance) -> cast to the instance.
  - A missing anim class warns once per component and the mesh holds its bind pose. There is no single-node path.
  - The component is the single clock: `_Time += dt * _Rate`. Loop wraps (`Math::Fmod`), one-shots clamp. `SpanSeconds`
    sets `_Rate`, `StartAlpha` seeds `_Time`, `Scrub_Clip` sets `_Time` with rate 0. `Get_PlayedAlpha` and
    `Get_HasPlayedThrough` read `_Time`.
  - Tick order: advance the clock -> refresh from the kernel -> return-to-loop -> write the instance.
  - `Set_Stretch` maps the stretch to `CrownOffset = (-Alpha*TravelCm, 0, Alpha*LiftCm)` and refreshes `SetBoundsScale`
    when the travel or lift changes: `(extent + |(T, 0, L)|) / extent`, with extent the half-diagonal of the mesh's
    imported bounds.
  - `Play_ClipChain` and its queue are deleted.
  - New struct `FMars_ScreamingTurnip_Stretch(Alpha, TravelCm, LiftCm)`.
- `Script/Items/Mars_Item_ScreamingTurnip.as`:
  - `k_StretchTravelCm` deleted.
  - `k_StretchTravelSafeMinCm = 20` / `k_StretchTravelSafeMaxCm = 230` (manifest `stretch_runtime_safe_travel_cm`).
  - `k_AnimBlueprintName = "ScreamingTurnip_R01_Mars_ABP"`, `AnimClass()` (soft class `..._ABP.ScreamingTurnip_R01_Mars_ABP_C`)
    and `TryLoad_AnimClass()`, which asks the registry by the blueprint asset, not the `_C`, then
    `System::LoadClassAsset_Blocking`.
  - The clip comment is updated.
- Tests (`Script/Tests/ScreamingTurnip/`):
  - The rig spawns its bed with an explicit `_BedPull` (travel 120, lift 15, 400/40/0.97, grip 0.2, cancel 0.7, turn
    540). `Get_WalkCmFor` reads `_BedPull.Stretch.TravelCm`.
  - New `Mars_AutoTest_ScreamingTurnipBed_PullSpecValidateRejectsBadTuners`:
    - Accepted: the defaults, a hand-set tuner, and the 230 edge.
    - Rejected, one per rule: travel 0, NaN, under and over the range; NaN lift; stiffness 0; damping -1; engage 0 and
      1.2; grip 0; cancel 0; turn 0.
    - A spawned bed with travel 0: the ensure is expected through a hand-authored `_Actor` wrapper pinned to
      `rejected the Pull: Pull.Stretch.TravelCm [0`, and no Forage or Control is left.
  - New `Mars_AutoTest_ScreamingTurnipBed_WalkDistanceIsTheStretchTravel`: travel 74 gives Control WalkCm 74 and the
    spring values; walking 37 cm reads alpha 0.5 +- 0.05.

### Engine APIs, verified against the engine source (D:/Repositories/UnrealEngine-Angelscript)

- `USkeletalMeshComponent::SetAnimInstanceClass` (UFUNCTION BlueprintCallable, SkeletalMeshComponent.h:1009-1010; it sets
  the mode to AnimationBlueprint).
- `AnimationMode` (UPROPERTY, :620; already set with `default` in this file).
- `UPrimitiveComponent::SetBoundsScale` (UFUNCTION, PrimitiveComponent.h:1474).
- `USkeletalMesh::GetImportedBounds` (UFUNCTION, SkeletalMesh.h:838).
- `UKismetSystemLibrary::LoadClassAsset_Blocking` returns `UClass*` (KismetSystemLibrary.h:429).
- Tick order: `USkinnedMeshComponent::TickComponent` runs the component's own tick (ReceiveTick) before `TickPose` /
  `RefreshBoneTransforms` (SkinnedMeshComponent.cpp:1664-1700), so this tick's writes are this frame's pose.
- `Math::Fmod` / `Math::Sqrt(-1)` / `Math::IsFinite` are used elsewhere in Script.
- `UAnimSequenceBase` as an AS property: compiled clean in the lanes.

### Lanes (`--test --no-live --discover-fresh`, one at a time)

| Pattern | Passed | Failed | Exit | Known reds |
| --- | --- | --- | --- | --- |
| ScreamingTurnip | 14 | 0 | 0 | none ran, no new failures |
| Control | 74 | 0 | 0 | none ran, no new failures |
| Forage | 10 | 0 | 0 | none ran, no new failures |

- Evidence: `Saved/Logs/TurnipJ/K-{ScreamingTurnip,Control,Forage}.out` (`Passed:` at 24463 / 27127 / 24424); editor logs
  `Saved/Logs/Test-TurnipK-<P>.log`.
- The expected ensure fired: `Saved/Logs/Mars_2-backup-2026.11.09-07.05.45.log:2055`. The missing-ABP warning, once per
  component, is in the same log at 1994+.
- The first attempt failed to compile: `'Pull' is not a member of FMars_ScreamingTurnipBed_EntityScript_SpawnParams`.
  The tests used the new spawn field before the generator had emitted it, and the toolbox refused stale bytecode
  (AS_COMPILE_FAILED, exit 76).
- Fix, in two steps:
  1. Pulled the two `Params.Pull` lines out. The live editor (holding the regen lock) hot-compiled and regenerated
     `Mars_EntitySpawnParams.as` with `Pull` (line 19665).
  2. Restored the lines and ran the lanes above.

  The step-1 lane (`K-regen.out`) is discarded.

### Blocked: `Mars.ScreamingTurnip.BuildReviewRoom <bed1 travel> <bed2 travel>` (Part 3 point 3)

Not implemented: AngelScript cannot reach a placed spawner's script instance.
- `ACk_EntitySpawner_UE::_EntityScript` is `UPROPERTY(EditAnywhere, Instanced)`, private, with no BlueprintRead and a
  C++-only getter (CkEntitySpawner_Actor.h:129-147).
- The AS plugin binds such a property edit-only: a class `default`, never read or written at runtime
  (Helper_PropertyBind.h: no read without CPF_BlueprintVisible).
- No Ck UFUNCTION exposes it. Only the CkTests editor C++ (`CkGroundNavStreamingAcceptance_EditorUtils::CreateVolumeSpawner`)
  configures a spawner's script, in C++.
- Kismet's Get/SetEditorProperty are wildcard CustomThunks, not bound in AS.

Options, my order:
1. A small CkFoundation editor UFUNCTION returning a spawner's script instance (e.g. on a `UCk_Utils_EntitySpawner_UE`
   editor library), then the AS builder sets `Pull.Stretch.TravelCm` per bed and rebuilds. Needs a C++ build and a
   CkFoundation change (outside Part 2's Script-only scope).
2. Part 3 sets the travel through editor Python: `spawner.get_editor_property("_EntityScript")` then `set_editor_property`
   on `Pull`. Python honours CPF_Edit. Inferred, not tried.

A builder whose args silently did nothing would be the hack, so it is unchanged.

### Unverified headless (Part 3)

- The ABP does not exist yet, so every lane ran with the "no anim blueprint" warning and the bind pose. The clock, the
  stretch mapping, the bounds scale and the instance writes are exercised only as far as `Get_PlayingClip` /
  `Get_PlayedAlpha`; nothing poses.
- Correction to D-K3: the lanes DO load the skeletal mesh. The TiredAnticipate test asserts `Get_HasMesh`, and the
  per-component warnings name `Mars_ScreamingTurnipPresentationComponent_N`.
- Inferred:
  - The ABP's Sequence Evaluator pins bind to `Sequence` / `ClipTime` and the Modify Bone `Translation` pin to
    `CrownOffset`.
  - The morph curves still drive through the evaluator.
  - The bounds scale keeps the leaves drawn with the bulb off-screen.
  - The crown offset sign: -X is the Use side, as authored.

## Phase K Part 3 - the ABP, the clip reimport, bed 1's travel, PIE run-12 (Opus, 2026-11-09) - DONE, awaiting Fable audit

Brief: `PHASE_K_BRIEF.md` Part 3, with the coordinator's rulings. No git, no Script edits, no deletes, no Save All, no
unload / reload. `R` = `Tools/LevelDesign/screaming_turnip_r01_review/`. The editor is left running on the review map with
PIE stopped.

### Preflight  **confirmed**
- PIE was off, the review map loaded, 0 dirty packages, `list_errored_blueprints` empty.
- Mars.log has no `Full Reload is required`. The last AngelScript reloads (to 14576) swapped in clean; the 12500 hot-reload
  error was fixed by later reloads.
- The parent class `/Script/Angelscript.Mars_ScreamingTurnip_AnimInstance` loads with `Sequence` / `ClipTime` /
  `CrownOffset`.

### The ABP (`R/screaming_turnip_animbp_ue.py`; reports `R/phaseK/animbp_report*.json`)
- **First build, `ScreamingTurnip_R01_Mars_ABP`: compile error.** The builder log reads "[Compiler] Sequence Evaluator (by
  time) references an unknown Anim Sequence Base" (Mars.log, `LogBlueprint: Error`).
  - Cause, read in the engine source: `UAnimGraphNode_AssetPlayerBase::ValidateAnimNodeDuringCompilationHelper`
    (AnimGraphNode_AssetPlayerBase.cpp:501-535) finds the property-access binding only through the EXPOSED pin, and
    `Sequence` is PinHiddenByDefault.
  - Monolith exposes pins only at node creation (`add_anim_graph_node expose_pins`, MonolithAbpWriteActions.cpp:1407-1428).
  - That builder's save step did not wait for the compile verdict, so the errored asset was saved. It stays on disk unused
    (no deletes). **The maintainer should delete it with the editor closed.** It is the only entry in
    `list_errored_blueprints`, so PIE was started with `on_compile_errors: suppress` (accepted by the coordinator).
  - Logs: `animbp_report_build_pass1.json` (every build call ok; the compile step's python failed on a `parent_class`
    read) and `animbp_report_v1_errored.json`.
- **The fix, in the builder:** `expose_pins: ["Sequence"]` on the Sequence Evaluator, and the save now needs
  compile_ok. Both dead ends and every call that worked are in the builder's header.
- **Rebuild to a fresh name per the rule: `ScreamingTurnip_R01_Mars_ABP_v2`.** `TURNIP_ABP_OK`, exit 0, compiled with no
  error line, saved alone (dirty after: []). The coordinator pointed `k_AnimBlueprintName` at it (Mars.log 14894 / 14900).
- Readback (`animbp_report_readback.json`, `--readback-only`, `TURNIP_ABP_OK`):
  - Parent `Mars_ScreamingTurnip_AnimInstance`; skeleton `ScreamingTurnip_R01_Mars_SKEL`; 0 state machines.
  - Nodes: Root, SequenceEvaluator, LocalToComponentSpace, ModifyBone (Bone: crown), ComponentToLocalSpace.
  - Bindings: Sequence <- [Sequence], ExplicitTime <- [ClipTime], Translation <- [CrownOffset], all type Property and
    bound.
  - Links: SequenceEvaluator.Pose -> LocalPose -> ComponentPose -> ModifyBone.Pose -> ComponentToLocalSpace.Pose ->
    Root.Result (`output_connected: true`).
  - Properties set (old -> new): bShouldLoop True -> False; ReinitializationBehavior ExplicitTime -> NoReset;
    TranslationMode BMM_Additive; TranslationSpace BCS_ComponentSpace; Rotation / Scale BMM_Ignore; Alpha 1.0.
  - `list_errored_blueprints` does not list `_v2`.

  **confirmed**.

### Clip reimport: `R/phaseJ/reimport_phaseJ_ue.py clips SRC_Tug,SRC_Cancel,SRC_Release` (`R/phaseJ/reimport_phaseK_clips.json`)  **confirmed**
- Three clips saved; duplicates []; 0 packages dirty before and after; all four readback groups PASS (`TURNIP_OK`).
- **SRC_Tug crown head x over every frame: max deviation from f0 0.0161 cm** (gate 0.05). f15 is (0.0, -0.0, 33.8646),
  err 0.0 vs `review/phaseK/crown_travel.json`.
- Frame counts 15 / 7 / 6; landmark worst <= 8.2e-5 cm.
- Diff against the 1e readback:
  - Clip lines only in the three SRC clips.
  - Mesh: one line, the envelope margin 6.046 -> 6.2. The manifest's envelope is clip-only now; the asset is unchanged
    (**inferred**).
  - Owned / root assets: the two new ABPs.
- No SK reimport.

### Bed 1's travel (editor Python on the review map; the coordinator's ruling 3)  **confirmed**
```python
es = spawner.get_editor_property("_EntityScript")       # ScreamingTurnipR01Review_Bed (Ck_EntitySpawner_UE_4)
p = es.get_editor_property("Pull")                       # the AS struct's fields are not Python-visible (UPROPERTY()
txt = p.export_text().replace("Stretch=(TravelCm=146.199997,LiftCm=18.000000)",   #  without Edit flags), so via text
                              "Stretch=(TravelCm=74.000000,LiftCm=9.000000)")
p.import_text(txt); spawner.modify(); es.modify(); es.set_editor_property("Pull", p)
unreal.get_editor_subsystem(unreal.LevelEditorSubsystem).save_current_level()
```
- Read back after the save: bed 1 `(Stretch=(TravelCm=74.000000,LiftCm=9.000000),Spring=(400,40,0.97),Timing=(0.4,0.7,540))`;
  bed 2 unchanged (146.2 / 18).
- The save wrote only `Content/ArtCandidates/ScreamingTurnip/R01/Review/ScreamingTurnip_R01_Review_MAP.umap` (find
  -newer); dirty after: [].
- `get_editor_property("Stretch")` on the struct is a dead end (the fields are not reflected to Python); export / import
  text is the working route.

### PIE run-12 (`R/captures/pie/run-12-walk/`; analysis `run12_analysis.json`, `R/phaseK/run12_summary.txt`, `R/phaseK/run12_lag.txt`)
- Driver: `run_12` in `R/screaming_turnip_walk_ue.py`, slomo 0.25, 30 cm/s, the 110 cm stand. It now reads the planted
  clip from the AS instance's `Sequence` / `ClipTime` / `CrownOffset`: the single-node readout returns nothing in
  AnimationBlueprint mode. The first attempt with the old readout is `run-12-walk-void-a/`.
- Both planted components run `ScreamingTurnip_R01_Mars_ABP_v2_C` in AnimationBlueprint mode (read at the run start).

**Bed 1 (TravelCm 74 / LiftCm 9).**
- d0 110.39. The root popped at **74.00 cm walked** (alpha 0.961, ring 0.996).
- Crown x vs -alpha x 74: within **0.023 cm on all 342 Tug ticks**. CrownOffset vs (-a T, 0, a L) within 0.008.
- Full strain: crown x -71.14 at alpha 0.961. **Crown x / alpha = -74.005.**
- Sockets travel 73.33 cm at alpha 0.961 = 76.3 per alpha (T + 2.3, the D-K3 swing). Ring vs drawn alpha: see the lag.
- Gloves: 0.000 cm to the previous tick's sockets (223 ticks); same tick <= 1.93 cm, mean 0.32 cm.

**Bed 2 (TravelCm 146.2 / LiftCm 18), pull 2 (the full pull).**
- d0 111.46. The pop at **144.57 cm walked (-1.63)**, alpha 0.967 (ring 0.9995).
- Crown x vs -a T within 0.031 cm (627 ticks). **Crown x / alpha = -146.198.** At the break crown x is -141.32.
- Sockets 143.50 cm = 148.5 per alpha.
- Gloves: 0.000 cm to the previous tick's sockets; same tick <= 2.16 cm.

**"Crown x at full strain = -TravelCm within 2 cm": PARTIAL.**
- The bed never reaches alpha 1: it pops at EngageAlpha 0.97. So the full strain shown is -0.961 x 74 = -71.1 (2.9
  short) and -0.967 x 146.2 = -141.3 (4.9 short).
- The mapping itself is exact: crown x = -a T within 0.031 cm, extrapolated to a = 1 it gives -74.005 / -146.198.

**The one-tick lag is still there** (`run12_lag.txt`). **confirmed**.
- The drawn alpha (instance ClipTime / 0.5) equals the Control's alpha of the **previous** tick within 0.0001. Against the
  same tick it differs by up to 0.026 (the ring runs one tick ahead).
- The gloves sit on the previous tick's sockets (0.000 cm).
- So the pose is one tick behind the Control, and the gloves are one tick behind the pose.
- Inferred cause: the presentation component's tick (it writes the instance) runs before the bed's follow tick (it sets
  the scrub and the stretch) in the same frame.
- The crown matches the instance's own CrownOffset of the same tick: the ABP itself adds no lag.

**Bed 2 cancel** (`bed2_cancel`).
- Let go at alpha 0.462 (the stop is at 0.45). SRC_Cancel's first tick t 0.1308 = start 0.5606 vs 1 - a = 0.5384 plus one
  tick of play (0.0155 x 0.333 / 0.2333 = 0.022): consistent.
- **Switch: the socket step is 0.25 cm** on the switch tick (<= 1.5). The offset holds the Tug value for that one tick,
  then follows the clip.
- **The offset shrinks in step with the clip, one tick late:** CrownOffset.x vs -(1 - played) x T stays about -3 cm,
  i.e. one tick of cancel, on every 60 Hz tick (-18.3 cm on one 0.088 s screenshot tick).
- **Cancel speed: the sockets move 2.8-4.1 cm per ~60 Hz tick**: about 210 cm/s, the 146 cm offset closing in 0.32 s at
  the 0.7 s span. That exceeds the 1.5 cm rule. It is the known Phase J 4x finding: the span is Fable's call.
- Charge kept (`bed1_after_cancel` charges=1). The second pull popped (`bed1_after` released=1).

**Bulb off-screen** (bed 2, phase `offscreen1b`, a camera 25 cm off the pull axis aimed 110 cm out, alpha 0.922).
- `was_recently_rendered` true on all 92 ticks.
- `Q10_bed2_bulb_offscreen.png`: the green rods fill the frame and the bulb is not in it. **confirmed**.

**Morph curves.** The pulled bed-2 root was picked up (Held), then sampled:
- Inhale 0.92 at its Inhale.
- Scream 1.0 at Scream for the held root (and for the loose bed-1 root).

The curves arrive through the ABP: the Sequence Evaluator passes the clip curves. `Q11_scream_fp.png`: the held root with
the mouth open and the teeth showing. **confirmed** (the instance's `get_curve_value` and the capture).

**Ensures, dirty, Sandbox**  **confirmed**.
- Mars.log 14693-30989 (the builds, the reimport, the map save, run-12, run-12b, run-12c): 0 `Ensure condition failed`,
  0 `Full Reload is required`.
- 0 dirty packages after.
- The Sandbox mtime is 2026-11-07 21:08, unchanged.

### Captures, my read
- `run-12-walk/sheet_fp_both.png` (left bed 1 / right bed 2: grip, mid, full).
  - Grip: the gloves on the stalks under the prompt.
  - Mid / full: the stalks and leaves run down-screen toward the camera, the gloves at the frame bottom, the pink cone
    behind the prompt.
  - Bed 2 reaches farther down-screen than bed 1 at the same alpha.
- `run-12c-walk/side_by_side_74_vs_146.png` (bed 1 from run-12b, bed 2 from run-12c; side, target 0.92).
  - Bed 1: a 74 cm rod from the low pink cone to the leaves at the chef's hand.
  - Bed 2: a rod about twice as long, the chef farther out.
  - The leaves trail at the far end in both.
  - run-12's `Q9_bed2_full_side` is **void**: the camera stood outside the room. Bed 2's side shot was retaken in
    run-12c.
- `run-12-walk/sheet_side_cancel_scream.png`: Q6 the cancel (the gloves already leaving, leaves near the idle); Q10 the
  bulb off-screen; Q11 the scream.

### Finding (Script side, not reproduced): an interaction that started without a press
- run-12b (`R/captures/pie/run-12b-walk/walk_rows.json`): after a let-go on bed 1, the player walked to bed 2.
- Bed 2 entered SRC_Grip at game 9.98 with no key held (`keys: []`), 0.30 s before the driver's press (10.28). The gloves
  reached the stalks, but the Control's manipulation never began: ring 0.0 and no Tug while the player walked 135 cm away.
- run-12c, the same sequence, started on the press (10.33 after 10.30) and stretched normally.
- One sample. The cause is not investigated (Script scope).

### Rerun
```text
python Tools/LevelDesign/screaming_turnip_r01_review/screaming_turnip_animbp_ue.py [--readback-only]
run_python execute_file: .../phaseJ/reimport_phaseJ_ue.py clips SRC_Tug,SRC_Cancel,SRC_Release
(bed travel: the python above; the review map saved)
start_pie {on_compile_errors: suppress}; run_python: t.begin("run-12-walk"); w.state["full_speed"] = 400.0; w.sample_start(); w.run_12()
  ... w.finish(); stop_pie                     (run-12b: w.run_12b(); run-12c: w.run_12b(beds=(1,), label="run-12c-walk"))
python phaseK/analyse_run12.py captures/pie/run-12-walk/walk_rows.json captures/pie/run-12-walk/run12_analysis.json
```
run-12c's `beds=(1,)` did not take effect: both beds ran (the reload). Bed 2's shot is from that run either way.

### Not verified
- Grip node to socket (private handles).
- Why the pose and gloves still lag one tick (the cause is inferred from tick order).
- The run-12b press-less grip.
- The claim I'd most expect to be wrong: that the ABP adds no lag. That rests on crown == CrownOffset in the same sample,
  and both are read after the frame.

## Phase K - Fable audit (2026-11-09): the stretch is an Unreal tuner; Parts 1-3 ACCEPTED, Part 2c open, uncommitted

Audited against the artifacts: Part 1's inject_summary.json (17 travels; safe range 20..230 cm) and sheets, Part 2's
diff (PullSpec + Validate, the presentation as the single clock writing UMars_ScreamingTurnip_AnimInstance, lanes
ScreamingTurnip 14 / Control 74 / Forage 10), Part 3's animbp_report_readback.json, reimport_phaseK_clips.json,
run12_analysis.json / run12_summary.txt / run12_lag.txt, side_by_side_74_vs_146.png, sheet_fp_both.png.

- Proven: two beds pull 74 and 146.2 cm from the SAME three clips; crown x = -alpha * TravelCm within 0.03 cm on every
  tick; the pops at 74.00 / 144.57 cm walked; morph curves drive the scream through the evaluator; bulb-off-screen draws;
  cancel switch 0.25 cm; 0 ensures (Mars.log 14693-30989).
- Fable's edits this phase: k_AnimBlueprintName -> ScreamingTurnip_R01_Mars_ABP_v2 (the unsuffixed first build saved with
  a compile error: its Sequence pin was bound without being exposed; the builder now exposes it and waits for the verdict).
  MAINTAINER: delete /Game/ArtCandidates/ScreamingTurnip/R01/Animation/ScreamingTurnip_R01_Mars_ABP with the editor closed.
- Rulings: "crown at -TravelCm at full strain" is restated as "-EngageAlpha * TravelCm at the pop" (0.97 by design);
  the cancel-speed rule stays relaxed and the span is now a tuner (Pull.Timing.CancelSecondsFromFullStrain); the review
  room's per-bed travel is set through the placed spawner's details (editor Python export/import text), since the spawner's
  script instance is editor-only data AngelScript cannot set at runtime and a CkFoundation change is out of bounds.
- Open (Part 2c, Script executor): the drawn pose trails the Control by one tick and the gloves one more (a frame-order
  fix, not a deferral); a press-less grip on bed 2 in run-12b (driver keys empty at 9.98, ring from 9.39) to be explained
  with file:line and fixed with a headless test if it is a defect.

## Phase K Part 2c - Script: the drawn pull is this frame's; the run-12b press-less grip audited (Opus, 2026-11-09) - DONE (pose link fixed; glove link one frame by framework order; 2 not reproduced on the Use path); awaiting Fable audit

### (1) Frame order, read from the code (confirmed by source; group order is CkProcessorGroups.h's RunAfter chain)

1. **FGroup_Gameplay_TimeDelta.**
   - The bed's follow tick runs here: `utils_timer::Create_Tick` fires from `FProcessor_Timer_Update` (CkTimer_Processor.h:110-122, Group TimeDelta).
   - The autotest step timer runs here too.
2. **FGroup_Gameplay_Script.**
   - `UMars_Processor_Control_Tick` sets this frame's alpha.
   - `UMars_Processor_FPHands_Tick` refreshes each reach target's `AnchorWorld` from the grip node's current transform (`utils_fphands::Update_ReachTarget`, Mars_FPHands_Processor_Tick.as:34).
3. **FGroup_Transform.**
   - Scene-node offset requests apply here (`FProcessor_SceneNode_HandleRequests`, CkSceneNode_Processor.h:18-27).
   - `FProcessor_SceneNode_FollowUnrealAnchor` (socket followers) runs earlier, in Transform_SyncFrom.
4. **FGroup_PostTransform.**
   - `FProcessor_UnrealComponent_Tick` (CkUnrealComponent_Processor.h:64-76) calls `TickComponent` (.cpp:343).
   - `USkinnedMeshComponent::TickComponent` runs the component's own tick (our `Tick`), then `TickPose` / `RefreshBoneTransforms` (SkinnedMeshComponent.cpp:1664-1700). The turnip pose is evaluated here.
5. **After the ECS tick.**
   - The FPHands ABP's `BlueprintUpdateAnimation` composes the gloves from the stored `AnchorWorld` (Mars_FPHands_AnimInstance.as:56-130).
   - Inferred, not confirmed: this runs after the ECS frame. Run-12's 0.000 cm glove-to-previous-socket fits it.

**Why it lagged** (the cause run-12 measured):
- The bed set the scrub and the stretch in TimeDelta from last frame's Control alpha, so the pose drew alpha N-1.
- The grip nodes take the sockets of the pose evaluated last frame (N-1).

**Fix (the pose link):** the presentation draws the pull itself in its own tick, which runs after the Control in the same frame.
- `Mars_ScreamingTurnipPresentationComponent.as`:
  - `Set_PullDrawing(FMars_ScreamingTurnip_PullDrawing(Control, TravelCm, LiftCm))`, set once by the bed, replaces `Set_Stretch` and `FMars_ScreamingTurnip_Stretch`.
  - `DoFollow_Pull` (in Tick, after the clock) scrubs SRC_Tug to `Control.TryGet_ManipulationAlpha()` while the drawing shows Grip or Tug and the alpha moved or the Grip played through. This is the bed's old rule, moved.
  - The stretch alpha follows the clip on screen: Tug's played alpha, Cancel's `1 - played`, else 0. Tug's played alpha is the scrub, and it now holds after the threshold ends the grip until the release, where the old code dropped to 0 for those frames.
- `Mars_ScreamingTurnipBed_EntityScript.as`:
  - `DoScrub_Tug`, `Get_StretchAlpha` and `DoSet_Stretch` are removed.
  - `OnPlantedSkeletalAdded` sets the drawing (bounds widened from the start). `OnForageReleased` clears it.
  - The follow tick keeps the turn and the grip nodes.

**The link that cannot be same-frame without touching the framework: sockets -> grip nodes -> gloves.**
- The pose is evaluated in FGroup_PostTransform, after FGroup_Transform (where a scene node's offset lands) and after FPHands_Tick reads `AnchorWorld` (Gameplay_Script).
- So the earliest a grip node, or the anchor FPHands stores, can hold this frame's sockets is the next frame's Transform pass.
- Moving the bed's grip-node write into PostTransform gains nothing: the request still lands next frame.
- The ways out:
  - an immediate scene-node set or a post-pose transform pass (CkFoundation);
  - or FPHands resolving a skeletal socket live at anim time. Today `Make_EntryGrip` stores the socket relative to the node at reach start, and `Find_EntitySocketComponent` searches static meshes only. That is a Mars FPHands change that moves the glove grip frame, so it needs a PIE look first: proposed, not done.
- Net effect: the gloves were two Control frames behind and are now one (they sit on the sockets of the pose drawn with last frame's alpha).

**Proof** (headless; lanes run with the v2 ABP loaded): new `Mars_AutoTest_ScreamingTurnipBed_TheDrawnStretchIsThisFramesPull`.
- The step timer samples in TimeDelta, so it reads the Control alpha and the instance from the same end-of-frame state.
- It samples 30 frames of the spring following a 0.8 step: max |CrownOffset.X + alpha*T| <= 0.01 cm, Tug ClipTime = alpha*length within 0.0005 s, and the alpha moved > 0.01 per frame.
- **Before the fix, the same test failed:** worst 11.80 cm over 30 samples, 2 of 4 assertions (`Saved/Logs/TurnipJ/K2c-A-prefix.out:23629`).
- **After the fix it passed** (`K2c-ScreamingTurnip.out`). confirmed.

### (2) The run-12b press-less grip

- **Not reproduced on the Use path.** New `Mars_AutoTest_Control_ACancelledPullStartsNothingOnTheNextFocus`, through the player's real ManipulateControl, UseIntentToResolver and Hands tasks:
  1. Grip lever A, then release Use: the pull finishes Failed.
  2. The gloves are back at rest; A is withdrawn and lever B offered, with Use up.
  3. For 1 s: no interaction on B, B not gripped, the gloves never reach B.
  4. A fresh press starts B.

  It passes. The Use task opens only on a press edge (`Open_Intent` from `OnIntentPressed`, Hfsm_Tasks.as ~964), and its release / finish / removal paths all close it.
- **Inferred: the signature fits an interaction started by the Primary intent, not by Use.**
  - Primary shares LMB and resolves the Use channel (Mars_PlayerCharacter_Assets.as:207-214). It starts a target itself whenever its press is not deferred to Use (`Forward_To` Hfsm_Tasks.as:1058-1070, `Get_DefersStart` :1073).
  - `UMars_SmTask_ManipulateControl` watches only the Use intent's best targets (:499). An interaction Primary starts never reaches its `OnNewInteraction` (:528), so no manipulation begins and the ring stays 0. That matches run-12b.
  - Then the driver's real press at 10.28 opens Use, whose `Forward_To` joins the already-live interaction (:1066). ManipulateControl starts watching only after the interaction's start has fired, so it never begins either. That matches "ring 0 while the player walked 135 cm away".
- **What opened the Primary intent (or produced a press edge) with no driver key is NOT established.**
  - Primary closes on release, on its forwarded interaction's finish (`Spend_Hold`), and two frames after an early release (`_CloseWhenStarted`), so a stale open needs an edge I cannot see from the code.
  - Leads in Mars.log:
    - 07:31:42.802: `FProcessor_IntentSampler_Sample` dropped 2 intervals after the R1 screenshot hitch, just before bed 1's release.
    - 07:32:00.038: `LevelEditor.ToggleImmersive`, within about 2 s of game 9.98 at the 0.25 slomo, from the R2 shot's wall/game mapping. A viewport change can deliver a mouse-capture down into PIE.
  - Both are inferred and point at the PIE driver session rather than Script. Next proof: log the Primary / Use phase edges (`OnIntentPhaseChanged`) in a PIE rerun of run-12b.
- **Separate robustness defect (inferred, not fixed):** ManipulateControl ignores a ManuallyCompleted interaction already live from its player when it starts watching a target. The fix would be: on adopting `_Target`, treat `TryGet_Interaction(_Target, _Player)` as a new interaction. It is a behaviour change on every pulled control: Fable's call.

### Lanes (`--test --no-live --discover-fresh`, one at a time)

| Pattern | Passed | Failed | Exit | Known reds |
| --- | --- | --- | --- | --- |
| ScreamingTurnip | 15 | 0 | 0 | none ran, no new failures |
| Control | 75 | 0 | 0 | none ran, no new failures |
| Player | 34 | 0 | 0 | none ran, no new failures |
| Interactable | 14 | 0 | 0 | none ran, no new failures |

Evidence: `Saved/Logs/TurnipJ/K2c-{ScreamingTurnip,Control,Player,Interactable}.out` (`Passed:` at 24515 / 27166 / 27295 /
24468); editor logs `Saved/Logs/Test-TurnipK2c-<P>.log`.

- Process note: I wrote the Control test file while the pre-fix A run was running. That run tested only TheDrawnStretch and was not flagged CONTAMINATED. The four lanes above started after every edit.

### Side finding

- During run-12b, Mars.log logs `Currently in Animation Blueprint mode. Please change AnimationMode to Use Animation Asset` twice per frame.
- The presentation no longer calls any single-node API. Inferred: it comes from the PIE driver reading `get_position` / `get_play_rate` on the two beds' components. The driver should read the instance's ClipTime instead.

### Unverified headless (PIE)
- The pose matching the Control on screen.
- The gloves' remaining one-frame trail (expected: glove to the previous tick's socket 0.000, same-tick difference about halved).
- The Tug holding after the threshold until the release.

## Phase K Part 2d - Script: ManipulateControl adopts an interaction already live on a target it starts watching (Opus, 2026-11-09) - DONE, awaiting Fable audit

Ruling (Fable): the defect found in Part 2c is real for every pulled control. Fixed.

- `Script/PlayerCharacter/HFSM/Mars_PlayerCharacter_Hfsm_Tasks.as`, `UMars_SmTask_ManipulateControl::OnBestTargetsChanged`:
  - After binding the new ManuallyCompleted Control target, a live `utils_interact_target::TryGet_Interaction(_Target, _Player)`
    goes through `OnNewInteraction(_Target, Live)` as if it had just fired: pending interaction, grip wait or reach ask,
    and a Look control's view hold.
  - Nothing else changes.
  - The header comment documents the case: Primary and Use share LMB, Primary resolves the Use channel and can start a
    Use-channel control itself, and a later Use press only joins it (`Forward_To`).
- New `Script/Tests/Control/Mars_AutoTest_Control_AnAlreadyLiveInteractionIsAdoptedOnWatch.as`, through the player rig:
  1. Start the lever's interaction directly.
  2. Assert one interaction and no manipulation.
  3. Offer the lever and press Use.
  4. The gloves grip and the manipulation begins, carrying that same interaction. The Use press started no second one.
  5. A pull past the threshold ends it Succeeded.
- Without the fix the manipulation could not begin (the interaction's start fired before the watch). This is inferred; I
  did not run an A/B.
- The press-less-grip root cause stays open for PIE (the Use / Primary phase edges).

### Lanes (`--test --no-live --discover-fresh`, one at a time)

| Pattern | Passed | Failed | Exit | Known reds |
| --- | --- | --- | --- | --- |
| Control | 76 | 0 | 0 | none ran, no new failures |
| Player | 34 | 0 | 0 | none ran, no new failures |

Evidence: `Saved/Logs/TurnipJ/K2d-Control.out` (`Passed:` 27535; the new test Success), `K2d-Player.out` (`Passed:` 27299);
editor logs `Saved/Logs/Test-TurnipK2d-<P>.log`.

## Phase K Part 3b - run-13: the same-frame drawing, the held strain, the press-less grip hunt, a cold boot (Opus, 2026-11-09) - DONE, awaiting Fable audit

Same hard rules. `R` = `Tools/LevelDesign/screaming_turnip_r01_review/`. No Unreal asset writes this part.

### A fresh editor (the cold-boot proof)
- **The previous live editor was found closed** between Part 3 and Part 3b: no MarsEditor process, Monolith refusing
  connections, and no crash dump newer than 2026-11-08 23:40. The cause is unknown; its log had already been rotated away
  by the headless lane editors (Saved/Logs/Mars.log was a Test-TurnipK2d lane's).
- With the coordinator's agreement I launched a fresh editor with `CkAuto/UnrealToolbox.exe --launch-editor`
  (`Saved/Logs/TurnipK3b/launch-editor.out`) and loaded the review map. It is left running.
- **So run-13 is also the cold-boot proof** of the Phase K scripts and the `_v2` ABP.
  - Boot compile (Mars.log): `script compilation total` 2467, swap-in 2469. No AngelScript error, 0
    `Full Reload is required`.
  - `list_errored_blueprints` was empty at boot: the stale unsuffixed ABP was not loaded.
  - Bed 1's travel survived the reboot: export_text 74 / 9 (bed 2 146.2 / 18).
  - On the cold boot the PullSpec struct's fields are visible to Python (`stretch`, `spring`, `timing`). After the hot
    reload in Part 3 they were not.
- **Driver fix:** `screaming_turnip_pie_ue.clip_state()` reads the instance's `Sequence` / `ClipTime`. The single-node
  `GetPosition` / `GetAnimationAsset` are no longer called; the walk sampler uses the same. Mars.log has **0** "Currently in
  Animation Blueprint mode" lines over the whole session.
- **Intent rows:** new `_intents()` in `R/screaming_turnip_walk_ue.py`.
  - Path: the local player's `Ck_InputSource_Subsystem` -> `get_input_source()` ->
    `Ck_Utils_InputLayer_UE.try_get_layer_with_priority(source, 10)` (the gameplay profile's layer) ->
    `Ck_Utils_IntentMatcher_UE.do_cast_checked` -> `get_intent_phase` / `try_get_activation_frame`.
  - Tags `Mars.Intent.Interact.Use` / `.Primary`. The matcher reports 21 active intents.

### run-13 (`R/captures/pie/run-13-walk/`; `run13_analysis.json`, `R/phaseK/run13_summary.txt`, `R/phaseK/run13_strain_held.txt`)
- Slomo 0.25 (game ticks about 0.0085 s), the 110 cm stand, both beds.
- `run_13`: A (bed 1 slow, shots, let go); B x3 (run-12b's sequence); C (bed 2 slow to the break, shots); D (bed 1 at full
  backward speed to the break).

**1. Lag.** **confirmed**.

| pull | ticks | drawn alpha vs the SAME tick's Control alpha | vs the previous tick's | glove vs previous-tick socket | glove vs same-tick socket (max / mean) | walk |
|---|---|---|---|---|---|---|
| bed 1 slow (A) | 270 | **<= 0.00014** | 0.036 | 0.000 | 2.73 / 0.25 cm | 31.5 cm/s |
| bed 2 slow (C) | 541 | **<= 0.00014** | 0.018 | 0.000* | 1.49 / 0.26 cm | 31.5 cm/s |
| bed 1 full speed (D) | 56 | **<= 0.00014** | 0.045 | 0.000 | 3.48 / 1.35 cm | 418 cm/s |

\* One 2.71 cm row compares across a 1.63 s gap: the side-view rows between are excluded. It is not a tick pair.

- The drawn pose is now this frame's Control alpha (run-12: one tick behind). The gloves still sit exactly on the previous
  tick's sockets.
- **The remaining trail: about 0.25 cm (mean) at 30 cm/s and about 1.35 cm (mean, max 3.5) at full speed.** It is the one
  frame of socket travel, about half of run-12's.

**2. The strain held** (`run13_strain_held.txt`).
- On both beds the release is the tick right after the last visible tick:
  - bed 1, full speed: ring 0.9964, drawn alpha 0.9666, crown offset -71.52 at 64.1432; hidden at 64.1512 with the offset
    still -71.52;
  - bed 2: ring 0.9981, offset -141.55.
- The offset goes to 0 only on the next tick, after the mesh is hidden. The crown never drops while visible. **confirmed**.
- There is no observable "threshold-to-release" window: the threshold and the release land in the same frame, so the
  Tug-hold (Part 2d) has no visible ticks to act on here (**inferred** from the ring -> hidden sequence).

**3. The press-less grip: not reproduced in 3 runs** (`run13_analysis.json` `pressless`). **confirmed**.
- Each repetition: bed 1 grip -> back to 0.5 -> Use up -> walk to bed 2 with LMB up -> wait 2.0 s -> press.
  - Between the let-go and the press, bed 2 never left SRC_Idle (`grip_before_press: []`).
  - The Use and Primary rows were Idle except on the let-go tick itself: both ACTIVE at 10.7625 / 25.6703-25.6846 /
    40.5888-40.5958, carrying the press's activation frame, then Idle.
- On the press both rows go ACTIVE together (LMB maps both), with new activation frames 5423 / 6316 / 7212. The Grip
  started 0.023 / 0.016 / 0.028 s after the press.
- Each repetition stretched (max alpha 0.505 / 0.504 / 0.505, ring 0.52) and cancelled with the charge kept
  (`B1..B3_bed2_after_cancel` charges=1).
- Whether a Primary-started pull stretches could not be tested: no pull started without a press.

**4. Breaks, cancels, charge.**
- Bed 2's three cancels at alpha ~0.50: start 0.508 / 0.510 / 0.507 vs 1 - a 0.495 / 0.496 / 0.495 (one tick of play).
  - **Switch step 1.81-2.05 cm, the same size as the next steps (1.64-2.10)**: no extra jump at the switch. It is the
    cancel's own speed.
  - Per 60 Hz: max 3.67-3.68 cm (the 0.7 s span over 146 cm; Fable's call).
- Bed 1's cancel at 0.92 (A): start 0.093 vs 0.080, switch step 1.03 cm.
- Both beds broke (`bed2_after` / `bed1_after` released=1).
- **Ensures:** Mars.log (the fresh editor's) 1-3670, including the run window 3318-3670: **0** `Ensure condition failed`,
  0 Full Reload. 0 dirty packages. The Sandbox mtime is 2026-11-07 21:08, unchanged.

### Captures (`R/captures/pie/run-13-walk/sheet_run13.png`)
- **S1 / S2, bed 1 mid / full (first person):** the gloves on the stalks, the stalks and leaves leaning down toward the
  camera, the cone at the bed. The white root at the left is the review map's display actor.
- **S3 / S4, bed 2 mid / full:** the same, longer. The stretch now stays inside the frame (the camera pitch at the stand).
- **S5, bed 2 side at full strain:** a 146 cm rod from the low pink cone, the leaves trailing at the chef's end, the chef a
  little beyond them.

### Rerun
```text
start_pie {on_compile_errors: suppress}; run_python: t.begin("run-13-walk"); w.state["full_speed"] = 400.0; w.sample_start();
  w.state["track_intents"] = True; w.run_13()   ... w.finish(); stop_pie
python phaseK/analyse_run13.py captures/pie/run-13-walk/walk_rows.json captures/pie/run-13-walk/run13_analysis.json
```

### Not verified
- run-12b's press-less grip: it did not recur in 3 runs, so its cause and whether Part 2d fixes a Primary-started pull are
  open.
- The Tug-hold window (none observed).
- The grip-node lag is framework order, as the coordinator states (not measured: private handles).
- The claim I'd most expect to be wrong: that the 2 cm cancel steps hide no switch discontinuity. At 8 ms ticks a 0.3 cm
  mismatch would sit inside a 2 cm step.

## Phase K - Fable audit addendum (2026-11-09): Parts 2c / 2d / 3b ACCEPTED; Phase K complete, uncommitted

- Same-frame pose: the presentation reads the Control in its own tick (PostTransform, after the Control tick); headless
  test TheDrawnStretchIsThisFramesPull (failed 11.80 cm before, passes after); PIE run-13: drawn alpha = same-tick Control
  alpha within 0.00014 on 867 ticks. The gloves keep a one-frame trail behind the sockets (0.25 cm at 30 cm/s, 1.35 mean /
  3.5 max at full speed): framework order (scene-node offsets apply in FGroup_Transform, the pose evaluates in
  FGroup_PostTransform, FPHands composes after). Proper routes, both outside this phase: FPHands resolving skeletal sockets
  live at anim time (Make_EntryGrip stores the socket relative to the node at reach start; Find_EntitySocketComponent only
  searches static meshes), or a CkFoundation post-pose transform pass. Not papered over.
- ManipulateControl adopts an interaction already live on the target it starts watching (Part 2d, test
  AnAlreadyLiveInteractionIsAdoptedOnWatch; Control 76/0, Player 34/0): a real defect for every pulled control.
- Press-less grip (run-12b): 0 of 3 reproductions in run-13 with the Use/Primary intent rows logged; closed as not
  reproducible, leading hypothesis an editor-window mouse-down during the driver's ToggleImmersive (Mars.log 07:32:00).
- Cold boot: the previous live editor was found closed before Part 3b (no crash dump; cause unknown). The fresh editor
  compiled the whole Phase K script set clean (Mars.log 2467-2469) and bed 1's 74/9 travel survived the reload.
- Rulings: cancel speed stays relaxed (now a tuner, Pull.Timing.CancelSecondsFromFullStrain: ~1.9 s would meet 1.5 cm per
  frame at 146 cm); "strain held" has no visible window (threshold and release share a frame).
- Final lanes this phase: ScreamingTurnip 15, Control 76, Player 34, Interactable 14, Forage 10, all exit 0, no new reds.
- MAINTAINER: delete Content/ArtCandidates/ScreamingTurnip/R01/Animation/ScreamingTurnip_R01_Mars_ABP(.uasset/.ckexport)
  with the editor closed (the errored first build; the game uses _v2). Open calls: the glove one-frame trail (above), the
  square-rod stem look at long stretches (6-8 sided tapered stems = mesh change + SK reimport), the HUD prompt covering
  the turnip from standing height.

## Phase L Part 1 - Script: the gloves read their grip live (anchors at composition, skeletal sockets as grips) (Opus, 2026-11-09) - DONE, awaiting Fable audit

Brief: `PHASE_L_BRIEF.md` D-L1..D-L4. Script/ only.

### Changes

`Script/ECS/FPHands/Mars_FPHands_Grips.as`:
- **`FMars_FPHands_HandGrip`** gains:
  - `UPROPERTY() FCk_Handle_UnrealComponent SocketHost`: invalid means the anchor itself is the base.
  - `UPROPERTY() FName Socket`.

  `Grip` is in the BASE space: the socket's for a socket grip, where identity means the socket's own axes; else the
  anchor's. `AnchorWorld` is the last known base world, used as the fallback.
- **`FMars_FPHands_GripEntry`** gains `UPROPERTY() TOptional<FQuat> SocketRotation`. It is the handed grip rotation in the
  socket's frame; unset means the socket's axes. The positional ctor takes it as a trailing defaulted 8th parameter, so
  the existing 7-argument calls (Station, WorldItem, tests) are unchanged.
- **`FMars_FPHands_MeshGrips`** gains `FCk_Handle_UnrealComponent SocketHost`, `FName RightSocket`, `FName LeftSocket`.
- **New** `FMars_FPHands_SocketComponent { UMeshComponent Component; FCk_Handle_UnrealComponent Host; }`: the
  transient result of the socket lookup.
- **`Find_EntitySocketComponent(Root, Socket)`** now returns `FMars_FPHands_SocketComponent`. It searches every
  `UMeshComponent` (static or skeletal) in the transform tree through `utils_unreal_component::Get_HandlesByType` +
  `Get_Component`.
- **New** `TryGet_SocketWorld(HandGrip)` and `Get_GripBaseWorld(HandGrip)`. The base is resolved in this order:
  1. the live socket;
  2. else the cached `AnchorWorld` for a socket grip whose component or socket is gone;
  3. else the live anchor;
  4. else `AnchorWorld`.
- **D-L1:** `Resolve_WorldGrip` composes `Grip * Get_GripBaseWorld(...)`, Sides centre included. `Refresh_Anchor` stores
  `Get_GripBaseWorld` and still keeps the cache for a dead anchor. `Roll_HandGrip` (FaceViewer) rolls against the live
  base.
- **D-L2, entries:** `Make_EntryGrip`'s socket path fills `SocketHost` / `Socket`, `Grip = SocketRotation` (or identity)
  and `AnchorWorld` = the socket's world. A missing socket still ensures and falls back to the node, as before.
- **D-L2, object sockets:** `Find_EntitySockets` iterates the static mesh handles and records the component handle and the
  socket names. The object-socket path in `Resolve_ReachTarget_AsAuthored` binds live through the new
  `Make_UsedSocketGrip(Shared, Socket, SocketWorld)` (identity grip, FaceViewer roll as before) whenever `SocketHost` is
  valid. A plain actor's sockets (`Find_ActorSockets`, no Ck handle) stay baked as before.
- `Anchor_HandGrip` (items re-anchored to their root) leaves a socket grip on its socket.

`Script/WorldObjects/Forage/Mars_ScreamingTurnipBed_EntityScript.as`:
- `AddHarvestGrips(InHandle)` writes two entries on `_PlantedNode`:
  - `Socket` = `k_HarvestGripSocket_R / _L`;
  - `SocketRotation` = `Make_GripRotation(Right, +X, -Y)` / `(Left, +X, +Y)`;
  - Pose Power, Roll Fixed.
- Removed: `_HarvestGrip_R/_L`, `_HarvestGripRotation_R/_L`, `DoMove_GripNode` and the node moves. The follow tick keeps
  the turn and its end condition. The header comment is updated.

`Script/Items/Mars_Item_ScreamingTurnip.as`: `k_HarvestGripLocation_R / _L` deleted (no reader left, including no test);
the socket comment is updated. The manifest is not touched: it is Blender's file.

### Tests (D-L4)

- **`Mars_AutoTest_FPHands_ANodeAnchorIsReadLiveAtResolve`:** a grip-table reach on a node, resolved once and held.
  - Move the node 30 cm with nothing refreshing the held target: the cached `AnchorWorld` is still the old place, while
    `Resolve_WorldGrip` puts the grip on the new node position within 0.01 cm.
  - Refresh, then destroy the node: the grip is the last known world, with no ensure.
  - The move is a deferred transform request, so "no tick between" is implemented as "no refresh of the held target in
    between". That is the property D-L1 changes.
- **`Mars_AutoTest_FPHands_ASkeletalSocketGripIsResolvedLive`:** a node carrying `UMars_ScreamingTurnipPresentationComponent`
  (the SK through ABP v2, loaded headless) and an entry on `HarvestGrip_R` with a SocketRotation.
  - Resolved: `SocketHost` is valid, `Socket` = HarvestGrip_R, and `Grip` = the SocketRotation.
  - Move the node: the grip = SocketRotation x the live socket (0.01 cm, rotation 1e-4).
  - Pose the mesh (SRC_Tug scrubbed to 1 with a 100 cm crown offset through `Set_PullDrawing` and no Control): the socket
    moves more than 50 cm off the node, and the grip follows the socket.
  - **This confirms the pose is evaluated headless** (`VisibilityBasedAnimTickOption` refreshes the bones under nullrhi).
  - It logs `HarvestGrip_R in the component at bind: location X=-1.522 Y=4.683 Z=38.035, rotation P=0 Y=0 R=0`.
    **The socket's bind frame is the component's (identity)**, so the bed's SocketRotation reproduces Phase K's world
    rotation (yaw x Make_GripRotation) at rest. During the pull the glove now also takes the crown's pitch: that is the
    PIE call in D-L3 / D-L5.
- `SocketGripFollowsMovingPart` (lever object sockets, now bound live) and `GripTableGivesEachHandItsOwnAnchor` pass
  unchanged.
- The ScreamingTurnip rig had no reader of `k_HarvestGripLocation_*`.

### Lanes (`--test --no-live --discover-fresh`, one at a time)

| Pattern | Passed | Failed | Exit | Known reds |
| --- | --- | --- | --- | --- |
| FPHands | 36 | 0 | 0 | none ran, no new failures |
| ScreamingTurnip | 15 | 0 | 0 | none ran, no new failures |
| Control | 76 | 0 | 0 | none ran, no new failures |
| WorldItem | 25 | 0 | 0 | none ran, no new failures |
| Station | 75 | 1 | 1 | none listed ran; 1 NEW failure, not ours |

- Evidence: `Saved/Logs/TurnipJ/L1-<P>.out`; editor logs `Saved/Logs/Test-TurnipL1-<P>.log`.
- **The Station red:** `CkTests.UnitTests.CkCrowd.StationaryMarkup.WindowedSpeedThreshold`.
  - It is a CkTests C++ CkCrowd unit test that matches the pattern only through "Stationary". It expects the warning
    `Invalid stationary-markup movement sample` 6 times and finds 1.
  - It is red again alone (`Saved/Logs/TurnipJ/L1-Windowed.out`, `Passed: 0` / `Failed: 1`).
  - Not caused by this change, by reasoning: it is a synchronous C++ unit test of CkCrowd that runs no Mars script. No A/B
    was run.
  - It is not on any knownReds list. The "two known Station reds" the coordinator named did not appear in the
    known-reds block. Following the gate's rules, the entry belongs in CkTests' own list via that home project, not here.
  - Every Mars Station test passed (75).

Rerun:
```bash
./CkAuto/UnrealToolbox.exe --test --no-live --discover-fresh --test-pattern FPHands --output=Saved/Logs/Test-TurnipL1-FPHands.log --project=D:/Repositories/CkRepos/Orion/Mars.uproject
# ScreamingTurnip, Control, WorldItem, Station likewise, one at a time
```

### The PIE driver (Part 2)

- No driver line samples the old grip nodes; they were private.
- `screaming_turnip_walk_ue.py` already samples the bed sockets (`sock_r/sock_l` = `get_socket_location("HarvestGrip_R/_L")`,
  :108-109) and the glove bones (`grip_r/grip_l` on the FPHands mesh, :189).
- So "glove to SAME-tick socket" is `|grip_r - sock_r|` and `|grip_l - sock_l|` in the same row. The analysis
  (`phaseK/analyse_run12.py`) should report those per row instead of against the previous row's sockets.
- Also recommended: drop the single-node reads that log `Currently in Animation Blueprint mode` twice a frame. Read the
  instance's ClipTime instead.

### Unverified headless (PIE, D-L5)

- The glove-to-same-tick socket distance on screen. Expected 0.00x; it rests on the inferred anim-time order.
- Whether Make_GripRotation's +X fingers / palm-to-crown read right on the pitched, turned stalks.
- Every other grip's look after D-L1: lever, pickups, platter / dock Place.
- That the Station's socket grips (now live) and the lever object sockets look as before.

## Phase L Part 2 - PIE: the gloves on the live sockets (run-14) and the regression look in the Sandbox (Opus, 2026-11-09) - DONE, awaiting Fable audit

Brief: `PHASE_L_BRIEF.md` D-L5 plus the coordinator's points. No git, no Script edits, no asset writes. The Sandbox was
loaded and NOT saved. `R` = `Tools/LevelDesign/screaming_turnip_r01_review/`. The editor is left running on the review map
with PIE stopped.

### Preflight  **confirmed**
- Mars.log of the editor launched in Part 3b: the Phase L hot compiles at 4806-6576, the last swap-in at 6576. No
  AngelScript error, 0 `Full Reload is required`.
- PIE off, 0 dirty packages.
- The driver reads no single-node state. **"Currently in Animation Blueprint mode": 0 lines in the whole session**
  (Mars.log 1-8306).

### run-14 (`R/captures/pie/run-14-walk/`; `run14_analysis.json`, `R/phaseL/run14_summary.txt`; driver `run_14`)
Slomo 0.25, the 110 cm stand. Bed 1 (74 / 9) pull 1 slow with a sidestep, pull 2 at full speed. Bed 2 (146.2 / 18) pull 1
to 0.5 then cancel, pull 2 slow to a hold, pull 3 at full speed.

| pull | glove to the SAME tick's socket (mean / max) | glove to the previous tick's socket (mean / max) | drawn vs the Control, same tick | walk |
|---|---|---|---|---|
| bed 1 slow | **0.000 / 0.000** (183 ticks) | 0.38 / 0.66 cm | <= 0.0001 | 31.5 cm/s |
| bed 1 sidestep | **0.000 / 0.000** (160) | 0.15 / 0.21 | <= 0.0001 | (around the bed) |
| bed 1 full speed | **0.000 / 0.000** (29) | 2.64 / 6.54 | <= 0.0001 | 419 cm/s |
| bed 2 slow | **0.000 / 0.000** (433) | 0.49 / 1.33 | <= 0.0001 except the let-go tick* | 31.5 cm/s |
| bed 2 full speed | **0.000 / 0.000** (39) | 3.81 / 6.98 | <= 0.0001 | 420 cm/s |

\* On the let-go tick (game 20.6285) the ring is already 0 while the drawing still shows the Tug at 0.507. It is not a lag.

- **The glove trail is gone: the glove bones sit on the same tick's sockets at 0.000 cm** at 30 cm/s and at full speed on
  both beds. Against the previous tick they now read one frame of socket travel, which is the old trail inverted.
  **confirmed**.
- **The yaw carries the grips.** Sidestep: planted yaw 44.29 -> 72.50 deg, the bearing to the player the same; yaw error
  <= 0.0007 deg, and the gloves at 0.000 cm on the turning sockets. **confirmed**.
- **The cancel** (bed 2 at alpha 0.507): start 0.519 (1 - a 0.493 plus a tick of play). The gloves are 1.43 cm off the
  socket on the first Cancel tick (they let go, as before). `bed2_after_cancel` charges=1. **confirmed**.
- **Breaks:** bed 1 at 13.43 (full speed), bed 2 at 34.42 (full speed); `bed1_after` / `bed2_after` released=1.
  **confirmed**.

**The glove frame on the stalks** (`sheet_run14.png`, `zoom_gloves.png`: grip and full strain, both beds; my read).
- **At the grip:** both gloves close round the stalks from either side, fists closed, knuckles up toward the leaves, the
  stalks between the palms. They read right.
- **At full strain:** the gloves sit in the leaf cluster at the stalks' far end, mostly hidden behind the leaves. Their
  backs face the camera and the stalk bundle runs between them. That is consistent with palms toward the stalk and crown
  as the crown pitches.
- Nothing looks twisted or inside-out at this resolution, but **the finger wrap at full strain cannot be judged**: the
  leaves cover the fingers. **inferred**. No SocketRotation change is proposed.

### The regression look in the Sandbox (D-L1 freshens every grip)
- Loaded with `LevelEditorSubsystem.load_level` (read-only). 0 dirty packages after the load and after both PIE sessions.
- Never saved: the `Sandbox_Mars_MAP.umap` mtime is still 2026-11-07 21:08.
- The review map was reloaded afterwards.
- Driver: `R/screaming_turnip_regression_ue.py` teleports the pawn to a stand 120 cm off each target, aims, and presses Use
  through Mars_ExpeditionAcceptance.
  - Runs: `run-14-sandbox` (the lever) and `run-14-sandbox-pickups`.
  - `run-14-sandbox-void-a` died at its first shot: a duplicate keyword in the mark call.
  - In the first run's pickups the aim passed over the floor items (no prompt, nothing held). The pickups run re-aimed
    low.

| grip | capture | result (my read) |
|---|---|---|
| Pulled lever (Mech_LeverA, a Mars_Sandbox_PulledLever) | `run-14-sandbox/G0_lever_focus`, `G1_lever_grip`, `G2_lever_pulled` | G1: one glove closes on the top of the handle. G2: after 20 look deltas down the handle has gone forward out of view with the glove on it. Plausible. Glove-to-handle-socket not sampled (no Python path to the lever's grip). |
| Two-handed pickup (Item_Cookbook) | `run-14-sandbox-pickups/G3b_cookbook_*` | The prompt "Pick up Cookbook"; the reach and held: both gloves hold the book's sides in front of the camera; `held=Mars_ItemDef_Cookbook` (inspect). Looks right. |
| One-handed pickup riding home (Item_Key_Red) | `G5b_key_*` | The prompt "Pick up Red key"; the right glove holds the key in its fist at the hand's rest; `held=Mars_ItemDef_Key_Red`. Looks right. |
| Platter / dock Place | - | Not done: the dock was not located in the time. The platters exist (Sandbox_Platter_Large / Small). |

- **"Looks as before": not claimable.** There are no pre-Phase-L captures of these grips in this campaign to diff. What
  can be said is that each looks correct, with no glove off its grip, twisted or inside-out. **inferred**.
- The right glove reads darker brown than the left in these shots. In the review map both read tan, so it is likely the
  shadow side of the Sandbox light, not a material change (**inferred**).

### Ensures, dirty, Sandbox  **confirmed**
- Mars.log 1-8306 (Phase L hot compiles, run-14 from 6764, both Sandbox sessions): **0** `Ensure condition failed`, 0 Full
  Reload, 0 "Currently in Animation Blueprint mode".
- 0 dirty packages at the end (the review map loaded).
- The Sandbox file is unchanged.

### Rerun
```text
review map, PIE: t.begin("run-14-walk"); w.state["full_speed"] = 400.0; w.sample_start(); w.state["track_intents"] = True; w.run_14() ... w.finish()
python phaseL/analyse_run14.py captures/pie/run-14-walk/walk_rows.json captures/pie/run-14-walk/run14_analysis.json
sandbox (load_level, never save), PIE: import screaming_turnip_regression_ue as g; t.begin("run-14-sandbox"); g.run()   (or g.run_pickups())
```

### Not verified
- The finger wrap at full strain (hidden by the leaves).
- Glove to the lever's grip socket.
- The platter / dock Place.
- "As before" (no baseline captures).
- The claim I'd most expect to be wrong: that the gloves at full strain have the right handed frame. Only their backs are
  visible.

## Phase L - Fable audit (2026-11-09): live grip anchors + skeletal-socket grips ACCEPTED; uncommitted

- FPHands: Resolve_WorldGrip composes on a live base (socket -> cached world if the host is gone -> live anchor -> cached
  world; Get_GripBaseWorld / TryGet_SocketWorld), grips may be sockets on any UMeshComponent (HandGrip.SocketHost + Socket,
  Grip in socket space; GripEntry.SocketRotation), object sockets bind live (Make_UsedSocketGrip); the bed grips
  HarvestGrip_R/_L on the planted node and moves no scene nodes (k_HarvestGripLocation_* deleted). Tests
  ANodeAnchorIsReadLiveAtResolve and ASkeletalSocketGripIsResolvedLive (the turnip SK posed through its ABP headless).
  Lanes FPHands 36 / ScreamingTurnip 15 / Control 76 / WorldItem 25 green; Station 75/1, the red being
  CkTests.UnitTests.CkCrowd.StationaryMarkup.WindowedSpeedThreshold, a C++ unit test red alone and recorded red on
  2026-11-06 before any of this work (not ours; belongs in CkTests' own list via its home project).
- PIE run-14: glove-to-SAME-tick socket 0.000 / 0.000 cm on every pull (slow, sidestep, full speed, both beds; 844 ticks);
  drawn alpha same-tick within 0.0001; the yaw turn carries the grips (bearing error 0.0007 deg); cancel from the strain,
  charge kept; 0 ensures (Mars.log 1-8306). Gloves judged on zoom_gloves.png: fists round the stalks from both sides at
  the grip, backs to the camera inside the leaf cluster at full strain; no twist. SocketRotation unchanged.
- Sandbox regression look (loaded read-only, never saved, 0 dirty): pulled lever, two-handed Cookbook pickup, one-handed
  Red key ride-home all grip correctly (no pre-Phase-L captures exist to say "as before"; the paths changed only in reading
  the anchor a frame fresher). Platter/dock Place not exercised (the Place path itself is untouched by D-L2): owed to the
  maintainer's next platter session.
- Owed: finger wrap at full strain is hidden by the leaves (a side camera could show it); glove-to-lever-socket not sampled.
