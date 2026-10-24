# I18 / MournerCacheGateSkin

Generate MournerCacheGateSkin, asset I18, for Mise en Monstre Warrens C. Ultra-low-poly flat shading, chunky primitive silhouette, 1-2 broad bevels, no realistic microdetail. Proposed width/depth/height [250.0, 30.0, 250.0]cm. Blender Z up, width local X, front -Y. Pivot: bottom-center at contact plane. Materials ['TX09', 'TX01']. shared Mourner seal with I06; source P3 latch, no second player hold. Art skin only. Keep existing actor collision, pivots, sweeps, grip frames and traces. Collision replacement requires a later gameplay/PIE pass. UV0: use shared palette or one trim lane for small props; tiling surfaces at catalog tile_metres for large forms. UV1: non-overlapping lightmap UVs with padding when static-light use requires them. Keep all moving components separate. Apply object scale; do not add gameplay, lights or collision automatically. Output one named collection, meshes, optional UCX only when later approved, and a neutral front/side/three-quarter preview.

Priority: P0

Dimension basis: proposed modeling envelope; fit current source ports/collision before dressing

Tiles: Reliquary

Triangle target: [300, 1800] (proposal).

Sockets: ['Axis', 'Grip_Existing']

## Visual references

- [MODEL25](../art/model-sheets/MODEL25_LaddersAndBacksideGateHardware.png)
- [DRESS08](../art/district-sheets/DRESS08_ReliquaryDressingAssembly.png)
