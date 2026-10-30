# Vine and root generator: final implementation plan

Status: design only. Nothing in this plan has been built yet. Engine paths are relative to
`D:/Repo/UnrealEngine-Angelscript/Engine` and PCG paths to `Engine/Plugins/PCG/Source/PCG`. Repo paths are relative to
`D:/Repo/Mars`. A `(src: file:line)` citation means the line was read while writing this plan. A **[spike]** is a claim the
headers support but nothing in the repo exercises yet. Phase 0 proves each one and each has a fallback. **[EDITOR-VERIFY]**
means only a person looking at PIE can judge it.

This plan builds on the actor-first design (`as-actor`). It takes ideas from the PCG-native and mesh-generation designs and
applies every correction the two judges asked for. §0 lists what this synthesis changed and why.

---

## 0. What changed against the three designs (read first)

1. **The art pipeline already exists, so this plan reuses it.** None of the three designs noticed the environment dressing
   kit in `Tools/Blender/mars_environment/`:
   - `env_spec.py` already registers a `"vines"` family: `("Vines", "Dressing_Vines.blend", "build_env_vines.py")`.
   - `ENV_KIT.md` §"vines and water" points at this folder for the vine plan.
   - `unreal/mars_env_ue.py` already builds two masters, `EnvPaint_Mars_M` and `EnvFoliage_Mars_M`, both rebuilt in
     place.
   - `EnvPaint_Mars_M` already has per-instance and per-actor hue/value breakup, world-space grime, moss on up-facing
     faces and wetness. `EnvFoliage_Mars_M` is two-sided foliage with wind weighted by a UV1 "EnvData" flex channel.
     `_usage()` sets the ISM and spline-mesh usage flags on both.
   - Material assets already exist under `Content/Mars/Environment/Dressing/Materials/`, including `EnvBark_Mars_MI`,
     `EnvLeaf_Mars_MI`, `EnvLeafDry_Mars_MI` and `EnvMoss_Mars_MI`.
   - The style ruling in `env_spec.py` says "No new textures on props" and that breakup lives in the masters.

   So this plan drops the designs' new `Tools/Blender/mars_dressing/` folder, their numpy textures and their three new
   masters. The vine meshes become `build_env_vines.py` in the existing kit. The masters gain four neutral data slots in
   place (§5). The organic family's `DeadLeaves_Pile_*`, `DeadLeaves_Scatter_A`, `MossPad_*` and `MossDrape_A` become the
   skirt and litter meshes.
2. **The PCG volume is a plain `AActor`.** It has a `UBoxComponent` root and a `UPCGComponent` default component, not an
   AngelScript `APCGVolume` subclass. That was the judges' must-fix, and I verified it:
   - A non-volume actor's self data comes from its components. A `UBoxComponent` becomes `UPCGCollisionShapeData`, so
     culling against the volume works (src: `Private/Data/Registry/PCGGetDataFunctionRegistry.cpp:184-187, 269-275`;
     `Private/Data/PCGCollisionShapeData.cpp:32-44`).
   - Bounds are the union of the primitive bounds, including non-colliding ones (src: `Private/Helpers/PCGHelpers.cpp:155-180`).
3. **Grid extents come from the volume, never a constant.** `CreatePointsGrid` computes its point counts from
   `GridExtents / CellSize` before any culling (src: `Private/Elements/PCGCreatePointsGrid.cpp:103-107`). It also resets
   the referential's scale (`:86-87`).
   - The volume's construction script writes `PcgGridExtents = Bounds.GetScaledBoxExtent()` (src:
     `Source/Runtime/Engine/Classes/Components/BoxComponent.h:41-43`, a UFUNCTION). It also writes a `PcgCellSize` that it
     coarsens until the point count is ≤ 60 000.
   - Both values reach the grid node through single-attribute Get Actor Property nodes wired into the node's own
     override pins. A param with a single attribute on a non-global pin is used whatever its name (src:
     `Private/Metadata/Accessors/PCGAttributeAccessorHelpers.cpp:403-404`).
4. **Every designer knob reaches a graph through that same mechanism.** That means a single-attribute Get Actor Property
   into a node's override pin. The designs leaned on things nobody verified: attribute-set broadcasts, graph user
   parameters (not scriptable: `AddUserParameters` is not a UFUNCTION, src: `Public/PCGGraph.h:630`) or nested struct
   extraction.
5. **The facts the judges disputed are settled in source:**
   - **`bNeverNeedsCookedCollisionData`: dropped.** The setter is not a UFUNCTION (src:
     `Source/Runtime/Engine/Classes/Components/SplineMeshComponent.h:185, 404-405`). AngelScript `default` statements
     cannot reach `Create()`d segments, so it cannot be set on them.
   - **`default` writes are valid.** `default` on an EditAnywhere property that is BlueprintReadOnly is allowed, because
     `CPF_Edit` grants edit access (src: `Plugins/Angelscript/Source/AngelscriptCode/Private/Binds/Helper_PropertyBind.h:82-88`).
     This covers `PCG.GenerationTrigger` (src: `Public/PCGComponent.h:348-349`) and `ShadowCacheInvalidationBehavior`
     (src: `Source/Runtime/Engine/Classes/Components/PrimitiveComponent.h:315-317`).
     - The enum is a plain `UENUM()` (src: `Source/Runtime/Engine/Public/SceneTypes.h:216-218`). AngelScript binds every
       UENUM not marked NotBlueprintType (src: `Plugins/Angelscript/.../Binds/Bind_UEnum.cpp:321-338`).
   - **`SetCustomDataValue` must dirty the render state.** It defaults `bMarkRenderStateDirty = false` (src:
     `Source/Runtime/Engine/Classes/Components/InstancedStaticMeshComponent.h:312-313`). The emitter passes `true` on the
     last write of each batch.
   - **Validation is a mixin:** `mixin FMars_Validation Validate(const UMars_VineProfile Self)`, the
     `Script/Fx/Mars_SurfaceFx.as:258` pattern.
   - **Editor-only PCG fields:** nothing the scripts write on the PCG component from a construction script is
     editor-only data. `bRegenerateInEditor` is `WITH_EDITORONLY_DATA` (src: `Public/PCGComponent.h:374-376`). This plan
     never touches it. If a later change needs it, the write goes under `#if EDITOR`.
   - **Custom PCG element, if ever used:** set it with `SetBlueprintElementType` (src:
     `Public/Elements/PCGExecuteBlueprint.h:90-91`), not the deprecated `SetElementType` (`:86-88`).
