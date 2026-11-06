# Phase B brief - final look, cavity bake, all 15 clips, exports, round trip, manifest

You are the Opus executor for Phase B of the Screaming Turnip R01 campaign. Read first: `PROGRESS.md` (Phase 1,
Phase A section and the Phase A audit with misses A-1..A-5), `PHASE_A_BRIEF.md`, the package
`docs/art/screaming-turnip-production-r01/` (`DESIGN_TECH_SPEC.md` sections 3-4 and 10 Gate A/B, `ASSET_MANIFEST.json`
`clips`, `ANIMATION_MANIFEST.csv`) and LOOK AT the six PNG sheets (Read tool), especially `04-exaggerated-vocal-cycle.png`,
`03-ground-and-harvest.png`, `06-throw-and-settle.png`. Then the Phase A scripts in `scripts/` (yours to extend) and the
bat precedents `Tools/Blender/mars_monsters/cellar_bat_r01/scripts/animate_cellar_bat.py` (pose library, Catmull-Rom
clip authoring, per-frame audit, `clips.json`), `export_anims_cellar_bat.py` (one FBX per clip, manifest),
`render_anims_cellar_bat.py`, `validate_roundtrip.py` (`check_anims`), `bat_audit.py` (cavity bake).

Blender: `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`, headless only, `--factory-startup`. Keep the
Phase A contract: 17 bones (names/parents exact), `root` identity in every frame of every clip, D-A1 rig rules (identity
rest rotations, body X == Z scale, jaw/crown rotate about Y only), slots `Skin, Leaf, Mouth, Teeth`, scene 1 BU = 1 cm,
30 fps, export recipe verbatim. Rebuild path stays: `build_screaming_turnip.py` (mesh + rig + poses) then
`animate_screaming_turnip.py` (clips) then `export_screaming_turnip.py` then `validate_roundtrip.py`; renders separate.

## Part 1 - look pass on the mesh (fix A-1..A-5, keep the facet style)

1. **Neutral seam = closed X-pucker, no cavity at rest.** The lips meet; from the front the mouth reads as a folded
   cross of creases (a shallow dark crease line is fine, no plum cavity showing). Model the pucker: four lip wedges
   meeting at a centre point with the fold lines running to the corners (the "folded cross-like mouth seam" of sheet
   01), enough loops that the gape can open to the Phase A scream and the pucker can tighten on inhale.
2. **Cheeks = lateral bellows lobes.** Two cream lobes on the bulb's front-lateral surface either side of the seam
   (sheet 04 inhale: they bulge WELL beyond the neutral bulb silhouette - target bulb width at cheek height >= 1.35x
   neutral at full inhale, lobes visible in the front view as two bumps with the pinched centre between them). Move the
   `cheek_l/_r` bone heads to the lobe centres (|y| about 3.0-3.5 cm, forward of the bulb centre), weight the lobe
   geometry to them with a soft falloff into `body`, and make the inhale pose pucker the seam (aperture <= 0.15 cm,
   never a widened bowtie). Keep D-A1 (cheek bones scale uniformly or per-axis without rotation).
3. **Colour transition.** Replace the flat bands with a stepped faceted transition: magenta shoulders, one or two
   facet rows of blended tone whose lower edge zig-zags per facet (random walk +-1 row per column, seeded), into ivory.
   Keep the +-5% per-facet jitter. Judge it on the front/three-quarter renders against sheet 01.
4. **Scream profile.** Lips roll outward on the gape (upper lip lifts and flares, lower lip drops and flares with the
   jaw); no notch biting into the bulb in the side view. Teeth: upper row visible at the scream peak (tips + part of the
   wedge), lower row full, none penetrating lips or cavity.
5. **Leaves.** Thicker angular blades (visible thickness ~0.4-0.6 cm at the midrib), stouter stems; the crown's five
   leaves fan evenly in the top view (sheet 01 TOP). Leaf-vs-leaf overlaps must be 0 in every frame of every clip
   (stagger droop angles / leaf lengths; see A-5).
6. **Cavity bake.** `Col` alpha = per-face occlusion in the NEUTRAL pose (bat recipe: cos-weighted rays, 1 - 0.85*occ,
   floor 0.15); the inside of the mouth cavity dark, lip undersides and leaf roots darker. RGB unchanged.
7. Keep tris in 1.5-3k, 15 closed islands or fewer, 0 defects, max 4 influences, nothing weighted to `root`.
   Re-measure everything from Phase A (`measurements.json`, landmarks, hull, beds) and note what moved.

