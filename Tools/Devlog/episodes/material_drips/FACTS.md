# Facts behind the drips breakdown

Every caption and every diagram label, with the line that supports it. Paths are relative to `D:\Repo\Mars`. Numbers
marked *(ref)* come from running `Tools/Blender/mars_water/drip_reference.py` (the plain-Python mirror of the clock;
`--selftest` passes: `DRIP_REFERENCE_OK`, land error 4.6e-13 cm, inverse error 3.2e-15 s).

## Captions

| Claim on screen | Source | Note |
|---|---|---|
| **No particles. No simulation.** | `Shaders/Water/MarsDrip.ush:3-5` (every moving part "is closed-form maths of game time"); `Script/WorldObjects/Dressing/Water/Mars_DripLeak.as:3` (the actor "only lays the strands out"); `Tools/Environment/DRIPS_PLAN.md:43` (Niagara emitters not built), `:1076-1079` (Niagara and GPU particles rejected), `:84` (no ticks, no actors, deterministic) | The drops are drawn on instanced quads ("cards") that the vertex shader moves (`Shaders/Water/MarsWet.ush:103-108`). Say "cards", never "no geometry". |
| **Each drop is a formula of time** | `MarsWet.ush:143-150`: the card picks its drop from T (`MarsDrip_SlotDrop`), age `A = T - Release`, height `Y0 + DistanceAt(A)` | |
| **Run it backwards: when does it land?** | `MarsDrip.ush:57` ("AgeAt is its exact inverse"), `:69-73` (`MarsDrip_AgeAt`), `:84` (fall time = `AgeAt(L - Y0 - R)`); `Script/Tests/Drips/Mars_AutoTest_DripSchedule_ADropLandsAtTheImpactTime.as:3, 46-48` (AgeAt inverts DistanceAt to 1e-4 s) | |
| **The bead swells until it lets go** | `MarsDrip.ush:126-140` (`MarsDrip_BeadGrowth`: 0..1 between the previous and next release); `MarsWet.ush:187-189` (radius `R(0.35 + 0.65 g^1/3)`, sag), `:202` (at detach the bead centre is where the drop starts) | |
| **Four cards per strand take turns** | `MarsDrip.ush:17` (`MARS_DRIP_SLOTS 4`), `:107-115` (`MarsDrip_SlotDrop`, slot = K mod 4); `Mars_DripLeak.as:5` (6 cards: 4 drop/splash slots, bead, thread) | |
| **A card waits out its own splash** | `MarsDrip.ush:19` (slot busy 0.28 s after impact), `:85-86` (`Busy = TFall + SPLASH_S`, period stretched so "slots never overlap"); `Mars_AutoTest_DripSchedule_SlotsNeverOverlapAndWrapSeamlessly.as:1-4, 64` | |
| **Loops every hour without a seam** | `MarsDrip.ush:18` (wrap 3600 s, the Time node's period), `:87-88` (N drops per wrap is a multiple of 4, the period divides the wrap), `:50-55` (the hash index wraps with K mod N); `Tools/Blender/mars_water/unreal/mars_water_ue.py:127-131` (Time node `Period = 3600`); test `...SlotsNeverOverlapAndWrapSeamlessly.as:3-4, 65-66` | 3600 s = 1 hour. |
| **Each strand is traced to the floor** | `Mars_DripLeak.as:100-104` (runs from the construction script), `:364-371` (trace up to the ceiling), `:384-398` (trace down; `Length = Hit.Distance`); `Mars_AutoTest_DripLeak_TracesStrandsDownToTheFloor.as:1-4` | Done in the editor when the actor is built or moved, not per frame. Shown over `drip_splash_floor`, whose strand (Leak_VaultLine #1) really was traced both ways: the leak is placed at z 300 (`Tools/Blender/mars_water/unreal/mars_water_review.py:256`, `AttachUp` defaults true `Mars_DripTypes.as:178`) and its cached source is at z 349 under the vault, impact z -0.5 on the floor (footage `shot.json` `strand`). |
| **Every drop lands exactly on it** | `Mars_AutoTest_DripSchedule_ADropLandsAtTheImpactTime.as:1-3, 34-35` (leading edge = strand length at FallSeconds, within 0.05 cm, 10 cm to 12 m); `Mars_DripLeak.as:456` (cards sit at the impact), `MarsWet.ush:119` (source = impact + L) | On screen the footage drop lands at beat 3.92 s (game 16.92 s) and the synced inset's drop lands on the same frame (checked at 1080p: crown at 16.93, first ring at 17.03 in both). |

## Diagram labels

| Diagram: label | Source | Note |
|---|---|---|
| fall_curve: "with drag" curve | `MarsDrip.ush:57-62` (`MarsDrip_DistanceAt`), constants `:13-14` (g 980 cm/s², terminal 750 cm/s) | Plotted from `drip_reference.distance_at`, leading edge (`Y0 + DistanceAt + R`), `Y0 = 1.6 × 0.45 cm` (`MarsDrip.ush:83`, `water_spec.py:56`). |
| fall_curve: "no air" curve | none in Mars | A comparison curve (½gt²) drawn by the diagram only. |
| fall_curve: "0.93 s" / "0.84 s" | *(ref)* 350 cm strand: fall time 0.931 s with drag, 0.844 s without | The inset sits over the 85 cm pipe-joint strand, so the kit's label pill says **"Example: a 3.5 m strand"**; the curve is not the footage strand's (that one falls 0.365 s from its thread tip). |
| fall_curve: "top speed 750 cm/s" | `MarsDrip.ush:14`; `...ADropLandsAtTheImpactTime.as:68, 70` (speed stays below terminal, settles at it) | Stylised; `DRIPS_PLAN.md:174` notes real drops reach about 900. |
| fall_curve: `DistanceAt(t)` / `AgeAt(y)` | `MarsDrip.ush:58, 69` | |
| drip_clock: bead, falls, crown, rings | bead `MarsDrip.ush:126-140`; fall `MarsWet.ush:147-150`; floor crown 0.16 s `MarsDrip.ush:20`, `MarsWet.ush:170-173`; rings 22 cm/s for 1.4 s `MarsDrip.ush:21-22`, `MarsWet.ush:439-441` | Bead and drop sizes are exaggerated for legibility; positions and times are the clock's. Rendered for the footage strand (Leak_PipeJoint #0: L 85, rate 1.4813, seed 0.73664, jitter 0.4, mode 1 DropsWithThread; period 0.675 s, fall 0.365 s, same as its `shot.json`) at t0 14.0 = macro `frozen_t0` 12.0 + the beat's in point 2.0, so its releases (game 14.70, 15.32, 15.98, 16.70 ...) are the macro's. The thread is drawn because mode 1 starts drops at `Y0 = 14 + 30 frac(seed x 7.13)` = 21.6 cm (`MarsDrip.ush:82`). On a short strand the side-view ring is drawn at a reduced scale so it stays in the column. |
| drip_clock: card lanes (fall bar, splash bar, skipped drop ring) | `MarsDrip.ush:92-105` (release, skip, impact), `:16` (skip chance 0.25 × jitter) | Future events are drawn dim: the clock can be evaluated at any time. |
| slots_wrap: "12 m fall, asked 2.0 drops/s: the clock gives 1.29/s" | `MarsDrip.ush:86-88` (slot cap); *(ref)* strand 1200 cm, 2.0 /s, seed 0.37, jitter 1.0: busy 2.406 s, period 0.7765 s | Test: "the slot cap only ever lowers the rate" (`...SlotsNeverOverlapAndWrapSeamlessly.as:67`). |
| slots_wrap: "One loop = 3600 s = 4636 drops, a multiple of 4" / "3600 s = 0 s" | `MarsDrip.ush:87-88`; *(ref)* N = 4636 | |
| slots_wrap: release ticks stay in order | `MarsDrip.ush:15` (jitter < 0.5 period keeps releases ordered); `Mars_AutoTest_DripSchedule_ReleasesStayOrderedAndAverageTheRate.as:1-5` | |
| strand_trace: "Trace up to the ceiling" / "The strand hangs from whatever ceiling it finds" | `Mars_DripLeak.as:365-371` (AttachUp: a hit facing down moves the source to 1 cm under it) | |
| strand_trace: "Trace down to the floor" / "The hit also says floor, water or slope" | `Mars_DripLeak.as:384-397` (Water phys mat, normal Z < 0.7 = Dry, else Floor) | |
| strand_trace: "L = 350 cm", Length 349.5, Rate 0.66, Seed 0.58, Jitter 0.70, Mode Drops | the footage strand, Leak_VaultLine #1 (`drip_splash_floor/shot.json` `strand`, read from the DripLeak `CachedStrands` entry) | "350 cm" is 349.5 rounded. Rendered at t0 13.0 = `frozen_t0` 12.5 + in point 0.5. |
| strand_trace: Surface "Floor", DropScale "1.0" | Surface: the strand lands on the sewer flagstones, which are not a Water hit (`Mars_DripLeak.as:391-396`); DropScale: the VaultLine preset does not set it (`Mars_DripLeak.as:125`), default 1.0 (`Mars_DripTypes.as:139`) | Neither is in the footage `shot.json`; both are inferred from the source as cited, not read from the actor. |
| strand_trace: "Pack it into custom data" rows Length, Rate, Seed, Jitter, Mode, Slot, DropScale, Surface | `Mars_DripLeak.as:458-479`; `Tools/Blender/mars_water/README.md:28-29` | Values are the example strand's; DropScale default 1.0 `Mars_DripTypes.as:139`. |
| strand_trace: "6 cards" at the impact | `Mars_DripLeak.as:250-254, 453-479`; test `...TracesStrandsDownToTheFloor.as:1-2` (30 cards for 5 strands, at the impact) | |
| strand_trace: `y = Y0 + DistanceAt(t - release)` | `MarsWet.ush:145, 149` | |

## Claims considered and left out
- The trace beat over the pipe-joint strand (`drip_strand_side`): not used, because that leak has `attach_up` off
  (`mars_water_review.py:252-254`), so the trace-up phase of `strand_trace` would not be true of it.
- "Rings start the frame the drop lands" belongs to the water episode (sourced there).
- Any per-frame cost figure: no measured number in the sources beyond the plan's budgets.