6. **GeometryScripting is already loaded in every editor session**, contrary to the brief. Monolith declares it as an
   optional dependency (src: `Plugins/Monolith/Monolith.uplugin:51-53`; `Saved/Logs/Mars.log:181` "Mounting Engine plugin
   GeometryScripting"). Version 1 does not need it. The optional editor-only bake in Phase 6 does, and declaring it in
   `Mars.uproject` is a decision for Stephen (§11).
7. **Draw-call and per-actor overhead fixes:**
   - `AMars_Vine` creates only the HISMs it actually uses, instead of ten default HISMs.
   - Fringe kinds (ceiling moss and rootlets, pier-base moss, leaf litter) are volume-level PCG ISMs, never one actor per
     site.
   - The number of PCG-spawned actors per volume is capped.
8. **The hero roots get a Blender path** (`AMars_HeroRoot`, from the mesh-generation design). The procedural spline-mesh
   `GiantRoot` profile stays for mid-size and secondary roots.

---

## 1. Summary

**The approach.** There is one placeable AngelScript dressing actor, `AMars_Vine`, and it follows the
`Mars_HangingChain` pattern. In its construction script it:

1. Traces the level with `System::LineTraceSingle` on the Visibility channel.
2. Solves a set of polylines (stems, branches, tendrils, flare fingers) with a deterministic surface-walk solver.
3. Caches the solve in a serialized property keyed by a hash of its inputs.
4. Emits geometry:
   - `USplineMeshComponent` chains for thick roots.
   - HISM instances for thin stems, leaves, moss strands, rootlets, cobwebs, knots and litter.

**What PCG does.** PCG handles mass placement through `AMars_VineVolume`, a box actor with a PCG component, in two ways:

- **Fitted vines:** it spawns `AMars_VinePcg` actors (an `AMars_Vine` subclass), seeded per point, at ledges and
  ceilings. Each spawned vine reads its settings from the volume it is attached to.
- **Fringe:** it scatters the stemless fringe directly as merged ISMs. Their traced length is packed into per-instance
  custom data.

**What else is built:**

- `AMars_HeroRoot` stacks Blender-sculpted twin-rope root modules down to the traced floor for the atrium.
- Meshes come from `build_env_vines.py` in the existing environment kit. Materials are the kit's own two masters, each
  gaining four neutral data slots.

| Request (quoted) | Feature that answers it |
|---|---|
| "Vine/Roots generator that can be built out around the environment" | `AMars_Vine` with 6 layouts (Spline, Creep, Drop, Curtain, Wrap, Patch) and 6 profiles (Ivy, GiantRoot, ThinRoot, HangingMoss, Rootlets, Cobweb). Everything is traced against whatever collision is in the room (§3). |
| "( through PCG," | `AMars_VineVolume` with 4 graphs (§6). `VineCurtain_Mars_PCG` and `VineCeilingRoots_Mars_PCG` spawn fitted vines. `VineUnderside_Mars_PCG` and `VineSkirt_Mars_PCG` are PCG-only instancing. |
| "splines that attach to the enviroment" | `Layout = Spline`: guide samples cling to the nearest surface within `ClingRadius`, distance-weighted, and stay free beyond it. The `Creep` surface walk handles concave and convex corners and lips, and `Wrap` coils round piers and pipes (§3.3-3.4). |
| "toggle wrapping to ground vs staying in air" | `EMars_VineEnd { Ground, Air }` on every layout. **Ground**: trace to the floor, fillet, creep along it, flare into fingers. **Air**: end inside a seeded clearance band above the traced floor and curl the tip. `GroundShare` mixes the two per strand (§3.5). |
| "The strands might have to trace to the ground to match the length ( could be driven through PCG and custom data as well )" | Every hanging strand traces its own floor distance in the actor. In `VineCeilingRoots_Mars_PCG` a second downward ray writes `ImpactDistance × LengthFrac` as a Spawn Actor override. In `VineUnderside_Mars_PCG` the traced length becomes the strand's Z scale and per-instance custom data slot 3, which the strand material reads to scale sway (§3.9, §4, §6). |
| "can be placed in many environments" | Nothing depends on kit names: the solver and graphs see only collision. A kit-mesh-name filter exists as an opt-in fast path for kit rooms, never as a requirement (§6.3). The tests use engine cubes only (§9). |
| "have a bit of breakup" | Seeds fall back to a position hash, and every purpose has its own stream. Curtain lengths are correlated, with stragglers; strands clump; leaf density falls off toward the tip. PCG spatial noise thins sites. In the masters: per-instance and per-actor hue/value, world-space grime and moss, wetness, a per-leaf id jitter and a world-position wind phase (§3.2, §3.9, §5). |
| "If these assets can be made to be procedural in nature" | Paths re-solve from a seed and the room. Meshes come from a seeded headless Blender builder, and the materials and graphs from re-runnable editor-Python builders. |

**Why the actor solver and not a PCG-native solve.** Clinging needs a *sequential* surface walk: each step's trace
depends on the last hit. Stock PCG nodes are data-parallel, and the PCG-native design's six-ray nearest-hit cling jumps
faces at lips and corners (judge finding). One AngelScript solver serves both hand-placed and PCG-placed vines, is
testable headless on engine cubes, and keeps PCG to what it is good at: finding sites in a volume.

---

## 2. Architecture

### 2.1 AngelScript, under `Script/WorldObjects/Dressing/Vines/`

These are dressing actors, not ECS features: visual composition only, like `Mars_HangingChain.as`. Only `utils_vine`
namespaces exist. Functions take at most 3 parameters, and wider inputs are packed into query structs. No struct holds
more than 7 fields; larger groups nest.

| File | Contents |
|---|---|
| `Mars_Vine_Types.as` | **Enums:**<br>- `EMars_VineLayout { Spline, Creep, Drop, Curtain, Wrap, Patch }`<br>- `EMars_VineEnd { Ground, Air }`<br>- `EMars_VineCollision { FromProfile, Off, On }`<br>- `EMars_VinePathKind { Stem, Branch, Tendril, Finger }`<br>- `EMars_VineStemRender { None, Instanced, SplineMesh }`<br>- `EMars_VinePreset { Ivy, GiantRoot, ThinRoot, HangingMoss, Rootlets, Cobweb }`<br>**Structs:**<br>- `FMars_Vine_Shape` (7 layout knobs)<br>- `FMars_Vine_Request` (the effective inputs)<br>- `FMars_Vine_Path`, `FMars_Vine_Solved` (the cache)<br>- `FMars_Vine_SurfaceHit`<br>- the query structs `FMars_Vine_ProbeQuery`, `FMars_Vine_CreepQuery`, `FMars_Vine_HangQuery`<br>- `FMars_Vine_Report` |
| `Mars_VineProfile.as` | `class UMars_VineProfile : UDataAsset` with the nested sub-structs of §4.2.<br>Mixins: `mixin FMars_Validation Validate(const UMars_VineProfile Self)` and `mixin FString Get_SolveSignature(const UMars_VineProfile Self)`.<br>`namespace utils_vine { void Fill_Preset(UMars_VineProfile InProfile, EMars_VinePreset InPreset); }` holds the preset numbers in one place for the seeding command and the tests. |
| `Mars_Vine_Solve.as` | `struct FMars_Vine_Solver` holds the trace counter, budget and ignore list. Its methods are `Probe`, `Project`, `Creep`, `Hang`, `End_Ground`, `End_Air`, one `Solve_<Layout>` per layout, and `Smooth`.<br>`namespace utils_vine` holds the pure helpers: `Make_Stream`, `Get_PositionSeed`, `Hash_Fnv1a`, `Rmf_Frames`, `Resample_CatmullRom`, `Rotate_About`. |
| `Mars_Vine_Emit.as` | `struct FMars_Vine_Emitter`. It owns the HISMs it creates on demand (one per mesh used) and the spline-mesh chains, and does the custom data writes. |
| `Mars_Vine.as` | `class AMars_Vine : AActor`.<br>`class AMars_VinePcg : AMars_Vine` has `default SettingsSource = EMars_VineSettingsSource::Volume;` and the `PullVolumeSettings` post-spawn function. |
| `Mars_VineVolume.as` | `class AMars_VineVolume : AActor` (§6.2). |
| `Mars_HeroRoot.as` | `class AMars_HeroRoot : AActor` (§3.11). |
| `VINES.md` | The authoring contract (the §4 tables), mirroring `Script/ECS/Searing/GUIDELINE.md`. |
| `Script/Editor/Mars_VineCommands.as` (`#if EDITOR`) | Console commands, following the `FConsoleCommand` pattern in `Script/Editor/Mars_CampMapBuilder.as:28`:<br>- `Mars.Vine.SeedProfiles [force]` creates `Vine<Preset>_Mars_DA` with `UDataAssetFactory` + `AssetTools::CreateAsset` (the pattern at `Script/Editor/Mars_CrawlerAttackClips.as:17, 306-312`).<br>- `Mars.Vine.ReattachAll` (Phase 1).<br>- `Mars.Vine.Report` (Phase 1).<br>- `Mars.Vine.BakeSelected` (optional, Phase 6). |
| `Script/Tests/Vine/` | `UMars_AutoTestRig_Vine` (Abstract) plus one test class per file (§9). |

**`AMars_Vine` default components.** There are only two, so an empty vine costs nothing:

- `SceneRoot` (`USceneComponent`, Static).
- `Guide` (`USplineComponent`, `default Guide.bInputSplinePointsToConstructionScript = true`, as at
  `Mars_HangingChain.as:106-108`).

Every HISM and spline-mesh segment is created by the emitter inside the construction script with
`UHierarchicalInstancedStaticMeshComponent::Create(this)` and `USplineMeshComponent::Create(this)`.
`Create` called inside a construction script, or in a game world, goes through `PostCreateBlueprintComponent`, so the
component is marked `UserConstructionScript` and the engine destroys it on the next rerun (src:
`Plugins/Angelscript/Source/AngelscriptCode/Private/Binds/Bind_UActorComponent.cpp:70-99`). Each created component gets the tag
`Mars.Vine.Emitted`.

**`AMars_Vine` properties:**

- **Vine:**
  - `UMars_VineProfile Profile`
  - `EMars_VineLayout Layout`
  - `EMars_VineEnd End`
  - `int32 Seed` (0 = derive from position)
  - `EMars_VineCollision Collision`
  - `EMars_VineSettingsSource SettingsSource` (`Own` / `Volume`)
- **Layout:** `FMars_Vine_Shape Shape` with `LengthCm`, `WidthCm`, `StrandCount`, `Turns`, `HeightCm`, `PatchRadiusCm`,
  `GroundShare`. Also `float32 LengthOverrideCm = 0` (AdvancedDisplay), which only PCG writes.
- **Solve:**
  - `bool Freeze`
  - `UPROPERTY(NotEditable, AdvancedDisplay) FMars_Vine_Solved Solved`
  - `UPROPERTY(VisibleAnywhere) FString Status`
- **Buttons** (`UFUNCTION(CallInEditor)`): `Regenerate`, `Reseed`, `Reattach`, `AdoptVolumeSettings`.
- **Test seams:** `Rebuild()`, `Get_Report()`, `Get_PathPoints(int32, TArray<FVector>&)`, `Get_EmittedComponents(TArray<UPrimitiveComponent>&)`.

### 2.2 Blender, in `Tools/Blender/mars_environment/` (the existing kit)

| File | Role |
|---|---|
| `env_spec.py` (edit) | Adds slot `"EnvStrand": ("EnvFoliage_Mars_M", (70, 82, 44), "hanging moss strands, rootlets, cobwebs (two-sided, wind, length sway)")`. Family `"vines"` is already registered. |
| `env_vines_parts.py` (new) | numpy part generators in the style of `env_*_parts.py`: `bark_tube`, `ivy_chord`, `tip`, `knot`, `leaf_cluster`, `moss_strand`, `rootlet`, `cobweb_strand`, `hero_root_module` (SDF). The hero modules reuse `candle_gen.surface_nets`, `_smin`, `fill_pinches` and `_decimate` (`Tools/Blender/mars_cooking/candle_gen.py:149, 427, 460, 523`). `env_common.py` already puts `mars_cooking` on `sys.path` (`env_common.py:25-28`). |
| `build_env_vines.py` (new) | `blender -b --factory-startup --python build_env_vines.py -- [--export] [--sheets] [--save] [--only <part>]`. It rebuilds from fixed seeds, checks each mesh against §4.3 and prints `ENV_VINES_OK`, `ENV_VINES_FAIL` or `ENV_VINES_PARTIAL`. Export goes through `ec.export(obj, family="vines")` into `D:\Repo\Content\Environment\Dressing\export`, review sheets through `ec.review`. |

### 2.3 Editor Python, in `Tools/Blender/mars_environment/unreal/`

| File | Role |
|---|---|
| `mars_env_ue.py` (edit) | Adds the four "Env Data" slots to `build_paint_master` and `build_foliage_master` in place (§5.1). Adds `EnvStrand` to `_instance_table`. Its `import_meshes` and `assign_slots` already handle the `vines` family through the sidecar `ue_folder`. |
| `mars_vine_ue.py` (new) | Imports `mars_env_ue as me` and `mars_cooking_ue as mc`. Functions:<br>- `build_instances()`: `VineBarkRoot_Mars_MI`, `VineBarkWet_Mars_MI`, `VineLeafIvyWet_Mars_MI`, presets written only on creation, as `me._instance` does.<br>- `build_pcg_graphs()`, `check_pcg_graphs()`<br>- `place_volume(graph, box)`<br>- `build_gym_map()`<br>- `capture_review(out_dir)`<br>- `luminance_check(png)`<br>- `run_all()` |

### 2.4 Content

Meshes go under `/Game/Mars/Environment/Dressing/Meshes/Vines/`, which `env_spec.ue_mesh_folder("vines")` resolves to.

| Kind | Assets |
|---|---|
| Spline-mesh bark | `VineBark_A_Mars_SM`, `VineBark_B_Mars_SM` |
| Thin stems | `VineStemIvy_Mars_SM` |
| Root details | `VineTip_Mars_SM`, `VineKnot_A_Mars_SM`, `VineKnot_B_Mars_SM` |
| Leaf clusters | `VineLeaves_A/B/C_Mars_SM` |
| Moss strands | `VineMossStrand_A/B/C_Mars_SM` |
| Rootlets | `VineRootlet_A/B_Mars_SM` |
| Cobweb | `VineCobweb_A_Mars_SM` |
| Hero roots | `HeroRoot_Top_A_Mars_SM`, `HeroRoot_Mid_A/B/C_Mars_SM` (350 cm, one full twist), `HeroRoot_Flare_A/B_Mars_SM` |

Reused from the organic family: `DeadLeaves_Pile_A/B`, `DeadLeaves_Scatter_A`, `MossPad_A/B`, `MossDrape_A`.

| Kind | Path and names |
|---|---|
| Materials | Existing masters `/Game/Mars/Environment/Dressing/Materials/EnvPaint_Mars_M` and `EnvFoliage_Mars_M`. Existing instances `EnvBark/EnvLeaf/EnvLeafDry/EnvMoss_Mars_MI`. New: `EnvStrand_Mars_MI` and the three vine instances in `.../Materials/Instances/`. |
| Profiles | `/Game/Mars/Environment/Dressing/Vines/Profiles/Vine{Ivy,GiantRoot,ThinRoot,HangingMoss,Rootlets,Cobweb}_Mars_DA` |
| PCG graphs | `/Game/Mars/Environment/Dressing/Vines/PCG/VineCurtain_Mars_PCG`, `VineCeilingRoots_Mars_PCG`, `VineUnderside_Mars_PCG`, `VineSkirt_Mars_PCG`, optional `VineWallCreep_Mars_PCG` |
| Gym map | `/Game/Mars/Maps/VineGym_Mars_MAP` |

---

## 3. Algorithms

### 3.1 Construction script, cache and AngelScript traps

```
ConstructionScript():
    this.SetbRunConstructionScriptOnDrag(false)   // mixin, AngelscriptActorLibrary.h:5,168-174 (editor-only body)
    DoBuild()

Rebuild():                                       // tests + buttons
    if GetWorld().IsGameWorld(): DoBuild()
    else: utils_actor::Request_RerunConstructionScript(this)   // Plugins/CkFoundation/Script/Generated/utils_actor.as:14
                                                               // -> CkActor_Utils.cpp:622-632 RerunConstructionScripts
DoBuild():
    ApplyPhysics(actor tags)                      // HangingChain order (Mars_HangingChain.as:256-286)
    DestroyEmitted()                              // components tagged Mars.Vine.Emitted (a game-world Rebuild keeps them;
                                                  // an editor rerun has already destroyed them)
    Req = Resolve_Request()                       // own fields, or the attach-parent volume's (SettingsSource == Volume)
    if Req.Profile == null:          Status = "no profile";            return   // quiet: a designer state, never an ensure
    if Req.AwaitingVolume:           Status = "waiting for its volume"; return   // first PCG spawn pass, before attach
    V = Req.Profile.Validate(), then Req.Validate()
    if ck::EnsureIfNot(V.IsValid(), f"[Vine] [{GetName()}] {V.Get_Error()}"): Status = V.Get_Error(); return
    Hash = utils_vine::Get_InputHash(Req, ActorTransform, Guide points when Layout == Spline)
    if Freeze or (Hash == Solved.InputHash and !_ForceSolveOnce): reuse Solved (0 traces)
    else: Solved = FMars_Vine_Solver(this, Req).Solve(); Solved.InputHash = Hash; _ForceSolveOnce = false
    Report = FMars_Vine_Emitter(this, Req).Emit(Solved)  // deterministic from Solved + seed, no traces
    if Layout != Spline: write the main path into Guide (visibility only, as HangingChain does)
    Status = Report.ToString()   // "412 traces, 38 segments, 1210 leaves, solved|cached"
```

**Traps and their rules:**

- **The 1 s script limit.** `EditorMaximumScriptExecutionTime = 1.f` (src:
  `Plugins/Angelscript/Source/AngelscriptCode/Public/AngelscriptSettings.h:147`), and Mars config does not override it.
  `Validate` therefore rejects any request whose *worst-case* estimate exceeds these limits:

  | Item | Limit per actor |
  |---|---|
  | Traces | ≤ 3000 |
  | Spline-mesh segments | ≤ 64 |
  | Leaves | ≤ 4000 |
  | Strand cards | ≤ 1500 |
  | Instanced stem chords | ≤ 3000 |

  The estimate is computed from the profile, the shape and the layout's sample counts.
- **Buttons never build directly.** `Create` called in the editor world *outside* a construction script adds an instance
  component, and those accumulate (src: `Bind_UActorComponent.cpp:70-88`). So buttons set flags and request a rerun.
  `AActor::RerunConstructionScripts` itself is not a UFUNCTION, which is why the CkCore helper wraps it.
- **Level load.** The editor reruns construction scripts on level load, actor by actor. The kit's collision may not be
  registered yet. The cache means a load never re-traces, so a vine cannot collapse because of load order. A changed room
  never re-solves silently: the designer presses Reattach, or runs `Mars.Vine.ReattachAll`.
- **Profile fallback.** It runs only in the editor world: `EditorAsset::DoesAssetExist` first, then `LoadObject`, with the
  result kept on `Profile` (`Mars_HangingChain.as:238-255`). A missing package must never log, because that fails autotests.

### 3.2 Seeds and streams

- `EffectiveSeed = Seed != 0 ? Seed : int32(Hash_Fnv1a(f"{round(X/10)},{round(Y/10)},{round(Z/10)}"))`. Alt-drag copies
  differ automatically. Reseed writes a new non-zero `Seed`.
- `Make_Stream(Seed, Index, Purpose) = FRandomStream(int32(Hash_Fnv1a(Purpose) ^ (uint32(Seed) * 2654435761u) ^ (uint32(Index) * 40503u)))`.
  This is the mixing in `Script/ECS/AnchorResolver/Mars_AnchorResolver_Solve.as:530-551`. It matters because raw
  consecutive seeds give an LCG similar first draws (`:587`).
- Purposes: `strand`, `len`, `meander`, `branch`, `leaf`, `card`, `knot`, `finger`, `tint`. Each purpose has its own
  stream, so changing leaf density never reshuffles a path.
- The emitter uses no traces: leaves and knots read the normals stored on the path. Emission is therefore a pure function
  of `Solved` and the seed.

### 3.3 Surface primitives

Every trace is:

```
System::LineTraceSingle(Start, End, ETraceTypeQuery::Visibility, TraceComplex, Ignored, EDrawDebugTrace::None, Hit, true)
```

There is an in-repo call in a namespace function at `Script/Fx/Mars_SurfaceFx.as:313-314`. `TraceComplex` comes from the
profile: true for ivy (so it hugs the carved surface, not the UCX hull), false for roots. Each trace increments
`TraceCount`. Points are quantized to 0.1 cm and normals to 1e-3 before they are stored, so hashes stay stable.

```
Probe(Q{P, HintN, Radius}) -> SurfaceHit?
    HintN != 0: one ray P + HintN*R -> P - HintN*R
    else: 14 rays (+-X +-Y +-Z, 8 diagonals) of length R; the nearest hit
Creep(Q{Start, N, Dir, Length, Step, StandOff, Bias, BiasWeight, MeanderDeg, Stream}):
    p = Start; n = N; d = normalize(Dir - n*(n.Dir))
    while walked < Length and TraceCount < Budget:
        d = Rotate_About(d, n, Stream.FRandRange(-1, 1) * MeanderDeg)
        d = normalize(lerp(d, TangentOf(Bias, n), BiasWeight))
        q = p + d*Step
        fwd = ray p -> q + d*StandOff                         // concave corner: climb onto the facing wall
        if fwd: p = fwd.P + fwd.N*StandOff; n = fwd.N; d = TangentOf(Bias or d, n); append; continue
        down = ray q + n*Step -> q - n*2*Step                 // stay on the surface
        if down: p = down.P + down.N*StandOff; n = normalize(lerp(n, down.N, 0.7))
        else:                                                // convex edge: wrap round it
            wrap = ray q - n*(StandOff+Step) -> p - n*(StandOff+Step)
            if wrap: p = wrap.P + wrap.N*StandOff; d = -n; n = wrap.N
            else: return (path, LeftSurfaceAt = p)           // the edge drops into air: caller hangs from here
        append (p, n)
```

`TangentOf(B, n) = normalize(B - n*(n.B))`, falling back to the current `d` when `B ∥ n`. This one primitive covers floor
creep (Bias 0), wall climb (Bias +Z, weight 0.3), drape over a lip (Bias −Z after the lip), ceiling flare and pier
wrapping.

### 3.4 Layouts

| Layout | Input | Solve |
|---|---|---|
| Spline | Guide points (actor-local) | Resample at `Attach.StepCm`. Per sample, `h = Probe(p, 0, Rc)` and `w = 1 - smoothstep(0.5Rc, Rc, dist)`, then `p' = lerp(p, h.P + h.N(r + StandOff), w)`. The normal is stored when `w > 0.5`. The guide itself is never rewritten (non-destructive). The last point gets end handling (§3.5). |
| Creep | Origin near a wall or pipe | Start = `Probe(origin, 0, 150)`. Then `Creep(Bias +Z, 0.3, Length = Shape.HeightCm or 400)`. 1-3 stems fan out at ±35°. The bottom gets end handling. |
| Drop | Origin under a ceiling | Ray up 300 cm. Bury the start `Ends.Ceiling.BuryCm` (20 cm) above the hit. Axis −Z with meander `A·(n1(s/λ), n2(s/λ))` from 1D value noise, tapered to 0 over the first and last 80 cm. Floor ray down `Ends.Air.MaxDropCm` (3000) gives `D`. `L = LengthOverrideCm > 0 ? min(LengthOverrideCm, D) : drawn`. Then end handling. |
| Curtain | Origin 30 cm past a lip, +X outward, local Y along the edge | For each of K strands at `y_k = (k/(K-1) - 0.5)·Width + jitter(±0.15·Width/K)`:<br>1. Find the face: ray from `S - Z·15` toward −X, 80 cm.<br>2. Find the top: ray down from `face - X·10 + Z·40`.<br>3. Start `TopInset` (10-25 cm) back on the top, then `Creep(Dir +X)`. It wraps the lip and creeps down the face with Bias −Z until the face ends; baluster gaps detach it naturally.<br>4. Hang (§3.5).<br>No host found: the strand hangs straight from S. |
| Wrap | Origin at a pier or pipe base (±30 cm). Axis = actor local Z, so a rotated actor wraps a horizontal pipe | `N = ceil(Turns·24)` samples with `θ_i = θ0 + 2π·Turns·i/N` and `z_i = H·i/N` (H = `HeightCm`, or a ray to the ceiling capped at 600). Ray from `axis + 200(cosθ, sinθ, 0) + z` inward gives `p = hit + n·StandOff`. 1-3 stems with phase `2πj/StemCount`. The bottom gets end handling. |
| Patch | Origin under an arch or vault | `N = density·πR²` strands (R = `PatchRadiusCm`, 90). Clumps: `max(1, N/5)` centres in the disc, strands at centre + Gaussian σ 18 cm (Box-Muller). Ray up 2000 cm, accepting hits with `n.z < −0.2`. Ray down gives D. The clump length is drawn once and each strand takes `× U(0.7, 1.3)`. |

### 3.5 The Ground / Air toggle

The toggle applies to every free end.

```
End_Air(Q{PLast, DFloor, Stream}):
    L = clamp(DFloor * U(LenFracMin, LenFracMax), LenMin, DFloor - ClearanceMin)   // Curtain: §3.9 correlated lengths
    hang straight down to PLast.z - L with sway (SwayCm, wavelength 120 cm); the last 15 % curls by TipCurlDeg
    about a seeded horizontal axis; no point below floor + ClearanceMin
End_Ground(Q{PLast, FloorHit, Stream}):
    hang to F + N_f*(r + ContactBendCm); quarter-circle fillet into d
    d = the most open of 8 horizontal rays at 30 cm height, +-30 deg jitter
    Creep(F, N_f, d, U(CreepMin, CreepMax), Step, StandOff = -SinkFrac*r)   // a negative stand-off sinks roots in
    roots: F fingers, yaw_j = phi0 + 2*pi*j/F + U(-0.35, 0.35); each starts 30 cm above contact on the main surface and
           creeps U(FingerLenMin, FingerLenMax); radius 0.30R -> 0.04R
    rootlets: coil 10-30 cm on contact; litter instance (organic DeadLeaves_Scatter_A scaled 0.3-0.5) with LitterChance
GroundShare: each strand takes End_Ground when Stream.FRand() < GroundShare, else End_Air (default 1 for Ground, 0 for Air)
No floor within MaxDropCm: Ground falls back to Air and Status reports "no floor under N strands"
```

The ceiling flare (GiantRoot, ThinRoot) reuses the finger code with `N = ceiling normal`: 2-4 fingers, 40-120 cm.

### 3.6 Taper, frames and the two-strand twist

- **Radius:** `R(s) = R0·lerp(1, EndFrac, (s/L)^TaperPower)·(1 + JitterFrac·n(s))`, where `R0 = StartCm·U(0.75, 1.25)` is
  drawn once per vine. Roots get +15 % buttress over the 40 cm before ground contact.
- **Frames** are rotation-minimising (double reflection):
  ```
  v1 = x_{i+1}-x_i; rL = r_i - 2(v1·r_i)/(v1·v1)·v1; tL = t_i - 2(v1·t_i)/(v1·v1)·v1
  v2 = t_{i+1}-tL;  r_{i+1} = rL - 2(v2·rL)/(v2·v2)·v2;  b = t × r
  ```
  `r_0` is the surface normal where there is one, otherwise any horizontal vector perpendicular to `t_0`. Each spline-mesh
  segment gets `SplineUpDir = r_i`, so a vertical drop never uses the default `(0,0,1)` up, which would be parallel to its
  tangent.
- **Twist** (`Twist.Strands = 2`), for strand k ∈ {0, 1}:
  - `θ_k(s) = θ0 + 2πs/Pitch + kπ`
  - `d(s) = R(s)·OffsetFrac·(1 + 0.8·max(smoothstep(L−90, L, s), 1 − smoothstep(0, 90, s)))`
  - `c_k = C + d(cosθ_k r + sinθ_k b)`, with radius `R·StrandFrac`

  Defaults are Pitch 220, OffsetFrac 0.42 and StrandFrac 0.62. The centre distance 0.84R is less than the radius sum
  1.24R, so the two strands fuse like rope and fork at both ends (concept a).

### 3.7 Branches, tendrils, knots

- **Branches (ivy).** Along the surface part of a path, every `Branches.SpacingCm·U(0.6, 1.4)` (35 cm), a branch starts
  with chance 0.45. It leaves at 25-60° in the tangent plane and creeps 15-60 cm with the parent's bias, depth 1. On
  hanging parts a branch is instead a 20-80 cm hang: a dangling tendril.
- **Tendrils.** 1-2 per Air tip, 10-25 cm long, curled 90°. No traces.
- **Knots (roots).** A Poisson process at 0.5 per metre. Each sits at `c + r̂·R·0.6`, oriented to the frame, with scale
  `R·U(0.5, 0.8)/50`. Emitter only.

### 3.8 Smoothing and resampling

1. Drop points closer than 0.5·Step.
2. Run 2 Laplacian passes. On surface points the delta is projected onto the tangent plane, `Δ − n(n·Δ)`, so the stand-off
   holds without re-tracing.
3. Resample by arc length with centripetal Catmull-Rom to `Stem.SegmentLengthCm`: 75 for roots, 40 for thin roots, 10 for
   ivy chords.

The tangents `T_i = 0.5(P_{i+1} − P_{i−1})` become the spline-mesh start and end tangents.

### 3.9 Leaves, strands, curtain lengths

- **Leaves.** Spacing is `7 cm·U(0.6, 1.4)`. The keep probability is
  `Density·(s/L < 0.65 ? 1 : lerp(1, 0.3, (s/L − 0.65)/0.35))`. Meshes A/B/C are picked with weights 0.5/0.35/0.15. Scale
  is `U(0.8, 1.25)·lerp(1, 0.6, s/L)`.
  - On a surface: Z is the normal tilted by U(0, 25°); X is the tangent turned ±70°, alternating sides; the position is
    `p + n·StandOff + side·r`.
  - Hanging: Z is horizontal ±60° outward and X droops 40°.
- **Curtain lengths** are correlated, not independent. Control values `c_m = FRand()` sit every 3 strands and are
  cosine-interpolated to `f(k)`, so `L_k = lerp(FracMin, FracMax, f(k))·D_k`. With 12 % chance a strand is a straggler at
  `min(1.35 L_k, D_k − ClearanceMin)`. Each strand traces its own `D_k`: that is the "trace to the ground to match the
  length".
- **Strand cards** (moss, rootlets, cobweb). Each sits 2 cm inside the surface at the hit, with yaw U(0, 360), tilt ≤ 3°
  and scale `(w, w, L/100)`, where w = U(0.7, 1.4). The cards are 100 cm long, so `L/100` stretches them to the traced
  length, and `L` goes into custom data slot 3 (§4.1).

### 3.10 Emission

**Roots** (`Stem.Render = SplineMesh`), per segment i:

```
Seg = USplineMeshComponent::Create(this); Seg.ComponentTags.Add(n"Mars.Vine.Emitted")
Seg.SetMobility(Static); Seg.SetStaticMesh(Bark A or B by stream); Seg.SetForwardAxis(ESplineMeshAxis::X, false)
Seg.SetStartAndEnd(P_i, T_i, P_{i+1}, T_{i+1}, false)            // actor-local; the component sits at the root
Seg.SetStartScale(FVector2D(r_i/50, r_i/50), false); Seg.SetEndScale(FVector2D(r_{i+1}/50, r_{i+1}/50), false)
Seg.SetSplineUpDir(r_i, false); Seg.SetStartRollDegrees(roll_i, false); Seg.SetEndRollDegrees(roll_{i+1}, false)
Seg.SetBoundaryMin(0, false); Seg.SetBoundaryMax(100, false)
Seg.SetDefaultCustomPrimitiveDataFloatArray(0, {VarSeed, MossScale, WetAdd, 0})   // serialized; PrimitiveComponent.h:1219-1220
Seg.SetCollisionProfileName(...); tags; Seg.SetCastShadow(...); Seg.SetAffectDistanceFieldLighting(false)
Seg.UpdateMesh()
```

- Every setter is a UFUNCTION (src: `SplineMeshComponent.h:274-402`, `PrimitiveComponent.h:1219-1220, 1882, 1922`).
- `roll_i = U(0, 360)` per point, so the facets never line up.
- Repo precedent for `USplineMeshComponent::Create` exists only in a game world:
  `Plugins/CkTests/Script/CkJolt/CkJoltGym_StaticBake.as:302`. The construction-script case is spike S1.

**Instanced stems and cards.** The emitter keeps one HISM per mesh it uses, created on demand:

- Set up: `Create(this)`, Static, `SetNumCustomDataFloats(4)`
  (src: `InstancedStaticMeshComponent.h:315-317`).
- Fill: `AddInstances(Transforms, false)` (`:263-264`).
- Data: `SetCustomDataValue(Index, k, v, bMarkRenderStateDirty = (last write))` (`:312-313`).
- Cull: `SetCullDistances(3500, 5000)` (`:431-433`).

Ivy stems are one HISM chord per resampled step, scaled `(len·1.1/100, r/50, r/50)`; the 10 % overlap hides the joints.
`SetCustomDataValue` returns false silently when `NumCustomDataFloats` is too small, so the emitter asserts it is 4 once
per component.

### 3.11 `AMars_HeroRoot` (atrium hero roots)

- `H` is the traced floor distance from the actor (the ceiling contact), or `FixedHeightCm`.
- `n = max(1, round((H − TopH − FlareH)/350))` mid modules.
- `zScale = (H − TopH − FlareH)/(n·350)` must lie in [0.8, 1.25]. If not, `Validate` ensures and names the height.
- Each mid module yaw-flips 0° or 180° by stream, which keeps the twist continuous because both strands are identical, and
  picks variant A/B/C.
- There is one HISM per module slot (Top, Mid, Flare), created on demand as in §3.10. The modules carry UCX hulls.
  Collision defaults to On (§8, §11).

### 3.12 Profile defaults (`utils_vine::Fill_Preset`)

| Field | Ivy | GiantRoot | ThinRoot | HangingMoss | Rootlets | Cobweb |
|---|---|---|---|---|---|---|
| Stem render | Instanced | SplineMesh | SplineMesh | None | None | None |
| Radius start / end (cm) | 1.2 / 0.6 | 35 (×U .75-1.25) / 6 | 4 / 0.8 | - | - | - |
| Segment (cm) | 10 | 75 | 40 | - | - | - |
| Twist strands / pitch (cm) | 1 | 2 / 220 | 1 | - | - | - |
| ClingRadius / StandOff / Step (cm) | 60 / 0.5 / 10 | 120 / −0.15R / 50 | 60 / 0.5 / 20 | - | - | - |
| Meander amplitude / wavelength (cm) | 3 / 40 | 35 / 300 | 10 / 120 | - | - | - |
| Ground | creep 30-120 | fingers 3-5 × 60-160, sink 0.35 | fingers 2-3 × 20-60 | touch | touch + coil 10-30, litter 0.3 | - |
| Ceiling flare | - | 2-4 × 40-120, bury 20 | 0-2 × 20-40 | - | - | - |
| Air clearance (cm) / length fraction | 60-250 / 0.35-0.95 | 80-200 / - | 40-180 / - | 40 / 0.06-0.30, max 300 | 25 / 0.10-0.60, max 400 | 25 / - |
| Branches | 35 cm, p .45, 25-60°, 15-60 cm | - | p .2 forks | - | - | - |
| Leaves / cards | 7 cm, A/B/C | knots 0.5/m, tip | tip | 6/m², clumps | 4/m² | 1/m², 30-80 cm |
| Shadows | leaves on (Rigid), stems off | on | on | off | off | off |
| Collision | Off | Off (On optional) | Off | Off | Off | Off |

---

## 4. Data contracts

### 4.1 Custom data: four floats, the same slot meaning on every vine primitive

| Material | Slot 0 | Slot 1 | Slot 2 | Slot 3 |
|---|---|---|---|---|
| `EnvPaint_Mars_M` (bark, stems, knots, tips, hero roots) | VarSeed [0, 1) (default 0) | MossScale [0, 2] (default 1) | WetAdd [0, 1] (default 0) | reserved (default 0) |
| `EnvFoliage_Mars_M` (leaves, strands, litter) | VarSeed (default 0) | Dryness [0, 1] (default 0) | WindWeight [0, 2] (default 1) | LengthCm (default 100) |

**Writers:**

- **Spline-mesh segments:** `FMars_Vine_Emitter`, through `SetDefaultCustomPrimitiveDataFloatArray`. The runtime
  `SetCustomPrimitiveData*` setter "doesn't serialize" (src: `PrimitiveComponent.h:1136-1138` vs `:1219-1220`). Placed vines
  never rerun their construction script in a cooked game, so runtime-only data would be lost.
- **Emitter HISMs:** `SetCustomDataValue` per instance.
- **PCG ISMs:** `UPCGInstanceDataPackerByAttribute.AttributeSelectors`, in slot order (src:
  `Public/InstanceDataPackers/PCGInstanceDataPackerByAttribute.h:23-27`). `VineUnderside_Mars_PCG` packs
  `[VarSeed, Dryness, WindWeight, LengthCm]`, and `VineSkirt_Mars_PCG` packs `[VarSeed, MossScale, WetAdd, 0]` for
  MossPads, or the foliage layout for leaf piles.
- **`AMars_HeroRoot`:** its HISMs, per instance.

**Reader:**

- Each slot is read with a `PerInstanceCustomData(DataIndex = i)` expression whose `DefaultValue` input is wired to a CPD
  scalar parameter `Env Data i` (`use_custom_primitive_data`, `primitive_data_index = i`, the pattern at
  `Tools/Blender/mars_cooking/unreal/mars_cooking_ue.py:316-317`). The `DefaultValue` input exists at
  `Source/Runtime/Engine/Public/Materials/MaterialExpressionPerInstanceCustomData.h:18-25`.
- The shader returns `DefaultValue` whenever the index is at or above the primitive's custom-data count (src:
  `Engine/Shaders/Private/MaterialTemplate.ush:1484-1494, 1514-1524`).
