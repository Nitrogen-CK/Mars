# Phase 6b-2 brief - final AnimBP on the final assets, full PIE review, focused gates, final evidence

Read `PROGRESS.md` end to end (phases, audits, incidents I-1..I-3 and the operating rules they produced: never
delete / force-delete / reload a Blueprint or package the live editor has loaded; PIE compiles every dirty Blueprint;
no `run_console_command` level ops; sockets only via Monolith `add_socket`; no raw `SkeletalMesh.add_socket`). Read
`PHASE_6B2_PREP_BRIEF.md` and the prep results (`Tools/LevelDesign/cellar_bat_r01_review/cellar_bat_animbp_ue.py`,
its docstring of working Monolith calls, `cellar_bat_review_ue.py` with the chase camera), the runtime code under
`Script/ECS/Bat/`, `Script/WorldObjects/Monsters/Mars_CellarBat_*.as`, `Mars_SandboxBat.as`, `Script/Tests/Bat/`, and
the Phase 5 readback `export/unreal_readback_final.json` (final assets under `/Game/ArtCandidates/CellarBat/R01/`:
`Meshes/CellarBat_R01_Mars_SK`, `_SKEL`, `Physics/CellarBat_R01_Mars_PHYS`, `Materials/CellarBat_R01_<Slot>_Mars_MI`,
`Animation/CellarBat_R01_<Clip>_Mars_ANIM` x18 with the banks additive against Hover frame 0).

## Work

1. **Final AnimBP** on `CellarBat_R01_Mars_SKEL` from a manifest mapping every state to its real clip (RoostIdle,
   RoostAlert, Launch, Hover/FlyForward/Glide in the Speed blend space, SwoopTelegraph, Swoop, SwoopRecover, Brake,
   Perch, Screech, Hit, Stun, DeathFall, DeathLand; BankLeft/BankRight additive on `BankLeftAlpha`/`BankRightAlpha`).
   Name: `CellarBat_R01_Mars_ABP` if that path does not exist on disk or is not loaded in this editor session;
   otherwise build `CellarBat_R01_Final_Mars_ABP` and record why (the prep ABP on the blockout skeleton may be
   loaded; never delete it live). Loop flags: RoostIdle, Hover, FlyForward, Glide, Stun loop; everything else plays
   once and holds its last frame (DeathLand) or hands back to the kernel phase. Give Screech a way to play: add a
   `Screeching` presentation phase to the kernel (`EMars_Bat_Phase`, set by the Alert task for the first
   `Spec.Roost.AlertSeconds` or by Telegraph entry - pick one, document it; keep it a presentation-only phase that
   the kernel accepts from `Request_SetPhase`). Fix the bank: diagnose why `BankAlpha` stayed 0 in the prep PIE
   (does CkCrowd's `FaceAngle3D` write the root yaw? does `Telemetry.SignedTurnRate` read it? is the smoothing rate
   eating it?) and make the banks visibly engage on the review route's turns; if the crowd agent does not yaw the
   root, derive the turn rate from the velocity heading change in `TickTelemetry` and say so. Clamp the death-fall
   velocity seed (`State.Fall.Velocity = Telemetry.Velocity` clamped to `Flight.SwoopSpeed`).
2. **Wire the candidate** (`Mars_CellarBat_EntityScript.as` defaults and the review preset): final mesh, final ABP,
   physics asset from the mesh, sockets `Mouth` (swoop sweep start, replacing `MouthOffset` when present) and the
   perch contact sockets for the hang alignment (`Get_HangPoint` may offset by the socket), LOD screen sizes and the
   extended bounds from Phase 5. Keep `LoopClip` as the no-ABP fallback.
3. **Focused gates (test-only path, quiescence protocol):** `--test --discover-fresh --test-pattern
   Mars_AutoTest_Bat_` and `--test-pattern Monster`; exits and names into PROGRESS.md. No full gate. Never add
   known reds.
4. **Real PIE review** on the review map with the final assets, through Monolith (`start_pie`/`run_pie_smoke`,
   `capture_pie_movement_clip` with the chase camera; the `InRHITexture` ensure may break into VS on the first
   capture - if the editor freezes, report to main and wait; never kill it). Capture, LOOK at, and name frames for:
   neutral and amber/teal lighting on the final materials; both membrane sides; deep wing extremes (Hover down
   frame, upstroke); the full wrap in RoostIdle and the feet on the perch; Launch and Perch transitions; banks on a
   turn; FlyForward -> Glide blend; Telegraph -> Swoop -> Recover with the contact; Hit and Stun (apply damage below
   and above `StunDamage` through run_python on the bat's Health); DeathFall -> DeathLand (kill mid-flight) and the
   corpse holding its last frame; LOD switching (force LOD via `r.SkeletalMeshLODBias` or a far camera) and bounds
   (no wing clipping at the frustum edge during the downstroke). Record the phase timeline and the hit count (one per
   landed swoop) from the `[CellarBat]` log lines. Stop PIE, confirm PIE off, 0 dirty packages, Sandbox map restored.
   Save only the new ABP (and the blend space / additive assets it creates).
5. **Asset manifest** `export/CellarBat_R01_AssetManifest.json`: every Unreal package path under the candidate root
   with its class and what produced it (Phase 5 importer, ABP builder, review map builder), plus the source paths.
6. `PROGRESS.md` Phase 6b-2 section: everything above with commands, exits, frame names, and the remaining
   limitations (multiplayer not addressed, packaged build not tested, no performance claim).

Rules: no git state changes; no edits outside `Script/ECS/Bat/`, `Script/WorldObjects/Monsters/Mars_CellarBat_*.as`,
`Mars_SandboxBat.as`, `Script/Tests/Bat/`, `Tools/LevelDesign/cellar_bat_r01_review/`, the owned Unreal root and
PROGRESS.md/export manifest; no `AutomationGate.json` edits; the Blender folders are read-only for you. Report: files,
commands and exits, ABP readback, the PIE evidence frames per item, the bank diagnosis, and what remains unverified.
