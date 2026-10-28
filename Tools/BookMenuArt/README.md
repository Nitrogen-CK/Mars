# BookMenuArt — worn field cookbook from the Animated Book Menu book

Scripts that pull `SK_Book_01` and its six animations out of the BookMenu plugin (`/BookMenu`), rebuild them in
Blender, wear the book in, and export a mesh that drops back onto `Anim_Book_Skeleton`. Binary outputs (`.fbx`,
`.blend`, `.png`) are gitignored; only the scripts are tracked.

## Pipeline

Run from the repo root. Blender is `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`.

| Stage | Command | Writes |
|---|---|---|
| 0. Unreal export | `Binaries\Win64\MarsEditor-Cmd.exe Mars.uproject -run=pythonscript -script="Tools\BookMenuArt\export_from_unreal.py" -unattended -nosplash -nopause -AllowCommandletRendering -CkAsDeclineRegenOwnership` | `Export/` FBX, textures, `export_report.json` |
| 1. Assemble | `blender -b --factory-startup --python Tools/BookMenuArt/blender_assemble.py` | `Blender/BookMenu_Source.blend` |
| 2. Wear | `blender -b Tools/BookMenuArt/Blender/BookMenu_Source.blend --python Tools/BookMenuArt/blender_wear.py` | `Blender/BookMenu_Worn.blend` |
| 3. Stains | `blender -b Tools/BookMenuArt/Blender/BookMenu_Worn.blend --python Tools/BookMenuArt/blender_stains.py` | `Textures/`, preview materials in the worn .blend |
| 4. Export | `blender -b Tools/BookMenuArt/Blender/BookMenu_Worn.blend --python Tools/BookMenuArt/blender_export.py` | `ToUnreal/SK_Book_Worn.fbx` |

`blender_preview.py` renders a contact sheet of any `Action:frame` list (Workbench or EEVEE).

Stage 0 notes: the plugin declares `EngineVersion 5.5.0` and the engine is 5.7, so an unattended boot answers "No" to
the compatibility prompt and skips the plugin — blank `EngineVersion` in `BookMenu.uplugin` for the run and restore it.
`-AllowCommandletRendering` is required: the skeletal-mesh FBX exporter CPU-skins through a render-backed component.

## What the Blender files contain

- `Book_Armature` under the Empty `SK_Book_01_Root` (the FBX root, scale `0.01` in Unreal terms). **That Empty's scale
  is what makes a page 25 cm wide** (`0.01 × 0.6689`); bone data and actions are untouched, so the rig is still exactly
  `Anim_Book_Skeleton`.
- All six actions with fake users and a muted NLA track each; `PageBend_01..04` morph curves (which Blender's FBX
  importer drops) are rebuilt as keyed custom props on the armature driving the shape keys.
- Material slots carry the Unreal slot names: `Cover, PagesBase (block edges), PageA (left page), PageB/PageC (the
  turning sheet), PageD (right page), PageFirst, PageLast`.

## Wear (all knobs at the top of `blender_wear.py`, millimetres at the 25 cm scale)

- Turning sheet: two coincident planes 0.13 mm apart with no edge → a closed 0.8 mm sheet with a rim, thinning back at
  the gutter, thickness recomputed per shape key so the curl keeps it (`SHEET_THICKNESS_MM`).
- Page block fore-edge, head and tail: page-clump ridges (`BLOCK_RIDGE_MM`); the fore-edge strips are subdivided across
  the stack for this (`BLOCK_FORE_EDGE_CUTS`).
- Pages: in-plane only — wobbly outline and blunted fore-edge corners. The sheet rests ~0.6 mm above whichever page it
  lies on and lands on both, so cockling or curled corners would intersect it.
- Cover: outward board bow, flared and blunted corners, edge wobble (`COVER_*`).

Every displacement is a function of rest position (seam-split duplicates move together) and is mirrored into every
shape key. Authored normals are kept wherever geometry did not move.

## Stains (`blender_stains.py`)

On a new 4th UV channel **`StainUV` (Unreal UV3)** — UV2 is not unique across the pages (the sheet's PageB/PageC rects
overlap the others). StainUV = UV2, except the sheet's faces reuse the UV2 of the page they lie on (B→D, C→A), so a
turned page shows the same soaked-through stains as the page beneath it. The plugin's own UV0–UV2 are unchanged.

| File | Colour space | Content |
|---|---|---|
| `T_BookWorn_Pages_Stain_BC.png`, `T_BookWorn_Cover_Stain_BC.png` | sRGB | RGB stain colour, A opacity → `lerp(base, RGB, A)` |
| `T_BookWorn_Pages_StainMask.png`, `T_BookWorn_Cover_StainMask.png` | linear | R liquid, G grease (lower roughness), B grime, A total |

Stains are placed in 3D (pages: lying open; cover: lying closed), so a spill runs across the gutter, the turning sheet
and the fore-edge without seams. Placement and colours are in `page_stains()` / `cover_stains()`.

## In Unreal (`/Game/Mars/Gameplay/PlayerCookbook`)

`SK_Book_Worn` is imported there on `Anim_Book_Skeleton` with `PA_Book_01`. `setup_in_unreal.py` (live-editor Python,
idempotent) does the rest and has been run:

- `Textures/PlayerCookbook_{Pages,Cover}Stain[Mask]_Mars_T` — the stain PNGs.
- `Materials/PlayerCookbook_{Pages,Cover}_Mars_M` — copies of the plugin's `M_Pages_Master` / `M_Cover_Master` with
  one extra layer at the end: the plugin's `MF_Add_Dirt` fed by the stain texture on **UV3**. Parameters (group
  *Stains*): `Stain Intensity` (1), `Stain Roughness` (0.1), `Grease Roughness` (-0.45), `Stain BC`, `Stain Mask`.
  Everything else, including the `BC` param the BookMenu anim instance overrides with each page's widget render
  target, is the plugin's graph unchanged.
- `Materials/PlayerCookbook_*_Mars_MI` — copies of the plugin MIs on those masters (B/C/D inherit from PageA as in the
  plugin), assigned to the mesh slots exactly like `SK_Book_01` (PageFirst = PageA's MI, PageLast = PageB's).

Still to do where the book is placed: scale its mesh component by **0.6689** for a 25 cm page (the animations carry
the original proportions). Plugin content is never modified.