- So:
  - instanced vines read their per-instance values;
  - spline meshes read their CPD;
  - every *existing* kit prop, which has no CPD and 0 custom floats, reads the neutral defaults and looks exactly as it does
    today.

**Neutral defaults are mandatory.** A merge bake drops per-instance data and must not change the look.

### 4.2 `UMars_VineProfile` (sub-structs ≤ 7 fields, nested where larger)

| Struct | Fields |
|---|---|
| `Stem: FMars_VineProfile_Stem` | `Render`, `Meshes: FMars_VineProfile_StemMeshes {Mesh, AltMesh, TipMesh, KnotMesh, ForwardAxis, BoundaryCm}`, `Radius: {StartCm, EndFrac, TaperPower, JitterFrac}`, `SegmentLengthCm`, `RollJitterDeg` |
| `Twist` | `Strands (1 or 2)`, `PitchCm`, `StrandFrac`, `OffsetFrac`, `SplitLengthCm` |
| `Attach` | `ClingRadiusCm`, `StandOffCm`, `StepCm`, `SmoothPasses`, `TraceComplex`, `Meander: {AmpCm, WavelengthCm, CreepDeg}` |
| `Ends` | `Ground: {CreepCm (FVector2D), Fingers: {Count (FIntPoint), LengthCm, RadiusFrac, SinkFrac}, ContactBendCm, LitterChance}`, `Air: {ClearanceCm, LengthFrac, LengthCm, TipCurlDeg, MaxDropCm}`, `Ceiling: {Fingers, BuryCm}` |
| `Branches` | `SpacingCm`, `Chance`, `AngleDeg (FVector2D)`, `LengthCm`, `Depth`, `TipTendrils (FIntPoint)` |
| `Leaves` | `Meshes (≤ 3)`, `Weights`, `SpacingCm`, `Scale (FVector2D)`, `Falloff: {HoldFrac, TipDensity, TipScale}`, `TiltDeg`, `DroopDeg` |
| `Strands` | `Meshes (≤ 3)`, `PerSquareMetre`, `ClumpSigmaCm`, `PerMetre`, `Width (FVector2D)`, `LitterMesh` |
| `Curtain` | `StrandsRange (FIntPoint)`, `WidthCm`, `TopInsetCm`, `StragglerChance` |
| `Rendering` | `StemMaterial`, `LeafMaterial`, `StrandMaterial` (null = mesh slot default), `Shadows: {Stems, Leaves, Strands}`, `CullCm (FVector2D)`, `Collision`, `Data: {MossScale, WetAdd, Dryness}` |