Iterate with look-and-fix rounds (sheets under `review/phaseB/iterations/rNN_*`), at least one side-by-side per round:
concept crop (sheet 01 FRONT / sheet 04 INHALE / SCREAM) beside the render at the same view. Add an EEVEE three-light
pass (warm key / neutral fill / rim) and a **neutral vs amber-key/teal-fill** comparison (game lighting) for the
neutral, inhale and scream poses. Add one **first-person scale mock**: the neutral and scream poses rendered from a
90-degree-FOV camera 45 cm away at eye height with a 10 cm ruler, to judge readability at hand distance (that is the
design bet; report what you see).

## Part 2 - clips (`scripts/animate_screaming_turnip.py`, saves the blend; `export/anims/clips.json`)

Author every clip in `ANIMATION_MANIFEST.csv` except the four `HANDS_*` rows (D-4: not Blender work). That is 15
clips, durations EXACT (seconds -> frames at 30 fps, N+1 samples with the last frame duplicating the first for loops;
Unreal reads N+1 keys and length N/30 s):

| clip | s | frames | loop | authoring notes |
|---|---:|---:|---|---|
| SRC_Idle | 2.0 | 0..60 | yes | planted pose (body sunk so SoilLine sits at the bed top - the SAME skeleton, body bone translated down so the seam is below z 9.6 and the magenta shoulder just shows; record the body offset used); gentle leaf sway, no mouth |
| SRC_Grip | 0.2 | 0..6 | no | stalks compress at the HarvestGrip points (crown dips, leaves close slightly) |
| SRC_Tug | 0.5 | 0..15 | no | stalks stretch up, bulb squashes against the rim (body squash 0.9 h / 1.1 w, crown up), ends at full strain |
| SRC_Release | 0.2 | 0..6 | no | elastic break-free: crown springs back, leaves rebound, bulb overshoots to 1.1 h then settles; root never moves (the world lifts the yield) |
| SRC_Cancel | 0.25 | 0..7 | no | from full strain back to the planted rest (ends == SRC_Idle frame 0) |
| ROOT_QuietIdle | 2.0 | 0..60 | yes | closed pucker, tiny breath (body 1.00..1.015 h), relaxed crown; frame 60 == frame 0 |
| ROOT_Anticipate | 0.3 | 0..9 | no | squash 0.9 h / 1.1 w, cheeks begin (1.1), crown lifts; starts == QuietIdle frame 0 |
| ROOT_Inhale | 1.2 | 0..36 | no | cheeks to the full bellows (>= 1.35x width at cheek height), leaves rise, pursed aperture; eases in, holds the last 0.2 s; starts == Anticipate end |
| ROOT_Scream | 0.6 | 0..18 | no | snap to full gape within 3 frames (Phase A scream: 1.30 h / 0.90 w, gape 0.65 of neutral width), leaves fan + recoil back, slight shake (+-1.5 deg body about Y at 15 Hz) for the hold, starts == Inhale end |
| ROOT_Recover | 1.0 | 0..30 | no | deflate, overshoot squash 0.75 h / 1.25 w at ~0.25 s, crown slumps; ends == RecoveryIdle frame 0; starts == Scream end |
| ROOT_RecoveryIdle | 2.0 | 0..60 | yes | tired breathing (0.97..1.0 h), drooped leaves; seamless loop |
| ROOT_AirborneLeafTrail | 1.0 | 0..30 | yes | leaves trail back (crown pitched -X), face quiet; seamless loop; root never moves |
| ROOT_ImpactSquash | 0.25 | 0..7 | no | squash 0.80 h / 1.20 w then back to neutral; pivot = bulb centre (root fixed) |
| ROOT_SettleRock | 0.4 | 0..12 | no | damped leaf recoil (2 oscillations), bulb still; ends neutral |
| ROOT_PlaceSettle | 0.25 | 0..7 | no | gentle set-down squash 0.92 h then neutral |

Rules: pose library in Python (named poses = per-bone rotation/scale/translation on the EXPORT bones; no control
armature - D-B1, simpler and deterministic), Catmull-Rom (periodic for loops) through the keys, every frame keyed,
one action per clip named exactly `<Clip>` with fake user; `root` never keyed (assert identity on every frame); body
translation keys allowed (DEV-5) and body scale with X == Z (D-A1). Continuity: the cycle clips must chain -
Anticipate f0 == QuietIdle f0, Inhale f0 == Anticipate fN, Scream f0 == Inhale fN, Recover f0 == Scream fN,
RecoveryIdle f0 == Recover fN, and Anticipate f0 must also be reachable from RecoveryIdle f0 within a 2-frame hard cut
(the runtime cuts between clips with no blend: D-3). Print the seam/chain deltas (max bone head delta cm, max rotation
delta deg) and fail the build if any exceeds 0.1 cm / 1 deg except the two documented hard cuts (QuietIdle/RecoveryIdle
-> Anticipate), which you report.

