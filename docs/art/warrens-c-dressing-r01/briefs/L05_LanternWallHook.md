# L05 / LanternWallHook

Generate LanternWallHook, asset L05, for Mise en Monstre Warrens C. Ultra-low-poly flat shading, chunky primitive silhouette, 1-2 broad bevels, no realistic microdetail. Proposed width/depth/height [15.0, 25.0, 25.0]cm. Blender Z up, width local X, front -Y. Pivot: rear-center mounting surface; art faces local -Y. Materials ['TX09']. mount origin on wall; preserve existing interaction point where a real hook exists. NoCollision visual dressing; retained greybox/world collision is authoritative. UV0: use shared palette or one trim lane for small props; tiling surfaces at catalog tile_metres for large forms. UV1: non-overlapping lightmap UVs with padding when static-light use requires them. Keep all moving components separate. Apply object scale; do not add gameplay, lights or collision automatically. Output one named collection, meshes, optional UCX only when later approved, and a neutral front/side/three-quarter preview.

Priority: P0

Dimension basis: proposed modeling envelope; fit current source ports/collision before dressing

Tiles: Hub, Court, Ossuary, Waterworks-W, Pit, Canal, Belfry, Reliquary, Mill, Catacomb, Brineworks

Triangle target: [200, 1000] (proposal).

Sockets: ['Mount']

## Visual references

- [MODEL09](../art/model-sheets/MODEL09_PracticalLightKit.png)