**`Validate` rejects:**

- missing meshes for the chosen render mode;
- `EndFrac` outside (0, 1];
- any range with Min > Max;
- `StepCm` outside [2, 200];
- `StandOffCm > ClingRadiusCm`;
- `Twist.Strands == 2` with `PitchCm ≤ 0`;
- a worst-case estimate above the §3.1 budgets.

Each error names the field.

**`Get_SolveSignature`** joins only the fields that affect the solve. Meshes, materials and data are left out, so swapping a
mesh re-emits without re-tracing.

**Profiles are `.uasset` data assets**, so designers can edit and duplicate them. They are created by `Mars.Vine.SeedProfiles`.
Tests build them with `NewObject(this, UMars_VineProfile)` + `Fill_Preset` and engine shapes only.

### 4.3 Mesh contract

This is the env kit's own contract (`env_spec.py` header): centimetres, Blender Z up, Unreal local = (x, −y, z). Colour
attribute "Col" holds linear RGB albedo with cavity in A. UV1 "EnvData" has u = per-piece id and v = flex, 0 at the
attachment and 1 at the free tip (stored `1 − v` in Blender: `env_common.write_data_uv`).

| Mesh | Pivot and axis | Size | Tri budget (`env_spec.TRIS`) | Slot | UV1 EnvData |
|---|---|---|---|---|---|
| `VineBark_A/B` | x = 0 start, +X long, open ends | 100 long, radius 50; 9 sides × 6 (A) / 8 (B, mid knot bulge) rings; ridge amplitude 0.08, identical on the x = 0 and x = 100 rings (periodic, so segments meet seamlessly) | ≤ 160 (scatter) | EnvBark | - |
| `VineStemIvy` | as bark | 100 long, radius 50, 6 × 4 | ≤ 60 | EnvBark | - |
| `VineTip` | base at x = 0, +X to the point | 100 long, base radius 50 | ≤ 40 | EnvBark | - |
| `VineKnot_A/B` | centre | radius 50 lump | ≤ 80 | EnvBark | - |
| `VineLeaves_A/B/C` | petiole base; leaves fan to +X, faces +Z | 9 / 14 / 20 cm, 3 / 5 / 7 folded ivy leaves (kite, three-lobed and five-lobed outlines, reusing `build_env_organic.leaf_shape` copied in, since builders never import each other: `env_common.py` header) | ≤ 30 / 50 / 70 | EnvLeaf | u = leaf id, v = distance from pivot / max |
| `VineMossStrand_A/B/C` | top; hangs −Z | 100 long, two crossed jagged ribbons, 12 rows, width 3-6 cm tapering | ≤ 60 | EnvStrand | u = strand id, v = 0 top → 1 bottom |
| `VineRootlet_A/B` | top; −Z | 100 long, 3-sided, radius 0.5, 2-3 hairs | ≤ 60 | EnvStrand | same |
| `VineCobweb_A` | top centre | 100 × 100 sagging fan of thin triangle threads, pale paint (geometry, no texture) | ≤ 120 | EnvStrand | u = thread id, v = sag weight |
| `HeroRoot_Top_A` | top centre (ceiling contact), hangs −Z | 2 strands fused, 180 tall, 60-80 thick, 3 ceiling fingers | ≤ 9000 (furniture) | EnvBark | - |
| `HeroRoot_Mid_A/B/C` | top centre, −Z | 350 tall, one full twist, canonical joint loops at both ends (vertex group locked under Decimate; noise faded within 15 cm of the joints; 4 cm overlap) | ≤ 9000 | EnvBark | - |
| `HeroRoot_Flare_A/B` | top centre, −Z to the floor | 160 tall plus 4-6 floor fingers to 260 cm | ≤ 9000 | EnvBark | - |

**Builder checks** (all must pass for `ENV_VINES_OK`):

- tri budget;
- slot names are in `env_spec.SLOTS`;
- the "Col" attribute exists, with alpha in [0, 1];
- UV1 is present wherever the table requires it;
- the long axis is 100 ± 0.5 cm for segments;
- the bark end rings match;
- the hero joint loops match between Top/Mid/Flare (max vertex delta < 0.2 cm).

