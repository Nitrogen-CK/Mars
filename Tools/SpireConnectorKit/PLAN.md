# Production gates

1. Baseline and reusable geometry: capture owned-path/source hashes, validate numeric spec, build an axis/scale FBX fixture. Verify imported100cm fixture and marker signs before batch export.
2. Blender production: build shared prop and structural mesh catalog, all four assemblies, a linked-data kit library and diorama; save editable scenes and FBXs. Verify actual mesh bounds, exact tread tops, manifold support/collision pieces, instance counts and reference renders. Any clearance deviation: repair geometry, never relax the spec.
3. Unreal import: ownership-checked imports under the new kit folder, shared materials, HISM assembly; create four source maps, separate kit map and comparative diorama. Verify imported assets, transforms, material slots, counts, source map hashes and saved package existence.
4. Review and handoff: reopen saved Blender/Unreal artifacts, inspect full and player-height views, run focused appropriate toolbox checks on final content. Record all limits, particularly CkJolt packaged collision. Do not claim runtime/playtest proof from static renders.

Generated output is >10 files, so each gate updates PROGRESS.md with real evidence. Existing dirty files and submodule changes remain untouched. No all-project save or broad Git staging.
