# E20 / DripCard

Generate DripCard, asset E20, for Mise en Monstre Warrens C. Ultra-low-poly flat shading, chunky primitive silhouette, 1-2 broad bevels, no realistic microdetail. Proposed width/depth/height [30.0, 1.0, 120.0]cm. Blender Z up, width local X, front -Y. Pivot: bottom-center at contact plane. Materials ['FX_Water']. vertical alpha carrier for sparse leaks; geometry/material input only, no finished moving particles or gameplay wetness. NoCollision visual dressing; retained greybox/world collision is authoritative. UV0: use shared palette or one trim lane for small props; tiling surfaces at catalog tile_metres for large forms. UV1: non-overlapping lightmap UVs with padding when static-light use requires them. Keep all moving components separate. Apply object scale; do not add gameplay, lights or collision automatically. Output one named collection, meshes, optional UCX only when later approved, and a neutral front/side/three-quarter preview.

Priority: P2

Dimension basis: proposed modeling envelope; fit current source ports/collision before dressing

Tiles: Waterworks-W, Brineworks, Catacomb

Triangle target: [30, 350] (proposal).

Sockets: []

## Visual references

- [MODEL34](../art/model-sheets/MODEL34_AtmosphereCarrierMeshes.png)