**Collision.** Bark A/B carry one `UCX_` convex 8 × 2 hull for the optional collision path, and the spline mesh deforms
simple shapes (`SplineMeshComponent.cpp`, RecreateCollision). Hero modules carry 2-4 UCX hulls per module. Leaves, strands,
knots and tips carry none, so the importer gives them no collision (`env_spec.py` naming note).

**Import.** `me.import_meshes(only="vines")` with Nanite off. LOD1 is added afterwards by `mars_vine_ue` at 50 % with
screen size 0.15.

---

## 5. Materials

### 5.1 The two existing masters, extended in place (`mars_env_ue.py`)

Both masters are rebuilt in place by `me._master()`, which empties the same `UMaterial` and refills it. Replacing a master
asserts in the renderer (`mars_env_ue.py` docstring and `_master`). Usage flags (ISM + spline mesh) are already set by
`_usage()`. The builder then asserts them with `has_material_usage`.

**New group "Env Data"** in both masters: four `PerInstanceCustomData` expressions (slots 0-3), each with `DefaultValue` ←
the CPD scalar `Env Data i`, using the defaults from §4.1.

**`EnvPaint_Mars_M`** (Opaque, DefaultLit, one-sided):

- `Extra` input of `VARIATION_HLSL`: today a zero constant. It becomes `Data0`, so `r = frac(h + Rand·7.137 + Data0·3.31)`
  gives a per-vine shift.
- `MossAmount` becomes `saturate(MossAmount·Data1)`.
- `Wetness` becomes `saturate(Wetness + Data2)`.
- `LAYERS_HLSL` already produces moss on up-facing faces, world-space fbm grime and wet darkening/roughness. Wet roughness
  0.1 reads glossy only near a reflection capture, which is correct under `r.ReflectionMethod=0`.
- `VertexNormalWS` on a spline mesh is the deformed normal, so moss follows the bend.

**`EnvFoliage_Mars_M`** (TwoSidedFoliage, two-sided, opaque):

- `Extra = u + Data0` (per-leaf id plus per-vine seed).
- New vector `Dry Color` (0.12, 0.07, 0.03). `Base = lerp(Base, DryColor·lumaOf(Base)/0.06, Data1)`.
- Wind: `Strength_eff = Strength · Data2 · lerp(1, Data3/100, LengthSway)`, with new scalar `Length Sway` 1. A 3 m moss
  strand therefore sways three times as far as a 1 m strand, at the same flex² profile.
- `WIND_HLSL` is unchanged otherwise. Its phase is `Id·2π + dot(WP, (0.0071, 0.0053, 0.0029)) + Rand·4.1`, so no two
  leaves, strands or places sway in step, and this still works after a merge.
- The albedo floor stays at 0.02 linear or above, so ivy is not crushed under manual exposure (checked by the luminance
  test in §9.2).

`Tint`, `Cavity AO`, `Hue Variation` and `Value Variation` stay as they are today. Wind: `Wind Strength` 1.5 cm,
`Speed` 1.1, `Flutter` 0.35.

### 5.2 Instances

| Instance | Parent | Presets |
|---|---|---|
| `EnvBark_Mars_MI` (exists) | Paint | Roughness 0.85, Moss 0.35 |
| `EnvLeaf_Mars_MI` (exists) | Foliage | Roughness 0.55 |
| `EnvLeafDry_Mars_MI` (exists) | Foliage | dry tones, Wind 0.4 |
| `EnvStrand_Mars_MI` (new slot) | Foliage | Roughness 0.9, Wind Strength 3 (per metre via Length Sway), Flutter 0.15, Subsurface (0.06, 0.08, 0.03) |
| `VineBarkRoot_Mars_MI` | Paint | Moss 0.5, Grime 0.35, Value Variation 0.18 |
| `VineBarkWet_Mars_MI` | Paint | Wetness 0.7, Moss 0.6 (sewer and cistern) |
| `VineLeafIvyWet_Mars_MI` | Foliage | Roughness 0.3 (glints near captures) |

The profile's `Rendering.*Material` picks a vine instance. When it is null, the mesh's slot default (`<Slot>_Mars_MI`)
applies, bound by `me.assign_slots`.

### 5.3 Where breakup comes from

The material layers are:

- `PerInstanceRandom` per leaf, card and chord;
- the object-position hash per actor (for spline meshes that is the actor root, so one vine is consistent with itself);
- Data0 per vine;
- the UV1 id per leaf;
- world-space grime and moss fbm in metres, with no tiling;
- moss on up-facing normals;
- wetness and dryness per instance;
- the wind phase from world position.

Geometry adds seeded paths, variant meshes, scale, tilt and correlated lengths on top. There are no textures, by the kit's
style ruling.

---

## 6. PCG

### 6.1 Verified mechanics

| Mechanic | Source |
|---|---|
| PCG's BlueprintCallable surface is reachable from AngelScript, e.g. `GenerateLocal(bool)`, `CleanupLocal(bool)`, `ClearPCGLink(UClass)`, `SetGraph` (a NetMulticast UFUNCTION) | `Public/PCGComponent.h:223-224, 249-262, 300-302` |
| `GenerationTrigger` is EditAnywhere + BlueprintReadOnly, so `default PCG.GenerationTrigger = EPCGComponentGenerationTrigger::GenerateOnDemand` is allowed | `PCGComponent.h:348-349`; §0.5 |
| **Spawn Actor:** property overrides are applied to a transient template that is passed as `SpawnParams.Template`, so the construction script sees overridden values | `Private/Elements/PCGSpawnActor.cpp:836-848` |
| **Spawn Actor:** post-spawn functions run after spawning (no parameters, or point + metadata) | `:980-1000` |
| **Spawn Actor:** in the editor, post-spawn functions on actors must be `CallInEditor` or they are skipped with a graph warning | `Private/Helpers/PCGHelpers.cpp:660-680` |
| **Spawn Actor:** `AttachOptions` defaults to `Attached`, and actors spawn into the target actor's level | `Public/Elements/PCGSpawnActor.h:89`; `.cpp:848` |
| **Spawn Actor:** `bWarnOnIdenticalSpawn` defaults true, so set it false, because a warning fails autotests | `PCGSpawnActor.h:99` |
| **Overrides:** writable property types are numeric, bool, string, name, enum, soft and hard class/object, vector, rotator and transform | `Private/Metadata/Accessors/PCGAttributeAccessorHelpers.cpp:103-195` |
| **Overrides:** property chains are resolved | `Private/Metadata/PCGObjectPropertyOverride.cpp:123-140` |
| World Raycast attribute names: `ImpactResult`, `ImpactNormal`, `ImpactDistance`, `ImpactStaticMesh`, ... | `Public/Helpers/PCGWorldQueryHelpers.h:35-48` |
| World Raycast: a hit's seed is recomputed from the hit position | `Private/Elements/PCGWorldRaycast.cpp:535` |
| World Raycast: `bUnbounded` defaults false (rays are clipped to the actor bounds) | `PCGWorldRaycast.h:97-98` |
| World Raycast: query params include `bIgnorePCGHits`, `bIgnoreSelfHits` (true), `CollisionChannel` (WorldStatic), `ActorTagFilter`/`ActorTagsList`, `bGetImpact`, `bGetImpactNormal`, `bGetDistance`, `bGetReferenceToStaticMesh` | `Public/Data/PCGWorldData.h:61-177` |
| Normal To Density computes `pow(clamp(Up·Normal + Offset, 0, 1), 1/Strength)` on the point's Z axis, which is the impact normal after a raycast | `Private/Elements/PCGNormalToDensity.cpp:45-53` |
| **Graph authoring:** `AddNodeOfType`, `RemoveNodes`, `AddEdge`, `GetInputNode`, `GetOutputNode` and `ForceNotificationForEditor` are UFUNCTIONs, and `Nodes` is BlueprintReadOnly | `Public/PCGGraph.h:351-387, 446-447, 531-532` |
| **Graph authoring:** `AddEdge` returns `To` even when a pin label is wrong; it only logs `LogPCG Error ... does not have the X label` | `Private/PCGGraph.cpp:1101-1128` |
| **Graph authoring:** each node has a `Seed` property | `Public/PCGSettings.h:412-413` |
| Pin labels: `In`, `Out`, `Overrides`, `InsideFilter`, `OutsideFilter` | `Public/PCGCommon.h:200-208` |
| Pin labels: Difference `Source` / `Differences` | `PCGDifferenceElement.h:12-13` |
| Graph asset creation: `AssetToolsHelpers.get_asset_tools().create_asset(name, path, unreal.PCGGraph, None)`, as in Epic's test | `Engine/Plugins/PCG/Content/Python/test_pcg_manage_asset.py:31-41` |
| Every settings class this plan names exists in 5.7. Checked: `UPCGCreatePointsGridSettings`, `UPCGGetActorPropertySettings`, `UPCGWorldRaycastElementSettings`, `UPCGNormalToDensitySettings`, `UPCGDensityFilterSettings`, `UPCGTransformPointsSettings`, `UPCGAttributeFilteringSettings`, `UPCGMergeSettings`, `UPCGDifferenceSettings`, `UPCGDataFromActorSettings`, `UPCGPointExtentsModifierSettings`, `UPCGSelfPruningSettings`, `UPCGSpatialNoiseSettings`, `UPCGAttributeNoiseSettings`, `UPCGMetadataMathsSettings`, `UPCGMetadataMakeVectorSettings`, `UPCGGenerateSeedSettings`, `UPCGRandomChoiceSettings`, `UPCGSpawnActorSettings`, `UPCGStaticMeshSpawnerSettings`, `UPCGMeshSelectorWeighted`, `UPCGInstanceDataPackerByAttribute` | grep of `Plugins/PCG/Source/PCG/Public` |
| Static Mesh Spawner: `SetMeshSelectorType` and `SetInstancePackerType` exist, plus `PostProcessFunctionNames`, `bAllowMergeDifferentDataInSameInstancedComponents` and `bWarnOnIdenticalSpawn` | `Public/Elements/PCGStaticMeshSpawner.h:56-59, 102, 110, 118` |
| Static Mesh Spawner: the ISM descriptor carries `ComponentTags` | `Public/MeshSelectors/PCGISMDescriptor.h:25` |
| Static Mesh Spawner: the descriptor carries `Mobility`, cull distances, `bCastShadow`, `bAffectDistanceFieldLighting`, `WorldPositionOffsetDisableDistance` and `ShadowCacheInvalidationBehavior` | `Source/Runtime/Engine/Public/ISMPartition/ISMComponentDescriptor.h:62-249` |
| **Custom elements in AngelScript are possible but unused.** `UPCGBlueprintBaseElement` is `Abstract, BlueprintType, Blueprintable`, with a BlueprintNativeEvent `Execute` | `Public/Elements/Blueprint/PCGBlueprintBaseElement.h:23-40` |
| The AngelScript preprocessor refuses only parents tagged `CannotDeriveAngelscript` | `AngelscriptPreprocessor.cpp:2772`, per the designs |
| A custom element would be set with `SetBlueprintElementType` | `PCGExecuteBlueprint.h:90-91` |

Custom elements are not on the critical path. An AngelScript element would not appear in the node palette, and nothing in
the repo exercises one.

### 6.2 `AMars_VineVolume`

```angelscript
class AMars_VineVolume : AActor
{
    default bReplicates = false;
    UPROPERTY(DefaultComponent, RootComponent) UBoxComponent Bounds;           // PCG self data = box shape
    default Bounds.Mobility = EComponentMobility::Static;                      // PCG ISMs re-parent to Static
    default Bounds.BoxExtent = FVector(1200, 1600, 600);
    UPROPERTY(DefaultComponent) UPCGComponent PCG;
    default PCG.GenerationTrigger = EPCGComponentGenerationTrigger::GenerateOnDemand;

    UPROPERTY(Category = "Vines") UPCGGraphInterface Graph;                    // one of the four graphs
    UPROPERTY(Category = "Vines") FMars_VineVolume_Settings Settings;          // Profile, Layout, End, Shape, Collision, Density
    UPROPERTY(Category = "Vines") FMars_VineVolume_Fringe Fringe;              // underside/skirt knobs (§6.5-6.6)
    UPROPERTY(Category = "Vines") int32 MaxActors = 48;
    // Resolved graph inputs, written by the construction script, read by single-attribute Get Actor Property nodes:
    UPROPERTY(VisibleAnywhere, AdvancedDisplay) FVector PcgGridExtents;        // = Bounds.GetScaledBoxExtent()
    UPROPERTY(VisibleAnywhere, AdvancedDisplay) FVector PcgCellSize;           // coarsened to <= 60 000 grid points
    UPROPERTY(VisibleAnywhere, AdvancedDisplay) FVector PcgPruneExtents;       // from Settings.SpacingCm and MaxActors
    UPROPERTY(VisibleAnywhere, AdvancedDisplay) float32 PcgLengthFracMin; ... PcgLengthFracMax, PcgClearanceCm,
                                                int32 PcgEndIsGround, float32 PcgFringeDensity
    UPROPERTY(VisibleAnywhere) FString Status;
    UPROPERTY(NotEditable) UPCGGraphInterface _AppliedGraph;   // GetGraph() is not a UFUNCTION (PCGComponent.h:218)

    ConstructionScript:
        Bounds NoCollision + tag Ck.Jolt.NoBake; actor tag Ck.Jolt.NoBake (the box must never hit vine traces nor bake)
        if PCG.bIsComponentPartitioned: ensure + Status "unpartition the volume" (partitioned output attaches to partition
            actors, which breaks the volume link)
        resolve the Pcg* fields; Validate (cells, spacing, clearance) -> ensure + Status on failure
        if Graph != _AppliedGraph: PCG.SetGraph(Graph); _AppliedGraph = Graph
    CallInEditor: Generate()       -> check point budget, then PCG.GenerateLocal(true)
                  Clear()          -> PCG.CleanupLocal(true)
                  ApplyToVines()   -> GetAttachedActors (Actor.h:3558-3560) -> each AMars_VinePcg: rerun
                  ReattachVines()  -> each: _ForceSolveOnce = true, rerun
                  DetachFromPcg()  -> each: AdoptVolumeSettings(); then PCG.ClearPCGLink(nullptr)
}
```

