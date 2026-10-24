# E06 / CavePillarShell

Generate CavePillarShell, asset E06, for Mise en Monstre Warrens C. Ultra-low-poly flat shading, chunky primitive silhouette, 1-2 broad bevels, no realistic microdetail. Proposed width/depth/height [200.0, 200.0, 500.0]cm. Blender Z up, width local X, front -Y. Pivot: bottom-center at contact plane. Materials ['TX04']. split half-shells around an existing support only; do not scatter new pillars in playable space. NoCollision visual dressing; retained greybox/world collision is authoritative. UV0: use shared palette or one trim lane for small props; tiling surfaces at catalog tile_metres for large forms. UV1: non-overlapping lightmap UVs with padding when static-light use requires them. Keep all moving components separate. Apply object scale; do not add gameplay, lights or collision automatically. Output one named collection, meshes, optional UCX only when later approved, and a neutral front/side/three-quarter preview.

Priority: P1

Dimension basis: proposed modeling envelope; fit current source ports/collision before dressing

Tiles: Pit, Canal

Triangle target: [100, 700] (proposal).

Sockets: []

## Visual references

- [MODEL17](../art/model-sheets/MODEL17_CaveWallCeilingAndCorners.png)
