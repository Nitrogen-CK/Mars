# Drips, droplets, puddles and wet surfaces: final implementation plan (Mars)

Status: final synthesis of three designs (material-cards, pcg-instanced, hybrid-fx) and two judge verdicts, 2026-10-20.
Scope: the "Water droplets + puddle material" half of the request. Vines and roots are a separate plan in this folder.

Path shorthands: `UE` = `D:/Repo/UnrealEngine-Angelscript/Engine`, `PCG` = `UE/Plugins/PCG/Source/PCG`,
`AS` = `UE/Plugins/Angelscript/Source`. Every engine fact this plan relies on has a cite. I re-checked the decisive ones for
this synthesis (marked **[re-checked]**). A **[VERIFY Pn]** tag marks something source alone cannot settle. Each one names
the phase that settles it and the fallback.

---

## 0. How the three designs were merged

The two judges picked different winners: judge 1 chose pcg-instanced (62 vs 59), judge 2 chose material-cards (61 vs 57).
Summed, the scores are a tie. So this plan takes the **runtime architecture of pcg-instanced** and the **safety and sync
discipline of material-cards**:

- From pcg-instanced: one small card per drop, correct PCG raycasts, the `AMars_DripField` host, and the integer time wrap.
- From material-cards: no PCG types in AngelScript until the PCG commit is decided, one `.ush` with an exact AS mirror and a
  parity check, the two-layer DBuffer puddle, PICD read in the vertex shader, and the trace cache.
- From hybrid-fx: the grafted items (Single Layer Water cistern, frozen-time captures, Air mode, receiver-facet mask, decal
  audit).

| Contradiction between the designs | Resolution |
|---|---|
| One full-length strand card (material-cards, hybrid-fx) vs one card per drop (pcg-instanced) | **One card per drop.** A 10 m strand card shades its whole area every frame. Drop cards shade only the drop. A velocity-aligned card faces the camera, so it also fixes the cylindrical-billboard collapse when you look straight up a strand (judge 2 must-fix). The cost is a rate cap per strand (§3.3), which covers every concept rate. Faster leaks use `Stream` mode. |
| Unlit translucent with per-room Warm/Cold MIs (material-cards) vs lit (pcg-instanced, hybrid-fx) | **Lit forward translucency** (`TLM_SurfacePerPixelLighting`, `UE/Source/Runtime/Engine/Classes/Engine/EngineTypes.h:351` **[re-checked]**). Drops take torch or moon colour with no per-room MI, which is what "placed in many environments" needs. |
| Pure-gravity fall (pcg-instanced), piecewise (hybrid-fx), quadratic drag (material-cards) | **Quadratic drag with its exact closed-form inverse.** Spacing accelerates and then settles at a terminal speed. Both directions are cheap. |
| `UPCGComponent` as an AngelScript DefaultComponent (pcg-instanced, hybrid-fx) vs no PCG types in AS (material-cards) | PCG is enabled only in the uncommitted `Mars.uproject` hunk **[re-checked]: `git diff Mars.uproject` shows only `+ "PCG" Enabled`**, and the memory notes say not to commit that file. **Phase 0 asks Stephen to decide (§11, D1).** Whatever he decides, every AS file except one compiles without PCG. `UPCGComponent` lives only in `Mars_DripField.as`, and that file is written only after the hunk is committed. Until then the host is a stock `APCGVolume` with preset graphs. Both hosts run the same graph core (§6). |
| PCG raycasts on `ECC_Visibility` (material-cards, hybrid-fx) | **Wrong, and fixed.** PCG builds `FCollisionObjectQueryParams(Settings->WorldQueryParams.CollisionChannel)` and calls `SweepMultiByObjectType` (`PCG/Private/Elements/PCGWorldRaycast.cpp:263, 479` **[re-checked]**). The channel is an **object type**. Keep the default `ECC_WorldStatic` (`PCG/Public/Data/PCGWorldData.h:77` **[re-checked]**). |
| `bUnbounded` omitted | **Set `bUnbounded = true` on every raycast.** Otherwise hits outside the host bounds are dropped (`PCGWorldRaycast.cpp:238, 489` **[re-checked]**). |
| AS traces on Visibility vs object type | AS uses `System::LineTraceSingleForObjects` with `EObjectTypeQuery::WorldStatic`. The function is in `UE/Source/Runtime/Engine/Classes/Kismet/KismetSystemLibrary.h:1397` and the enum is bound in `AS/AngelscriptCode/Private/Binds/Bind_ConfigEnums.cpp:45` **[re-checked]**. PCG and hand traces therefore hit exactly the same primitives. |
| Water discriminator: actor tag (pcg-instanced, hybrid-fx) or physical material (material-cards) | **Physical material `Water_Mars_PhysMat`.** One down-ray reads it: PCG through `bGetReferenceToPhysicalMaterial` (`PCGWorldData.h:115, 220` **[re-checked]**), AS through `Hit.PhysMaterial` (the same read as `Script/Fx/Mars_SurfaceFx.as:313-319`). It also works on future kit water meshes. Actor tag `Mars.Water` is set too, for designers to read. |
| Projected puddle decal with DecalColor (hybrid-fx) vs mesh decals on ISM | **Mesh decals on ISM by default.** They batch, and they carry 4 to 8 floats. The projected `UDecalComponent` path (sync floats in `DecalColor`) is the fallback if the Phase-2 check fails. |
| `UPCGMergeSettings` dynamic pins | **Correction to judge 1's must-fix:** no extra pins are needed. Merge's static `In` pin is built with `FPCGPinProperties(DefaultInputLabel, Point)`. That constructor defaults `bInAllowMultipleConnections = true` (`PCG/Public/PCGPin.h:50-55` **[re-checked]**). The element gathers every data item on its node-defined pins (`PCG/Private/Elements/PCGMergeElement.cpp:66-68`). So all sources connect to `In`. Adding pins (`OnUserAddDynamicInputPin`) is editor C++ only, not a UFUNCTION (`PCG/Public/PCGSettingsWithDynamicInputs.h:27`), so the builder does not depend on it. |
| Python dotted selectors (`ImpactNormal.Z`) said to be impossible (material-cards) | They are possible: `selector.import_text("PCGBegin(ImpactNormal.Z)PCGEnd")`. See `UE/Plugins/Experimental/PythonScriptPlugin/Source/PythonScriptPlugin/Private/PyWrapperStruct.cpp:1283` and `PCG/Private/Metadata/PCGAttributePropertySelector.cpp:24-25` **[re-checked]**. The builder asserts each selector's read-back. |
| A `constants_drip` namespace (hybrid-fx) | Not allowed (CLAUDE.md: only `utils_<feature>` namespaces). Slot indices are **enums** (`EMars_DripSlot` and so on), cast to `int32` at the write. |
| StillWater CPD written with the runtime setter (pcg-instanced) | Use `SetDefaultCustomPrimitiveDataFloat` (`UE/Source/Runtime/Engine/Classes/Components/PrimitiveComponent.h:1195` **[re-checked]**). The runtime setter "doesn't serialize" (:1136-1138 **[re-checked]**). |
| Time wrap | The Time node gets **both** `bOverride_Period = true` and `Period = 3600` (`UE/Source/Runtime/Engine/Public/Materials/MaterialExpressionTime.h:23-28` **[re-checked]**). The builder asserts both. |
| Shared HLSL by string concatenation (hybrid-fx) | Custom node `IncludeFilePaths` (`UE/Source/Runtime/Engine/Public/Materials/MaterialExpressionCustom.h:86` **[re-checked]**) with `/Project/...`, which maps to `Mars/Shaders` (`UE/Source/Runtime/Launch/Private/LaunchEngineLoop.cpp:2517` **[re-checked]**). This is how `Shaders/Looks/*.ush` already work. |
| PCG generation inside headless AutoTests | **Not by default.** PCG is checked by editor Python (`verify()`, a generate-and-count check). One gated headless test is added only after the Phase-5 spike proves a game-world `GenerateLocal` is warning-free under `-nullrhi` **and** PCG is committed (§9.1). |
| Niagara hero emitters (hybrid-fx) | **Not built.** The user asked for cards, material, PCG and custom data. The per-drop velocity-aligned card already reads from below, which was Niagara's main argument. See §12. |

---

## 1. Summary

**Approach.** Every moving part (a bead swelling at its source, a drop detaching and falling faster and faster, the splash,
the rings on the puddle or water, ambient rain rings) is **closed-form shader maths of game time**. It is evaluated by one
HLSL library, `Shaders/Water/MarsDrip.ush`.

- A strand's layout is baked: which points drip, and how far each falls.
- Layout comes from the PCG graph or from the `AMars_DripLeak` construction script. Each one traces up to the ceiling and
  down to the floor or water.
- Layout reaches the materials as **per-instance custom data** on ISMs.
- Each strand is **6 tiny cards at its impact point**: 4 falling-drop/splash slots, 1 bead slot, 1 thread slot. The vertex
  shader moves each card to wherever its drop is right now.
- The ring decal under the strand reads **the same 5 sync floats** and runs **the same schedule**. A ring therefore starts
  on the frame its drop vanishes, with nothing ticking and nothing communicating.
- Puddles are two mesh-decal layers: wet darkening, and a separate gloss layer pushed below the reflection-capture fade
  band.
- Still water is opaque (basin) or Single Layer Water (cistern).
- Wet wall streaks are projected decals, parameterised through `DecalColor`.

