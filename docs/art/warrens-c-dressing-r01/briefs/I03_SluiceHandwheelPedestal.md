# I03 / SluiceHandwheelPedestal

Generate SluiceHandwheelPedestal, asset I03, for Mise en Monstre Warrens C. Ultra-low-poly flat shading, chunky primitive silhouette, 1-2 broad bevels, no realistic microdetail. Proposed width/depth/height [100.0, 100.0, 160.0]cm. Blender Z up, width local X, front -Y. Pivot: bottom-center at contact plane. Materials ['TX08', 'TX09']. same source handwheel actor; keep grip rotation and reach point. Art skin only. Keep existing actor collision, pivots, sweeps, grip frames and traces. Collision replacement requires a later gameplay/PIE pass. UV0: use shared palette or one trim lane for small props; tiling surfaces at catalog tile_metres for large forms. UV1: non-overlapping lightmap UVs with padding when static-light use requires them. Keep all moving components separate. Apply object scale; do not add gameplay, lights or collision automatically. Output one named collection, meshes, optional UCX only when later approved, and a neutral front/side/three-quarter preview.

Priority: P0

Dimension basis: current authored source proxy envelope

Tiles: Brineworks

Triangle target: [300, 1800] (proposal).

Sockets: ['Axis', 'Grip_Existing']

## Visual references

- [MODEL05](../art/model-sheets/MODEL05_SluiceChainKit.png)
- [DRESS11](../art/district-sheets/DRESS11_BrineworksDressingAssembly.png)
