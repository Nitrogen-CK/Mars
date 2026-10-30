# Vines and roots: authoring contract

The generator behind `AMars_Vine`, `AMars_VinePcg` and `AMars_HeroRoot`. The design and its reasoning are in
`Tools/Environment/VINES_PLAN.md`; this file is what a designer or a programmer needs to use and extend it.

## Files

| File | What |
|---|---|
| `Mars_Vine_Types.as` | Enums (layouts, ends, path kinds, streams), the shape knobs, the cached solve (`FMars_Vine_Solved`), the query structs, the per-actor budgets. |
| `Mars_VineProfile.as` | `UMars_VineProfile` (data asset), `Validate()`, `Get_SolveSignature()`, `utils_vine::Fill_Preset` (the six presets' numbers). |
| `Mars_Vine_Solve.as` | `FMars_Vine_Solver`: traces, the surface walk, the six layouts, Ground / Air ends, branches, tendrils, smoothing, resampling, the twin-strand twist. The request's `Validate()` and the worst-case budget estimate. |
| `Mars_Vine_Emit.as` | `FMars_Vine_Emitter`: spline-mesh roots, instanced stems, leaves, knots, tips, strand cards, litter. No traces. |
| `Mars_Vine.as` | `AMars_Vine` (placeable) and `AMars_VinePcg` (the class PCG spawns). |
| `Mars_HeroRoot.as` | `AMars_HeroRoot`: Top + n x Mid + Flare modules stacked to the traced floor. |
| `Script/Editor/Mars_VineCommands.as` | `Mars.Vine.SeedProfiles [force]`, `Mars.Vine.ReattachAll`, `Mars.Vine.Report`. |
| `Script/Tests/Vine/` | `UMars_AutoTestRig_Vine` and 14 tests (engine shapes only). |
| `Tools/Blender/mars_environment/build_env_vines.py` + `env_vines_parts.py` | The meshes (family `vines`). |
| `Tools/Blender/mars_environment/unreal/mars_vine_ue.py` | Vine material instances, profiles, the four PCG graphs, `VineGym_Mars_MAP`, captures. |

## Placing a vine

1. Drop `Mars_Vine`. Pick `Profile` (unset in the editor world: `VineIvy_Mars_DA`), `Layout` and `End`.
2. Layouts:
   - **Spline**: shape the `Guide` spline. Its samples within `Attach.ClingRadiusCm` of a surface cling to it (fully
     inside half the radius), the rest stay where the guide is. A free last point gets the end treatment.
   - **Creep**: the actor near a wall or pipe; stems climb `Shape.HeightCm` (400 by default) up the nearest surface,
     fanned +-35 degrees when `StrandCount` > 1. Ground: the stem first creeps down to the floor and along it.
   - **Drop**: under a ceiling (found within 300 cm above the actor). Roots bury their top and flare fingers over it.
   - **Curtain**: the actor 30 cm past a lip, +X pointing out, local Y along the edge. Strands start on the top, wrap the
     lip, creep down the face and hang where it ends.
   - **Wrap**: at a pier or pipe base; coils `Turns` round the actor's local Z (rotate the actor for a horizontal pipe).
   - **Patch**: under an arch or vault; clumped strands over a disc of `PatchRadiusCm`.
3. **End = Ground** reaches the floor, fillets onto it, creeps along it in its most open direction and (roots) forks
   into fingers. **Air** stops inside the profile's clearance band (or at a fraction of the floor distance), the last
   15 % curling. `Shape.GroundShare` mixes the two per strand (below 0 it follows End).
4. `Seed` 0 derives from the position, so Alt-drag copies differ. **Reseed** writes a new seed.

The solve is cached on the actor (`Solved`, keyed by a hash of the profile's solve fields, the layout, shape, seed,
transform and the guide). A rerun with the same inputs traces nothing, so loading a level never re-solves. **The room
changing never re-solves a vine on its own**: press **Reattach** (or run `Mars.Vine.ReattachAll`). **Freeze** keeps the
solve whatever moves. Swapping a mesh or a material in the profile re-emits without re-tracing.

`Status` reads `N traces, N paths, N segments, N chords, N leaves, N cards, solved|cached`.

## Budgets (per actor)

The editor stops a construction script after 1 s, so `Validate()` rejects a request whose worst case (estimated for a
1050 cm, three-storey drop) is over: 3000 traces, 64 spline segments, 4000 leaves, 1500 cards, 3000 stem chords. The
solver and the emitter also stop at those counts at runtime, so a taller room is capped, never stalled. Errors name the
knob to turn.

## Profiles

`/Game/Mars/Environment/Dressing/Vines/Profiles/Vine<Preset>_Mars_DA`, written by `Mars.Vine.SeedProfiles force`
(it refills the numbers and binds the kit meshes; a kit mesh that is missing falls back to an engine shape and says so).
Duplicate one to make a variant. `Validate()` names the first bad field.

| Preset | Stem | Notes |
|---|---|---|
| Ivy | instanced chords (VineStemIvy), leaves A/B/C | branches every ~35 cm, tendrils on air tips, leaf shadows off |
| GiantRoot | spline mesh (VineBark A/B), knots, tip | two strands twisting (pitch 500, 72 cm segments), 48 cm radius, leaning up to 2.2 m (`Attach.Meander.LeanCm`) with an 80 cm wander, ground fingers 3-4, ceiling fingers 2-3 |
| ThinRoot | spline mesh | fingers 2-3, air clearance 40-180 cm |
| HangingMoss | cards (VineMossStrand A/B/C) | 6 / m2, clumped, 6 - 30 % of the floor distance, max 300 cm |
| Rootlets | cards (VineRootlet A/B) | ground: reach the floor plus a coil; litter (DeadLeaves_Scatter_A) at 30 % of contacts |
| Cobweb | cards (VineCobweb_A), `VineCobweb_Mars_MI` | 3 / m2, 40 - 110 cm, 1.0 - 1.7 wide |

Leaf shadows are off by default: script cannot set `ShadowCacheInvalidationBehavior = Rigid` on a created HISM, so
swaying leaves would invalidate their virtual shadow map pages every frame. Turn `Rendering.Shadows.Leaves` on per
profile where the cost is acceptable.

## Custom data: four floats, zero-neutral

Both dressing masters read `PerInstanceCustomData(i)` with its default from the Custom Primitive Data scalar
`Env Data i`. A primitive without custom data reads 0 for both, so **every slot is an offset whose 0 is neutral**: every
prop placed before the generator, and any merge bake that drops per-instance data, looks unchanged.

| Master | 0 | 1 | 2 | 3 |
|---|---|---|---|---|
| `EnvPaint_Mars_M` (bark, stems, knots, tips, hero roots, moss pads) | VarSeed [0, 1) | MossAdd = MossScale - 1 | WetAdd [0, 1] | 0 |
| `EnvFoliage_Mars_M` (leaves, strands, litter) | VarSeed | Dryness [0, 1] | WindAdd = WindWeight - 1 | LengthAdd = LengthCm / 100 - 1 |

Writers: the emitter (`SetCustomDataValue` per instance; `SetDefaultCustomPrimitiveDataFloatArray` on spline segments,
which serializes), `AMars_HeroRoot`, and the PCG instance packers (`VineUnderside_Mars_PCG` packs
`[VarSeed, Dryness, WindAdd, LengthAdd]`). A strand card is 100 cm; it is stretched to its traced length
(scale z = L / 100) and its sway grows with LengthAdd (`Length Sway` on the master).

## Collision and the Jolt bake

Default: every primitive is NoCollision with the `Ck.Jolt.NoBake` tag (actor and components), so editing a vine never
needs a static-world re-cook. `Collision = On` (or a profile with `Rendering.Collision`) makes root segments BlockAll and
untagged: re-cook the static world after every edit. Spline meshes created at runtime do not cook collision, so tests
never rely on it. `AMars_HeroRoot` collides by default (convex hulls on the modules).

## PCG (local-only plugin)

PCG is enabled only in a local, uncommitted `Mars.uproject` line, so no AngelScript names a PCG type. The PCG layer is
stock `PCGVolume` actors running four graphs built and checked by `mars_vine_ue.build_pcg_graphs()` /
`check_pcg_graphs()` (`/Game/Mars/Environment/Dressing/Vines/PCG/`):

| Graph | Does |
|---|---|
| `VineCurtain_Mars_PCG` | lips of up-facing tops (nothing within 150 cm below a point 30 cm out), carved by actors tagged `Mars.VineExclude`, a site every ~1.8 m, each an `AMars_VinePcg` (Curtain, Air, VineIvy) |
| `VineCeilingRoots_Mars_PCG` | ceiling points, clumped by noise, a second ray down; `LengthCm = ImpactDistance x U(0.35, 0.9)` written to the spawned vine's `LengthOverrideCm` |
| `VineUnderside_Mars_PCG` | moss strands under ceilings and soffits as instances (no actors), length = floor distance x U(0.06, 0.3) |
| `VineSkirt_Mars_PCG` | moss pads and dead leaves at wall and pier bases (falls back to vine meshes while the organic family is not imported) |

Settings are node defaults written by the builder (edit them in the graph, or rerun the builder). A spawned vine gets its
seed and traced length through Spawn Actor property overrides and its look from the Profile of the node's template
actor. Surfaces tagged `Mars.NoVines` are skipped by the first ray of each graph. Volumes are Generate On Demand: press
Generate after a change; PCG never runs in game.

## Hero roots

`AMars_HeroRoot` at the ceiling contact: n = round((H - 180 - 160) / 350) mid modules share one zScale in [0.8, 1.25]
(outside it, `Validate()` names the height: move the root or set `FixedHeightCm`). Mid modules are any variant, yaw 0 or
180, chosen by seed; all modules meet on identical joint loops.

## Meshes (`build_env_vines.py`)

Centimetres, Blender Z up (Unreal local = x, -y, z), colour "Col" = linear albedo + cavity in A, UV1 "EnvData" on leaves
and cards (u = id, v = 0 at the attachment to 1 at the free end).

- Bark segments and stem chords run along +X from 0 to 100 with radius 50; their end rings are one shared profile, so
  any segment meets any other.
- Leaf clusters fan to +X, faces +Z, petiole base at the origin (9 / 14 / 20 cm).
- Cards hang from the origin to z -100.
- Hero modules: top centre pivot, -Z down; joint loops are the tube's exact horizontal slice at the joint height.

The builder checks budgets, slots, colours, UV1, the 100 cm axis, end-ring equality and hero joint loops (< 0.2 cm, also
under a 180 degree flip), prints `ENV_VINES_OK`, and renders review sheets plus a mock room (`vines_sweep_*.png`).