| Request (verbatim) | Feature that answers it |
|---|---|
| "Water droplets + puddle material. The droplets can be a single card with a material showing a dropplet." | `Droplet_Mars_M` on `DropletCard_Mars_SM` (one quad). A teardrop SDF with a pseudo-sphere normal, lit specular glints, a rim, and a fake inverted-lens refraction from `SceneColor`. The same card is a static bead on a surface (`HangingBead` / `SittingBead`, Rate 0), a falling drop, the swelling bead at a source, a trickle thread, and the splash. The puddle is `PuddleWet_Mars_M` + `PuddleGloss_Mars_M` (§5.3). |
| "The strands might have to trace to the ground to match the length" | PCG down-raycast `ImpactDistance` (`PCG/Public/Helpers/PCGWorldQueryHelpers.h:39` **[re-checked]**), or `AMars_DripLeak`'s `LineTraceSingleForObjects`, goes into PICD slot 0. The card pivot is the impact point and the source is `Length` above it, so drops end exactly at the hit. |
| "(could be driven through PCG and custom data as well)" | `UPCGInstanceDataPackerByAttribute.AttributeSelectors` (`PCG/Public/InstanceDataPackers/PCGInstanceDataPackerByAttribute.h:27` **[re-checked]**) packs 8 attributes into PICD. The same material falls back to Custom Primitive Data on a plain component (§4.2). |
| "Vine/Roots ... toggle wrapping to ground vs staying in air" (the drip-side equivalent) | Strand **Air mode**: a negative packed length means no impact; drops fade over the last 25 % of the fall, into darkness or a void. Other drip modes: `Drops`, `DropsWithThread` (pipe joint), `Stream` (trickle), `HangingBead`, `SittingBead` (condensation). |
| "can be placed in many environments, have a bit of breakup" | No textures and no per-room assets. Lit drops take any room's light. Everything is seeded per instance and anchored in world space: log-uniform rates, ±45 % release jitter, skipped drops, ±20 % drop size, lobed and faceted puddle SDFs, world-noise dry islands, rain cells. Plus PCG spatial-noise clustering and the host `Seed`. |
| Concept (b) sewer pipe | `AMars_DripLeak` (preset `PipeTrickle`, attached to `PipeSpout_A`'s `SOCKET_Drip`, `Tools/Blender/mars_environment/ENV_KIT.md:72`). Its `WetStreak` decal (rust MI) runs down the wall. `AMars_StillWater` is attached to `StoneBasin_A`'s `SOCKET_Water` (`ENV_KIT.md:74`). Puddles on the flagstones. |
| Concept (c) flooded cistern | A field or volume with the Cistern preset: drips along `SourceLine` splines under the ribs, irregular accelerating spacing, rings on `StillWater` (SLW cistern MI, moss-dark absorption). |
| Concept (d) ossuary | `Ossuary` preset: sparse slow seeps (0.08-0.2 /s), small puddles, damp streaks. |

**Why material-first and not Niagara or simulation.** Mars has no sky light, `r.ReflectionMethod=0`, manual exposure, and no
AA (`Config/DefaultEngine.ini:56-61` **[re-checked]**). What sells water here is:

- point-light speculars;
- capture shine at roughness below 0.1;
- motion.

Shader motion costs no ticks and no actors, and it is deterministic. The same seed gives the same drips, and ring sync is
exact. Hundreds of drips in a cistern are 4 instanced draws per field.

**No C++, no editor rebuild.** The system is AngelScript, editor Python, `.ush` files, plain-Python reference tools and
assets. **No Blender generator is needed:** every card is a duplicate of `/Engine/BasicShapes/Plane`, because the vertex
shader places each vertex from its UV (§12).

---

## 2. Architecture

### 2.1 AngelScript (`Script/WorldObjects/Dressing/Water/`, plain `AActor` dressing, not ECS: visual composition only, like `Mars_HangingChain.as`)

| File | Contents |
|---|---|
| `Mars_DripTypes.as` | **Enums:** `EMars_DripMode { Drops, DropsWithThread, Stream, HangingBead, SittingBead }`; `EMars_DripSurface { Floor, Water, Dry, Air }`; `EMars_DripSlot { Drop0, Drop1, Drop2, Drop3, Bead, Thread }`; `EMars_DripCardData { Length, Rate, Seed, Jitter, Mode, Slot, DropScale, Surface, Count }`; `EMars_DripRingData { Length, Rate, Seed, Jitter, Mode, RingAmp, Count }`; `EMars_PuddleData { Seed, Wetness, RainRate, Aspect, Count }`; `EMars_StillWaterData { SizeX, SizeY, Seed, Murk, RainRate, Count }`; `EMars_DripLayout { Single, Line, Cluster }`; `EMars_DripPreset { CisternDrip, VaultLine, PipeJoint, PipeTrickle, OssuarySeep, Beads, Custom }`; `EMars_DripTraceMode { Live, Locked }`; `EMars_DripTraceState { Hit, MissedKeptCached, MissedNoCache, Air, Locked }`. **Structs** (each at most 7 fields): `FMars_DripTiming`, `FMars_DripLook`, `FMars_DripImpact`, `FMars_DripTrace`, `FMars_DripStreak`, `FMars_DripStrandRecord`, `FMars_DripStrandHit` (§4.4). |
| `Mars_DripSchedule.as` | `struct FMars_DripSchedule`, the exact mirror of the schedule half of `MarsDrip.ush` (§3.2). Used by tests, by the `AMars_DripLeak` readouts (`EffectiveRate`, `FallSeconds`) and by any later drip audio. |
| `Mars_DripLeak.as` | `AMars_DripLeak`: the hand-placed hero leak, vault line, cluster, pipe trickle or bead patch. Components: `SceneRoot`; ISMs `Drops`, `Rings`, `PuddleWet`, `PuddleGloss`; `UDecalComponent Streak`. |
| `Mars_Puddle.as` | `AMars_Puddle`: a loose puddle cluster with no drip (rain rings optional); projects each puddle down. |
| `Mars_StillWater.as` | `AMars_StillWater`: a plane `UStaticMeshComponent Surface` + `UBoxComponent Probe` (query-only WorldStatic) + CPD + phys mat + tags. |
| `Mars_WetStreak.as` | `AMars_WetStreak`: a hand-placed damp or rust streak (`UDecalComponent`); traces wall then floor. |
| `Mars_DripSource.as` | *(Phase 5b, optional)* `AMars_DripSource`: a PCG marker at a joint. Editor-only billboard; writes `Name:Value` tags (`MarsDripSource`, `DripRate:x`, `DripMode:n`, `DripSeed:s`). No PCG types. |
| `Mars_DripField.as` | *(written only after decision D1 = commit the PCG hunk)* `AMars_DripField`: Box `Bounds`, Spline `SourceLine`, `UPCGComponent PCG`; contract structs `FMars_DripField_PcgGrid`, `FMars_DripField_PcgDrips`, `FMars_DripField_PcgPuddles`. **The only file that names a PCG type.** |
| `Script/Tests/Drips/*.as` | §9.1 (one class per file). |

Conventions held:
- No `b` prefix on bools.
- At most 3 parameters per function; inputs packed into structs of about 7 fields or fewer.
- `float32(...)` casts at every `SetCustomDataValue`.
- No logging in construction scripts (logs fail autotests).
- Every primitive is NoCollision with the `Ck.Jolt.NoBake` component and actor tag (the `Mars_HangingChain.as:184, 276`
  pattern **[re-checked]**), except the StillWater probe (§8).

### 2.2 Shaders (`Shaders/Water/`, virtual `/Project/Water/...`)

| File | Contents |
|---|---|
| `MarsDrip.ush` | `#pragma once`. Constants (`#define MARS_DRIP_*`), integer hash, the slot clock, drag fall and its inverse, release/skip/impact times, slot resolve, bead growth, thread profile, ring candidates and the ring slope field, rain cells. Pure functions, no `Parameters`. |
| `MarsWet.ush` | `#include "/Project/Water/MarsDrip.ush"`. Value noise and fbm, drop SDF and pseudo-normal, splash crown and Worthington jet, faceted puddle SDF and halo, receiver-facet mask, wet streak, still-water swell, shallows/scum. |

### 2.3 Python tools (`Tools/Blender/mars_water/`; the folder name follows `mars_cooking` / `mars_environment`)

| File | Kind | Role |
|---|---|---|
| `water_spec.py` | plain Python | Single source of truth: asset names and paths, folder constants, slot-name orders (must equal the AS enums and the packer orders), presets (§3.7). |
| `drip_reference.py` | plain Python 3 (`python -I`) | Reference implementation of the schedule, with uint32 maths masked. Emits the golden table pasted into the AS test, the frozen-time predictions for captures, and space-time PNG sheets (time against depth) for tuning. |
| `check_drip_parity.py` | plain Python 3 | Parses the `#define MARS_DRIP_*` values in `MarsDrip.ush`, the `const` mirror values in `Mars_DripSchedule.as`, the AS slot enums and the `water_spec` packer orders. Fails on any mismatch. Run before every AS test run and at commit. |
| `unreal/mars_water_ue.py` | editor Python over Monolith (driven by `Tools/Blender/mars_environment/unreal/env_drive.py --module mars_water_ue --alias mw --call "mw.run_all()"`) | `build_meshes()` (duplicates Plane, bounds extensions, removes collision), `build_physmat()`, `build_masters()` (**in place**), `build_instances()`, `audit_decal_response()`, `verify_materials()`. Reuses `mars_cooking_ue` (`_asset` :73, `_tools` :77, `_Graph` :266, `capture` :883 **[re-checked]**) and the in-place `_master()` loop in `mars_candle_ue.py:154-163` **[re-checked]**. |
| `unreal/mars_water_pcg.py` | editor Python | `build_graph(preset, host)` for the 4 volume presets and the field graph; `verify(graph)`; `place_volume(bounds, preset)`; `audit_pcg_hosts()`. |
| `unreal/mars_water_review.py` | out-of-editor driver + hidden editor (`--launch --port 9317`), same pattern as `mars_cook_parity.py` | Builds `WaterLookdev_Mars_MAP`; frozen-time contact sheets; automated timing-parity and ring-sync probes; perf capture. |
| `README.md` | doc | Pipeline, slot contract, presets, wet-room lighting rules, traps. |

Note: `Tools/Blender/mars_environment/` (`env_drive.py`, `env_spec.py`, `ENV_KIT.md`) is untracked in the current tree
(`git status`). It must be committed before `mars_water_ue` depends on `env_drive.py`. If it isn't, run `mars_water_ue`
through the same Monolith RPC call `env_drive.py` makes.

### 2.4 Assets (under `/Game/Mars/Environment/Dressing/Water/`; `env_spec.UE_ROOT` is `/Game/Mars/Environment/Dressing`, `env_spec.py:30` **[re-checked]**)

| Asset | Kind | Notes |
|---|---|---|
| `Meshes/DropletCard_Mars_SM` | static mesh | Duplicate of the engine Plane (100×100 cm in XY, UV0 0..1). `PositiveBoundsExtension (0,0,100)` and `NegativeBoundsExtension (0,0,25)` (`UE/Source/Runtime/Engine/Classes/Engine/StaticMesh.h:1488-1518`). Collision removed (`StaticMeshEditorSubsystem.remove_collisions`). Nanite off. The vertex shader ignores the local geometry. |
| `Meshes/WetDecalCard_Mars_SM` | static mesh | Duplicate of the Plane, collision removed. Shared by the Rings, PuddleWet and PuddleGloss layers. Each layer has its own MI, so PCG never sees an identical mesh+material pair. |
| `Meshes/StillWater_Mars_SM` | static mesh | Duplicate of the Plane, collision removed (the probe box collides instead). |
| `Materials/Droplet_Mars_M` + `Droplet_Mars_MI`, `DropletRust_Mars_MI`, `DropletMurk_Mars_MI` | material | §5.1 |
| `Materials/DripImpact_Mars_M` + `DripImpact_Mars_MI` | material (mesh decal) | §5.2 |
| `Materials/PuddleWet_Mars_M` + `PuddleWet_Mars_MI`, `PuddleWetSewer_Mars_MI` | material (mesh decal) | §5.3 |
| `Materials/PuddleGloss_Mars_M` + `PuddleGloss_Mars_MI`, `PuddleGlossRain_Mars_MI` | material (mesh decal) | §5.3 |
| `Materials/WetStreak_Mars_M` + `WetStreakDamp_Mars_MI`, `WetStreakRust_Mars_MI` | material (projected decal) | §5.4 |
| `Materials/StillWater_Mars_M` + `StillWaterBasin_Mars_MI` | material (opaque) | §5.5 |
| `Materials/StillWaterDeep_Mars_M` + `StillWaterCistern_Mars_MI` | material (Single Layer Water) | §5.5 |
| `PCG/DripVolume_Cistern_Mars_PCG`, `DripVolume_Sewer_Mars_PCG`, `DripVolume_Ossuary_Mars_PCG`, `DripVolume_Atrium_Mars_PCG` | PCG graphs (volume host) | §6 |
| `PCG/DripField_Mars_PCG` | PCG graph (field host, after D1) | §6 |
| `/Game/Mars/Physics/Water_Mars_PhysMat` | physical material | Duplicate of `Mud_Mars_PhysMat` (the folder holds `*_Mars_PhysMat`, `Content/Mars/Physics/` **[re-checked]**). |
| `/Game/Mars/Maps/WaterLookdev_Mars_MAP` | map | Three bays from the crypt kit: 10.5 m vault over flagstones, sewer pipe wall + basin, cistern with still water. |

`_Mars_PCG` is a new suffix (Mars has no PCG asset yet). It is listed for review in §11.

Saving writes `.ckexport` sidecars through the CkAssetExporter save hook; commit them with each asset.
`Script/Generated/MarsAssets.as` (`namespace assets::load` at :1311 **[re-checked]**) gains the accessors
`assets::load::DropletCard_Mars_SM()` and so on. Commit generated files together with their assets.

---

## 3. Algorithms

### 3.1 Shared constants (`MarsDrip.ush`, mirrored in `Mars_DripSchedule.as`, diffed by `check_drip_parity.py`)

| Constant | Value | Meaning |
|---|---|---|
| `MARS_DRIP_GRAVITY` | 980 cm/s² | |
| `MARS_DRIP_TERMINAL` | 750 cm/s | quadratic-drag terminal speed (stylised; real drops are about 900) |
| `MARS_DRIP_MAX_JITTER` | 0.45 | × period; below 0.5, releases stay ordered |
| `MARS_DRIP_SKIP_PER_JITTER` | 0.25 | skip probability = 0.25 × Jitter (12 % at the 0.5 default; a full rhythmic stop happens about 1.6 % of the time at Jitter 1) |
| `MARS_DRIP_SLOTS` | 4 | falling-drop/splash cards per strand |
| `MARS_DRIP_WRAP` | 3600 s | Time node `bOverride_Period = true`, `Period = 3600` |
| `MARS_DRIP_SPLASH_S` | 0.16 s | a slot shows the splash this long after impact |
| `MARS_DRIP_RING_SPEED` | 22 cm/s | the minimum phase speed of capillary-gravity waves |
| `MARS_DRIP_RING_LIFE` | 1.4 s | |
| `MARS_DRIP_RING_LAMBDA` | 2.4 cm | |

### 3.2 The clock (one copy, HLSL; the AS mirror is line-for-line)

```hlsl
#pragma once
struct FMarsDrip   { float Length; float Rate; float Seed; float Jitter; float Mode; };   // PICD/CPD 0..4 on every consumer
struct FMarsClock  { float P; int N; float Y0; float TFall; uint Key; bool Impact; };

uint MarsDrip_Hash(uint X) { X ^= X >> 16; X *= 0x7feb352du; X ^= X >> 15; X *= 0x846ca68bu; X ^= X >> 16; return X; }
float MarsDrip_Rand(FMarsClock C, int K, uint Salt)                  // [0,1); K wraps with the period
{   uint k = (uint)(((K % C.N) + C.N) % C.N);
    return float(MarsDrip_Hash(k * 2654435761u ^ C.Key ^ MarsDrip_Hash(Salt))) * (1.0 / 4294967296.0); }

// Quadratic drag from rest: y = vT^2/g ln cosh(g a / vT). Written overflow-free; AgeAt is the exact inverse.
float MarsDrip_DistanceAt(float A) { float X = MARS_DRIP_GRAVITY * max(A, 0) / MARS_DRIP_TERMINAL;
    return (MARS_DRIP_TERMINAL * MARS_DRIP_TERMINAL / MARS_DRIP_GRAVITY) * (X + log(0.5 + 0.5 * exp(-2 * X))); }
float MarsDrip_SpeedAt(float A)    { return MARS_DRIP_TERMINAL * tanh(MARS_DRIP_GRAVITY * A / MARS_DRIP_TERMINAL); }
float MarsDrip_AgeAt(float Y)      { float C = exp(MARS_DRIP_GRAVITY * max(Y, 0) / (MARS_DRIP_TERMINAL * MARS_DRIP_TERMINAL));
    return (MARS_DRIP_TERMINAL / MARS_DRIP_GRAVITY) * log(C + sqrt(C * C - 1)); }

FMarsClock MarsDrip_Clock(FMarsDrip D, float DropRadius)
{   FMarsClock C;  C.Impact = D.Length > 0;  float L = abs(D.Length);
    C.Key   = MarsDrip_Hash(uint(D.Seed * 16777215.0));
    C.Y0    = (D.Mode > 0.5 && D.Mode < 1.5) ? min(14 + 30 * frac(D.Seed * 7.13), 0.5 * L)   // thread tip (DropsWithThread)
                                             : 1.6 * DropRadius;                               // bead centre at detach
    C.TFall = MarsDrip_AgeAt(max(L - C.Y0 - DropRadius, 1));
    float Busy = C.TFall + MARS_DRIP_SPLASH_S;
    float P1 = max(1.0 / max(D.Rate, 1e-3), Busy / (MARS_DRIP_SLOTS - 2 * MARS_DRIP_MAX_JITTER));  // slots never overlap
    C.N = MARS_DRIP_SLOTS * max(1, (int)floor(MARS_DRIP_WRAP / (P1 * MARS_DRIP_SLOTS)));
    C.P = MARS_DRIP_WRAP / C.N;                                      // divides the wrap: seamless at T = 3600 -> 0
    return C; }

float MarsDrip_Release(FMarsDrip D, FMarsClock C, int K)
{ return (K + D.Seed + saturate(D.Jitter) * MARS_DRIP_MAX_JITTER * (2 * MarsDrip_Rand(C, K, 0) - 1)) * C.P; }
bool  MarsDrip_Skipped(FMarsDrip D, FMarsClock C, int K)
{ return MarsDrip_Rand(C, K, 1) < MARS_DRIP_SKIP_PER_JITTER * saturate(D.Jitter); }
float MarsDrip_Impact(FMarsDrip D, FMarsClock C, int K) { return MarsDrip_Release(D, C, K) + C.TFall; }
```

Properties the tests pin (§9.1):

- **Ordered releases.** Consecutive releases differ by at least `P(1 − 0.9·Jitter) > 0`.
- **Mean interval** is `P`, which is `1/Rate` unless the slot cap applies.
- **Irregular spacing**, from jitter and skips.
- **Accelerating spacing.** In-flight drops are points on one curve `y = Y0 + DistanceAt(age)`. Two drops `Δt` apart sit
  `≈ SpeedAt(age)·Δt` apart, so they spread out as they fall, up to terminal speed.
- **Slots never overlap.** Drop k on slot `k mod 4` ends by `Release(k) + Busy`, and drop `k + 4` releases at least
  `(4 − 0.9)·P ≥ Busy` later.
- **Seamless wrap.** N is a multiple of 4 and the hash index is `k mod N`. At `T = 3600 → 0`, drop −1 is drop N−1 shifted by
  exactly 3600 s. Float time stays below 3600, so its precision is about 0.24 ms.

**Fall times and rate cap** (DropRadius 0.45, `Y0 ≈ 0.7`):

| Fall | `TFall` | Max rate per strand |
|---|---|---|
| 1 m (pipe into basin) | 0.46 s | ≈ 5 /s |
| 3.5 m (one storey) | 0.93 s | ≈ 2.8 /s |
| 10.5 m (three storeys) | 1.92 s | ≈ 1.5 /s |
| 12 m (atrium) | 2.13 s | ≈ 1.35 /s |

Every concept rate (cistern 0.25-0.9, vault lines 0.3-1.0, pipe joint 1.5-2.5 over about 1 m) fits under the cap. Above the
cap, the clamp lowers the effective rate. `AMars_DripLeak` shows `EffectiveRate` in its readout, and presets for fast leaks
use `Stream`.

### 3.3 Card roles (vertex shader of `Droplet_Mars_M`; slot = PICD 5)

Common: `T = DebugTime >= 0 ? DebugTime : Time` (Time node with wrap). `D` = PICD 0..4. `C = MarsDrip_Clock(D, R)`.
`R = DropRadiusCm · DropScale`.

**Drop slots s = 0..3.**

```
m  = floor(T / C.P - D.Seed)                      // the newest nominal index
k0 = m - ((m - s) mod 4 + 4) mod 4                // the newest index on slot s with k0 <= m
k  = Release(k0 + 4) <= T ? k0 + 4 : (Release(k0) <= T ? k0 : k0 - 4)    // jitter can pull k0+4 early
if Skipped(k) or Mode >= 2 (Stream / beads) : collapse (all 4 vertices to the pivot: 0 pixels)
a  = T - Release(k)
if a < C.TFall:   falling. Centre y = C.Y0 + DistanceAt(a) below the source, v = SpeedAt(a)
elif a < C.TFall + SPLASH_S and C.Impact and Surface != Dry-without-splash: splash phase at the impact (§3.5)
else: collapse
Air (Length < 0): no splash; alpha *= 1 - smoothstep(0.75 L, L, y)
```

**Bead slot s = 4.**
- `Kn` is the next non-skipped release after T, searched over 3 steps. `Kp` is the previous one.
- Growth `g = saturate((T − Release(Kp) − 0.05) / (Release(Kn) − Release(Kp) − 0.05))`. Volume grows linearly, so the radius
  is `Rb = R·(0.35 + 0.65·g^(1/3))`.
- Sag `e = 1 + 0.6·smoothstep(0.7, 1, g)`. The bead hangs at `C.Y0`, which is where the next drop starts, so a drop never
  jumps at detach.
- If the search hits 3 skips, `g = 1` (a full bead waiting: a natural pause).
- `HangingBead` / `Rate == 0`: `g = 0.75 + 0.05·sin(0.7T + 40·Seed)` (breathing).
- `SittingBead`: a dome above y = 0 (half-ellipse, height 0.7Rb), card normal-aligned, no fall.

**Thread slot s = 5** (Mode 1 or 2; collapsed otherwise).
- The card runs from the source to `C.Y0` (Mode 1) or to `|L|` (Mode 2 = Stream).
- Width has constant flux: `w(y) = ThreadWidthCm·(1 + 2g·y/v0²)^(−1/4)`, with `v0 = 30 cm/s`.
- Mode 2: below `ThreadBreakCm·(0.85 + 0.15·sin(7.1T + 40·Seed))`, the thread breaks into a Rayleigh-Plateau bead lattice
  in departure time (`τ = T − AgeAt(y)`, `φ = frac(9τ + Seed)`).
- Highlight bands travel down at `SpeedAt(AgeAt(y))`.
- Stream splashes pulse at the nominal rate from slot 0's schedule.

**Velocity-aligned camera-facing billboard** (every drop and the splash):

```
F    = normalize(CameraPositionWS - Centre)
Up   = normalize(Vdir - dot(Vdir, F) F)    Vdir = (0,0,-1); fall back to camera up when |.| < 1e-3 (looking straight up)
Rt   = cross(Up, F)
pxCm = Dist * 2 * TanHalfFov / ViewSizeY                      (ViewProperty: TanHalfFieldOfView, ViewSize)
W    = max(2 Rk, MinPixels * pxCm);  Hraw = 2 Rk (1 + TearK saturate(v/400)) + v * Shutter;  H = max(Hraw, MinPixels * pxCm)
Alpha = clamp((2 Rk * Hraw) / (W * H), 0.35, 1)                 energy kept when clamped (no TAA: r.AntiAliasingMethod=0)
Vertex = Centre + Rt (u - 0.5) W + Up (0.5 - v) H;   WPO = Vertex - WorldPosition (excluding offsets)
Rk = R (0.8 + 0.4 Rand(C, k, 2))                                per-drop size
```

The thread card is cylindrical about world Z (it is a vertical line), widened to at least 1.5 px. When looking up a thread
(`|CameraVector.z| > 0.9`), it fades to 0.

Defaults: `R = 0.45 cm`, `TearK = 1.6`, `Shutter = 1/90 s`, `MinPixels = 1.5`. At 6 m of fall (`v ≈ 690 cm/s`), the streak is
about 9 cm.

Varyings to the pixel shader: two `UMaterialExpressionVertexInterpolator` float4s, `I0 = (W, H, Rk, Alpha)` and
`I1 = (Role, Speed, Seed, pxCm)`. All PICD is read in the VS (§4.2).

### 3.4 Drop and bead pixel shading (`MarsWet.ush`)

Card space `q = ((u − 0.5)·W, (0.5 − v)·H)` cm.

```hlsl
float MarsWet_DropSdf(float2 q, float r, float tail, float H)   // round head leading (down), tapered tail up
{   float2 c = q - float2(0, -0.5 * H + r);
    float k = c.y > 0 ? 1 + tail : 1;
    float2 e = float2(c.x * (1 + 0.35 * saturate(c.y / (r * k))), c.y / k);
    return length(e) - r; }
mask = saturate(0.5 - d / pxCm);                                // analytic AA
n    = float3(e / r, sqrt(saturate(1 - dot(e / r, e / r))));    // pseudo-sphere normal
NormalWS = Rt * n.x + Up * n.y + F * n.z                        // world-space normal (TangentSpaceNormal off: WPO moves tangents)
RefractUV = ScreenUV - n.xy * RefractPx * InvViewSize           // inverted lens
Emissive  = SceneColor(RefractUV) * Transmission * WaterTint * mask      // fake refraction (static switch, default on)
BaseColor = BodyTint (0.02, 0.025, 0.03); Roughness 0.05; Specular 0.5 (stylised sparkle)
Opacity   = mask * Alpha * lerp(0.92, 0.6, n.z)                 // denser rim
```

Torches and candles give real glints through the forward light loop. Reflection captures reach forward translucency
through the image-based reflection path (`ForwardLightingCommon.ush:566`, cited by hybrid-fx). With the switch off, the
emissive is a 2-tone body gradient instead.

`SceneColor` is Surface-domain and pixel-only, with an OffsetFraction/Coordinates input
(`UE/Source/Runtime/Engine/Public/Materials/MaterialExpressionSceneColor.h:31-47`). It forces a scene-colour copy while any
drop is visible (§8).

### 3.5 Splash (a phase of drop slots 0..3)

`u = (a − TFall) / SPLASH_S`, in [0, 1].

- **Floor:** a 9-spike crown SDF. Radius 1→4 cm, height up to 3 cm then collapsing. Three crown droplets of 0.22 cm,
  ballistic: `h = v0·t − ½g·t²` with `v0 = 70 ± 25 cm/s` and lateral ±(10..25) cm/s from the hash.
- **Water (`Surface = 1`):** a Worthington jet droplet: `y = 6·4u(1 − u)` cm over 0.28 s. The slot's busy time extends to
  0.28 s on water: `SPLASH_S` is the maximum of the two and the clock uses it.
- **Dry slope (`Surface = 2`):** a smaller crown, and no ring (RingAmp 0).

### 3.6 Impact rings (pixel shader of the `DripImpact_Mars_M` mesh decal)

The decal sits at the impact, scaled to 60 cm. Puddle-local `p` (cm) = `(UV − 0.5) · 100 · InstanceScaleXY`, and `r = |p|`.

```hlsl
FMarsClock C = MarsDrip_Clock(D, R);  if (!C.Impact || RingAmp <= 0) return (flat, opacity 0);
// Constant-cost inversion: the crest at radius r belongs to the drop that landed r/RING_SPEED ago.
int K0 = (int)floor((T - C.TFall - r / MARS_DRIP_RING_SPEED) / C.P - D.Seed);
for (int i = -1; i <= 1; ++i) {                                 // 3 candidates cover +/-0.45 jitter
    int K = K0 + i;  if (MarsDrip_Skipped(D, C, K)) continue;
    float age = T - MarsDrip_Impact(D, C, K);  if (age <= 0 || age > MARS_DRIP_RING_LIFE) continue;
    float u   = r - MARS_DRIP_RING_SPEED * age;
    float env = exp(-u*u / (W*W)) * exp(-age / Decay) * saturate(20 * age) / (1 + 0.08 * r);
    float k2  = 6.2831853 / MARS_DRIP_RING_LAMBDA;
    G += RingAmp * env * (-k2 * sin(k2 * u) - (2 * u / (W*W)) * cos(k2 * u)) * (p / max(r, 1e-3));
    if (age < 0.12) G += Dimple * saturate(1 - r / 2) * (p / max(r, 1e-3)); }
Normal = normalize(float3(-G, 1));  Opacity = saturate(length(G) * RingAlphaGain);  Roughness 0.03; Specular 0.3
// Mode == Stream: + a steady noisy disturbance within 3 cm of the centre.
```

Outputs are Normal, Roughness, Specular and Opacity only, with no BaseColor. So the rings never touch the puddle's
darkening, and on still water they only perturb the surface. Cost is flat in drip rate (3 candidates).

### 3.7 Surface attachment and length tracing

**`AMars_DripLeak::Rebuild()`**, called from `ConstructionScript`:

1. **Resolve assets.** Generated accessors for committed assets (`assets::load::DropletCard_Mars_SM()` and so on). These
   cannot fail and log. Any optional kit lookup uses the `Mars_HangingChain.as:242` guard **[re-checked]**: editor world
   only, plus `EditorAsset::DoesAssetExist`.
2. **ApplyPhysics.** NoCollision on every primitive, plus the `Ck.Jolt.NoBake` component and actor tags; Static mobility
   (as `Mars_HangingChain.as:104-112, 258-276`).
3. **Clear.** `ClearInstances()` on every ISM, then `SetNumCustomDataFloats(n)` (this resets values, so it must come after
   the clear and before `AddInstance`).
4. **Source points**, actor-local XY:
   - `Single`: (0,0).
   - `Line`: `x_i = (i/(N−1) − 0.5)·LineLength + (Roll(i,0) − 0.5)·0.7·spacing` (vault ribs).
   - `Cluster`: sunflower `r = Radius·√((i+0.5)/N)`, `θ = 2.39996·i`, jitter ±0.3 spacing.
   - `Roll` is HangingRack's repeatable hash (`Mars_HangingRack.as:245` **[re-checked]**).
5. **Attach up** (`Trace.AttachUp`, default on). `LineTraceSingleForObjects(o + 1·Z, o + MaxRise·Z, [WorldStatic], true, Ignore{this}, None, Hit, true)`.
   On a hit with `ImpactNormal.Z < −0.35`, the source is `ImpactPoint − 1·Z`. Otherwise the origin is used. Each Line or
   Cluster point re-runs this, so strands follow an arch soffit.
6. **Down trace** (skipped for `Look.Mode == SittingBead`, and when `Trace.Surface == Air`, which gives `L = −AuthoredLength`).
   `LineTraceSingleForObjects(Source, Source − MaxLength·Z, [WorldStatic], true, Ignore{this}, None, Hit, true)`.
   - Hit with `Distance ≥ MinLength (20)`: `L = Hit.Distance`. Classify:
     - `Hit.PhysMaterial == Water_Mars_PhysMat` → Water;
     - otherwise `ImpactNormal.Z < 0.7` → Dry;
     - otherwise Floor.
   - Miss: if `CachedStrands[i]` exists, keep it; **a miss never overwrites a cached hit** (protects World Partition cells
     that are not loaded). State `MissedKeptCached`. With no cache: `L = −MaxLength` (Air), state `MissedNoCache`, no
     impact instances.
   - `Trace.Mode == Locked`: reuse the cache and do not trace.
7. **Per-strand values.** `Rate_i = exp(lerp(ln RateMin, ln RateMax, Roll(i,1)))` (log-uniform). `Seed_i = frac(Seed·0.618 + Roll(i,2))`.
8. **Instances** (world space, scale (0.1, 0.1, |L|/100), identity rotation; `AddInstance(T, true)`):
   - 6 drop cards at the impact (or at `Source − |L|·Z` for Air), with PICD 0..7.
   - Floor: 1 ring decal at `Impact + 1.0·N`, scale 0.6. Plus PuddleWet and PuddleGloss at `Impact + WaterLevelOffset(1.5)·N`.
     Rotation `FRotator::MakeFromXZ(projectedYaw, N)` (used in `Mars_FPHands_Grips.as`), random yaw; scale
     `Size/100`, with Size from `[SizeMin, SizeMax]`.
   - Water: 1 ring decal at `Impact + 0.3·Z`, no puddle.
   - Dry: no ring, no puddle; splash only.
9. **Wall streak** (`Streak.OnWall`):
   - Trace along `−ActorForward` (designer convention: local +X points out of the wall), up to 60 cm.
   - On a hit, trace down along `wall + 4·N` to the floor (up to 600 cm) to get the length.
   - Place `Streak` with decal +X going into the wall. Size goes through relative scale against the default half-extents
     (16, 50, 50) set by `default`, because `DecalSize` is BlueprintReadOnly (`DecalComponent.h:82`; the scale approach of
     `Mars_CuttingStation_EntityScript.as:395-425`).
   - `SetDecalColor(Seed, Dampness, Flow, Mineral)` (`DecalComponent.h:113` **[re-checked]**).
10. **Store `CachedStrands`** (`TArray<FMars_DripStrandRecord>`, VisibleAnywhere). The last `SetCustomDataValue` per
    component passes `bMarkRenderStateDirty = true`.

**PCG**: the same steps in graph form (§6). Ceiling hits come from up-rays; floor or water hits come from down-rays, which
write `ImpactDistance` and `PhysicalMaterial`. Points end at the impact, so no source position is ever copied back.

### 3.8 Puddle shape and DBuffer arithmetic (two layers)

A DBuffer decal applies one opacity per DBuffer target (`DecalCommon.ush:110-112`). Which targets a master writes is fixed
by its connected pins (`DecalRenderingCommon.cpp:118-126`). Two masters with disjoint pins write disjoint targets, so
**darkening and gloss are tuned independently**. That is the fix for pcg-instanced's "deep `a ≥ 0.93` forces albedo ×0.07".

Shape, in puddle-local `p ∈ [−1,1]²`, with aspect `1 + 0.8·Aspect01` along X:

```hlsl
float s = MarsWet_Facet(p, Facets, Seed)                   // max of Facets half-planes at seeded angles (Facets 9; 0 = round)
        + 0.30 * MarsWet_Value2(p * 1.7 + Seed * 13.1)     // lobes
        + 0.12 * MarsWet_Value2(WorldPos.xy * 0.02);       // world wobble: neighbours differ
float island = smoothstep(0.62, 0.70, MarsWet_Value2(WorldPos.xy * 0.067));   // dry islands
float deep = smoothstep(1.00, 0.78, s) * (1 - island);
float rim  = smoothstep(1.25, 0.95, s);
```

| Layer (master) | Writes | Opacity | Values | Result on stone (R_in ≈ 0.8) |
|---|---|---|---|---|
| `PuddleWet_Mars_M` | BaseColor (DBuffer A) | `max(deep·DeepDarken 0.6, rim·RimDarken 0.45)·Wetness`, halo at 1.18× with a noisy edge | BaseColor = `WaterTint` (0.010, 0.009, 0.007); sewer MI: scum tint | albedo × 0.4 deep, × 0.55 rim |
| `PuddleGloss_Mars_M` | Normal (B), Roughness/Specular/Metallic (C) | `max(deep·0.95, rim·0.5)·Wetness` | Roughness `lerp(0.35, 0.03, deep)`, Specular 0.3, Metallic 0, Normal flat ⊕ rain rings ⊕ micro-ripple | R ≈ 0.07 deep: **below the 0.1 capture fade start**; R ≈ 0.55 rim (damp) |

Reflection captures fade between roughness 0.1 and 0.3, with little indirect light behind them (pcg-instanced's derivation:
`ReflectionEnvironment.cpp:66, 74`). That is why the deep gloss opacity is fixed at 0.95 or more:
`a > (R_in − 0.1)/(R_in − R_w) = 0.907`.

**Mesh decals need no receiver-facet mask.** The quad hovers 1.5 cm above the floor. Raised flagstones poking through are
depth-occluded and stay dry, which gives free natural islands. The **projected** decals (WetStreak, and the puddle
fallback) do apply hybrid-fx's facet mask, so wet does not smear onto perpendicular facets:
`faceMask = smoothstep(0.6, 0.85, |dot(normalize(cross(ddx(WP), ddy(WP))), DecalAxis)|)`. This is exact per facet on the
low-poly kit.

### 3.9 Rain rings (`PuddleGloss` and still water; static switch `RainRipples`, rate from PICD 2 / CPD 4)

- World-XY cells of `RainCellCm` (16).
- Each cell gets a hashed centre (±0.3 of a cell), a period of `1/(RainRate·cellArea)` and an offset.
- The ring profile is the one from §3.6, with `R = 18·age` and life 0.8 s.
- Each pixel evaluates the 2×2 nearest cells (ring radius ≤ cell).
- Rings are world-anchored, so there are no seams between puddles.

### 3.10 Wet streak (`WetStreak_Mars_M`, projected)

`u` runs up the wall (1 at the source), `v` across.

- Band half-width `wb(u) = 0.5·(0.35 + 0.65·(1 − u)^0.6)`, widening downward, with edge value-noise.
- 3 to 5 seeded rivulets `x_i(u) = x0_i + 0.03·vnoise(u·L·0.04 + i)`. Flow beads scroll down at 8-15 cm/s when `Flow > 0`
  (viscous film: constant speed).
- `Opacity = Dampness·band + 0.5·rivulet`, times the facet mask.
- Roughness `lerp(0.25, 0.06, rivulet)`.
- `BaseColor = lerp(0, MineralTint, Mineral·(1 − u)²)`: rust or calcite gathers under the joint.
- Normal: rivulet bulge.
- A `FlipV` parameter covers decal UV orientation **[VERIFY P4]**.

### 3.11 Still water

`StillWater_Mars_M` (opaque basin):

- Edge distance `d = min(u, 1−u)·SizeX` and `min(v, 1−v)·SizeY` (CPD 0/1), plus world noise.
- Colour from moss-brown (0.03, 0.035, 0.02) at the edge to (0.006, 0.009, 0.007) beyond `DepthFadeCm` (180) × Murk.
- Scum band `d < 15 cm` with roughness 0.35; open water roughness 0.03, Specular 0.3.
- Swell normal: two drifting value-noise slopes (world XY / 37 and / 91 cm, amplitude 0.02).
- Rain rings optional.
- `MaterialDecalResponse = MDR_NormalRoughness`, so ring decals perturb it without tinting.

`StillWaterDeep_Mars_M` (Single Layer Water, cistern; `MSM_SingleLayerWater`, `EngineTypes.h:716` **[re-checked]**):

- Absorption (0.040, 0.014, 0.020)/cm and scattering (0.0012, 0.0026, 0.0018), PhaseG 0.15, ColorScaleBehindWater 0.6.
  Units are 1/cm (`MaterialExpressionSingleLayerWaterMaterialOutput.h:16-30`). Red dies within about 25 cm and green within
  about 70 cm, which gives the moss-dark depth with pier bases fading to green-black.
- Roughness 0.035; same swell.
- The capture composite still runs with `r.ReflectionMethod=0` (`SingleLayerWaterRendering.cpp:62-65, 1552-1633`, verified
  by both judges).
- Whether SLW receives DBuffer ring decals is **[VERIFY P4]**. Fallback: the field and leak lay `DripImpact` as a
  translucent flat ring card instead (static switch `RingAsCard` in a translucent sibling master `DripRingCard_Mars_M`, same
  `.ush`, opacity = crest mask).

Optional static switch `DistanceFieldShore` (off): a dark band where `DistanceToNearestSurface < 6 cm` at pier bases. The
global DF is prepared when a material uses it (`SceneVisibility.cpp:1319`, `DistanceFieldAmbientOcclusion.cpp:768-779`, per
judge 1). The surface component sets `bAffectDistanceFieldLighting = false`.

### 3.12 Presets (`EMars_DripPreset`, written by `ApplyPreset()` CallInEditor; the PCG volume graphs bake the same numbers)

| Preset | Layout / count | Rate (/s) | Jitter | Mode | Impact | Streak |
|---|---|---|---|---|---|---|
| CisternDrip | Cluster 6, r 120 | 0.25-0.9 | 0.6 | Drops | puddle 40-110 / wet 0.85, or rings on water | off |
| VaultLine | Line 8, 600 | 0.3-1.0 | 0.7 | Drops | puddle 35-80 / 0.8 | off |
| PipeJoint | Single | 1.5-2.5 | 0.4 | DropsWithThread | basin water | Rust |
| PipeTrickle | Single | 6-9 (Stream) | 0.3 | Stream | basin water | Rust |
| OssuarySeep | Cluster 3, r 40 | 0.08-0.2 | 0.8 | Drops | puddle 20-40 / 0.5 | Damp |
| Beads | Cluster 12, r 30 | 0 | n/a | HangingBead | none | off |

Shader defaults:

| Group | Values |
|---|---|
| Drop | DropRadius 0.45, TearK 1.6, Shutter 0.011, MinPixels 1.5, RefractPx 6, Transmission 0.85, ThreadWidth 0.16, ThreadBreak 14 |
| Ring | λ 2.4, W 1.2, Decay 0.5, RingAmp 0.55 (PICD 5 scales it), RingAlphaGain 0.6, Dimple 0.4 |
| Cull / fade | Drop cards: fade 2500-3500, cull 4000. Rings: cull 2500. Puddles: cull 6000 |

---

## 4. Data contracts

### 4.1 Per-instance custom data

**Drop cards** (`Drops` ISM, `NumCustomDataFloats = 8`, enum `EMars_DripCardData`):

| Slot | Name | Range | PCG attribute | AS source |
|---|---|---|---|---|
| 0 | Length | ±0..4000 cm; < 0 = Air (no impact, fade) | `ImpactDistance` (engine), negated for Air | trace distance |
| 1 | Rate | 0..12 /s (0 = static bead) | `DripRate` | log-uniform roll |
| 2 | Seed | [0,1) | `DripSeed` | roll |
| 3 | Jitter | 0..1 | `DripJitter` | `Timing.Jitter` |
| 4 | Mode | 0..4 (`EMars_DripMode`) | `DripMode` | `Look.Mode` |
| 5 | Slot | 0..5 (`EMars_DripSlot`) | `DripSlot` | loop index |
| 6 | DropScale | 0.5..2 | `DropScale` | `Look.DropScale` |
| 7 | Surface | 0 Floor, 1 Water, 2 Dry | `DripSurface` | classify |

**Rings** (`Rings` ISM, 6 floats, `EMars_DripRingData`): slots 0..4 = the strand's slots 0..4, **bit-identical** (this is the
sync contract the tests assert), then 5 RingAmp (0..2; 0 on Dry).

