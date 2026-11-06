# Phase 4 brief - all 18 animation clips, baked to the export skeleton, reviewed in motion, exported one FBX per clip

Read `PROGRESS.md` (Phases 2, 3, 3b: the rig controls, the fold/fan/ear/jaw/perch sliders, the bake and export
scripts), the prompt's Phase 4 section in `docs/art/flying-units-r01/MODEL_ANIMATE_IMPORT_PROMPT.md`,
`PRODUCTION_SPEC.md` section 4, `ANIMATION_LIST.csv` (authoritative names, fps, frame ranges, loop flags, event
intent) and LOOK at `04-animation-poses.png` and `03-wing-rig-and-expressions-v2.png` (Read tool). Work only under
this folder (`scripts/`, `source/`, `export/`, `review/phase4/`); background Blender only; no git state changes; no
Unreal writes.

## Deliverable

1. `scripts/animate_cellar_bat.py`: a reproducible authoring script that creates every control-rig action listed
   below (keys on `CTL_*` controls and sliders, 30 fps, the CSV's frame ranges), then bakes each to the export armature
   with `scripts/bake_cellar_bat.py` into an export action of the clip's exact name, and saves the scene. Keep a small
   pose library in the script (the Phase 3 pose actions are a start: Spread/Up/Power/Down/Recover/HalfFold/Wrap/Hang/
   Banks) and build clips from poses + timing + per-control offsets; no hand-typed keyframe soups.
2. The 18 clips, exactly these names and ranges (frames inclusive, 30 fps):
   `RoostIdle` 0-60 loop, `RoostAlert` 0-18, `Launch` 0-24, `Hover` 0-15 loop, `FlyForward` 0-15 loop, `Glide` 0-30
   loop, `BankLeft` 0-0 additive pose, `BankRight` 0-0 additive pose, `Brake` 0-18, `Perch` 0-24, `Screech` 0-24,
   `SwoopTelegraph` 0-18, `Swoop` 0-18, `SwoopRecover` 0-18, `Hit` 0-12, `Stun` 0-30 loop, `DeathFall` 0-21,
   `DeathLand` 0-18.
   - Loops: frame 15 (or last) == frame 0 in pose AND matching tangents; the exporter must not double-hold the seam
     (export 0..N-1 samples with the seam frame equal to frame 0, and say which convention you used so the Unreal
     importer's frame count is predictable: document "16 samples, frame 15 duplicates frame 0" or "15 samples" and
     stick to it for every loop).
   - The flap cycle (Hover, FlyForward): keys at 0/4/8/12/15 = high V upstroke, power stroke through horizontal, deep
     downstroke, bent-wrist reduced-area recovery, back to high V; exaggerate elevation and wrist fold until the 3D
     cycle reads as a full beat. Membrane drag (fingers lag the wrist by 1-2 frames), chest/pelvis response, ear
     overlap, feet trailing. FlyForward is the same cycle with the body pitched forward and a slightly flatter
     downstroke.
   - Glide: spread with subtle finger flex and a slow 1 s breath.
   - BankLeft/BankRight: ONE frame each, authored as the full pose (body roll toward the bat's own left/right ~25 deg,
     inner wing dropped, outer wing raised, head counter-rolled). Export them as full poses; record in PROGRESS.md and in
     the manifest that the additive reference pose is `Hover` frame 0 (the Unreal importer sets them additive against
     that reference). Do not fabricate motion.
   - RoostIdle: wrapped and inverted (the Phase 3b hang), feet planted, quiet breathing on spine/pelvis, one ear
     twitch; seamless loop. RoostAlert: partial unwrap + head turn toward +X. Launch: feet release (root stays!),
     body rotates from inverted to flight attitude via pelvis/spine, wings unfurl into the first downstroke; a
     `ReleaseContact` marker frame recorded in the manifest. Brake: wings cup forward, feet drop and reach. Perch:
     reach, grip (feet to the perch control), rotate to hanging, wrap; `FootContact` marker frame recorded. Screech:
     jaw open, ears back, wings braced; `ScreechSound` near frame 9. SwoopTelegraph: rear-up windup. Swoop: tuck and
     extend, visual contact near frame 9. SwoopRecover: open and pull out. Hit: asymmetric recoil, interruptible.
     Stun: unsteady hover with flattened ears, loop. DeathFall: limp collapse (the runtime moves the body). DeathLand:
     impact and settle into a final pose.
   - The world root never moves in any clip (assert it in the bake: root translation/rotation keys all identity).
   - No animated scale.
3. Review in motion: for every clip render a 4-up contact sheet (`review/phase4/<Clip>_sheet.png`) and an MP4 or image
   sequence at real time (`review/phase4/<Clip>/frame_###.png`); for Hover, Launch, Perch, Swoop and RoostIdle also a
   half-speed sequence. LOOK at them (Read) and fix one visible issue per round. Run the intersection audit
   (`bat_audit.py`) on every frame of every clip; the table (membrane-body, membrane-legs, left-right, ribs-body) must
   be zero everywhere except the hanging/wrap attachment contacts you document.
4. Export: one FBX per clip (`export/anims/CellarBat_R01_<Clip>_Mars_ANIM.fbx`) with the proven recipe
   (`bake_anim_use_all_actions=False`, `bake_anim_use_nla_strips=False`, only the one action, export armature + mesh
   or armature-only - say which and keep it stable), plus the bind mesh and LODs re-exported from the final scene
   (`export/CellarBat_R01_Mars_SK.fbx`, `_LOD1_`, `_LOD2_`). Write `export/CellarBat_R01_Manifest.json`: versions,
   dimensions, axis/unit settings, tri/vertex counts per LOD, bones+parents, slots, morphs (none), clips with name /
   fps / frames / samples / loop / markers / source action, additive reference pose, export paths, intended Unreal paths
   (`/Game/ArtCandidates/CellarBat/R01/Meshes/CellarBat_R01_Mars_SK`, `_SKEL`, `_PHYS`,
   `/Game/ArtCandidates/CellarBat/R01/Animation/CellarBat_R01_<Clip>_Mars_ANIM`, `/Game/ArtCandidates/CellarBat/R01/
   Materials/CellarBat_R01_<Slot>_Mars_MI`).
5. Round trip: extend `scripts/validate_roundtrip.py` to import every clip FBX into a fresh scene and check bone set,
   frame count, root stationarity, loop seam equality, and sampled landmarks (wing tips at the flap keys) against the
   authored values; write `export/anims/roundtrip_report.json`.
6. `PROGRESS.md` Phase 4 section: commands, the clip table (name, frames, samples, loop seam check, markers, audit
   result), what you looked at and fixed, deviations from the CSV (none expected), open risks.

Report: files, rerun commands, the clip table, the audit table, round-trip results, the contact sheets to look at,
and what remains unverified.
