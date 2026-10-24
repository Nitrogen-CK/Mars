# Saved-mesh Sluice brace contact audit

**Confirmed:** all four final fitted braces have their lower TX08 wood endcaps strictly inside the intended post and their upper TX08 wood endcaps strictly inside the final header. Across all 32 endcap vertices, the smallest nearest actual support-surface distance is **24.74458mm**. The chosen **40mm axial insertion is a visual join allowance**, not an invented structural requirement.

## Exact final transforms

Plan metres; rotations follow the existing kit conversion. All braces have unit scale and Y=21.85.

| Post X | Final fitted brace X | Final fitted brace Z | Yaw | Lower-cap minimum surface distance | Upper-cap minimum surface distance |
|---|---|---|---|---|---|
| 116 | 116.516562796346 | -0.616562822608743 | 0 | 24.74458mm | 24.74838mm |
| 120 | 120.516562796346 | -0.616562822608743 | 0 | 24.74458mm | 24.74838mm |
| 124 | 124.516562796346 | -0.616562822608743 | 0 | 24.74458mm | 24.74838mm |
| 128 | 127.133437209614 | -0.616562822608743 | 180 | 24.74458mm | 24.74838mm |

The source posts remain CCS86 at X=116/120/124/128, Y=21.85, Z=-1, scale `[1.5,1,1]`, plan rotation `[90,0,0]`. Their actual wood occupies X approximately `[postX-.35, postX]`, not a symmetric interval around postX. That pivot/rotation asymmetry requires the last mirrored brace's different offset.

**Final header audited:** CCS86 at `[121.82500000298023,21.85,.5]`, scale `[6.174999997019768,1,1]`, yaw0, no explicit rotation. Its full wood envelope spans X approximately115.65..128 and Z=.5...85. The shift from provisional center122 to121.825 leaves all four brace-cap containment results and nearest-surface minima unchanged. Endcaps are away from the header's end bevels. This audit specifically proves brace-to-post/header joints; it does not measure physical load capacity.

For stable rounded placement values, the recommendations are X116.516563/120.516563/124.516563/127.13344 with Z-.616563. Main's socket-derived values above were separately evaluated and pass; retain those derived values rather than replacing them with rounded constants.

## Actual saved wood geometry and proof

Opened `Output/WarrensVariantC_KitLibrary.blend` read-only in Blender5.2.2 LTS. The saved geometry, not source dimensions or a regenerated proxy, was used. TX08 faces were selected by the saved material's `catalog_key`; TX09 straps/pins were excluded from brace end identification.

- CCS87 TX08 local bounds: X `[-.5565628409385681,.5565628409385681]`, Y `[-.08161156624555588,.1249999925494194]`, Z `[.04343722015619278,1.1565628051757812]`. These differ from the full normalized1.2m envelope because iron straps extend the assembled bounds.
- Actual lower vertical endcap: saved polygon7, vertex IDs `[11,6,0,5]`, outward local normal `[-1,0,0]`.
- Actual upper horizontal endcap: saved polygon5, vertex IDs `[9,10,4,3]`, outward local normal `[0,0,1]`.
- CCS86's main closed wood component has24 vertices/26 faces. Disconnected shallow hewing overlays are excluded from the structural volume test. CCS87's wood component has12 vertices/8 faces.
- Applied the existing `build_kit.py` conversion: plan rotation `[pitch,yaw,roll]` becomes Blender Euler XYZ `[roll,-pitch,-yaw]`; yaw-only rows use `-yaw`. Mesh scale precedes rotation; Blender Y reflection is reversed when reporting plan coordinates. Object-local identity transforms were checked before evaluating saved vertices.
- For each support, transformed actual polygon planes were oriented outward and the component's convexity was checked against every component vertex. Each of the four vertices of each endcap was then tested strictly inside all actual support planes. Since each endcap and support component are convex, containment of every cap vertex establishes containment of the whole endcap face, not an AABB-only touch.
- Independently used `BVHTree.FromPolygons`/`find_nearest` on the actual beveled wood faces for each cap vertex. The minimum distances above include bevel effects; they are not inferred from envelope overlap. Point coordinates, signed plane distances, and actual nearest surface points for every tested vertex are recorded in the JSON artifact.

With yaw0, the lower end plane lies40mm inside the post's right side; with yaw180, it lies40mm inside the last post's left side. All upper wood endcaps are at Z approximately.54,40mm above the header's bottom plane. The bevels reduce the nearest-surface distance to about24.75mm while retaining strictly positive containment throughout the checked endcap faces.

The proposed source sockets `post_end=(-w/2,0,t/2)` and `header_end=(w/2-t/2,0,h)` address the saved end planes in the required X/Z coordinates after the existing finish normalization. Main's fitter uses those transformed socket coordinates to derive the final placements; the current resulting rows match the independent saved-mesh recommendation within floating-point tolerance.

## Reproduction and artifacts

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background `
  'Tools/WarrensVariantCKit/Output/WarrensVariantC_KitLibrary.blend' `
  --python-exit-code 1 --python `
  'Tools/WarrensVariantCKit/Output/Reports/sluice_saved_mesh_probe.py'
```

The final read-only run exited0 and emitted four `SLUICE_CONTACT` records plus `SLUICE_READ_ONLY_GEOMETRY_COMPLETE`. The probe writes only `Output/Reports/sluice_saved_mesh_geometry.json`; it calls no scene mutation, generator, save, export, or Unreal operation.

- Probe: `Output/Reports/sluice_saved_mesh_probe.py`.
- Per-vertex evidence: `Output/Reports/sluice_saved_mesh_geometry.json`.
- Audited final rebuilt library SHA256: `860cac453221d8b3d14657c822ac9d00c4d5411d99ad0d8c5c14b7972796afa2`.
- Audited final rebuilt library mtime:2026-10-24 18:44:07 UTC; length12,309,619bytes. Main rebuilt the library after the initial18:22:53 snapshot audit. The complete probe was rerun on that new save, confirming unchanged TX08 end geometry and all four final fitted contact results. A closing on-disk hash comparison matched the final probe snapshot. This worker never saved the library.

No implementation, placement, map, or AS source file was authored by this worker. Main owns rebuilding/applying the fitted output and the subsequent actual Sluice image check. This geometric result does not substitute for that image or for collision/gameplay tests.