**Puddles** (`PuddleWet` and `PuddleGloss` ISMs, 4 floats each, identical values, `EMars_PuddleData`): 0 Seed, 1 Wetness,
2 RainRate (rings per m²/s), 3 Aspect01. Size is the instance XY scale (the quad is 100 cm).

Writers:
- **PCG:** packer `AttributeSelectors` in exactly these orders. Bool, int, float and double each pack to one float (per the
  judges, `PCGInstanceDataPackerBase.cpp:19-46`).
- **AS:** `SetNumCustomDataFloats` then `SetCustomDataValue(i, int32(EMars_DripCardData::X), float32(v), last)`, as
  `Plugins/CkTests/Script/CkUsf/CkUsfGym_PerInstanceShowcase.as:51` **[re-checked]** does.
- Persistence: `PerInstanceSMCustomData` is bulk-serialized. The UPROPERTY is `SkipSerialization`
  (`InstancedStaticMeshComponent.h:192-193` **[re-checked]**) because the bulk path writes it. So the layout survives PIE
  and cook without re-tracing.

### 4.2 One material, PICD or CPD, read in the vertex shader

- Every read is a `UMaterialExpressionPerInstanceCustomData` (`DataIndex = k`). Its **`DefaultValue` input**
  (`MaterialExpressionPerInstanceCustomData.h:18-19` **[re-checked]**) is wired to a ScalarParameter with
  `use_custom_primitive_data = True` and `primitive_data_index = k`, set from Python exactly as `mars_candle_ue.py:175-180`
  **[re-checked]** does.
