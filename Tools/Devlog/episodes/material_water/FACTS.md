# Facts behind the water breakdown

Every caption and every diagram label, with the line that supports it. Paths are relative to `D:\Repo\Mars`. Numbers
marked *(ref)* come from `Tools/Blender/mars_water/drip_reference.py`.

## Captions

| Claim on screen | Source | Note |
|---|---|---|
| **No textures. Every ripple is maths.** | `Shaders/Water/MarsWet.ush:3-4` ("No textures are sampled anywhere: all breakup is hashed per instance and anchored in world space"); `Tools/Environment/DRIPS_PLAN.md:647`; ripples are functions: impact rings `MarsWet.ush:420-454`, rain rings `:459-486`, still-water swell `:579-583` | Covers the water and wet materials, not the stone kit around them. |
| **Each puddle draws its own outline** (over the Final -> Base colour wipe) | `MarsWet.ush:491-514` (`MarsWet_PuddleShape`: facets at seeded angles, value-noise lobes, a world-space wobble, dry islands); seed per puddle in custom data `Script/WorldObjects/Dressing/Water/Mars_DripLeak.as:508`, `Tools/Blender/mars_water/README.md:29-30`; `Script/Tests/Drips/Mars_AutoTest_Puddle_ReseedChangesShapesNotCount.as:1-3` | The footage's second pass is `SCS_BASE_COLOR` (no roughness capture exists), labelled **Base colour** on screen, not "Mask"; it shows the darkened outline, which comes from the PuddleWet layer (`MarsWet.ush:516-520`). |
| **A deep core and a damp rim** | `MarsWet.ush:511-513` (returns `(Deep, Rim)`), `:490` (both puddle layers call it with identical inputs) | |
| **Wet stone: darker and far glossier** | darker: `MarsWet.ush:516-520`, `Tools/Blender/mars_water/unreal/mars_water_ue.py:465-472` (BaseColor toward WaterTint 0.010/0.009/0.007, opacity `max(deep x 0.6, rim x 0.45) x Wetness`); glossier: `MarsWet.ush:522-533`, `mars_water_ue.py:482-512` (Normal + Roughness layer) | "Far glossier" is against stone at roughness about 0.8, the plan's working figure (`DRIPS_PLAN.md:433`); the kit stone's own roughness was not checked. |
| **Roughness drops from 0.35 to 0.03** | `MarsWet.ush:531` (`lerp(RimRoughness, DeepRoughness, deep)`); defaults `mars_water_ue.py:484-485` | Rim 0.35 to core 0.03. |
| **Each ring starts when its drop lands** (over `drip_splash_floor` 2.0-7.5 with the synced `ring_timing`) | `MarsWet.ush:439-440` (ring age = T - `MarsDrip_Impact(K)`), `MarsDrip.ush:102-105` (impact = release + fall time); `Mars_DripLeak.as:7-8, 491-495` (the ring's custom data 0..4 equal the strand's bit for bit); tests `Mars_AutoTest_DripLeak_TracesStrandsDownToTheFloor.as:3-4`, `Mars_AutoTest_DripLeak_LandsOnStillWaterAsRingsOnly.as:1-5`; `DRIPS_PLAN.md:59-60` | On still water the rings are a translucent card (`DripRingCard_Mars_M`), same function (`mars_water_ue.py:406-441`). The footage strand (Leak_VaultLine #1) lands on the floor at game 15.45, 16.92, 18.26 s; the inset's diamonds are on those frames (checked at 1080p: splash and diamond together at 18.22 s output time). |
| **Spreading at 22 cm/s, like real ripples** | `MarsDrip.ush:21` (`MARS_DRIP_RING_SPEED 22.0`, "minimum phase speed of capillary-gravity waves"), `MarsWet.ush:441` | Life 1.4 s: `MarsDrip.ush:22`, `MarsWet.ush:440`. |
| ~~**The colour holds still. Normals move.**~~ **Dropped 2026-10-24** (beat cut; see *Claims considered and left out*) | `MarsWet.ush:572-584` (`MarsWet_StillWater`: depth and scum use UV, world XY and custom data only; T enters only the swell and rain slopes that become `Normal`); colour and roughness built from depth and scum `mars_water_ue.py:598-604`; cistern base colour = colour x 0.25 `:637` | The ring card on the cistern has a constant base colour (`WaterColour`, `mars_water_ue.py:426, 437`) and a crest-shaped opacity; it is translucent. If the footage's base-colour pass shows the ring cards moving, change this caption to **The motion lives in the normals**. |
| ~~**Wall streaks trace down to the floor**~~ | replaced 2026-10-24 by the two captions below | The ossuary Streak_2 in `wetstreak_wall` runs about 1.3 m and ends at the first niche row, not at the floor (UNREAL_SHOTS.md B). |
| **Each streak finds the wall behind it** | `Script/WorldObjects/Dressing/Water/Mars_DripAssets.as:95` (`Place_Streak`: a trace 60 cm back from the actor along -Out; no hit = hidden, `:96-100`); `Mars_WetStreak.as:1-3` (placed in front of the wall, +X out of it) | |
| **then traces its run down the wall** | `Mars_DripAssets.as:105-106` (a trace straight down from 4 cm off the wall; `Length` = the hit distance, else `MaxLengthCm`, default 600 `Mars_DripTypes.as:210`), `:113` (the decal is scaled to `Length`); test `Script/Tests/Drips/Mars_AutoTest_WetStreak_TracesWallToFloor.as:1-3` | Deliberately says neither "floor" nor where it stops: in the footage it stops at the niche row (the first surface the down-trace meets, or the cap; not checked in the map). Rivulet beads crawl down at `Flow` cm/s (`MarsWet.ush:558-562`), not claimed on screen. |

## Diagram labels

| Diagram: label | Source | Note |
|---|---|---|
| wet_layers (full frame, beat 3): Stone | illustrative procedural flagstones | Not a Mars material; the stand-in floor the layers go on. Its roughness 0.75 is illustrative. |
| wet_layers: Mask "deep core + damp rim" | `MarsWet.ush:491-514` ported line for line (master defaults Facets 9, LobeAmount 0.3, IslandThreshold 0.62: `mars_water_ue.py:447-449`) | Seed 0.55, aspect 0.4, chosen for a clean outline. |
| wet_layers: Darker "up to 60 % darker" | `mars_water_ue.py:466` (DeepDarken 0.6, "albedo x (1 - this)"); `MarsWet.ush:519` | Times Wetness; the diagram uses 0.85, the CisternDrip preset (`Mars_DripLeak.as:123`). |
| wet_layers: Glossy "roughness 0.35 -> 0.03" | `MarsWet.ush:531`; `mars_water_ue.py:482-485` (DeepOpacity 0.95, RimOpacity 0.5) | |
| wet_layers: Ripples "slow drifting normals" | `MarsWet.ush:528-529` (value-noise slope drifting with T, times the deep mask), MicroRippleAmp 0.03 `mars_water_ue.py:487` | Thumbnail contrast-stretched. |
| wet_layers: Rings "keyed to each landing" | `MarsWet.ush:420-454`, ported; ring decal width 1.2 cm, decay 0.8 s, dimple 0.4 `mars_water_ue.py:382-385` | Rings thumbnail is a fixed 0.45 s-old ring (an icon); the composite's ring follows the clock. |
| wet_layers: lamp highlight | `Tools/Blender/mars_water/README.md:49-53` (lamps with SourceRadius >= 8 cm sell the water) | The lighting in the composite is a simple illustrative model, not Mars's renderer. |
| ring_timing: diamonds "drop lands" at impact times | `MarsDrip.ush:92-105`; the footage strand Leak_VaultLine #1 (`drip_splash_floor/shot.json`: L 349.5, rate 0.6574, seed 0.5782, jitter 0.7; period 1.523 s, fall 0.930 s) | Rendered with `--sync drip_splash_floor/shot.json --offset 2.0` (t0 14.5), 5.5 s: impacts at 15.45, 16.92, 18.26 s, the shot's 2.95, 4.42, 5.76 s (UNREAL_SHOTS.md B). |
| ring_timing: "22 cm/s", "gone at 1.4 s" | `MarsDrip.ush:21-22` | Line brightness follows `exp(-age / 0.8 s)` (`MarsWet.ush:442`, Decay default `mars_water_ue.py:420`). |
| ring_timing: top view | `MarsWet.ush:420-454` evaluated on a 60 cm disc (the ring decal is scaled 0.6: `Mars_DripLeak.as:490`) | Display gain 2.0 instead of the card's RingAlphaGain 0.8 so the ring reads in an inset. |

## Claims considered and left out
- **"The colour holds still. Normals move."** (planned beat 5, base colour vs normals wipe): the footage cannot show it.
  `water_basecolor` is black water (single-layer water colour comes from absorption and scattering, not base colour), and
  `water_normals` is a near-flat blue plane: the impact rings are not in the `SCS_NORMAL` capture, and the water's R/G
  values sit at 0-15 of 255 (they look clamped at 0, so half of the slopes are missing). A contrast-stretched test copy
  showed only slow swell blobs with 8-bit banding and no rings, so no derived `water_normals_stretched` sequence was made.
  The source claim (`MarsWet.ush:572-584`) is still true; it is just not shown.
- Rain rings: the cistern instance does not enable `RainRipples` (`water_spec.py:93-95`), so they are not shown.
- "Reflections": Mars has no SSR or Lumen reflections (`README.md:49`); no caption talks about reflections.
- "Physically based ripples" beyond the 22 cm/s speed: the ring profile is stylised (Gaussian envelope x sine).
