# CCS25 / AxleBearingBlock

Generate CCS25 AxleBearingBlock for the Chain Crossing / Sluice in Mise en Monstre. Ultra-low-poly, chunky flat-shaded primitives with at most one broad bevel and quiet matte surfaces. Envelope W/D/H [30.0, 25.0, 35.0]cm; proposed art envelope; fit retained geometry/actor before import. Pivot: wheel/drum axle center; source Unreal axis is local +X, mesh adapter must preserve it. Materials TX09. single bearing body mirrored/instanced as needed; no moving collider or new interaction. Visual skin/carrier defaults NoCollision; retain current greybox and gameplay-actor collision, traces, grip frames and movement sweeps. Keep moving and static components separate. UV0 uses the shared palette/trim or tiling scale from materials.json. Apply object scale, name collection CCS25_AxleBearingBlock, provide front/side/three-quarter views. No collision, lights, gameplay or finished FX system automatically. Reference: art/CS07.png.

[Visual reference](../art/CS07.png)

Shared family: W06. Use shared family as shape/material starting point; section dimensions and source contract win. This is not a request to duplicate an existing mesh.