- `GetPerInstanceCustomData(FMaterialVertexParameters, ...)` returns `DefaultValue` past the instance data count
  (`UE/Shaders/Private/MaterialTemplate.ush:1514` **[re-checked]**). So the same master serves an ISM (PICD), a plain
  `UStaticMeshComponent` (its CPD in the details panel, for example a single static bead or a single puddle), and the
  parameter default.
- **All reads are in the VS** (WPO for drops; a VS stage for the decals), passed to the PS through
  `UMaterialExpressionVertexInterpolator`. This sidesteps the pixel-shader PICD question (`HLSLMaterialTranslator.cpp:16038`
  comment, versus `LocalVertexFactory.ush:573-575`).
- Every master that reads PICD sets `used_with_instanced_static_meshes`, because `USES_PER_INSTANCE_CUSTOM_DATA` requires it
  (`HLSLMaterialTranslator.cpp:16217` **[re-checked]**). The usage flag is honoured for the decal domain
  (`Material.cpp:2002`).

### 4.3 Non-ISM channels

| Consumer | Channel | Layout | Writer |
|---|---|---|---|
| `AMars_StillWater.Surface` | CPD, serialized defaults: `SetDefaultCustomPrimitiveDataFloat` (`PrimitiveComponent.h:1195`) | 0 SizeX cm, 1 SizeY cm, 2 Seed, 3 Murk, 4 RainRate | construction script |
| `WetStreak` decals (leak and `AMars_WetStreak`) | `DecalColor` (EditAnywhere UPROPERTY, `DecalComponent.h:86` **[re-checked]**; read by `UMaterialExpressionDecalColor`, which returns 1 on mesh decals) | R Seed, G Dampness, B Flow (cm/s ÷ 100), A Mineral | construction script |
| Puddle **fallback** (projected `AMars_Puddle` decals, only if mesh decals on ISM fail) | `DecalColor` ×2 components: wet/gloss = (Seed, Wetness, RainRate, Aspect); ring = (Length, Rate, Seed, Jitter); Mode is dropped (Drops assumed) | as before | `AMars_Puddle` / PCG Spawn Actor property overrides (applied to the template before spawn, `PCGSpawnActor.cpp:996-1004`) |

