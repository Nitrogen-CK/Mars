# I19 / VaultDoorSkin

Generate VaultDoorSkin, asset I19, for Mise en Monstre Warrens C. Ultra-low-poly flat shading, chunky primitive silhouette, 1-2 broad bevels, no realistic microdetail. Proposed width/depth/height [250.0, 30.0, 300.0]cm. Blender Z up, width local X, front -Y. Pivot: existing actor hinge, never recompute from artist view. Materials ['TX09', 'TX01']. source opening span 250cm; pivot and sweep must match existing door actor. Art skin only. Keep existing actor collision, pivots, sweeps, grip frames and traces. Collision replacement requires a later gameplay/PIE pass. UV0: use shared palette or one trim lane for small props; tiling surfaces at catalog tile_metres for large forms. UV1: non-overlapping lightmap UVs with padding when static-light use requires them. Keep all moving components separate. Apply object scale; do not add gameplay, lights or collision automatically. Output one named collection, meshes, optional UCX only when later approved, and a neutral front/side/three-quarter preview.

Priority: P0

Dimension basis: proposed modeling envelope; fit current source ports/collision before dressing

Tiles: Pit

Triangle target: [300, 1800] (proposal).

Sockets: ['Axis', 'Grip_Existing']

## Visual references

- [MODEL26](../art/model-sheets/MODEL26_VaultDoorCampPlinthAndBox-r02.png)
- [DRESS05](../art/district-sheets/DRESS05_PitDressingAssembly.png)
