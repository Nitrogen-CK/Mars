# Feature showcase: the pan — storyboard (final)

**Decisions (Stephen, 2026-10-25):** approved without the fryer beat (6 is cut; ~42 s). Shot as **A. kernel replay** on
the devlog stage's cooking bay. Pieces: lookdev cube for beats 1-2, cut slab pieces for beats 4-7, "multiple cubes,
whatever functionality is available now" allowed as the fallback. Captions as listed, none added.

**Pieces used:** the lookdev cube (`MeatCube_Mars_SM`) for every pan beat. The four slab quarters were made
(`devlog_pan_cut.py --export` -> `SlabPiece_A..D_Mars_SM`, imported to `/Game/Mars/Devlog/Pieces` on `MeatSlab_Mars_MI`),
but in the pan they do not read their cook state: an all-seared piece stays red with a pale fat top
(`D:\Repo\Content\Devlog\pan_showcase\_pieces\look_test_slab_top_vs_cube_bottom.png`; the 2026-10-10 parity sheet found
the same). Five of them (7.3 x 4.0 x 4.8 cm at the stage pan's scale) also leave no room for a toss on the 9.5 cm
flat base. So beats 4-7 use the cube, as the fallback allows; beat 3 still shows the slab being cut.

Output: `D:\Repo\Content\Devlog\renders\pan_showcase.mp4`, 1920x1080, 30 fps, 41.6 s, no audio.

| # | segment | start | end | dur | footage (source s) | caption |
|---|---|---|---|---|---|---|
| T | `title` | 0:00.00 | 0:02.00 | 2.0 | `title_still.png` (oil macro, seared cube, sizzle 1), blur 8, darken 0.5 | Mise en Monstre / The pan |
| 1 | `oil_land` | 0:01.60 | 0:07.00 | 5.4 | `oil_land` 0.4-5.8: oil macro (EV -1.6), the cube drops in, lands flat at 1.50 s, pool forms, beads start | none |
| 2 | `sear_flip` | 0:06.60 | 0:15.00 | 8.4 | `sear_flip` 0.4-8.8: top-down 60, -Z sears 0 -> 1 by 3.0 s, flip 3.6-4.0 s, the seared face on the near side, -Y done at 7.0 s | "Six faces. Three seconds each." 0:07.20-0:09.70, top |
| 3 | `bench_cut` | 0:14.60 | 0:19.00 | 4.4 | `bench_cut` 0.3-4.7 (Blender): the slab on a board, cut x = 0 (0.8-1.2 s), halves part, cut y = 0 (2.2-2.6 s), four pieces | "Cut first, then cook" 0:15.40-0:17.90, top |
| 4 | `five_pieces` | 0:18.60 | 0:29.00 | 10.4 | `five_pieces` 0-10.4: three-quarter 30, five cubes land 0.25-2.65 s, each its own pool; toss 5.40-5.85 s: two cubes hop 5.6 cm and turn a quarter, pools close and re-form, trails lag | "Every piece keeps its own pool" 0:23.50-0:26.00, top |
| 5 | `char_fond` | 0:28.60 | 0:35.00 | 6.4 | `char_fond` 0.4-6.8: top-down tighter, one cube on its seared face runs on to 1.9 while the fond builds; turned over 4.0-4.6 s to show the charred face | "Leave it, and it chars" 0:31.90-0:34.40, top |
| 7 | `ready_lineup` | 0:34.60 | 0:40.00 | 5.4 | `ready_lineup` 0.4-5.8: raw, half, seared, charred side by side, slow push (in the footage) | none |
| E | `end` | 0:39.60 | 0:41.60 | 2.0 | `end_still.png` (the lineup), blur 8, darken 0.55 | Mise en Monstre / devlog 02 |

Transitions: fade 0.4 s into every segment; progress bar on; no music. Every clip runs 0.4 s longer than its proposed
beat so the fades do not shorten it. Captions are `big`, 2.5 s, top (every subject sits centre-frame), clear of the fades.

## What drives each beat (kernel replay, `Tools/Devlog/footage/unreal/devlog_pan_shots.py`)
- Sear: the face on the pan is the local axis pointing most down (`utils_foodpiece::Get_DownFace`); it gains
  dt / `SecondsPerFace` 3.0 (`Mars_Searing_Feature.as:74`) while the piece rests on the hot pan, clamped at 1
  (`Mars_Searing_Processor_Tick.as:245`). Display: Penetration = min(1, sum), Shape = sum / 6 (`Mars_CookState.as:76-77`).
- Station dressing (`Mars_SearingStation_EntityScript.as`): footprint radius h x sqrt2 x 0.9 (:110), pool scalars
  1.1 / 0.6 / 0.5 / 0.4 / 0.4 x h of the largest piece (:111-115), trail lag 0.25 s (:143, exponential as :558),
  pool lift fade 4 cm (:145, :719), sizzle ramp full / 0.4 seared face, rise 2 / fall 1 per s (:136-140, :724-737),
  fond 0.1 + 0.02 / s while sizzling (:141-142, :737), oil coat to 0.7 at 1 / s on the hot pan (:149-152, :827),
  k_PoolSlots 6 (:148), MaxPieces 6 (`Mars_Searing_Feature.as:60`).
- Not the kernel (scripted for the shot): the motion (drops, flip, toss), the char past 1.0 in beat 5 (the kernel stops
  at 1.0; the material reads up to 2 = burnt), the fond pushed 0.3 -> 0.9 over beat 5, the lineup's states and
  Glaze 0.35, Oil Amount 0.9 (the stage look; the station runs 0.7).

## Re-run
```
cd D:\Repo\Mars\Tools\Devlog\footage\blender
"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" -b --factory-startup --python devlog_pan_cut.py -- [--draft] [--export]
cd D:\Repo\Mars\Tools\Devlog\footage\unreal
python run_pan.py --import-pieces                 # only after a new --export
python run_pan.py --shot all [--draft] [--quit]   # or --shot sear_flip,char_fond
cd D:\Repo\Mars\Tools\Devlog
python -m devlog_kit.validate episodes\pan_showcase\episode.json
python -m devlog_kit.render episodes\pan_showcase\episode.json --out D:\Repo\Content\Devlog\renders\pan_showcase.mp4
```
