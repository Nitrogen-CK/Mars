# CCS52 / FoamEdgeStrip

Generate CCS52 FoamEdgeStrip for the Chain Crossing / Sluice in Mise en Monstre. Ultra-low-poly, chunky flat-shaded primitives with at most one broad bevel and quiet matte surfaces. Envelope W/D/H [200.0, 50.0, 1.0]cm; proposed art envelope; fit retained geometry/actor before import. Pivot: surface corner at exact retained floor/water elevation; no thickness above walk plane. Materials FX_Water. thin irregular alpha carrier at bank/abutment contact; no foam ribbon spanning the crossing. Visual skin/carrier defaults NoCollision; retain current greybox and gameplay-actor collision, traces, grip frames and movement sweeps. Keep moving and static components separate. UV0 uses the shared palette/trim or tiling scale from materials.json. Apply object scale, name collection CCS52_FoamEdgeStrip, provide front/side/three-quarter views. No collision, lights, gameplay or finished FX system automatically. Reference: art/CS14.png.

[Visual reference](../art/CS14.png)

Shared family: W12. Use shared family as shape/material starting point; section dimensions and source contract win. This is not a request to duplicate an existing mesh.