Per-frame audit (every frame of every clip): triangle-pair intersections (lip/teeth vs cavity, leaf vs leaf, leaf vs
bulb, bulb self) must be 0 except documented chin folds at the scream (<= 3 pairs); bounds per frame; the global
envelope across all clips (must fit 22 x 14 x 13 or report the measured envelope). Write `review/phaseB/anim_report.json`.

Renders (`scripts/render_anims_screaming_turnip.py`): per clip a contact sheet of key frames (front + three-quarter,
8 frames evenly spaced, ruler) under `review/phaseB/clips/<Clip>_sheet.png`, plus one `cycle_sheet.png` showing the
chained cycle QuietIdle -> Anticipate -> Inhale -> Scream -> Recover -> RecoveryIdle at 6 fps. Look at them yourself and
fix what does not read (at least two rounds on Inhale and Scream).

## Part 3 - export, round trip, manifest

`scripts/export_screaming_turnip.py` (extend): bind SK `export/ScreamingTurnip_R01_Mars_SK.fbx`, statics
`export/ScreamingTurnip_R01_Collision_Mars_SM.fbx`, `export/TurnipBed_R01_Mars_SM.fbx`, `export/TurnipBedEmpty_R01_Mars_SM.fbx`,
cube `export/validation/Cube10_Mars_SM.fbx`, one clip FBX each `export/anims/ScreamingTurnip_R01_<Clip>_Mars_ANIM.fbx`
(armature + mesh + exactly one action, scene range = clip range; a one-sample clip is forbidden - none here).
`export/ScreamingTurnip_R01_Manifest.json` in the bat's shape (asset, versions, units_axes, dimensions_cm, bone_count,
bones, material_slots, vertex_colour, uv, clip_contract, clips{frames, samples, fps, loop, file, bytes, unreal_path,
note, chain}, sockets{Grip_L, Grip_R, MouthCue, SoilLine, HarvestGrip_L, HarvestGrip_R: bone + root-relative transform
in UNREAL cm (x, -y, z) with rotation; MouthCue parented to `jaw`, SoilLine/HarvestGrip_* to `crown` or `body` - say
which), collision{extents, centre_offset}, beds, export_paths, unreal_paths per D-1).
`scripts/validate_roundtrip.py` (extend `check_anims`): each clip into a fresh scene (`anim_offset=0`): one action,
frames exact, N+1 samples, `root` == rest every frame (<= 1e-4), landmark bone heads every frame <= 0.1 cm, skinned
extremes as scalars, loop seams <= 1e-3 cm, scale keys preserved (cheek/body at their peak frames within 0.01).
Write `export/anims/roundtrip_report.json` and `export/anims/expected_anims.json`.

## Hard rules

- Write only under `Tools/Blender/mars_ingredients/screaming_turnip_r01/`. No git operations. Nothing under `Content/`,
  `Script/`, `Plugins/`, `Tools/Blender/mars_cooking/`, `Tools/Blender/mars_monsters/`. No Unreal import (Phase C).
  Another executor is editing `Script/` in parallel; you never touch it.
- Every script prints `TURNIP_OK` / `TURNIP_FAIL <reason>`, exits non-zero on failure; only build/animate save the blend.
- The spec and sheets win over Phase A where they disagree; a proportion/topology change is recorded as DEV-n with
  before/after renders. Never clip a pose to fit the envelope; report the measured envelope.
- Do not claim from a script existing; run it, read the numbers and the PNGs.
- Fill the Phase B section of `PROGRESS.md`: rerun commands, look-pass changes per audit item A-1..A-5 with the sheet
  that proves each, re-measured table, clip table (frames, loop, seam/chain deltas, per-frame intersection maxima,
  per-clip bounds, global envelope), round-trip numbers, manifest path, deviations, not verified. Confirmed/inferred.

## Reporting back (your final message)

Files; rerun commands; A-1..A-5 status with the proving sheet each; re-measured dimensions and landmarks (incl. the
new cheek bone heads and the SRC planted body offset); the clip table; chain/seam deltas and the two hard cuts;
intersection maxima; global envelope; round-trip results; manifest socket table; first-person mock verdict; what
remains unverified. Confirmed vs inferred on every claim.
