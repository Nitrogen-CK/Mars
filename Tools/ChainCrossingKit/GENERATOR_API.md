# Generator API

All sizes/coordinates in metres. Build local parts around origin. `build(b, part)` returns nothing; every primitive registers in the current asset collection. No global scene cleanup, saving, export, cameras, materials, collision or editor mutations in family modules. One module owns its assigned IDs only.

`b.size`: `(width, depth, height)` from catalog, metres. Front is -Y, Z up. `b.id`: current CCS ID. `b.mat(index=0)` returns configured shared material by index (falls back to first). `b.material(key)` resolves TX01 etc for explicit detail when needed.

This API describes the neutral Blender frame. Native Unreal FBX import maps vertices `(X,-Y,Z)`, so imported front is +Y. The adapter to a runtime mechanism's +X front is **Unreal yaw -90 degrees**. Do not copy a neutral Blender `mesh_adapter=+90deg` flag directly into an Unreal transform. The importer verifies its actual axis settings and writes the converted adapter into Unreal asset metadata and the import report.

- `b.box(name, loc, size, mat=None, bevel=0.015)` local box, dimensions applied; simple one-segment bevel applied by core. Mat may be material object or material ID string.
- `b.cyl(name, loc, radius, depth, mat=None, axis='Z', sides=12)` centered cylinder with cap; axis X/Y/Z.
- `b.cone(name, loc, radius1, radius2, depth, mat=None, axis='Z', sides=12)` centered truncated cone.
- `b.torus(name, loc, major, minor, mat=None, axis='Z', major_segments=12, minor_segments=4)` major radius is centerline radius.
- `b.rod(name, a, z, radius, mat=None, sides=8)` straight cylinder between endpoints a and z.
- `b.mesh(name, verts, faces, mat=None)` direct local mesh vertices/faces. Faces can be ngons.
- `b.extrude(name, points, z0, z1, mat=None)` extrudes 2D XY polygon between z0 and z1.
- `b.plane(name, loc, width, height, mat=None, vertical=False)` local XY plane centered at loc; vertical means XZ plane.
- `b.rng` deterministic Python random.Random seeded per ID.
- returned objects support transforms; only move/rotate returned objects deliberately. Core applies transforms, validates, generates UVs, merges pieces into the asset, sets origin and exports.
- `b.flag(key,value)` attaches asset-level metadata. Use `moving_part`, `axis`, `card`, `variation` when useful; no gameplay functions.

Do not fall back to one scaled box for an entire asset. Curved hollow objects need explicit ring geometry/open mouths. Torus links must be closed, with open center. Rock surfaces use broad deterministic facets. Every part needs a deliberate silhouette and thickness/joints appropriate to the inspected concept sheet. Complex collections may contain separate static subparts in the same asset, but separate catalog moving parts stay separate asset IDs.

The core may conform final dimensions to catalog; retain relative proportions in the local construction. Flat floor/water carriers stay on Z=0 with thickness below, wall/card contact conventions are finalized by core metadata.