**Grid budget.** The grid makes `PointCount = Π floor(2E/C)`, plus one layer per axis where `E < C/2` (src:
`PCGCreatePointsGrid.cpp:105-140`). The construction script raises `C.xy` by `sqrt(Count/60000)` until the count is
≤ 60 000. `Status` shows the effective cell size.

**How spawned vines get their settings:**

- **Per-point values** come from Spawn Actor overrides: `$Seed → Seed`, and `LengthCm → LengthOverrideCm` (Graph B).
- **Volume-wide values** (Profile, Layout, End, Shape, Collision) come from the attach parent. `AMars_VinePcg.Resolve_Request()`
  reads `Cast<AMars_VineVolume>(GetAttachParentActor())` (a UFUNCTION, `Actor.h:3547-3548`). If there is no parent, it
  reports `AwaitingVolume`. That is the first construction run inside `SpawnActor`, before PCG attaches the actor.
- **`PullVolumeSettings()`** is `UFUNCTION(CallInEditor)`, parameter-less, and named in `PostSpawnFunctionNames`. It
  calls `Rebuild()`, which reruns the construction script in the editor or calls `DoBuild` directly in a game world.
- **Reuse.** The input hash includes the volume's settings, so after `ApplyToVines` only the vines whose inputs changed
  re-trace.

### 6.3 Graph A: `VineCurtain_Mars_PCG` (ivy curtains off rails and ledges, concept a)

Python names drop the `U` (`unreal.PCGCreatePointsGridSettings`). The builder gives every node a unique `Seed`
(`hash(graph_name + node_key)`), so two nodes of the same class never share a random stream.

| # | Node | Settings | Edges, and the attributes that flow |
|---|---|---|---|
| P1 | `PCGGetActorPropertySettings` | `actor_selector.actor_filter = SELF`, `property_name = "PcgGridExtents"` | → G1 pin `GridExtents` |
| P2 | `PCGGetActorPropertySettings` | `"PcgCellSize"` | → G1 pin `CellSize` |
| P3 | `PCGGetActorPropertySettings` | `"PcgPruneExtents"` | → N10 pin `Extents` |
| G1 | `PCGCreatePointsGridSettings` | `coordinate_space = ORIGINAL_COMPONENT`, `cull_points_outside_volume = True`, default `cell_size = (40, 40, 350)` (one layer per 3.5 m storey) | Out → N2 |
| N2 | `PCGWorldRaycastElementSettings` "Tops" | `raycast_mode = NORMALIZED_WITH_LENGTH`, `ray_direction = (0, 0, -1)`, `ray_length = 350`, `bounded` (default), query: `ignore_pcg_hits = True`, `trace_complex = True`, `actor_tag_filter = EXCLUDE`, `actor_tags_list = "Mars.NoVines"`, `keep_original_point_on_miss = False` | Out → N3 (point Z = impact normal) |
| N3 | `PCGNormalToDensitySettings` | `normal = (0, 0, 1)`, `strength = 1`, mode Set | → N4 |
| N4 | `PCGDensityFilterSettings` | `lower_bound = 0.85`, `upper_bound = 1` (top faces) | Out → N5a..d |
| N5a-d | `PCGTransformPointsSettings` | absolute offset `(±30, 0, 8)` or `(0, ±30, 8)`, absolute rotation yaw 0 / 180 / 90 / 270 | → N6a-d |
| N6a-d | `PCGWorldRaycastElementSettings` "DropProbe" | `(0, 0, -1)`, `ray_length = 150`, `get_impact = True`, `keep_original_point_on_miss = True`, `unbounded = True` | → N7a-d (`ImpactResult`) |
| N7a-d | `PCGAttributeFilteringSettings` | `ImpactResult == false` (constant threshold, boolean) | `InsideFilter` → N8 |
| N8 | `PCGMergeSettings` | four edges into `In` | → N9 `Source` |
| N9 | `PCGDifferenceSettings` | `Differences` ← `PCGDataFromActorSettings` (actors tagged `Mars.VineExclude`) | Out → N9b |
| N9b (opt-in) | `PCGAttributeFilteringSettings` on `ImpactStaticMesh` Substring | only when `Settings.KitFilter != ""` (for example `Balustrade`). Off by default, so greybox works. Needs `get_reference_to_static_mesh` on N2 (`PCGWorldData.h:175-177`) and the Substring operator (`PCGAttributeFilter.h:12-22, 271`) | → N10 |
| N10 | `PCGPointExtentsModifierSettings` | mode Set; extents ← P3 (default 90 cm, so a site every ~1.8 m) | → N11 |
| N11 | `PCGSelfPruningSettings` | `pruning_type = ALL_EQUAL`, randomized (`PCGSelfPruning.h:19-26`) | → N12 |
| N12 | `PCGSpawnActorSettings` | `template_actor_class = Mars_VinePcg`, `option = NO_MERGING`, `attach_options = ATTACHED`, `warn_on_identical_spawn = False`, overrides `[$Seed → "Seed"]`, `post_spawn_function_names = ["PullVolumeSettings"]` | → Output |

A surviving point sits 30 cm past a lip, 8 cm above the top, yawed outward. That is exactly the Curtain origin contract in
§3.4.

**Volume defaults** for this graph: `Profile = VineIvy`, `Layout = Curtain`, `End = Air`, `Shape.WidthCm = 160`,
`StrandCount 6-10`.

**Actor cap.** The volume refuses `Generate` when the grid estimate implies more than `MaxActors`, using
`rail length ÷ (2·PruneExtents)`. It raises `PcgPruneExtents` to fit, and widens `Shape.WidthCm` to match.

### 6.4 Graph B: `VineCeilingRoots_Mars_PCG` (two-ray trace-to-ground length)

1. P1, P2 as above. G1 uses `cell_size = (300, 300, 100)`; `PcgGridExtents.z` is forced to 40, so there is one layer at
   mid-height (`PCGCreatePointsGrid.cpp:130-140`).
2. `PCGTransformPointsSettings`: offset ±120 XY (seeded).
3. Raycast **up** `(0, 0, 1)`, length 3000, unbounded, then `NormalToDensity` with `normal = (0, 0, -1)`, then a density
   filter ≥ 0.6. This keeps ceilings and vault soffits.
4. `PCGSpatialNoiseSettings` (Perlin2D into density), then a density filter ≥ 0.55. This clumps the roots.
5. Extents 150, then self-pruning.
6. Second raycast **down** from the anchor: `get_distance = True`, unbounded, length 3000, `keep_original_point_on_miss = True`.
   It writes `ImpactDistance` and moves the point to the floor. `PCGCopyAttributesSettings` (`$Position → AnchorPos`)
   runs before it, and a second copy (`AnchorPos → $Position`) runs after it, which restores the anchor.
7. `PCGAttributeNoiseSettings` writes `LengthFrac`. Its value min/max pins ← `PcgLengthFracMin` / `PcgLengthFracMax`.
8. `PCGMetadataMathsSettings` (Multiply): `LengthCm = ImpactDistance × LengthFrac`.
9. `PCGTransformPointsSettings` with absolute rotation yaw U(0, 360). This resets the upside-down impact frame.
10. Spawn Actor `Mars_VinePcg` with overrides `[$Seed → Seed, LengthCm → LengthOverrideCm]`.

**Volume defaults:** `Profile = VineGiantRoot` (or ThinRoot), `Layout = Drop`. With `End = Ground` the actor ignores the
override and reaches the floor. With `End = Air` the override length applies, clamped by the clearance.

### 6.5 Graph C: `VineUnderside_Mars_PCG` (PCG-only moss strands, rootlets and cobwebs; concepts c and d)

1. P1, P2. G1 at cell 30-60 cm, one layer.
2. Raycast up, then `NormalToDensity (0, 0, -1)` with a filter ≥ 0.2, which also keeps curved arch soffits.
3. `SpatialNoise` clumps, then a density filter ← `PcgFringeDensity`.
4. Extents 20, then prune.
5. Second down ray (`get_distance`, unbounded), as in Graph B.
6. `AttributeNoise` writes `LengthFrac` [min, max].
7. `PCGSwitchSettings` on override pin `IntegerSelection` ← Get Actor Property `PcgEndIsGround`. This is the Ground / Air
   toggle in the graph, through the same single-attribute pin mechanism:
   - **Air branch:** Maths gives `LengthCm = min(ImpactDistance × LengthFrac, ImpactDistance − PcgClearanceCm)`.
   - **Ground branch:** `LengthCm = ImpactDistance`, plus a `MossPad_B` ISM at each floor contact.
8. Write `$Scale = MakeVector(w, w, LengthCm / 100)`, with `w` from `AttributeNoise` 0.7-1.4, through
   `PCGMetadataMakeVectorSettings`.
9. `AttributeNoise` writes `VarSeed`, `Dryness` and `WindWeight` (0.6-1.2).
10. `PCGStaticMeshSpawnerSettings`:
    - `set_mesh_selector_type(PCGMeshSelectorWeighted)` with `VineMossStrand_A/B/C` 0.4/0.35/0.25, or rootlets, or cobweb;
    - `set_instance_packer_type(PCGInstanceDataPackerByAttribute)` with `attribute_selectors = [VarSeed, Dryness, WindWeight, LengthCm]`;
    - ISM descriptor: `mobility = STATIC`, collision `NoCollision`, `component_tags = ["Ck.Jolt.NoBake"]`,
      `cast_shadow = False`, `affect_distance_field_lighting = False`, `instance_end_cull_distance = 3500`,
      `world_position_offset_disable_distance = 3000`;
    - `warn_on_identical_spawn = False`, `allow_merge_different_data_in_same_instanced_components = True`.

    The result is one ISM per mesh per volume.

This graph is the literal answer to "strands trace to the ground to match the length ... through PCG and custom data".

### 6.6 Graph D: `VineSkirt_Mars_PCG` (pier-base moss and dead leaves; concepts c and d)

1. G1 one layer near the floor. Raycast down, then `NormalToDensity (0, 0, 1)` ≥ 0.85, which keeps floor hits.
2. Four horizontal raycasts (±X / ±Y) from +10 cm, length 40, `get_distance`, merged. Keep the hits, then
   `PCGTransformPointsSettings` offset 5-25 cm out along the wall normal. These are points near a wall or pier base.
3. Extents 30, then prune.
4. `RandomChoice` splits the points into a moss stream and a litter stream (ratio from `Fringe.LitterShare`).
5. The moss stream goes to a Static Mesh Spawner with `MossPad_A/B` (packer `[VarSeed, MossScale, WetAdd, 0]`). The litter
   stream goes to `DeadLeaves_Pile_A/B` / `DeadLeaves_Scatter_A` (packer `[VarSeed, Dryness, WindWeight = 0.2, 100]`).
   Yaw is aligned to the wall: absolute rotation from the hit normal. Same descriptor rules as Graph C.

Optional `VineWallCreep_Mars_PCG`: one floor-band layer, then four horizontal rays, then `NormalToDensity (0, 0, 1)`
inverted ≤ 0.3, which keeps walls. Prune at 200, then Spawn Actor with `Layout = Creep`.

### 6.7 How the graphs are built (`mars_vine_ue.build_pcg_graphs()`)

1. **Create or reuse the asset.** Load the graph asset, or create it with `create_asset(name, folder, unreal.PCGGraph, None)`.
2. **Empty it in place.** `graph.remove_nodes(list(graph.get_editor_property("nodes")))`. The input and output nodes stay.
3. **Add each node.** `node, s = graph.add_node_of_type(cls)`, then set the node `Seed`, then struct round trips
   (`p = s.get_editor_property("world_query_params"); ...; s.set_editor_property("world_query_params", p)`). Attribute
   selectors are set through `unreal.PCGAttributePropertySelectorBlueprintHelpers`.