### 4.4 AngelScript structs (each at most 7 fields)

```angelscript
struct FMars_DripTiming  { UPROPERTY() float32 RateMin = 0.25f; UPROPERTY() float32 RateMax = 0.9f; UPROPERTY() float32 Jitter = 0.6f; }
struct FMars_DripLook    { UPROPERTY() EMars_DripMode Mode = EMars_DripMode::Drops; UPROPERTY() float32 DropScale = 1.0f;
                           UPROPERTY() UMaterialInterface DropMaterial; }            // null = Droplet_Mars_MI
struct FMars_DripImpact  { UPROPERTY() bool Puddles = true; UPROPERTY() float32 SizeMin = 40.0f; UPROPERTY() float32 SizeMax = 110.0f;
                           UPROPERTY() float32 Wetness = 0.85f; UPROPERTY() float32 WaterLevelOffset = 1.5f;
                           UPROPERTY() float32 RingAmp = 1.0f; UPROPERTY() float32 RainRate = 0.0f; }
struct FMars_DripTrace   { UPROPERTY() bool AttachUp = true; UPROPERTY() float32 MaxRise = 800.0f; UPROPERTY() float32 MaxLength = 1500.0f;
                           UPROPERTY() float32 MinLength = 20.0f; UPROPERTY() bool Air = false; UPROPERTY() float32 AirLength = 600.0f;
                           UPROPERTY() EMars_DripTraceMode Mode = EMars_DripTraceMode::Live; }
struct FMars_DripStreak  { UPROPERTY() bool OnWall = false; UPROPERTY() float32 WidthCm = 30.0f; UPROPERTY() float32 MaxLengthCm = 600.0f;
                           UPROPERTY() float32 Dampness = 0.45f; UPROPERTY() float32 Flow = 30.0f; UPROPERTY() float32 Mineral = 0.0f; }
struct FMars_DripStrandHit    { UPROPERTY() FVector Point; UPROPERTY() FVector Normal; UPROPERTY() EMars_DripSurface Surface; }
struct FMars_DripStrandRecord { UPROPERTY() FVector Source; UPROPERTY() FMars_DripStrandHit Impact; UPROPERTY() float32 Length;
                                UPROPERTY() float32 Rate; UPROPERTY() float32 Seed; UPROPERTY() EMars_DripTraceState State; }
struct FMars_DripSchedule     // mirror of MarsDrip.ush; members only
{   float Length = 0; float Rate = 0.8; float Seed = 0; float Jitter = 0.6; float Mode = 0; float DropRadius = 0.45;
    // Get_Period(), Get_SlotCount(), Get_FallSeconds(), Get_Release(int32), Get_Impact(int32), Is_Skipped(int32),
    // Get_DistanceAt(float), Get_AgeAt(float), Get_EffectiveRate()
    // uint32 hash maths with wrap (precedent: Script/ECS/AnchorResolver/Mars_AnchorResolver_Solve.as);
    // cosh/acosh/tanh built from Math::Exp / Math::Loge
}
```

`AMars_DripLeak` top-level properties:
- `Preset`, `Layout`, `Count`, `LineLength`, `Radius`, `Seed`
- `Timing`, `Look`, `Impact`, `Trace`, `Streak`
- readouts `CachedStrands`, `EffectiveRate` (VisibleAnywhere)
- buttons `ApplyPreset()`, `Reseed()`, `Retrace()` (CallInEditor)

Presets are an enum plus a button, not data assets: a level reference to a script `asset` object is fragile across
recompiles.

### 4.5 PCG attribute contract (field host, after D1)

The struct field names **are** the attribute and override-pin names. Struct extraction reads direct children only
(`PCGGetActorProperty.h:79-80`), so there is one `GetActorProperty` node per struct (`bForceObjectAndStructExtraction`,
`PCGGetActorProperty.h:80` **[re-checked]**):

| Struct (`UPROPERTY(VisibleInstanceOnly, AdvancedDisplay, Category = "PCG Contract")`) | Fields |
|---|---|
| `PcgGrid : FMars_DripField_PcgGrid` | `GridExtents` (FVector), `CellSize` (FVector), `OffsetMin`, `OffsetMax`, `LowerBound` (density), `AreaEnabled`, `LinesEnabled` |
| `PcgDrips : FMars_DripField_PcgDrips` | `RateMin`, `RateMax`, `DripJitter`, `ThreadChance`, `MinLengthCm`, `DropScale`, `RingAmp` |
| `PcgPuddles : FMars_DripField_PcgPuddles` | `PuddleChance`, `PuddleScaleMin`, `PuddleScaleMax`, `WetnessMin`, `WetnessMax`, `RainRate`, `AmbientChance` |

Attributes the graph generates: `DripRand`, `DripRate`, `DripSeed`, `ThreadRoll`, `DripMode`, `DripSlot`, `DripSurface`,
`PuddleSeed`, `PuddleWetness`, `PuddleAspect`, `PuddleScale`. Engine-written: `ImpactNormal`, `ImpactDistance`,
`PhysicalMaterial`.

### 4.6 Mesh channels

| Mesh | UV0 | Other | Pivot |
|---|---|---|---|
| `DropletCard_Mars_SM` | Plane corners (0,0)-(1,1) | no vertex colour, no UV1 | Plane centre. The shader treats the instance origin as the impact and `TransformPosition(Local→World, (0,0,100))` as the source. |
| `WetDecalCard_Mars_SM` | decal-local 0..1 | n/a | centre |
| `StillWater_Mars_SM` | 0..1 over the extent (the shader also uses world XY) | n/a | centre |

`build_meshes()` asserts that the Plane has 1 UV channel and ±50 cm bounds.

---

## 5. Materials

All masters are built **in place** by `mars_water_ue.build_masters()`: `_master()` empties the asset in a loop until it has
zero expressions (`mars_candle_ue.py:154-163`). Replacing a live master asserts in the renderer. MIs are re-parented, and
values artists set survive.

- Custom nodes set `include_file_paths = ["/Project/Water/MarsWet.ush"]` and have 1-6 line bodies.
- Every Time node gets `override_period = True, period = 3600`, and the builder asserts both.
- `MEL.get_statistics()` instruction counts are logged and checked against §8.
- Substrate is off (`r.Substrate` default 0); DBuffer is on (`r.DBuffer` default 1).
- No textures are sampled anywhere.

| Master | Domain / blend / shading | Flags | Outputs |
|---|---|---|---|
| `Droplet_Mars_M` | Surface / Translucent / DefaultLit, `TLM_SurfacePerPixelLighting` | two-sided, `used_with_instanced_static_meshes`, tangent-space normal off, translucency Before DOF, `bComputeFogPerPixel`, no velocity, WPO | BaseColor, Emissive (SceneColor), Normal, Roughness, Specular, Opacity, WPO |
| `DripImpact_Mars_M` | DeferredDecal (mesh decal) | ISM usage; sort priority 2 | Normal, Roughness, Specular, Opacity |
| `PuddleWet_Mars_M` | DeferredDecal (mesh decal) | ISM usage; sort priority 0 | BaseColor, Opacity |
| `PuddleGloss_Mars_M` | DeferredDecal (mesh decal) | ISM usage; sort priority 1 | Normal, Roughness, Specular, Metallic, Opacity |
| `WetStreak_Mars_M` | DeferredDecal (projected) | DecalColor | BaseColor, Normal, Roughness, Specular, Opacity |
| `StillWater_Mars_M` | Surface / Opaque / DefaultLit | `MDR_NormalRoughness`, CPD | BaseColor, Normal, Roughness, Specular |
| `StillWaterDeep_Mars_M` | Surface / Opaque / SingleLayerWater | SLW output node, CPD | BaseColor, Normal, Roughness, Specular, SLW pins |

### 5.1 `Droplet_Mars_M` graph outline

```
[PICD 0..7 (DefaultValue <- CPD scalar k)] [Time Period=3600 override] [DebugTime] [TexCoord0] [CameraPositionWS]
[ViewProperty TanHalfFOV, ViewSize] [ObjectPositionWS] [TransformPosition L->W (0,0,100)] [WorldPosition excl. offsets] [MI params]
  -> Custom "DropVS"  (MarsWet_DropVS(...) -> WPO float3; extra outputs I0, I1 float4)
  -> WPO;  I0, I1 -> VertexInterpolator x2
[I0, I1 interpolated, TexCoord0, ScreenPosition]
  -> Custom "DropPS" (Opacity; extra RefractUV float2, NormalWS float3, Mask)
  -> SceneColor(Coordinates <- RefractUV)  [static switch UseSceneRefraction]
  -> outputs per 3.4
```

Parameters:
- Shape: DropRadiusCm, TearK, Shutter, MinPixels, ThreadWidthCm, ThreadBreakCm.
- Look: BodyTint, WaterTint, Transmission, RefractPx, Roughness, Specular, OpacityScale.
- Distance: FadeStartCm, FadeEndCm.
- Debug: DebugTime −1.
- CPD defaults "Length (CPD 0)" … "Surface (CPD 7)".

MIs: `DropletRust_Mars_MI` (tint 0.75, 0.55, 0.40) and `DropletMurk_Mars_MI` (sewer).

### 5.2 `DripImpact_Mars_M`

- VS: PICD 0..5 → interpolators.
- PS: `MarsWet_ImpactRings` (§3.6).
- Parameters: RingWidthCm, Decay, RingAlphaGain, Dimple, Roughness 0.03, Specular 0.3, DebugTime.

### 5.3 `PuddleWet_Mars_M` and `PuddleGloss_Mars_M`

- Both: VS PICD 0..3 → interpolators. Shape from §3.8, computed in both masters by the same `MarsWet_PuddleShape` call
  (identical inputs, so the edges coincide).
- Wet parameters: WaterTint, DeepDarken 0.6, RimDarken 0.45, HaloScale 1.18, HaloSoftCm 6, Facets 9, LobeAmount 0.3,
  IslandThreshold 0.62.
- Gloss parameters: DeepOpacity 0.95, RimOpacity 0.5, DeepRoughness 0.03, RimRoughness 0.35, Specular 0.3, static switch
  RainRipples, RainCellCm 16, MicroRippleAmp 0.03.
- MIs: `PuddleWetSewer_Mars_MI` (scum tint (0.02, 0.03, 0.015) on the rim), `PuddleGlossRain_Mars_MI` (rain on, for rooms
  under grates).

### 5.4 `WetStreak_Mars_M`

Parameters: Rivulets 4, RivuletWidth 0.06 (UV), HaloOpacity 0.35, CoreOpacity 0.85, CoreRoughness 0.06, FilmSpeed 12,
MineralTint (0.09, 0.04, 0.015) or calcite (0.5, 0.48, 0.42) in the MIs, FlipV.

### 5.5 Still water: §3.11

Parameters: DeepColour, EdgeColour, DepthFadeCm 180, ScumWidthCm 15, ScumRoughness 0.35, Roughness 0.03/0.035, Swell 0.02,
static switches RainRipples and DistanceFieldShore. Plus, on the SLW master, Absorption, Scattering, PhaseG and
ColorScaleBehindWater.

### 5.6 How breakup is produced

