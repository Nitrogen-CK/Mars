# Cookbook R03 — chunkier Option C

Scope: new physical geometry and matching rig, clips and closed proxy. Existing R02 page widgets/art remain in use. Section navigation is not part of this model update.

## Source and rollback

- Model/Cookbook_StylizedR03.blend: illustrated source for studio review.
- Model/Cookbook_StylizedR03_WidgetReady.blend: identical mesh/rig/actions, blank page-facing materials.
- Model/build_stylized.py: reproducible R03 geometry and animation generator.
- Model/FBX/: true-centimetre skeletal mesh, six clips and closed static proxy.
- PREVIEW.html: actual R02/R03 studio comparison with identical camera transforms.
- R02 source and Unreal assets remain retained. Evidence/Before contains the four pre-integration runtime/test source files.

## Geometry

Reading page: 17 x23cm authoring, unchanged. Existing runtime scale remains1.2.
Cover thickness2x; plan-view radius2x; rounded L-shaped brass corner guards; page stacks1.5x, with5 broad signature ridges; turning-leaf rim3x (0.612mm authoring /0.734mm runtime). The spine spans the closed binding, then folds down to32 percent closed depth on opening. Its reference mesh is flat-open (Spine scale1); the closed clip expands the binding3.125x with a matching1.9625cm offset. Scale/translation are keyed in all6 clips; page and cover bones are not squashed. The geometry uses12 bones and4 named page-bend morphs. Same first8 page/material slots and normalized front/back UVs.

Final source closed bound:19.074 x26.696 x5.128cm (including binding/stitches/ribbon); the whole-object depth is affected by the modeled binding, not only the page-stack target. Runtime closed depth is approximately6.154cm at1.2 scale.

Do not mix the R03 mesh/rest skeleton with R02 clips. All6 R03 clips are exported against the new hinge height; the terminal turn pose and spine-centred gutter compensation are retained.

## Offline verification

Final validate_all.py process exited0. FBX checks12/12, gutter4/4,216 turn frames without fixed-page surface intersections.7 skeletal/animation FBXs have unit metadata and root scale1. The static proxy has an independent expected-bounds report and is checked on Unreal import.18,460 triangles; no frame-time claim.

## Rebuild

Run Blender5.2 background with --python-exit-code1 on Model/build_stylized.py, then Model/validate_all.py. The generator exports skeletal mesh/clips; validation exports evaluated morph samples and the closed proxy. Run render_matched.py to refresh identical-camera R02/R03 comparisons. Never run prepare_revision.py over a hand-edited source unless intentionally regenerating the revision scaffolding.

## Unreal integration

Target namespace:/Game/Mars/Gameplay/PlayerCookbook/StylizedR03.
New SK_Cookbook_Field, SM_Cookbook_Closed, dedicated skeleton,6 Cookbook_*_AS clips and20 material sections. Page materials retain BC and reference existing R02 sample textures; runtime uses existing6 Ck page widgets.

Geometry-derived closed mount offset: (1.4244,-8.619,1.0813)cm before runtime scale. Width/height are unchanged, so open-hand half-width remains21.7872cm. Closed runtime pickup half-extents:(11.4444,16.0175832,3.077018)cm. Native proxy readback matches the source, and the fresh Cookbook tests verify pickup fit and visual scale.

Native build exited0. Fresh Cookbook baseline5/5 passed; final integration gate5/5 passed,0 failures/skips/contamination, exit0. The initial pre-build attempt stopped before tests on a stale Get_SourceComponent binding; the native rebuild resolved it without unrelated source changes. Evidence/baseline-build-and-test.log and Evidence/final-cookbook-test.log preserve the actual logs.

UnrealGameplay/R03-Final contains seven rendered PIE captures plus native state snapshots. Raw production-input events exercised pickup, opening, forward/reverse turns, closing, reopening and dropping during a turn. Native snapshots confirm closed Spine scale3.125 and open scale1. Physical keyboard, multiplayer and packaged-build behavior were not checked. The pre-existing mid-turn page trajectory briefly extends beyond the top of the viewport in both R02 and R03 captures; it is unchanged.

All R03 assets are saved; PIE is stopped on Sandbox_Mars_MAP, with no dirty editor packages. Work remains uncommitted. The unrelated pre-existing AutoTests_Mars_MAP.umap disk change is untouched. See DELIVERY.json for the verified scope and rollback.

## Next adjustment

Model/build_stylized.py owns the geometry and poses. The turning-leaf half rim is .00045 before author scale. Spine scale.z in set_pose goes from3.125 closed to1 open; closed local Z offset is .019625metres. Re-export/reimport the mesh and all six clips together after a geometry or rig change; retain the first eight material slots and four page-bend curve names.
