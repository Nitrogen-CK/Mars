# I17 / LoftLadder125Segment

Generate LoftLadder125Segment, asset I17, for Mise en Monstre Warrens C. Ultra-low-poly flat shading, chunky primitive silhouette, 1-2 broad bevels, no realistic microdetail. Proposed width/depth/height [100.0, 15.0, 125.0]cm. Blender Z up, width local X, front -Y. Pivot: bottom-center at contact plane. Materials ['TX08', 'TX09']. two segments over source 2.5m height; existing P5 gate and ladder logic. Art skin only. Keep existing actor collision, pivots, sweeps, grip frames and traces. Collision replacement requires a later gameplay/PIE pass. UV0: use shared palette or one trim lane for small props; tiling surfaces at catalog tile_metres for large forms. UV1: non-overlapping lightmap UVs with padding when static-light use requires them. Keep all moving components separate. Apply object scale; do not add gameplay, lights or collision automatically. Output one named collection, meshes, optional UCX only when later approved, and a neutral front/side/three-quarter preview.

Priority: P0

Dimension basis: proposed modeling envelope; fit current source ports/collision before dressing

Tiles: Belfry

Triangle target: [300, 1800] (proposal).

Sockets: ['Axis', 'Grip_Existing']

## Visual references

- [MODEL25](../art/model-sheets/MODEL25_LaddersAndBacksideGateHardware.png)
- [DRESS07](../art/district-sheets/DRESS07_BelfryDressingAssembly.png)