| Element | Source of variation |
|---|---|
| Release rhythm | per-drop hash: jitter ±0.45P, skips 0.25·Jitter |
| Rates | log-uniform per strand; phase from Seed |
| Drops | size ±20 %, bead breathing phase, thread-break wobble |
| Puddles | faceted, lobed SDF; aspect; random yaw and size; world-noise dry islands and edge wobble; rain cells |
| Streaks | rivulet lanes, edge noise and mineral from DecalColor |
| Water | per-actor seed and drift (CPD) |
| PCG | spatial-noise clustering, jitter, self-pruning, host `Seed` (`PCGComponent.h:336` **[re-checked]**) |
| Lighting | lit drops take each room's warm or cold light, so no tint MIs are needed |

Nothing samples a tiling texture, so repetition can only come from seeds, and seeds are per instance.

### 5.7 Lighting rules for wet rooms (in `README.md` and the workflow)

- Every room with puddles or still water gets a **Box Reflection Capture** fitted to the room. Recapture after lighting
  edits (precedent: `mars_station_gym_ue.py:633-642`).
- Torches and candles near water: `SourceRadius ≥ 8 cm`, so their reflections are visible blobs, not single pixels.
- Props under a leak that use `EnvPaint_Mars_M`: `Wetness ≥ 0.85` (that master's roughness reaches 0.1 at most,
  `mars_env_ue.py:117-119`).
- `audit_decal_response()` lists every `/Game/Mars/Environment` master that is not `MDR_ColorNormalRoughness`; those must be
  fixed in the kit builder before dressing.

---

## 6. PCG

### 6.1 Hosts and graph variants

`mars_water_pcg.build_graph(preset, host)` emits one node list from `water_spec`. The **front end** (sources) and the
**parameter source** differ by host. Everything from `RayUp` onwards is identical.

| Host | When | Graph asset | Parameters | Sources |
|---|---|---|---|---|
| Stock **`APCGVolume`** (engine actor; no AS) | Always available; the only host until D1 | `DripVolume_<Preset>_Mars_PCG` | Constants baked per preset. Graph user parameters cannot be created from script: `AddUserParameters` is C++-only (`PCGGraph.h:630`). | `UPCGVolumeSamplerSettings` on `In`/`Volume`, `VoxelSize (Spacing, Spacing, 100)`, world-aligned. Column duplicates are removed by SelfPruning after the up-ray. |
| **`AMars_DripField`** (after D1) | Room fields with designer knobs, lines, Regenerate/Bake | `DripField_Mars_PCG` | `UPCGGetActorPropertySettings` ×3 (Self; `PcgGrid`/`PcgDrips`/`PcgPuddles`; struct extraction) → `UPCGMergeAttributesSettings` → override pins | `UPCGCreatePointsGridSettings` (`LocalComponent`, `CellCenter`; overrides `GridExtents`, `CellSize`) + `UPCGSplineSamplerSettings` on the `SourceLine` spline (from `UPCGDataFromActorSettings`, Self, by component class, 15 cm, ignore PCG-generated) |

### 6.2 Node table (shared core; P = parameter source above)

Pins: `In`/`Out` (`PCGCommon.h:200-202`), raycast input `Origins`, add-attribute input `Attributes`, filter outputs
`InsideFilter`/`OutsideFilter`. "Filter" means `UPCGAttributeFilteringSettings` (per point). Selectors with extractors are
built with `import_text("PCGBegin(...)PCGEnd")`.

| # | `UPCGSettings` class | Key settings | Flow / attributes |
|---|---|---|---|
| S1 | front end (6.1) | | candidate points |
| S2 | `UPCGTransformPointsSettings` "Jitter" | Offset ±(0.4·Spacing, 0.4·Spacing, 0), `bAbsoluteOffset` | |
| S3 | `UPCGMergeSettings` | grid ∪ lines ∪ (optional) markers, **all wired into `In`** (multi-connection pin, §0) | |
| S4 | `UPCGSpatialNoiseSettings` | Perlin2D → `$Density`. Transform scale tuned so clusters are about 6 m (the node composes its transform with an internal scale; `verify()` prints the achieved coverage) **[VERIFY P5]** | |
| S5 | `UPCGDensityFilterSettings` | `LowerBound = 1 − Coverage` (Cistern 0.55, Sewer 0.75, Ossuary 0.85, Atrium 0.7) | |
| U1 | `UPCGWorldRaycastElementSettings` "RayUp" | `RaycastMode NormalizedWithLength`, `RayDirection (0,0,1)`, `RayLength 3000`, **`bUnbounded = true`**, `WorldQueryParams{ CollisionChannel = ECC_WorldStatic (default; object type), bTraceComplex = true, bIgnorePCGHits = true, bGetImpactNormal = true, ActorTagFilter = Exclude, ActorTagsList = [Mars.NoDrip] }`, `bKeepOriginalPointOnMiss = false` | Points move to the hit with transform Z = impact normal (`PCGWorldQueryHelpers.cpp:32-41`); `ImpactNormal` |
| U2 | Filter | `ImpactNormal.Z` LesserOrEqual constant −0.35 (soffits, vault undersides, balcony bottoms) | `InsideFilter` |
| U3 | `UPCGTransformPointsSettings` "Source" | `bAbsoluteRotation` (0), absolute offset (0,0,−1) | |
| U4 | `UPCGBoundsModifierSettings` + `UPCGSelfPruningSettings` | Bounds set to ±18 cm, randomized pruning (36 cm spacing, removes column duplicates) | **sources** |
| R1 | `UPCGAttributeNoiseSettings` | → `DripRand` 0..1 | |
| R2 | `UPCGMetadataMathsSettings` ×3 | `DripRate = Exp(Lerp(Ln RateMin, Ln RateMax, DripRand))` (log-uniform) | |
| R3 | `UPCGAttributeNoiseSettings` | → `DripSeed` 0..1 | |
| R4 | `UPCGAttributeNoiseSettings` + `UPCGMetadataCompareSettings` + `UPCGAttributeCastSettings` | `ThreadRoll < ThreadChance` → bool → Double `DripMode` (0 Drops / 1 DropsWithThread) | |
| R5 | `UPCGAddAttributeSettings` ×2 | `DripJitter` (preset), `DropScale` 1 | |
| D1 | `UPCGWorldRaycastElementSettings` "RayDown" | `(0,0,−1)`, `RayLength 4000`, **`bUnbounded`**, WorldStatic, complex, `bIgnorePCGHits`, `bGetDistance`, `bGetImpactNormal`, `bGetReferenceToPhysicalMaterial` | `ImpactDistance`, `ImpactNormal`, `PhysicalMaterial` (`PCGWorldQueryHelpers.h:39-41` **[re-checked]**). Metadata of the input point is kept on a hit. **impacts** |
| D2 | Filter | `ImpactDistance ≥ MinLengthCm` (60) | |
| D3 | Filter "IsWater" | `PhysicalMaterial` Equal SoftObjectPath `/Game/Mars/Physics/Water_Mars_PhysMat.Water_Mars_PhysMat` | Inside **W** / Outside **G** |
| D4 | Filter on G | `ImpactNormal.Z ≥ 0.7` | Inside **Gf** (floor) / Outside **Gd** (dry slope) |
| D5 | `UPCGAddAttributeSettings` ×3 (+ `RingAmp`) | `DripSurface` = 0 on Gf, 1 on W, 2 on Gd. `RingAmp` = P value on Gf/W, 0 on Gd | |
| D6 | `UPCGMergeSettings` | Gf + W + Gd → **I** (impacts with surface) | |
| C1 | `UPCGCreatePointsSettings` | 6 points at the origin | slot templates |
| C2 | `UPCGAttributeCastSettings` | `$Index` → Double `DripSlot` | |
| C3 | `UPCGCopyPointsSettings` | Source = C2, Target = I, `AttributeInheritance = SourceFirst` (`PCGCopyPoints.h:36` **[re-checked]**) | 6 per strand |
| C4 | `UPCGTransformPointsSettings` | `bAbsoluteRotation` 0 (world-vertical) | |
| C5 | `UPCGMetadataMathsSettings` ×2 + `UPCGMetadataMakeVectorSettings` | `$Scale = (0.1, 0.1, ImpactDistance/100)` | |
| C6 | `UPCGStaticMeshSpawnerSettings` **"Drops"** | `set_mesh_selector_type(PCGMeshSelectorWeighted)`; `set_instance_packer_type(PCGInstanceDataPackerByAttribute)` (`PCGStaticMeshSpawner.h:55-59` **[re-checked]**); entry `DropletCard_Mars_SM` + `Droplet_Mars_MI`; packer `[ImpactDistance, DripRate, DripSeed, DripJitter, DripMode, DripSlot, DropScale, DripSurface]` | **drop ISM** |
| I1 | `UPCGTransformPointsSettings` | from I minus Gd: offset +1.0 along the normal (Gf) or +0.3 Z (W), random yaw, scale 0.6 | |
| I2 | `UPCGStaticMeshSpawnerSettings` **"Rings"** | `WetDecalCard_Mars_SM` + `DripImpact_Mars_MI`; packer `[ImpactDistance, DripRate, DripSeed, DripJitter, DripMode, RingAmp]` | **ring ISM** |
| P1 | `UPCGAttributeNoiseSettings` + Filter | from Gf: `PuddleRoll < PuddleChance` | |
| P2 | Ambient branch (optional) | From S5 a second sparse set (`AmbientChance`) → RayDown copy → Gf filter → merge here. Puddles without drips (rain only). | |
| P3 | `UPCGAttributeNoiseSettings` ×4 + `UPCGMetadataMathsSettings` (Lerp) ×2 | `PuddleSeed`, `PuddleAspect`, `PuddleWetness` ∈ [WetnessMin, WetnessMax], `PuddleScale` ∈ [PuddleScaleMin, PuddleScaleMax] | |
| P4 | `UPCGBoundsModifierSettings` + `UPCGSelfPruningSettings` | Bounds = ±50·PuddleScale; `LargeToSmall` | no overlaps |
| P5 | `UPCGTransformPointsSettings` + `UPCGMetadataMathsSettings` | offset +1.5 along the normal, yaw 0..360, `$Scale = PuddleScale` | |
| P6 | `UPCGStaticMeshSpawnerSettings` **"PuddleWet"** | `WetDecalCard_Mars_SM` + `PuddleWet_Mars_MI`; packer `[PuddleSeed, PuddleWetness, RainRate, PuddleAspect]` | |
| P7 | `UPCGStaticMeshSpawnerSettings` **"PuddleGloss"** | same points and packer, `PuddleGloss_Mars_MI` | |
| X1 (opt) | `UPCGDataFromActorSettings` (tag `Mars.DripBlocker`) + `UPCGDifferenceSettings` on U4 | | designer exclusion boxes |
| M1 (opt, 5b) | `UPCGDataFromActorSettings` (all world actors, tag `MarsDripSource`, overlapping, `GetSinglePoint`, silence sanitised-name warnings) → straight into D1, skipping U1-U4 | `DripRate:`/`DripMode:`/`DripSeed:` tags become attributes | pipe-joint markers |

Common spawner descriptor (`FPCGSoftISMComponentDescriptor`):
- `ComponentTags = [Ck.Jolt.NoBake]` (`PCG/Public/MeshSelectors/PCGISMDescriptor.h:25` **[re-checked]**).
- NoCollision (the PCG default: `PCGISMDescriptor.cpp:11-19`; the builder still sets it).
- `bCastShadow = False`; drop/ring `bReceivesDecals = False`.
- `TranslucencySortPriority` 0 for Drops (`ISMComponentDescriptor.h:104` **[re-checked]**).
- `InstanceEndCullDistance` 4000 / 2500 / 6000 / 6000.

`PostProcessFunctionNames = [PostSpawn_ApplyDressingPolicy]` (`PCGStaticMeshSpawner.h:102` **[re-checked]**) is set **only in
field-host graphs**, because the function lives on `AMars_DripField`.

### 6.3 Creation (editor Python)

```python
g = mc._asset(F_PCG, name) or mc._tools().create_asset(name, F_PCG, unreal.PCGGraph, unreal.PCGGraphFactory())
#   UPCGGraphFactory is UCLASS(hidecategories=Object) in PCGEditor/Private/PCGGraphFactory.h:12-13 [re-checked];
#   Python exposure of a Private-header UCLASS is [VERIFY P0]; fallback: duplicate a hand-made empty graph asset.
keep = (g.get_input_node(), g.get_output_node())
g.remove_nodes([n for n in g.get_editor_property("nodes") if n not in keep])     # rebuild IN PLACE (volumes keep their refs)
def node(cls, x, y, **props):
    n, s = g.add_node_of_type(cls)                                               # PCGGraph.h:351 (UFUNCTION)
    for k, v in props.items(): s.set_editor_property(k, v)
    n.set_node_position(x, y); return n, s
def sel(text):
    s = unreal.PCGAttributePropertyInputSelector()
    assert s.import_text("PCGBegin(%s)PCGEnd" % text)
    assert unreal.PCGAttributePropertySelectorBlueprintHelpers.get_attribute_name(s) is not None   # read-back
    return s
g.add_edge(a, "Out", b, "In")                                                    # PCGGraph.h:375
unreal.EditorAssetLibrary.save_loaded_asset(g)
```

`verify(graph)` reloads the asset and asserts:
- the node count;
- every edge and override edge;
- each spawner's packer selector order equals `water_spec` (and therefore the AS enums, through `check_drip_parity.py`);
- descriptor tags and NoCollision;
- all raycasts have `bUnbounded`, `collision_channel == WORLD_STATIC`, and the `bGet*` flags.

It prints `WATER_PCG_OK`.

`audit_pcg_hosts()` walks every PCG component in the Mars maps and asserts
`generation_trigger == GENERATE_ON_DEMAND`. The default is `GenerateOnLoad` (`PCGComponent.h:349` **[re-checked]**), so
nothing may be left on it.