4. **Wire the edges.** `graph.add_edge(a, "Out", b, "In")`. Override pins use their property names (`GridExtents`,
   `CellSize`, `Extents`, `IntegerSelection`, value pins on `AttributeNoise`).
5. **Notify and save.** `graph.force_notification_for_editor()`, then save.
6. **Fail on bad wiring.** The builder records the log length before it starts and fails on any new
   `does not have the .* label` line, because `AddEdge` reports success on a wrong pin.

`check_pcg_graphs()` re-reads the node classes, key settings, unique seeds and edge counts per graph and prints
`VINE_PCG_OK` or `VINE_PCG_FAIL`. `place_volume(graph, box)` spawns a volume for the gym.

---

## 7. Designer workflow

1. **Hand-place a vine.** Drop `Mars_Vine` and pick Profile, Layout and End.
   - **Spline:** drag the Guide points near walls. They cling within ClingRadius and stay free elsewhere.
   - **Other layouts:** move the actor; the guide shows the solved path.
   - An unset Profile falls back, in the editor world only, to `VineIvy_Mars_DA`, and the result is kept.
2. **Live editing.**
   - A property edit or a drag end reruns the construction script once (drag is off: `SetbRunConstructionScriptOnDrag(false)`),
     and it re-traces only when the input hash changed.
   - A profile edit changes the signature, so every vine using that profile re-solves on its next construction run.
   - A mesh or material swap only re-emits.
   - `Status` shows traces, segments, instances and whether the result was solved or cached.
3. **Re-seed.** Reseed sets a new non-zero Seed. Copies with `Seed = 0` differ by position.
4. **Environment changed.** Use Reattach for one vine, `ReattachVines` for a volume, or `Mars.Vine.ReattachAll` for the
   whole level.
5. **Freeze.** The cached solve is kept even when the vine is moved. Paths are actor-local, so the vine moves rigidly.
6. **PCG rooms.**
   1. Place `Mars_VineVolume` and size its box floor to ceiling.
   2. Pick `Graph` and `Settings`, then press **Generate**.
   3. Carve out areas with `Mars.VineExclude`-tagged actors, or with the `Mars.NoVines` tag on hosts.
   4. After a settings change, use **Apply to Vines** for fitted vines, or **Generate** for fringe ISMs.
   5. Re-seed a whole room through `PCG.Seed`.
7. **Override one PCG vine.** AdoptVolumeSettings copies the volume's settings and sets `SettingsSource = Own`. A
   regeneration still owns managed actors. To keep a hand-tuned one, Alt-drag a copy, adopt it, and exclude its spot.
   `DetachFromPcg` adopts every vine and calls `ClearPCGLink`, which turns them into plain level actors.
8. **Undo.** `Solved` is an actor UPROPERTY written during the construction script, so undo restores it with its inputs.
   The rerun then hits the cache and makes zero traces. PCG generation is not undoable; use Clear and Generate.
9. **Live vs shipped.**
   - The editor is live.
   - PIE duplicates the editor world.
   - Cooked builds load the serialized construction-script components, default CPD and per-instance data.
   - Volumes are GenerateOnDemand, so PCG never runs at runtime.
   - No bake is required to ship.
10. **Optional merge** (Phase 6).
    - **Manual:** Tools > Merge Actors bakes spline deformation and expands ISMs, but loses per-instance data. That is why
      the material defaults are neutral (§4.1).
    - **Scripted:** `Mars.Vine.BakeSelected` merges a selection into one StaticMesh with GeometryScript, editor-only:
      `GeometryScript_SceneUtils.CopyMeshFromComponent`, `GeometryScript_MeshEdits.AppendMesh`,
      `GeometryScript_AssetUtils.CopyMeshToStaticMesh` in place, and `GeometryScript_NewAssetUtils.CreateNewStaticMeshAssetFromMeshLODs`
      for the first bake (src: `Plugins/Runtime/GeometryScripting/Source/GeometryScriptingCore/Public/GeometryScript/SceneUtilityFunctions.h:56, 82`;
      `MeshBasicEditFunctions.h:112, 314`; `MeshAssetFunctions.h:211, 282`;
      `GeometryScriptingEditor/Public/GeometryScript/CreateNewAssetUtilityFunctions.h:126, 188`). This needs §11 decision 1.
11. **Library path** (Phase 6, optional), for modular repeats:
    1. Fit a curtain once on a `CryptBalustrade4m_Mars_SM` in the gym.
    2. Merge-bake it into `VineCurtainBalustrade4m_A_Mars_SM`.
    3. Spread it onto every copy of the rail with `Mars.Vine.SpreadLibrary`. That command walks the kit HISMs in the open
       level (`GetInstanceCount` / `GetInstanceTransform`, UFUNCTIONs, `InstancedStaticMeshComponent.h:328, 422-424`, used by
       `Mars_HangingChain.as:206-213`) and writes instances with Data0 seeds into one HISM per library mesh.

---

## 8. Performance budget, collision and the Jolt bake

The renderer context is Lumen GI, `r.ReflectionMethod=0`, Virtual Shadow Maps on and distance fields on
(`Config/DefaultEngine.ini:56-59`). **Every number below is a target, measured in Phase 5 before any claim is made.**

| Item | Per actor | Per room (atrium) |
|---|---|---|
| Construction-script solve | typical ≤ 40 ms, worst ≤ 250 ms; ≤ 3000 traces | - |
| Emit (cached path) | ≤ 30 ms for 4000 leaves | - |
| Spline-mesh segments | ≤ 64 (GiantRoot ≈ 46: 2 × 14 main + 4 × 3 + 3 × 2 fingers) | ≤ 400 |
| HISMs | only those used: ivy 2-4, root 1-3 | - |
| Leaves | ≤ 4000 (curtain ≈ 250 × ~45 tris) | ≤ 20 000 instances, ≤ 1.5 M vine tris before culling |
| Fringe cards (PCG ISM) | - | ≤ 3000, 3 ISMs per volume |
| PCG-spawned actors | - | ≤ 48 per volume (`MaxActors`) |
| Draw calls | ivy 2-4; roots one per segment per pass until measured (spline meshes go through GPUScene and may batch) | ≤ 300 across passes |
| PCG generation | - | ≤ 60 000 grid points, ≤ 100 000 rays, ≤ 3 s per volume (on demand) |
| Hero root | 3 HISMs, ≤ 9000 tris per module | 2-4 hero roots |

**Mitigations:**

| Area | Measure |
|---|---|
| Ivy stems | Instanced chords, not spline meshes |
| Distance culling | 3500 / 5000 on leaves and cards |
| WPO | `SetWorldPositionOffsetDisableDistance(3000)` (src: `StaticMeshComponent.h:469-470`) |
| Shadows | Strands, moss, rootlets and ivy stems use `SetCastShadow(false)`. Leaves cast shadows, with `ShadowCacheInvalidationBehavior = Rigid`, so WPO stops invalidating VSM pages (src: `PrimitiveComponent.h:315-317`). On emitter-created HISMs this is set at runtime **[spike S1b]**: no setter UFUNCTION was found, and `default` reaches only default components. The fallback is leaf shadows off per profile. On PCG ISMs it is a descriptor field (`ISMComponentDescriptor.h:249`). |
| Distance fields | `SetAffectDistanceFieldLighting(false)` on spline meshes (their distance fields are undeformed) and on thin parts |
| Overdraw | None from masking: every leaf, strand and cobweb is opaque geometry, by the kit's no-texture rule |
| LOD | Nanite off; LOD1 at 50 % |

**Collision and the Jolt bake:**

- **Default: Off.** Every vine primitive is `NoCollision` and carries component and actor tag `Ck.Jolt.NoBake`. That tag
  is excluded by `CkJolt_ProjectSettings.cpp:57-59`, and NoCollision components are skipped too
  (`CkJoltBakeExtraction.cpp:201`). This is HangingChain's `ApplyPhysics`. Editing a vine never needs a static-world
  re-cook.
- **Collision On**, a per-actor option available for GiantRoot and the default for `AMars_HeroRoot`:
  - Segments use `BlockAll` with no tag. Spline meshes deform their UCX hull.
  - CkJolt bakes the per-segment body setups. **Re-cook the static world after any edit**, as HangingChain documents
    (`Mars_HangingChain.as:8-9`).
  - Collision cooks only for editor-authored spline meshes, not for spline meshes created at runtime
    (`Plugins/CkTests/Script/CkJolt/CkJoltGym_StaticBake.as:288-338`), so tests never rely on root collision.
- **Never collide:** leaves, strands, knots, PCG ISMs and the volume box.
- **PCG raycasts** query UE collision on `ECC_WorldStatic` (`PCGWorldData.h:77`), not Jolt. Vine traces use Visibility.
  Both hit the kit's BlockAll collision.

---

## 9. Verification

### 9.1 Headless autotests (`Script/Tests/Vine/`, one class per file)

**Rig.** `UCLASS(Abstract) class UMars_AutoTestRig_Vine : UCk_AutoTest_Base`. Steps use `Add_Step`, `Add_Step_WaitFrames`
and `Add_Step_WaitUntil(name, predicate, frames, seconds)` (`Plugins/CkTests/Script/Common/CkAutoTest_Base.as:252-301`).
The rig provides:

- `k_Origin = FVector(-80000, 70000, 40000) + index × 6000`, a private corner of the shared test world.
- `SpawnSlab(Center, Scale)`, copied from `Mars_AutoTestRig_PlayerCombat.SpawnBlock` (an engine cube with BlockAll,
  `Script/Tests/PlayerCombat/Mars_AutoTestRig_PlayerCombat.as:82-96`).
- `Make_Profile(Preset)`: `NewObject(this, UMars_VineProfile)` + `utils_vine::Fill_Preset`, then engine shapes only
  (Cylinder stems with `ForwardAxis = Z`, Plane cards, Cube knots).
- `SpawnVine(...)`: a deferred `SpawnActor(..., NAME_None, true)` + `FinishSpawningActor`
  (`Plugins/CkTests/Script/CkGroundNav/CkGroundNavGym_Common.as:160-169`), so the construction script runs once with the
  test's properties. A step waits for two frames so the slab bodies register, then calls `Rebuild()`.

**Staying silent under -nullrhi:**

- no CkUsf looks and no MIDs, so the headless look trap from memory cannot fire;
- engine default materials only;
- no profile or kit lookup in game worlds;
- no PCG in tests 1-14;
- validation tests call `Validate()` directly, so no ensure fires.

| # | Test | Asserts |
|---|---|---|
| 1 | `Mars_AutoTest_Vine_GroundedDropReachesAndCreepsAlongTheFloor` | Drop + Ground between slabs 1050 cm apart. The lowest stem point is within r + 2 cm of the floor top. Creep length is within ±25 % of the drawn value. Every creep point is within 3 cm of the floor. The finger count is in range. |
| 2 | `Mars_AutoTest_Vine_AirDropEndsInsideItsClearance` | Air: the lowest point lies in [floor + ClearMin − 2, floor + ClearMax + 2], and no point is below the floor. |
| 3 | `Mars_AutoTest_Vine_SplineClingsToANearWallAndStaysFreeFarFromIt` | A guide 40 cm off a wall, then 200 cm off. Near samples are at StandOff ± 3 cm from the wall plane; far samples are unchanged (≤ 1 cm). |
| 4 | `Mars_AutoTest_Vine_CurtainWrapsTheLipAndHangsEveryStrand` | K paths. Each has a point on the top, passes the face, and hangs below the ledge bottom. The lengths' standard deviation is > 5 cm. |
| 5 | `Mars_AutoTest_Vine_WrapCoilsRoundThePierAtItsStandOff` | A 60 × 60 pier. Every point is within StandOff ± 3 cm of a face. The swept angle is Turns × 360 ± 10 %. |
| 6 | `Mars_AutoTest_Vine_PatchHangsStrandsFromTheUnderside` | The count is within density × area ± 30 %. Tops are within 3 cm of the underside. Lengths are ≤ floor distance − ClearMin. |
| 7 | `Mars_AutoTest_Vine_SameSeedSameVineOtherSeedOtherVine` | Two actors with the same seed and transform give identical instance transforms and segment counts. Another seed gives different ones. |
| 8 | `Mars_AutoTest_Vine_UnchangedInputsReuseTheSolveWithoutTracing` | A second `Rebuild()` traces 0 times and produces the same geometry, even after the slab is destroyed. After `Reattach`, the trace count is > 0. |
| 9 | `Mars_AutoTest_Vine_RebuildReplacesItsComponentsInsteadOfAddingThem` | The counts of emitted components and HISM instances are equal before and after a second `Rebuild()` (the HangingChain idempotency pattern, `Mars_AutoTest_HangingChain_CatenaryLaysLinksAndSags.as`). |
| 10 | `Mars_AutoTest_Vine_ProfileValidateRejectsEachBadRange` | One case per rule: `Validate()` returns an error naming the field. Every preset passes. |
| 11 | `Mars_AutoTest_Vine_TwinStrandRootTwistsAndStaysInsideItsBudgets` | Strand centres are 0.84R ± 10 % apart. The phase advances 2π per pitch ± 10 %. Segments ≤ 64; traces ≤ 3000. |
| 12 | `Mars_AutoTest_Vine_RootFramesNeverFlipBetweenSegments` | A 3-storey vertical GiantRoot. For every adjacent segment pair, `dot(UpDir_i, UpDir_{i+1}) > 0` (≤ 90°), and > cos 30° on 95 % of pairs. Read with `GetSplineUpDir`. |
| 13 | `Mars_AutoTest_Vine_UncollidingVineCarriesTheJoltNoBakeTag` | Default: the actor and every emitted component carry `Ck.Jolt.NoBake` with NoCollision. With `Collision = On`, segments are BlockAll and untagged. |
| 14 | `Mars_AutoTest_HeroRoot_StacksModulesToTheFloor` | Engine-cylinder stand-ins with overridden module heights. Coverage from top to floor is ± 1 cm, `zScale` stays in [0.8, 1.25], and flips are deterministic per seed. An out-of-range height is rejected by `Validate()`. |
| 15 (conditional on spike S8) | `Mars_AutoTest_VineVolume_CeilingGraphSpawnsSeededVinesWithTracedLengths` | A volume with `VineCeilingRoots_Mars_PCG` (through the `assets::` accessor) over a ceiling and floor slab, then `PCG.GenerateLocal(true)`, then wait until `bGenerated`. The attached `AMars_VinePcg` count is > 0. Each `LengthOverrideCm` equals the slab gap × a fraction in [min, max] ± 2 cm. Seeds are distinct. |

