# Warrens C / dressing production pack r01

Open **PREVIEW.html** for material previews, modeling sheets, a searchable prop catalog and tile-specific dressing instructions.

- 19 surface families,95 map PNGs,1024x1024 each: BaseColor/ORM/NormalGL/NormalDX/16-bit Height.
- Two five-map trim sheets, a32-color palette and a glyph/navigation alpha atlas with20 individual vector/PNG icons.
- Four wear decals, water normal/breakup maps and a graphic flame card.
- Six native transparent painted emblems/murals; 38 Blender modeling-reference sheets and 11 district assembly sheets.
- 150 prop entries:67 P0 core,66 P1 support,17 P2 optional, with dimensions/pivots/materials/collision/variants/Blender briefs.
- All11 current Level Instance tiles and24 source room records covered; all10 source view rays listed.
- A packed Blender material library,35 unique art materials and three rendered review scenes.

Start with `BLENDER_AUTHORING.md`, then the first24-entry batch and the appropriate tile in `ROOM_DRESSING.md`. Use `MATERIAL_GUIDE.md` for map channels, UV scale, trim bands, native-art caveats and eventual Unreal material integration. `SOURCE.json` records what is source-measured versus proposed. `prop_catalog.csv` is the production tracker; `briefs/` holds individual requests.

`ASSEMBLY_RECIPES.md` maps every one of the26 source dressing proxies and all seven authored puzzle locations to the reusable catalog pieces. Generate each shared asset once, then instance it. Use the current file selected in `image_jobs.json`/PREVIEW.html; original images retained beside r02 corrections are revision sources.

The current layout JSON governs dimensions/mechanism locations. The prior concept paintings govern mood and shapes. P7 is in Salt Mill; the Red key is on the accessible Belfry loft, distinct from the high landmark bell. The picture sheets are not metric CAD drawings and do not override these contracts.

Materials/maps are actual local assets. The surface/FX/vector resources are deterministic code-native outputs; painted emblems/modeling images use built-in image generation. Painted sources remain native1254px transparent art for Blender, with power-of-two prop-atlas baking left to prop production. No external image API runner was used.

This is a Blender-ready art handoff. It has not been imported into Unreal or accepted in PIE. The live level, gameplay, plugin configuration and existing cookbook library are unchanged. No commit or push is part of this request.

Look controls live in `materials.json` (base_srgb_hex, roughness, metallic, tile_metres, relief_mm) and `palette.json`. Procedural rebuilding requires NumPy/Pillow; the supplied `.blend` can be opened independently without installing them. `prepare.py` is initialization-only and refuses to overwrite an existing pack. Generated art is preserved; use its prompt/revision records rather than re-running preparation.


## Expanded visual coverage

See [VISUAL_COVERAGE.md](VISUAL_COVERAGE.md): every one of the149 new-model candidates has a linked modeling sheet. I14 reuses the existing Red key. There are38 modeling sheets and11 exploratory district composition studies. The [Chain Crossing / Sluice dossier](sections/chain-crossing-sluice/PREVIEW.html) adds88 local component entries,23 model sheets and4 assembly/player-view sheets with individual Blender briefs.

District DRESS images are exploratory composition studies, not technical model sheets or placement plans. Their in-image IDs and relative arrangements are non-authoritative and sometimes conflict with the catalog/source; use the linked MODEL/CS sheets and written briefs for asset identity, dimensions and placement constraints. DRESS06 in particular must not be used to add a waterfall or stepping-stone crossing. These known limitations are deliberate review flags, not runtime acceptance.
