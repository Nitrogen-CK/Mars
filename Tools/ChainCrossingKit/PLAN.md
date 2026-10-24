# Production gates

1. Research/baseline: inspect source and live instance structure; preserve unrelated dirty state and map assets before writes.
2. Model generation: all 88 catalog IDs get deliberate low-poly geometry, materials, UVs, pivots and reusable family parameters. Validate topology/bounds/nonempty geometry in a fresh Blender process.
3. Library/diorama/export: linked instances, neutral/contact and dark player-camera renders; FBX scale and material-slot roundtrip; no placeholders reported as production.
4. Unreal import: import owned meshes/materials, verify counts/bounds/UVs and relative material assignment.
5. Level-instance dressing: show rendered arrangement before live writes, then apply source-fitted visual-only ISMs in correct existing instance assets. Preserve authored gameplay and source boundaries.
6. Acceptance: matched editor/player-camera evidence, traversal/clearance and focused CkAuto checks appropriate to any runtime changes. Clearly separate source/static checks, PIE observation and unverified packaged/network claims.

Rollback: restore the three named pre-write map backups with the editor closed, preserving subsequent unrelated edits first. Removing tagged dressing actors alone does not restore original render-material/visibility overrides. Existing dirt and unrelated levels are never reset.
