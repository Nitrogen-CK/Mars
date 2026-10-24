# L09 / ShaftLightFrame

Generate ShaftLightFrame, asset L09, for Mise en Monstre Warrens C. Ultra-low-poly flat shading, chunky primitive silhouette, 1-2 broad bevels, no realistic microdetail. Proposed width/depth/height [200.0, 50.0, 150.0]cm. Blender Z up, width local X, front -Y. Pivot: bottom-center at contact plane. Materials ['TX01', 'TX09']. frame source shaft light aperture; keep existing light reach for later PIE calibration. NoCollision visual dressing; retained greybox/world collision is authoritative. UV0: use shared palette or one trim lane for small props; tiling surfaces at catalog tile_metres for large forms. UV1: non-overlapping lightmap UVs with padding when static-light use requires them. Keep all moving components separate. Apply object scale; do not add gameplay, lights or collision automatically. Output one named collection, meshes, optional UCX only when later approved, and a neutral front/side/three-quarter preview.

Priority: P1

Dimension basis: proposed modeling envelope; fit current source ports/collision before dressing

Tiles: Hub

Triangle target: [200, 1000] (proposal).

Sockets: []

## Visual references

- [MODEL32](../art/model-sheets/MODEL32_GlassWaxBrazierAndLightFrame.png)
- [DRESS01](../art/district-sheets/DRESS01_HubDressingAssembly.png)
