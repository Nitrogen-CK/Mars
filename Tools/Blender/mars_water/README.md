# Mars drips, droplets, puddles and wet surfaces

Spec: `Tools/Environment/DRIPS_PLAN.md`. Every moving part (bead swelling, drop falling and accelerating, splash, rings,
rain rings) is closed-form shader maths of game time in `Shaders/Water/MarsDrip.ush` (the clock) and
`Shaders/Water/MarsWet.ush` (the looks). Script and PCG only lay strands out and pack their custom data.

## Pieces

| Where | What |
|---|---|
| `Shaders/Water/MarsDrip.ush` | the drip clock (constants, hash, drag fall and its inverse, release / skip / impact, slot resolve, bead growth) |
| `Shaders/Water/MarsWet.ush` | drop / bead / thread / stream / splash cards (VS + PS), impact rings, rain rings, puddle shape, wet streak, still water |
| `Script/WorldObjects/Dressing/Water/` | `AMars_DripLeak`, `AMars_Puddle`, `AMars_StillWater`, `AMars_WetStreak`, the types, the AS mirror of the clock (`FMars_DripSchedule`, `utils_drip`) |
| `Script/Tests/Drips/` | DripSchedule (pure maths, golden table), DripLeak, Puddle, WetStreak, StillWater autotests |
| `water_spec.py` | names, folders, slot orders (= AS enums = PCG packer orders), presets |
| `drip_reference.py` | plain-Python clock: `--selftest`, `--golden` (the AS test's table), `--predict`, `--sheet` |
| `check_drip_parity.py` | `.ush` constants vs AS mirror vs water_spec, slot enums, packer orders: `DRIP_PARITY_OK` |
| `check_water_captures.py` | ring-sync and timing checks on the frozen-time captures, contact sheets |
| `unreal/mars_water_ue.py` | meshes (engine Plane duplicates), `Water_Mars_PhysMat`, the 7 masters (built in place) and 12 instances, `verify_materials` |
| `unreal/mars_water_pcg.py` | the 4 `DripVolume_*_Mars_PCG` graphs for stock PCG volumes, `verify`, `place_volume`, `audit_pcg_hosts` |
| `unreal/mars_water_review.py` | `WaterLookdev_Mars_MAP` (sewer, cistern, ossuary bays + probe), captures, frozen-time frames, ring / timing probes |

Run editor modules through `Tools/Blender/mars_environment/unreal/env_drive.py` on a hidden editor of your own
(`--port 9318 --launch`, logs to `Saved/Logs/HiddenEnv_9318_Mars.log`), never on Stephen's 9316 while he works.

## Custom-data contract

Drop cards (`Drops` ISM, 8 floats): Length (cm, < 0 = Air), Rate, Seed, Jitter, Mode, Slot (0..3 drops, 4 bead, 5 thread),
DropScale, Surface (0 floor, 1 water, 2 dry, 3 air). Rings (6): the strand's 0..4 bit for bit, then RingAmp. Puddles (4,
both layers): Seed, Wetness, RainRate, Aspect. Still water (CPD defaults, 5): SizeX, SizeY, Seed, Murk, RainRate.
Every master reads per-instance data with the matching custom-primitive-data scalar as the default, so a plain
static-mesh component with CPD works too (a one-off bead: CPD = 0, 0, seed, 0, 3, 4, 1, 0).

## Designer workflow

- **A leak:** place *Mars Drip Leak*, pick `Preset`, press **ApplyPreset**, tweak. It traces up to the ceiling and down
  to the floor or water on every edit; a miss never overwrites a cached hit; `Trace.Mode = Locked` freezes it.
  On a wall, +X points out of the wall and `Streak.OnWall` projects a damp / rust streak.
- **Room drips (PCG, local only):** place an engine *PCG Volume* over the room, Graph = `DripVolume_<Preset>_Mars_PCG`,
  **GenerationTrigger = GenerateOnDemand**, Generate. Or `mars_water_pcg.place_volume(centre, extent, preset)`.
  PCG is enabled only in a local `Mars.uproject` change (decision D1): these graphs load only where PCG is enabled, and
  no AngelScript names a PCG type.
- **Pools:** *Mars Still Water* at the water line, sized to the pool; `Deep` = Single Layer Water (cistern).
- **Puddles without drips:** *Mars Puddle*. **Damp patches:** *Mars Wet Streak*.
- **Judge timing:** set an instance's `DebugTime`, or `r.Test.OverrideTimeMaterialExpressions <t>`.

## Lighting rules for wet rooms

Mars has no SSR / Lumen reflections (`r.ReflectionMethod=0`). In the editor-world SceneCapture lookdev the reflection
captures did not show in water at all (water and puddles reflected only point-light speculars), so the drips sell
through lamps: put a lamp (SourceRadius >= 8 cm) where its mirror image lands in the pool or puddle near the impacts,
and keep a Box Reflection Capture per room for the game view. Drops carry a display-referred sparkle rim
(`SparkleStrength`) so they read in any room.

## Traps found while building

- `MTP_BeforeDOF` translucency does not show in SceneCapture2D: the drop master uses After DOF.
- A Custom node's extra output fed into a VertexInterpolator was not trusted: the drop master calls `MarsWet_DropVS`
  from three Custom nodes (WPO, I0, I1).
- `recompileshaders changed` does not see `/Project/Water/*.ush` edits: recompile the masters
  (`unreal.MaterialEditingLibrary.recompile_material`). A Custom node's AdditionalDefines do not reach the include.
- AS cannot read `PerInstanceSMCustomData` or `CustomPrimitiveData`: the actors keep a mirror of what they write for tests.
- PCG raycasts drop hits whose response to the queried channel is not Block: the still-water probe blocks WorldStatic.
- PCG selectors need `import_text("PCGBegin(ImpactNormal.Z)PCGEnd")`; `UPCGGraph.remove_nodes` takes its array by
  reference (Python sees no argument): remove nodes one by one.