**Running them:**

- **Focused:** `./CkAuto/UnrealToolbox.exe --test --no-live --test-pattern Mars_AutoTest_Vine`. This is AngelScript only,
  so no `--build`. Say which pattern produced a result.
- **Full gate:** `--test --no-live --discover-fresh` once at the end, read against `knownReds`. Never add a known-red to
  cover your own red.
- **Commit:** the regenerated `Script/Generated/*` wrappers and the `AutoTests_Mars_MAP` external actors, with explicit
  pathspecs. Never commit `Config/DefaultGameplayTags.ini`, stray `Content/` assets or `Mars.uproject`.

### 9.2 Pipeline checks and visuals

1. `build_env_vines.py --export --sheets` prints `ENV_VINES_OK` and writes iso / front / top sheets, a line-up with a 1 m
   bar, and a preset sweep.
2. `mars_vine_ue.check_pcg_graphs()` prints `VINE_PCG_OK`. `build_pcg_graphs()` fails on any LogPCG label error.
3. **Material regression.** Capture `Content/.../Dressing` props (skull pile, pipes) before and after the master edit. The
   mean absolute RGB difference must be < 1/255, which shows the data slots are neutral.
4. **`build_gym_map()`** builds `VineGym_Mars_MAP` from the kit, under the Mars light rig: warm candles and torches, cold
   moon or spirit light, manual exposure, fog backdrop, no sky light. It has four bays:
   - **(a) Atrium:** `CryptPierH11m5_Mars_SM`, `CryptBalustrade4m_Mars_SM` / `CryptGalleryEdge4m_Mars_SM` at 3.5 m and
     7 m, two `AMars_HeroRoot`, two GiantRoot Drop+Ground, a Curtain volume and two Wrap ivies.
   - **(b) Sewer:** `CryptWall4m_Mars_SM` with the env kit `Pipe_2m` and `PipeElbow90`, a Creep ivy round the pipe, and
     `VineBarkWet_Mars_MI`.
   - **(c) Cistern:** `CryptVaultRib8m_Mars_SM` / `CryptArcadeBay4m_Mars_SM`, an Underside volume (moss) and a Skirt
     volume.
   - **(d) Ossuary:** `CryptWallOssuary4m_Mars_SM`, ThinRoot Air drops, Rootlets Patch+Ground with litter, and cobwebs.
5. **`capture_review(dir)`**, run as its own call, uses `mc.capture` (`mars_cooking_ue.py:883`). It takes the shots
   `atrium_wide`, `rail_close`, `root_base`, `sewer_pipe`, `cistern_moss` and `ossuary_rootlets`, and builds A/B sheets
   against each concept.
   - It runs in the hidden editor on :9317 when Stephen's editor is busy. Saving into assets his editor has loaded goes
     through his Monolith on :9316 (memory: second-editor asset lock).
   - **Luminance check:** fewer than 60 % of the leaf-mask pixels may be below 0.02 luminance.
6. **[EDITOR-VERIFY] PIE walk.** SceneCapture renders darker than the game view, so a person checks:
   - leaf sway is subtle;
   - curtains read as long strands;
   - roots fork at both ends and never twist-flip;
   - wet bark glints only near a capture;
   - nothing pops at cull distances;
   - VSM does not shimmer.

   A look is done only once it has been seen in PIE.
7. **[EDITOR-VERIFY] PCG.** Generate in each gym volume. Expect:
   - one actor per pruned site, each attached;
   - `Status` "solved", never "waiting";
   - Clear removes them all;
   - the fringe ISMs carry 4 custom floats.
8. **Performance.** In the atrium bay, record `stat scenerendering`, `stat initviews`, an Insights trace and
   `Mars.Vine.Report`, all against §8.

---

## 10. Build order and risks

### Phases

| Phase | Work | Ends with |
|---|---|---|
| **0. Spikes** (½ day, throwaway branch) | **S1.** `USplineMeshComponent::Create` + `UHierarchicalInstancedStaticMeshComponent::Create` inside an editor-world construction script of a Static actor: renders, survives rerun, save, reload and PIE duplication, and does not accumulate. **S1b.** A runtime write of `ShadowCacheInvalidationBehavior` on a created HISM: look for a mixin or setter; otherwise accept the fallback. **S2.** A trace from a struct method in the construction script uses the actor's world (editor and game world). **S3.** `AMars_VineVolume`: box self data culls the grid; a single-attribute Get Actor Property drives the `GridExtents` / `CellSize` pins. **S4.** Spawn Actor with the AngelScript template: overrides are visible in the construction script; `PullVolumeSettings` runs; the actor is attached. **S5.** Python: `create_asset(..., None)`, struct round-trips, selector helpers, override pin labels, `remove_nodes`. **S6.** The instance packer fills 4 PICD floats on PCG ISMs. **S7.** A Switch `IntegerSelection` override from Get Actor Property. **S8.** PCG generation in a PIE autotest world is silent under -nullrhi (decides whether test 15 exists). | A pass/fail list; each fail switches to its fallback |
| **1. Core** | `Mars_Vine_Types`, `Mars_VineProfile` + Validate, solver primitives, Drop and Spline, Ground/Air, cache, emitter on engine meshes, rig, tests 1-3 and 7-10, `ReattachAll` and `Report` commands | Focused tests green |
| **2. Layouts** | Curtain, Creep, Wrap, Patch, branches and tendrils, twist, fingers and knots, leaves and cards; tests 4-6 and 11-13 | 13 tests green |
| **3. Art** | `env_spec` EnvStrand slot, `env_vines_parts.py`, `build_env_vines.py` (no hero yet), `me.import_meshes("vines")`, the master data slots + regression capture, instances, `Mars.Vine.SeedProfiles`, the gym map | `ENV_VINES_OK`, sheets, regression < 1/255, first captures |
| **4. PCG** | `Mars_VineVolume.as`, `build_pcg_graphs` / `check_pcg_graphs` for graphs A-D, gym volumes, test 15 if S8 passed | `VINE_PCG_OK` + the PCG editor checks |
| **5. Hero roots and polish** | `hero_root_module` SDF + `--only HeroRoot`, `AMars_HeroRoot` + test 14, shadows, culls, LODs, measured budgets, `VINES.md` | Atrium capture signed off in PIE; full gate green against known reds |
| **6. Optional** | `Mars.Vine.BakeSelected` (GeometryScript, after decision 1), the library path, `VineWallCreep_Mars_PCG` | Bake round-trip checked in the editor |

### Risks

| Risk | Mitigation |
|---|---|
| **R1. Components created in the construction script misbehave** (S1): lost on save, or duplicated by the instance-data cache | Spike first. Fallback for roots: rigid HISM chord segments with `VineKnot` spheres at the joints. Fallback for HISMs: fixed default HISM slots (HangingRack style). |
| **R2. The 1 s script limit or slow emit** on dense curtains | `Validate` checks worst-case budgets before solving. The cache makes load and undo trace-free. PCG caps site spacing and strands (≤ 10 per curtain actor). |
| **R3. Python PCG authoring fails silently** (wrong pins, struct fields that do not stick) | The builder log scan plus `check_pcg_graphs` re-reads every setting. Every knob reaches a graph through one verified mechanism (single-attribute override pin). Fallback: set the offending field by hand once in the asset, and have `check` verify it. |
| R4. Draw calls from many PCG actors or spline segments | `MaxActors`, wider curtains, fringe as volume ISMs, HISMs only when used, Phase 5 measurement, optional merge or library. |
| R5. Root up-vector flips on vertical drops | RMF frames + per-segment `SplineUpDir`; test 12; PIE check. |
| R6. The master edit changes existing kit props | Neutral defaults + the shader fallback (`MaterialTemplate.ush:1492`); before/after regression capture; in-place rebuild only. |
| R7. Level-load ordering collapses vines | The input-hash cache: no traces on load; explicit Reattach. |
| R8. A partitioned volume breaks the attach link | The construction script ensures on `bIsComponentPartitioned`. |
| R9. A colliding root forces a Jolt re-cook | Collision is opt-in per actor, documented, and Freeze is used after cooking. |
| R10. GeometryScripting disappears if Monolith is removed | Version 1 never needs it; the bake is optional and gated on decision 1. |
| R11. Hero module seams after decimation | Locked joint loops, symmetric noise fade, 4 cm overlap, the builder's joint-delta check. |

---

## 11. Decisions for the user

1. **Declare GeometryScripting in `Mars.uproject`?** Today it loads only because Monolith depends on it. Only the optional
   Phase 6 scripted bake needs it. *Recommendation: not now.* Version 1 ships live components. Decide when the merge bake
   is wanted, and commit it deliberately, since the rule is "never commit Mars.uproject" casually.
2. **Extend the shared `EnvPaint_Mars_M` / `EnvFoliage_Mars_M` masters in place, or build separate vine masters?**
   *Recommendation: extend in place.* Vines and the existing dressing then share one look, the defaults are provably
   neutral, and a regression capture guards it.
3. **Collision default for `AMars_HeroRoot`.** *Recommendation: On.* Players will walk into 70 cm roots, so accept a Jolt
   re-cook after edits. Keep every other profile Off.
4. **Curtains as fitted actors (cling), or cheaper library instances on modular rails?** *Recommendation: fitted actors in
   version 1*, which look right in any room. Add the library path only if Phase 5 measures the atrium over budget.

## 12. Rejected alternatives

- **ProceduralMeshComponent tube sweep:** no LOD, no instancing, and it cannot be baked from script
  (`ProceduralMeshConversion` is not a UFUNCTION).
- **DynamicMeshComponent sweep as the live mesh** (mesh-generation design): it ties the live path to GeometryScripting,
  which only loads through Monolith. It also means one bake asset per vine per map, and a vertex-buffer build in script
  under the 1 s limit.
- **PCG-native solve** (cling, ending, taper and twist as about 150 graph nodes): the cling is not surface-following, it
  rests on many unverified metadata semantics, and designers cannot debug it.
- **PCG Spline Sampler + Static Mesh Spawner for stems:** it cannot follow surfaces or express the Ground/Air ending.
- **PCG Spawn Spline Mesh for roots:** spline meshes land at identity transform with no CPD in the descriptor
  (`Private/Helpers/PCGActorHelpers.cpp:418-421`, the identity-transform note), and the descriptor can be retuned only from Python.
- **AngelScript `APCGVolume` subclass:** no precedent in the repo, and a Python-spawned volume has no brush.
- **Graph user parameters:** `AddUserParameters` is not a UFUNCTION (`PCGGraph.h:630`).
- **Custom AngelScript PCG element on the critical path:** it would be absent from the palette and unexercised. Kept as a
  fallback only, set with `SetBlueprintElementType`.
- **GPU PCG nodes:** the -nullrhi lanes cannot run them.
- **Masked card textures for leaves, moss and cobwebs:** they break the kit's no-texture style ruling and add overdraw.
  Geometry instead.
- **Rigid HISM segments for thick roots:** the kinks show at 30-80 cm. Kept only as the R1 fallback, with knots at the
  joints.
- **`bNeverNeedsCookedCollisionData` on segments:** AngelScript cannot set it on `Create()`d components
  (`SplineMeshComponent.h:404-405`).