### 6.4 `AMars_DripField` (after D1 only; sketch)

```angelscript
class AMars_DripField : AActor
{
    default bReplicates = false;
    UPROPERTY(DefaultComponent, RootComponent) USceneComponent SceneRoot;  default SceneRoot.Mobility = EComponentMobility::Static;
    UPROPERTY(DefaultComponent, Attach = SceneRoot) UBoxComponent Bounds;  default Bounds.BoxExtent = FVector(600, 600, 50);
    UPROPERTY(DefaultComponent, Attach = SceneRoot) USplineComponent SourceLine;
    UPROPERTY(DefaultComponent) UPCGComponent PCG;                          // PCGComponent.h:149 BlueprintSpawnableComponent
    default PCG.GenerationTrigger = EPCGComponentGenerationTrigger::GenerateOnDemand;      // :349 (default is GenerateOnLoad)
    default PCG.bGenerateOnDropWhenTriggerOnDemand = true;                                  // :353
    // Designer knobs (Sources / Drips / Puddles): Sources {Area, Lines, AreaAndLines}, Spacing, Jitter, Coverage, RateMin,
    // RateMax, Jitter, ThreadChance, MinLength, PuddleChance, PuddleSize min/max, Wetness min/max, RainRate, Ambient, Seed.
    UPROPERTY(VisibleInstanceOnly, AdvancedDisplay, Category = "PCG Contract") FMars_DripField_PcgGrid PcgGrid;
    UPROPERTY(VisibleInstanceOnly, AdvancedDisplay, Category = "PCG Contract") FMars_DripField_PcgDrips PcgDrips;
    UPROPERTY(VisibleInstanceOnly, AdvancedDisplay, Category = "PCG Contract") FMars_DripField_PcgPuddles PcgPuddles;
    UFUNCTION(BlueprintOverride) void ConstructionScript() { Rebuild(); }
    UFUNCTION(CallInEditor, Category = "PCG") void Rebuild();      // policy; fill Pcg*; PCG.Seed = Seed; SetGraph only if null
    UFUNCTION(CallInEditor, Category = "PCG") void Regenerate();   // PCG.CleanupLocal(true); PCG.GenerateLocal(true) (:251, :262)
    UFUNCTION(CallInEditor, Category = "PCG") void Bake();         // PCG.ClearPCGLink() (:302)
    UFUNCTION(CallInEditor) void PostSpawn_ApplyDressingPolicy(); // every generated ISM: NoCollision, NoBake, no shadow
}
```

- PCG loads at `Default` and Angelscript at `PostDefault` (`PCG.uplugin:21`, `Angelscript.uplugin:22` **[re-checked]**), so
  the type is visible to script.
- `UPCGComponent` as an AS DefaultComponent, and `default` on its `EditAnywhere, BlueprintReadOnly` trigger (the
  `default SceneRoot.Mobility` pattern), are **[VERIFY D1 spike]**. Fallback: the field attaches a stock `APCGVolume` child
  in the construction script. Its graph uses `GetActorProperty` with the `Parent` actor filter.

---

## 7. Designer workflow

| Task | How | Live or baked |
|---|---|---|
| Room-scale drips (any time) | Place an engine **PCG Volume** covering the room footprint, any height between floor and vault (raycasts are unbounded). Set Graph = `DripVolume_Cistern_Mars_PCG` (or Sewer/Ossuary/Atrium) and **GenerationTrigger = GenerateOnDemand**, then Generate. Or run `mars_water_pcg.place_volume(bounds, "Cistern")`, which sets the trigger and calls `generate_local(True)`. | Layout baked as PCG-managed ISMs saved in the level; motion live |
| Room fields with knobs and rib lines (after D1) | Place **Mars Drip Field**, size `Bounds`; it generates on drop. Tune Coverage, Spacing and rates, then Regenerate (or rely on the owner-change refresh **[VERIFY P5]**). Draw `SourceLine` under the ribs. | same |
| A specific leak, vault line, pipe or bead patch | Drag **Mars Drip Leak**, pick `Preset` → **ApplyPreset**, tweak the groups. On a pipe: attach to `PipeSpout_A`'s `SOCKET_Drip`. On a wall: +X out of the wall, enable `Streak.OnWall`. | Construction script re-traces on every move or edit; motion live |
| Drip into darkness | `Trace.Air = true`, `AirLength`. | |
| Re-seed | Leak: **Reseed** (Seed += 1). Volume/field: change the component `Seed`, then Generate. | Deterministic |
| Freeze a leak (WP levels, geometry being edited) | `Trace.Mode = Locked`. In Live mode a miss never overwrites a cached hit; `CachedStrands[i].State` shows what happened. | Baked |
| Loose puddles | **Mars Puddle** (Count, Radius, Size, Wetness, RainRate, Seed). | Baked layout |
| Cistern or basin water | **Mars Still Water** sized to the pool, Z at the water line; MI Basin (opaque) or Cistern (SLW). Attach to `StoneBasin_A`'s `SOCKET_Water`. Add a **Box Reflection Capture** for the room. | Baked |
| Damp or rust patch | **Mars Wet Streak**: +X out of the wall; length auto-traced. | Baked |
| Exclude an area | Tag ceiling actors `Mars.NoDrip`, or place a box tagged `Mars.DripBlocker` (field graph X1), then regenerate. | |
| One-off static bead | A StaticMeshActor with `DropletCard_Mars_SM` + `Droplet_Mars_MI`; CPD 0..7 = (0, 0, seed, 0, 3 or 4, 4, 1, 0). | CPD fallback |
| Tune the look | Edit the `.ush`, then `recompileshaders changed` (whether an include edit triggers recompile on its own is **[VERIFY P1]**). Re-run `mw.build_masters()` only when the node graph changes. | |
| Judge timing | Set an MI's `DebugTime`, or run `r.Test.OverrideTimeMaterialExpressions <t>` (`SceneView.cpp:382-383` **[re-checked]**). | |

**Undo.** Undoing a leak property re-runs the construction script with the same seed and traces, so the result is identical.
PCG generation is not transactional: use Cleanup / Generate, or change the seed. Never hand-edit PCG output, because
Generate discards it; override with blockers or leaks.

**Two editors.** Build materials while Stephen's editor is closed, or drive his Monolith on :9316 when he is idle. A hidden
editor (:9317) cannot save assets his editor has loaded, and his editor keeps stale copies until it restarts (memory notes).

---

## 8. Performance budget, collision and Jolt

These are estimates until the Phase-6 `ProfileGPU` / `stat gpu` capture at 1080p in `WaterLookdev_Mars_MAP` and
`BrokenCistern_Mars_MAP`. Nothing here is measured yet.

| Item | Budget | Basis |
|---|---|---|
| Draws per field or volume | 5 (Drops, Rings, PuddleWet, PuddleGloss + still water), no shadow draws | one ISM per spawner |
| Draws per leak | ≤ 5, + 1 projected streak | |
| Instances | A 20×20 m field at 1.2 m cells, coverage 0.35, gives about 100 strands → 600 drop cards, 100 rings, ≤ 60 puddles ×2. Cap ≤ 160 strands per field and ≤ 400 visible per room. | |
| Drop translucency | About 0.8 live drops per strand × 10-40 px, so under 5 k px per field. Idle slots collapse to zero area. Target ≤ 0.25 ms. | A full-length strand card would be about 350 k px for 100 strands at 8 m |
| SceneColor copy | One scene-colour copy per frame while any refracting drop is visible. Static switch off in `Droplet_Lite` if measured as costly. | |
| Ring decals | 60 cm → about 1.5 k px at 6 m; 3 candidates per pixel | |
| Puddle decals | 0.7-1.8 m → 3-15 k px per layer. DBuffer total (rings + puddles + streaks) target ≤ 0.40 ms | |
| Shader instructions (PS / VS) | Droplet ≤ 260 / 320; DripImpact ≤ 200; PuddleWet ≤ 90; PuddleGloss ≤ 200; StillWater ≤ 180 | logged by the builder |
| Construction script per leak | ≤ 2 traces per strand + 1 per streak; a 12-strand leak is about 25 traces and ≤ 600 `SetCustomDataValue`; editor only, well under 1 ms (estimate) | Placed actors do not re-run it in cooked builds |
| PCG generate | About 2-3 k raycasts per volume, editor only, target ≤ 150 ms | |
| Precision | Wrap at 3600 s keeps time precision below 0.25 ms | |

**Collision and Jolt bake policy:**
- Every drop, ring and puddle ISM, generated or hand-placed, is **NoCollision** with component tag `Ck.Jolt.NoBake`. The
  leak, puddle, streak and field actors carry the actor tag too. NoCollision components are not eligible for the CkJolt bake
  (`CkJoltBakeExtraction.cpp:201`), and the tag is in the default exclusion lists (`CkJolt_ProjectSettings.cpp:57-59`). So
  adding, moving or regenerating drips never stales the static-world cook hash.
- Decal components are not primitives and cannot affect the bake.
- `AMars_StillWater.Probe` (UBoxComponent, thin, at the water line):
  - `SetCollisionEnabled(QueryOnly)`, `SetCollisionObjectType(WorldStatic)`, `SetCollisionResponseToAllChannels(Ignore)`,
    `SetPhysMaterialOverride(Water_Mars_PhysMat)`;
  - tags `Ck.Jolt.NoBake` + `Mars.Water`.
  - Object-type queries (PCG and AS) match on object type and see it. Trace-channel queries (Visibility: camera, interaction,
    `Mars_SurfaceFx` ground probes) and pawns ignore it.
  - That object queries ignore channel responses here is **[VERIFY P3]**, settled by `DripLeak_LandsOnStillWater`. Fallback:
    `SetCollisionResponseToChannel(WorldStatic, Block)`.
  - Option `SolidForJolt` (off) mirrors HangingChain's `Collides`.
- The `Surface` mesh is NoCollision.

---

## 9. Verification

### 9.1 Headless AutoTests (`Script/Tests/Drips/`, `UCk_AutoTest_Base`, one class per file)

Rigs follow `Script/Tests/SurfaceFx/Mars_AutoTest_SurfaceFx_GroundTraceReturnsOverridePhysMat.as` and the HangingChain test:
- an `AStaticMeshActor` cube, set Movable before `SetStaticMesh`, BlockAll (object type WorldStatic);
- `Add_Step_WaitFrames(2)` so the body registers;
- a private parking spot (X 12000-18000, unique Y per test, Z ≥ 5000);
- slabs destroyed in cleanup.

