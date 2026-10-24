# Warrens Variant C full-level kit

This kit packages the source-grounded visual model library, fitted placement data, and review evidence for the 11 Variant C district tiles plus dressing recorded for the surrounding Main map. It supersedes the earlier partial kit previews for full-level review; the Chain Crossing and Pump/Cistern kits remain reusable asset sources.

## Local review page

From the repository root, regenerate `Output/PREVIEW.html` with:

```powershell
python Tools/WarrensVariantCKit/make_preview.py
```

Open `Tools/WarrensVariantCKit/Output/PREVIEW.html` in a browser. The page reads `model_catalog.json`, `Output/asset_manifest.json`, `zone_plan.json`, `Output/fitted_instances.json`, `Output/review_views.json`, current report files, and exact `Output/Runtime/<view-id>.png` captures. Library counts come from the generated and reusable catalog arrays. District and Main counts, placement totals, and validation labels are reported from their respective source records; the page does not infer coverage from tile-named screenshots or fabricate completion states. Report statuses are recorded values, not an overall completion claim.

The gallery has search plus tile, category, and generated/reuse filters. Runtime targets have a separate kind filter for rooms, boundaries, and sightlines. Model previews link to the appropriate local kit preview when one exists. Source concept/model sheets, report files, Blender projects, and Unreal Level Instance paths are exposed as evidence links or paths.

The checked input snapshot records 196 library entries (83 generated and 113 reused), 37,511 fitted placement rows, and 7,481 source instances. These are data counts, not acceptance results; the HTML generator reads them from the catalog and current manifests/reports rather than fixing them in the page template.

## Evidence limits

Current known scope notes: the original P4 baseline is missing its dial and clue actors and has no Bellkeeper encounter. Existing prototype controls are retained; fixed-answer leaf actors are not fabricated. Source documentation keeps the six glyphs swappable and the phrase gameplay-authored (`docs/art/warrens-c-dressing-r01/SOURCE.json` and `ASSEMBLY_RECIPES.md`).

Report status is shown only when a report file records it. A source plan, fitted-instance manifest, Blender preview, import report, or room screenshot does not by itself prove that the map is correct in play. The evidence currently linked does not establish physical-input feel, network/co-op behavior, packaged-build collision, or full regression coverage. See `Output/Reports/boundary_visual_review.md`, `gate_art_binding.md`, `placement_adversarial_review.md`, `unreal_level_validation.json`, and `pie_final_rooms_r05.json` for recorded review and validation findings; the preview page links these only when present.

The map paths are the Variant C Level Instances under `/Game/Mars/Maps/Variants/v8c/`. The source tile list and per-tile references are derived from `zone_plan.json`; placement data is in `Output/fitted_instances.json`.
