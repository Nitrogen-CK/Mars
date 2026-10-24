# D13 / WaterlineCard

Generate WaterlineCard, asset D13, for Mise en Monstre Warrens C. Ultra-low-poly flat shading, chunky primitive silhouette, 1-2 broad bevels, no realistic microdetail. Proposed width/depth/height [200.0, 60.0, 1.0]cm. Blender Z up, width local X, front -Y. Pivot: bottom-center at contact plane. Materials ['FX_Water']. follow existing water edge; no surface that reads as a walkable plank. NoCollision visual dressing; retained greybox/world collision is authoritative. UV0: use shared palette or one trim lane for small props; tiling surfaces at catalog tile_metres for large forms. UV1: non-overlapping lightmap UVs with padding when static-light use requires them. Keep all moving components separate. Apply object scale; do not add gameplay, lights or collision automatically. Output one named collection, meshes, optional UCX only when later approved, and a neutral front/side/three-quarter preview.

Priority: P2

Dimension basis: proposed modeling envelope; fit current source ports/collision before dressing

Tiles: Canal, Waterworks-W, Brineworks

Triangle target: [30, 350] (proposal).

Sockets: []

## Visual references

- [MODEL20](../art/model-sheets/MODEL20_DeepAndShallowWaterAssembly.png)
- [DRESS06](../art/district-sheets/DRESS06_CanalDressingAssembly.png)