| Test class | Asserts |
|---|---|
| `UMars_AutoTest_DripSchedule_ReleasesStayOrderedAndAverageTheRate` | 500 releases strictly increasing at Jitter 1; mean interval within 2 % of `Get_Period()`; CV > 0.1 at Jitter 0.6 and < 1e-6 at Jitter 0; skip rate 0.25·J ± 2 % |
| `UMars_AutoTest_DripSchedule_ADropLandsAtTheImpactTime` | `Y0 + DistanceAt(FallSeconds) + R == L ± 0.05` for L ∈ {10, 100, 350, 1050, 1200}; `AgeAt(DistanceAt(a)) == a ± 1e-4`; speed monotonic and below terminal; spacing of consecutive in-flight drops grows with depth |
| `UMars_AutoTest_DripSchedule_SlotsNeverOverlapAndWrapSeamlessly` | For random (L, Rate, Jitter): `Release(k + 4) ≥ Release(k) + Busy`; N is a multiple of 4; `N·P == 3600`; `Release(N−1) − 3600 == Release(−1) ± 1e-3`; `EffectiveRate ≤ Rate` |
| `UMars_AutoTest_DripSchedule_MatchesTheReferenceTable` | 40 golden rows from `drip_reference.py` (seed, rate, jitter, L, k → release, impact, skipped) within 1e-4 s |
| `UMars_AutoTest_DripLeak_TracesStrandsDownToTheFloor` | Cluster of 5, floor top at 0, leak at +400. 30 drop instances (6 per strand), slots 0..5 present per strand, PICD0 = 399 ± 0.5. 5 rings whose PICD 0..4 equal their strand's bit for bit. Puddle instances at floor + 1.5. A second Rebuild gives identical counts and values. |
| `UMars_AutoTest_DripLeak_AttachesUpToTheCeiling` | Mid-air leak under a ceiling slab: source Z = slab bottom − 1 |
| `UMars_AutoTest_DripLeak_LandsOnStillWaterAsRingsOnly` | `AMars_StillWater` between leak and floor: Length = distance to the water; Surface = Water (PhysMat); PuddleWet/Gloss counts 0; 1 ring; the probe is QueryOnly, WorldStatic, tagged NoBake; a Visibility `LineTraceSingle` through it misses |
| `UMars_AutoTest_DripLeak_AirModePacksNegativeLength` | `Trace.Air`: PICD0 = −AirLength, 0 rings, 0 puddles, state Air |
| `UMars_AutoTest_DripLeak_AMissKeepsTheLastTracedLength` | Trace, destroy the floor, Rebuild: length and impacts unchanged, state MissedKeptCached. A fresh leak with no floor: −MaxLength, MissedNoCache, no impacts. Positive first step proves the trace ran. |
| `UMars_AutoTest_DripLeak_StaysOutOfTheJoltBake` | Every primitive of DripLeak, Puddle and WetStreak is NoCollision with component and actor tags; `CastShadow` false |
| `UMars_AutoTest_Puddle_ReseedChangesShapesNotCount` | Same count; different PICD0; deterministic per Seed |
| `UMars_AutoTest_WetStreak_TracesWallToFloor` | Decal X points into the wall; length = wall height ± 1; `DecalColor == (Seed, Dampness, Flow/100, Mineral)` |
| `UMars_AutoTest_StillWater_WritesSerializedCustomData` | CPD defaults 0..4 equal Size/Seed/Murk/Rain, read from `CustomPrimitiveData.Data` **[VERIFY P0: AS readability; fallback: the actor's mirror array]** |
| *(gated)* `UMars_AutoTest_DripField_PcgLaysStrandsBetweenSlabs` | **Added only if D1 = commit and the P5 spike shows a game-world `GenerateLocal` logs nothing under `-nullrhi`.** Field between slabs, coverage 1. Wait on `PCG.bGenerated` (`PCGComponent.h:421`, `Add_Step_WaitUntil`, 30 s). Drop ISM has 6× strands instances; every PICD0 ∈ gap ± 2; rings PICD 0..4 match; trigger is GenerateOnDemand; ISM tagged NoBake. Any PCG warning fails the test. |

How the tests stay clean under `-nullrhi`:
- no CkUsf looks, no MIDs, no captures, no Niagara;
- assets loaded only through generated `assets::load::` accessors for committed assets (`Water_Mars_PhysMat` and the meshes
  exist before the tests);
- optional kit lookups are editor-world only (the HangingChain guard);
- no logging in construction scripts;
- anything render-dependent added later is gated on `FApp::CanEverRender()` (`Mars_Steward_EntityScript.as:390`
  **[re-checked]**).

PICD read-back in tests uses `PerInstanceSMCustomData` (EditAnywhere, `InstancedStaticMeshComponent.h:192-193`).
**[VERIFY P0]**: readable from AS the way `NumCustomDataFloats` is writable. Fallback: assert against the leak's
`CachedStrands` plus a test-only `Get_WrittenCardData()` mirror.

**Gate:** `check_drip_parity.py`, then `/build-test` with `--test-pattern DripSchedule`, then `--test-pattern Drip`,
`--test-pattern Puddle`, `--test-pattern WetStreak`, `--test-pattern StillWater`. Then one full
`./CkAuto/UnrealToolbox.exe --test --no-live --discover-fresh`, reading `=== Known reds ===`. No `knownReds` entry for any of
these tests, ever. The full gate rewrites `Config/DefaultGameplayTags.ini`, so commit with explicit pathspecs.

### 9.2 Offline checks (`python -I`)

- `check_drip_parity.py`: constants, slot enums and packer orders.
- `drip_reference.py --selftest`: clock invariants over 10⁵ drops, matching the AS tests. Space-time sheets go to
  `D:/Repo/Content/Water/export/review/`.

### 9.3 Editor checks (`mars_water_review.py`, hidden editor :9317, or :9316 when idle)

1. `mw.verify_materials()`:
   - domain, blend and shading per §5;
   - ISM usage flags;
   - Time period override set;
   - include paths resolve;
   - no compile errors;
   - instruction budgets;
   - StillWater `MDR_NormalRoughness`;
   - mesh bounds extensions;
   - `audit_decal_response()` output.
2. **Mesh decal on ISM (first Phase-2 check):** two PuddleGloss instances with different PICD0 must render different shapes
   in a capture. If they don't, switch to the §4.3 projected fallback before any puddle work continues.
3. **Frozen-time contact sheets** with `r.Test.OverrideTimeMaterialExpressions t` (or MI `DebugTime`). t = 10.000 … 11.500
   in 0.125 s steps, for: a strand + puddle, a strand + still water, a pipe trickle into the basin, and a vault line. Shown
   side by side with concepts (b), (c) and (d).
4. **Timing parity (automatic):**
   - One strand, orthographic side camera, black backdrop, frozen t.
   - Detect drop rows from the column maximum and compare with `drip_reference.py` predictions within ±1.5 px.
   - **Ring sync:** an `SCS_Normal` capture from above at `I_k + 0.05` must show the normal perturbed at r ≈ 22·0.05 cm, and
     `I_k − 0.05` must be flat.
   - A colour capture at `I_k − 0.02` must show a bright drop just above the impact.
   - Prints `WATER_TIMING_OK`.
5. **Look checks:** captures in a separate call after the reflection captures update. Each bay under warm torch and cold
   moon, with and without the Box Reflection Capture, at 3 view angles. Buffer visualisation Roughness must be below 0.1 in
   puddle cores.
6. **[EDITOR-VERIFY] in PIE** (SceneCapture stills render darker than the game):
   - stand under the cistern strands and look straight up: drops stay round, threads fade;
   - drops visibly accelerate and spread;
   - the bead swells and then detaches;
   - no shimmer at 20 m;
   - pause and unpause stay in sync;
   - `slomo 60` past the 3600 s wrap: no pop;
   - generate a volume, save, reopen: instances persist; PIE shows the same drips.
7. **Perf:** `ProfileGPU` deltas for translucency, DBuffer decals, the SLW composite and base pass, with a full volume and
   with an empty one. Recorded in `README.md`.

---

## 10. Build order and risks

| Phase | Work | Ends with (testable) |
|---|---|---|
| **P0 Preflight** (half a day) | **Decision D1** (PCG hunk). Python spikes: `unreal.PCGGraphFactory`, `add_node_of_type`, `import_text` selector read-back, `generate_local` on a scratch volume, `material_decal_response` on `Surface_Mars_M` / `MiseAtlas_Mars_M`, `bReceivesDecals` on kit HISMs. A scratch AS file (deleted afterwards) that reads `PerInstanceSMCustomData` and `CustomPrimitiveData.Data` and calls `LineTraceSingleForObjects` with `EObjectTypeQuery::WorldStatic`. Commit `Tools/Blender/mars_environment` if it is still untracked. Check Monolith is up (it was down while this plan was written: ECONNREFUSED). | Checklist with go/no-go per item |
| **P1 Maths** | `MarsDrip.ush` (clock), `Mars_DripSchedule.as`, `Mars_DripTypes.as`, `water_spec.py`, `drip_reference.py`, `check_drip_parity.py`, 4 DripSchedule tests | `--test-pattern DripSchedule` green; parity clean; space-time sheets |
| **P2 Drops + decal proof** | `build_meshes`, `Water_Mars_PhysMat`, `MarsWet.ush` (drop, splash, rings, puddle), `Droplet_Mars_M`, `DripImpact_Mars_M`, `PuddleWet/Gloss_Mars_M` + MIs; **mesh-decal-on-ISM check first** | Instruction budgets logged; frozen-time sheet; `WATER_TIMING_OK`; ring-sync probe passes |
| **P3 Hand actors** | `AMars_DripLeak` (layouts, presets, trace cache, Air), `AMars_Puddle`, `AMars_StillWater` + `StillWater_Mars_M`, tests | `--test-pattern Drip`/`Puddle`/`StillWater` green; leaks dressed in the lookdev map |
| **P4 Remaining looks** | `WetStreak_Mars_M` + `AMars_WetStreak` (+ leak streak), `StillWaterDeep_Mars_M` (SLW), the SLW ring-decal check (fallback ring card), lighting rules in `README.md` | WetStreak test green; sewer and cistern sheets reviewed by Stephen |
| **P5 PCG** | `mars_water_pcg.py`, 4 `DripVolume_*` presets, `verify`, `place_volume`, `audit_pcg_hosts`. If D1 = commit: `AMars_DripField` + `DripField_Mars_PCG` + the gated test spike. 5b (optional): `AMars_DripSource` markers. | `WATER_PCG_OK`; a volume regenerates deterministically; persistence check |
| **P6 Dress + perf + gate** | Dress BrokenCistern, a sewer corner, the ossuary; perf capture; tune culls; full gate | Measured numbers recorded; full gate shows no new reds |

| # | Risk | Mitigation |
|---|---|---|
| R1 | **PCG enablement is local-only** (uncommitted `Mars.uproject` hunk). PCG graph assets and an AS `UPCGComponent` would break on other checkouts and red the gate. | D1 at P0. Only `Mars_DripField.as` names a PCG type, and it is written only after a commit. Every other file, test and the stock-volume path work either way. Hand leaks need no PCG at all. |
| R2 | Mesh decals on ISM (or on Nanite kit floors) do not render or do not read PICD | First P2 check. Fallback: projected `UDecalComponent` puddles and rings with `DecalColor` sync floats, spawned by `AMars_Puddle` or PCG Spawn Actor (`NoMerging`). Batching is lost and the budget is re-measured. |
| R3 | A kit master has `MDR_None`, or kit HISMs do not receive decals | P0 audit; fix in the kit builder, never by hand |
| R4 | Kit ceilings or floors lack collision, so rays miss | Complex traces; `verify()` prints hit counts; spline lines and hand leaks as the fallback |
| R5 | Puddles read matte under capture-only lighting | Deep gloss opacity ≥ 0.95 with roughness 0.03; a capture per room; `SourceRadius ≥ 8 cm`; review with and without the capture |
| R6 | `.ush` and AS constants drift | `check_drip_parity.py` at commit; golden-table test |
| R7 | The slot cap lowers fast rates on long falls | Documented cap (§3.2); `EffectiveRate` readout; Stream mode for fast leaks; `MARS_DRIP_SLOTS` can go to 6 later (+2 instances per strand) |
| R8 | Translucent overdraw or sorting spikes | Drop-sized cards; idle slots collapse; cull and fade; coverage caps; SceneColor static switch |
| R9 | No TAA, so 1-3 px drops shimmer | Analytic SDF AA, minimum-pixel clamp with alpha compensation, no dithering |
| R10 | World Partition cells unloaded during a construction trace | "A miss never overwrites a cached hit" plus Locked mode |
| R11 | The second editor holds stale materials, or save-while-open | In-place rebuild only; build when Stephen's editor is idle or closed (memory notes) |
| R12 | SLW does not receive DBuffer rings | P4 check; translucent ring-card fallback over the water |
| R13 | PCG logs in game worlds | No headless PCG test unless the spike proves it is clean; PCG checks stay in editor Python |
| R14 | Python cannot reach `PCGGraphFactory` | Duplicate a hand-made empty graph asset and rebuild it in place |
| R15 | Hot reload re-instances `AMars_DripField` and orphans PCG output | Regenerate button; workflow note: regenerate after a structural script reload |

---

## 11. Decisions for the user

| # | Decision | Recommendation |
|---|---|---|
| D1 | Commit **just the PCG plugin hunk** of `Mars.uproject` (staged with `git add -p`, without the other local changes)? Or keep PCG local-only? | **Commit the hunk.** It unlocks `AMars_DripField` (designer knobs, rib splines, Regenerate/Bake) and makes PCG graph assets load for everyone. Without it, only stock volumes with preset graphs work, and only on machines that enable PCG locally. |
| D2 | Default drop shading: lit forward translucency, or unlit with Warm/Cold MIs? | **Lit** (no per-room tuning). Unlit stays available as a static switch if the forward light loop costs too much in dense rooms. |
| D3 | Cistern water: Single Layer Water (moss-dark absorption, extra composite pass) or the cheap opaque master everywhere? | **SLW for cisterns, opaque for basins**, pending the P4 ring-decal check. |
| D4 | SceneColor refraction on drops (one scene-colour copy per frame)? | **On**, re-decided from the P6 measurement. |
| D5 | Asset folder and suffix: `/Game/Mars/Environment/Dressing/Water/` and `_Mars_PCG` for graphs. | Accept, or name a different PCG suffix now, before the first asset is saved. |
| D6 | Build the optional `AMars_DripSource` markers (P5b)? | **Defer.** `AMars_DripLeak` attached to `SOCKET_Drip` covers pipe joints. |

---

## 12. Rejected alternatives

- **Full-length strand card per drip:** shades its whole length every frame (about 70× the pixels of drop cards), and a
  cylindrical billboard collapses when you look up the strand.
- **Niagara for ambient or hero drips:** a tick and a system per source, no instancing across systems, and sync rests on
  matching `Engine.Time` to material time. Drop cards already read from below. Not what was asked.
- **GPU particles with depth-buffer collision:** they fail when the floor is off-screen, cannot fire rings without extra
  plumbing, and the impact plane is already known from the trace.
- **Masked or dithered drops:** they alias badly with no TAA (`r.AntiAliasingMethod=0`).
- **Single-layer DBuffer puddle:** one opacity per target forces "glossy = near black".
- **Wetness layer inside the kit masters (MF_Mars_Wetness):** it touches every kit master and cannot carry per-drip ring
  data. Possible later for global damp, not for puddles.
- **Per-decal MIDs:** construction-script MIDs don't serialise dependably and add objects. `DecalColor` and CPD serialise.
- **Data-asset presets:** level references to script `asset` objects are fragile across recompiles. Enum plus ApplyPreset
  instead.
- **CkUsf looks for these masters:** CkUsf connects every decal output pin (no two-layer split), has no SceneColor or
  DecalColor input and no PICD-then-CPD fallback, and warns under `-nullrhi`.
- **Visibility-channel PCG raycasts:** PCG queries by object type, so they would hit nothing.
- **Actor-tag water detection:** it needs two down-rays in PCG. The physical material needs one, and the AS trace shares it.
- **Blender meshes for the cards:** the vertex shader places every vertex from UV0, so a duplicated engine Plane is enough.
- **Headless PCG AutoTests by default:** game-world PCG logging under `-nullrhi` is unproven. They stay editor checks until
  a spike proves otherwise.
- **`constants_drip` namespace:** violates the `utils_<feature>`-only rule. Enums instead.
- **Dynamic Merge pins from Python:** not needed (the `In` pin takes multiple connections) and not reachable
  (`OnUserAddDynamicInputPin` is not a UFUNCTION).
