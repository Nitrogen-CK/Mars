# I12 / CuringVat

Generate CuringVat, asset I12, for Mise en Monstre Warrens C. Ultra-low-poly flat shading, chunky primitive silhouette, 1-2 broad bevels, no realistic microdetail. Proposed width/depth/height [240.0, 160.0, 140.0]cm. Blender Z up, width local X, front -Y. Pivot: bottom-center at contact plane. Materials ['TX08', 'TX09', 'TX15']. P7 source support stop +5m; tool/hand area stays unobstructed. Art skin only. Keep existing actor collision, pivots, sweeps, grip frames and traces. Collision replacement requires a later gameplay/PIE pass. UV0: use shared palette or one trim lane for small props; tiling surfaces at catalog tile_metres for large forms. UV1: non-overlapping lightmap UVs with padding when static-light use requires them. Keep all moving components separate. Apply object scale; do not add gameplay, lights or collision automatically. Output one named collection, meshes, optional UCX only when later approved, and a neutral front/side/three-quarter preview.

Priority: P0

Dimension basis: current authored source proxy envelope

Tiles: Mill

Triangle target: [300, 1800] (proposal).

Sockets: ['Axis', 'Grip_Existing']

## Visual references

- [MODEL06](../art/model-sheets/MODEL06_SaltMillCuringStation.png)
- [MODEL37](../art/model-sheets/MODEL37_MillAndCuringVatBreakdown-r02.png)
- [DRESS09](../art/district-sheets/DRESS09_MillDressingAssembly.png)
