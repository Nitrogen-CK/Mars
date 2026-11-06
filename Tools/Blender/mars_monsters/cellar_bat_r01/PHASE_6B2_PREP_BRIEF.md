# Phase 6b-2 prep brief - AnimBP build route on the blockout skeleton, bat-tracking PIE captures, route-stamp test

Read `PROGRESS.md` (Phase 6a, 6b-1 and both audits), then the code: `Script/ECS/Bat/`,
`Script/WorldObjects/Monsters/Mars_CellarBat_EntityScript.as`, `Mars_CellarBat_AnimInstance.as`, `Mars_SandboxBat.as`,
`Script/Tests/Bat/`, `Tools/LevelDesign/cellar_bat_r01_review/cellar_bat_review_ue.py`. The editor is open under a
Visual Studio debugger (an engine ensure breaks into VS; if the editor freezes with all threads waiting, report and
wait - never kill it). Monolith: confirm the project path before any write; PIE off before you finish; writes only under
`/Game/ArtCandidates/CellarBat/R01/` and the Script/Tools files named here. The final mesh and 18 clips are not ready;
this phase builds the reusable tooling on the Phase 2 blockout assets in `/Game/ArtCandidates/CellarBat/R01/Validation/`
(`CellarBat_R01_Blockout_Mars_SK`, `_SKEL`, clip `CellarBat_R01_Blockout_Flap_Mars_ANIM`).

## Work

1. **AnimBP builder script** `Tools/LevelDesign/cellar_bat_r01_review/cellar_bat_animbp_ue.py`, run through
   `editor_query run_python`, driven by a JSON clip manifest `{clip name -> asset path}` so the same script builds the
   final AnimBP later. It must: create (or rebuild idempotently) `/Game/ArtCandidates/CellarBat/R01/Animation/
   CellarBat_R01_Mars_ABP` on the given skeleton with parent class `UMars_CellarBat_AnimInstance`
   (`/Script/Angelscript.Mars_CellarBat_AnimInstance` - verify the exact class path via `unreal.load_class`), a state
   machine with states RoostIdle, RoostAlert, Launch, Locomotion (Hover/FlyForward blended by Speed, Glide above a
   speed threshold), Telegraph, Swoop, Recover, Brake, Perch, Screech, Hit, Stun, DeathFall, DeathLand, transitions
   driven by the AnimInstance's `Phase` (and `IsFlying`/`SwoopAlpha` where useful) with settle-friendly blend times,
   and an apply-additive layer for BankLeft/BankRight weighted by `BankAlpha` (negative = left) over the locomotion
   pose. Use Monolith `animation_query` actions (`create_anim_blueprint`, `build_state_machine`/`create_state_machine`,
   `add_state_to_machine`, `set_state_animation`, `add_transition`, `set_transition_rule`, `add_apply_additive`,
   `add_variable_get`, `connect_anim_graph_pins`, `set_additive_settings`, `auto_layout`, `get_abp_info`...) or
   `unreal` Python where Monolith lacks an action - read each action's schema with `describe_query action_schema`
   first. For this prep run, every state uses the one flap clip (and the additive banks use it too after
   `set_additive_settings` makes an additive copy via `duplicate_sequence`), so the graph compiles and plays. Compile
   the ABP, read back `get_abp_info` and save ONLY the new assets. Record the exact Monolith calls that worked in the
   script's docstring.
2. **Wire it:** `Mars_SandboxBat.as` review preset sets `AnimClass` to the new ABP class (`..._ABP_C`) instead of
   `LoopClip`; keep `LoopClip` as the fallback. Push the AnimInstance variables every frame (already done in 6a - verify
   `BankAlpha` is derived from `SignedTurnRate` with a clamp and smoothing, and `SwoopAlpha` from the ledger).
3. **Bat-tracking captures:** in `cellar_bat_review_ue.py` add a chase camera that follows the bat (a CameraActor
   updated from the bat's location each frame by a tick in run_python/PIE, or a spring-arm camera attached to the bat's
   presentation node in the entity script when a `ReviewCamera` flag is set) and use it as the view target for
   `capture_pie_movement_clip` / `capture_scene_preview` so the bat fills at least a quarter of the frame. Produce:
   `captures/pie8_tracked_cycle/` (full Roost -> Swoop -> Perch), `captures/pie9_tracked_swoop/` (close), and
   `captures/pie10_tracked_death/`. Confirm by LOOKING at frames (Read) that the wings move between frames; name the
   frames that show the flap, the swoop contact, and the landed corpse. The `InRHITexture` ensure may break into VS on
   the first viewport read: if the editor freezes, report to main and wait.
4. **Headless test for the route-generation stamp:** add `Script/Tests/Bat/Mars_AutoTest_Bat_StaleRouteAnswerIsIgnored`
   (a Reached/Failed answer carrying an older generation does not change the current route's outcome; the rig can push a
   `FMars_Request_Bat_RouteResult` with an explicit old generation). Run `--test --discover-fresh --test-pattern
   Mars_AutoTest_Bat_` and `--test-pattern Monster` (quiescence protocol; PowerShell, background, long timeout) and
   record exits.
5. Update `PROGRESS.md` (Phase 6b-2 prep section): the ABP structure readback, the Monolith call list, test exits,
   capture paths with the frame numbers that prove motion, open items.

## Rules

Same as Phase 6b-1: no git state changes, no Save All, no `run_console_command` level ops, no edits to the Blender track
folders, no `AutomationGate.json` edits, never add known reds. Report exactly: files, commands and exits, ABP readback
summary, capture frames that prove the flap/swoop/death, and what is unverified.
